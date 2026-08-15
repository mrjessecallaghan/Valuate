#!/usr/bin/env node
/*
 * @gate The UI checker finds a frame drawn outside its parent, and stays quiet when nothing is
 *
 * Runs ui/UICheck.lua against a mocked WoW API with FABRICATED geometry.
 *
 * What this gate does NOT do is check the UI. It cannot: the harness has no font metrics and
 * does no layout, which is the entire reason /valuate uicheck exists. GetTop and GetBottom
 * return resolved screen coordinates and the harness has nothing to resolve them against.
 *
 * What it checks is the CHECKER - that when something is drawn outside its parent the report
 * says so and names it, and that when nothing is, the report is silent. A diagnostic that
 * cannot fail is worse than none, because a clean run from it would be read as evidence.
 *
 * The rectangles below are made up. They are the shape of the v0.158.0a defect - a row whose
 * text wrapped past the bottom edge of the row - written as coordinates, so the logic that
 * would have caught it can be proven here even though the measurement cannot.
 *
 * Usage:  node tools/uicheck.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load(["ui/Shared.lua", "ui/UICheck.lua"]);

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

-- Fabricated geometry. The harness does no layout, so these are set by hand - which is the
-- honest version of what this gate can claim: the arithmetic and the reporting are tested,
-- the measuring is not, because there is nothing here to measure.
local function place(f, top, bottom, left, right)
    f.GetTop = function() return top end
    f.GetBottom = function() return bottom end
    f.GetLeft = function() return left end
    f.GetRight = function() return right end
    return f
end

UIParent = CreateFrame("Frame")
place(UIParent, 768, 0, 0, 1024)

local function newWindow()
    local root = CreateFrame("Frame", "ValuateUIFrame")
    place(root, 700, 100, 100, 900)
    root:Show()
    ns.ValuateUIFrame = root
    return root
end

-- ---- a clean window reports clean -------------------------------------------------------
-- The direction that matters most. If this file only proved the checker can complain, a
-- checker that complained about everything would pass it.
local root = newWindow()
local panel = CreateFrame("Frame", nil, root)
place(panel, 690, 110, 110, 890)
panel:Show()
local label = panel:CreateFontString(nil, "OVERLAY")
label:SetText("A line that fits")
place(label, 680, 660, 120, 400)
label:Show()

local problems, examined = ns.RunUICheck()
eq(problems, 0, "a window whose contents all fit reports nothing")
ok(examined > 0, "and says how much it looked at (" .. tostring(examined) .. ")")

-- ---- text spilling out of the bottom of its row -----------------------------------------
-- This is v0.158.0a exactly: a fixed-height row, and a detail that wrapped to three lines.
-- Every headless gate passed. It was visible the moment anyone opened the tab.
root = newWindow()
local row = CreateFrame("Frame", nil, root)
place(row, 600, 560, 110, 890)      -- a 40px row
row:Show()
local detail = row:CreateFontString(nil, "OVERLAY")
detail:SetText("No stat priority was ever published for that spec, so they were read off it")
place(detail, 596, 520, 120, 880)   -- wraps 40px past the bottom
detail:Show()

problems = ns.RunUICheck()
ok(problems >= 1, "text drawn below its own row is reported")

-- ---- and it names the thing ---------------------------------------------------------------
-- "1 problem found" is not actionable in a window with several hundred frames. The text of
-- the offending string is the fastest way to find it, so the report carries it.
__printed = {}
ns.RunUICheck()
local said = table.concat(__printed, " ")
ok(said:find("spills", 1, true) ~= nil, "the report says what went wrong")
ok(said:find("below", 1, true) ~= nil, "and in which direction")
ok(said:find("No stat priority", 1, true) ~= nil, "and quotes the text, so it can be found")

-- ---- the other three directions ------------------------------------------------------------
for _, case in ipairs({
    { name = "above", t = 700, b = 580 },
    { name = "left of", l = 90, r = 800 },
    { name = "right of", l = 120, r = 990 },
}) do
    root = newWindow()
    local box = CreateFrame("Frame", nil, root)
    place(box, 600, 560, 110, 890)
    box:Show()
    local fs = box:CreateFontString(nil, "OVERLAY")
    fs:SetText("out")
    place(fs, case.t or 590, case.b or 570, case.l or 120, case.r or 880)
    fs:Show()
    __printed = {}
    ns.RunUICheck()
    ok(table.concat(__printed, " "):find(case.name, 1, true) ~= nil,
       "a region past the " .. case.name .. " edge is reported")
end

-- ---- hidden things have no position, and that is not a defect ------------------------------
-- Pooled rows sit hidden with stale coordinates. Treating "no position" as a failure would
-- make every panel in the addon report dozens of problems it does not have.
--
-- The HIDDEN thing is the child, inside a SHOWN parent - which is the real shape of a frame
-- pool. Written the other way round first, with the parent hidden too, and the case passed
-- whether the child was checked or not: the parent's own guard was doing all the work, so
-- the assertion proved nothing about the one it was written for.
root = newWindow()
local list = CreateFrame("Frame", nil, root)
place(list, 600, 560, 110, 890)
list:Show()
local hiddenRow = CreateFrame("Frame", nil, list)
place(hiddenRow, 400, 300, 120, 880)   -- stale coordinates, far outside the list
hiddenRow:Hide()
eq(ns.RunUICheck(), 0, "a hidden row is not measured, however wrong its old coordinates are")

-- ---- an unresolved position is silence, not a failure ---------------------------------------
root = newWindow()
local floating = CreateFrame("Frame", nil, root)
floating:Show()
floating.GetTop = function() return nil end
eq(ns.RunUICheck(), 0, "a frame the client cannot place yet is skipped rather than blamed")

-- ---- exactly one tab is marked ---------------------------------------------------------------
root = newWindow()
local function tab(lit)
    local b = CreateFrame("Button", nil, root)
    place(b, 120, 100, 200, 300)
    b:Show()
    b.accent = b:CreateTexture(nil, "OVERLAY")
    place(b.accent, 120, 118, 202, 298)
    if lit then b.accent:Show() else b.accent:Hide() end
    return b
end
root.tabs = { buttons = { a = tab(true), b = tab(false), c = tab(false) } }
eq(ns.RunUICheck(), 0, "one tab marked out of three is correct")

root.tabs = { buttons = { a = tab(true), b = tab(true), c = tab(false) } }
__printed = {}
ns.RunUICheck()
ok(table.concat(__printed, " "):find("at once", 1, true) ~= nil,
   "two tabs marked at once is reported - a bar on every tab marks nothing")

root.tabs = { buttons = { a = tab(false), b = tab(false) } }
__printed = {}
ns.RunUICheck()
ok(table.concat(__printed, " "):find("none of the", 1, true) ~= nil,
   "no tab marked at all is reported - which is what four of six did until v0.156.0a")

return failures, checks
`,
  "uicheck",
  "the in-client UI checker"
);
