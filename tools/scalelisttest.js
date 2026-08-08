#!/usr/bin/env node
/*
 * @gate Pooled scale rows act on the scale they currently show
 *
 * Runs ui/ScaleList.lua for real and repopulates its row pool with different lists.
 *
 * The panel used to rebuild its rows on every change and orphan the old ones - WoW never
 * frees a frame, so that leaked about five per scale per edit, permanently. Pooling was
 * written down as a known fix and deliberately NOT attempted for several releases, on the
 * grounds that the failure mode is a row whose handlers still refer to the scale that
 * used to occupy it - and one of those handlers deletes a scale, with no undo.
 *
 * That risk is the whole reason this file exists. Every test below repopulates the pool
 * with a DIFFERENT and SHORTER list, then fires the handlers and checks which scale they
 * reached. A row that captured its scale at build time passes a test that only ever
 * populates once; it fails here.
 *
 * Usage:  node tools/scalelisttest.js
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

-- ---- the world -------------------------------------------------------------
local SCALES = {}
local primary = nil
local confirmPrompt = nil

Valuate.GetScales = function() return SCALES end
Valuate.GetPrimaryScale = function() return SCALES[primary], primary end
Valuate.ResetTooltips = function() end
Valuate.ClearBestEquipmentForScale = function() end
Valuate.ShowConfirmDialog = function(self, opts) confirmPrompt = opts end
function ValuateUI_UpdateScaleEditor(name, scale) __lastEditorName = name end

__shift = false
function IsShiftKeyDown() return __shift end

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end
ColorPickerFrame = CreateFrame("Frame")
function ColorPickerFrame:GetColorRGB() return 0, 0, 0 end
function ColorPickerFrame:SetColorRGB() end

local function setScales(list)
    SCALES = {}
    for _, name in ipairs(list) do
        SCALES[name] = { DisplayName = name, Color = "FFFFFF", Visible = true }
    end
end

local parent = CreateFrame("Frame")
ns.CreateScaleList(parent)

local function rowsShowing()
    local names = {}
    for i = 1, 20 do
        local r = ns.ScaleListButtons[i]
        if not r then break end
        names[#names + 1] = tostring(r.scaleName)
    end
    return table.concat(names, ",")
end

-- ---- populate, then repopulate with a different list ------------------------
setScales({ "Alpha", "Bravo", "Charlie" })
ns.UpdateScaleList()
eq(rowsShowing(), "Alpha,Bravo,Charlie", "three scales, sorted by display name")

local framesAfterFirst = #__frames

-- Ten more updates must not create a single frame. This is the leak the pool exists to
-- close; without it each pass builds a row's worth of frames and orphans the last set.
for _ = 1, 10 do ns.UpdateScaleList() end
eq(#__frames, framesAfterFirst, "repeated updates create no new frames")

-- Growing past the high-water mark builds rows; shrinking never does.
setScales({ "Alpha", "Bravo", "Charlie", "Delta" })
ns.UpdateScaleList()
ok(#__frames > framesAfterFirst, "a fourth scale builds a fourth row")
local framesAtFour = #__frames
setScales({ "Alpha" })
ns.UpdateScaleList()
eq(#__frames, framesAtFour, "shrinking builds nothing")
setScales({ "Alpha", "Bravo", "Charlie", "Delta" })
ns.UpdateScaleList()
eq(#__frames, framesAtFour, "growing back to the high-water mark reuses the parked rows")

-- ---- THE risk: delete acts on the scale the row shows NOW -------------------
-- Bravo is removed, so the row that used to be Bravo now shows Charlie. Clicking its
-- delete button must delete Charlie. A handler that captured "Bravo" at build time
-- deletes a scale the user is not looking at.
setScales({ "Alpha", "Bravo", "Charlie", "Delta" })
ns.UpdateScaleList()
setScales({ "Alpha", "Charlie", "Delta" })
ns.UpdateScaleList()
eq(rowsShowing(), "Alpha,Charlie,Delta", "rows shifted up after a deletion")

local row2 = ns.ScaleListButtons[2]
eq(row2.scaleName, "Charlie", "row 2 now shows Charlie")

__shift = true
row2.deleteBtn:GetScript("OnClick")(row2.deleteBtn)
__shift = false
ok(SCALES.Charlie == nil, "shift-delete on row 2 removed Charlie")
ok(SCALES.Bravo == nil and SCALES.Alpha ~= nil and SCALES.Delta ~= nil,
   "...and nothing else was touched")

-- The confirmation dialog must name the same scale it will delete. Naming the previous
-- occupant would be worse than a silent bug: it invites you to confirm the wrong thing.
setScales({ "Alpha", "Bravo", "Charlie" })
ns.UpdateScaleList()
setScales({ "Alpha", "Charlie" })
ns.UpdateScaleList()
confirmPrompt = nil
local r2 = ns.ScaleListButtons[2]
r2.deleteBtn:GetScript("OnClick")(r2.deleteBtn)
ok(confirmPrompt ~= nil, "a plain click asks for confirmation")
ok(confirmPrompt and string.find(confirmPrompt.text, "Charlie", 1, true) ~= nil,
   "the prompt names Charlie, the scale actually on that row")
confirmPrompt.onAccept()
ok(SCALES.Charlie == nil, "accepting deletes Charlie")

-- ---- the lookup ScaleEditor uses -------------------------------------------
-- ui/ScaleEditor.lua selects a scale by calling ns.ScaleListButtons[name]'s OnClick
-- directly, so a stale key there drives the editor to the wrong scale.
setScales({ "Alpha", "Bravo", "Charlie" })
ns.UpdateScaleList()
setScales({ "Alpha", "Charlie" })
ns.UpdateScaleList()
ok(ns.ScaleListButtons["Bravo"] == nil, "the deleted scale leaves no entry behind")
ok(ns.ScaleListButtons["Charlie"] ~= nil, "the surviving scale is still reachable by name")
eq(ns.ScaleListButtons["Charlie"].scaleName, "Charlie", "and that entry shows Charlie")
eq(ns.ScaleListButtons[3], nil, "the array part shrinks with the list")

__lastEditorName = nil
local byName = ns.ScaleListButtons["Charlie"]
byName:GetScript("OnClick")(byName)
eq(__lastEditorName, "Charlie", "selecting by name opens Charlie in the editor")
eq(ns.CurrentSelectedScale, "Charlie", "and marks it selected")

-- ---- a parked row is inert --------------------------------------------------
-- Rows past the end of the list keep their handlers - nothing can remove them - so the
-- release path clears the identity instead. Firing one must do nothing at all.
setScales({ "Alpha", "Bravo" })
ns.UpdateScaleList()
local wasBravoRow = ns.ScaleListButtons[2]
setScales({ "Alpha" })
ns.UpdateScaleList()
eq(wasBravoRow.scaleName, nil, "a parked row forgets its scale")
eq(wasBravoRow:IsShown(), false, "a parked row is hidden")
local before = 0
for _ in pairs(SCALES) do before = before + 1 end
wasBravoRow.deleteBtn:GetScript("OnClick")(wasBravoRow.deleteBtn)
local after = 0
for _ in pairs(SCALES) do after = after + 1 end
eq(after, before, "clicking a parked row's delete button deletes nothing")

-- ---- visibility follows the row too ----------------------------------------
setScales({ "Alpha", "Bravo", "Charlie" })
ns.UpdateScaleList()
setScales({ "Alpha", "Charlie" })
ns.UpdateScaleList()
local vrow = ns.ScaleListButtons[2]
vrow.visCheckbox:SetChecked(false)
vrow.visCheckbox:GetScript("OnClick")(vrow.visCheckbox)
eq(SCALES.Charlie.Visible, false, "unticking row 2 hides Charlie, not the previous occupant")
eq(SCALES.Alpha.Visible, true, "...and leaves Alpha alone")

-- ---- the colour picker does not answer someone else's cancel -----------------
--
-- ColorPickerFrame is Blizzard's and shared with every other addon. Valuate installs func
-- and cancelFunc on it and nothing removes them, so they outlive our use. Most addons set
-- func before showing it, which displaces ours - but plenty set only func and leave
-- cancelFunc alone, and then OUR cancelFunc answers THEIR cancel and writes a Valuate
-- scale's colour back to whatever previousValues we left behind.
--
-- Clearing the fields on hide would be the obvious fix and the wrong one: 3.3.5's cancel
-- button hides the frame before calling cancelFunc. So the guard is ownership instead -
-- act only while our func is still installed - which needs no cleanup and does not care
-- what order Blizzard hides and cancels in.
setScales({ "Alpha", "Bravo" })
ns.UpdateScaleList()
SCALES.Alpha.Color = "FF0000"

local crow = ns.ScaleListButtons[1]
crow.colorBtn:GetScript("OnClick")(crow.colorBtn)
ok(type(ColorPickerFrame.func) == "function", "opening the picker installs our handler")
ok(type(ColorPickerFrame.cancelFunc) == "function", "...and a cancel handler")

local ourFunc = ColorPickerFrame.func
local ourCancel = ColorPickerFrame.cancelFunc

-- Our own cancel still works: it restores the colour we opened with.
SCALES.Alpha.Color = "00FF00"
ourCancel()
eq(SCALES.Alpha.Color, "FF0000", "our own cancel restores the colour we opened with")

-- Now another addon opens the picker: it sets func and leaves cancelFunc alone, which is
-- the common shape. Our stale cancelFunc must decline to act.
SCALES.Alpha.Color = "0000FF"
ColorPickerFrame.func = function() end
ourCancel()
eq(SCALES.Alpha.Color, "0000FF", "a cancel belonging to another addon does not touch our scale")

-- ---- the primary marker moves ----------------------------------------------
setScales({ "Alpha", "Bravo" })
primary = "Alpha"
ns.UpdateScaleList()
eq(ns.ScaleListButtons[1].primaryMark:IsShown(), true, "the current spec is starred")
eq(ns.ScaleListButtons[2].primaryMark:IsShown(), false, "other scales are not")
primary = "Bravo"
ns.UpdateScaleList()
eq(ns.ScaleListButtons[1].primaryMark:IsShown(), false, "the star leaves the old primary")
eq(ns.ScaleListButtons[2].primaryMark:IsShown(), true, "and lands on the new one")

-- ---- renaming reorders --------------------------------------------------------
-- Rows are sorted by DISPLAY name, so an edit can move a scale to a different row. The
-- row it lands on must adopt it completely.
setScales({ "Alpha", "Bravo" })
SCALES.Bravo.DisplayName = "Aardvark"
ns.UpdateScaleList()
eq(rowsShowing(), "Bravo,Alpha", "a rename reorders the rows")
eq(ns.ScaleListButtons[1].nameLabel:GetText(), "Aardvark", "row 1 shows the new display name")
__lastEditorName = nil
local top = ns.ScaleListButtons[1]
top:GetScript("OnClick")(top)
eq(__lastEditorName, "Bravo", "clicking row 1 opens the scale that moved there")

return failures, checks
`,
  "scalelisttest",
  "the pooled scale list"
);
