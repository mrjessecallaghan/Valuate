#!/usr/bin/env node
/*
 * @gate Hit past the cap scores nothing, and the addon refuses to guess when it cannot tell
 *
 * Runs the real GetHitState / HitValueFactor / DiminishingFactor / CalculateItemScore.
 *
 * A stat weight is a claim about the NEXT point of a stat, and this addon treated that claim
 * as fixed. Hit is where that breaks hardest: once you cannot miss, the next point of hit is
 * worth exactly nothing, and a scale weighting it at 1.0 will rank a hit-stacked item above a
 * better one forever.
 *
 * Two risks, opposite in direction, and both are covered here:
 *
 *   NOT CAPPING when it should - the original bug, silently over-valuing dead stats.
 *
 *   CAPPING ON A GUESS - much worse. The rating-to-percent conversion changes with level and
 *   this is a modified server, so a wrong conversion would quietly mis-rank every piece of
 *   gear carrying hit, in a direction nobody can see. The conversion is DERIVED from the
 *   player's own gear, and when it cannot be derived the feature must do nothing at all.
 *
 * The third thing tested is honesty about kind: crit and haste have no diminishing returns in
 * 3.3.5 - that conversion is linear - so the taper is a preference and must default to off.
 *
 * Usage:  node tools/hitcap.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local HIT_CAP_BY_GAP = \{[\s\S]*?\r?\n\}/m,
  /^local CR_HIT_MELEE, CR_HIT_RANGED, CR_HIT_SPELL = [\d, ]+/m,
  /^local function ScaleIsCaster\([\s\S]*?\r?\nend/m,
  /^local hitStateCache, hitStateAt = nil, -1/m,
  /^local HIT_STATE_TTL = \d+/m,
  /^function Valuate:InvalidateHitState\([\s\S]*?\r?\nend/m,
  /^function Valuate:GetHitState\([\s\S]*?\r?\nend/m,
  /^local function HitValueFactor\([\s\S]*?\r?\nend/m,
  /^local DIMINISHING_RATINGS = \{[\s\S]*?\r?\n\}/m,
  /^local function DiminishingFactor\([\s\S]*?\r?\nend/m,
  /^function Valuate:CalculateItemScore\([\s\S]*?\r?\nend/m,
  /^function Valuate:BuildHitCapLine\([\s\S]*?\r?\nend/m,
  /^function Valuate:CalculateStatBreakdown\([\s\S]*?\r?\nend/m,
  /^function Valuate:CalculateStatBreakdownWithComparison\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
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
local function near(got, want, what)
    checks = checks + 1
    if type(got) ~= "number" or math.abs(got - want) > 0.001 then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted about " .. tostring(want) .. ")")
    end
end

Valuate = {}
local OPTIONS = { hitCapAware = true, hitCapTargetGap = 0,
                  diminishingReturns = false, diminishingHalfAtPercent = 10 }
function Valuate:GetOptions() return OPTIONS end

local OWNED = {}
function Valuate:GetCachedEquippedStatTotals() return OWNED end

-- The client's view of your hit. RATING and PERCENT are set independently on purpose: their
-- ratio is the conversion the whole feature turns on, and a mock that derived one from the
-- other could not express a client that disagrees with our arithmetic.
local RATING, PERCENT = 0, 0
-- Per-index, because the taper reads a DIFFERENT rating than the hit cap does. A single
-- shared return would have crit answering with the hit percentage and passing anyway.
local BONUS_BY_INDEX = {}
function GetCombatRating() return RATING end
function GetCombatRatingBonus(index)
    if BONUS_BY_INDEX[index] ~= nil then return BONUS_BY_INDEX[index] end
    return PERCENT
end

local TIME = 1000
function GetTime() return TIME end
local function tick() TIME = TIME + 10 Valuate:InvalidateHitState() end

` + sliced.join("\n") + `

local MELEE = { Values = { Strength = 1.0, AttackPower = 0.5, HitRating = 1.0 } }
local CASTER = { Values = { Intellect = 1.0, SpellPower = 0.8, HitRating = 1.0 } }

-- ---- which cap applies is read off the scale ------------------------------------
-- One HitRating stat, two different caps. Asking the scale what it values beats adding a
-- stat nobody's gear carries.
RATING, PERCENT = 100, 5.0
tick()
eq(Valuate:GetHitState(MELEE).key, "melee", "a strength/AP build is scored against the melee cap")
eq(Valuate:GetHitState(CASTER).key, "spell", "an int/spellpower build is scored against the spell cap")

-- Both in the same repaint must not share one cached answer.
eq(Valuate:GetHitState(MELEE).cap, 5.0, "melee, same-level: 5%")
eq(Valuate:GetHitState(CASTER).cap, 4.0, "spell, same-level: 4% - and asking for melee first did not poison it")

-- ---- the example from the request ------------------------------------------------
-- "im lvl 10 and my hit cap is 4". That is the spell cap against a same-level target, and it
-- does not depend on level at all - the CONVERSION does, which is why that is derived.
RATING, PERCENT = 10, 2.0
tick()
local low = Valuate:GetHitState(CASTER)
eq(low.cap, 4.0, "the cap is 4% for a caster against same-level targets, at any level")
near(low.headroom, 2.0, "with 2% already, there is 2% to go")
near(low.perPercent, 5.0, "and the conversion is derived from the gear: 10 rating for 2% is 5 per 1%")

-- ---- how much of an item's hit is worth anything ---------------------------------
-- 2% of headroom at 5 rating per 1% means 10 rating is fully useful.
local scoreOf = function(stats, scale) return Valuate:CalculateItemScore(stats, scale) end

near(scoreOf({ HitRating = 10 }, CASTER), 10, "hit that lands entirely under the cap counts in full")

-- 20 rating is 4%, but only 2% fits. Half of it is dead weight.
near(scoreOf({ HitRating = 20 }, CASTER), 10, "hit that overshoots counts only up to the cap")

-- Already capped: worth nothing at all. This is the bug the whole feature exists for.
RATING, PERCENT = 20, 4.0
tick()
eq(scoreOf({ HitRating = 20 }, CASTER), 0, "once capped, more hit scores zero")
near(scoreOf({ Intellect = 5, HitRating = 20 }, CASTER), 5,
     "and the rest of the item is scored exactly as before - only hit is zeroed")

-- ---- it must NOT act on a guess ---------------------------------------------------
-- The conversion changes with level and this is a modified server. Capping on an assumed
-- curve would mis-rank every hit item in a direction nobody can see.
RATING, PERCENT = 0, 0
tick()
local blind = Valuate:GetHitState(CASTER)
eq(blind.calibrated, false, "with no hit rating there is nothing to derive the conversion from")
near(scoreOf({ HitRating = 999 }, CASTER), 999,
     "so hit is scored at FULL weight - refusing to guess beats guessing wrong")

-- Same rule when the client has no such API at all.
local realGCR = GetCombatRating
GetCombatRating = nil
tick()
eq(Valuate:GetHitState(CASTER), nil, "a client without GetCombatRating reports nothing")
near(scoreOf({ HitRating = 50 }, CASTER), 50, "and scoring is untouched")
GetCombatRating = realGCR

-- ---- switched off means switched off -----------------------------------------------
RATING, PERCENT = 20, 4.0
tick()
OPTIONS.hitCapAware = false
near(scoreOf({ HitRating = 20 }, CASTER), 20, "with the feature off, capped hit scores in full again")
OPTIONS.hitCapAware = true
eq(scoreOf({ HitRating = 20 }, CASTER), 0, "and back to zero when switched on")

-- ---- one switch off while the other is on -------------------------------------------
-- The scoring loop only reaches these adjusters when EITHER feature is on, so with hit-cap
-- off and diminishing returns on, HitValueFactor is still called and its own switch is the
-- only thing stopping it. A mutation deleting that switch survived because nothing here had
-- ever been in this state - which is exactly the combination a user gets by switching on the
-- optional one and leaving the default one alone.
OPTIONS.hitCapAware = false
OPTIONS.diminishingReturns = true
OWNED = {}
near(scoreOf({ HitRating = 20 }, CASTER), 20,
     "with hit-cap off but diminishing returns on, hit is still scored in full")
OPTIONS.hitCapAware = true
OPTIONS.diminishingReturns = false

-- ---- headroom never goes negative -----------------------------------------------------
-- Being over the cap means no room left, not negative room. /valuate hit prints this as
-- "%.2f%% to go", and "-1.50% to go" is not a sentence.
RATING, PERCENT = 40, 8.0
tick()
local over = Valuate:GetHitState(CASTER)
ok(over.percent > over.cap, "the fixture really is past the cap")
eq(over.headroom, 0, "and headroom reads zero rather than a negative amount left to gain")

RATING, PERCENT = 20, 4.0
tick()

-- ---- what you are fighting changes the cap -------------------------------------------
-- 4% against a same-level mob, 17% against a boss. Someone levelling with the boss number set
-- would stack four times the hit they can use.
OPTIONS.hitCapTargetGap = 3
tick()
eq(Valuate:GetHitState(CASTER).cap, 17.0, "against a boss the spell cap is 17%")
ok(scoreOf({ HitRating = 20 }, CASTER) > 0, "so hit that was dead at same-level is worth something again")
OPTIONS.hitCapTargetGap = 0
tick()

-- ---- diminishing returns are a PREFERENCE, and default to off --------------------------
-- 3.3.5 has no diminishing returns on the crit or haste conversion. This is a claim about
-- worth, and shipping it on by default would silently reorder everyone's gear.
--
-- The threshold is a PERCENTAGE, not a rating, and that is the whole point of this section.
-- It shipped as "400 rating", which is about 9% crit at level 80 and an unreachable amount at
-- level 10 - so the feature would have sat inert for exactly the character who asked for it.
-- A percentage means the same thing at every level; a rating does not.
local CRIT = { Values = { CritRating = 1.0, Intellect = 0.1 } }
local CRIT_SPELL_INDEX = 11

eq(OPTIONS.diminishingReturns, false, "it is off unless asked for")
BONUS_BY_INDEX[CRIT_SPELL_INDEX] = 10
near(scoreOf({ CritRating = 10 }, CRIT), 10, "and off means untouched")

OPTIONS.diminishingReturns = true
OPTIONS.diminishingHalfAtPercent = 10
near(scoreOf({ CritRating = 10 }, CRIT), 5,
     "at exactly the half-value PERCENTAGE, crit is worth half - which is what the setting says")

BONUS_BY_INDEX[CRIT_SPELL_INDEX] = 0
near(scoreOf({ CritRating = 10 }, CRIT), 10, "with none of the stat yet, the first points are worth full")

BONUS_BY_INDEX[CRIT_SPELL_INDEX] = 30
near(scoreOf({ CritRating = 10 }, CRIT), 2.5, "and it keeps falling smoothly rather than cliffing")

-- Never reaches zero: a stat with no cap should always be worth something, and a curve that
-- hit zero would make items containing it unrankable against each other.
BONUS_BY_INDEX[CRIT_SPELL_INDEX] = 100000
ok(scoreOf({ CritRating = 10 }, CRIT) > 0, "the curve approaches zero without arriving")

-- The level problem, stated as a test. A character with 10% crit is half-valued whatever
-- their level and whatever rating that percentage cost them - which a rating threshold could
-- not express, because 400 rating is a different amount of crit at 10 than at 80.
BONUS_BY_INDEX[CRIT_SPELL_INDEX] = 10
near(scoreOf({ CritRating = 1 }, CRIT), 0.5,
     "a level 10 with 10% crit is tapered exactly like a level 80 with 10% crit")
near(scoreOf({ CritRating = 400 }, CRIT), 200,
     "and the RATING carried has no bearing on it, which is what a rating threshold got wrong")

-- Cannot tell: change nothing, the same rule the hit cap follows.
BONUS_BY_INDEX[CRIT_SPELL_INDEX] = nil
PERCENT = 0
near(scoreOf({ CritRating = 10 }, CRIT), 10,
     "a client reporting no crit percentage leaves scoring alone rather than guessing")
BONUS_BY_INDEX[CRIT_SPELL_INDEX] = 10
PERCENT = 2.0

-- Only the stats the client can report a percentage for.
local STR = { Values = { Strength = 1.0 } }
near(scoreOf({ Strength = 10 }, STR), 10, "primary stats are not tapered - they do not work like that")
OPTIONS.diminishingReturns = false

-- ---- the tooltip says WHY the number moved ------------------------------------------
-- A score that quietly changed is worse than one that did not: you cannot tell a working
-- addon from a broken one. This whole project shows a breakdown because a confident number
-- with no explanation is not evidence, and v0.130.0a introduced a silent adjustment.
local function tipFor(stats, scale) return Valuate:BuildHitCapLine(stats, scale) end

OPTIONS.hitCapAware = true
OPTIONS.diminishingReturns = false

-- Nothing to say is the common case, and saying nothing is right.
RATING, PERCENT = 10, 2.0
tick()
eq(tipFor({ Intellect = 5 }, CASTER), nil, "an item with no hit gets no line")
eq(tipFor({ HitRating = 5 }, { Values = { Intellect = 1.0 } }), nil,
   "nor does a build that does not want hit - nothing is being penalised")

OPTIONS.hitCapAware = false
eq(tipFor({ HitRating = 5 }, CASTER), nil, "nor when the feature is switched off")
OPTIONS.hitCapAware = true

-- Fits entirely: confirm it counts, and say how much room is left. That is the thing someone
-- hovering a hit item actually wants to know.
local fits = tipFor({ HitRating = 5 }, CASTER)
ok(fits ~= nil, "an item whose hit all fits still gets a line")
ok(fits:find("All 5 hit counts", 1, true) ~= nil, "saying it all counts")
ok(fits:find("2.00%", 1, true) ~= nil, "and how much headroom is left")

-- Partly wasted. The useful RATING is named, not a percentage - the number on the item is a
-- rating, so the comparison has to be in the same units to mean anything.
local partial = tipFor({ HitRating = 20 }, CASTER)
ok(partial ~= nil, "an item that overshoots gets a line")
ok(partial:find("Only 10 of this item's 20 hit counts", 1, true) ~= nil,
   "naming how much of it counts, in rating rather than percent")

-- Fully capped: the strongest case, and the one that makes a good item look bad for no
-- visible reason.
RATING, PERCENT = 20, 4.0
tick()
local capped = tipFor({ HitRating = 20 }, CASTER)
ok(capped ~= nil, "a capped character gets a line")
ok(capped:find("worth nothing", 1, true) ~= nil, "saying the hit is worth nothing")
ok(capped:find("4.0%", 1, true) ~= nil, "and naming the cap it is measured against")

-- Uncalibrated has to speak too. The feature is doing NOTHING here, so silence would read as
-- "you have headroom" when the truth is "this was not adjusted at all".
RATING, PERCENT = 0, 0
tick()
local blind2 = tipFor({ HitRating = 20 }, CASTER)
ok(blind2 ~= nil, "an uncalibrated character gets a line rather than silence")
ok(blind2:find("scored in full", 1, true) ~= nil,
   "saying the score was not adjusted - silence would read as 'you have room'")

RATING, PERCENT = 10, 2.0
tick()

-- ---- an item you are ALREADY WEARING ---------------------------------------------------
-- The flaw this section exists for, found by sweeping after the fact rather than while
-- writing it. Your current hit % includes everything equipped, so a worn item has already
-- been counted into it. Scored naively, the very piece that got you to the cap contributes
-- nothing - while a bag alternative carrying no hit is scored in full. Best Equipment would
-- advise swapping away the item keeping you capped, which drops you under it, which makes hit
-- valuable again, which advises swapping back.
RATING, PERCENT = 20, 4.0   -- exactly capped, and ALL of it from the one piece below
tick()

local wornPiece = { HitRating = 20, Intellect = 5 }
near(scoreOf(wornPiece, CASTER), 5,
     "scored as a bag item, a capped character's hit is worth nothing - correct for something " ..
     "you are considering ADDING")
near(Valuate:CalculateItemScore(wornPiece, CASTER, { worn = true }), 25,
     "but the piece you are WEARING is scored for what you would lose by removing it - all " ..
     "of its hit is doing work, because without it you are under the cap")

-- The half-wasted case, from the other side: 8% worn against a 4% cap means half of that
-- item's hit is genuinely dead even though you are wearing it.
RATING, PERCENT = 40, 8.0
tick()
near(Valuate:CalculateItemScore({ HitRating = 40 }, CASTER, { worn = true }), 20,
     "a worn item carrying twice the cap has half its hit doing work, and half wasted")

-- And a worn item with no hit is unaffected by any of this.
RATING, PERCENT = 20, 4.0
tick()
near(Valuate:CalculateItemScore({ Intellect = 5 }, CASTER, { worn = true }), 5,
     "a worn item with no hit scores exactly as it always did")

-- ---- the breakdown agrees with the score ------------------------------------------------
-- Two independent paths computed contributions and only one knew about the cap, so the score
-- said hit contributed nothing while the panel explaining that score listed it as the biggest
-- line on the item. The panel is the thing people open BECAUSE the total surprised them.
local function breakdownTotal(stats, scale)
    local rows = Valuate:CalculateStatBreakdown(stats, scale)
    local sum = 0
    for _, r in ipairs(rows or {}) do sum = sum + r.contribution end
    return sum
end

local capped2 = { HitRating = 20, Intellect = 5 }
near(breakdownTotal(capped2, CASTER), scoreOf(capped2, CASTER),
     "the breakdown adds up to the score it is explaining")

local function rowFor(stats, scale, want)
    for _, r in ipairs(Valuate:CalculateStatBreakdown(stats, scale) or {}) do
        if r.statName == want then return r end
    end
end
local hitRow = rowFor(capped2, CASTER, "HitRating")
ok(hitRow ~= nil, "hit still appears in the breakdown rather than vanishing")
near(hitRow.contribution, 0, "contributing nothing, which is what the score did with it")
eq(hitRow.adjusted, true, "and flagged as adjusted, so a display can say WHY it is smaller")

-- Under the cap, nothing is flagged - a marker on everything would mean nothing.
RATING, PERCENT = 5, 1.0
tick()
local roomy = rowFor({ HitRating = 5 }, CASTER, "HitRating")
eq(roomy.adjusted, nil, "with headroom to spare, nothing is marked as adjusted")

RATING, PERCENT = 10, 2.0
tick()

-- ---- the comparison tooltip, where BOTH questions are asked at once --------------------
-- The most-read tooltip in the addon, and a third path with its own contribution arithmetic.
-- Its two sides are not the same question: the equipped item is on your body and its hit is
-- already in your total, so it is worth what you would LOSE by removing it; the hovered item
-- is not, so it is worth what it would ADD. Treating them alike either tells you your own
-- gear is worthless or that a candidate is better than it is.
RATING, PERCENT = 20, 4.0   -- capped, entirely from the equipped piece below
tick()

local function cmpRow(hover, equipped, scale, want)
    for _, r in ipairs(Valuate:CalculateStatBreakdownWithComparison(hover, equipped, scale) or {}) do
        if r.statName == want then return r end
    end
end

local row = cmpRow({ HitRating = 20 }, { HitRating = 20 }, CASTER, "HitRating")
ok(row ~= nil, "hit appears in the comparison breakdown")
near(row.hoverContribution, 0,
     "the CANDIDATE's hit is worth nothing - you are capped, so adding more does nothing")
near(row.equippedContribution, 20,
     "but the EQUIPPED item's hit is worth all of it - take it off and you fall under the cap")
ok(row.diff < 0,
   "so swapping a hit piece for an identical one reads as a LOSS of nothing... " ..
   "and swapping it for a no-hit item reads as the loss it really is")
eq(row.adjusted, true, "and the row is flagged, so the display can say why the numbers moved")

-- The asymmetry is the whole point: identical stats on both sides must NOT cancel to zero
-- here, because one of them is doing work and the other would not be.
ok(row.hoverContribution ~= row.equippedContribution,
   "identical hit on both sides is valued differently, because the questions differ")

-- Under the cap there is nothing to adjust and nothing to flag.
RATING, PERCENT = 5, 1.0
tick()
local roomyRow = cmpRow({ HitRating = 5 }, { HitRating = 5 }, CASTER, "HitRating")
near(roomyRow.hoverContribution, roomyRow.equippedContribution,
     "with headroom to spare both sides are valued the same")
eq(roomyRow.adjusted, nil, "and nothing is flagged")

RATING, PERCENT = 10, 2.0
tick()

return failures, checks
`,
  "hitcap",
  "the hit cap, and refusing to guess at the conversion"
);
