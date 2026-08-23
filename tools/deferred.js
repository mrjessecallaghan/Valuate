#!/usr/bin/env node
/*
 * @gate A deferred callback that breaks is reported, not lost
 *
 * Runs the real ValuateAfter from Valuate.lua against all three timer flavours.
 *
 * The frame handler wraps OnEvent in a pcall and reports whatever breaks, once per event,
 * into /valuate errors. Work handed to a timer escapes every bit of that: it runs on
 * Blizzard's ticker, so a bug there is a raw Lua error on the player's screen and this addon
 * never learns it happened.
 *
 * That is not a hypothetical. The v0.204.0a format crash was deferred by a tick, and its
 * traceback runs through SharedXML/Util/Timer.lua rather than through anything in this addon
 * - which is exactly why it reached a player before it reached /valuate errors.
 *
 * Deferring is common in Valuate.lua and deliberately so: profession and vendor windows
 * populate their lists AFTER their event fires, so reading a tick later is correct rather
 * than a workaround. That makes this the one wrapper worth having.
 *
 * Three flavours, because a client picks one and this addon must behave the same on all of
 * them: C_Timer.NewTimer, C_Timer.After, and no C_Timer at all. A gate that only drove the
 * flavour this machine happens to model would prove nothing about the other two, and the
 * fallback branch is precisely the one nobody looks at.
 *
 * The assertion that matters most is not "an error is caught" - it is that two DIFFERENT
 * failing sites get two DIFFERENT keys. Reporting is once-per-key by design, so that a timer
 * firing every second cannot fill the chat with one line. Key them all as "deferred" and the
 * first deferred bug of a session silences every other one for good, which is the same
 * mistake pointing the other way.
 *
 * Usage:  node tools/deferred.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local timerFramePool = \{\}/m,
  /^local function ValuateAfter\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error(
      "  SLICE  could not find " + re + " in Valuate.lua - this gate is testing nothing"
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
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

tinsert, tremove = table.insert, table.remove

-- The reporter, recorded rather than printed. Once-per-key is the REAL one's behaviour, so
-- it is modelled here too: a mock that happily records the same key twice would let a broken
-- key scheme look fine.
REPORTS, ORDER = {}, {}
Valuate = {}
function Valuate:ReportRuntimeError(key, err)
    if REPORTS[key] then return end
    REPORTS[key] = tostring(err)
    ORDER[#ORDER + 1] = key
end

` + sliced.join("\n") + `

local function reset() REPORTS, ORDER = {}, {} end

-- Two callbacks that fail on DIFFERENT lines of this chunk. Kept adjacent on purpose: their
-- file:line strings differ only in the number, which is the whole point.
local function boomA() error("first thing went wrong") end
local function boomB() error("second thing went wrong") end

-- ---- flavour 1: C_Timer.NewTimer (what this client ships) -----------------------------------
local fired
C_Timer = { NewTimer = function(_, cb) fired = cb return { native = true } end }

reset()
local handle = ValuateAfter(0.2, boomA)
ok(handle ~= nil, "NewTimer still returns a handle")
ok(fired ~= nil, "and hands a callback to the timer")
ok(pcall(fired), "a callback that errors does NOT escape into the ticker")
eq(#ORDER, 1, "it is reported instead")
ok(ORDER[1] and ORDER[1]:find("deferred", 1, true) ~= nil, "as a deferred failure")

-- THE ONE THAT MATTERS. Once-per-key is deliberate, so the key has to identify the SITE.
-- Key everything "deferred" and the first deferred bug of a session hides every later one.
ValuateAfter(0.2, boomB)
pcall(fired)
eq(#ORDER, 2, "a DIFFERENT failing site gets its own key rather than being swallowed")
ok(ORDER[1] ~= ORDER[2], "and the two keys differ")

-- The pair: the SAME site twice is still reported once. Without this, a timer that re-arms
-- every second would fill the chat with one line, which is what the rule exists to stop.
ValuateAfter(0.2, boomA)
pcall(fired)
eq(#ORDER, 2, "the same site failing again is not reported a second time")

-- ---- a callback that WORKS is untouched ------------------------------------------------------
reset()
local ran, gotArg = false, nil
ValuateAfter(0.2, function(a) ran = true gotArg = a end)
fired("timer-object")
ok(ran, "a callback that succeeds still runs")
eq(gotArg, "timer-object",
   "and its arguments are FORWARDED - a client may hand the timer to its own callback")
eq(#ORDER, 0, "with nothing reported")

-- ---- flavour 2: C_Timer.After (no native cancel) ---------------------------------------------
reset()
fired = nil
C_Timer = { After = function(_, cb) fired = cb end }

local h2 = ValuateAfter(0.2, boomA)
ok(h2 and h2.Cancel ~= nil, "the After branch still returns something cancelable")
ok(pcall(fired), "an error here does not escape either")
eq(#ORDER, 1, "and is reported")

-- Cancel still wins. Reporting must not have turned a cancelled timer into one that runs.
reset()
local h3 = ValuateAfter(0.2, boomA)
h3:Cancel()
ok(pcall(fired), "a cancelled timer fires nothing")
eq(#ORDER, 0, "so nothing is reported for it")

-- ---- flavour 3: no C_Timer at all -------------------------------------------------------------
-- The branch nobody looks at, on the clients least likely to be tested.
reset()
C_Timer = nil
local h4 = ValuateAfter(0.01, boomA)
ok(h4 ~= nil, "the OnUpdate fallback returns a handle")
local frame = h4.frame
ok(frame ~= nil, "with a frame behind it")
if frame and frame.__scripts and frame.__scripts.OnUpdate then
    ok(pcall(frame.__scripts.OnUpdate, frame, 5), "a fallback timer's error does not escape")
    eq(#ORDER, 1, "and is reported the same way as the other two flavours")
end

return failures, checks
`,
  "deferred",
  "deferred callbacks"
);
