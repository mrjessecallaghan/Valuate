#!/usr/bin/env node
/*
 * @gate A spec's tooltip says what it will chase, and admits when the numbers are a guess
 *
 * Fires the real OnEnter handler on a real spec button from ui/Pickers.lua, against a
 * tooltip that records what it was told rather than throwing it away.
 *
 * The tooltip used to repeat the two things already printed on the button - the name and the
 * role - which is the tooltip equivalent of saying nothing. Everything worth knowing before
 * committing to a template was sitting unread in the data.
 *
 * THE LAST CHECK IS THE POINT. Six of the 101 specs carry weights INFERRED from prose rather
 * than transcribed from a published stat priority, and they looked exactly like the other
 * ninety-five. Picking one got you a guess delivered with the confidence of a fact. That is
 * the failure this addon keeps having to apologise for, and it is invisible by construction:
 * a guessed weight renders identically to a researched one.
 *
 * The other checks are ordinary, but one is not: the stat list must be ORDERED. `pairs()`
 * order is undefined, so a tooltip built straight from the weights table can reshuffle its
 * own rows between two hovers of the same button - which reads as a bug in the addon rather
 * than a bug in the tooltip.
 *
 * Usage:  node tools/spectip.js
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

-- The CoA set, because it is the only one containing BOTH kinds of spec - inferred and
-- researched - and the picker frame is built once and cached, so a gate gets one set.
-- Classic reachability is tools/pickertest.js's job; the tooltip code is set-agnostic.
local SET = ns.COA_CLASS_SPEC_TEMPLATES
Valuate.GetTemplateSet = function() return SET, "coa" end
Valuate.GetScales = function() return {} end
function UnitClass() return "Son of Arugal", "SON OF ARUGAL" end

-- A tooltip that REMEMBERS. The shared harness stub swallows every line, which is why this
-- whole surface could be rewritten without a single gate noticing.
local LINES = {}
GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:ClearLines() LINES = {} end
function GameTooltip:SetText(text) LINES = { tostring(text) } end
function GameTooltip:AddLine(text) LINES[#LINES + 1] = tostring(text) end
function GameTooltip:AddDoubleLine(left, right)
    LINES[#LINES + 1] = tostring(left) .. "\\t" .. tostring(right)
end
function GameTooltip:Show() end
function GameTooltip:Hide() end

local function tipText() return table.concat(LINES, "\\n") end
local function tipHas(needle) return tipText():find(needle, 1, true) ~= nil end

-- Hover the button belonging to a named spec, by firing the handler the game would.
local function hover(specName)
    for _, f in ipairs(__frames) do
        if f.template and f.template.name == specName then
            local handler = f.GetScript and f:GetScript("OnEnter")
            if handler then
                LINES = {}
                handler(f)
                return true
            end
        end
    end
    return false
end

-- Pick the fixtures out of the DATA rather than naming them here. A gate that hardcodes
-- "Ferocity" starts testing nothing the day that spec is renamed or its weights are
-- published - and it would still pass, because the spec it looked for would simply be gone.
local inferredSpec, solidSpec, richSpec
for _, class in ipairs(SET) do
    for _, spec in ipairs(class.specs or {}) do
        if spec.inferred and not inferredSpec then inferredSpec = spec end
        if not spec.inferred and not solidSpec then solidSpec = spec end
        -- Something with more weights than the tooltip will show, so the overflow line
        -- has something to count.
        if not richSpec and type(spec.weights) == "table" then
            local n = 0
            for _ in pairs(spec.weights) do n = n + 1 end
            if n > 5 then richSpec = spec end
        end
    end
end
ok(inferredSpec ~= nil, "the set still contains an inferred spec to warn about")
ok(solidSpec ~= nil, "and one that is not, so the warning can be shown to discriminate")
ok(richSpec ~= nil, "and one weighting more stats than the tooltip lists")

ValuateUI_ShowFullTemplatePicker()

-- ---- an ordinary spec ---------------------------------------------------------
ok(hover(solidSpec.name), "the button for " .. solidSpec.name .. " exists and has a hover handler")
ok(tipHas(solidSpec.name), "the tooltip names the spec")

-- The description. Without it the tooltip only repeats what the button already says.
if type(solidSpec.description) == "string" and solidSpec.description ~= "" then
    ok(tipHas(solidSpec.description),
       "it carries the spec's own description, rather than repeating the button")
end

-- The stat priority IS the template. This is the claim a reader can check against what they
-- already believe, and the reason to trust or distrust the rest of it.
ok(tipHas("Values most"), "it heads the numbers with what they mean")
local heaviest, heaviestStat = 0, nil
for stat, w in pairs(solidSpec.weights) do
    if type(w) == "number" and w > heaviest then heaviest, heaviestStat = w, stat end
end
local shownName = (ValuateStatNames or {})[heaviestStat] or heaviestStat
ok(tipHas(shownName), "and names the stat this spec values most (" .. tostring(shownName) .. ")")
ok(tipHas(string.format("%.2f", heaviest)), "with the weight attached, not just the name")

-- ---- nothing is silently truncated --------------------------------------------
ok(hover(richSpec.name), "a spec with more than five weighted stats is on screen")
ok(tipHas("more"), "and the tooltip says how many it did not list, rather than stopping at five")

-- ---- ordering is not optional -------------------------------------------------
-- pairs() order is undefined. A tooltip built straight off the weights table reshuffles
-- between two hovers of the SAME button, which reads as the addon being broken.
hover(richSpec.name)
local first = tipText()
for _ = 1, 8 do
    hover(richSpec.name)
    if tipText() ~= first then break end
end
eq(tipText(), first, "hovering the same spec repeatedly says exactly the same thing every time")

-- And the order is by weight, descending: the first stat line must be the heaviest.
hover(richSpec.name)
local topValue
for line in tipText():gmatch("[^\\n]+") do
    local value = line:match("^%s%s.-\\t([%d%.]+)$")
    if value and not topValue then topValue = tonumber(value) end
end
ok(topValue ~= nil, "the stat lines are shaped so a reader can tell name from number")
local richest = 0
for _, w in pairs(richSpec.weights) do
    if type(w) == "number" and w > richest then richest = w end
end
eq(topValue, richest, "and the first listed is the heaviest, not whichever pairs() reached first")

-- ---- the guess has to announce itself -----------------------------------------
-- These specs have no published stat priority anywhere. Their weights were read off the
-- spec's own prose. Offered silently, they are indistinguishable from researched ones, and
-- that is the failure this whole gate exists for.
ok(hover(inferredSpec.name), "the inferred spec " .. inferredSpec.name .. " is on screen")
ok(tipHas("GUESS"), "and its tooltip says outright that the weights are a guess")
ok(tipHas("published"), "explaining that no stat priority was ever published for it")
ok(tipHas("starting point"), "and what to do about it, rather than only casting doubt")

ok(hover(solidSpec.name), "a spec with researched weights is on screen too")
eq(tipHas("GUESS"), false,
   "and its tooltip does NOT carry the warning - a caveat on everything is a caveat on nothing")

return failures, checks
`,
  "spectip",
  "spec tooltips say what they value and admit what they guessed"
);
