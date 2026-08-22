#!/usr/bin/env node
/*
 * @gate A setting you changed survives an update that adds new settings
 *
 * Runs the REAL DEFAULT_OPTIONS, ApplyOptionDefaults and Valuate:GetOptions from Valuate.lua.
 *
 * Every login backfills missing options onto whatever this character saved, so that code
 * written against "every key exists" is safe. That is a sound design and it has one failure
 * mode, which is severe and quiet: if the backfill ever overwrote a key that was ALREADY THERE,
 * every choice you have made would revert at the next login.
 *
 * The dangerous direction is not the obvious one. Most automations default to `false`, so a
 * clumsy backfill leaves them alone. But a dozen options default to **true** - the login
 * summary, rolling on recipes, hit-cap awareness - and for those, `if not options[key]` instead
 * of `if options[key] == nil` reads a deliberate `false` as "missing" and turns the feature
 * back on. You would switch something off, log out, and find it on again, with nothing to
 * connect the two.
 *
 * So the central assertion here is not written against a fixed list. It walks every option that
 * defaults to true, sets it false, and demands it stay false - which means an option added next
 * year is covered the day it is added.
 *
 * The other half is aliasing: a table-valued default must be handed out as a FRESH table.
 * Sharing one would make two characters edit the same profession overrides, and would let a
 * character write into DEFAULT_OPTIONS itself.
 *
 * Usage:  node tools/optiondefaults.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

function slice(re, what) {
  const hit = lua.match(re);
  if (!hit) {
    console.error("  SLICE  could not find " + what + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return hit[0];
}

const defaults = slice(/^local DEFAULT_OPTIONS = \{[\s\S]*?\r?\n\}\r?\n/m, "DEFAULT_OPTIONS");
const apply = slice(/^local function ApplyOptionDefaults\([\s\S]*?\r?\nend\r?\n/m, "ApplyOptionDefaults");
const getter = slice(/^function Valuate:GetOptions\([\s\S]*?\r?\nend\r?\n/m, "Valuate:GetOptions");

const run = load([]);

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

` + defaults + `
` + apply + `
` + getter + `

-- ---- a choice you made SURVIVES ---------------------------------------------------------------
-- The whole point. A backfill exists to add what is missing, never to restate what is there.
local saved = { autoSellJunk = true, autoDeleteKeepFree = 9 }
ApplyOptionDefaults(saved)
eq(saved.autoSellJunk, true, "an automation you switched on stays on")
eq(saved.autoDeleteKeepFree, 9, "and a number you typed is not replaced by the default")

-- ---- ...INCLUDING A DELIBERATE FALSE -----------------------------------------------------------
-- The severe case, and the one a careless rewrite would miss. Options that default to FALSE are
-- unharmed by any version of this code; options that default to TRUE are not. For those,
-- treating a saved false as "missing" turns a feature you switched off back on at every login.
--
-- Walked over the defaults rather than written against a list, so an option added next year is
-- covered the day it is added.
local trueByDefault = {}
for key, value in pairs(DEFAULT_OPTIONS) do
    if value == true then trueByDefault[#trueByDefault + 1] = key end
end
-- Sorted: the failure message names a key, and an unsorted walk would name a different one on
-- different runs for the same bug.
table.sort(trueByDefault)
ok(#trueByDefault > 0,
   "there are options that default to true - without any, this whole section proves nothing")

local switchedOff = {}
for _, key in ipairs(trueByDefault) do switchedOff[key] = false end
ApplyOptionDefaults(switchedOff)
for _, key in ipairs(trueByDefault) do
    eq(switchedOff[key], false, "'" .. key .. "' stays switched off after a backfill")
end

-- ---- what is genuinely missing IS filled ---------------------------------------------------------
-- The other direction, or "never overwrite anything" would pass by doing nothing at all.
local sparse = {}
ApplyOptionDefaults(sparse)
local filled = 0
for _ in pairs(sparse) do filled = filled + 1 end
local declared = 0
for _ in pairs(DEFAULT_OPTIONS) do declared = declared + 1 end
eq(filled, declared, "a character with nothing saved gets every option")

-- An upgrade that ADDS an option gives it to a character who saved before it existed.
local older = { autoSellJunk = true }
ApplyOptionDefaults(older)
ok(older.autoDeleteKeepFree ~= nil, "an option added after you last logged in appears")
eq(older.autoSellJunk, true, "without disturbing what was already saved")

-- ---- a key this version has never heard of is LEFT ALONE --------------------------------------------
-- Downgrading, or an option retired between versions. Deleting it would lose the setting for
-- anyone who upgrades again, and the backfill has no business pruning.
local withStranger = { somethingFromTheFuture = "keep me" }
ApplyOptionDefaults(withStranger)
eq(withStranger.somethingFromTheFuture, "keep me", "an unrecognised saved key is not removed")

-- ---- table defaults are FRESH, never shared ------------------------------------------------------
-- Handing out the default table itself would let one character write into DEFAULT_OPTIONS, and
-- through it into every other character on the account.
local tableKeys = {}
for key, value in pairs(DEFAULT_OPTIONS) do
    if type(value) == "table" then tableKeys[#tableKeys + 1] = key end
end
table.sort(tableKeys)

if #tableKeys > 0 then
    local charA, charB = {}, {}
    ApplyOptionDefaults(charA)
    ApplyOptionDefaults(charB)
    for _, key in ipairs(tableKeys) do
        ok(charA[key] ~= DEFAULT_OPTIONS[key],
           "'" .. key .. "' is a fresh table, not the default one itself")
        ok(charA[key] ~= charB[key],
           "'" .. key .. "' is not shared between two characters")
        charA[key].marker = true
        eq(DEFAULT_OPTIONS[key].marker, nil,
           "writing to '" .. key .. "' does not reach DEFAULT_OPTIONS")
        eq(charB[key].marker, nil, "nor the other character")
    end
else
    ok(true, "no table-valued defaults on this version, so there is no aliasing to check")
end

-- ---- the getter builds one for a character that has none -------------------------------------------
ValuateOptions = nil
local built = Valuate:GetOptions()
ok(type(built) == "table", "a character with no saved options gets a table rather than nil")
ok(next(built) ~= nil, "and it is populated, not empty")

-- ...and hands back the SAME table next time, or every caller would edit a different copy and
-- nothing anyone changed would stick.
ValuateOptions.autoSellJunk = true
eq(Valuate:GetOptions().autoSellJunk, true,
   "the getter returns the same table, so a change made through it persists")

return failures, checks
`,
  "optiondefaults",
  "the option backfill"
);
