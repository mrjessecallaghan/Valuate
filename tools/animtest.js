#!/usr/bin/env node
/*
 * @gate Runs the animation engine against a mocked WoW API
 *
 * Runs ui/Animations.lua for real, against a mocked WoW API.
 *
 * The other gates are static: check.js parses, globals.js resolves scope, tocsync.js
 * compares lists. None of them execute a single line of Valuate, so a clamp with its
 * comparison the wrong way round, or a tween that never leaves the active list, passes
 * all of them and only shows up in the client.
 *
 * Animations.lua was the right file to start executing: its entire external surface is
 * CreateFrame plus one option read, so the mock is small enough to trust. It is also the
 * one file where a bug is systemic rather than local - every animated thing in the addon
 * runs through this driver.
 *
 * The fengari bootstrap and the WoW mock live in luaharness.js, shared with the other
 * runtime gates so there is exactly ONE idea of what the client does.
 *
 * Usage:  node tools/animtest.js        (run from the addon root or tools/)
 * Exits non-zero on the first failed assertion.
 */
"use strict";

const { load } = require("./luaharness");

const run = load(["ui/Shared.lua", "ui/Animations.lua"]);

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

-- ------------------------------------------------------- the easing invariant
-- Everything downstream leans on this: the driver clamps progress to 1 and calls
-- onUpdate one last time, so a tween lands exactly on its target IF AND ONLY IF its
-- easing returns exactly 1 at t=1. That is what lets Anim.setHeight fix its ease and
-- still land on the pixel, and it is why the onDone guards elsewhere are insurance
-- rather than load-bearing.
--
-- It was entirely untested, and an easing added later that overshoots or falls short
-- at the endpoint would break several unrelated things at once with no gate objecting.
-- outBack and outElastic both overshoot in the MIDDLE, which is the point of them -
-- the endpoints are what must be exact.
-- The two ends are held to deliberately DIFFERENT standards, because only one of them
-- is load-bearing:
--
--   t=1 must be EXACT. It is the resting state - a shortfall there is permanent and
--        visible (a panel stuck at 0.98 alpha, a window a pixel short).
--   t=0 only needs to be near. It is a state the driver never actually evaluates
--        (elapsed is always > 0 on the first frame), and outBack legitimately returns
--        2.2e-16 there: its formula is 1 + c3*u^3 + c1*u^2, which at u = -1 is
--        1 - 2.70158 + 1.70158 - exact in algebra, not in floating point. Demanding
--        exactness would mean rewriting a correct easing to satisfy a test.
local easingCount = 0
for name, fn in pairs(ns.Easing) do
    easingCount = easingCount + 1
    ok(fn(1) == 1, "easing '" .. name .. "' returns " .. tostring(fn(1)) .. " at t=1, not exactly 1")
    ok(math.abs(fn(0)) < 1e-9, "easing '" .. name .. "' starts at " .. tostring(fn(0)) .. ", not ~0")
end
ok(easingCount >= 6, "expected the full easing library; found only " .. easingCount)

-- ------------------------------------------------------------------ revealIn
-- Lands on EXACTLY 1. A panel resting at 0.98 is the failure this guards.
local panel = CreateFrame("Frame")
panel:SetAlpha(1)
Anim.revealIn(panel, 0)
ok(panel:GetAlpha() == 0, "revealIn must start from 0, not from wherever the frame was")
advance(MOTION.base * 2)
ok(panel:GetAlpha() == 1, "revealIn left alpha at " .. tostring(panel:GetAlpha()) .. ", not exactly 1")

-- Re-revealing REPLACES the reveal already running, rather than adding a second.
-- Cascades get re-triggered constantly - switching tabs, a scan landing while the
-- panel is open - and two tweens writing one frame's alpha is the fault this engine
-- exists to prevent. Harmless for alpha alone (both end at 1); NOT harmless for
-- anything carrying a value, which is how the Best Equipment count-ups could finish
-- on the previous scan's number.
local restarted = CreateFrame("Frame")
Anim.revealIn(restarted, 0)
advance(0.05, 3)
local firstHandle = restarted.__anim_revealin
Anim.revealIn(restarted, 0)
ok(restarted.__anim_revealin ~= nil, "revealIn should own its tween so it can be replaced")
ok(restarted.__anim_revealin ~= firstHandle, "re-revealing did not replace the running tween")
advance(MOTION.base * 2)
ok(restarted:GetAlpha() == 1, "a replaced reveal must still land at 1")

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
-- Routed through Valuate:ReportRuntimeError when it exists, so the failure reaches
-- /valuate errors instead of only scrolling past in chat. Defined on the mock HERE
-- rather than in the prelude, so the fallback path stays covered everywhere else.
local routed = {}
Valuate.ReportRuntimeError = function(_, key, err)
    table.insert(routed, tostring(key) .. ": " .. tostring(err))
