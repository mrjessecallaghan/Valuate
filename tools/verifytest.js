#!/usr/bin/env node
/*
 * @gate The verify walkthrough hands out the right check
 *
 * Runs the REAL source of VersionOlder / VerifiedState / NextPendingCheck against a
 * synthetic checklist.
 *
 * Those three decide what `/valuate verify next` gives you and what the summary line
 * claims, and every way they can be wrong is quiet: a stale tick counted as finished, a
 * version compared as text so "0.9.0a" looks newer than "0.10.0a", an unknown recorded
 * version treated as old so a check nags forever. Each of those reads as a working
 * checklist that is simply wrong about what you have verified - which is worse than no
 * checklist, because the whole point of the thing is telling you what to trust.
 *
 * The functions are SLICED out of Valuate.lua rather than loaded with it: the core file
 * needs most of the WoW API to reach its end, and these three need none of it. Slicing
 * tests the shipped source rather than a copy of it - a copy would be one more
 * hand-maintained duplicate, which is the failure this toolchain exists to catch. A
 * failed slice throws; a truncated one will not compile as Lua. Neither can pass quietly.
 *
 * Usage:  node tools/verifytest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

function slice(name) {
  const m = lua.match(new RegExp("^local function " + name + "\\(([\\s\\S]*?)\\nend\\n", "m"));
  if (!m) {
    console.error(
      "  SLICE  could not find `local function " + name + "` in Valuate.lua - " +
        "it was renamed, moved or reshaped, so this gate is testing nothing"
    );
    process.exit(1);
  }
  return m[0];
}

const REAL = ["VersionOlder", "VerifiedState", "NextPendingCheck"].map(slice).join("\n");

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end

local OPTS = { verifiedChecks = {} }
Valuate = { version = "0.41.0a" }
function Valuate:GetOptions() return OPTS end

-- A synthetic list, so the gate tests the LOGIC and does not fail every time a real
-- check is added or its version revised.
VERIFY_CHECKS = {
    { id = "a", since = "0.20.0a" },
    { id = "b", since = "0.30.0a" },
    { id = "c", since = "0.40.0a" },
}

` + REAL + `

-- Nothing ticked: the first entry, and all three outstanding.
local c, i, n = NextPendingCheck()
ok(c and c.id == "a", "fresh list hands out the first check")
ok(i == 1, "fresh list reports index 1")
ok(n == 3, "fresh list counts all three pending, got " .. tostring(n))

-- Tick the first: advance, count drops.
OPTS.verifiedChecks.a = "0.41.0a"
c, i, n = NextPendingCheck()
ok(c and c.id == "b", "advances past a ticked check")
ok(i == 2, "the index follows the check, got " .. tostring(i))
ok(n == 2, "count drops to 2, got " .. tostring(n))

-- A tick OLDER than the check's own since is stale, so it comes round again even though
-- it is ticked. This is the whole reason the walkthrough exists.
OPTS.verifiedChecks.a = "0.10.0a"
OPTS.verifiedChecks.b = "0.41.0a"
OPTS.verifiedChecks.c = "0.41.0a"
c, i, n = NextPendingCheck()
ok(c and c.id == "a", "a stale tick is offered again, got " .. tostring(c and c.id))
ok(n == 1, "stale counts as pending, got " .. tostring(n))

-- Ticked at exactly the check's own since is current, not stale.
OPTS.verifiedChecks.a = "0.20.0a"
c, i, n = NextPendingCheck()
ok(c == nil, "ticked at exactly since is not stale, got " .. tostring(c and c.id))
ok(n == 0, "nothing pending when all current, got " .. tostring(n))

-- Newer than since is obviously current too.
OPTS.verifiedChecks.a = "0.41.0a"
c, i, n = NextPendingCheck()
ok(c == nil and n == 0, "a newer tick stays current")

-- Compared as NUMBERS: 0.9 is older than 0.10 as versions, newer as text.
ok(VersionOlder("0.9.0a", "0.10.0a") == true, "0.9.0a is older than 0.10.0a numerically")
ok(VersionOlder("0.10.0a", "0.9.0a") == false, "0.10.0a is not older than 0.9.0a")

-- "?" is what gets recorded when the addon cannot read its own version. Unknown is not
-- old: calling it stale would nag about a check that may well be current.
OPTS.verifiedChecks.a = "?"
c, i, n = NextPendingCheck()
ok(c == nil, "an unknown tick version is not treated as stale")

-- Unticking brings it back.
OPTS.verifiedChecks.b = nil
c, i, n = NextPendingCheck()
ok(c and c.id == "b", "an untick brings the check back")
ok(n == 1, "an untick restores the count")

return failures, checks
`,
  "verifytest",
  "the /valuate verify walkthrough"
);
