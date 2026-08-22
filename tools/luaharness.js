#!/usr/bin/env node
/*
 * Shared bootstrap for the runtime gates: loads real Valuate files under fengari
 * against a mocked WoW API, then runs a block of Lua assertions against them.
 *
 * Extracted once there was a second file worth executing. The mock is the valuable
 * part and it must stay ONE mock - two drifting copies of "what the WoW API does"
 * would be worse than none, because each gate would be testing against a different
 * imaginary client.
 *
 * The mock is deliberately dumb: it records what it was told and hands it back. A
 * mock that reimplements behaviour can agree with a broken addon.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require("fengari");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");

/*
 * Two 3.3.5-vs-5.3 shims: math.pow was removed in 5.3 (outElastic uses it) and
 * `unpack` moved to table.unpack. Both exist in the game client, so restoring them is
 * matching the target runtime rather than papering over anything.
 */
const PRELUDE = `
math.pow = math.pow or function(a, b) return a ^ b end
-- Removed in 5.3, present in the 5.1 client. MinimapButton uses it for the drag angle.
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
unpack = unpack or table.unpack
strsub, strlower, strtrim = string.sub, string.lower, function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
tinsert, tremove = table.insert, table.remove

__frames = {}
UIParent = { __name = "UIParent" }
UISpecialFrames = {}

-- The client's default UI font and the font-object factory. Both are real 3.3.5 APIs, so they
-- are modelled here - but nothing in the addon uses them any more, and that is deliberate.
--
-- v0.74.0a built font objects with these at file scope. This mock answered SetFont with a
-- stored table and CreateFont with a frame, so every assertion about the resulting type scale
-- passed while the real client refused the font and the UI would not open. The mock agreed
-- with the mistake. tools/loadtime.js now refuses file-scope calls to anything outside a tiny
-- guaranteed set, CreateFont among them, so that shape cannot ship again.
STANDARD_TEXT_FONT = "Fonts\\\\FRIZQT__.TTF"

function CreateFont(name)
    return CreateFrame("Font", name)
end

function CreateFrame(frameType, name, parent, template)
    local f = {
        __type = frameType, __name = name, __template = template, __scripts = {},
        __alpha = 1, __scale = 1, __height = 100, __width = 100,
        __shown = true, __points = {}, __parent = parent,
        __fill = {0, 0, 0, 1}, __border = {0, 0, 0, 1},
        __children = {}, __regions = {},
    }
    -- A frame registers itself with its parent so GetChildren() can find it. Regions are
    -- NOT children in the client - GetChildren returns frames, GetRegions returns font
    -- strings and textures, and nothing appears in both. Registering them in both here
    -- made every region collide with itself in any check that walks the pair, which read
    -- as 40 layout bugs that did not exist.
    local isRegion = (frameType == "FontString" or frameType == "Texture")
    if not isRegion and parent and type(parent) == "table" and parent.__children then
        table.insert(parent.__children, f)
    end

    -- A NAMED frame becomes a global in the client, which is how addons find each other's
    -- frames and how UISpecialFrames closes one by name. Without this, any code doing
    -- _G["ValuateSomething"] silently found nil here and the gate agreed with it.
    if name and type(name) == "string" then
        _G[name] = f
    end
    function f:SetScript(which, fn) self.__scripts[which] = fn end
    function f:GetScript(which) return self.__scripts[which] end
    -- HookScript ADDS to a handler rather than replacing it, which is the whole reason
    -- addons use it on Blizzard frames. Modelled properly: replacing here would let a gate
    -- pass while the real client ran two handlers.
    function f:HookScript(which, fn)
        local prev = self.__scripts[which]
        if prev then
            self.__scripts[which] = function(...) prev(...) return fn(...) end
        else
            self.__scripts[which] = fn
        end
    end
    function f:SetAlpha(a) self.__alpha = a end
    function f:GetAlpha() return self.__alpha end
    function f:SetScale(s) self.__scale = s end
    function f:GetScale() return self.__scale end
    -- A RESIZE TELLS THE FRAME. In the client, changing a frame's dimensions fires
    -- OnSizeChanged, and panels rely on that to recompute anything measured against their own
    -- size - scroll ranges above all. A mock that only stored the number left every such
    -- handler unreachable from a gate, so a range computed once against the wrong height
    -- looked correct forever.
    local function sizeChanged(self)
        local handler = self.__scripts and self.__scripts.OnSizeChanged
        if handler then handler(self, self.__width or 0, self.__height or 0) end
    end
    function f:SetHeight(h) local was = self.__height self.__height = h if was ~= h then sizeChanged(self) end end
    function f:GetHeight() return self.__height end
    function f:SetWidth(w) local was = self.__width self.__width = w if was ~= w then sizeChanged(self) end end
    function f:GetWidth() return self.__width end
    function f:Show() self.__shown = true end
    function f:Hide() self.__shown = false end
    function f:IsShown() return self.__shown end
    function f:IsVisible() return self.__shown end
    function f:SetPoint(...) table.insert(self.__points, {...}) end
    function f:ClearAllPoints() self.__points = {} end
    function f:SetBackdrop(bd) self.__backdrop = bd end
    function f:SetBackdropColor(r, g, b, a) self.__fill = {r, g, b, a} end
    function f:GetBackdropColor() return unpack(self.__fill) end
    function f:SetBackdropBorderColor(r, g, b, a) self.__border = {r, g, b, a} end
    function f:GetBackdropBorderColor() return unpack(self.__border) end
    -- SetText FIRES OnTextChanged on an EditBox, as the client does.
    --
    -- Real code leans on this: the icon picker clears its search on reopen with a bare
    -- SetText("") and relies on the resulting OnTextChanged to restore the full grid, and
    -- the shared search box's Escape does the same to re-run the filter. A mock that
    -- swallowed it would make those look broken here and work in the game - or worse, the
    -- reverse, once someone "fixed" the code to match the mock.
    --
    -- Guarded against recursion: a handler that calls SetText would otherwise loop, and an
    -- infinite loop in a gate is a confusing way to learn that.
    function f:SetText(t)
        self.__text = t
        local handler = self.__scripts and self.__scripts.OnTextChanged
        if handler and self.__type == "EditBox" and not self.__inTextChanged then
            self.__inTextChanged = true
            handler(self, false)   -- userInput = false, same as a programmatic SetText
            self.__inTextChanged = false
        end
    end
    function f:GetText() return self.__text end
    function f:SetTextColor(...) self.__textColor = {...} end
    function f:SetCursorPosition(p) self.__cursor = p end
    function f:GetCursorPosition() return self.__cursor or 0 end
    -- Font strings and textures are REGIONS of the frame that made them, not children.
    -- The client draws that distinction and so does GetChildren/GetRegions, which is the
    -- pair any layout check has to walk. Returning a loose frame here (what this used to
    -- do) made CheckColumnAnchors see an empty column and report a clean bill of health
    -- while the client printed six overlap warnings.
    -- A FontString is NOT a frame, and the difference that matters is mouse handling.
    --
    -- Everything here is built from CreateFrame, so font strings inherited SetScript and
    -- EnableMouse - which the client does not give them. Calling SetScript on a label
    -- therefore passed every gate and then errored on load in v0.176.0a, aborting the
    -- Settings panel mid-build and taking every panel constructed after it with it.
    --
    -- Removed rather than made to no-op: a silent no-op would still let the code ship and
    -- simply lose the hover. Erroring here is the same failure the client gives, at the only
    -- point where it is cheap.
    function f:CreateFontString(name, layer, template)
        local fs = CreateFrame("FontString", name, self, template)
        fs.__layer = layer
        fs.SetScript = nil
        fs.HookScript = nil
        fs.EnableMouse = nil
        fs.RegisterEvent = nil
        table.insert(self.__regions, fs)
        return fs
    end
    function f:CreateTexture(name, layer, template)
        local t = CreateFrame("Texture", name, self, template)
        t.__layer = layer
        table.insert(self.__regions, t)
        return t
    end
    function f:GetRegions() return unpack(self.__regions) end
    function f:GetChildren() return unpack(self.__children) end
    function f:GetDrawLayer() return self.__layer end
    function f:SetDrawLayer(layer) self.__layer = layer end
    function f:GetNumPoints() return #self.__points end
    function f:GetPoint(i)
        local p = self.__points[i or 1]
        if not p then return nil end
        return unpack(p)
    end
    function f:SetTexture(t) self.__texture = t; return true end
    function f:GetTexture() return self.__texture end
    function f:SetVertexColor(...) self.__vertex = {...} end

    -- Everything below is here because a real panel needed it. Added ONE AT A TIME as
    -- gates reached for them, never speculatively and never as a catch-all __index
    -- returning no-ops: a mock that answers every call agrees with every mistake, which
    -- is the opposite of what these gates are for. An unmocked method is a loud nil-call
    -- naming the exact line, which is the right failure.
    function f:SetSize(w, h)
        local ww, hh = self.__width, self.__height
        self.__width, self.__height = w, h
        if ww ~= w or hh ~= h then sizeChanged(self) end
    end
    function f:GetParent() return self.__parent end
    function f:SetParent(p) self.__parent = p end
    function f:SetChecked(v) self.__checked = v and true or false end
    function f:GetChecked() return self.__checked end
    function f:SetNormalTexture(t) self.__normalTexture = t end
    function f:SetPushedTexture(t) self.__pushedTexture = t end
    function f:SetHighlightTexture(t) self.__highlightTexture = t end
    function f:SetCheckedTexture(t) self.__checkedTexture = t end
    function f:SetAllPoints(o) self.__allPoints = o or true end
    function f:SetJustifyH(j) self.__justifyH = j end
    function f:SetJustifyV(j) self.__justifyV = j end
    function f:EnableMouse(e) self.__mouse = e end
    function f:EnableMouseWheel(e) self.__mouseWheel = e end
    function f:EnableKeyboard(e) self.__keyboard = e end
    function f:RegisterForClicks(...) self.__forClicks = {...} end
    function f:RegisterForDrag(...) self.__forDrag = {...} end
    function f:SetMovable(m) self.__movable = m end
    function f:SetResizable(r) self.__resizable = r end
    function f:SetClampedToScreen(c) self.__clamped = c end
    function f:SetToplevel(t) self.__toplevel = t end
    function f:SetFrameStrata(s) self.__strata = s end
    function f:SetFrameLevel(l) self.__frameLevel = l end
    function f:GetFrameLevel() return self.__frameLevel or 1 end
    function f:SetHitRectInsets(...) self.__hitRect = {...} end
    function f:SetScrollChild(c) self.__scrollChild = c end
    function f:GetScrollChild() return self.__scrollChild end
    function f:SetVerticalScroll(v) self.__vScroll = v end
    function f:GetVerticalScroll() return self.__vScroll or 0 end
    function f:SetMinMaxValues(lo, hi) self.__min, self.__max = lo, hi end
    function f:GetMinMaxValues() return self.__min or 0, self.__max or 0 end
    -- SetValue RUNS the handler, because in the client it does.
    --
    -- A mock that only stored the number made every OnValueChanged handler in this addon
    -- unreachable from a gate: whatever it did, right or wrong, nothing here ever called it.
    -- v0.177.0a shipped a scroll bar that threw the moment its value was set, past 71 gates.
    function f:SetValue(v)
        local changed = (self.__value ~= v)
        self.__value = v
        local handler = self.__scripts and self.__scripts.OnValueChanged
        -- Fired even when the value did not change, matching a first SetValue on a fresh
        -- slider - which is exactly the call that broke.
        if handler and (changed or not self.__valueSet) then handler(self, v) end
        self.__valueSet = true
    end
    function f:GetValue() return self.__value or 0 end
    function f:SetValueStep(s) self.__valueStep = s end
    function f:SetOrientation(o) self.__orientation = o end
    function f:SetThumbTexture(t) self.__thumb = t end
    function f:GetThumbTexture() return self.__thumb end
    function f:SetFontObject(o) self.__fontObject = o end
    function f:SetWordWrap(w) self.__wordWrap = w end
    function f:SetNonSpaceWrap(w) self.__nonSpaceWrap = w end
    function f:SetAutoFocus(a) self.__autoFocus = a end
    function f:SetMaxLetters(n) self.__maxLetters = n end
    function f:ClearFocus() self.__focused = false end
    function f:SetFocus() self.__focused = true end
    function f:SetID(i) self.__id = i end
    function f:GetID() return self.__id end
    function f:GetName() return self.__name end
    function f:GetObjectType() return self.__type end
    function f:SetDrawLayer(l) self.__drawLayer = l end
    function f:SetBlendMode(m) self.__blendMode = m end
    function f:SetTexCoord(...) self.__texCoord = {...} end
    function f:SetGradientAlpha(...) self.__gradient = {...} end
    function f:StartMoving() self.__moving = true end
    function f:StopMovingOrSizing() self.__moving = false end
    -- Text measurement. Returns a length proportional to the string so callers that
    -- compare it against a width get a monotonic answer, rather than a constant that
    -- would make every "does this fit?" branch take the same path.
    function f:GetStringWidth()
        return #(self.__text or "") * 6
    end
    -- Height that responds to the TEXT, because a constant makes every layout assertion a
    -- tautology. aboutfits.js asked "does this panel's content fit the window" against a flat
    -- 12, so it was measuring how many font strings existed rather than how much they said -
    -- and a feature list could triple in length without moving the number.
    --
    -- A rough model, deliberately: one line per newline, plus wrapping at the width the
    -- caller set. Real font metrics are not available here and pretending otherwise would be
    -- its own kind of lie, so this is only good enough to make "twice the text is taller"
    -- true. Gates that need exact pixels belong in the client, not here.
    function f:GetStringHeight()
        local text = self.__text
        if type(text) ~= "string" or text == "" then return 0 end
        -- Colour codes occupy no width on screen.
        local visible = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local width = self.__width
        local perLine = (type(width) == "number" and width > 0) and math.floor(width / 6) or 80
        if perLine < 8 then perLine = 8 end
        local lines = 0
        -- The appended newline makes the pattern also yield the text after the final one.
        for segment in (visible .. "\\n"):gmatch("([^\\n]*)\\n") do
            local len = #segment
            lines = lines + math.max(1, math.ceil(len / perLine))
        end
        return lines * 12
    end
    function f:SetFont(...) self.__font = {...} return true end
    function f:GetFont() return self.__font and self.__font[1] end
    function f:CopyFontObject(o) self.__copiedFrom = o end
    function f:GetFont() return unpack(self.__font or {}) end
    function f:SetShadowOffset(...) self.__shadowOffset = {...} end
    function f:SetShadowColor(...) self.__shadowColor = {...} end
    function f:LockHighlight() self.__highlightLocked = true end
    function f:UnlockHighlight() self.__highlightLocked = false end
    function f:SetTextInsets(...) self.__textInsets = {...} end
    function f:SetNumeric(n) self.__numeric = n end
    function f:HighlightText(...) self.__highlight = {...} end
    function f:SetMultiLine(m) self.__multiLine = m end
    function f:SetSpacing(s) self.__spacing = s end
    function f:SetDesaturated(d) self.__desaturated = d end

    -- Events are RECORDED, never dispatched. A mock that fired them would be deciding
    -- when the client does, which is exactly the behaviour a gate is trying to observe;
    -- a test that wants an event calls the handler itself.
    function f:RegisterEvent(ev)
        self.__events = self.__events or {}
        self.__events[ev] = true
    end
    function f:UnregisterEvent(ev)
        if self.__events then self.__events[ev] = nil end
    end
    function f:UnregisterAllEvents() self.__events = {} end
    function f:IsEventRegistered(ev)
        return (self.__events and self.__events[ev]) and true or false
    end
    -- A TEMPLATE BRINGS ITS OWN HANDLERS, and this one brings an assumption with it.
    --
    -- UIPanelScrollBarTemplate's OnValueChanged calls SetVerticalScroll straight on the
    -- slider's PARENT - it is written for a bar parented to the scroll frame it drives. Park a
    -- bar beside the scroll frame instead (which you must, if it is not to be clipped by it)
    -- and the first SetValue throws, unless your own handler has already replaced it.
    --
    -- Modelled here rather than assumed away: without it the harness builds templated frames
    -- as blank ones, so the window between CreateFrame and SetScript - the window v0.177.0a
    -- fell into - does not exist in a gate at all.
    if template == "UIPanelScrollBarTemplate" then
        f.__scripts.OnValueChanged = function(selfRef, value)
            selfRef:GetParent():SetVerticalScroll(value)
        end
    end

    -- ONLY A SCROLLFRAME SCROLLS.
    --
    -- Every mocked frame had these, so a plain Frame answered SetVerticalScroll as happily as
    -- the real thing - and the template handler above, which is only dangerous BECAUSE its
    -- parent is usually not a scroll frame, ran clean against it.
    --
    -- The second time in two days that a too-generous mock let a real crash through: a
    -- FontString had SetScript, and now a Frame scrolls. The rule is the same both times -
    -- a mock that answers calls the client would refuse is not a lenient test, it is a
    -- test of a client that does not exist.
    if frameType ~= "ScrollFrame" then
        f.SetScrollChild = nil
        f.GetScrollChild = nil
        f.SetVerticalScroll = nil
        f.GetVerticalScroll = nil
    end

    table.insert(__frames, f)
    return f
end

-- Blizzard's dropdown API, RECORDED rather than simulated.
--
-- Real UIDropDownMenu builds its list by calling an initialiser that calls AddButton once
-- per entry, so the honest mock keeps what it was handed and lets a test walk it. It does
-- not open, close or select anything by itself: a mock that decided what was selected would
-- be answering the question a gate is asking.
__dropdownButtons = {}
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_SetWidth(f, w) if f then f.__ddWidth = w end end
function UIDropDownMenu_SetButtonWidth(f, w) if f then f.__ddButtonWidth = w end end
function UIDropDownMenu_JustifyText(f, j) if f then f.__ddJustify = j end end
function UIDropDownMenu_SetText(f, t) if f then f.__ddText = t end end
function UIDropDownMenu_GetText(f) return f and f.__ddText end
function UIDropDownMenu_SetSelectedValue(f, v) if f then f.__ddValue = v end end
function UIDropDownMenu_GetSelectedValue(f) return f and f.__ddValue end
function UIDropDownMenu_SetSelectedID(f, i) if f then f.__ddID = i end end
function UIDropDownMenu_AddButton(info) table.insert(__dropdownButtons, info) return info end
function UIDropDownMenu_Initialize(f, initFn) if f then f.__ddInit = initFn end end
function ToggleDropDownMenu() end
function CloseDropDownMenus() end

-- Addon presence. Reports nothing loaded, which is the honest default: a gate that wants
-- an integration present says so itself rather than inheriting one.
function IsAddOnLoaded() return false end
function GetAddOnMetadata() return nil end

-- ReduceMotion() reads this. Off by default; a test flips it.
__reduceMotion = false
Valuate = { GetOptions = function() return { reduceMotion = __reduceMotion } end }

-- Capture print() rather than spewing addon chatter into the gate output.
__printed = {}
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    table.insert(__printed, table.concat(parts, " "))
end

__ns = {}
`;

