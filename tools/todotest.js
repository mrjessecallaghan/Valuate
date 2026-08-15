#!/usr/bin/env node
/*
 * @gate The to-do list is short, ordered by what unblocks what, and empty when it should be
 *
 * Runs the real Valuate:BuildTodoList against mocked sources.
 *
 * This composes four subsystems that are each gate-tested on their own, so what is left to
 * get wrong is the composition - and all three ways are the kind that make a list useless
 * rather than broken:
 *
 *   WRONG ORDER. A stale scale has to come first, because everything under it is scored BY
 *   that scale. Put upgrades on top and the list confidently tells you to equip things
 *   chosen by weights you have outgrown.
 *
 *   TOO LONG. Seventeen slots' worth of upgrades is the Best Equipment panel, not an answer
 *   to "what should I do next".
 *
 *   NEVER EMPTY. A to-do list that always has something in it is one you stop opening. When
 *   there is nothing to do it must say nothing, not print a heading over an empty space.
 *
 * Usage:  node tools/todotest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local todoAnnounced = false/m,
  /^function Valuate:AnnounceTodo\([\s\S]*?\r?\nend/m,
  /^function Valuate:BuildTodoList\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const found = lua.match(re);
  if (!found) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return found[0];
});
const m = [sliced.join("\n")];

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function saysAbout(reason, word, what)
    checks = checks + 1
    if type(reason) ~= "string" or not reason:find(word, 1, true) then
        table.insert(failures, what .. " (reason was: " .. tostring(reason) .. ")")
    end
end
local function eq(got, want, what)
    checks = checks + 1
    if got ~= want then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end

Valuate = {}

DRIFT, UPGRADES, SOCKETS, ENCHANTS = nil, nil, 0, 0
function Valuate:GetAutoScaleDrift() return DRIFT end
PRIMARY = nil
function Valuate:GetPrimaryScale()
    return PRIMARY or {}, (PRIMARY and PRIMARY.DisplayName) or "Dps"
end
function Valuate:RankAvailableUpgrades() return UPGRADES end
function Valuate:FindEmptySockets() return nil, SOCKETS end
function Valuate:FindMissingEnchants() return nil, ENCHANTS end

-- Whether this character has ever been SCANNED, which every case below assumed silently.
--
-- The fixture had no notion of it: GetBestEquipment was not mocked at all, so the list was
-- always built as if a scan had happened. That is the state most players are in and the
-- easiest one to write tests from, and it is exactly why the never-scanned case shipped
-- claiming "your gear is all up to date" about gear nothing had looked at.
SCANNED = true
function Valuate:GetBestEquipment()
    if not SCANNED then return {} end
    return { Dps = { [5] = {} } }
end

` + m[0] + `

local function kinds(items)
    local out = {}
    for _, i in ipairs(items or {}) do out[#out + 1] = i.kind end
    return table.concat(out, ",")
end

-- ---- nothing to do -----------------------------------------------------------
eq(#Valuate:BuildTodoList(), 0, "with nothing to act on the list is EMPTY")

-- ---- each source contributes independently -----------------------------------
DRIFT = "Auto - Str/Crit"
eq(kinds(Valuate:BuildTodoList()), "scale", "a stale scale alone is one item")
DRIFT = nil

SOCKETS = 3
eq(kinds(Valuate:BuildTodoList()), "sockets", "empty sockets alone is one item")
local socketItem = Valuate:BuildTodoList()[1]
ok(socketItem.text:find("3", 1, true) ~= nil, "and it reports how many")
SOCKETS = 0

ENCHANTS = 2
eq(kinds(Valuate:BuildTodoList()), "enchants", "missing enchants alone is one item")
ENCHANTS = 0

-- Zero must never produce a line. "Fill 0 empty sockets" is the failure that makes a list
-- always non-empty and therefore never read.
SOCKETS, ENCHANTS = 0, 0
eq(#Valuate:BuildTodoList(), 0, "a count of zero produces no line at all")

-- ---- the order IS the argument -----------------------------------------------
-- A stale scale first, because the upgrades below it are chosen BY that scale.
DRIFT = "Auto - Str/Crit"
UPGRADES = { { itemLink = "[Chest]", slotName = "Chest", gain = 40 } }
SOCKETS, ENCHANTS = 2, 1
eq(kinds(Valuate:BuildTodoList()), "scale,upgrade,sockets,enchants",
   "stale scale, then upgrades, then sockets, then enchants")

local first = Valuate:BuildTodoList()[1]
ok(first.detail and first.detail:find("scored by this scale", 1, true) ~= nil,
   "and the scale item says WHY it is first, rather than just being first")

-- ---- "I have not looked" is not "there is nothing" ---------------------------
-- RankAvailableUpgrades returns nil when there is no scan data, and the builder used to read
-- that as "no upgrades". A character who had never scanned therefore got an EMPTY list, and
-- both surfaces said so: the panel's words were "Nothing outstanding. Your gear, gems and
-- enchants are all up to date." A confident statement about gear nothing had ever examined.
--
-- CLAUDE.md states this rule off the back of the PassLoot Upgrade bug, which gave the same
-- answer for never-scanned and nothing-better-owned. The same mistake, made again, by someone
-- who had read about the first one.
DRIFT, UPGRADES, SOCKETS, ENCHANTS = nil, nil, 0, 0
SCANNED = false
local unscanned = Valuate:BuildTodoList()
ok(#unscanned > 0, "a character who has never scanned does NOT get an empty list")
eq(unscanned[1].kind, "scan", "it is told to scan")
ok(unscanned[1].command == "/valuate scan", "and given the command that does it")
ok(unscanned[1].detail and unscanned[1].detail:find("means nothing", 1, true) ~= nil,
   "and told why an empty list before that would have meant nothing")

-- The other way to know nothing: no scale to score against at all.
PRIMARY_NAME_NIL = true
local realPrimary = Valuate.GetPrimaryScale
Valuate.GetPrimaryScale = function() return nil, nil end
local noScale = Valuate:BuildTodoList()
ok(#noScale > 0, "a character with no active scale does not get an empty list either")
eq(noScale[1].kind, "scan", "the blocker comes first")
ok(noScale[1].command == "/valuate wizard", "and points at the thing that creates one")
Valuate.GetPrimaryScale = realPrimary

-- ...and once scanned, it stops nagging. A blocker that never clears is noise.
SCANNED = true
eq(#Valuate:BuildTodoList(), 0, "a scanned character with nothing to do gets an empty list")

-- ---- three upgrades, not seventeen -------------------------------------------
DRIFT = nil
SOCKETS, ENCHANTS = 0, 0
UPGRADES = {}
for i = 1, 17 do
    UPGRADES[i] = { itemLink = "[Item " .. i .. "]", slotName = "Slot " .. i, gain = 100 - i }
end
local many = Valuate:BuildTodoList()
eq(#many, 3, "at most three upgrades - this is a to-do list, not the whole panel")
ok(many[1].text:find("Item 1", 1, true) ~= nil, "and they are the BIGGEST three, in order")
ok(many[3].text:find("Item 3", 1, true) ~= nil, "third is the third biggest")

-- ...and it SAYS it stopped at three.
--
-- Trimming is right; stopping silently is not. A list that ends at three reads as a complete
-- one, so somebody with seventeen upgrades waiting would never learn that fourteen of them
-- exist. /valuate upgrades caps at five and has always said "...and N more"; this was the
-- one place in the addon that capped a list and kept quiet about it.
ok(many[3].detail and many[3].detail:find("14 more", 1, true) ~= nil,
   "the last row says how many were left out (" .. tostring(many[3].detail) .. ")")

-- On the LAST row, not a row of its own: an entry that is only an apology for the entries
-- above it is not a thing you can go and do.
eq(#many, 3, "and says so without spending a row on it")

-- Fewer than three is fine; it must not pad.
UPGRADES = { { itemLink = "[Only]", slotName = "Chest", gain = 5 } }
local one = Valuate:BuildTodoList()
eq(#one, 1, "one upgrade produces one item, not three")
eq(one[1].detail, nil, "and says nothing about more, because there are none")

-- Exactly three is exactly three, with nothing hidden - the off-by-one worth pinning, since
-- "3 more waiting" when there are none is worse than saying nothing.
UPGRADES = {}
for i = 1, 3 do
    UPGRADES[i] = { itemLink = "[Item " .. i .. "]", slotName = "Slot " .. i, gain = 10 - i }
end
local exactly = Valuate:BuildTodoList()
eq(#exactly, 3, "three upgrades gives three rows")
eq(exactly[3].detail, nil, "and no note, because nothing was left out")

-- An empty slot is called out, because the whole score being the gain makes it rank high
-- for a reason that is not "this item is remarkable".
UPGRADES = { { itemLink = "[Neck]", slotName = "Neck", gain = 30, emptySlot = true } }
local emptySlotItem = Valuate:BuildTodoList()[1]
ok(emptySlotItem.detail and emptySlotItem.detail:find("empty", 1, true) ~= nil,
   "an empty slot says so")

UPGRADES = { { itemLink = "[Neck]", slotName = "Neck", gain = 30, emptySlot = false } }
eq(Valuate:BuildTodoList()[1].detail, nil, "a slot you have something in does not")

-- ---- every item can be acted on ----------------------------------------------
DRIFT = "Auto - Str/Crit"
SOCKETS, ENCHANTS = 1, 1
for _, item in ipairs(Valuate:BuildTodoList()) do
    ok(type(item.text) == "string" and item.text ~= "", "every item says what to do: " .. item.kind)
    ok(type(item.command) == "string" and item.command:find("/valuate", 1, true) == 1,
       "and where to go for detail: " .. item.kind)
end

-- ---- a client missing the newer helpers still produces a list -----------------
-- These arrived across four separate releases; an older core without them must degrade to a
-- shorter list rather than erroring out of the command entirely.
Valuate.FindEmptySockets = nil
Valuate.FindMissingEnchants = nil
Valuate.GetAutoScaleDrift = nil
local degraded
ok(pcall(function() degraded = Valuate:BuildTodoList() end),
   "missing helpers are handled rather than crashing")
eq(kinds(degraded), "upgrade", "and what remains still reports")

-- ---- the one-line summary at login -------------------------------------------
-- It speaks ONCE. A summary that repeats is one you learn to filter out, and the whole
-- value is that you read it the one time it appears.
OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end

-- Put back the helpers the degradation test above deliberately removed, or this block would
-- be exercising the degraded path while claiming to test the normal one.
function Valuate:GetAutoScaleDrift() return DRIFT end
function Valuate:FindEmptySockets() return nil, SOCKETS end
function Valuate:FindMissingEnchants() return nil, ENCHANTS end

DRIFT, SOCKETS, ENCHANTS = "Auto - Str/Crit", 2, 1
UPGRADES = { { itemLink = "[Chest]", slotName = "Chest", gain = 40 } }
todoAnnounced = false

eq(Valuate:AnnounceTodo(), true, "with things to do, it announces")
eq(Valuate:AnnounceTodo(), false, "and never again this session")
saysAbout(select(2, Valuate:AnnounceTodo()), "Already", "saying why rather than going quiet")

-- Nothing to do must ALSO count as having spoken. Otherwise a character with a clean list
-- keeps re-checking, and the first thing to appear announces itself mid-dungeon - which is
-- precisely the interruption this feature is supposed to avoid.
todoAnnounced = false
DRIFT, SOCKETS, ENCHANTS, UPGRADES = nil, 0, 0, nil
eq(Valuate:AnnounceTodo(), false, "an empty list prints nothing")
DRIFT = "Auto - Str/Crit"
eq(Valuate:AnnounceTodo(), false, "and it does not start announcing later in the session")

-- Switched off means off.
todoAnnounced = false
OPTIONS.todoOnLogin = false
eq(Valuate:AnnounceTodo(), false, "switched off, it says nothing")
saysAbout(select(2, Valuate:AnnounceTodo()), "off", "and says that is why")
OPTIONS.todoOnLogin = nil

-- ---- a scale built on guessed weights ---------------------------------------------------
-- Six specs have no published stat priority, so theirs were read off their descriptions. The
-- picker says so while you hover, the list marks it and the editor repeats it - but all three
-- need you to go and LOOK, and the moment you would most want telling is the one where you
-- are looking at none of them: the scale is quietly scoring every item you see, on a guess.
local function kinds(list)
    local out = {}
    for _, item in ipairs(list or {}) do out[#out + 1] = item.kind end
    return out
end
local function indexOfKind(list, want)
    for i, item in ipairs(list or {}) do if item.kind == want then return i end end
end

PRIMARY = { DisplayName = "Guessy", Inferred = true, Values = { Agility = 1.0 } }
local list = Valuate:BuildTodoList()
ok(indexOfKind(list, "guess") ~= nil, "a guessed scale is raised in the to-do list")

local entry = list[indexOfKind(list, "guess")]
ok(entry.text:find("Guessy", 1, true) ~= nil, "naming the scale rather than saying 'a scale'")
ok(entry.detail:find("published", 1, true) ~= nil,
   "and explaining that nothing was ever published for it, rather than implying it is broken")
ok(entry.command ~= nil, "with somewhere to go about it")

-- Ordered ABOVE the upgrade entries, for the same reason a drifted scale is: everything
-- below is ranked BY this scale, so if it is wrong the rest of the list is wrong too.
local gi, ui = indexOfKind(list, "guess"), indexOfKind(list, "upgrade")
if gi and ui then
    ok(gi < ui, "and it comes before the upgrades it would be ranking")
end

-- A researched scale says nothing. A caveat on every login is one nobody reads.
PRIMARY = { DisplayName = "Solid", Values = { Agility = 1.0 } }
eq(indexOfKind(Valuate:BuildTodoList(), "guess"), nil,
   "a scale with researched weights raises nothing")

return failures, checks
`,
  "todotest",
  "the gear to-do list"
);
