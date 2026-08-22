#!/usr/bin/env node
/*
 * @gate The account-wide scale library saves, loads and refuses honestly
 *
 * Runs the REAL library functions from ImportExport.lua against a mocked scale store.
 *
 * Scales are per-character, so every alt started with none and the only way to move one was to
 * export a tag, write it down somewhere, and paste it back. The library is the account-wide
 * store that removes that chore - and until now none of its behaviour was gated at all, only
 * the existence of its methods.
 *
 * That matters more than most: it writes to a saved variable shared by EVERY character on the
 * account, and its load path translates ImportScale's result codes. The source names the trap
 * in a comment:
 *
 *     ImportScale returns (resultCode, scaleName, errorMessage), and EVERY code is a truthy
 *     number - SUCCESS is 1, TAG_ERROR is 3. Returning it straight through would make callers
 *     read a failure as success.
 *
 * A comment is not a test. Half of this file is about the refusals, because a library that
 * silently reports success while importing nothing is a library you trust with the scale you
 * spent an hour tuning.
 *
 * Usage:  node tools/librarytest.js
 */
"use strict";

const { load } = require("./luaharness");

const run = load(["ImportExport.lua"]);

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

-- The only thing ImportExport needs from the rest of the addon.
local scaleStore = {}
function Valuate:GetScales() return scaleStore end

local function freshScale(displayName)
    return {
        DisplayName = displayName or "Fire Mage",
        Color = "FF8800",
        Visible = true,
        Icon = "Interface\\\\Icons\\\\Spell_Fire_FlameBolt",
        Values = { INT = 1.0, SPI = 0.25, SPELLPOWER = 1.5, CRITRATING = 0.83 },
        Unusable = {},
    }
end

local function reset()
    ValuateScaleLibrary = nil
    scaleStore = {}
end

-- ---- the round trip, which is the whole feature ----------------------------------------------
-- The KEY and the DISPLAY NAME differ on purpose. They are the same string on most scales,
-- which made this fixture tidier than the game: filing an entry under the internal key instead
-- of the name you see was invisible, and the mutation for it survived.
reset()
scaleStore = { ["FireMage_v2"] = freshScale("Fire Mage") }

local saved, entry = Valuate:SaveScaleToLibrary("FireMage_v2")
eq(saved, true, "a real scale saves to the library")
eq(entry, "Fire Mage", "under its DISPLAY name, which is what you would look for")
ok(Valuate:GetScaleLibrary()["FireMage_v2"] == nil,
   "and not under the internal key, which you would never think to search for")

-- Now a different character: same account, empty scale list.
scaleStore = {}
local loaded, name = Valuate:LoadScaleFromLibrary("Fire Mage")
eq(loaded, true, "and loads onto a character that has never seen it")
ok(scaleStore[name] ~= nil, "putting a real scale in the store")
eq(scaleStore[name].Color, "FF8800", "with its colour")
eq(scaleStore[name].Values.SPELLPOWER, 1.5, "and its weights")

-- It stores TAGS, not scale tables. Reusing the export format is what stops the library
-- drifting from what a pasted tag does - so what is in there has to be the tag, not a copy.
local stored = Valuate:GetScaleLibrary()["Fire Mage"]
eq(type(stored), "string", "the library holds the export tag, not a second serialisation")

-- ---- THE TRAP THE SOURCE NAMES ------------------------------------------------------------------
-- ImportScale returns a result CODE, and every code is truthy: SUCCESS is 1, ALREADY_EXISTS
-- and TAG_ERROR are also numbers. Passing one straight through makes a failure read as a
-- success, and the caller then tells you your scale is on this character when it is not.
eq(Valuate.ImportResult.SUCCESS ~= nil, true, "there is a SUCCESS code to compare against")
ok(Valuate.ImportResult.ALREADY_EXISTS ~= false and Valuate.ImportResult.ALREADY_EXISTS ~= nil,
   "and ALREADY_EXISTS is a truthy value, which is what makes this worth testing")

-- Loading the same entry again, without overwrite: the scale is already there.
local again, why = Valuate:LoadScaleFromLibrary("Fire Mage")
eq(again, false, "loading one that is already here is a REFUSAL, not a success")
ok(type(why) == "string" and why:find("already exists", 1, true) ~= nil,
   "and says so in words rather than returning a number")

