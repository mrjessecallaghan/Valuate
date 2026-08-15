#!/usr/bin/env node
/*
 * @gate The addon reports what it cost you, sorted by the thing that actually stutters
 *
 * Runs the REAL Valuate:PrintEventCost against a fabricated cost table.
 *
 * WHY THIS EXISTS: the TSM integration froze a client on a hot path nobody was measuring.
 * This addon is the one always loaded, runs twenty automations off thirty-three events
 * including BAG_UPDATE and ITEM_PUSH, and had no instrument at all - /valuate profile
 * measured a scan on demand, which answers "how expensive is a scan" and not "why does the
 * game hitch when I loot".
 *
 * The measuring itself cannot be gated here: debugprofilestop is a client function and the
 * harness does no timing. What CAN be gated is everything around it, and every one of those
 * is a way to have numbers and still not answer the question -
 *
 *   - sorted by WORST single call, because a stutter is one long call and a hundred short
 *     ones on ITEM_PUSH can total more while feeling like nothing;
 *   - a stable order, because pairs() is not a ranking;
 *   - the warning said ONCE per event, because one that fires every time you loot is one
 *     you turn off, and then it is not a warning.
 *
 * Usage:  node tools/eventcost.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const hit = lua.match(/^function Valuate:PrintEventCost\([\s\S]*?\r?\nend/m);
if (!hit) {
  console.error("  SLICE  could not find Valuate:PrintEventCost - this gate tests nothing");
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

local ns = {}
Valuate = {}
ns.EVENT_STUTTER_MS = 100

${hit[0]}

local function lines()
    return table.concat(__printed, "\\n")
end

-- ---- nothing measured is not an empty report --------------------------------------------
-- A blank section reads as "this addon costs nothing", which is a claim. It has not looked.
ns.eventCost = {}
__printed = {}
eq(Valuate:PrintEventCost(), 0, "with nothing measured, nothing is reported")
ok(lines():find("nothing measured yet", 1, true) ~= nil,
   "and it says so rather than printing an empty heading")

-- ---- sorted by WORST, not by total ------------------------------------------------------
-- The case the ordering exists for. ITEM_PUSH costs far more in TOTAL - a hundred small
-- calls - and feels like nothing. BAG_UPDATE has one long call, and that is the stutter.
ns.eventCost = {
    ITEM_PUSH   = { worst = 3,   total = 900, count = 300 },
    BAG_UPDATE  = { worst = 140, total = 280, count = 2 },
    LOOT_OPENED = { worst = 30,  total = 60,  count = 2 },
}
__printed = {}
eq(Valuate:PrintEventCost(), 3, "every measured event is counted")
local text = lines()
local bagAt, pushAt = text:find("BAG_UPDATE", 1, true), text:find("ITEM_PUSH", 1, true)
ok(bagAt and pushAt and bagAt < pushAt,
   "the one long call is listed above the many short ones, whatever the totals say")

-- The total is still SHOWN. It is the thing that says "this is death by a thousand cuts"
-- rather than one bad call, and dropping it would lose that entirely.
ok(text:find("900", 1, true) ~= nil, "the running total is reported too")
ok(text:find("300", 1, true) ~= nil, "with how many calls it took to get there")

-- ---- a stable order ----------------------------------------------------------------------
-- pairs() is not a ranking. Two events costing the same would swap between runs, and a table
-- that reshuffles is one you stop trusting.
--
-- Re-running and comparing is NOT enough: pairs() is arbitrary but stable for one table in
-- one Lua state, so five identical runs prove only that nothing is random. They passed with
-- the tiebreaker deleted entirely.
--
-- So this asserts the ORDER is alphabetical, and first checks its own premise - that pairs()
-- is not already handing them over alphabetically. If it is, the fixture cannot test this and
-- says so, rather than passing on a coincidence.
ns.eventCost = {
    ZULU  = { worst = 50, total = 50, count = 1 },
    ALPHA = { worst = 50, total = 50, count = 1 },
    MIKE  = { worst = 50, total = 50, count = 1 },
    ECHO  = { worst = 50, total = 50, count = 1 },
    TANGO = { worst = 50, total = 50, count = 1 },
}
local natural = {}
for event in pairs(ns.eventCost) do natural[#natural + 1] = event end
local alreadySorted = true
for i = 2, #natural do
    if natural[i] < natural[i - 1] then alreadySorted = false break end
end
ok(not alreadySorted,
   "the fixture's pairs() order is not already alphabetical, so this can actually test the " ..
   "tiebreaker (order was: " .. table.concat(natural, ", ") .. ")")

__printed = {}
Valuate:PrintEventCost()
local text2 = lines()
local seen = {}
for _, event in ipairs({ "ALPHA", "ECHO", "MIKE", "TANGO", "ZULU" }) do
    seen[#seen + 1] = text2:find(event, 1, true)
end
local ascending = true
for i = 2, #seen do
    if not seen[i] or not seen[i - 1] or seen[i] < seen[i - 1] then ascending = false end
end
ok(ascending, "events costing exactly the same are listed alphabetically, not in pairs() order")

local first = lines()
for _ = 1, 5 do
    __printed = {}
    Valuate:PrintEventCost()
    eq(lines(), first, "and identically on every run")
end

-- ---- the list is capped, and says when it capped ------------------------------------------
-- Thirty-three events is a wall of text. Six is a report; the rest are cheaper by
-- construction, because the list is sorted - but silently stopping would read as complete.
ns.eventCost = {}
for i = 1, 12 do
    ns.eventCost["EVENT_" .. i] = { worst = i, total = i, count = 1 }
end
__printed = {}
eq(Valuate:PrintEventCost(), 12, "all twelve are counted")
ok(lines():find("and 6 more", 1, true) ~= nil,
   "and the six not shown are disclosed rather than dropped")

-- ---- a costly event is marked ---------------------------------------------------------------
ns.eventCost = { SLOW = { worst = 500, total = 500, count = 1 } }
__printed = {}
Valuate:PrintEventCost()
ok(lines():find("FF8800", 1, true) ~= nil, "an event over the stutter threshold is coloured")

ns.eventCost = { FINE = { worst = 5, total = 5, count = 1 } }
__printed = {}
Valuate:PrintEventCost()
eq(lines():find("FF8800", 1, true), nil,
   "and a cheap one is not - a report that flags everything flags nothing")

return failures, checks
`,
  "eventcost",
  "the per-event cost report"
);
