#!/usr/bin/env node
/*
 * Runs ui/Animations.lua for real, against a mocked WoW API.
 *
 * Every other gate here is static: check.js parses, globals.js resolves scope,
 * tocsync.js compares lists. None of them execute a single line of Valuate, so a
 * clamp with its comparison the wrong way round, or a tween that never leaves the
 * active list, passes all five and only shows up in the client.
 *
 * Animations.lua is the right file to start executing, because its entire external
 * surface is CreateFrame plus one option read - so the mock below is small enough to
 * trust. The engine is also the one file where a bug is systemic rather than local:
 * every animated thing in the addon runs through this driver.
 *
 * Usage:  node tools/animtest.js        (run from the addon root or tools/)
 * Exits non-zero on the first failed assertion.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");

// The files under test, in .toc order. Shared.lua first: Animations.lua reads
// ns.MOTION at call time, so the tokens must already be published.
const FILES = ["ui/Shared.lua", "ui/Animations.lua"];

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function fail(msg) {
  console.error("  " + msg);
  process.exit(1);
}

function runLua(src, chunkName, nargs) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@" + chunkName)) !== lua.LUA_OK) {
    fail("LOAD FAILED  " + chunkName + ": " + to_jsstring(lua.lua_tostring(L, -1)));
  }
  // Args were pushed by the caller *before* the chunk, so rotate them above it.
  if (nargs) lua.lua_insert(L, -1 - nargs);
  if (lua.lua_pcall(L, nargs || 0, 0, 0) !== lua.LUA_OK) {
    fail("RUNTIME ERROR in " + chunkName + ": " + to_jsstring(lua.lua_tostring(L, -1)));
  }
}

/*
 * The mock. Deliberately minimal and deliberately dumb - a mock that reimplements
 * behaviour can agree with a broken addon. It records, it does not decide.
 *
 * Two 3.3.5-vs-5.3 shims: math.pow was removed in 5.3 (outElastic uses it) and
 * `unpack` moved to table.unpack. Both exist in the game client, so restoring them
 * is matching the target runtime, not papering over anything.
 */
const PRELUDE = `
math.pow = math.pow or function(a, b) return a ^ b end
unpack = unpack or table.unpack

__frames = {}
UIParent = { __name = "UIParent" }

function CreateFrame(frameType, name, parent)
    local f = {
        __type = frameType, __name = name, __scripts = {},
        __alpha = 1, __scale = 1,
        __fill = {0, 0, 0, 1}, __border = {0, 0, 0, 1},
    }
    function f:SetScript(which, fn) self.__scripts[which] = fn end
    function f:GetScript(which) return self.__scripts[which] end
    function f:SetAlpha(a) self.__alpha = a end
    function f:GetAlpha() return self.__alpha end
    function f:SetScale(s) self.__scale = s end
    function f:GetScale() return self.__scale end
    function f:SetBackdropColor(r, g, b, a) self.__fill = {r, g, b, a} end
    function f:GetBackdropColor() return unpack(self.__fill) end
    function f:SetBackdropBorderColor(r, g, b, a) self.__border = {r, g, b, a} end
    function f:GetBackdropBorderColor() return unpack(self.__border) end
    table.insert(__frames, f)
    return f
end

-- ReduceMotion() reads this. Off by default; a test flips it.
__reduceMotion = false
Valuate = { GetOptions = function() return { reduceMotion = __reduceMotion } end }

-- ReportAnimError print()s. Capture instead of spewing into the gate output.
__printed = {}
local realPrint = print
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    table.insert(__printed, table.concat(parts, " "))
end

__ns = {}
`;

runLua(PRELUDE, "prelude", 0);

for (const rel of FILES) {
  const src = fs.readFileSync(path.join(ADDON_ROOT, rel), "utf8").replace(/^﻿/, "");
  // Addon files are called as `local _, ns = ...`, so push both varargs.
  lua.lua_pushstring(L, to_luastring("Valuate"));
  lua.lua_getglobal(L, to_luastring("__ns"));
  runLua(src, rel, 2);
}

/*
 * The assertions.
 *
 * Written in Lua rather than marshalled field-by-field into JS: these are statements
 * about Lua values, and reading them here as Lua keeps the test the same shape as the
 * thing it tests.
 */
