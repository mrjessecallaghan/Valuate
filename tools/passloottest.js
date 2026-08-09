#!/usr/bin/env node
/*
 * @gate The PassLoot Upgrade rule does not fire on absent data
 *
 * Runs the REAL source of UpgradeVerdict from Valuate-PassLoot.
 *
 * A PassLoot rule matching means PassLoot performs whatever action you configured, and the
 * usual configuration is "if Upgrade then Need". So a false TRUE here is a Need roll on
 * something that is not an upgrade - the exact failure the core addon's auto-roll is built
 * to make impossible (v0.53.1a: "never Need on something we do not want").
 *
 * The distinction the checks below turn on is between two things that both look like "no
 * data" and are not the same at all:
 *
 *   * NEVER SCANNED - we do not know. On a fresh character this used to answer TRUE, so
 *     every Upgrade rule fired on everything. Uncertainty must decline.
 *   * SCANNED, NOTHING TRACKED FOR THIS SLOT - we do know: you own nothing better, so the
 *     item genuinely is an upgrade. That is knowledge, and it must answer TRUE.
 *
 * Conflating them is what made returning TRUE for both look reasonable.
 *
 * NOTE: the source is in a SIBLING addon with no git remote. This skips rather than fails
 * when it is absent - see tools/surplustest.js for the same argument.
 *
 * Usage:  node tools/passloottest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const SRC = path.resolve(ADDON_ROOT, "..", "Valuate-PassLoot", "Valuate.lua");
if (!fs.existsSync(SRC)) {
  console.log("SKIP  Valuate-PassLoot is not installed next to this addon; nothing to check.");
  process.exit(0);
}

const lua = fs.readFileSync(SRC, "utf8");
const m = lua.match(/^function module:UpgradeVerdict\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `function module:UpgradeVerdict` in Valuate-PassLoot/Valuate.lua - " +
      "it was renamed or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end

local module = {}

` + m[0] + `

local function verdict(...) return (module:UpgradeVerdict(...)) end

-- ---- never scanned: decline ------------------------------------------------------
-- The item might well be an upgrade. We have no way to know, and the cost of guessing wrong
-- is a Need roll in front of other people.
ok(verdict(false, false, nil, 100) == false,
   "no scan data at all: the rule does not match")
ok(verdict(true, false, nil, 100) == false,
   "scanned, but never for this scale: the rule does not match")

-- The item's own score cannot rescue it - a big number is not evidence when there is
-- nothing to compare it against.
ok(verdict(false, false, nil, 99999) == false,
   "a huge score does not make absent data into a match")

-- ---- scanned, nothing tracked for the slot: match --------------------------------
-- This is knowledge, not its absence: you own nothing better for that slot.
ok(verdict(true, true, nil, 100) == true,
   "nothing tracked for the slot means anything is an upgrade")
ok(verdict(true, true, nil, 0) == true,
   "...even a worthless item, because there is nothing to lose by taking it")

-- ---- the ordinary comparison -----------------------------------------------------
ok(verdict(true, true, 50, 100) == true, "a higher score than the baseline is an upgrade")
ok(verdict(true, true, 100, 50) == false, "a lower score is not")

-- Equal is NOT an upgrade. Rolling Need on a sidegrade is the same social cost as rolling
-- on something worse, and you already have one.
ok(verdict(true, true, 100, 100) == false, "an equal score is not an upgrade")

-- Negative baselines and scores are legitimate - a scale can carry negative weights - and
-- the comparison has to keep working across zero.
ok(verdict(true, true, -50, -10) == true, "-10 beats a baseline of -50")
ok(verdict(true, true, -10, -50) == false, "-50 does not beat -10")
ok(verdict(true, true, 0, 1) == true, "1 beats a baseline of zero")

-- ---- every answer explains itself -------------------------------------------------
-- The reason is what the debug log prints; a verdict nobody can account for is the thing
-- that made this worth separating out in the first place.
for _, case in ipairs({
    { false, false, nil, 1 },
    { true, false, nil, 1 },
    { true, true, nil, 1 },
    { true, true, 5, 9 },
    { true, true, 9, 5 },
}) do
    local _, reason = module:UpgradeVerdict(case[1], case[2], case[3], case[4])
    ok(type(reason) == "string" and #reason > 0, "every verdict comes with a reason")
end

return failures, checks
`,
  "passloottest",
  "the PassLoot Upgrade rule"
);
