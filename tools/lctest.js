#!/usr/bin/env node
/*
 * @gate The LootCollector filter is inclusive on doubt
 *
 * Runs the REAL Score.lua from Valuate-LootCollector.
 *
 * That addon hides rows from someone else's list. Everything about it is therefore asymmetric:
 * a row shown unnecessarily costs a glance, and a row hidden wrongly costs a worldforged
 * upgrade you will never know existed, because the only evidence of the mistake is an absence.
 *
 * So the assertions here are mostly about the cases where the addon does NOT know:
 *
 *   * the client has not cached the item yet - constant on a fresh login, and nothing at all
 *     to do with whether the item is any good;
 *   * there is no active scale, so there is nothing to rank against;
 *   * the evaluation budget ran out before this row was reached.
 *
 * All three arrive as "unknown", and all three must leave the row on screen. A filter that
 * treats "I could not tell" as "no" is the same bug three times.
 *
 * The other half is that non-gear is never touched: the Mystic Scrolls and vendor tabs are not
 * lists of gear, and a stat filter that emptied them would look like a broken addon.
 *
 * NOTE: the source is in a SIBLING addon. This skips rather than fails when it is absent -
 * see tools/tsmratiotest.js for the argument.
 *
 * Usage:  node tools/lctest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const SRC = path.resolve(ADDON_ROOT, "..", "Valuate-LootCollector", "Score.lua");
if (!fs.existsSync(SRC)) {
  console.log("SKIP  Valuate-LootCollector is not installed next to this addon; nothing to check.");
  process.exit(0);
}

const run = load([]);

// The whole file, run as the addon runs it: `local _, ns = ...` with a table pushed in. No
// slicing, because Score.lua is pure by construction - that is why it is a separate file.
const lua = fs.readFileSync(SRC, "utf8");

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
-- loadstring in 5.1 (the client), load in 5.3 (fengari, which runs these gates).
local compile = loadstring or load
local chunk = assert(compile(${JSON.stringify(lua)}, "@Valuate-LootCollector/Score.lua"))
chunk("Valuate-LootCollector", ns)

-- ---- inclusive on doubt --------------------------------------------------------------------
-- The three ways of not knowing, which are three different situations and one answer.
for _, mode in ipairs({ "upgrades", "stats" }) do
    ok(ns.Keep(mode, true, ns.UNKNOWN),
       "an item we could not evaluate stays in the list (" .. mode .. ")")
    ok(ns.Keep(mode, true, nil),
       "and so does one nobody has looked at yet (" .. mode .. ")")
end

-- ---- what each mode actually filters ---------------------------------------------------------
ok(ns.Keep("upgrades", true, "upgrade"), "an upgrade survives the upgrades filter")
ok(not ns.Keep("upgrades", true, "stats"),
   "gear your scale merely likes does not - that is what the other mode is for")
ok(not ns.Keep("upgrades", true, "worthless"), "and gear it scores at zero does not")

ok(ns.Keep("stats", true, "upgrade"), "an upgrade survives the my-stats filter too")
ok(ns.Keep("stats", true, "stats"), "along with anything your scale values")
ok(not ns.Keep("stats", true, "worthless"), "but not what it scores at zero")

-- Off means off. Not "off means a permissive filter" - the hook returns early on this, so a
-- true here is the difference between the addon costing nothing and costing a full pass.
for _, verdict in ipairs({ "upgrade", "stats", "worthless", ns.UNKNOWN }) do
    ok(ns.Keep("off", true, verdict), "off keeps everything: " .. tostring(verdict))
end
ok(ns.Keep(nil, true, "worthless"), "and so does a mode nobody set")

-- ---- non-gear is never touched -----------------------------------------------------------
-- Mystic scrolls and black-market vendors are not things a stat scale ranks. A filter that
-- emptied the Mystic Scrolls tab because none of them are chest pieces reads as broken.
for _, mode in ipairs({ "upgrades", "stats" }) do
    ok(ns.Keep(mode, false, "worthless"),
       "a non-gear row is kept even when scored worthless (" .. mode .. ")")
end

-- ---- the verdict thresholds -----------------------------------------------------------------
eq(ns.Verdict(nil, false), ns.UNKNOWN, "stats that could not be read are not a judgement")
eq(ns.Verdict(nil, true), ns.UNKNOWN, "even if something claimed it was an upgrade")
eq(ns.Verdict(0, false), "worthless", "a scale that scores it at zero wants none of it")
eq(ns.Verdict(-5, false), "worthless", "nor below zero, which a banned stat can produce")
eq(ns.Verdict(120, false), "stats", "a scored item your gear already beats is 'stats'")
eq(ns.Verdict(120, true), "upgrade", "and one that beats your gear is an upgrade")

-- ---- 'is this gear' has three answers, not two ----------------------------------------------
-- The nil is the point. An uncached item has no equipLoc yet, and calling that "not gear"
-- would let it through as furniture rather than because we could not tell - and it would
-- STAY that way once the real answer arrived, because the row was never re-examined.
eq(ns.IsGear(nil, false), nil, "an uncached item is not yet known to be gear or not")
eq(ns.IsGear("INVTYPE_CHEST", false), nil,
   "and an equipLoc read while uncached is not trusted either")
eq(ns.IsGear("INVTYPE_CHEST", true), true, "a cached chest piece is gear")
eq(ns.IsGear("", true), false, "a cached item with no slot is not")
eq(ns.IsGear(nil, true), false, "nor one whose equipLoc came back nil once cached")
eq(ns.IsGear("INVTYPE_BAG", true), false, "and a bag is not gear a stat scale ranks")

-- ---- the mode cycle ---------------------------------------------------------------------------
-- One function, because the button and the slash command both use it. Two copies would drift
-- into different orders and the button would appear to skip a state.
eq(ns.NextMode("off"), "upgrades", "the cycle starts by filtering to upgrades")
eq(ns.NextMode("upgrades"), "stats", "then widens to anything your scale values")
eq(ns.NextMode("stats"), "off", "then back to off")
eq(ns.NextMode(nil), "off", "and anything unrecognised lands on off, not on a filter")

-- It must be a CYCLE - three steps returns to the start, so no state is unreachable.
eq(ns.NextMode(ns.NextMode(ns.NextMode("off"))), "off", "three clicks is a round trip")

-- Every mode the cycle can produce is one the labels know about, or the button goes blank.
local seen, m = {}, "off"
for _ = 1, #ns.MODES do
    seen[m] = true
    ok(ns.ModeLabel(m) ~= nil and ns.ModeLabel(m) ~= "", "'" .. m .. "' has a label")
    m = ns.NextMode(m)
end
for _, mode in ipairs(ns.MODES) do
    ok(seen[mode], "the cycle reaches every declared mode: " .. mode)
end

-- The labels have to differ, or the button says the same thing in three states.
ok(ns.ModeLabel("off") ~= ns.ModeLabel("upgrades"), "off and upgrades read differently")
ok(ns.ModeLabel("upgrades") ~= ns.ModeLabel("stats"), "so do upgrades and my-stats")

-- ---- the pending count ------------------------------------------------------------------------
-- On the button while the background pass runs. Without it a list narrowing under you is
-- indistinguishable from a filter that has finished and found little.
eq(ns.CountPending({ "upgrade", "stats", "worthless" }), 0, "nothing outstanding counts zero")
eq(ns.CountPending({ "upgrade", ns.UNKNOWN, ns.UNKNOWN }), 2, "two unknowns count two")
eq(ns.CountPending({}), 0, "an empty list counts zero")
eq(ns.CountPending(nil), 0, "and so does no list at all, rather than erroring")

return failures, checks
`,
  "lctest",
  "the LootCollector filter"
);
