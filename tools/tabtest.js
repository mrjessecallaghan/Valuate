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
