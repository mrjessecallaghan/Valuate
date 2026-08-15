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
  /^local DIMINISHING_STATS = \{[\s\S]*?\r?\n\}/m,
  /^local function DiminishingFactor\([\s\S]*?\r?\nend/m,
  /^function Valuate:CalculateItemScore\([\s\S]*?\r?\nend/m,
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
                  diminishingReturns = false, diminishingHalfAt = 400 }
function Valuate:GetOptions() return OPTIONS end

local OWNED = {}
function Valuate:GetCachedEquippedStatTotals() return OWNED end

-- The client's view of your hit. RATING and PERCENT are set independently on purpose: their
-- ratio is the conversion the whole feature turns on, and a mock that derived one from the
-- other could not express a client that disagrees with our arithmetic.
local RATING, PERCENT = 0, 0
function GetCombatRating() return RATING end
function GetCombatRatingBonus() return PERCENT end

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
OWNED = { CritRating = 400 }
local CRIT = { Values = { CritRating = 1.0 } }
eq(OPTIONS.diminishingReturns, false, "it is off unless asked for")
near(scoreOf({ CritRating = 10 }, CRIT), 10, "and off means untouched")

OPTIONS.diminishingReturns = true
near(scoreOf({ CritRating = 10 }, CRIT), 5,
     "at exactly the half-value rating, crit is worth half - which is what the setting says")

OWNED = { CritRating = 0 }
near(scoreOf({ CritRating = 10 }, CRIT), 10, "with none stacked, the first points are worth full")

OWNED = { CritRating = 1200 }
near(scoreOf({ CritRating = 10 }, CRIT), 2.5, "and it keeps falling smoothly rather than cliffing")

-- Never reaches zero: a stat with no cap should always be worth something, and a curve that
-- hit zero would make items containing it unrankable against each other.
OWNED = { CritRating = 999999 }
ok(scoreOf({ CritRating = 10 }, CRIT) > 0, "the curve approaches zero without arriving")

-- Only the stats that actually stack without a cap.
OWNED = { Strength = 99999 }
local STR = { Values = { Strength = 1.0 } }
near(scoreOf({ Strength = 10 }, STR), 10, "primary stats are not tapered - they do not work like that")
OPTIONS.diminishingReturns = false

return failures, checks
`,
  "hitcap",
  "the hit cap, and refusing to guess at the conversion"
);