end

local boom = CreateFrame("Frame")
Anim.tween({
    duration = 0.2,
    onUpdate = function() error("deliberate test explosion") end,
})
advance(1.0, 60)

local reports = 0
for _, line in ipairs(routed) do
    if line:find("deliberate test explosion", 1, true) then reports = reports + 1 end
end
ok(reports >= 1, "an erroring tween callback was not reported through Valuate:ReportRuntimeError")
ok(reports <= 1, "erroring tween reported " .. reports .. " times - it is looping, not cancelled")
Valuate.ReportRuntimeError = nil

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

-- ------------------------------------------- owned tweens on a plain table
-- ui/UpgradeArrows.lua depends on this: its rule is that nothing is ever written onto
-- a Blizzard frame, so it owns its tweens on its OWN record table instead of on the
-- item button. That only works because startProp does pure table access - it stores a
-- handle under a key and never calls a frame method. Pinned here because it is an
-- assumption about the engine made by a file the engine knows nothing about.
local plain = {}
local plainTicks = 0
Anim.owned(plain, "size", { duration = 0.3, onUpdate = function() plainTicks = plainTicks + 1 end })
advance(0.4, 20)
ok(plainTicks > 0, "an owned tween on a plain table never ran - the engine assumes a frame")
Anim.cancelProp(plain, "size")
ok(true, "cancelProp errored on a plain table")

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

-- --------------------------------------------------------------- Anim.setHeight
-- The main window's height has several writers across three files. They are only
-- safe to mix because this is the single entry point, so these check the contract
-- that makes that true rather than just "does it animate".
local win = CreateFrame("Frame")
win:SetHeight(600)

-- A snap must land immediately, with no frames in between.
Anim.setHeight(win, 800, false)
ok(win:GetHeight() == 800, "setHeight(animate=false) did not apply immediately")

-- THE safety property: a snap must KILL a running tween. Without this a plain
-- SetHeight during an animation is overwritten on the very next frame, and the
-- window springs back to a size nobody asked for.
Anim.setHeight(win, 600, true)
advance(0.05, 3)
Anim.setHeight(win, 750, false)
advance(0.5, 25)
ok(win:GetHeight() == 750,
    "a snap did not cancel the running height tween - the tween won, landing at " .. tostring(win:GetHeight()))

-- An animated change lands exactly on target, not near it.
win:SetHeight(600)
Anim.setHeight(win, 900, true)
ok(win:GetHeight() ~= 900, "setHeight(animate=true) jumped instead of animating")
advance(MOTION.base * 2)
near(win:GetHeight(), 900, "animated setHeight did not land on its target")

-- Sub-pixel changes snap: a 0.4px animation is a wasted frame budget.
win:SetHeight(500)
Anim.setHeight(win, 500.4, true)
ok(win:GetHeight() == 500.4, "a sub-pixel height change should snap, not animate")

-- Re-targeting mid-flight replaces rather than stacking.
win:SetHeight(400)
Anim.setHeight(win, 900, true)
advance(0.05, 3)
Anim.setHeight(win, 700, true)
advance(MOTION.base * 2)
near(win:GetHeight(), 700, "re-targeting an animated height did not land on the newest target")

-- Reduce Motion still lands exactly, and instantly.
__reduceMotion = true
win:SetHeight(300)
Anim.setHeight(win, 850, true)
ok(win:GetHeight() == 850, "Reduce Motion setHeight left the window at " .. tostring(win:GetHeight()))
__reduceMotion = false

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

return failures, checks`;

run(TESTS, "animtest", "ui/Animations.lua");
