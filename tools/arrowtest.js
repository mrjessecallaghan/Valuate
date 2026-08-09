#!/usr/bin/env node
/*
 * @gate The arrow pulse driver prunes in both motion modes
 *
 * Runs ui/UpgradeArrows.lua for real and ticks its OnUpdate.
 *
 * One driver animates every upgrade arrow on screen, walking a `shownArrows` set. Bags and
 * merchant windows close without notifying it, so the driver prunes as it goes: an arrow
 * whose texture is no longer visible is dropped and re-registers next time it is drawn.
 * Without that, the set only ever grows and the driver writes alpha to textures inside
 * closed bags on every frame for the rest of the session.
 *
 * The Reduce Motion branch used to return early with a loop of its own and no pruning. So
 * the leak existed only with the accessibility option ON - the branch least likely to be
 * noticed by whoever is watching the screen. Both modes now share one loop, and this gate
 * exercises both, because a fix that lives in one branch is what failed the first time.
 *
 * Usage:  node tools/arrowtest.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/UpgradeArrows.lua",
]);

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

local ns = __ns

-- ---- the world ---------------------------------------------------------------
local UPGRADES = {}
Valuate.GetOptions = function() return { showUpgradeArrows = true, reduceMotion = __reduceMotion } end
Valuate.IsItemLinkUpgrade = function(self, link) return UPGRADES[link] == true end

-- The driver is the LAST frame created at load, and it is the one carrying an OnUpdate.
-- Found rather than assumed: hardcoding an index into __frames would silently start
-- testing some other frame the day a texture is added above it.
local driver = nil
for i = #__frames, 1, -1 do
    if __frames[i].__scripts and __frames[i].__scripts.OnUpdate then
        driver = __frames[i]
        break
    end
end
ok(driver ~= nil, "found the pulse driver")

local function tick(dt)
    driver.__scripts.OnUpdate(driver, dt or 0.05)
end

-- A stand-in for a bag button. Its textures inherit visibility from it, which is what the
-- driver keys off: WoW hides the parent, the textures stop being visible, and no callback
-- tells the addon.
local function makeButton()
    local b = CreateFrame("Button")
    local made = {}
    b.CreateTexture = function(self)
        local t = CreateFrame("Texture")
        t.__owner = self
        t.IsVisible = function(tex) return tex.__shown and tex.__owner.__shown end
        table.insert(made, t)
        return t
    end
    b.__textures = made
    return b
end

-- How many arrows the driver is still walking. Counted by watching writes rather than by
-- reaching into the file-local set, which is not reachable from here - and should not be.
local function trackedCount()
    local seen = {}
    for _, f in ipairs(__frames) do
        if f.__type == "Texture" then f.__vertex = f.__vertex end
    end
    -- Mark every alpha, tick, and count which ones moved.
    local before = {}
    for _, f in ipairs(__frames) do
        if f.__type == "Texture" then
            before[f] = f.__alpha
            f:SetAlpha(-1)
        end
    end
    tick(0.05)
    local n = 0
    for _, f in ipairs(__frames) do
        if f.__type == "Texture" then
            if f.__alpha ~= -1 then n = n + 1 end
            if f.__alpha == -1 then f:SetAlpha(before[f]) end
        end
    end
    return n
end

local function runMode(label, reduce)
    __reduceMotion = reduce

    local b1, b2 = makeButton(), makeButton()
    UPGRADES["|Hitem:1|h[A]|h"] = true
    UPGRADES["|Hitem:2|h[B]|h"] = true

    ns.SetUpgradeArrow(b1, "|Hitem:1|h[A]|h")
    ns.SetUpgradeArrow(b2, "|Hitem:2|h[B]|h")

    -- Two arrows, two textures each (arrow + glow) = four written per tick.
    eq(trackedCount(), 4, label .. ": both arrows are being driven")

    -- Close the bag. WoW hides the PARENT; nothing calls back into the addon, and the
    -- arrow textures are never touched - their own __shown stays true.
    b1.__shown = false
    ok(b1.__textures[1]:IsVisible() == false, label .. ": hiding the button hides its textures")

    -- One tick to notice and drop it.
    tick(0.05)
    eq(trackedCount(), 2, label .. ": the closed bag's arrow was pruned")

    -- Closing everything leaves nothing to walk.
    b2.__shown = false
    tick(0.05)
    eq(trackedCount(), 0, label .. ": with every bag closed the driver walks nothing")

    -- Reopening re-registers, which is the half that makes pruning safe rather than
    -- destructive: a pruned arrow must come back.
    b1.__shown = true
    ns.SetUpgradeArrow(b1, "|Hitem:1|h[A]|h")
    eq(trackedCount(), 2, label .. ": reopening the bag brings its arrow back")

    ns.SetUpgradeArrow(b1, nil)
    tick(0.05)
    eq(trackedCount(), 0, label .. ": clearing an arrow deregisters it")
end

-- Motion ON: the pulse path, which always pruned.
runMode("motion", false)
-- Motion OFF: the accessibility path, which did not. Same assertions, deliberately.
runMode("reduce motion", true)

-- ---- and the alphas each mode writes ---------------------------------------
local b = makeButton()
UPGRADES["|Hitem:3|h[C]|h"] = true

__reduceMotion = true
ns.SetUpgradeArrow(b, "|Hitem:3|h[C]|h")
tick(0.05)
eq(b.__textures[2]:GetAlpha(), 1, "reduce motion leaves the arrow fully opaque")
eq(b.__textures[1]:GetAlpha(), 0.55, "reduce motion leaves the glow at a fixed alpha")

__reduceMotion = false
local moved = false
local last = b.__textures[1]:GetAlpha()
for _ = 1, 12 do
    tick(0.05)
    if math.abs(b.__textures[1]:GetAlpha() - last) > 0.001 then moved = true end
end
ok(moved, "with motion on, the glow alpha actually changes between frames")
ok(b.__textures[2]:GetAlpha() > 0.7, "the arrow itself never fades far enough to read as disappearing")

-- ---- future markers: still, blue, never stealing a green arrow ------------------
--
-- Two meanings share one texture pair. "upgrade" pulses green because you can act on it;
-- "future" is blue and STILL because you cannot. Movement is the loudest thing a bag icon
-- does and it belongs to the one you can act on - a future marker pulsing alongside would be
-- asking for attention it cannot reward, and you would learn to ignore both.
__reduceMotion = false
local UPGRADE = "|Hitem:100|h[Now]|h"
local FUTURE  = "|Hitem:200|h[Later]|h"
local FUTURE_SCALES = {}
UPGRADES[UPGRADE] = true
Valuate.GetFutureUpgradeScales = function(_, link) return FUTURE_SCALES[link] end
FUTURE_SCALES[FUTURE] = { "Melee" }

local bu, bf = makeButton(), makeButton()
ns.SetUpgradeArrow(bu, UPGRADE)
ns.SetUpgradeArrow(bf, FUTURE)

local function colourOf(btn)
    local v = btn.__textures[2].__vertex
    return v and (string.format("%.2f", v[1]) .. "," .. string.format("%.2f", v[2]))
end
ok(colourOf(bu) ~= colourOf(bf), "an upgrade and a future item are not the same colour")

-- The green one moves; the blue one does not - measured over the SAME frames, so this
-- cannot pass by having looked at them at different moments.
local upFirst, futureFirst = nil, nil
local upMoved, futureMoved = false, false
for _ = 1, 12 do
    tick(0.05)
    local u, f = bu.__textures[1]:GetAlpha(), bf.__textures[1]:GetAlpha()
    if upFirst == nil then upFirst, futureFirst = u, f end
    if math.abs(u - upFirst) > 0.001 then upMoved = true end
    if math.abs(f - futureFirst) > 0.001 then futureMoved = true end
end
ok(upMoved, "the upgrade marker pulses")
ok(not futureMoved, "the future marker holds still")
ok(bf.__textures[2]:GetAlpha() > 0.5, "...and stays clearly legible while it does")

-- An item that is BOTH must read as an upgrade: it is equippable and better, so the marker
-- you can act on wins. Ordering the checks that way means a bug in the future lookup can
-- never take a green arrow away from something wearable.
local bb = makeButton()
UPGRADES[FUTURE] = true
ns.SetUpgradeArrow(bb, FUTURE)
eq(colourOf(bb), colourOf(bu), "an item that is both shows the actionable marker")
UPGRADES[FUTURE] = nil

-- Levelling into an item swaps the marker in place, and that is worth an entrance: it is
-- the moment the item changed meaning.
ns.SetUpgradeArrow(bf, FUTURE)
ok(colourOf(bf) ~= colourOf(bu), "still blue while it is unusable")
UPGRADES[FUTURE] = true
ns.SetUpgradeArrow(bf, FUTURE)
eq(colourOf(bf), colourOf(bu), "levelling into it turns the marker green in place")
UPGRADES[FUTURE] = nil

-- Both kinds prune. The fix that closed a session-long leak has to hold for the mode added
-- after it - which is exactly what a second branch forgets.
--
-- Asked about THESE buttons rather than through trackedCount(): earlier cases left other
-- buttons on screen, so the global count is legitimately non-zero and using it here asserted
-- something about them instead. That is how the first version of this check failed.
local function writesTo(btn)
    for _, t in ipairs(btn.__textures) do t:SetAlpha(-1) end
    tick(0.05)
    for _, t in ipairs(btn.__textures) do
        if t:GetAlpha() ~= -1 then return true end
    end
    return false
end

ok(writesTo(bu), "a shown upgrade marker is still being driven")
ok(writesTo(bf), "a shown future marker is still being driven")

bu.__shown = false
bf.__shown = false
tick(0.05)   -- the pass that notices and drops them
ok(not writesTo(bu), "an upgrade marker is dropped when its bag closes")
ok(not writesTo(bf), "and so is a future marker - the pruning covers the newer mode too")

return failures, checks
`,
  "arrowtest",
  "the upgrade arrow driver"
);
