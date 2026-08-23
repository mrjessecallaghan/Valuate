#!/usr/bin/env node
/*
 * @gate The enhancement you are told to buy is scored for YOUR role, and admits its guesses
 *
 * Runs the real ns.EFFECT_VALUES, ns.RoleForScale and ns.ScoreEnhancement from ui/Enhance.lua.
 *
 * This is the function that decides which enchant the Enhance tab puts at the top of a slot.
 * It had no gate of its own. It ran transitively through RankForSlot, so it was *executed* -
 * but nothing anywhere asserted what it returned, and being executed is not being checked.
 *
 * Two things it can get wrong, and they fail in opposite directions.
 *
 * THE WRONG COLUMN. EFFECT_VALUES carries a number per role - dps, tank, healer - and the
 * column is chosen from the scale. Read the wrong one and a healer is recommended a melee
 * damage proc worth exactly nothing to them, with a confident number beside it. Nothing errors;
 * you just buy the wrong enchant. So the assertions here compare roles against each other
 * rather than against constants: an effect the table scores 45/25/0 must actually come out
 * highest for dps and zero for a healer, or the column is not being read at all.
 *
 * A SHORT ROW. `score + effect[column]` is an addition, so a row added later without all three
 * numbers makes `score + nil` - a hard error, for one role only. A dps player would never see
 * it and a healer could not use the tab at all. The table is well-formed today; this gate is
 * here so that stays true when somebody adds a row and stops at the two columns they cared
 * about.
 *
 * And one thing it must not get wrong in a quieter way: `estimated`. Part of this score comes
 * from a hand-written opinion about how much movement speed is worth. The panel admits that on
 * the row, and the admission is only as good as this flag. A score that is partly judgement,
 * presented as measurement, is the failure this whole project is most careful about.
 *
 * Usage:  node tools/enhancescore.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const src = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Enhance.lua"), "utf8");

const PIECES = [
  /^ns\.EFFECT_VALUES = \{[\s\S]*?\r?\n\}/m,
  /^function ns\.RoleForScale\([\s\S]*?\r?\nend/m,
  /^function ns\.ScoreEnhancement\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = src.match(re);
  if (!m) {
    console.error(
      "  SLICE  could not find " + re + " in ui/Enhance.lua - this gate is testing nothing"
    );
    process.exit(1);
  }
  return m[0];
});

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

ns = {}
Valuate = {}

-- Stat weights are somebody else's job and are gated elsewhere. Zero here so that every number
-- below comes from the judgement table alone - otherwise a column bug could hide behind a
-- stat score that happened to move the total the same way.
Valuate.CalculateItemScore = function() return 0 end

` + sliced.join("\n") + `

local DPS    = { Values = { AttackPower = 10, Agility = 8, Crit = 4 } }
local TANK   = { Values = { AttackPower = 4, Dodge = 6, Defense = 6, Armor = 5 } }
local HEALER = { Values = { SpellPower = 6, Healing = 8, Mp5 = 6, Spirit = 5 } }

-- ---- the role actually comes out of the scale --------------------------------------------
eq(ns.RoleForScale(DPS), "dps", "an offensive scale is a dps scale")
eq(ns.RoleForScale(TANK), "tank", "a scale whose defensive weights rival its offensive ones is a tank's")
eq(ns.RoleForScale(HEALER), "healer", "and a healing scale is a healer's")
eq(ns.RoleForScale(nil), "dps", "no scale falls back to dps rather than erroring")
eq(ns.RoleForScale({}), "dps", "and so does a scale with no weights")

-- ---- every row can be read by every role ---------------------------------------------------
-- score + effect[column] is an ADDITION. A row added later with only the columns its author
-- cared about makes score + nil, which is a hard error for one role and invisible to the rest.
local rows = 0
for i, effect in ipairs(ns.EFFECT_VALUES) do
    rows = rows + 1
    local word = tostring(effect[1])
    ok(type(effect[1]) == "string" and effect[1] ~= "",
       "EFFECT_VALUES row " .. i .. " has a word to match on")
    for column = 2, 4 do
        ok(type(effect[column]) == "number",
           "EFFECT_VALUES row " .. i .. " (" .. word .. ") has a number in column " .. column ..
           " - a missing one is score + nil, a crash for that role alone")
    end
    ok(type(effect[5]) == "string" and effect[5] ~= "",
       "EFFECT_VALUES row " .. i .. " (" .. word .. ") says WHY, because these are opinions")
end
ok(rows > 5, "the effect table is populated (" .. rows .. " rows)")

-- ---- THE COLUMN IS ACTUALLY READ ------------------------------------------------------------
-- Compared between roles rather than against a constant. If the same column were read for
-- everyone, every one of these would come out equal and a fixed-number assertion would happily
-- pass on whichever role it was written for.
local function scoreFor(name, scale)
    local s = ns.ScoreEnhancement({ name = name, stats = nil }, scale, "Any")
    return s
end

-- "crusher" is 45 dps / 25 tank / 0 healer in the table.
local cDps, cTank, cHeal = scoreFor("Crusher", DPS), scoreFor("Crusher", TANK), scoreFor("Crusher", HEALER)
ok(cDps > cTank, "a melee damage proc is worth more to dps than to a tank")
ok(cTank > cHeal, "and more to a tank than to a healer")
eq(cHeal, 0, "a healer is offered nothing for a melee proc, rather than a confident number")

-- "stoneshield" is 5 / 50 / 0 - the mirror image, so a gate that had the columns swapped
-- cannot pass both this and the one above.
local sDps, sTank = scoreFor("Stoneshield", DPS), scoreFor("Stoneshield", TANK)
ok(sTank > sDps, "armour is worth far more to a tank than to dps")

-- "spellpower" is 40 / 5 / 40: high for two roles that are not adjacent columns.
local pHeal, pTank = scoreFor("Spellpower", HEALER), scoreFor("Spellpower", TANK)
ok(pHeal > pTank, "spell power is worth more to a healer than to a tank")

-- ---- the deliberate cumulative nudge --------------------------------------------------------
-- The loop has no break, and that is intentional for exactly one row: "greater" is a small
-- bonus so that Greater X outranks plain X on a tie. Worth pinning, because a break added
-- later to "fix" the double-match would silently undo it.
ok(scoreFor("Greater Speed", DPS) > scoreFor("Speed", DPS),
   "Greater X outranks plain X, which is what the cumulative match is FOR")

-- ---- estimated: the admission that this is judgement -----------------------------------------
local _, estMatched = ns.ScoreEnhancement({ name = "Mongoose" }, DPS, "Any")
ok(estMatched, "a score touched by the judgement table says so")

local plainScore, estPlain = ns.ScoreEnhancement({ name = "Enchant Chest - Mighty Stats" }, DPS, "Any")
eq(estPlain, false,
   "a name matching nothing in the table is NOT flagged as estimated - the flag has to mean something")
eq(plainScore, 0, "and scores only what the stat weights gave it, which is zero here")

-- ---- it never throws -------------------------------------------------------------------------
-- This runs per entry per slot while the panel draws. An error here loses the tab.
local nilScore, nilEst = ns.ScoreEnhancement(nil, DPS, "Any")
eq(nilScore, 0, "no entry scores zero")
eq(nilEst, false, "and is not called an estimate")
ok(pcall(ns.ScoreEnhancement, { name = "Mongoose" }, nil, nil), "no scale is survivable")
ok(pcall(ns.ScoreEnhancement, {}, DPS, "Any"), "an entry with no name is survivable")

-- A stat scorer that throws must not take the panel with it. The pcall around it is the only
-- reason this function can be called on data it has never seen.
Valuate.CalculateItemScore = function() error("scale exploded") end
local okCall, thrown = pcall(ns.ScoreEnhancement, { name = "Mongoose", stats = { Agility = 1 } }, DPS, "Any")
ok(okCall, "a stat scorer that errors does not propagate out of the enhancement scorer")
ok(okCall and thrown > 0, "and the judgement part of the score still lands")

return failures, checks
`,
  "enhancescore",
  "enhancement scoring"
);
