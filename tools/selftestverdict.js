#!/usr/bin/env node
/*
 * @gate The self-test does not claim more than it examined
 *
 * Runs the REAL ns.SelfTestVerdict from Valuate.lua.
 *
 * `Valuate:RunSelfTest` needs a client, a character and a bag of gear, so no gate has ever
 * executed it — sixty-odd checks whose OUTPUT nothing has ever read back. The verdict is the
 * part of it that can be wrong in a way somebody acts on, so it lives apart from the checks and
 * is tested here with three numbers and no client at all.
 *
 * What was wrong with it: three blocks inside the self-test depend on the state of the
 * character running it. The item-API checks need something equipped, the junk sanity needs
 * AdiBags loaded, and the scan helpers need an active scale. Each was skipped silently, and the
 * verdict still printed **PASSED** — so a fresh character with no AdiBags could be told
 * everything was fine while a third of the checks never ran. "Self-test PASSED (42 checks)" is
 * the sentence somebody repeats back to you, and it was true and misleading at once.
 *
 * A skipped group is deliberately NOT a failure and is never worded as one. Nothing is broken;
 * the honest answer is a smaller claim, not a red one. Telling someone to fix a thing that is
 * not wrong is how a diagnostic stops being read at all.
 *
 * Usage:  node tools/selftestverdict.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const NL = String.fromCharCode(10);
const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const start = lua.indexOf("function ns.SelfTestVerdict(");
if (start < 0) {
  console.error(
    "  SLICE  could not find function ns.SelfTestVerdict in Valuate.lua - it was renamed or " +
      "folded back into RunSelfTest, so this gate is testing nothing"
  );
  process.exit(1);
}
const end = lua.indexOf(NL + "end" + NL, start);
const verdict = lua.slice(start, end + 5);

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
` + verdict + `

local V = ns.SelfTestVerdict

-- ---- a clean run, with nothing skipped ---------------------------------------------------------
local clean = V(42, 0, {})
eq(#clean, 1, "a clean run with nothing skipped is one line")
ok(clean[1]:find("PASSED", 1, true) ~= nil, "and says so")
ok(clean[1]:find("42", 1, true) ~= nil, "with the count")
eq(clean[1]:find("not run", 1, true), nil, "and claims nothing about groups it did not skip")

-- ---- THE ONE THAT MATTERS ----------------------------------------------------------------------
-- Passing while a third of the checks never ran is the sentence somebody repeats back to you, so
-- the count of what was missed belongs in the headline rather than a footnote below it.
local partial = V(42, 0, { "AdiBags junk classification - AdiBags is not loaded" })
ok(partial[1]:find("PASSED", 1, true) ~= nil, "a run with skips still passes - nothing is broken")
ok(partial[1]:find("1 group", 1, true) ~= nil,
   "but the HEADLINE says a group was not run")
eq(#partial, 2, "and the skipped group gets a line of its own")
ok(partial[2]:find("AdiBags", 1, true) ~= nil, "naming what was missed")
ok(partial[2]:find("not run", 1, true) ~= nil, "as not-run rather than as a failure")

-- ---- failures and skips are different things ------------------------------------------------------
local both = V(30, 3, {
    "item API - nothing equipped in the chest slot",
    "scan helpers - no active scale to run them against",
})
ok(both[1]:find("FAILED", 1, true) ~= nil, "a failing run says so")
ok(both[1]:find("3", 1, true) ~= nil, "with the failure count")
ok(both[1]:find("2 group", 1, true) ~= nil, "and the skip count beside it, not instead of it")
eq(#both, 3, "with a line per skipped group")

-- A skip is never coloured or worded as a failure. Nothing is broken, and sending someone to fix
-- a thing that is not wrong is how a diagnostic stops being read.
for _, line in ipairs(partial) do
    eq(line:find("FAIL", 1, true), nil, "a skip is never reported as a failure")
end

-- ---- bad input does not throw ----------------------------------------------------------------------
-- This runs at the END of a diagnostic. Erroring here would lose the whole report, which is the
-- one moment the report is worth most.
ok(pcall(V, nil, nil, nil), "no numbers at all is survivable")
ok(pcall(V, 5, 0), "and so is omitting the skip list")
local bare = V(5, 0)
eq(#bare, 1, "an omitted skip list behaves as an empty one")

return failures, checks
`,
  "selftestverdict",
  "the self-test verdict"
);
