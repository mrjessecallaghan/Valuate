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

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

/*
 * The options table is seeded from the REAL DEFAULT_OPTIONS.
 *
 * The first version of this fixture used a hand-written stub with three keys in it, and the
 * checkbox sweep below duly reported twenty-three failures - every one of them because an
 * option started `nil` in the stub and ended `false` after a round trip. Nothing was wrong
 * with the addon; the fixture was.
 *
 * That is the whole argument for taking the defaults from source: the panel's controls are
 * written against a table where every key exists, `ApplyOptionDefaults` guarantees that at
 * load, and a fixture that does not is testing a state the addon never runs in. It also
 * means adding an option cannot quietly fall out of this gate's coverage.
 */
const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const defaults = core.match(/local DEFAULT_OPTIONS\s*=\s*\{[\s\S]*?\n\}/);
if (!defaults) {
  console.error(
    "  SLICE  could not find `local DEFAULT_OPTIONS` in Valuate.lua - the fixture would " +
      "fall back to an option table the addon never actually runs with"
  );
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
` + defaults[0] + `
local STORE = DEFAULT_OPTIONS

-- OPTIONS is a recording proxy, not the table itself.
--
-- The sweep at the bottom needs to know which option each checkbox is SUPPOSED to own, and
-- the panel tells us without being asked: every box initialises itself with
-- SetChecked(Valuate:GetOptions().someKey == true), so the last key read immediately before
-- a SetChecked is that box's key. Compare it against the key the box WRITES when clicked
-- and a control wired to its neighbour's option stops being invisible.
--
-- Without this the sweep proves only "exactly one option changed", which a mis-wired
-- checkbox satisfies perfectly - it was caught doing so during a mutation run, which is why
-- the proxy exists.
--
-- Empty table + metatable, deliberately: __index and __newindex only fire for keys the
-- table does not have, so the store has to live elsewhere for every access to be seen.
__lastRead = nil
local OPTIONS = setmetatable({}, {
    __index = function(_, k) __lastRead = k return STORE[k] end,
    __newindex = function(_, k, v) STORE[k] = v end,
    __pairs = function() return pairs(STORE) end,
})
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

-- Records the option key each checkbox initialises itself from.
--
-- Wrapped around CreateFrame because the mock gives every frame its own methods, so there
-- is no single SetChecked to hook. Only the FIRST read is kept: the sweep below calls
-- SetChecked itself, and that must not overwrite what the panel established.
local realCreateFrame = CreateFrame
function CreateFrame(...)
    local f = realCreateFrame(...)
    if f.__type == "CheckButton" then
        local origSetChecked = f.SetChecked
        f.SetChecked = function(self, v)
            if self.__initKey == nil and __lastRead ~= nil then
                self.__initKey = __lastRead
            end
            -- Cleared so the NEXT checkbox cannot inherit this one's key by being built
            -- without reading an option of its own.
            __lastRead = nil
            return origSetChecked(self, v)
        end
    end
    return f
end

-- ---- build it ----------------------------------------------------------------
local parent = CreateFrame("Frame")
local built, err = pcall(ns.CreateSettingsPanel, parent)
if not built then
    return { "the Settings panel failed to build: " .. tostring(err) }, 1
end
ok(true, "the Settings panel builds")

-- ---- the three columns stay roughly level -------------------------------------
-- Sections have always been appended to whichever column looked emptiest at the time, and
-- nothing ever checked the result. By v0.124.0a it had drifted to 998 / 952 / 580.
--
-- That is not a broken layout - the panel scrolls, and the scroll child is sized from the
-- TALLEST column, so nothing is unreachable. It is worse than broken in a quieter way: the
-- last four hundred pixels of scrolling were two columns of whitespace beside one column of
-- content, which reads as the panel having ended and then not having ended.
--
-- The threshold is deliberately generous. Three columns filled by hand will never be equal,
-- and a gate that demanded they were would be re-tuned into meaninglessness the first time
-- it fired. 60% catches "a whole section landed on one column again" and stays quiet about
-- ordinary unevenness.
local h = parent.columnContentHeights
ok(type(h) == "table" and #h == 3, "the panel reports how tall each column's content is")

-- The reported numbers have to be a MEASUREMENT, not three copies of one number.
--
-- Reporting the tallest height for all three columns satisfies any balance check, forever,
-- on any layout - which is exactly what a mutation proved: the ratio came out at 1.00 and
-- the gate was delighted.
--
-- Three columns filled by hand do not come out identical, so identical numbers mean nobody
-- measured. That is a weaker guard than cross-checking against the real frames would be, and
-- it is deliberately where this stops: catching a constant is worth a line, and building a
-- second layout engine here to catch a hand-crafted near-constant is not.
if type(h) == "table" and #h == 3 then
    ok(not (h[1] == h[2] and h[2] == h[3]),
       "the three reported heights are not all identical - that means a constant, not a measurement")

end
if type(h) == "table" and #h == 3 then
    local tallest, shortest = 0, math.huge
    for _, v in ipairs(h) do
        if v > tallest then tallest = v end
        if v < shortest then shortest = v end
    end
    ok(tallest > 0, "the columns have content at all")
    local ratio = tallest > 0 and (shortest / tallest) or 0
    ok(ratio >= 0.60, string.format(
        "the shortest column is at least 60%% of the tallest - got %d%% (%d / %d / %d). " ..
        "A new section has probably landed on a column that was already the longest; " ..
        "move it to the shortest, or say here why this one belongs where it is.",
        math.floor(ratio * 100 + 0.5), h[1], h[2], h[3]))
end

-- ---- the layout self-check must not cry wolf ----------------------------------
-- Building the panel runs CheckColumnAnchors over all three columns. In the client it
-- printed a red "two controls share an anchor and will OVERLAP" warning repeatedly for
-- column 1, and every one was a false alarm.
--
-- CreateSectionHeader draws a decorative accent RULE anchored to (header, BOTTOMLEFT),
-- and the first control under that header is anchored to the same point - deliberately,
-- because they sit at different offsets (-2 for a 2px underline, -ELEMENT_SPACING*2 for
-- the control). The checker keys on (relativeTo, relativePoint) and ignores the offset,
-- which is the right call for two controls in a vertical stack and the wrong one for a
-- texture that is meant to share the slot.
--
-- A diagnostic that fires on correct layout is worse than no diagnostic: it trains you
-- to scroll past the exact message it exists to make you notice.
local layoutWarnings = 0
for _, line in ipairs(__printed) do
    if string.find(line, "layout bug", 1, true) then
        layoutWarnings = layoutWarnings + 1
    end
end
eq(layoutWarnings, 0, "building Settings reports no layout collisions")

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

-- ---- every checkbox writes exactly one option, and toggles back --------------
--
-- A settings panel is dozens of near-identical controls built by copy-paste, and the
-- failure that shape produces is a checkbox wired to its NEIGHBOUR'S option key. Nothing
-- errors: the box ticks, something gets saved, and the feature you meant to switch on
-- stays off while an unrelated one silently changes. Reading forty of them and checking
-- each against its label is exactly the job to hand to a machine.
--
-- Two properties, both copy-paste-sensitive:
--   * one click changes exactly ONE option (not zero, not two)
--   * clicking again puts it back (so the write is a toggle, not a one-way set)
local function snapshot()
    local s = {}
    for k, v in pairs(OPTIONS) do s[k] = v end
    return s
end

local function changedKeys(before, after)
    local seen, list = {}, {}
    for k, v in pairs(after) do
        if before[k] ~= v then seen[k] = true end
    end
    for k, v in pairs(before) do
        if after[k] ~= v then seen[k] = true end
    end
    for k in pairs(seen) do list[#list + 1] = k end
    table.sort(list)
    return list
end

local boxes = {}
for _, f in ipairs(__frames) do
    -- A settings checkbox: a CheckButton with a click handler. The keybind button is a
    -- plain Button, and the scale-list rows were built before this panel, so neither is
    -- picked up here.
    if f.__type == "CheckButton" and f.__scripts and f.__scripts.OnClick then
        boxes[#boxes + 1] = f
    end
end
ok(#boxes >= 10, "found the settings checkboxes (got " .. #boxes .. ")")

local multi, none = {}, {}
for i, box in ipairs(boxes) do
    local before = snapshot()
    box:SetChecked(not box:GetChecked())
    local fired = pcall(box.__scripts.OnClick, box)
    if fired then
        local changed = changedKeys(before, snapshot())
        if #changed > 1 then
            multi[#multi + 1] = i .. " -> " .. table.concat(changed, "+")
        elseif #changed == 0 then
            none[#none + 1] = tostring(i)
        else
            -- THE copy-paste failure: the box reads one option to draw itself and writes a
            -- different one when clicked. Exactly one option still changes and it still
            -- toggles back, so every other check here passes while the control does the
            -- wrong thing entirely.
            if box.__initKey then
                ok(box.__initKey == changed[1],
                   "checkbox " .. i .. " writes the option it was drawn from (drawn from " ..
                   tostring(box.__initKey) .. ", wrote " .. tostring(changed[1]) .. ")")
            end

            -- Toggle back: the same click again must restore exactly what it changed.
            local key, mid = changed[1], snapshot()
            box:SetChecked(not box:GetChecked())
            pcall(box.__scripts.OnClick, box)
            local back = snapshot()
            ok(back[key] == before[key],
               "checkbox " .. i .. " (" .. key .. ") toggles back to its starting value")
            ok(#changedKeys(mid, back) <= 1,
               "checkbox " .. i .. " (" .. key .. ") touches only its own option on the way back")
        end
    end
end

eq(#multi, 0, "no checkbox writes more than one option: " .. table.concat(multi, ", "))
-- Some boxes legitimately change nothing in OPTIONS - they drive a saved variable
-- elsewhere, or are disabled until a parent is on. Reported rather than failed, so the
-- number is visible if it ever jumps.
ok(#none <= #boxes / 2,
   "most checkboxes write an option (" .. #none .. " of " .. #boxes .. " wrote none)")

return failures, checks
`,
  "settingstest",
  "the Settings keybind capture"
);
