#!/usr/bin/env node
/*
 * @gate A Conquest of Azeroth character is offered CoA classes in the template picker
 *
 * The other half of tools/pickertest.js, and the half that matches the bug a user actually
 * reported: "CoA templates are not available in selecting template".
 *
 * Separate file for the same reason wizardroles.js is separate from wizarduitest.js - the
 * picker builds its frame ONCE and reuses it, so a single harness can be a classic character
 * or a CoA one but never both. Resetting the file-local frame mid-run would be testing a
 * thing no player can do.
 *
 * This one is CoA from the first line.
 *
 * Usage:  node tools/pickercoa.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Pickers.lua",
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

-- A CoA character, from the start.
Valuate.GetTemplateSet = function() return ns.COA_CLASS_SPEC_TEMPLATES, "coa" end
Valuate.GetScales = function() return {} end
function UnitClass() return "Necromancer", "NECROMANCER" end

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end

local function drawnClasses()
    local seen = {}
    for _, f in ipairs(__frames) do
        for _, region in ipairs(f.__regions or {}) do
            local text = region.GetText and region:GetText()
            if text then seen[text] = true end
        end
        if f.label and f.label.GetText then
            local t = f.label:GetText()
            if t then seen[t] = true end
        end
    end
    return seen
end

ValuateUI_ShowFullTemplatePicker()
local seen = drawnClasses()

local missing = {}
local total = 0
for _, entry in ipairs(ns.COA_CLASS_SPEC_TEMPLATES) do
    total = total + 1
    if not seen[entry.class] then missing[#missing + 1] = entry.class end
end

eq(#missing, 0,
   "every CoA class is offered (missing: " .. table.concat(missing, ", ") .. ")")
ok(total >= 21, "and there are at least 21 of them, got " .. total)

-- Named individually, because "21 classes appeared" would also pass if the picker drew 21
-- copies of one class. These are three from different parts of the list.
ok(seen["Necromancer"] ~= nil, "Necromancer specifically")
ok(seen["Starcaller"] ~= nil, "Starcaller specifically")
ok(seen["Witch Hunter"] ~= nil, "Witch Hunter specifically")

-- The other direction of the same mistake: offering a Necromancer an Arms Warrior build.
ok(seen["Paladin"] == nil, "no classic class is offered to a CoA character")
ok(seen["Death Knight"] == nil, "nor Death Knight")

-- ---- the search, which is what makes 70 specs usable rather than merely present -
-- Seventy spec buttons across five columns cannot be read at a glance. The search box is
-- the difference between "the CoA templates are there" and "you can find yours".
-- By NAME, for the reason statsearchtest.js learned the hard way: "the EditBox with an
-- OnTextChanged handler" also matches other boxes, and a gate that types into the wrong one
-- passes while testing nothing.
local box
for _, f in ipairs(__frames) do
    if f.__name == "ValuateTemplateSearchBox" then box = f end
end
ok(box ~= nil, "the picker has a search box")

local function search(text)
    box:SetText(text)
    box.__scripts.OnTextChanged(box)
end

-- Spec buttons are the frames carrying a .template. Counting the LIT ones is how the filter
-- is observed, since it dims rather than hides.
local function litSpecs()
    local lit = 0
    for _, f in ipairs(__frames) do
        if f.template and f.GetAlpha and (f:GetAlpha() or 1) > 0.9 then lit = lit + 1 end
    end
    return lit
end

if box then
    local all = litSpecs()
    ok(all > 0, "spec buttons start visible, got " .. all)

    search("necroman")
    local narrowed = litSpecs()
    ok(narrowed < all, "searching a class name dims the rest (" .. narrowed .. " of " .. all .. ")")
    ok(narrowed > 0, "and leaves that class's specs lit")

    -- Nothing MOVES. Hiding non-matches would relayout five columns on every keystroke and
    -- every surviving button would jump somewhere new; dimming keeps the page still.
    local hidden = 0
    for _, f in ipairs(__frames) do
        if f.template and f.IsShown and not f:IsShown() then hidden = hidden + 1 end
    end
    eq(hidden, 0, "filtering dims in place rather than hiding and reflowing")

    search("")
    eq(litSpecs(), all, "clearing the search restores every spec")

    search("zzzznothing")
    eq(litSpecs(), 0, "a query matching nothing dims everything rather than erroring")
    search("")
end

-- ---- and it has to FIT on a screen -------------------------------------------
-- This frame does not scroll; it grows to whatever its contents need. Making 21 classes
-- reachable at three columns would have produced a window around 800px tall, which runs off
-- the bottom of a 768-high display - the fix for one bug quietly creating another.
--
-- The window is the widest frame here; nothing else in this harness builds anything close.
local window
for _, f in ipairs(__frames) do
    if f.GetWidth and (not window or f:GetWidth() > window:GetWidth()) then window = f end
end
ok(window ~= nil, "the picker window was built")

local h = window:GetHeight()
ok(h <= 700, "the window fits a 768-high screen with room for the taskbar, got " .. tostring(h))
ok(h > 100, "and it is not empty, got " .. tostring(h))

-- Wide rather than tall is the deliberate trade: a 16:9 screen has room sideways.
ok(window:GetWidth() > window:GetHeight() * 0.5,
   "21 classes spread across columns rather than stacking into one tall list")

return failures, checks
`,
  "pickercoa",
  "CoA classes in the template picker"
);
