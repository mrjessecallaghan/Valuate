#!/usr/bin/env node
/*
 * @gate A generated scale names itself, and every stat has an abbreviation
 *
 * The wizard builds a scale and names it from what it weights: "Auto - Str/Crit/Hit/AP/Haste".
 * That name is the only summary of the scale most people will ever read, so it has to be
 * deterministic and it has to be complete.
 *
 * Deterministic is the harder half. The weights arrive in a table, pairs() order is undefined,
 * and equal weights are common - a caster template can easily weight four stats at 1.0. Without
 * a tiebreaker the same answers produce different names on different characters, and this
 * project has already shipped that bug once in the active-set tie (27397e7).
 *
 * Complete is the hand-maintained list, which is the ninth in this project: 51 stats in
 * ValuateStatCategories, 51 abbreviations, edited at different times. A stat added without one
 * falls back to its full name, and "Auto - Strength/CritRating/HitRating" is a name nobody
 * wants in a scale list.
 *
 * Usage:  node tools/autoname.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const stats = fs.readFileSync(path.join(ADDON_ROOT, "StatDefinitions.lua"), "utf8");

/* ---- the two lists have to agree, checked before anything is run ------------------ */

const categories = stats.match(/ValuateStatCategories = \{[\s\S]*?\n\}/);
const abbrevBlock = stats.match(/ValuateStatAbbreviations = \{[\s\S]*?\n\}/);
if (!categories || !abbrevBlock) {
  console.error("  SLICE  could not find the stat category or abbreviation table");
  process.exit(1);
}

