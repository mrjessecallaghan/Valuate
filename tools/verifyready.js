#!/usr/bin/env node
/*
 * @gate The checklist knows which checks you could actually do right now
 *
 * Runs the real ns.VerifyReadiness and ns.ReadyChecks from Valuate.lua.
 *
 * `/valuate verify` holds 78 behavioural checks, and every one of them covers something only a
 * running client can prove. None of them has ever been ticked.
 *
 * The reason is not that the list is badly presented - it hands out one at a time, the ticks
 * persist, and they un-tick themselves when the behaviour changes. The reason is that most
 * checks need a CIRCUMSTANCE: a repair vendor, an open profession window, the bank, a full
 * relog. Reading past sixty things you cannot do to find the three you can is how a checklist
 * stays at zero, and being handed one you cannot perform is worse than being handed nothing.
 *
 * So a check may now declare what it needs, and `/valuate verify here` answers "what could I do
 * without moving".
 *
 * The two defaults are the whole design, and they point in opposite directions:
 *
 *   NO PREDICATE means READY. Most checks need no circumstance at all, and treating silence as
 *   "unknown" would hide almost the entire list behind a field nobody had filled in yet.
 *
 *   A PROBE THAT ERRORS means READY. Readiness touches live client API. A broken probe must not
 *   be able to remove a check from the list - the worst it may do is offer you one you cannot
 *   currently perform, which costs you a glance. Hiding a check that needed doing costs the
 *   thing the check was protecting.
 *
 * Both are the same principle this project applies to every other "could not look" case: an
 * unreadable answer is never allowed to be the reassuring one.
 *
 * Usage:  node tools/verifyready.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const NL = String.fromCharCode(10);
const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

function slice(name) {
  const start = lua.indexOf("function ns." + name + "(");
  if (start < 0) {
    console.error(
      "  SLICE  could not find ns." + name + " in Valuate.lua - it was renamed or inlined, so " +
        "this gate is testing nothing"
    );
    process.exit(1);
  }
  const end = lua.indexOf(NL + "end" + NL, start);
  return lua.slice(start, end + 5);
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
` + slice("VerifyReadiness") + `
` + slice("ReadyChecks") + `

-- ---- no predicate means READY ------------------------------------------------------------------
-- The common case by a long way. Treating silence as "unknown" would hide almost the whole list
-- behind a field nobody had filled in yet.
local plain = { id = "plain" }
local ready, why = ns.VerifyReadiness(plain)
eq(ready, true, "a check that needs no circumstance is doable anywhere")
eq(why, nil, "and has nothing to explain")

-- ---- a predicate that says yes ------------------------------------------------------------------
local here = { id = "here", ready = function() return true end }
eq(ns.VerifyReadiness(here), true, "a satisfied precondition is ready")
eq(select(2, ns.VerifyReadiness(here)), nil, "with no reason attached")

-- ---- a predicate that says no, WITH a reason -----------------------------------------------------
-- The reason is the useful half: "waiting: a repair vendor" tells you when to come back.
local away = { id = "away", ready = function() return false, "a repair vendor" end }
local r2, why2 = ns.VerifyReadiness(away)
eq(r2, false, "an unmet precondition is not ready")
eq(why2, "a repair vendor", "and says what it is waiting for")

-- A no with no reason still gets one, because "waiting: nil" reaches a screen.
local mute = { id = "mute", ready = function() return false end }
ok(select(2, ns.VerifyReadiness(mute)) ~= nil, "a bare refusal is still given words")

-- ---- THE ONE THAT MATTERS: a broken probe must not hide a check ------------------------------------
-- Readiness touches live client API. The worst a broken probe may do is offer you a check you
-- cannot currently perform, which costs a glance. Hiding a check that needed doing costs the
-- thing the check was protecting - and this is the same rule as every other unreadable answer
-- in this addon: it is never allowed to be the reassuring one.
local broken = { id = "broken", ready = function() error("client said no") end }
local r3, why3 = ns.VerifyReadiness(broken)
eq(r3, true, "a readiness probe that ERRORS leaves the check visible")
eq(why3, nil, "and does not invent a reason for it")

-- Same for a ready that is not a function at all.
eq(ns.VerifyReadiness({ id = "x", ready = "soon" }), true, "a malformed predicate leaves it visible")
eq(ns.VerifyReadiness(nil), false, "but no check at all is not something to offer")

-- ---- splitting a list ------------------------------------------------------------------------------
local LIST = {
    { id = "anywhere" },
    { id = "vendor", ready = function() return false, "a repair vendor" end },
    { id = "bank", ready = function() return false, "the bank open" end },
    { id = "alsohere", ready = function() return true end },
    { id = "ticked" },
}
local function pending(c) return c.id ~= "ticked" end

local doable, blocked = ns.ReadyChecks(LIST, pending)
eq(#doable, 2, "the doable ones are collected")
eq(doable[1].id, "anywhere", "in list order")
eq(doable[2].id, "alsohere", "-- both of them")
eq(#blocked, 2, "and the blocked ones are kept rather than dropped")
eq(blocked[1].why, "a repair vendor", "each with what it waits on")

-- Already-ticked checks are not offered. The filter is the caller's, so this proves it is
-- actually consulted rather than ignored.
for _, d in ipairs(doable) do
    ok(d.id ~= "ticked", "a check that is already ticked is not offered again")
end

-- BLOCKED IS NOT DROPPED. An empty doable list with a non-empty blocked list is "nothing from
-- here", which is a different sentence from "nothing left" and points somewhere.
local allBlocked = ns.ReadyChecks({ LIST[2], LIST[3] }, pending)
eq(#allBlocked, 0, "with everything waiting, nothing is doable")
eq(#select(2, ns.ReadyChecks({ LIST[2], LIST[3] }, pending)), 2,
   "but the waiting ones are still reported, not silently discarded")

-- ---- it survives bad input ---------------------------------------------------------------------------
-- This runs from a slash command while you are standing somewhere; erroring loses the answer.
ok(pcall(ns.ReadyChecks, nil, nil), "no list at all is survivable")
ok(pcall(ns.ReadyChecks, {}, nil), "an empty list is survivable")
local everything = ns.ReadyChecks(LIST, nil)
eq(#everything, 3, "with no filter, every ready check is offered including ticked ones")

-- ---- unwatched first ---------------------------------------------------------------------------
-- Sixty of the 78 checks have a headless gate behind them, so doing one confirms something
-- already proven by other means. The rest are the only evidence that will ever exist for what
-- they cover. Both are worth doing and neither is hidden - but five minutes spent on the
-- unwatched ones buys strictly more, so they come out first.
local MIXED = {
    { id = "gatedA",   gate = "tools/a.js" },
    { id = "bareA" },
    { id = "gatedB",   gate = "tools/b.js" },
    { id = "bareB" },
    { id = "gatedC",   gate = "tools/c.js" },
}
local order = ns.ReadyChecks(MIXED, nil)
eq(#order, 5, "every ready check is still offered")
eq(order[1].id, "bareA", "the checks with no gate come FIRST")
eq(order[2].id, "bareB", "-- all of them")
eq(order[3].id, "gatedA", "then the gated ones")

-- STABLE within each group. Lua 5.1s table.sort is not a stable sort, and a ranked list that
-- reorders itself between two runs is a defect this project has already fixed twice elsewhere.
eq(order[4].id, "gatedB", "gated checks keep their declared order")
eq(order[5].id, "gatedC", "-- rather than an order that could differ between runs")
local again = ns.ReadyChecks(MIXED, nil)
for i = 1, #order do
    eq(again[i].id, order[i].id, "and the same list comes back the same way every time")
end

-- The partition must not lose or duplicate anything.
local allGated = ns.ReadyChecks({ MIXED[1], MIXED[3] }, nil)
eq(#allGated, 2, "a list of nothing but gated checks still returns all of them")
local allBare = ns.ReadyChecks({ MIXED[2], MIXED[4] }, nil)
eq(#allBare, 2, "and so does a list of nothing but unwatched ones")

-- Ordering must not resurrect a blocked check into the doable list.
local WITHBLOCK = {
    { id = "blocked", ready = function() return false, "the bank open" end },
    { id = "bare" },
}
local d2, b2 = ns.ReadyChecks(WITHBLOCK, nil)
eq(#d2, 1, "a blocked check is not pulled into the doable list by the reordering")
eq(d2[1].id, "bare", "only the doable one is offered")
eq(#b2, 1, "and the blocked one is still reported")

return failures, checks
`,
  "verifyready",
  "checklist readiness"
);
