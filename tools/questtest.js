#!/usr/bin/env node
/*
 * @gate Quest reward choice prefers upgrades, and declines to guess
 *
 * Runs the REAL source of ChooseQuestReward from Valuate.lua.
 *
 * A quest reward is IRREVERSIBLE. The moment one is taken the others are gone, and with auto
 * turn-in enabled this decision runs without asking. That puts it in the same category as
 * the deletion protections rather than with the display code, and the safety rule is the
 * same shape: when the action cannot be undone, uncertainty declines to act.
 *
 * Three claims, in order of how much they matter:
 *
 *   1. Nothing scored and more than one choice -> pick NOTHING. Leave it to the player.
 *   2. A real upgrade beats a bigger raw score. A strong weapon you will never beat your
 *      current best with should lose to a modest trinket that fills an empty slot - that is
 *      the entire reason this is not just "highest number wins".
 *   3. Ties go to the lowest index. An irreversible choice must not depend on the order a
 *      table happened to be built in.
 *
 * Usage:  node tools/questtest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^local function ChooseQuestReward\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `local function ChooseQuestReward` in Valuate.lua - " +
      "it was renamed, moved or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

const run = load([]);

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

` + m[0] + `

local function c(index, score, delta) return { index = index, score = score, delta = delta } end

-- ---- THE safety rule: do not guess ---------------------------------------------
-- All rewards are bags or consumables, so nothing scored. With a real choice to make and no
-- basis for making it, the addon must take nothing - the player still has the quest window
-- open and can decide for themselves.
eq(ChooseQuestReward({}, 3), nil, "nothing scored and three choices: picks nothing")
eq(ChooseQuestReward({}, 2), nil, "nothing scored and two choices: picks nothing")
eq(ChooseQuestReward(nil, 2), nil, "a nil list is the same as an empty one")

-- One choice is not a choice, so pre-selecting it costs nothing.
eq(ChooseQuestReward({}, 1), 1, "nothing scored but only one reward: that one is safe to take")

-- ---- upgrades beat raw scores ----------------------------------------------------
-- Reward 1 scores far higher but is worse than what you already wear. Reward 2 scores less
-- but actually improves a slot. The point of the feature is that 2 wins.
eq(ChooseQuestReward({ c(1, 500, -50), c(2, 100, 30) }, 2), 2,
   "a modest reward that upgrades beats a strong one that does not")

eq(ChooseQuestReward({ c(1, 500, 10), c(2, 100, 30) }, 2), 2,
   "between two upgrades, the BIGGER upgrade wins even with a lower raw score")

-- ---- no upgrades: fall back to the best item ------------------------------------
eq(ChooseQuestReward({ c(1, 100, -5), c(2, 300, -2), c(3, 50, -80) }, 3), 2,
   "when nothing is an upgrade, take the highest-scoring reward")

-- A delta of exactly zero is not an upgrade: it is the same as what you have, so there is
-- nothing to prefer it for.
eq(ChooseQuestReward({ c(1, 100, 0), c(2, 300, 0) }, 2), 2,
   "a delta of exactly zero is not an upgrade, so raw score decides")

-- ---- determinism -----------------------------------------------------------------
-- Ties must resolve the same way every time. This runs unattended on an irreversible
-- action; "usually picks the same one" is not good enough.
for run = 1, 6 do
    eq(ChooseQuestReward({ c(1, 200, 5), c(2, 200, 5), c(3, 200, 5) }, 3), 1,
       "identical rewards always resolve to the lowest index (run " .. run .. ")")
end
eq(ChooseQuestReward({ c(3, 200, 5), c(1, 200, 5), c(2, 200, 5) }, 3), 3,
   "...and 'lowest' means first in the list it was handed, whatever order that is")

-- ---- single scored choice among several ------------------------------------------
-- Two rewards, only one of which Valuate can score. Taking the scored one is right: the
-- other is a bag or a consumable, which this addon has no opinion about.
eq(ChooseQuestReward({ c(2, 80, -10) }, 2), 2,
   "one scoreable reward among several: take it even though it is not an upgrade")

-- ---- negative everything ----------------------------------------------------------
-- Every reward is worse than what you wear. Something still has to be chosen - the quest
-- gives you one regardless - so it takes the least bad.
eq(ChooseQuestReward({ c(1, 10, -100), c(2, 40, -70), c(3, 5, -200) }, 3), 2,
   "when every reward is a downgrade, take the least bad one")

return failures, checks
`,
  "questtest",
  "the quest reward choice"
);
