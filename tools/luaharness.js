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
unpack = unpack or table.unpack
strsub, strlower, strtrim = string.sub, string.lower, function(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end
tinsert, tremove = table.insert, table.remove

__frames = {}
UIParent = { __name = "UIParent" }
UISpecialFrames = {}

function CreateFrame(frameType, name, parent, template)
    local f = {
        __type = frameType, __name = name, __template = template, __scripts = {},
        __alpha = 1, __scale = 1, __height = 100, __width = 100,
        __shown = true, __points = {}, __parent = parent,
        __fill = {0, 0, 0, 1}, __border = {0, 0, 0, 1},
    }
    function f:SetScript(which, fn) self.__scripts[which] = fn end
    function f:GetScript(which) return self.__scripts[which] end
    function f:SetAlpha(a) self.__alpha = a end
    function f:GetAlpha() return self.__alpha end
    function f:SetScale(s) self.__scale = s end
    function f:GetScale() return self.__scale end
    function f:SetHeight(h) self.__height = h end
    function f:GetHeight() return self.__height end
    function f:SetWidth(w) self.__width = w end
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
    function f:SetText(t) self.__text = t end
    function f:GetText() return self.__text end
    function f:SetTextColor(...) self.__textColor = {...} end
    function f:SetCursorPosition(p) self.__cursor = p end
    function f:GetCursorPosition() return self.__cursor or 0 end
    function f:CreateFontString()
        local fs = CreateFrame("FontString")
        return fs
    end
    function f:CreateTexture() return CreateFrame("Texture") end
    function f:SetTexture(t) self.__texture = t; return true end
    function f:GetTexture() return self.__texture end
    function f:SetVertexColor(...) self.__vertex = {...} end

    -- Everything below is here because a real panel needed it. Added ONE AT A TIME as
    -- gates reached for them, never speculatively and never as a catch-all __index
    -- returning no-ops: a mock that answers every call agrees with every mistake, which
    -- is the opposite of what these gates are for. An unmocked method is a loud nil-call
    -- naming the exact line, which is the right failure.
    function f:SetSize(w, h) self.__width, self.__height = w, h end
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
    function f:SetValue(v) self.__value = v end
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
    table.insert(__frames, f)
    return f
end

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
  };
}

module.exports = { load, ADDON_ROOT };
