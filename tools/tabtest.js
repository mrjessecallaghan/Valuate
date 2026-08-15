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
  "ui/TodoPanel.lua",
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
local EXPECTED_TABS = { "scales", "settings", "changelog", "about", "instructions", "bestEquipment", "todo" }
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

-- ---- the tabs answer the mouse --------------------------------------------------
-- Every other clickable thing here responds to hover; tabs answered only by being clicked,
-- so the one row whose entire job is "click me to go somewhere" gave no sign it could be.
--
-- The active tab is deliberately exempt: it already wears the selected colours, and
-- tweening it on hover would dim the thing telling you where you are. SelectTab stays the
-- only writer of that colour, which is what makes the exemption safe rather than an
-- oversight - so it is asserted, not assumed.
--
-- The hover FADES, so the colour has not moved on the frame the mouse arrives. Reading it
-- immediately would compare a value against itself and pass no matter what the hover did -
-- which is how this assertion read on its first run.
-- The FIRST frame with an OnUpdate, not the last. Animations.lua creates its shared ticker
-- at load, before any of this window exists; several widgets built later keep an OnUpdate of
-- their own, so taking the last match drives some unrelated widget and the tween never runs.
local animDriver
for _, f in ipairs(__frames) do
    if f.__scripts and f.__scripts.OnUpdate and not animDriver then animDriver = f end
end
local function settle()
    if not animDriver then return end
    for _ = 1, 30 do animDriver.__scripts.OnUpdate(animDriver, 0.05) end
end

if buttons and animDriver then
    tabs.selectTab("scales")
    settle()

    local idle = buttons.about
    local before = { idle:GetBackdropColor() }
    idle:GetScript("OnEnter")(idle)
    settle()
    local after = { idle:GetBackdropColor() }
    local moved = false
    for i = 1, 4 do
        if before[i] ~= after[i] then moved = true end
    end
    ok(moved, "hovering a tab you are not on lightens it")
    idle:GetScript("OnLeave")(idle)
    settle()

    -- Watch the BORDER, not the fill.
    --
    -- SelectTab paints the active tab with COLORS.buttonHover - the same fill the hover
    -- tween targets - so a hover that wrongly fired on the active tab would move it to the
    -- colour it already has and change nothing observable. Written against the fill first,
    -- this assertion passed whether the guard existed or not.
    --
    -- The border is where the two differ: the active tab wears selectedBorder, the hover
    -- targets borderLight, and swapping one for the other dims the only strong edge in the
    -- row - the thing actually telling you which tab you are on.
    local active = buttons.scales
    local activeBefore = { active:GetBackdropBorderColor() }
    active:GetScript("OnEnter")(active)
    settle()
    local activeAfter = { active:GetBackdropBorderColor() }
    local activeMoved = false
    for i = 1, 4 do
        if activeBefore[i] ~= activeAfter[i] then activeMoved = true end
    end
    ok(not activeMoved, "hovering the tab you ARE on leaves its selected border alone")
end

-- ---- every button in the window answers the mouse ------------------------------
-- This gate builds the whole window, so it can ask the question of ALL of them at once
-- rather than one button at a time - which matters, because the way a button shows hover
-- here is not uniform and a check written against one technique would miss the others.
--
-- Two are legitimate and not interchangeable:
--   * a HIGHLIGHT-layer texture, drawn by the client only while the mouse is over the
--     frame, needing no script - used where OnEnter is already spoken for by a tooltip;
--   * a hover handler that moves the backdrop, instantly or as a fade.
--
-- Scan Best Equipment had neither, while the three buttons beside it each carried the
-- texture with a comment explaining the technique. It was found by auditing, not by
-- anyone noticing - a button that never lights up looks disabled rather than broken.
--
-- Narrowed by IDENTITY on the shared backdrop table, not merely "has a backdrop": slot
-- frames, scrollbar arrows, lock toggles and the colour swatch are all Buttons with a
-- backdrop, and none of them is trying to look like a button. Only the ones wearing
-- BACKDROP_BUTTON have made that promise.
--
-- Tabs are excluded and asserted separately, just above: the ACTIVE tab deliberately does
-- not answer hover, because it already wears the selected colours. Folding them in here
-- would need this sweep to know which tab is current, and would report the one correct
-- exemption in the window as a defect.
local isTab = {}
for _, btn in pairs(buttons or {}) do isTab[btn] = true end

local mute = {}
for _, f in ipairs(__frames) do
    if f.__type == "Button" and f.__backdrop == ns.BACKDROP_BUTTON and f.__scripts
       and not isTab[f] then
        local hl = false
        for _, region in ipairs(f.__regions or {}) do
            if region.__layer == "HIGHLIGHT" then hl = true end
        end
        if not hl and f.__scripts.OnEnter then
            -- Drive it and see whether anything about the frame's fill changes.
            local before = { f:GetBackdropColor() }
            pcall(f.__scripts.OnEnter, f)
            settle()
            local after = { f:GetBackdropColor() }
            for i = 1, 4 do
                if before[i] ~= after[i] then hl = true end
            end
            if f.__scripts.OnLeave then pcall(f.__scripts.OnLeave, f) end
            settle()
        end
        -- Named by its label, because these frames are anonymous and "unnamed" told me
        -- only how many were wrong, not which.
        if not hl then
            local who = f.__name
            if not who and f.label and f.label.GetText then who = f.label:GetText() end
            for _, region in ipairs(f.__regions or {}) do
                if not who and region.GetText and region:GetText() then who = region:GetText() end
            end
            mute[#mute + 1] = who or "unnamed"
        end
    end
end
eq(#mute, 0, "every button in the window shows something on hover (" ..
   table.concat(mute, ", ") .. ")")

-- ---- the To Do tab is rebuilt every time you look at it -------------------------
-- Deliberately OUTSIDE the isSwitch guard that everything else here is inside, and for a
-- reason worth stating: a stale to-do list is worse than none. It would have you chasing an
-- upgrade you have already equipped, and re-clicking the tab is a reasonable way to ask
-- whether it is still true.
local todoRefreshes = 0
local realTodoRefresh = ns.RefreshTodoPanel
ns.RefreshTodoPanel = function() todoRefreshes = todoRefreshes + 1 end

tabs.selectTab("scales")
todoRefreshes = 0
tabs.selectTab("todo")
eq(todoRefreshes, 1, "arriving at the To Do tab rebuilds the list")
tabs.selectTab("todo")
eq(todoRefreshes, 2, "and re-clicking it rebuilds it again, rather than showing a stale one")

ns.RefreshTodoPanel = realTodoRefresh

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
