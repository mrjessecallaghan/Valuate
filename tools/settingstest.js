#!/usr/bin/env node
/*
 * @gate The keybind capture always releases the keyboard
 *
 * Builds the real Settings panel and drives its keybind button.
 *
 * ui/Settings.lua is 2,232 lines and had no runtime coverage at all, which made it the
 * largest blind spot left - and reading it turned up a capture that never let go. On 3.3.5
 * there is no SetPropagateKeyboardInput until 4.0, so a frame holding EnableKeyboard(true)
 * CONSUMES what you type: an armed button on a visible panel eats keystrokes, and the next
 * key you press is silently bound to something.
 *
 * Capture had exactly two exits, Escape and pressing a key, and both need the panel in
 * front of you. Right-clicking to clear went round them, and so did closing the window.
 * This gate is about the exits, not the binding: every case below ends by asserting the
 * keyboard was handed back.
 *
 * The Valuate API is stubbed HERE rather than in luaharness.js. The shared mock is what the
 * CLIENT provides; pushing this addon's own methods into it would make every other gate test
 * against a more imaginary client than it does now.
 *
 * Usage:  node tools/settingstest.js
 */
"use strict";

const { load } = require("./luaharness.js");

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

-- ---- client surface this panel touches ---------------------------------------
__bindings = {}          -- key -> action
__saved = 0
function GetBindingKey(action)
    local found = {}
    for key, act in pairs(__bindings) do
        if act == action then table.insert(found, key) end
    end
    table.sort(found)
    return found[1], found[2]
end
function GetBindingAction(key) return __bindings[key] or "" end
function SetBinding(key, action)
    if action then __bindings[key] = action else __bindings[key] = nil end
    return true
end
function SaveBindings() __saved = __saved + 1 end
function GetCurrentBindingSet() return 1 end

__shift, __ctrl, __alt = false, false, false
function IsShiftKeyDown() return __shift end
function IsControlKeyDown() return __ctrl end
function IsAltKeyDown() return __alt end

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end
function GameTooltip:IsOwned() return false end
function GameTooltip:AddDoubleLine() end

-- ---- the addon's own API, stubbed for this gate ------------------------------
local OPTIONS = { reduceMotion = false, decimalPlaces = 1 }
Valuate.GetOptions = function() return OPTIONS end
Valuate.GetScales = function() return {} end
Valuate.GetActiveScales = function() return {} end
Valuate.GetPrimaryScale = function() return nil, nil end
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

-- ---- build it ----------------------------------------------------------------
local parent = CreateFrame("Frame")
local built, err = pcall(ns.CreateSettingsPanel, parent)
if not built then
    return { "the Settings panel failed to build: " .. tostring(err) }, 1
end
ok(true, "the Settings panel builds")

-- The keybind button is the only frame in this panel that listens for key presses.
-- Found by that rather than by position, so inserting a control above it does not
-- silently redirect the gate at something else.
local keybind = nil
for _, f in ipairs(__frames) do
    if f.__scripts and f.__scripts.OnKeyDown then keybind = f end
end
ok(keybind ~= nil, "found the keybind button")

local function click(button) keybind.__scripts.OnClick(keybind, button) end
local function press(key) keybind.__scripts.OnKeyDown(keybind, key) end
local function capturing() return keybind.__keyboard == true end

-- ---- the exits that already worked -------------------------------------------
eq(capturing(), false, "the button starts with the keyboard released")

click("LeftButton")
eq(capturing(), true, "left-click arms the capture")
eq(keybind.label:GetText(), "Press Key...", "...and says so")

press("ESCAPE")
eq(capturing(), false, "Escape releases the keyboard")

click("LeftButton")
press("K")
eq(capturing(), false, "binding a key releases the keyboard")
eq(__bindings["K"], "VALUATE_TOGGLE_UI", "the key is bound")

-- ---- THE regression: right-click to clear ------------------------------------
-- Right-click clears regardless of state, so it bypassed both exits. It set the label and
-- nothing else: the button kept the keyboard and bound whatever you pressed next.
click("LeftButton")
eq(capturing(), true, "armed again")
click("RightButton")
eq(capturing(), false, "right-clicking to clear mid-capture RELEASES the keyboard")
eq(__bindings["K"], nil, "...and still clears the binding")

press("J")
eq(__bindings["J"], nil, "a key pressed afterwards is not silently bound")

-- ---- THE second regression: closing the window -------------------------------
-- Capture's two exits both need the panel in front of you. Hidden frames get no input, so
-- this only bites when you come back - which is when you have forgotten about it.
click("LeftButton")
eq(capturing(), true, "armed once more")
keybind:Hide()
if keybind.__scripts.OnHide then keybind.__scripts.OnHide(keybind) end
eq(capturing(), false, "hiding the panel releases the keyboard")

keybind:Show()
press("L")
eq(__bindings["L"], nil, "reopening does not bind the next key you type")

-- ---- modifiers ---------------------------------------------------------------
click("LeftButton")
__shift, __ctrl = true, true
press("M")
__shift, __ctrl = false, false
eq(__bindings["SHIFT-CTRL-M"], "VALUATE_TOGGLE_UI", "modifiers are part of the binding")
eq(capturing(), false, "and it releases afterwards")

-- A modifier on its own must not end the capture: you are still mid-chord.
click("LeftButton")
press("LSHIFT")
eq(capturing(), true, "a modifier alone does not end the capture")
press("RALT")
eq(capturing(), true, "...nor does the other kind")
press("ESCAPE")
eq(capturing(), false, "and Escape still gets you out afterwards")

-- ---- rebinding replaces rather than accumulates ------------------------------
__bindings = {}
click("LeftButton")
press("N")
click("LeftButton")
press("P")
eq(__bindings["N"], nil, "rebinding clears the previous key")
eq(__bindings["P"], "VALUATE_TOGGLE_UI", "...and the new one is bound")
eq(capturing(), false, "still released at the end of it all")

return failures, checks
`,
  "settingstest",
  "the Settings keybind capture"
);
