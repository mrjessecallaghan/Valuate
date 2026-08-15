#!/usr/bin/env node
/*
 * @gate The minimap button's drag cannot outlive the drag
 *
 * Runs MinimapButton.lua for real and drives its drag handlers.
 *
 * The cursor-follow is a raw OnUpdate installed on OnDragStart and cleared on OnDragStop.
 * That is fine as long as OnDragStop is the only way a drag can end - and it was not: hiding
 * the button mid-drag (Settings has a toggle, so does /valuate minimap) left the handler
 * installed. Hidden frames get no OnUpdate, so nothing happens until you show it again, at
 * which point the button follows the cursor with no mouse button held.
 *
 * Exactly the shape of the Settings keybind capture: an armed state whose only exits needed
 * the thing that armed it to still be there. This gate states the general form - after any
 * way a drag can end, the button is not following the cursor - so a third exit added later
 * has an assertion waiting for it.
 *
 * This file also has form. The pulse and the drag once shared the button's single OnUpdate
 * slot, and the drag discarded the pulse's cleanup, leaving a starburst stuck on at 1.14x
 * scale. The pulse moved to the animation engine's named-property ownership; the last check
 * here is that it stayed there, because moving it back would silently restore that bug.
 *
 * Usage:  node tools/minimaptest.js
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
  "MinimapButton.lua",
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
Valuate.GetOptions = function() return OPTIONS end
Valuate.ToggleUI = function() end

Minimap = CreateFrame("Frame")
function Minimap:GetCenter() return 100, 100 end
function Minimap:GetEffectiveScale() return 1 end
__cursor = { 140, 100 }
function GetCursorPosition() return __cursor[1], __cursor[2] end
GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:SetText() end
__tipLines = {}
function GameTooltip:AddLine(text) __tipLines[#__tipLines + 1] = tostring(text) end
function GameTooltip:AddDoubleLine() end
function GameTooltip:Show() end
function GameTooltip:Hide() end

Valuate:ShowMinimapButton()

local btn = nil
for _, f in ipairs(__frames) do
    if f.__scripts and f.__scripts.OnDragStart then btn = f end
end
ok(btn ~= nil, "the minimap button exists and accepts drags")

-- The mock has no real mouse, so the button is asked directly.
__over = false
btn.IsMouseOver = function() return __over end

local function dragging() return btn:GetScript("OnUpdate") ~= nil end
local function startDrag() btn.__scripts.OnDragStart(btn) end
local function stopDrag() btn.__scripts.OnDragStop(btn) end

-- ---- the ordinary drag ---------------------------------------------------------
eq(dragging(), false, "the button starts still")
startDrag()
eq(dragging(), true, "OnDragStart installs the cursor-follow")

-- One tick must move it, or the handler is installed and inert.
OPTIONS.minimapButtonAngle = nil
btn:GetScript("OnUpdate")(btn)
ok(OPTIONS.minimapButtonAngle ~= nil, "a tick of the drag records the new angle")

stopDrag()
eq(dragging(), false, "OnDragStop removes the cursor-follow")

-- ---- THE regression: hidden mid-drag -------------------------------------------
startDrag()
eq(dragging(), true, "armed again")
btn:Hide()
if btn.__scripts.OnHide then btn.__scripts.OnHide(btn) end
eq(dragging(), false, "hiding the button mid-drag ends the drag")

btn:Show()
eq(dragging(), false, "...so showing it again does not resume following the cursor")

-- ---- the resting text colour matches where the cursor is -----------------------
-- Releasing while still over the button used to hand back the un-hovered white, so the
-- button looked un-hovered with the mouse sitting on it until you moved away and back.
local function textColour()
    local c = btn.vText.__textColor
    return c and (c[1] .. "," .. c[2] .. "," .. c[3])
end

__over = true
startDrag()
stopDrag()
local hovered = textColour()
__over = false
startDrag()
stopDrag()
local away = textColour()
ok(hovered ~= away, "the colour after a drag depends on whether the cursor is still there")
eq(away, "1,1,1", "released away from the button, the text goes back to white")

-- And the hovered value is the same one OnEnter uses, rather than some third colour.
__over = true
btn.__scripts.OnEnter(btn)
eq(textColour(), hovered, "released under the cursor, it matches what hovering gives you")

-- ---- the drag must not own the animation slot ---------------------------------
-- The pulse and the drag once shared this frame's single OnUpdate, and the drag discarded
-- the pulse's cleanup - leaving a starburst stuck on at 1.14x scale. The pulse now lives on
-- the animation engine's named-property ownership; this is the check that it stayed there.
__over = false
btn:Show()
Valuate:PulseMinimapButton()
ok(btn.__anim_pulse ~= nil, "the pulse runs through the animation engine, not OnUpdate")
eq(dragging(), false, "...so pulsing does not look like a drag")

startDrag()
ok(btn.__anim_pulse ~= nil, "starting a drag does not cancel a running pulse")
stopDrag()
ok(btn.__anim_pulse ~= nil, "and ending one does not discard the pulse's cleanup")

-- ---- changed options actually reach the button --------------------------------
-- Position and visibility are read when the button is CREATED, and ShowMinimapButton /
-- HideMinimapButton WRITE the option rather than applying it - they are the user's action.
-- So anything that changes both options wholesale (loading a settings snapshot, restoring
-- defaults) moved the setting while the button stayed put, and they only agreed again
-- after a reload.
--
-- That the angle is a DECLARED option rather than one created on first drag is checked by
-- tools/options.js. Asserting it here would prove nothing: the drag handler above writes
-- the angle into this very table, so it is non-nil by the time this runs either way.
local function pos()
    local p = btn.__points[#btn.__points]
    if not p then return nil, nil end
    return math.floor(p[4] + 0.5), math.floor(p[5] + 0.5)
end

OPTIONS.minimapButtonHidden = false
OPTIONS.minimapButtonAngle = 0
Valuate:ApplyMinimapButtonOptions()
local px, py = pos()
eq(px, 80, "angle 0 puts the button out to the right of the minimap centre")
eq(py, 0, "...and level with it")

OPTIONS.minimapButtonAngle = 90
Valuate:ApplyMinimapButtonOptions()
px, py = pos()
eq(px, 0, "a changed angle moves the button")
eq(py, 80, "...to the new point on the ring")

OPTIONS.minimapButtonHidden = true
Valuate:ApplyMinimapButtonOptions()
eq(btn:IsShown(), false, "a snapshot that hides the button hides it now, not after a reload")

OPTIONS.minimapButtonHidden = false
Valuate:ApplyMinimapButtonOptions()
eq(btn:IsShown(), true, "and one that shows it takes effect just as immediately")

-- ---- the hover says what the scale IS -------------------------------------------------
-- The picker says it on hover, the list marks it, the editor repeats it and the login summary
-- raises it. This is the surface people actually look at - so a scale built on weights nobody
-- ever published belongs in that same glance.
local button
for _, f in ipairs(__frames) do
    if f.__scripts and f.__scripts.OnEnter and f.vText then button = f end
end
ok(button ~= nil, "the minimap button has a hover handler")

local function hoverWith(scale)
    Valuate.GetPrimaryScale = function() return scale, "Test" end
    __tipLines = {}
    if button then pcall(button.__scripts.OnEnter, button) end
    return table.concat(__tipLines, " | ")
end

local guessed = hoverWith({ DisplayName = "Guessy", Inferred = true, Color = "FFFFFF",
                            Values = { Agility = 1.0 } })
ok(guessed:find("guess", 1, true) ~= nil,
   "hovering with a guessed scale says so - this is the glance, not a panel you opened")

local solid = hoverWith({ DisplayName = "Solid", Color = "FFFFFF", Values = { Agility = 1.0 } })
eq(solid:find("guess", 1, true), nil,
   "and a researched scale says nothing of the sort - a caveat on everything is a caveat on nothing")

-- The handler is pcall'd because it runs on every pass of the mouse. That must not turn a
-- missing scale into a silent empty tooltip.
local none = hoverWith(nil)
ok(none:find("No active scale", 1, true) ~= nil,
   "with no scale at all it says so rather than hovering blank")

return failures, checks
`,
  "minimaptest",
  "the minimap button"
);
