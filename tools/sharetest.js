#!/usr/bin/env node
/*
 * @gate Stat shares rank by what actually contributes
 *
 * Runs the REAL source of RankStatShares from Valuate.lua.
 *
 * It answers the question a stat-weight tool exists for and could not previously be asked:
 * of the weights I have set, which are doing any work? A scale with fifteen weights looks
 * carefully tuned, and if twelve are on stats your gear does not carry, tuning them is
 * theatre.
 *
 * Worth executing rather than reading, because every way it can be wrong produces a
 * plausible-looking table:
 *   - shares divided by the SIGNED total, so one penalty pushes everything past 100%
 *     (the same trap that had the tooltip printing "+-50%")
 *   - sorting by signed contribution, so a large penalty sorts last instead of first
 *   - pairs() order leaking into the output, so the list reshuffles between identical runs
 *   - a weighted stat you carry none of silently vanishing instead of being named
 *
 * Usage:  node tools/sharetest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

function slice(header) {
  const re = new RegExp("^" + header.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\(([\\s\\S]*?)\\nend\\n", "m");
  const hit = lua.match(re);
  if (!hit) {
    console.error(
      `  SLICE  could not find \`${header}\` in Valuate.lua - ` +
        "it was renamed, moved or reshaped, so this gate is testing nothing"
    );
    process.exit(1);
  }
  return hit[0];
}

const m = [slice("local function RankStatShares")];
const CACHE = slice("function Valuate:GetCachedEquippedStatTotals");

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
    if type(got) ~= "number" or math.abs(got - want) > 0.01 then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end

tinsert = table.insert

` + m[0] + `

-- The cache's own file-locals, declared here because the slice does not carry them.
local statTotalsCache, statTotalsAt, statTotalsSlots = nil, 0, 0
local STAT_TOTALS_TTL = 5
__now = 100
function GetTime() return __now end
__scans = 0
Valuate = Valuate or {}
Valuate.GetEquippedStatTotals = function()
    __scans = __scans + 1
    return { Strength = 10 * __scans }, 3
end

` + CACHE + `

-- ---- the ordinary case -------------------------------------------------------
local scale = { Values = { Strength = 2, Stamina = 1, Agility = 0.5 } }
local totals = { Strength = 100, Stamina = 100, Agility = 100 }
local ranked, idle, total = RankStatShares(totals, scale)

eq(#ranked, 3, "every weighted stat you carry is ranked")
eq(#idle, 0, "nothing is idle when you carry all of them")
near(total, 350, "total is the sum of value x weight")
eq(ranked[1].stat, "Strength", "the biggest contributor comes first")
eq(ranked[3].stat, "Agility", "the smallest comes last")
near(ranked[1].share, 200 / 350 * 100, "share is contribution over the total magnitude")
near(ranked[1].contribution, 200, "contribution is value x weight")

local sum = 0
for _, e in ipairs(ranked) do sum = sum + e.share end
near(sum, 100, "shares add up to 100%")

-- ---- a weight you carry none of ----------------------------------------------
scale = { Values = { Strength = 2, HitRating = 1.5, CritRating = 1 } }
totals = { Strength = 100, CritRating = 0 }
ranked, idle = RankStatShares(totals, scale)
eq(#ranked, 1, "only the stat you actually carry is ranked")
eq(#idle, 2, "both absent stats are named rather than dropped")
eq(idle[1], "CritRating", "idle list is sorted, so it does not reshuffle")
eq(idle[2], "HitRating", "...and contains the stat with a zero total as well as the missing one")

-- A zero VALUE and a missing value mean the same thing here - you are carrying none of it.
-- Ranking a zero contribution would put a 0.0% line in a list about what matters.

-- ---- a zero weight is not a weight -------------------------------------------
scale = { Values = { Strength = 2, Spirit = 0 } }
totals = { Strength = 100, Spirit = 500 }
ranked, idle = RankStatShares(totals, scale)
eq(#ranked, 1, "a zero weight does not contribute")
eq(#idle, 0, "...and is not reported as idle either - you did not ask for it")

-- ---- NEGATIVE weights --------------------------------------------------------
-- A penalty is a stat doing work. Dividing by the signed total would let it push the
-- others' shares past 100%; sorting by signed contribution would bury it last.
scale = { Values = { Strength = 2, Spirit = -3 } }
totals = { Strength = 100, Spirit = 100 }
ranked, idle, total = RankStatShares(totals, scale)
near(total, -100, "the total is signed: 200 - 300")
eq(ranked[1].stat, "Spirit", "the biggest MAGNITUDE ranks first, even as a penalty")
near(ranked[1].share, 60, "300 of 500 magnitude")
near(ranked[2].share, 40, "200 of 500 magnitude")
sum = 0
for _, e in ipairs(ranked) do sum = sum + e.share end
near(sum, 100, "shares still add to 100% with a penalty in the mix")
ok(ranked[1].share <= 100, "no share exceeds 100%")

-- ---- determinism -------------------------------------------------------------
-- pairs() order is undefined, so an unstable sort would reshuffle equal contributors
-- between identical runs and read as a bug in the numbers.
scale = { Values = { Alpha = 1, Bravo = 1, Charlie = 1, Delta = 1 } }
totals = { Alpha = 50, Bravo = 50, Charlie = 50, Delta = 50 }
local first = nil
for run = 1, 8 do
    local r = RankStatShares(totals, scale)
    local order = {}
    for i, e in ipairs(r) do order[i] = e.stat end
    local joined = table.concat(order, ",")
    if not first then first = joined end
    eq(joined, first, "identical contributions rank in a stable order (run " .. run .. ")")
end
eq(first, "Alpha,Bravo,Charlie,Delta", "...and that order is by name")

-- ---- nothing to say ----------------------------------------------------------
ranked, idle, total = RankStatShares({}, scale)
eq(#ranked, 0, "no stats at all means nothing ranked")
eq(#idle, 4, "...and every weight is reported as idle")
near(total, 0, "and the total is zero rather than nil")

ok(RankStatShares(nil, scale) == nil, "nil totals returns nil")
ok(RankStatShares({}, nil) == nil, "nil scale returns nil")
ok(RankStatShares({}, {}) == nil, "a scale with no Values returns nil")

-- ---- the totals cache --------------------------------------------------------
-- Reading seventeen slots through the private tooltip is what a SCAN costs, so the hover
-- path must not do it per row. Everything here is about not scanning, and about not
-- serving something stale for longer than a person would tolerate.
__scans = 0
__now = 100
local t, slots = Valuate:GetCachedEquippedStatTotals()
eq(__scans, 1, "the first call scans")
eq(slots, 3, "slot count is returned alongside the totals")
eq(t.Strength, 10, "the totals come from the scan")

Valuate:GetCachedEquippedStatTotals()
Valuate:GetCachedEquippedStatTotals()
eq(__scans, 1, "hovering along a column of rows costs no further scans")

__now = 104.9
Valuate:GetCachedEquippedStatTotals()
eq(__scans, 1, "still cached just inside the TTL")

__now = 106
t = Valuate:GetCachedEquippedStatTotals()
eq(__scans, 2, "expired past the TTL, so gear you just equipped shows up")
eq(t.Strength, 20, "and the fresh totals replace the old ones")

-- A /reload resets GetTime, so the clock CAN go backwards. Without the guard, now-then is
-- negative, that reads as "not expired", and the cache pins whatever it last held for as
-- long as the difference - which after a long session is the rest of the session.
__now = 3
t = Valuate:GetCachedEquippedStatTotals()
eq(__scans, 3, "a clock that went backwards forces a rescan rather than pinning the cache")

__now = 5
Valuate:GetCachedEquippedStatTotals()
eq(__scans, 3, "...and the cache works normally again from the new clock")

return failures, checks
`,
  "sharetest",
  "the stat share ranking"
);
