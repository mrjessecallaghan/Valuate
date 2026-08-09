#!/usr/bin/env node
/*
 * @gate The TSM upgrade columns divide safely
 *
 * Runs the REAL source of UpgradePercent and ComputeRatio from Valuate-TSM.
 *
 * These produce the "upgrade" and "upgrade per gold" columns in TSM's shopping results, and
 * both are divisions in display code - the shape that has produced three real bugs in this
 * project already (a percentage divided by a signed baseline, a HUGE! with no sign, a
 * scrollbar range left at the unfiltered length). This one was written carefully and I found
 * nothing wrong with it; the point of the gate is that it stays that way, since the traps
 * here are all silent:
 *
 *   * dividing by a zero or negative baseline
 *   * an empty slot, where the honest answer is "infinite improvement" rather than a number
 *   * a zero buyout, where there is no price to divide by at all
 *   * the invert option, which swaps numerator and denominator and so has its own zero
 *
 * A wrong answer here sorts a shopping list, which means it decides what you buy.
 *
 * NOTE: the source is in a SIBLING addon. This skips rather than fails when it is absent -
 * see tools/surplustest.js for the argument.
 *
 * Usage:  node tools/tsmratiotest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const SRC = path.resolve(ADDON_ROOT, "..", "Valuate-TSM", "Score.lua");
if (!fs.existsSync(SRC)) {
  console.log("SKIP  Valuate-TSM is not installed next to this addon; nothing to check.");
  process.exit(0);
}

const lua = fs.readFileSync(SRC, "utf8");
function slice(header) {
  const re = new RegExp(
    "^" + header.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\(([\\s\\S]*?)\\r?\\nend\\r?\\n",
    "m"
  );
  const hit = lua.match(re);
  if (!hit) {
    console.error(
      `  SLICE  could not find \`${header}\` in Valuate-TSM/Score.lua - ` +
        "it was renamed or reshaped, so this gate is testing nothing"
    );
    process.exit(1);
  }
  return hit[0];
}

const SRCS = [slice("function ns.UpgradePercent"), slice("function ns.ComputeRatio")].join("\n");

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function near(got, want, what)
    checks = checks + 1
    if type(got) ~= "number" or math.abs(got - want) > 0.01 then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end

local OPTS = { goldUnit = 1, invert = false }
ns = { Opts = function() return OPTS end }

` + SRCS + `

-- ---- UpgradePercent ------------------------------------------------------------
ok(ns.UpgradePercent(nil) == nil, "no entry, no percentage")
ok(ns.UpgradePercent({}) == nil, "no delta, no percentage")
ok(ns.UpgradePercent({ delta = 0, baseline = 100 }) == nil, "a delta of zero is not an upgrade")
ok(ns.UpgradePercent({ delta = -5, baseline = 100 }) == nil, "a negative delta is not an upgrade")

near(ns.UpgradePercent({ delta = 50, baseline = 100 }), 50, "half again as good is 50%")
near(ns.UpgradePercent({ delta = 200, baseline = 100 }), 200, "three times as good is 200%")

-- THE case worth naming: an empty slot has no baseline to divide by. The honest answer is
-- not a very large number, it is "infinite" - and it must never be filtered out for being a
-- small upgrade, which is what a division by a tiny baseline would produce.
ok(ns.UpgradePercent({ delta = 10, baseline = 0 }) == math.huge,
   "an empty slot is an infinite improvement, not a division by zero")
ok(ns.UpgradePercent({ delta = 10 }) == math.huge, "a missing baseline is the same case")
ok(ns.UpgradePercent({ delta = 10, baseline = -5 }) == math.huge,
   "a negative baseline does not flip the sign of the percentage")

-- ---- ComputeRatio ---------------------------------------------------------------
OPTS.goldUnit, OPTS.invert = 1, false
ok(ns.ComputeRatio(nil, 10000) == nil, "no numerator, no ratio")
ok(ns.ComputeRatio(100, nil) == nil, "no price, no ratio")
ok(ns.ComputeRatio(100, 0) == nil, "a zero buyout is not a price to divide by")
ok(ns.ComputeRatio(100, -5) == nil, "...nor is a negative one")

-- 10000 copper is one gold, so 100 points over 1g is 100 per gold.
near(ns.ComputeRatio(100, 10000), 100, "100 points for one gold is 100 per gold")
near(ns.ComputeRatio(100, 20000), 50, "the same points for two gold is half as good")

-- goldUnit rescales the denominator: with a unit of 10, one gold is a tenth of a unit.
OPTS.goldUnit = 10
near(ns.ComputeRatio(100, 100000), 100, "a gold unit of 10 makes 10g the divisor")
OPTS.goldUnit = 1

-- Invert swaps the question to "gold per point", where LOWER is better.
OPTS.invert = true
near(ns.ComputeRatio(100, 10000), 0.01, "inverted, one gold for 100 points is 0.01 gold per point")
near(ns.ComputeRatio(1, 10000), 1, "...and one gold for one point is 1")
ok(ns.ComputeRatio(100, 0) == nil, "inverted still refuses a zero price")
OPTS.invert = false

-- A sub-copper price rounds to zero gold, and dividing by that would give infinity - which
-- would sort to the top of a shopping list as the best possible buy.
near(ns.ComputeRatio(100, 1), 1000000, "a one-copper price gives a huge but FINITE ratio")
local r = ns.ComputeRatio(100, 1)
ok(r ~= math.huge and r == r, "...never infinity, and never NaN")

-- The same, inverted: a tiny price must not become a division by zero either.
OPTS.invert = true
local ri = ns.ComputeRatio(100, 1)
ok(ri == nil or (ri ~= math.huge and ri == ri), "inverted, a one-copper price is finite or refused")
OPTS.invert = false

return failures, checks
`,
  "tsmratiotest",
  "the TSM upgrade columns"
);