const TESTS = `
local ns = __ns
local Anim, MOTION = ns.Anim, ns.MOTION
local failures = {}
local checks = 0

local function ok(cond, msg)
    checks = checks + 1
    if not cond then table.insert(failures, msg) end
end
local function near(a, b, msg, tol)
    ok(a and math.abs(a - b) <= (tol or 0.0001), (msg or "") .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

-- The driver is the single frame Animations.lua creates at load.
local driver
for _, f in ipairs(__frames) do
    if f.__scripts.OnUpdate then driver = f end
end
ok(driver ~= nil, "animation driver frame was never created")
if not driver then return failures end

-- Advance the engine by "seconds", in "steps" slices, the way OnUpdate is fed.
local function advance(seconds, steps)
    steps = steps or 30
    for _ = 1, steps do driver.__scripts.OnUpdate(driver, seconds / steps) end
end

-- ---------------------------------------------------------------- staggerFor
-- The formula's whole point is that the total cascade stays bounded as the item
-- count grows. Assert the PROPERTY, not the arithmetic - restating gap = window/(n-1)
-- would just be the implementation typed twice.
ok(Anim.staggerFor(0) == 0, "staggerFor(0) must be 0 - nothing to stagger")
ok(Anim.staggerFor(1) == 0, "staggerFor(1) must be 0 - a lone item has no gap")

for _, n in ipairs({2, 3, 5, 8, 17, 40, 200}) do
    local gap = Anim.staggerFor(n)
    ok(gap <= MOTION.stagger + 1e-9, "staggerFor(" .. n .. ") exceeds the max gap")
    ok(gap >= MOTION.staggerMin - 1e-9, "staggerFor(" .. n .. ") is under the min gap")
    -- Bounded total: at or below the window, except where staggerMin forces it wider.
    local total = gap * (n - 1)
    local floorTotal = MOTION.staggerMin * (n - 1)
    ok(total <= math.max(MOTION.cascade, floorTotal) + 1e-9,
        "cascade of " .. n .. " runs " .. string.format("%.3f", total) .. "s, past its window")
end

-- Monotonic: more items must never mean a wider gap, or the bound leaks.
local prev = Anim.staggerFor(2)
for n = 3, 60 do
    local gap = Anim.staggerFor(n)
    ok(gap <= prev + 1e-9, "staggerFor(" .. n .. ") is wider than staggerFor(" .. (n - 1) .. ")")
    prev = gap
end

-- ------------------------------------------------------------------ revealIn
-- Lands on EXACTLY 1. A panel resting at 0.98 is the failure this guards.
local panel = CreateFrame("Frame")
panel:SetAlpha(1)
Anim.revealIn(panel, 0)
ok(panel:GetAlpha() == 0, "revealIn must start from 0, not from wherever the frame was")
advance(MOTION.base * 2)
ok(panel:GetAlpha() == 1, "revealIn left alpha at " .. tostring(panel:GetAlpha()) .. ", not exactly 1")

-- Delay is honoured: still invisible before its turn comes round.
local delayed = CreateFrame("Frame")
Anim.revealIn(delayed, 0.5)
advance(0.3)
ok(delayed:GetAlpha() == 0, "revealIn started before its delay elapsed")
advance(0.5 + MOTION.base)
ok(delayed:GetAlpha() == 1, "delayed revealIn never finished")

-- ------------------------------------------------------------- reduce motion
-- The accessibility path must reach the SAME end state, not a different one.
__reduceMotion = true
local instant = CreateFrame("Frame")
Anim.revealIn(instant, 5.0)
ok(instant:GetAlpha() == 1, "Reduce Motion must apply the final state immediately, even with a delay")
local popped = CreateFrame("Frame")
Anim.popIn(popped, 0.5)
ok(popped:GetAlpha() == 1, "Reduce Motion popIn left alpha at " .. tostring(popped:GetAlpha()))
ok(popped:GetScale() == 1, "Reduce Motion popIn left scale at " .. tostring(popped:GetScale()))

-- onDone must fire on the short-circuit too. Checking only alpha misses this: alpha
-- comes from onUpdate, so a Reduce Motion path that skipped onDone entirely would
-- still look right here while silently dropping every completion callback.
local doneRan = false
Anim.tween({ duration = 0.3, onDone = function() doneRan = true end })
ok(doneRan, "Reduce Motion skipped onDone - completion callbacks would never fire")
__reduceMotion = false

-- ------------------------------------------------------- custom easing lands
-- The onDone guards across this engine exist for easings that do NOT terminate at 1.
-- Every built-in one does, so without this case those guards are untested and could
-- be deleted with no gate objecting. A caller may pass any function it likes.
local sloppy = function(t) return t * 0.97 end   -- never reaches 1
local shortfall = CreateFrame("Frame")
Anim.revealIn(shortfall, 0, MOTION.base, sloppy)
advance(MOTION.base * 2)
ok(shortfall:GetAlpha() == 1,
    "revealIn with a non-terminating ease rested at " .. tostring(shortfall:GetAlpha()) .. ", not 1")

local landed = nil
Anim.number(CreateFrame("Frame"), "sloppy", 0, 4.4, MOTION.base, function(v) landed = v end, sloppy)
advance(MOTION.base * 2)
near(landed, 4.4, "Anim.number with a non-terminating ease did not land on its target")

-- ------------------------------------------------------------------- no leak
-- WoW never frees frames, and this list is walked every frame forever. A tween that
-- completes but is not removed costs a little on every frame for the rest of the
-- session, and nothing on screen looks wrong.
local before = #__printed
for i = 1, 50 do Anim.revealIn(CreateFrame("Frame"), 0) end
advance(MOTION.base * 3)
-- A drained list means the next OnUpdate returns on its first line. Prove it by
-- checking a fresh tween still runs (the list is live, just empty).
local after = CreateFrame("Frame")
Anim.revealIn(after, 0)
advance(MOTION.base * 2)
ok(after:GetAlpha() == 1, "engine stopped driving tweens after a batch completed")

-- --------------------------------------------------------- error containment
-- An erroring callback used to fail again every frame forever, because the code that
-- removes the tween sits past the error. Assert it is reported ONCE and dropped.
local boom = CreateFrame("Frame")
Anim.tween({
    duration = 0.2,
    onUpdate = function() error("deliberate test explosion") end,
})
advance(1.0, 60)
local reports = 0
for _, line in ipairs(__printed) do
    if line:find("deliberate test explosion", 1, true) then reports = reports + 1 end
end
ok(reports >= 1, "an erroring tween callback was never reported")
ok(reports <= 1, "erroring tween reported " .. reports .. " times - it is looping, not cancelled")

-- ...and the engine still works afterwards. Containment that stops everything else
-- is not containment.
local survivor = CreateFrame("Frame")
Anim.revealIn(survivor, 0)
advance(MOTION.base * 2)
ok(survivor:GetAlpha() == 1, "engine stopped working after a callback errored")

-- --------------------------------------------------------------- Anim.number
-- Must land exactly on the target: a score reading 4.39 instead of 4.4 forever is
-- the same class of bug as the 0.98 alpha.
local seen = nil
local owner = CreateFrame("Frame")
Anim.number(owner, "test", 0, 4.4, MOTION.count, function(v) seen = v end)
advance(MOTION.count * 2)
near(seen, 4.4, "Anim.number did not land on its target")

-- Negligible change short-circuits rather than animating.
seen = nil
Anim.number(owner, "test2", 2.0, 2.0, MOTION.count, function(v) seen = v end)
ok(seen == 2.0, "Anim.number should set instantly when there is nothing to animate")

-- ----------------------------------------------------------------- Anim.owned
-- The point of owned tweens is that re-triggering REPLACES rather than stacks. This
-- is what a bare frame:SetScript("OnUpdate", ...) cannot give you, and getting it
-- wrong is invisible: two tweens writing the same property just look like jitter.
local ownedFrame = CreateFrame("Frame")
local aTicks, bTicks = 0, 0
Anim.owned(ownedFrame, "prop", { duration = 0.4, onUpdate = function() aTicks = aTicks + 1 end })
advance(0.1, 5)
local aAtSwap = aTicks
Anim.owned(ownedFrame, "prop", { duration = 0.4, onUpdate = function() bTicks = bTicks + 1 end })
advance(0.6, 30)
ok(aTicks == aAtSwap, "re-triggering an owned tween left the previous one running (stacking)")
ok(bTicks > 0, "the replacing owned tween never ran")

-- Cancelling must NOT run onDone. The replacement owns the final state; running the
-- cancelled tween's cleanup in between is what would snap a frame back mid-animation.
local doneAfterCancel = false
Anim.owned(ownedFrame, "cleanup", { duration = 0.4, onDone = function() doneAfterCancel = true end })
advance(0.1, 5)
Anim.owned(ownedFrame, "cleanup", { duration = 0.4 })
ok(not doneAfterCancel, "cancelling an owned tween ran its onDone - the replacement should own cleanup")
advance(0.6, 30)

-- Different property keys on ONE frame must coexist: that is what makes this usable
-- for a frame that already animates something else.
local coA, coB = 0, 0
Anim.owned(ownedFrame, "alpha", { duration = 0.3, onUpdate = function() coA = coA + 1 end })
Anim.owned(ownedFrame, "scale", { duration = 0.3, onUpdate = function() coB = coB + 1 end })
advance(0.5, 25)
ok(coA > 0 and coB > 0, "two different owned properties on one frame cancelled each other")

-- ------------------------------------------------------------- Anim.cancelProp
-- "Stop animating this and give me the property back." The pressed-button case: a
-- hover fade must actually stop, or it overwrites the pressed colour a frame later.
local pressed = CreateFrame("Button")
pressed:SetBackdropColor(0, 0, 0, 1)
pressed:SetBackdropBorderColor(0, 0, 0, 1)
ns.TweenBackdrop(pressed, {1, 1, 1, 1}, {1, 1, 1, 1}, 0.4)
advance(0.1, 5)
Anim.cancelProp(pressed, "backdrop")
pressed:SetBackdropColor(0.5, 0.5, 0.5, 1)      -- what OnMouseDown does
advance(0.5, 25)
local pr = pressed:GetBackdropColor()
near(pr, 0.5, "a cancelled backdrop tween kept writing - the pressed colour was overwritten")

-- Cancelling must not disturb a DIFFERENT property on the same frame.
local multi = CreateFrame("Frame")
local otherTicks = 0
Anim.owned(multi, "keep", { duration = 0.4, onUpdate = function() otherTicks = otherTicks + 1 end })
Anim.owned(multi, "drop", { duration = 0.4 })
Anim.cancelProp(multi, "drop")
local atCancel = otherTicks
advance(0.3, 15)
ok(otherTicks > atCancel, "cancelProp took down an unrelated property on the same frame")

-- Safe on a frame that was never animated, and on an already-finished tween.
Anim.cancelProp(CreateFrame("Frame"), "never")
Anim.cancelProp(pressed, "backdrop")
ok(true, "cancelProp errored on a frame with no such tween")

-- -------------------------------------------------------------- TweenBackdrop
-- Reads the CURRENT colour as its start, so an interrupted hover resumes from where
-- it actually is rather than snapping back.
local btn = CreateFrame("Button")
btn:SetBackdropColor(0, 0, 0, 1)
btn:SetBackdropBorderColor(0, 0, 0, 1)
ns.TweenBackdrop(btn, {1, 1, 1, 1}, {1, 1, 1, 1}, MOTION.fast)
advance(MOTION.fast * 2)
local r = btn:GetBackdropColor()
near(r, 1, "TweenBackdrop did not reach its target fill")

return failures, checks
`;

if (lauxlib.luaL_loadbuffer(L, to_luastring(TESTS), null, to_luastring("@animtest")) !== lua.LUA_OK) {
  fail("TEST LOAD FAILED: " + to_jsstring(lua.lua_tostring(L, -1)));
}
if (lua.lua_pcall(L, 0, 2, 0) !== lua.LUA_OK) {
  fail("TEST ERROR: " + to_jsstring(lua.lua_tostring(L, -1)));
}

const checks = lua.lua_tointeger(L, -1);
lua.lua_pop(L, 1);

const failures = [];
const n = lauxlib.luaL_len(L, -1);
for (let i = 1; i <= n; i++) {
  lua.lua_geti(L, -1, i);
  failures.push(to_jsstring(lua.lua_tostring(L, -1)));
  lua.lua_pop(L, 1);
}

if (failures.length) {
  for (const f of failures) console.error("  FAIL  " + f);
  console.error("\nui/Animations.lua FAILED " + failures.length + " of " + checks + " checks.");
  process.exit(1);
}
console.log("OK  ui/Animations.lua passed " + checks + " runtime checks against a mocked WoW API.");
