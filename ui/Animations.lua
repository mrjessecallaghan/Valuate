-- ui/Animations.lua
-- Valuate's animation engine: one shared ticker, an easing library, and the tween
-- helpers used across the UI.
--
-- State (the active-tween list and the ticker frame) is deliberately kept LOCAL to this
-- file - no other file mutates it, so consumers can safely re-localise the functions
-- (`local Anim = ns.Anim`) without the cross-file assignment problem that applies to
-- shared mutable state.

local _, ns = ...

-- Animation engine
-- ========================================
-- One shared ticker drives every active tween, instead of a per-widget OnUpdate
-- script. That means fewer handlers, a single global pause for Reduce Motion, and
-- widgets keep their own OnUpdate for other purposes. Deliberately avoids C_Timer /
-- AnimationGroup, both of which vary across 3.3.5 clients.
local Anim = {}
local activeTweens = {}
local animDriver = CreateFrame("Frame", nil, UIParent)

local function ReduceMotion()
    return Valuate and Valuate.GetOptions and Valuate:GetOptions().reduceMotion == true
end

-- Easing library. t is 0..1; each returns the eased 0..1 (outBack/outElastic overshoot).
local Easing = {
    linear   = function(t) return t end,
    outQuad  = function(t) return 1 - (1 - t) * (1 - t) end,
    outCubic = function(t) local u = 1 - t; return 1 - u * u * u end,
    inOutQuad = function(t)
        if t < 0.5 then return 2 * t * t end
        local u = -2 * t + 2; return 1 - (u * u) / 2
    end,
    outBack = function(t)  -- gentle spring overshoot
        local c1 = 1.70158; local c3 = c1 + 1; local u = t - 1
        return 1 + c3 * u * u * u + c1 * u * u
    end,
    outElastic = function(t)  -- celebratory bounce
        if t <= 0 then return 0 elseif t >= 1 then return 1 end
        local c4 = (2 * math.pi) / 3
        return math.pow(2, -10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
    end,
}

animDriver:SetScript("OnUpdate", function(_, elapsed)
    local n = #activeTweens
    if n == 0 then return end
    for i = n, 1, -1 do
        local tw = activeTweens[i]
        tw.delay = tw.delay - elapsed
        if tw.delay <= 0 then
            tw.elapsed = tw.elapsed + elapsed
            local raw = tw.duration > 0 and (tw.elapsed / tw.duration) or 1
            if raw > 1 then raw = 1 end
            local eased = tw.ease(raw)
            if tw.onUpdate then tw.onUpdate(eased, raw) end
            if raw >= 1 then
                table.remove(activeTweens, i)
                if tw.onDone then tw.onDone() end
            end
        end
    end
end)

function Anim.cancel(handle)
    if not handle then return end
    for i = #activeTweens, 1, -1 do
        if activeTweens[i] == handle then table.remove(activeTweens, i); return end
    end
end

-- opts: duration, ease (name/fn), delay, onUpdate(eased, raw), onDone.
-- With Reduce Motion (or zero duration) it applies the final state instantly.
function Anim.tween(opts)
    local ease = opts.ease
    if type(ease) == "string" then ease = Easing[ease] end
    ease = ease or Easing.outQuad
    if ReduceMotion() or not opts.duration or opts.duration <= 0 then
        if opts.onUpdate then opts.onUpdate(1, 1) end
        if opts.onDone then opts.onDone() end
        return nil
    end
    local tw = {
        elapsed = 0, duration = opts.duration, delay = opts.delay or 0,
        ease = ease, onUpdate = opts.onUpdate, onDone = opts.onDone,
    }
    activeTweens[#activeTweens + 1] = tw
    return tw
end

-- Starts a tween "owned" by a property of a frame, cancelling any prior tween on that
-- same property first - so hover in/out or repeated triggers stay smooth instead of
-- stacking. Returns the handle.
local function startProp(frame, propKey, opts)
    local key = "__anim_" .. propKey
    if frame[key] then Anim.cancel(frame[key]) end
    local tw = Anim.tween(opts)
    frame[key] = tw
    return tw
end

-- Convenience: fade a frame's alpha from its current value to `to`.
function Anim.fade(frame, to, duration, ease, onDone)
    if not frame then return end
    local from = frame:GetAlpha() or 1
    return startProp(frame, "alpha", {
        duration = duration, ease = ease, onDone = onDone,
        onUpdate = function(e) frame:SetAlpha(from + (to - from) * e) end,
    })
end

-- Convenience: tween a frame's scale (used for window open/close pop).
function Anim.scaleTo(frame, to, duration, ease, onDone)
    if not frame or not frame.SetScale then return end
    local from = frame:GetScale() or 1
    return startProp(frame, "scale", {
        duration = duration, ease = ease, onDone = onDone,
        onUpdate = function(e) frame:SetScale(from + (to - from) * e) end,
    })
end

-- Convenience: count a number from -> to, calling setter each tick. For score/stat
-- roll-ups. owner lets a re-trigger cancel the previous run cleanly.
function Anim.number(ownerFrame, propKey, from, to, duration, setter, ease)
    if math.abs(to - from) < 0.001 then setter(to); return end
    return startProp(ownerFrame, propKey, {
        duration = duration, ease = ease or "outCubic",
        onUpdate = function(e) setter(from + (to - from) * e) end,
        onDone = function() setter(to) end,
    })
end

-- Back-compat shims: the older helpers now route through the shared ticker, so all
-- existing callers (button hover, tab accent, set-activation flash) get the engine
-- for free. ValuateTween passes RAW t to `apply` (callers ease themselves).
local function EaseOutQuad(t) return Easing.outQuad(t) end

local function ValuateTween(frame, duration, apply, onDone)
    if not frame or not apply then return end
    return startProp(frame, "tween", {
        duration = duration, ease = "linear", onDone = onDone,
        onUpdate = function(_, raw) apply(raw) end,
    })
end

local function ColorLerp(from, to, t)
    return from[1] + (to[1] - from[1]) * t,
           from[2] + (to[2] - from[2]) * t,
           from[3] + (to[3] - from[3]) * t,
           (from[4] or 1) + ((to[4] or 1) - (from[4] or 1)) * t
end

-- Fades a backdrop's fill and border to target colours from their current values.
local function TweenBackdrop(frame, toFill, toBorder, duration)
    if not frame or not frame.GetBackdropColor then return end
    local fr, fg, fb, fa = frame:GetBackdropColor()
    local br, bg, bb, ba = frame:GetBackdropBorderColor()
    local fromFill = { fr or 0, fg or 0, fb or 0, fa or 1 }
    local fromBorder = { br or 0, bg or 0, bb or 0, ba or 1 }
    return startProp(frame, "backdrop", {
        duration = duration, ease = "outQuad",
        onUpdate = function(e)
            frame:SetBackdropColor(ColorLerp(fromFill, toFill, e))
            frame:SetBackdropBorderColor(ColorLerp(fromBorder, toBorder, e))
        end,
    })
end
-- ========================================
-- Publish to the shared namespace
-- ========================================
ns.Anim = Anim
ns.Easing = Easing
ns.ReduceMotion = ReduceMotion
ns.EaseOutQuad = EaseOutQuad
ns.ColorLerp = ColorLerp
ns.ValuateTween = ValuateTween
ns.TweenBackdrop = TweenBackdrop
