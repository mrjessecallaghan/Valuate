#!/usr/bin/env node
/*
 * @gate Runs input validation + colour handling for real
 *
 * Runs ui/Widgets.lua for real, against a mocked WoW API.
 *
 * Widgets.lua is the addon's pure logic: what happens to the characters you type into
 * a stat-weight box, and how a saved colour becomes RGB. No scan, no scoring, no
 * frames worth speaking of - which is exactly why it is worth executing rather than
 * reading. Input validation is all edge cases, and every one of its failure modes is
 * quiet: a weight that silently becomes a different number, or a colour that resolves
 * to white and looks like a theme choice.
 *
 * Usage:  node tools/widgettest.js       (run from the addon root or tools/)
 * Exits non-zero on the first failed assertion.
 */
"use strict";

const { load } = require("./luaharness");

const run = load(["ui/Shared.lua", "ui/Animations.lua", "ui/Widgets.lua"]);

const TESTS = `
local ns = __ns
local failures = {}
local checks = 0

local function ok(cond, msg)
    checks = checks + 1
    if not cond then table.insert(failures, msg) end
end
local function eq(got, want, msg)
    ok(got == want, msg .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end
local function near(a, b, msg)
    ok(type(a) == "number" and math.abs(a - b) < 0.001,
        msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

local V = ns.ValidateStatValueInput
local W = ns.ValidateWholeNumberInput
local HexToRGB, RGBToHex = ns.HexToRGB, ns.RGBToHex

-- ------------------------------------------------- stat value input validation
-- This runs on OnTextChanged, so it sees every intermediate state of what someone
-- types, not just finished input. Anything it rejects wrongly is a key that appears
-- not to work.
eq(V(nil), "", "nil input")
eq(V(""), "", "empty input")
eq(V("3"), "3", "a plain digit")
eq(V("3.5"), "3.5", "a decimal")
eq(V("-2"), "-2", "a negative")
eq(V("-2.5"), "-2.5", "a negative decimal")

-- A lone minus must survive: it is the first keystroke of every negative number, and
-- stripping it would make typing one impossible.
eq(V("-"), "-", "a lone minus is a legal intermediate state")

-- Junk is dropped, not rejected wholesale - the point is to keep what is usable.
eq(V("abc"), "", "letters")
eq(V("1a2"), "12", "letters between digits")
eq(V("1,5"), "15", "a comma (a decimal separator in much of the world) is dropped")

-- Only one decimal point, and it is the FIRST one that counts.
eq(V("1.2.3"), "1.23", "a second decimal point is dropped, not the first")

-- A lone decimal point is not a number and must not survive as one.
eq(V("."), "", "a lone decimal point")
eq(V("-."), "", "a minus and a lone decimal point")

-- The digit cap is five. It counts DIGITS, not characters, so the decimal point does
-- not eat into the budget.
eq(V("123456789"), "12345", "digits are capped at five")
eq(V("1.2345"), "1.2345", "five digits with a decimal point is still five digits")
eq(V("-123456"), "-12345", "the cap applies to negatives too, and the sign is kept")

-- A minus only counts at the start; one in the middle is junk like any other.
eq(V("1-2"), "12", "a minus after the first character is dropped")

-- Everything it returns must be something tonumber() accepts, or the value committed
-- to the scale would silently become nil. This is the property that actually matters,
-- and it is worth stating separately from the cases above.
for _, s in ipairs({"3", "3.5", "-2", "-2.5", "1.2.3", "123456789", "1a2", "0.001", "-0.5"}) do
    local cleaned = V(s)
    if cleaned ~= "" and cleaned ~= "-" then
        ok(tonumber(cleaned) ~= nil,
            "V(" .. s .. ") returned '" .. cleaned .. "', which tonumber() rejects")
    end
end

-- ------------------------------------------------- whole number input validation
eq(W(nil), "", "nil input")
eq(W(""), "", "empty input")
eq(W("2"), "2", "a digit")
eq(W("2.5"), "25", "decimals are not whole numbers - the point is dropped")
eq(W("-3"), "3", "a minus is dropped; there are no negative decimal places")
eq(W("abc"), "", "letters")

-- gsub returns TWO values. If this were written 'return text:gsub(...)' the caller
-- would receive the replacement COUNT as a second return, which silently becomes an
-- extra argument at any call site that forwards it.
local a, b = W("x1y2")
eq(a, "12", "digits extracted")
eq(b, nil, "must return exactly one value, not gsub's replacement count")

-- ------------------------------------------------------------- colour handling
near(select(1, HexToRGB("FF0000")), 1, "red channel of FF0000")
near(select(2, HexToRGB("00FF00")), 1, "green channel of 00FF00")
near(select(3, HexToRGB("0000FF")), 1, "blue channel of 0000FF")
near(select(1, HexToRGB("000000")), 0, "black")

-- Wrong length falls back to white rather than erroring.
near(select(1, HexToRGB("FFF")), 1, "a short string falls back to white")
near(select(1, HexToRGB(nil)), 1, "nil falls back to white")

-- SIX characters that are not hex. Length alone is not validity, and these values
-- come from saved variables and imported scale tags - neither of which this addon
-- controls. tonumber("ZZ", 16) is nil, and nil/255 is a hard error inside a UI build,
-- which takes the whole panel down rather than showing one wrong colour.
local okCall, r = pcall(HexToRGB, "ZZZZZZ")
ok(okCall, "HexToRGB errored on a six-character non-hex colour instead of falling back")
if okCall then near(r, 1, "a non-hex colour falls back to white") end

local okPartial = pcall(HexToRGB, "FF00GG")
ok(okPartial, "HexToRGB errored on a colour with only some invalid characters")

-- Round trip: what RGBToHex writes, HexToRGB must read back.
for _, rgb in ipairs({{1,0,0}, {0,1,0}, {0,0,1}, {0,0,0}, {1,1,1}, {0.5,0.25,0.75}}) do
    local hex = RGBToHex(rgb[1], rgb[2], rgb[3])
    ok(#hex == 6, "RGBToHex produced '" .. tostring(hex) .. "', which is not six characters")
    local rr, gg, bb = HexToRGB(hex)
    -- 1/255 tolerance: eight bits per channel is all the format holds.
    ok(math.abs(rr - rgb[1]) <= 1/255 and math.abs(gg - rgb[2]) <= 1/255
        and math.abs(bb - rgb[3]) <= 1/255,
        "colour did not survive a round trip through " .. hex)
end

-- Out-of-range input is clamped rather than producing a malformed hex string.
-- 0.5 becomes 7F, not 80: RGBToHex floors rather than rounds. That is a legitimate
-- choice - the round-trip check above proves it stays inside the format's own
-- precision - but it is the kind of thing worth writing down, since half the channel
-- values in a picker land on a .5 boundary.
eq(RGBToHex(2, -1, 0.5), "FF007F", "channels outside 0..1 are clamped")

-- ---------------------------------------------------------- RegisterEscapeClose
-- UISpecialFrames is shared by every addon, and Blizzard walks it on every Escape
-- press, so a duplicate entry is pure noise in a hot path.
local reg = ns.RegisterEscapeClose
ok(reg("ValuateTestFrame") == true, "first registration should report that it registered")
ok(reg("ValuateTestFrame") == false, "a duplicate registration must be refused")
local count = 0
for _, n in ipairs(UISpecialFrames) do
    if n == "ValuateTestFrame" then count = count + 1 end
end
eq(count, 1, "frame name appears in UISpecialFrames exactly once")

-- Only a string names a frame; anything else would sit in that list forever doing
-- nothing.
ok(reg(nil) == false, "nil must not be registered")
ok(reg(CreateFrame("Frame")) == false, "a frame OBJECT is not a frame NAME and must be refused")

-- ---- ns.SetSolidColor: the same call on two client generations ----------------
--
-- Every accent bar, separator, row highlight and header background in the addon fills a
-- texture through this. SetColorTexture is Legion; Interface 30300 has SetTexture(r,g,b,a).
-- Ascension ships a customised 3.3.5a client and may have either, so the helper asks the
-- texture rather than assuming - and both answers are exercised here, because a fallback
-- nothing runs is a fallback nobody knows is broken.
local SSC = ns.SetSolidColor
ok(type(SSC) == "function", "ns.SetSolidColor is published")

-- A modern client: the method exists and must be preferred.
local modern = { calls = {} }
function modern:SetColorTexture(r, g, b, a) self.calls[#self.calls + 1] = { "color", r, g, b, a } end
function modern:SetTexture(r, g, b, a) self.calls[#self.calls + 1] = { "texture", r, g, b, a } end
SSC(modern, 0.1, 0.2, 0.3, 0.4)
eq(#modern.calls, 1, "one call on a modern client")
eq(modern.calls[1][1], "color", "a modern client uses SetColorTexture")
near(modern.calls[1][2], 0.1, "red is passed through")
near(modern.calls[1][5], 0.4, "alpha is passed through")

-- A 3.3.5a client: no such method, so it must fall back rather than error.
local wotlk = { calls = {} }
function wotlk:SetTexture(r, g, b, a) self.calls[#self.calls + 1] = { "texture", r, g, b, a } end
SSC(wotlk, 0.5, 0.6, 0.7, 0.8)
eq(#wotlk.calls, 1, "one call on a 3.3.5a client")
eq(wotlk.calls[1][1], "texture", "a 3.3.5a client falls back to SetTexture")
near(wotlk.calls[1][2], 0.5, "red survives the fallback")
near(wotlk.calls[1][5], 0.8, "alpha survives the fallback")

-- Alpha is optional at several call sites (unpack of a 3-entry colour).
local three = { calls = {} }
function three:SetTexture(r, g, b, a) self.calls[#self.calls + 1] = { r, g, b, a } end
SSC(three, 1, 1, 1)
eq(three.calls[1][4], nil, "a missing alpha stays missing rather than becoming 0")

-- A nil texture must be a no-op, not an error: several call sites guard their texture
-- with an existence check first, and one of them will eventually forget.
local okCall = pcall(SSC, nil, 1, 1, 1, 1)
ok(okCall, "a nil texture is ignored rather than raising")

return failures, checks
`;

run(TESTS, "widgettest", "ui/Widgets.lua");
