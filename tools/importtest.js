#!/usr/bin/env node
/*
 * @gate Runs scale-tag parsing + the export/import round trip
 *
 * Runs ImportExport.lua for real, against a mocked WoW API.
 *
 * This file makes ZERO WoW API calls - it is string parsing over text a user pasted
 * in from somewhere else, plus the export that produces that text. Two properties
 * matter and neither is visible to a parser:
 *
 *   1. Export -> import must be LOSSLESS. Anything dropped in the round trip is
 *      silent data loss: the scale imports fine and simply scores differently.
 *   2. Anything the exporter can produce, the importer must accept. A tag this addon
 *      wrote and this addon then rejects is the worst outcome, because the error
 *      blames the tag and the user has nowhere to go.
 *
 * Usage:  node tools/importtest.js       (run from the addon root or tools/)
 * Exits non-zero on the first failed assertion.
 */
"use strict";

const { load } = require("./luaharness");

const run = load(["ImportExport.lua"]);

const TESTS = `
local failures = {}
local checks = 0

local function ok(cond, msg)
    checks = checks + 1
    if not cond then table.insert(failures, msg) end
end
local function eq(got, want, msg)
    ok(got == want, msg .. " (got " .. tostring(got) .. ", want " .. tostring(want) .. ")")
end

-- The only thing ImportExport needs from the rest of the addon.
local scaleStore = {}
function Valuate:GetScales() return scaleStore end

local R = Valuate.ImportResult

local function freshScale(over)
    local s = {
        DisplayName = "Fire Mage",
        Color = "FF8800",
        Visible = true,
        Icon = "Interface\\\\Icons\\\\Spell_Fire_FlameBolt",
        Values = { INT = 1.0, SPI = 0.25, SPELLPOWER = 1.5, CRITRATING = 0.83 },
        Unusable = {},
    }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end

-- ------------------------------------------------------------- round trip
-- The property that matters most. Everything else here is a way of failing it.
scaleStore = { ["Fire Mage"] = freshScale() }
local tag = Valuate:GetScaleTag("Fire Mage")
ok(type(tag) == "string" and tag ~= "", "GetScaleTag produced nothing for a real scale")

local name, data, err = Valuate:ParseScaleTag(tag)
ok(name ~= nil, "a tag this addon just exported failed to parse: " .. tostring(err))
if data then
    eq(name, "Fire Mage", "display name survived the round trip")
    eq(data.Color, "FF8800", "colour survived")
    eq(data.Icon, "Interface\\\\Icons\\\\Spell_Fire_FlameBolt", "icon path survived")
    for stat, want in pairs(freshScale().Values) do
        eq(data.Values[stat], want, "weight for " .. stat .. " survived")
    end
    local n = 0
    for _ in pairs(data.Values) do n = n + 1 end
    eq(n, 4, "no extra stats appeared during the round trip")
end

-- Negative and fractional weights are ordinary input and must survive intact.
scaleStore = { ["Odd"] = freshScale({ DisplayName = "Odd",
    Values = { SPI = -1.5, STA = 0.001, AGI = 12345 } }) }
local _, oddData = Valuate:ParseScaleTag(Valuate:GetScaleTag("Odd"))
if oddData then
    eq(oddData.Values.SPI, -1.5, "a negative weight survived")
    eq(oddData.Values.STA, 0.001, "a small fractional weight survived")
    eq(oddData.Values.AGI, 12345, "a large weight survived")
end

-- Visible=false is a real setting, and 'false' is exactly the value a lazy
-- round trip turns back into 'true'.
scaleStore = { ["Hidden"] = freshScale({ DisplayName = "Hidden", Visible = false }) }
local _, hidData = Valuate:ParseScaleTag(Valuate:GetScaleTag("Hidden"))
if hidData then
    eq(hidData.Visible, false, "Visible=false survived the round trip")
end

-- ------------------------------------------- what the exporter may produce
-- The importer refuses names containing { } or |, since those are the tag's own
-- syntax. The exporter must not be able to produce such a tag - handing someone a
-- tag that this very addon rejects gives them an error about the FORMAT, with no
-- hint that the name is the problem.
-- Asserting it PARSES is not enough. "My{Scale" used to parse happily - as a scale
-- called "My", because the outer pattern stops at the first brace. Silent truncation
-- is worse than a rejection, so the round trip has to preserve the NAME.
for _, badName in ipairs({ "My{Scale", "My}Scale", "My|Scale", "{}|" }) do
    scaleStore = { ["X"] = freshScale({ DisplayName = badName }) }
    local t, why = Valuate:GetScaleTag("X")
    if t then
        local gotName, _, parseErr = Valuate:ParseScaleTag(t)
        ok(gotName ~= nil,
            "exported a tag for the name '" .. badName ..
            "' that this addon then refuses to import: " .. tostring(parseErr))
        eq(gotName, badName, "the name '" .. badName .. "' survived a round trip")
    else
        -- Refusing is the correct outcome, but only WITH a reason: the caller has to
        -- be able to tell the user which scale to rename.
        ok(type(why) == "string" and why ~= "",
            "refused to export '" .. badName .. "' without saying why")
    end
end

-- ------------------------------------------------------- malformed input
-- All of this is text someone pasted. None of it may raise.
for _, junk in ipairs({
    "", "   ", "not a tag at all", "{Valuate:v1:}", "{Valuate:}", "{}",
    "{Valuate:v1:Name{", "{Valuate:v1:Name{}}", "{Valuate:vX:Name{Color=FFFFFF}}",
    "{Valuate:v1:Name{Color}}", "{Valuate:v1:Name{=5}}", "{Valuate:v1:Name{INT=abc}}",
    "{{{{", "}}}}", "|cFFFFFFFF{Valuate:v1:N{Color=FFFFFF}}|r",
}) do
    local callOk, gotName, _, gotErr = pcall(Valuate.ParseScaleTag, Valuate, junk)
    ok(callOk, "ParseScaleTag RAISED on pasted junk: " .. string.format("%q", junk))
    if callOk and gotName == nil then
        ok(type(gotErr) == "string" and gotErr ~= "",
            "rejected " .. string.format("%q", junk) .. " with no explanation")
    end
end

-- Non-strings are a programming error, not user input, but must still not raise.
for _, bad in ipairs({ 42, true }) do
    ok(pcall(Valuate.ParseScaleTag, Valuate, bad), "ParseScaleTag raised on a " .. type(bad))
end
ok(pcall(Valuate.ParseScaleTag, Valuate, nil), "ParseScaleTag raised on nil")

-- ------------------------------------------------------- version handling
-- A NEWER tag must be refused with an explanation, not parsed into nonsense. This is
-- the whole reason the version exists: a v2 tag carries WeaponSet.* keys that a v1
-- reader would happily import as bogus stat weights.
local futureTag = "{Valuate:v99:Future{Color=FFFFFF,Visible=1,INT=1}}"
local fName, _, fErr = Valuate:ParseScaleTag(futureTag)
ok(fName == nil, "a tag from a future version was accepted")
ok(type(fErr) == "string" and fErr:find("newer"), "the future-version error should say the addon needs updating")

-- ...and an OLDER tag must still import, or every existing shared tag breaks.
local v1Tag = "{Valuate:v1:Old{Color=FFFFFF,Visible=1,INT=2.5}}"
local oName, oData = Valuate:ParseScaleTag(v1Tag)
ok(oName == "Old", "a v1 tag must still import")
if oData then eq(oData.Values.INT, 2.5, "weights from a v1 tag") end

-- ------------------------------------------- the exporter's version number
-- The exporter must stamp the CURRENT format version, not an older one. If it
-- downgraded, this addon would emit tags containing v2 keys (WeaponSet.*) labelled
-- v1 - and an older Valuate, seeing v1, would import "WeaponSet.TwoHand=1" as a
-- bogus stat weight instead of refusing. That is precisely what the version is for.
--
-- Tied to the parser rather than to a hardcoded number: whatever version the exporter
-- writes must be accepted, and one higher must not be. Bumping the format in one
-- place and not the other therefore fails here.
--
-- Note what this deliberately does NOT catch: changing SCALE_TAG_VERSION itself. That
-- constant feeds both the exporter and the parser's compatibility test, so moving it
-- moves both together and nothing inside this process can tell. The only observer
-- that could is a DIFFERENT, older Valuate, which no harness can model.
--
-- That is a property worth keeping rather than a hole worth plugging: single-sourcing
-- the version is exactly what makes the two sides incapable of disagreeing. Do not
-- "fix" this by asserting a literal version number here - that just adds an eighth
-- hand-maintained value to drift.
scaleStore = { ["Ver"] = freshScale({ DisplayName = "Ver" }) }
local verTag = Valuate:GetScaleTag("Ver")
local writtenVersion = tonumber(string.match(verTag or "", "^{Valuate:v(%d+):"))
ok(writtenVersion ~= nil, "could not read a version out of an exported tag")
if writtenVersion then
    ok(Valuate:ParseScaleTag(verTag) ~= nil, "the parser rejected the version the exporter writes")
    local nextTag = string.gsub(verTag, "^{Valuate:v%d+:", "{Valuate:v" .. (writtenVersion + 1) .. ":", 1)
    ok(Valuate:ParseScaleTag(nextTag) == nil,
        "the parser accepts v" .. (writtenVersion + 1) .. " but the exporter only writes v" ..
        writtenVersion .. " - the exporter is behind the format")
end

-- Weapon sets are the v2 feature, and the reason the version exists at all. They must
-- survive the round trip, including the FALSE entries: a disabled weapon set is a
-- decision, and dropping it silently re-enables that set on import.
Valuate.GetWeaponSetDefinitions = function()
    return { { key = "TwoHand" }, { key = "OneHandShield" }, { key = "DualWield" } }
end
scaleStore = { ["Sets"] = freshScale({ DisplayName = "Sets",
    WeaponSets = { TwoHand = true, OneHandShield = false, DualWield = true },
    ActiveWeaponSet = "TwoHand" }) }
local _, setData = Valuate:ParseScaleTag(Valuate:GetScaleTag("Sets"))
if setData and setData.WeaponSets then
    -- Asserted as SEMANTICS, not representation. A disabled set comes back as nil
    -- rather than false, and that is deliberate: Valuate:IsWeaponSetEnabled reads
    -- "no WeaponSets table at all" as everything-enabled, but a MISSING KEY inside an
    -- existing table as disabled. So nil and false mean the same thing here, and
    -- pinning the exact falsy value would be pinning an implementation detail.
    --
    -- What must hold is that the table EXISTS (otherwise every set silently switches
    -- back on) and that each key is truthy exactly when it was.
    ok(setData.WeaponSets.TwoHand, "an enabled weapon set survived")
    ok(not setData.WeaponSets.OneHandShield, "a disabled weapon set came back ENABLED")
    ok(setData.WeaponSets.DualWield, "the third weapon set survived")
    eq(setData.ActiveWeaponSet, "TwoHand", "the active weapon set survived")
else
    ok(false, "weapon-set configuration was lost entirely - every set would switch back on")
end

-- The case the representation makes fragile: ALL sets disabled. The parser stores nil
-- for each, so the table ends up empty - and an empty table must still be a table,
-- because nil would mean "all enabled", the exact opposite of what was saved.
scaleStore = { ["None"] = freshScale({ DisplayName = "None",
    WeaponSets = { TwoHand = false, OneHandShield = false, DualWield = false } }) }
local _, noneData = Valuate:ParseScaleTag(Valuate:GetScaleTag("None"))
ok(noneData and type(noneData.WeaponSets) == "table",
    "a scale with every weapon set disabled lost its WeaponSets table, which reads as all-enabled")

-- --------------------------------------------------- ImportScale contract
-- EVERY status code is a truthy number, SUCCESS included. Code reading the first
-- return as a boolean therefore treats TAG_ERROR as success - which is exactly the
-- mistake that shipped once in the scale-library loader.
scaleStore = {}
local code, gotName2, msg = Valuate:ImportScale(v1Tag)
eq(code, R.SUCCESS, "importing a good tag reports SUCCESS")
eq(gotName2, "Old", "importing reports the scale name")
eq(msg, nil, "a successful import has no error message")
ok(scaleStore["Old"] ~= nil, "the scale was not actually stored")

-- Importing the same tag again must NOT silently overwrite.
local code2, name3 = Valuate:ImportScale(v1Tag)
eq(code2, R.ALREADY_EXISTS, "re-importing an existing scale must report ALREADY_EXISTS")
eq(name3, "Old", "ALREADY_EXISTS still reports which scale")

-- ...unless asked to.
scaleStore["Old"].Values.INT = 999
local code3 = Valuate:ImportScale(v1Tag, true)
eq(code3, R.SUCCESS, "importing with overwrite=true should succeed")
eq(scaleStore["Old"].Values.INT, 2.5, "overwrite did not actually replace the data")

-- Failure codes are distinct AND every one of them is truthy.
local badCode = Valuate:ImportScale("garbage")
eq(badCode, R.TAG_ERROR, "garbage input should report TAG_ERROR")
local verCode = Valuate:ImportScale(futureTag)
eq(verCode, R.VERSION_ERROR, "a future-version tag should report VERSION_ERROR")
for label, code4 in pairs(R) do
    ok(code4 and code4 ~= 0, "ImportResult." .. label .. " must be truthy-and-nonzero to be usable")
end
ok(R.SUCCESS ~= R.TAG_ERROR and R.TAG_ERROR ~= R.VERSION_ERROR
    and R.ALREADY_EXISTS ~= R.SUCCESS, "ImportResult codes must all be distinct")

return failures, checks
`;

run(TESTS, "importtest", "ImportExport.lua");
