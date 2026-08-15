#!/usr/bin/env node
/*
 * @gate Re-clicking the active tab does not replay its arrival
 *
 * Builds the real main window and drives its tab buttons.
 *
 * SelectTab did the same work whether you were switching tabs or clicking the one you were
 * already on. For Best Equipment that meant snapping the window to MIN_WINDOW_HEIGHT and
 * growing it back to fit, so a click that changed nothing collapsed the window and
 * re-expanded it; the staggered column reveals replayed, and the crossfade blinked the panel
 * you were reading. An entrance is for arriving. Playing it when nothing arrived is what
 * makes a UI feel loose, and it is invisible to every static gate.
 *
 * The property is stated as "arrivals happen on arrival": the reveal and the height reset
 * fire on a real switch and not otherwise, while everything else - showing the panel,
 * restyling the buttons, refreshing content - still runs either way, because a re-click is
 * still a reasonable way to ask for a refresh.
 *
 * Usage:  node tools/tabtest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const defaults = core.match(/local DEFAULT_OPTIONS\s*=\s*\{[\s\S]*?\n\}/);
if (!defaults) {
  console.error("  SLICE  could not find `local DEFAULT_OPTIONS` in Valuate.lua");
  process.exit(1);
}

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Dialog.lua",
  "ui/Pickers.lua",
  "ui/ScaleList.lua",
  "ui/ScaleEditor.lua",
  "ui/BestEquipment.lua",
  "ui/Settings.lua",
  "ui/InfoPanels.lua",
  "ui/CharacterWindow.lua",
  "ui/UpgradeArrows.lua",
  "ui/UpgradePopup.lua",
  "ValuateUI.lua",
]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function eq(got, want, what)
    checks = checks + 1
    if got ~= want then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end

local ns = __ns

` + defaults[0] + `
local OPTIONS = DEFAULT_OPTIONS

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end
function GameTooltip:IsOwned() return false end
function GameTooltip:AddDoubleLine() end
function GetBindingKey() return nil end
function GetBindingAction() return "" end
function SetBinding() return true end
function SaveBindings() end
function GetCurrentBindingSet() return 1 end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function GetInventoryItemLink() return nil end
function UnitLevel() return 80 end
function UnitName() return "Tester" end

Valuate.GetOptions = function() return OPTIONS end
Valuate.GetScales = function() return {} end
Valuate.GetActiveScales = function() return {} end
Valuate.GetPrimaryScale = function() return nil, nil end
Valuate.GetBestEquipment = function() return {} end
Valuate.ResetTooltips = function() end
Valuate.ScanBestEquipment = function() end
Valuate.ToggleMinimapButton = function() end
Valuate.ShowMinimapButton = function() end
Valuate.HideMinimapButton = function() end
Valuate.RefreshCharacterWindowDisplay = function() end
Valuate.RefreshCharacterWindowVisibility = function() end
Valuate.RestoreDefaultOptions = function() end
Valuate.SaveSettingsSnapshot = function() end
Valuate.LoadSettingsSnapshot = function() end
Valuate.HasSettingsSnapshot = function() return false end
Valuate.ShowConfirmDialog = function() end
Valuate.GetProfessionOverrideChoices = function() return {} end
Valuate.GetAutomationHeartbeat = function() return nil end

__reveals = 0
__heightResets = 0
Valuate.RefreshBestEquipmentDisplay = function() end

-- Watch the height reset specifically: MIN_WINDOW_HEIGHT is the value SelectTab resets to
-- before refitting, so a SetHeight to exactly that is the reset and nothing else is.
local MIN_H = nil

-- ShowUI wraps its whole build in a pcall of its own and reports failures by PRINTING
-- them, so it returns success even when the window did not get built. A gate that trusted
-- the return value would sail past a broken window; the printed output is the real signal.
__printed = {}
local built, err = pcall(Valuate.ShowUI, Valuate)
if not built then return { "ShowUI raised: " .. tostring(err) }, 1 end
if #__printed > 0 then
    return { "the main window failed to build: " .. table.concat(__printed, " | ") }, 1
end
ok(ns.ValuateUIFrame ~= nil, "the main window builds")

local tabs = ns.ValuateUIFrame.tabs
ok(tabs ~= nil, "the tab system is reachable")
ok(type(tabs.selectTab) == "function", "selectTab is exposed")

-- Counters go in AFTER the build, not before: the panels assign these functions
-- themselves while building, so a stub installed earlier is overwritten and every
-- assertion below silently counts zero. The first run of this gate did exactly that.
Valuate.RevealBestEquipmentColumns = function() __reveals = __reveals + 1 end
ns.RevealSettingsColumns = function() __reveals = __reveals + 1 end

MIN_H = ns.ValuateUIFrame:GetHeight()

-- Count height resets by wrapping SetHeight on the window.
local realSetHeight = ns.ValuateUIFrame.SetHeight
ns.ValuateUIFrame.SetHeight = function(self, h)
    if h == MIN_H then __heightResets = __heightResets + 1 end
    return realSetHeight(self, h)
end

local function switchTo(name)
    __reveals, __heightResets = 0, 0
    tabs.selectTab(name)
end

-- ---- arriving somewhere DOES play the arrival --------------------------------
switchTo("bestEquipment")
eq(__reveals, 1, "switching to Best Equipment reveals its columns")
ok(__heightResets >= 1, "switching to Best Equipment resets the height to refit")

switchTo("settings")
eq(__reveals, 1, "switching to Settings reveals its columns")
ok(__heightResets >= 1, "switching to Settings resets the height")

-- ---- THE regression: clicking the tab you are already on ---------------------
switchTo("settings")
eq(__reveals, 0, "re-clicking Settings does NOT replay the column reveal")
eq(__heightResets, 0, "...and does not reset the window height")

tabs.selectTab("bestEquipment")
switchTo("bestEquipment")
eq(__reveals, 0, "re-clicking Best Equipment does NOT replay the column reveal")
eq(__heightResets, 0, "...and does not collapse the window to refit it")

-- ---- a re-click still leaves the panel visible and opaque --------------------
-- The crossfade is skipped on a re-click, so the panel must be pinned to full alpha
-- rather than left mid-fade or faded from zero.
tabs.selectTab("about")
tabs.selectTab("about")
local panel = ns.ValuateUIFrame.tabs.aboutPanel
ok(panel == nil or panel:IsShown(), "the re-clicked panel is still shown")

-- ---- switching back and forth still animates ---------------------------------
-- The guard must key on the tab actually changing, not on "have we been here before".
switchTo("changelog")
local firstAway = __reveals
switchTo("bestEquipment")
eq(__reveals, 1, "returning to a tab you left DOES play its arrival again")

-- ---- every tab is built the same way -------------------------------------------
-- Four of the six were hand-copied from the helper, and none of the copies carried the
-- accent bar - the azure line marking the tab you are actually on. SelectTab guards on the
-- accent existing at all, so it skipped them in silence: no missing texture, no error,
-- just four tabs that never showed you where you were.
--
-- Written against the whole set rather than the four, because the next tab added by hand
-- would be the fifth and this gate should not need editing to notice.
local EXPECTED_TABS = { "scales", "settings", "changelog", "about", "instructions", "bestEquipment" }
local buttons = ns.ValuateUIFrame.tabs.buttons
ok(buttons ~= nil, "the tab buttons are reachable from outside the builder")

if buttons then
    local built = 0
    for _ in pairs(buttons) do built = built + 1 end
    eq(built, #EXPECTED_TABS, "every tab in the row was built")

    for _, name in ipairs(EXPECTED_TABS) do
        local btn = buttons[name]
        ok(btn ~= nil, "tab exists: " .. name)
        if btn then
            ok(btn.accent ~= nil,
               "tab has the accent bar that marks the one you are on: " .. name)
            ok(btn.label ~= nil, "tab has a label: " .. name)
            ok(btn:GetWidth() > 0, "tab was sized to its text: " .. name)
        end
    end

    -- And the accent actually follows the selection, rather than merely existing.
    --
    -- Guarded, because a missing accent is the exact failure above and an unguarded index
    -- here would abort the run with a Lua error instead of reporting which tab was wrong.
    -- The gate still fails either way; only one of the two tells you what happened.
    local a, b = buttons.about.accent, buttons.bestEquipment.accent
    if a and b then
        tabs.selectTab("about")
        ok(a:IsShown(), "the selected tab shows its accent")
        ok(not b:IsShown(), "and the others hide theirs")
        tabs.selectTab("bestEquipment")
        ok(b:IsShown(), "which moves with the selection")
        ok(not a:IsShown(), "leaving the tab you came from unmarked")
    end
end

-- ---- and the tab still changes ------------------------------------------------
switchTo("instructions")
switchTo("bestEquipment")
eq(__reveals, 1, "a genuine switch always reveals, however many times you do it")
switchTo("about")
switchTo("bestEquipment")
eq(__reveals, 1, "...and again")

return failures, checks
`,
  "tabtest",
  "the tab switching"
);
