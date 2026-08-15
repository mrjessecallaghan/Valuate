#!/usr/bin/env node
/*
 * @gate Missing dungeon data produces silence, never "nothing here for you"
 *
 * Runs the real ns.GetDungeonLoot / BossLootKnown / CountRemainingUpgrades.
 *
 * This feature advises you to LEAVE a dungeon. The failure that matters is not being wrong
 * about an item - it is being confident on the strength of a table nobody finished. Every
 * item id in DungeonLoot.lua is a claim about a modified server that cannot be queried from
 * here, so the table is small on purpose and the code has to make that safe:
 *
 *   AN UNLISTED DUNGEON returns nil. The caller says nothing at all. "I have no data" and
 *   "there is nothing here for you" are opposite answers that look identical to someone
 *   standing at the instance portal.
 *
 *   A BOSS WITH NO ITEMS is unknown, not empty. A half-written table would otherwise start
 *   telling people to leave the moment someone added a boss name without its drops.
 *
 * The count of UNKNOWN bosses is what lets the caller stay quiet. Advising on a dungeon with
 * even one unmapped boss left is a guess wearing the clothes of a fact.
 *
 * Usage:  node tools/dungeonloot.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

// The runtime half, sliced from the real file. Slicing rather than re-typing is the point:
// a copy would keep passing after the original changed underneath it.
const PIECES = [
  /^local dungeonKilled = \{\}/m,
  /^local dungeonKilledIn = nil/m,
  /^local dungeonLeaveOffered = false/m,
  /^local dungeonTracking = false/m,
  /^function Valuate:GetCurrentDungeon\([\s\S]*?\r?\nend/m,
  /^local function DungeonItemIsUpgrade\([\s\S]*?\r?\nend/m,
  /^function Valuate:GetDungeonUpgradeStatus\([\s\S]*?\r?\nend/m,
  /^function Valuate:ConsiderDungeonLeave\([\s\S]*?\r?\nend/m,
  /^function Valuate:ResetDungeonProgress\([\s\S]*?\r?\nend/m,
  /^function Valuate:UpdateDungeonTracking\([\s\S]*?\r?\nend/m,
  /^function Valuate:NoteDungeonUnitDeath\([\s\S]*?\r?\nend/m,
  /^local WHERE_ITEM_BUDGET = \d+/m,
  /^function Valuate:FindUpgradeSources\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return m[0];
});

const run = load(["ui/Shared.lua", "ui/Data.lua", "ui/DungeonLoot.lua"]);

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

-- ---- an unlisted dungeon is SILENCE ------------------------------------------
eq(ns.GetDungeonLoot("Some Instance Nobody Mapped"), nil,
   "a dungeon with no entry returns nil, so the caller can say nothing")
eq(ns.GetDungeonLoot(nil), nil, "and nil is handled rather than crashing")
eq(ns.GetDungeonLoot(""), nil, "so is an empty name")

ok(ns.GetDungeonLoot("The Deadmines") ~= nil, "a dungeon that IS listed is found")

-- ---- a boss with no items is UNKNOWN, not empty ------------------------------
eq(ns.BossLootKnown({ name = "Nobody Filled This In" }), false,
   "a boss with no item list is not 'known to drop nothing'")
eq(ns.BossLootKnown({ name = "Empty", items = {} }), false,
   "an empty list is unknown too - somebody started the entry and stopped")
eq(ns.BossLootKnown({ name = "Real", items = { 1234 } }), true,
   "a boss with items is known")
eq(ns.BossLootKnown(nil), false, "and nil is handled")

-- ---- counting what is left ----------------------------------------------------
local dungeon = {
    bosses = {
        { name = "First",  items = { 100, 101 } },
        { name = "Smite",  items = { 200 } },
        { name = "Last",   items = { 300 } },
    },
}

-- Only item 200 is an upgrade: the Mr Smite case from the request.
local function upgradeIs200(id) return id == 200 end

local remaining, upgrades, unknown = ns.CountRemainingUpgrades(dungeon, {}, upgradeIs200)
eq(remaining, 3, "nothing killed yet: three bosses remain")
eq(upgrades, 1, "exactly one of them can drop something you would wear")
eq(unknown, 0, "and every boss is mapped")

-- Killing a boss with nothing for you must NOT trigger the advice.
remaining, upgrades = ns.CountRemainingUpgrades(dungeon, { First = true }, upgradeIs200)
eq(remaining, 2, "after the first kill, two remain")
eq(upgrades, 1, "and Smite is still ahead of you, so there is still a reason to be here")

-- The whole point of the request: quiet until Smite is dead, THEN nothing is left.
remaining, upgrades = ns.CountRemainingUpgrades(dungeon, { First = true, Smite = true }, upgradeIs200)
eq(remaining, 1, "one boss left after Smite")
eq(upgrades, 0, "and nothing remaining can drop an upgrade - this is when the prompt is earned")

-- ---- an unmapped boss keeps it quiet ------------------------------------------
-- This is the safety property. With one boss unmapped, "no upgrades remain" is a guess.
local partial = {
    bosses = {
        { name = "Known",   items = { 100 } },
        { name = "Unmapped" },
    },
}
remaining, upgrades, unknown = ns.CountRemainingUpgrades(partial, {}, upgradeIs200)
eq(remaining, 2, "both bosses are still up")
eq(upgrades, 0, "neither KNOWN item is an upgrade")
eq(unknown, 1, "but one boss has no data, which is what must keep the caller quiet")

-- Once the unmapped boss is dead, the remaining picture is trustworthy again.
remaining, upgrades, unknown = ns.CountRemainingUpgrades(partial, { Unmapped = true }, upgradeIs200)
eq(unknown, 0, "killing the unmapped boss removes the uncertainty with it")

-- ---- trash and other things you cannot kill ------------------------------------
-- A "Trash Mobs" section never dies. Counted as a boss it would sit in the remaining list
-- forever, the dungeon would never read as finished, and the prompt would never fire at all.
-- Counted as nothing it would hide real loot. So: a reason to STAY, never a thing to finish.
local withTrash = {
    bosses = { { name = "Only", items = { 100 } } },        -- 100 is not an upgrade
    extra  = { { name = "Trash Mobs", items = { 200 } } },  -- 200 is
}
remaining, upgrades, unknown = ns.CountRemainingUpgrades(withTrash, {}, upgradeIs200)
eq(remaining, 1, "trash is not counted among the bosses you still have to kill")
eq(upgrades, 1, "but its loot is still a reason to be here")
eq(unknown, 0, "and it is fully mapped")

-- With the boss dead, trash alone still holds the prompt back.
remaining, upgrades = ns.CountRemainingUpgrades(withTrash, { Only = true }, upgradeIs200)
eq(remaining, 0, "no bosses left")
eq(upgrades, 1, "yet trash can still drop something you would wear")

-- Trash with nothing for you must not block anything.
local dullTrash = {
    bosses = { { name = "Only", items = { 100 } } },
    extra  = { { name = "Trash Mobs", items = { 100 } } },
}
remaining, upgrades, unknown = ns.CountRemainingUpgrades(dullTrash, {}, upgradeIs200)
eq(upgrades, 0, "trash with nothing in it for you is not a reason to stay")
eq(unknown, 0, "and does not make the picture uncertain")

-- Unreadable trash is still uncertainty.
local coldTrash = {
    bosses = { { name = "Only", items = { 100 } } },
    extra  = { { name = "Trash Mobs" } },
}
remaining, upgrades, unknown = ns.CountRemainingUpgrades(coldTrash, {}, upgradeIs200)
eq(unknown, 0, "an extra section with no item list is simply skipped, not counted as unknown")

-- ---- refusals -----------------------------------------------------------------
eq(ns.CountRemainingUpgrades(nil, {}, upgradeIs200), nil, "no dungeon is nil, not zero")
eq(ns.CountRemainingUpgrades({}, {}, upgradeIs200), nil, "a dungeon with no boss list is nil too")

-- ---- the shipped table is honest about itself ---------------------------------
-- Every boss listed with items must have real ones. A seeded name with a placeholder id
-- would be exactly the confident-but-wrong entry this whole design is built to avoid.
local named, withItems = 0, 0
for name, d in pairs(ns.DUNGEON_LOOT) do
    ok(type(d.bosses) == "table" and #d.bosses > 0, name .. " lists its bosses")
    for _, boss in ipairs(d.bosses) do
        named = named + 1
        ok(type(boss.name) == "string" and boss.name ~= "", "every boss is named in " .. name)
        if boss.items then
            withItems = withItems + 1
            ok(#boss.items > 0, boss.name .. " has items rather than an empty list")
            for _, id in ipairs(boss.items) do
                ok(type(id) == "number" and id > 0, boss.name .. " lists numeric item ids")
            end
        end
    end
end
ok(named > 0, "the shipped table names at least one boss, got " .. named)

-- The table is generated from AtlasLoot rather than written by hand, so it should be big.
-- A generator that silently harvested nothing would leave a syntactically perfect file that
-- makes the whole feature a no-op, and every assertion above would still pass.
local dungeonCount = 0
for _ in pairs(ns.DUNGEON_LOOT) do dungeonCount = dungeonCount + 1 end
ok(dungeonCount >= 30, "the generated table covers the 5-mans, got " .. dungeonCount .. " dungeons")
ok(named >= 200, "and names their bosses, got " .. named)
ok(withItems >= 200, "with real item ids attached, got " .. withItems .. " bosses carrying loot")

-- The example from the request, end to end on the SHIPPED data.
local dm = ns.GetDungeonLoot("The Deadmines")
ok(dm ~= nil, "Deadmines is in the shipped table under the name GetInstanceInfo reports")
local foundSmite = false
for _, b in ipairs(dm.bosses) do if b.name == "Mr. Smite" then foundSmite = true end end
ok(foundSmite, "and Mr. Smite is one of its bosses, by the name the combat log will use")

-- ============================================================================
-- THE RUNTIME HALF - the real bodies from Valuate.lua against a mocked client
-- ============================================================================
-- Everything above tests arithmetic on a table. What actually ships is the code that decides
-- whether to interrupt you, and that is where the wrong answer costs something.

local OPTIONS = { notifyDungeonNoUpgrades = true }
function Valuate:GetOptions() return OPTIONS end
local MARKS = {}
function Valuate:MarkAutomation(key, detail) MARKS[key] = detail end

-- The mocked client.
local INSTANCE_NAME, INSTANCE_TYPE = "The Deadmines", "party"
function GetInstanceInfo() return INSTANCE_NAME, INSTANCE_TYPE end

-- Item id -> what the client knows. nil entry = never seen it, so GetItemInfo returns nothing.
local ITEM_CACHE = {}
function GetItemInfo(id)
    local e = ITEM_CACHE[id]
    if not e then return nil end
    -- Nine returns, because equipLoc is the ninth and it is what separates a chestpiece from
    -- a recipe. A mock that stopped at two made that distinction untestable.
    return e.name, e.link, nil, nil, nil, nil, nil, nil, e.equipLoc or "INVTYPE_CHEST"
end
local ITEM_STATS = {}
function Valuate:GetScaledStatsForItem(link) return ITEM_STATS[link] end
local UPGRADES = {}
function Valuate:IsUpgradeForAnyScale(link) return UPGRADES[link] == true end

local PENDING = {}
function ValuateAfter(delay, fn) table.insert(PENDING, { delay = delay, fn = fn }) end
local function firePending()
    local queue = PENDING
    PENDING = {}
    for _, p in ipairs(queue) do p.fn() end
end

local DIALOGS = {}
function Valuate:ShowConfirmDialog(opts) table.insert(DIALOGS, opts) end

local registered = {}
frame = { RegisterEvent = function(_, e) registered[e] = true end,
          UnregisterEvent = function(_, e) registered[e] = nil end }

` + sliced.join("\n") + `

local function seedItem(id, isUpgrade)
    local link = "|Hitem:" .. id .. "|h[Item " .. id .. "]|h"
    ITEM_CACHE[id] = { name = "Item " .. id, link = link }
    ITEM_STATS[link] = { Strength = 10 }
    UPGRADES[link] = isUpgrade and true or false
end

-- Something that is not gear at all: a recipe, a bag, a reagent. AtlasLoot's boss tables are
-- full of them.
local function seedJunk(id)
    local link = "|Hitem:" .. id .. "|h[Junk " .. id .. "]|h"
    ITEM_CACHE[id] = { name = "Junk " .. id, link = link, equipLoc = "" }
end

-- A dungeon shaped like the request: only the fourth boss has anything for you.
ns.DUNGEON_LOOT["Testmines"] = {
    bosses = {
        { name = "First",  items = { 9001 } },
        { name = "Second", items = { 9002 } },
        { name = "Smite",  items = { 9003 } },
        { name = "Last",   items = { 9004 } },
        -- A FIFTH boss, so that two are still standing when the prompt fires. With only one
        -- left, ConsiderDungeonLeave returns early on "the dungeon is done" and the
        -- ask-once guard below is never reached - the assertion passed while protecting
        -- nothing, and mutation testing is what said so.
        { name = "Fifth",  items = { 9005 } },
    },
}
seedItem(9001, false)
seedItem(9002, false)
seedItem(9003, true)     -- the only upgrade in the place
seedItem(9004, false)
seedItem(9005, false)

INSTANCE_NAME = "Testmines"
Valuate:ResetDungeonProgress()

-- ---- an unmapped instance is silence, at runtime too --------------------------
INSTANCE_NAME = "Some Instance Nobody Mapped"
eq(Valuate:GetCurrentDungeon(), nil, "an unmapped instance has no dungeon at runtime")
eq(Valuate:GetDungeonUpgradeStatus(), nil, "and no status to report")
DIALOGS = {}
Valuate:ConsiderDungeonLeave()
eq(#DIALOGS, 0, "and above all, no prompt - the addon has nothing to say here")

-- ---- the open world and raids are not this feature ----------------------------
INSTANCE_NAME, INSTANCE_TYPE = "Testmines", "raid"
eq(Valuate:GetCurrentDungeon(), nil, "a raid is not a 5-man, even by a matching name")
INSTANCE_TYPE = "none"
eq(Valuate:GetCurrentDungeon(), nil, "neither is standing in the open world")
INSTANCE_TYPE = "party"

-- ---- the Mr Smite sequence from the request -----------------------------------
INSTANCE_NAME = "Testmines"
Valuate:ResetDungeonProgress()

local status = Valuate:GetDungeonUpgradeStatus()
eq(status.remaining, 5, "five bosses up at the start")
eq(status.upgrades, 1, "exactly one of them has something for you")
eq(status.unknown, 0, "and every one of them is answerable")

-- Killing the first two must NOT prompt: Smite is still ahead of you.
DIALOGS = {}
Valuate:NoteDungeonUnitDeath("First")
firePending()
eq(#DIALOGS, 0, "no prompt after the first kill - Smite is still alive")
Valuate:NoteDungeonUnitDeath("Second")
firePending()
eq(#DIALOGS, 0, "still no prompt after the second")

-- A mob that is not a boss changes nothing at all.
Valuate:NoteDungeonUnitDeath("Defias Thug")
firePending()
eq(#DIALOGS, 0, "a trash mob with a name nobody mapped is ignored, not guessed at")
eq(Valuate:GetDungeonUpgradeStatus().remaining, 3, "and does not count as a boss kill")

-- Now Smite. THIS is the moment the request describes.
Valuate:NoteDungeonUnitDeath("Smite")
eq(#DIALOGS, 0, "nothing fires on the kill itself - the corpse has not been looted yet")
ok(#PENDING > 0, "the check is scheduled for a moment later instead")
firePending()
eq(#DIALOGS, 1, "once Smite is dead and looted, the prompt appears")
ok(DIALOGS[1].onAccept ~= nil, "and it is a question with an action, not a bare message")

-- Asked once, not once per boss.
DIALOGS = {}
Valuate:NoteDungeonUnitDeath("Last")
firePending()
eq(#DIALOGS, 0, "having declined once, it does not ask again on the next kill")
eq(Valuate:GetDungeonUpgradeStatus().remaining, 1,
   "and a boss is still alive, so it was the ask-once guard that stopped it rather than " ..
   "the dungeon simply being over")

-- ---- the safety property, at runtime ------------------------------------------
-- One boss with no loot data must suppress the prompt entirely, even though NOTHING
-- answerable is an upgrade. This is the case the whole design exists for.
ns.DUNGEON_LOOT["Partialmines"] = {
    bosses = {
        { name = "Known",    items = { 9001 } },   -- not an upgrade
        { name = "Unmapped" },                      -- no data at all
    },
}
INSTANCE_NAME = "Partialmines"
Valuate:ResetDungeonProgress()

status = Valuate:GetDungeonUpgradeStatus()
eq(status.upgrades, 0, "nothing KNOWN in here is an upgrade")
eq(status.unknown, 1, "but one boss cannot be answered for")

DIALOGS = {}
Valuate:ConsiderDungeonLeave()
eq(#DIALOGS, 0, "so it says nothing, rather than 'there is nothing here for you'")
ok(MARKS.dungeonLeave and MARKS.dungeonLeave:find("no loot data", 1, true),
   "and the heartbeat says WHY it stayed quiet, so silence is diagnosable")

-- ---- an uncached item is unknown, not "no" ------------------------------------
-- On a fresh login GetItemInfo returns nothing for most items. Reading that as "not an
-- upgrade" would make the addon most confident about leaving exactly when it knows least.
ns.DUNGEON_LOOT["Coldmines"] = {
    bosses = { { name = "Only", items = { 9999 } } },   -- 9999 was never seeded
}
INSTANCE_NAME = "Coldmines"
Valuate:ResetDungeonProgress()
eq(Valuate:GetDungeonUpgradeStatus().unknown, 1,
   "an item the client has never cached leaves the boss unknown")
DIALOGS = {}
Valuate:ConsiderDungeonLeave()
eq(#DIALOGS, 0, "so a cold cache produces silence, not advice to leave")

-- An item that parses to no stats at all is the same kind of unknown.
ITEM_CACHE[9999] = { name = "Item 9999", link = "cold" }   -- cached, but no stats seeded
Valuate:ResetDungeonProgress()
eq(Valuate:GetDungeonUpgradeStatus().unknown, 1,
   "an item whose tooltip parsed to nothing is unknown too, not 'no'")

-- ---- a recipe is a definite no, not a shrug ------------------------------------
-- AtlasLoot lists recipes, bags and quest items among a boss's drops. Those parse to no
-- stats, which looks exactly like "the client has not cached this yet" - and reading them as
-- unknown would leave the boss permanently unanswerable and the prompt permanently silent.
-- That failure is indistinguishable from the feature being switched off.
ns.DUNGEON_LOOT["Recipemines"] = {
    bosses = { { name = "Cook", items = { 8801 } } },   -- drops a recipe and nothing else
}
seedJunk(8801)
INSTANCE_NAME = "Recipemines"
Valuate:ResetDungeonProgress()
status = Valuate:GetDungeonUpgradeStatus()
eq(status.unknown, 0, "a recipe is not gear, and the addon can say so definitely")
eq(status.upgrades, 0, "and it is certainly not an upgrade")

DIALOGS = {}
Valuate:ConsiderDungeonLeave()
eq(#DIALOGS, 1, "so a boss that only drops recipes does NOT block the prompt")

-- ---- a finished dungeon is not worth interrupting anyone over -------------------
-- Every boss here has something for you, so no prompt can fire while any of them is alive.
-- That leaves the "the dungeon is over" check as the only thing standing between you and a
-- popup telling you to leave a dungeon you have just finished, which is pure noise.
ns.DUNGEON_LOOT["Richmines"] = {
    bosses = { { name = "A", items = { 9003 } }, { name = "B", items = { 9003 } } },
}
INSTANCE_NAME = "Richmines"
Valuate:ResetDungeonProgress()
DIALOGS = {}
Valuate:NoteDungeonUnitDeath("A")
firePending()
eq(#DIALOGS, 0, "no prompt while a boss with an upgrade is still alive")
Valuate:NoteDungeonUnitDeath("B")
firePending()
eq(#DIALOGS, 0, "and none when the last boss dies - the dungeon is simply over")
eq(Valuate:GetDungeonUpgradeStatus().remaining, 0, "nothing remains to advise about")

-- ---- switched off means switched off -------------------------------------------
INSTANCE_NAME = "Testmines"
Valuate:ResetDungeonProgress()
OPTIONS.notifyDungeonNoUpgrades = false
DIALOGS = {}
Valuate:NoteDungeonUnitDeath("First")
Valuate:NoteDungeonUnitDeath("Second")
Valuate:NoteDungeonUnitDeath("Smite")
firePending()
eq(#DIALOGS, 0, "with the option off, nothing is ever offered")
OPTIONS.notifyDungeonNoUpgrades = true

-- ---- the combat log is not left switched on ------------------------------------
-- COMBAT_LOG_EVENT_UNFILTERED is the loudest event in the game. Registering it everywhere
-- to answer a question that only arises in eight places per run is a real cost.
registered = {}
dungeonTracking = false
INSTANCE_NAME = "Some Instance Nobody Mapped"
Valuate:UpdateDungeonTracking()
eq(registered.COMBAT_LOG_EVENT_UNFILTERED, nil,
   "no combat log listener in a dungeon with no data")

INSTANCE_NAME = "Testmines"
Valuate:UpdateDungeonTracking()
eq(registered.COMBAT_LOG_EVENT_UNFILTERED, true,
   "it goes on when you enter a dungeon that has data")

INSTANCE_NAME = "Some Instance Nobody Mapped"
Valuate:UpdateDungeonTracking()
eq(registered.COMBAT_LOG_EVENT_UNFILTERED, nil, "and off again when you leave")

INSTANCE_NAME = "Testmines"
OPTIONS.notifyDungeonNoUpgrades = false
Valuate:UpdateDungeonTracking()
eq(registered.COMBAT_LOG_EVENT_UNFILTERED, nil,
   "and never goes on at all while the feature is switched off")
OPTIONS.notifyDungeonNoUpgrades = true

-- ---- a second run starts clean --------------------------------------------------
INSTANCE_NAME = "Testmines"
Valuate:ResetDungeonProgress()
Valuate:NoteDungeonUnitDeath("First")
firePending()
eq(Valuate:GetDungeonUpgradeStatus().remaining, 4, "one boss down on this run")
Valuate:ResetDungeonProgress()
eq(Valuate:GetDungeonUpgradeStatus().remaining, 5,
   "re-entering resets the kills - a second run must not inherit the first run's progress")

-- And prove it survives a kill in the SECOND run, which is the moment a stale table would
-- be read back: NoteDungeonUnitDeath re-adopts the dungeon by name, and if the old kills
-- came with it, run two would start half-finished.
Valuate:NoteDungeonUnitDeath("Second")
firePending()
eq(Valuate:GetDungeonUpgradeStatus().remaining, 4,
   "one kill into run two means four left, not three - 'First' died in the previous run")

-- ---- where do I go to fix this slot? ---------------------------------------------------
-- 36 dungeons and 2,918 item ids sat in the table while the only way to learn whether a
-- dungeon had anything for you was to be standing in it. Three rules carry this, and all
-- three are the same one: do not present a guess as a finding.

local WHERE_SCALE = { Values = { Intellect = 1.0, SpellPower = 0.8 } }
Valuate.GetPrimaryScale = function() return WHERE_SCALE, "Test" end
local PLAYER_LEVEL = 10
function UnitLevel() return PLAYER_LEVEL end
ns.EQUIP_SLOTS = ns.EQUIP_SLOTS or {}

-- itemId -> what the client knows. minLevel and equipLoc are what the filter reads.
local WHERE_ITEMS = {}
function GetItemInfo(id)
    local e = WHERE_ITEMS[id]
    if not e then return nil end
    return e.name, e.link, nil, nil, e.minLevel or 1, nil, nil, nil, e.equipLoc or "INVTYPE_CHEST"
end
function Valuate:GetScaledStatsForItem(link) return ITEM_STATS[link] end
function Valuate:IsUpgradeForAnyScale(link)
    if UPGRADES[link] == true then return true, 10 end
    return false, 0
end

local function seedWhere(id, opts)
    local link = "|Hwhere:" .. id .. "|h"
    WHERE_ITEMS[id] = { name = "W" .. id, link = link,
                        minLevel = opts.minLevel, equipLoc = opts.equipLoc }
    ITEM_STATS[link] = opts.noStats and nil or { Intellect = 5 }
    UPGRADES[link] = opts.upgrade and true or false
end

ns.DUNGEON_LOOT = {
    ["Reachable"] = { bosses = { { name = "A", items = { 7001 } } } },
    ["TooHigh"]   = { bosses = { { name = "B", items = { 7002 } } } },
    ["NotGear"]   = { bosses = { { name = "C", items = { 7003 } } } },
    ["Worse"]     = { bosses = { { name = "D", items = { 7004 } } } },
}
seedWhere(7001, { minLevel = 8,  upgrade = true })                   -- wearable and better
seedWhere(7002, { minLevel = 60, upgrade = true })                   -- better, unreachable
seedWhere(7003, { minLevel = 1,  upgrade = true, equipLoc = "" })    -- not gear at all
seedWhere(7004, { minLevel = 1,  upgrade = false })                  -- wearable, no better

local list, whyNot, unknown, asked = Valuate:FindUpgradeSources()
ok(list ~= nil, "it answers at all" .. (whyNot and (": " .. whyNot) or ""))

local named = {}
for _, e in ipairs(list or {}) do named[e.dungeon] = true end

ok(named["Reachable"] == true, "a dungeon with a wearable upgrade is named")
eq(named["TooHigh"], nil,
   "one whose upgrade needs level 60 is NOT - the level filter comes from the client, " ..
   "because the generated table carries no level range and inventing one puts a level 10 in a raid")
eq(named["NotGear"], nil, "an item that is not equippable is not an upgrade")
eq(named["Worse"], nil, "and neither is gear that loses to what you have")

-- Levelling up changes the answer, which is the point of reading the level rather than a table.
PLAYER_LEVEL = 70
list = Valuate:FindUpgradeSources()
named = {}
for _, e in ipairs(list or {}) do named[e.dungeon] = true end
ok(named["TooHigh"] == true, "at 70 the same dungeon becomes an answer")
PLAYER_LEVEL = 10

-- ---- an uncached item is counted, not silently dropped ---------------------------------
ns.DUNGEON_LOOT = { ["Cold"] = { bosses = { { name = "A", items = { 7999 } } } } }
list, whyNot, unknown, asked = Valuate:FindUpgradeSources()
eq(#list, 0, "an item the client cannot read yields no recommendation")
ok(unknown >= 1, "but it is COUNTED as unknown rather than dropped - a cold cache must read " ..
   "as 'ask again', never as 'nothing here'")
ok(asked >= 1, "and the number asked is reported, so coverage is visible")

-- ---- ordering is the answer -------------------------------------------------------------
ns.DUNGEON_LOOT = {
    ["Small"] = { bosses = { { name = "A", items = { 8001 } } } },
    ["Big"]   = { bosses = { { name = "B", items = { 8002 } } } },
}
seedWhere(8001, { minLevel = 1, upgrade = true })
seedWhere(8002, { minLevel = 1, upgrade = true })
function Valuate:IsUpgradeForAnyScale(link)
    if link:find("8002", 1, true) then return true, 50 end
    if link:find("8001", 1, true) then return true, 5 end
    return false, 0
end
list = Valuate:FindUpgradeSources()
ok(list[1] and list[1].dungeon == "Big",
   "the biggest upgrade is listed first - the question is where to GO, so the order IS the answer")

-- Stable between runs. pairs() order is not an order, and a list that reshuffles between two
-- runs of the same command reads as the addon being unsure of itself.
eq(#list, 2, "both dungeons are recognised before ordering is asserted")
local first = (list[1] and list[1].dungeon or "?") .. "/" .. (list[2] and list[2].dungeon or "?")
for _ = 1, 6 do
    local again = Valuate:FindUpgradeSources()
    eq((again[1] and again[1].dungeon or "?") .. "/" .. (again[2] and again[2].dungeon or "?"), first,
       "the same question gives the same order every time")
end

return failures, checks
`,
  "dungeonloot",
  "dungeon loot data and the silence rule"
);
