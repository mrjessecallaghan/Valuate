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

const REAL = ["VersionOlder", "VerifiedState", "NextPendingCheck", "PrintVerifyCheck"]
  .map(slice)
  .join("\n");

/* ---------------------------------------------------------------------------
 * The REAL list, checked statically: does it still describe the addon that ships?
 *
 * This checklist is the only evidence some behaviours will ever have, and it stopped
 * growing at 0.64.0a while the addon went on to 0.89.0a - twenty-five releases, including
 * the CoA template set, the new secondaries, wardrobe collecting and the AdiBags button,
 * every one of them resting on an assumption about the client that nothing here can test.
 *
 * A checklist that quietly falls behind is worse than a short one: `/valuate verify`
 * reports "nothing pending" and sounds like assurance. So the newest entry has to stay
 * within sight of the .toc. There is no escape hatch on purpose - shipping ten minor
 * releases with nothing a human should look at is itself the thing worth being told.
 * ------------------------------------------------------------------------- */
const LAG_ALLOWED = 10;

const listBlock = lua.match(/^local VERIFY_CHECKS = \{[\s\S]*?\n\}/m);
if (!listBlock) {
  console.error("  SLICE  could not find `local VERIFY_CHECKS` in Valuate.lua - this gate tests nothing");
  process.exit(1);
}
const entries = [...listBlock[0].matchAll(/\bid = "([^"]+)",\s*since = "(\d+)\.(\d+)\.(\d+)a"/g)];
if (entries.length === 0) {
  console.error("  SLICE  VERIFY_CHECKS parsed to zero entries - the shape changed");
  process.exit(1);
}

const seen = new Map();
for (const [, id] of entries) {
  // A duplicate id silently shares one tick in verifiedChecks, so verifying either marks
  // both done - the exact failure this whole checklist exists to prevent.
  if (seen.has(id)) {
    console.error(`Two verify checks share the id "${id}". Ticking one would tick both.`);
    process.exit(1);
  }
  seen.set(id, true);
}

const toc = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.toc"), "utf8");
const tocV = toc.match(/^## Version:\s*(\d+)\.(\d+)\.(\d+)a/m);
if (!tocV) {
  console.error("  Could not read `## Version:` from Valuate.toc");
  process.exit(1);
}
const tocMinor = Number(tocV[2]);
const newest = entries.reduce((best, e) => {
  const minor = Number(e[3]);
  return minor > best.minor ? { minor, id: e[1], since: `${e[2]}.${e[3]}.${e[4]}a` } : best;
}, { minor: -1, id: null, since: null });

const lag = tocMinor - newest.minor;
if (lag > LAG_ALLOWED) {
  console.error(
    `The verify checklist has fallen ${lag} minor releases behind.\n` +
      `  newest check: ${newest.since} ("${newest.id}")\n` +
      `  Valuate.toc:  ${tocV[1]}.${tocV[2]}.${tocV[3]}a\n\n` +
      "Something has shipped since then that only the client can prove. Add a check for it\n" +
      "in VERIFY_CHECKS - or if nothing in those releases is worth a human's eyes, that is\n" +
      "itself worth being sure about before you raise LAG_ALLOWED."
  );
  process.exit(1);
}

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

-- ---- UNGATED checks are handed out first -------------------------------------
--
-- A check whose logic a build gate already executes is a smaller thing to confirm: the
-- behaviour is proven and what remains is whether it looks right. A check with no gate is
-- the only evidence that behaviour will ever have. Twenty-one of these is a long sitting and
-- it may stop half way, so the half that gets done should be the half nothing else covers.
VERIFY_CHECKS = {
    { id = "gated1",   since = "0.20.0a", gate = "tools/x.js" },
    { id = "ungated1", since = "0.20.0a" },
    { id = "gated2",   since = "0.20.0a", gate = "tools/y.js" },
    { id = "ungated2", since = "0.20.0a" },
}
OPTS.verifiedChecks = {}

c, i, n = NextPendingCheck()
ok(c and c.id == "ungated1", "the first ungated check wins over an earlier gated one")
ok(n == 4, "the pending count still covers everything, gated or not")

OPTS.verifiedChecks.ungated1 = "0.41.0a"
c = NextPendingCheck()
ok(c and c.id == "ungated2", "then the next ungated one, in list order")

OPTS.verifiedChecks.ungated2 = "0.41.0a"
c, i, n = NextPendingCheck()
ok(c and c.id == "gated1", "only once the unknowns are done does it fall back to the gated ones")
ok(n == 2, "...with the count still honest about how many are left")

OPTS.verifiedChecks.gated1 = "0.41.0a"
c = NextPendingCheck()
ok(c and c.id == "gated2", "and those keep their list order too")

OPTS.verifiedChecks.gated2 = "0.41.0a"
c, i, n = NextPendingCheck()
ok(c == nil and n == 0, "everything ticked means nothing pending")

-- A STALE gated check still yields to a fresh ungated one: staleness makes it pending, not
-- urgent, and the ungated check still carries more of the evidence.
OPTS.verifiedChecks = { gated1 = "0.10.0a" }
VERIFY_CHECKS[1].since = "0.30.0a"
c = NextPendingCheck()
ok(c and c.id == "ungated1", "a stale gated check does not jump the queue")

-- ---- an ungated check says it is ungated --------------------------------------------
-- NextPendingCheck has always handed these out first, which the assertions above cover. What
-- it did not do is say WHY: a gated check prints "Already proven: tools/x.js runs this logic -
-- you are checking it LOOKS right", and an ungated one printed nothing extra. So the checks
-- carrying the most weight were distinguishable from the ones carrying least only by an
-- absence.
--
-- That is the failure this entire checklist exists to catch, built into the checklist.
local printed = {}
local realPrint = print
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    printed[#printed + 1] = table.concat(parts, " ")
end
local function say(check)
    printed = {}
    PrintVerifyCheck(check, 1)
    return table.concat(printed, " | ")
end

local gatedText = say({ id = "g", since = "0.1.0a", title = "T", steps = "S", expect = "E",
                        broke = "B", gate = "tools/example.js" })
local ungatedText = say({ id = "u", since = "0.1.0a", title = "T", steps = "S", expect = "E",
                          broke = "B" })
print = realPrint

ok(gatedText:find("Already proven", 1, true) ~= nil, "a gated check says what already covers it")
ok(gatedText:find("tools/example.js", 1, true) ~= nil, "and names the gate")
ok(ungatedText:find("Nothing else proves this", 1, true) ~= nil,
   "an ungated check says so outright rather than leaving it to an absence")
ok(ungatedText:find("Already proven", 1, true) == nil,
   "and does not claim a gate it does not have")
-- The distinction is the point, not the wording: a rewrite may change either sentence and may
-- not make the two states read the same.
ok(gatedText ~= ungatedText, "the two states produce different text")

return failures, checks
`,
  "verifytest",
  `the /valuate verify walkthrough (${entries.length} checks listed, newest ${newest.since}, ${lag} behind the .toc)`
);