function fail(msg) {
  console.error("  " + msg);
  process.exit(1);
}

/*
 * Loads `files` (paths relative to the addon root, in .toc order) into a fresh Lua
 * state, then returns a runner for an assertion block.
 */
function load(files) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  function exec(src, chunkName, nargs) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@" + chunkName)) !== lua.LUA_OK) {
      fail("LOAD FAILED  " + chunkName + ": " + to_jsstring(lua.lua_tostring(L, -1)));
    }
    // Args were pushed by the caller *before* the chunk, so rotate them above it.
    if (nargs) lua.lua_insert(L, -1 - nargs);
    if (lua.lua_pcall(L, nargs || 0, 0, 0) !== lua.LUA_OK) {
      fail("RUNTIME ERROR in " + chunkName + ": " + to_jsstring(lua.lua_tostring(L, -1)));
    }
  }

  exec(PRELUDE, "prelude", 0);

  for (const rel of files) {
    const src = fs.readFileSync(path.join(ADDON_ROOT, rel), "utf8").replace(/^﻿/, "");
    // Addon files are called as `local _, ns = ...`, so push both varargs.
    lua.lua_pushstring(L, to_luastring("Valuate"));
    lua.lua_getglobal(L, to_luastring("__ns"));
    exec(src, rel, 2);
  }

  /*
   * Runs a Lua assertion block, which must `return failures, checks`.
   *
   * Assertions are written in Lua rather than marshalled field-by-field into JS:
   * they are statements about Lua values, and keeping them in Lua keeps the test the
   * same shape as the thing it tests.
   */
  return function run(testSrc, label, subject) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(testSrc), null, to_luastring("@" + label)) !== lua.LUA_OK) {
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
      console.error("\n" + subject + " FAILED " + failures.length + " of " + checks + " checks.");
      process.exit(1);
    }
    console.log("OK  " + subject + " passed " + checks + " runtime checks against a mocked WoW API.");

    // A benchmark that never shows its number is half a benchmark: a budget only reports
    // when it is breached, so the measurement itself would be invisible on every green
    // run. A block may set a global __report string to have it printed alongside the OK.
    lua.lua_getglobal(L, to_luastring("__report"));
    if (lua.lua_isstring(L, -1)) {
      console.log("      " + to_jsstring(lua.lua_tostring(L, -1)));
    }
    lua.lua_pop(L, 1);
  };
}

module.exports = { load, ADDON_ROOT };