-- ...and with overwrite, it goes through.
local over = Valuate:LoadScaleFromLibrary("Fire Mage", true)
eq(over, true, "with overwrite it loads over the top")

-- ---- refusals, each with its own reason -------------------------------------------------------
reset()
local no1, msg1 = Valuate:SaveScaleToLibrary("Not A Scale")
eq(no1, false, "saving a scale this character does not have is refused")
ok(msg1:find("no such scale", 1, true) ~= nil, "and says which way it is wrong")

local no2, msg2 = Valuate:SaveScaleToLibrary(nil)
eq(no2, false, "saving nothing is refused")
ok(type(msg2) == "string" and msg2 ~= "", "with a reason rather than a bare false")

local no3, msg3 = Valuate:LoadScaleFromLibrary("Nothing Here")
eq(no3, false, "loading an entry that does not exist is refused")
ok(msg3:find("Nothing Here", 1, true) ~= nil,
   "and NAMES the entry, so a typo is visible rather than mysterious")

local no4 = Valuate:LoadScaleFromLibrary(nil)
eq(no4, false, "loading nothing is refused")

-- A scale whose DISPLAY name cannot be serialised - GetScaleTag validates that one, not the
-- internal key. The reason is passed THROUGH rather than replaced: "couldn't serialise that
-- scale" is unactionable when the real problem is a brace in the name, which you can fix in
-- five seconds once someone tells you.
--
-- Written unconditionally. The first version wrapped this in "if the refusal happened", with
-- an else branch saying the format must accept braces - which is not defensiveness, it is an
-- assertion that passes either way. IsValidScaleTagName rejects { } and |, so the refusal is
-- not in doubt and pretending otherwise only hid whether this was tested at all.
scaleStore = { ["Bad"] = freshScale("Bad {Name}") }
local no5, msg5 = Valuate:SaveScaleToLibrary("Bad")
eq(no5, false, "a scale whose name cannot be serialised is refused")
ok(msg5:find("cannot contain", 1, true) ~= nil,
   "and says what is wrong with the name, not merely that something went wrong")
ok(msg5:find("Bad {Name}", 1, true) ~= nil, "naming the scale you have to rename")

-- ---- delete ------------------------------------------------------------------------------------
reset()
scaleStore = { ["Fire Mage"] = freshScale() }
Valuate:SaveScaleToLibrary("Fire Mage")
eq(Valuate:DeleteScaleFromLibrary("Fire Mage"), true, "an entry that exists deletes")
eq(Valuate:GetScaleLibrary()["Fire Mage"], nil, "and is gone")
eq(Valuate:DeleteScaleFromLibrary("Fire Mage"), false,
   "deleting it again reports false rather than pretending")
eq(Valuate:DeleteScaleFromLibrary(nil), false, "and deleting nothing is not a success")

-- Deleting from the library must NOT touch the scale on this character. They are separate
-- stores, and a delete that reached through to the live scale would be unrecoverable.
ok(scaleStore["Fire Mage"] ~= nil, "the character's own scale is untouched by a library delete")

-- ---- listing -------------------------------------------------------------------------------------
reset()
scaleStore = {
    ["Zed"] = freshScale("Zed"), ["Alpha"] = freshScale("Alpha"), ["Mid"] = freshScale("Mid"),
}
Valuate:SaveScaleToLibrary("Zed")
Valuate:SaveScaleToLibrary("Alpha")
Valuate:SaveScaleToLibrary("Mid")

local list = Valuate:ListScaleLibrary()
eq(#list, 3, "everything saved is listed")
-- SORTED. pairs() order is undefined and this reaches a menu; a list that reshuffles between
-- openings is one you cannot find anything in twice.
eq(list[1], "Alpha", "sorted, so the same entry is in the same place every time")
eq(list[2], "Mid", "second")
eq(list[3], "Zed", "third")

reset()
eq(#Valuate:ListScaleLibrary(), 0, "an untouched library lists nothing rather than erroring")
eq(type(Valuate:GetScaleLibrary()), "table",
   "and asking for it creates it, so the first save has somewhere to go")

return failures, checks
`,
  "librarytest",
  "the scale library"
);