const headers = new Set([...categories[0].matchAll(/header = "([^"]+)"/g)].map((m) => m[1]));
const declared = [...categories[0].matchAll(/"(\w+)"/g)]
  .map((m) => m[1])
  .filter((s) => !headers.has(s));
const abbreviated = new Set([...abbrevBlock[0].matchAll(/(\w+)\s*=\s*"/g)].map((m) => m[1]));

if (declared.length < 40) {
  console.error(
    `ERROR  only found ${declared.length} stats - ValuateStatCategories changed shape, so ` +
      "this gate would pass by seeing nothing"
  );
  process.exit(2);
}

const missing = [...new Set(declared)].filter((s) => !abbreviated.has(s)).sort();
if (missing.length) {
  console.error("Stats with no abbreviation in ValuateStatAbbreviations:");
  for (const s of missing) console.error(`  ${s}`);
  console.error(
    "\nA generated scale name falls back to the full stat name for these, which is how you " +
      'get "Auto - Strength/CritRating/HitRating". Add a short form.'
  );
  process.exit(1);
}

const orphans = [...abbreviated].filter((s) => !declared.includes(s)).sort();
if (orphans.length) {
  console.error(
    "Abbreviations for stats that do not exist: " + orphans.join(", ") +
      " - remove them, or the list reads as covering more than it does."
  );
  process.exit(1);
}

/* ---- and the naming itself, run for real ----------------------------------------- */

const nameFn = core.match(/^function Valuate:BuildAutoScaleName\(([\s\S]*?)\r?\nend\r?\n/m);
const uniqueFn = core.match(/^function Valuate:BuildUniqueAutoScaleName\(([\s\S]*?)\r?\nend\r?\n/m);
if (!nameFn || !uniqueFn) {
  console.error(
    "  SLICE  could not find BuildAutoScaleName / BuildUniqueAutoScaleName in Valuate.lua - " +
      "renamed, moved or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

const prefix = core.match(/local AUTO_NAME_PREFIX = "[^"]*"/);
const count = core.match(/local AUTO_NAME_COUNT = \d+/);
if (!prefix || !count) {
  console.error("  SLICE  could not find the AUTO_NAME_ constants");
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

` + abbrevBlock[0] + `
` + prefix[0] + `
` + count[0] + `
Valuate = {}
local scales = {}
function Valuate:GetScales() return scales end
` + nameFn[0] + `
` + uniqueFn[0] + `

local function name(w) return Valuate:BuildAutoScaleName(w) end

-- ---- the shape the feature promises -------------------------------------------
eq(name({ Strength = 1.0, CritRating = 0.8, HitRating = 0.75, AttackPower = 0.5, HasteRating = 0.4 }),
   "Auto - Str/Crit/Hit/AP/Haste",
   "five weighted stats give the documented name")

-- ---- only the top five, in weight order ----------------------------------------
eq(name({ Strength = 1.0, CritRating = 0.9, HitRating = 0.8, AttackPower = 0.7,
          HasteRating = 0.6, ExpertiseRating = 0.5, Stamina = 0.4 }),
   "Auto - Str/Crit/Hit/AP/Haste",
   "a sixth and seventh stat do not reach the name")

eq(name({ HasteRating = 0.1, Strength = 1.0, CritRating = 0.5 }),
   "Auto - Str/Crit/Haste",
   "the name is ordered by weight, not by the order the stats arrived in")

-- ---- fewer than five ------------------------------------------------------------
eq(name({ Intellect = 1.0, SpellPower = 0.9 }), "Auto - Int/SP",
   "two stats give a two-stat name rather than padding")
eq(name({}), "Auto - Empty", "no weights still yields a usable name")
eq(name(nil), "Auto - Empty", "and so does no table at all")

-- ---- what the scale does NOT chase does not describe it -------------------------
eq(name({ Strength = 1.0, Spirit = 0, Intellect = 0 }), "Auto - Str",
   "a zero weight is not part of the name")
eq(name({ Strength = 1.0, Spirit = -5 }), "Auto - Str",
   "and neither is a negative one")
eq(name({ Strength = 1.0, Agility = "lots" }), "Auto - Str",
   "a non-number weight is ignored rather than crashing the name")

-- ---- determinism, which is the whole reason the tiebreaker exists ----------------
-- Equal weights are ordinary: a caster template can weight four stats at 1.0. pairs()
-- order is undefined, so without a total order this returns different names on
-- different characters for identical input.
local tied = { CritRating = 1.0, HitRating = 1.0, HasteRating = 1.0, Intellect = 1.0 }
local first = name(tied)
local stable = true
for _ = 1, 25 do
    if name(tied) ~= first then stable = false end
end
ok(stable, "equal weights produce the SAME name every time")
eq(first, "Auto - Crit/Haste/Hit/Int",
   "ties break on the stat name, so the order is defined rather than merely stable")

-- A fresh table with the keys inserted in the opposite order must still agree: same
-- weights, same name, whatever pairs() feels like doing.
eq(name({ Intellect = 1.0, HasteRating = 1.0, HitRating = 1.0, CritRating = 1.0 }), first,
   "insertion order does not change the name")

-- ---- a stat with no abbreviation still names itself ------------------------------
eq(name({ SomeNewStat = 1.0 }), "Auto - SomeNewStat",
   "an unabbreviated stat falls back to its full name rather than vanishing")

-- ---- uniqueness, so running the wizard twice cannot overwrite --------------------
local weights = { Strength = 1.0, CritRating = 0.8 }
eq(Valuate:BuildUniqueAutoScaleName(weights), "Auto - Str/Crit",
   "the first build gets the plain name")

scales["Auto - Str/Crit"] = {}
eq(Valuate:BuildUniqueAutoScaleName(weights), "Auto - Str/Crit (2)",
   "a second identical build is suffixed rather than colliding")

scales["Auto - Str/Crit (2)"] = {}
scales["Auto - Str/Crit (3)"] = {}
eq(Valuate:BuildUniqueAutoScaleName(weights), "Auto - Str/Crit (4)",
   "the suffix skips names already taken instead of stopping at the first gap")

-- A scale of the same name on ANOTHER character must not affect this one: the caller
-- passes the table, so the wizard can be tested and reasoned about without globals.
eq(Valuate:BuildUniqueAutoScaleName(weights, {}), "Auto - Str/Crit",
   "an explicit empty scale table is respected over the character's own")

return failures, checks
`,
  "autoname",
  "generated scale names"
);
