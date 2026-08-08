#!/usr/bin/env node
/*
 * @gate The tooltip comparison never contradicts itself
 *
 * Runs the REAL source of FormatPercentageComparison from Valuate.lua.
 *
 * This builds the "(+12.4, +8.3%)" text on every item tooltip, which makes it the most-read
 * string the addon produces. It divided the difference by the equipped score directly, so a
 * NEGATIVE equipped score flipped the sign of the percentage: going from -10 to -5 is an
 * improvement, and it reported -50%. The caller picks its "+" and its green from `diff`,
 * which had already been decided, so the tooltip rendered "+-50.0%" in green.
 *
 * Negative scores are not hypothetical - the weight box deliberately preserves a leading
 * minus, so a scale can penalise a stat. And the addon already knew the answer:
 * CalculateStatBreakdownWithComparison divides by math.abs for the per-stat lines. It was
 * the same computation, in the same tooltip, disagreeing with itself.
 *
 * The invariant worth pinning is not the arithmetic but the CONSISTENCY: the sign of the
 * percentage must match the sign of the difference, always. That is what makes the sign the
 * caller prints and the colour it chooses agree with the number underneath.
 *
 * Usage:  node tools/tooltiptest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^local function FormatPercentageComparison\(([\s\S]*?)\nend\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `local function FormatPercentageComparison` in Valuate.lua - " +
      "it was renamed, moved or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function has(text, needle, what)
    checks = checks + 1
    if not string.find(text, needle, 1, true) then
        table.insert(failures, what .. " (got " .. tostring(text) .. ", wanted it to contain " .. needle .. ")")
    end
end
local function hasnt(text, needle, what)
    checks = checks + 1
    if string.find(text, needle, 1, true) then
        table.insert(failures, what .. " (got " .. tostring(text) .. ", which must NOT contain " .. needle .. ")")
    end
end

` + m[0] + `

local FMT = "%.1f"

-- ---- nothing equipped, and a zero baseline --------------------------------
has(FormatPercentageComparison(12, nil, FMT, "percent"), "new",
    "no equipped score reads as new")
has(FormatPercentageComparison(12, 0, FMT, "percent"), "12.0",
    "a zero baseline falls back to the raw number, since no percentage exists")

-- ---- the ordinary case ------------------------------------------------------
local up = FormatPercentageComparison(5, 10, FMT, "percent")
has(up, "+50.0%", "an improvement over a positive score reads +50%")
has(up, "00FF00", "...in green")

local down = FormatPercentageComparison(-3, 10, FMT, "percent")
has(down, "-30.0%", "a downgrade reads -30%")
has(down, "FF0000", "...in red")

-- ---- THE regression: a negative baseline ------------------------------------
-- -10 to -5 is an improvement of 5. The percentage must be POSITIVE, because the caller
-- has already chosen "+" and green from the difference.
local negUp = FormatPercentageComparison(5, -10, FMT, "percent")
has(negUp, "50.0%", "an improvement over a negative score still reports 50%")
hasnt(negUp, "-50.0", "...and NOT a negative percentage the green + would contradict")

-- Getting worse from a negative baseline must read negative.
local negDown = FormatPercentageComparison(-5, -10, FMT, "percent")
has(negDown, "-50.0%", "a further loss from a negative score reads -50%")

-- "both" mode prints the number and the percent side by side, so a sign flip is visible
-- twice in one string. This is where "+-50.0%" actually appeared.
local both = FormatPercentageComparison(5, -10, FMT, "both")
has(both, "+5.0", "both mode shows the raw difference")
hasnt(both, "+-", "both mode never emits a doubled sign")

-- ---- the property, stated once ---------------------------------------------
-- The sign of the percentage matches the sign of the difference for EVERY baseline.
-- One loop is worth more than the cases above: it is the actual invariant, and it holds
-- for baselines the arithmetic makes awkward rather than just the ones I thought of.
-- This holds for the HUGE! path too, which is why it is worth stating as one rule: a
-- percentage too large to print still has a direction, and that direction is the only
-- thing the reader needs. It did NOT hold before - "(HUGE!)" for a catastrophic downgrade
-- carried no sign at all, because diffSign is empty for losses on the convention that the
-- number carries its own minus, and that branch prints no number.
local baselines = { -100, -10, -1, -0.5, 0.5, 1, 10, 100 }
local diffs = { -20, -1, 1, 20 }
for _, base in ipairs(baselines) do
    for _, d in ipairs(diffs) do
        for _, mode in ipairs({ "percent", "both", "number" }) do
            local text = FormatPercentageComparison(d, base, FMT, mode)
            local where = "diff " .. d .. " over baseline " .. base .. " (" .. mode .. "): " .. text
            local negative = string.find(text, "(-", 1, true) ~= nil
            ok(negative == (d < 0), "sign follows the difference for " .. where)
            hasnt(text, "+-", "no doubled sign for " .. where)
            -- The colour must agree with the sign, or the two cues fight each other.
            ok(string.find(text, d < 0 and "FF0000" or "00FF00", 1, true) ~= nil,
               "colour agrees with the sign for " .. where)
        end
    end
end

-- ---- extreme values ---------------------------------------------------------
has(FormatPercentageComparison(500, 10, FMT, "percent"), "+HUGE",
    "a 5000% gain is reported as HUGE rather than a wall of digits")
has(FormatPercentageComparison(500, -10, FMT, "percent"), "+HUGE",
    "...and the magnitude check works off a negative baseline too")
has(FormatPercentageComparison(-500, 10, FMT, "percent"), "-HUGE",
    "a catastrophic downgrade says so, instead of reading as good news")
has(FormatPercentageComparison(-500, 10, FMT, "both"), "-HUGE",
    "...in both mode as well")

return failures, checks
`,
  "tooltiptest",
  "the tooltip comparison text"
);
