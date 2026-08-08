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

return failures, checks
`,
  "arrowtest",
  "the upgrade arrow driver"
);
