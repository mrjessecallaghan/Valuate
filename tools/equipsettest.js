#!/usr/bin/env node
/*
 * @gate Saving best-in-slot as an equipment set never writes a half-swapped mix
 *
 * Runs the real UnmatchedBestSlots / PlanEquipmentSetSave against mocked gear.
 *
 * SaveEquipmentSet saves WHAT YOU ARE WEARING - there is no API to write a set from a list -
 * so this equips first and saves after, and equipping is asynchronous. That single fact is
 * the whole risk:
 *
 *   SAVING TOO EARLY writes a set that is part best gear and part whatever had not swapped
 *   yet. Nothing looks wrong at the time. You find out a week later when you click the set
 *   and get the mix back, with no way to tell what it was supposed to be.
 *
 *   OVERWRITING silently destroys a set someone built by hand. This command has no business
 *   doing that without asking.
 *
 * Refusing is the safe failure. Saving anyway is not, which is why the timeout path reports
 * and writes nothing.
 *
 * Usage:  node tools/equipsettest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const data = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Data.lua"), "utf8");

const slots = data.match(/^ns\.EQUIP_SLOTS = \{[\s\S]*?\r?\n\}/m);
if (!slots) {
  console.error("  SLICE  could not find ns.EQUIP_SLOTS in ui/Data.lua - this gate tests nothing");
  process.exit(1);
}

const PIECES = [
  /^local function GetItemIdFromLink\([\s\S]*?\r?\nend/m,
  /^local levelUpEquipPending = false/m,
  /^function Valuate:ShouldAutoEquipOnLevelUp\([\s\S]*?\r?\nend/m,
  /^function Valuate:TryAutoEquipOnLevelUp\([\s\S]*?\r?\nend/m,
  /^function Valuate:UnmatchedBestSlots\([\s\S]*?\r?\nend/m,
  /^function Valuate:PlanEquipmentSetSave\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return m[0];
});

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
local function saysAbout(reason, word, what)
    checks = checks + 1
    if type(reason) ~= "string" or not reason:find(word, 1, true) then
        table.insert(failures, what .. " (reason was: " .. tostring(reason) .. ")")
    end
end

ns = {}
` + slots[0] + `

Valuate = {}
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local BEST = { Dps = {} }
function Valuate:GetBestEquipment() return BEST end
function Valuate:GetPrimaryScale() return {}, "Dps" end

local EQUIPPED = {}
function GetInventoryItemLink(_, slotId) return EQUIPPED[slotId] end

local IN_COMBAT = false
function InCombatLockdown() return IN_COMBAT end

local SETS = {}
function GetNumEquipmentSets() return #SETS end
function GetEquipmentSetInfo(i) return SETS[i] end
function SaveEquipmentSet(name) SETS[#SETS + 1] = name end

local function link(id) return "|Hitem:" .. id .. ":0:0:0:0:0:0:0:80|h[Item " .. id .. "]|h" end

` + sliced.join("\n") + `

local function names(list) return table.concat(list or {}, ",") end

-- ---- which slots have not caught up yet --------------------------------------
BEST.Dps[5]  = { itemLink = link(105) }   -- Chest
BEST.Dps[15] = { itemLink = link(115) }   -- Back
EQUIPPED[5], EQUIPPED[15] = link(105), link(115)
eq(names(Valuate:UnmatchedBestSlots("Dps")), "", "with everything equipped, nothing is unmatched")

EQUIPPED[5] = link(999)
eq(names(Valuate:UnmatchedBestSlots("Dps")), "Chest", "a slot holding the wrong item is unmatched")

EQUIPPED[5] = nil
eq(names(Valuate:UnmatchedBestSlots("Dps")), "Chest", "an empty slot is unmatched too")
EQUIPPED[5] = link(105)

-- Matched by item ID, so your own enchanted copy still counts as the right item. Comparing
-- links would leave a slot permanently "unmatched" and the save would never happen.
EQUIPPED[5] = "|cffa335ee|Hitem:105:2343:41285:0:0:0:0:0:80|h[Item 105]|h|r"
eq(names(Valuate:UnmatchedBestSlots("Dps")), "",
   "an enchanted copy of the right item counts as matched")
EQUIPPED[5] = link(105)

-- BANK gear is excluded. Equip All cannot reach it, so waiting for it would mean waiting
-- forever and never saving anything.
BEST.Dps[7] = { itemLink = link(107), source = "bank" }
eq(names(Valuate:UnmatchedBestSlots("Dps")), "",
   "a best item sitting in the bank does not block the save")
BEST.Dps[7] = nil

eq(Valuate:UnmatchedBestSlots("NoSuchScale"), nil, "an unknown scale is nil, not an empty list")

-- ---- what can be decided before touching your gear ---------------------------
SETS = {}
local plan = Valuate:PlanEquipmentSetSave("Raid Gear", "Dps")
ok(plan ~= nil, "a valid request plans")
eq(plan.setName, "Raid Gear", "keeping the name")
eq(plan.overwrites, false, "and noting that nothing is being replaced")

eq(Valuate:PlanEquipmentSetSave("  Raid Gear  ", "Dps").setName, "Raid Gear",
   "surrounding whitespace is trimmed, so 'Raid ' and 'Raid' are not two different sets")

-- An existing set must be FLAGGED, not silently replaced. Someone built that by hand.
SETS = { "Raid Gear" }
eq(Valuate:PlanEquipmentSetSave("Raid Gear", "Dps").overwrites, true,
   "an existing set is reported as an overwrite")
eq(Valuate:PlanEquipmentSetSave("Other", "Dps").overwrites, false,
   "a different name is not")
SETS = {}

-- ---- refusals, each naming itself --------------------------------------------
eq(Valuate:PlanEquipmentSetSave("", "Dps"), nil, "an empty name is refused")
saysAbout(select(2, Valuate:PlanEquipmentSetSave("", "Dps")), "name", "saying a name is needed")
eq(Valuate:PlanEquipmentSetSave("   ", "Dps"), nil, "and so is whitespace")

eq(Valuate:PlanEquipmentSetSave("X", nil), nil, "no active scale is refused")
saysAbout(select(2, Valuate:PlanEquipmentSetSave("X", nil)), "scale", "by name")

eq(Valuate:PlanEquipmentSetSave("X", "NoSuchScale"), nil, "a scale with no scan data is refused")
saysAbout(select(2, Valuate:PlanEquipmentSetSave("X", "NoSuchScale")), "scan",
   "and points at /valuate scan")

IN_COMBAT = true
eq(Valuate:PlanEquipmentSetSave("X", "Dps"), nil, "in combat it refuses before touching anything")
saysAbout(select(2, Valuate:PlanEquipmentSetSave("X", "Dps")), "combat", "and says why")
IN_COMBAT = false

local realSave = SaveEquipmentSet
SaveEquipmentSet = nil
eq(Valuate:PlanEquipmentSetSave("X", "Dps"), nil, "a client without SaveEquipmentSet refuses")
saysAbout(select(2, Valuate:PlanEquipmentSetSave("X", "Dps")), "SaveEquipmentSet",
   "and names the API it could not find")
SaveEquipmentSet = realSave

-- A client with no set-listing API cannot detect an overwrite. It must still plan - the
-- worst case is being asked to confirm nothing, not being unable to save at all.
local realNum, realInfo = GetNumEquipmentSets, GetEquipmentSetInfo
GetNumEquipmentSets, GetEquipmentSetInfo = nil, nil
local blindPlan = Valuate:PlanEquipmentSetSave("Raid Gear", "Dps")
ok(blindPlan ~= nil, "a client that cannot list sets can still save one")
eq(blindPlan.overwrites, false, "and reports no known overwrite rather than guessing")
GetNumEquipmentSets, GetEquipmentSetInfo = realNum, realInfo

-- ---- equipping when you level ------------------------------------------------
-- You level mid-pull constantly, so the interesting behaviour is not "does it equip" but
-- "what does it do when it CANNOT, and does it remember to come back".
local OPTIONS = {}
Valuate.GetOptions = function() return OPTIONS end
local equips = {}
Valuate.EquipBestSet = function(_, scaleName) table.insert(equips, scaleName) end
local MARKS = {}
Valuate.MarkAutomation = function(_, key, detail) MARKS[key] = detail end

OPTIONS.autoEquipOnLevelUp = nil
eq(Valuate:TryAutoEquipOnLevelUp(false), false, "switched off, levelling equips nothing")
eq(#equips, 0, "nothing was equipped")

OPTIONS.autoEquipOnLevelUp = true
eq(Valuate:TryAutoEquipOnLevelUp(false), true, "switched on, levelling equips your best")
eq(equips[1], "Dps", "for the active scale")

-- In combat it must WAIT, not fail. The client refuses gear changes there anyway, and this
-- is the common case: you ding in the middle of the pull that levelled you.
equips = {}
IN_COMBAT = true
eq(Valuate:TryAutoEquipOnLevelUp(false), false, "levelling in combat does not swap gear")
eq(#equips, 0, "nothing equipped mid-fight")
saysAbout(select(2, Valuate:TryAutoEquipOnLevelUp(false)), "combat", "and says it is waiting")

-- ...and comes back when the fight ends.
IN_COMBAT = false
eq(Valuate:TryAutoEquipOnLevelUp(true), true, "leaving combat completes the deferred equip")
eq(equips[1], "Dps", "equipping what it was waiting to")

-- Leaving combat with nothing pending must do nothing at all. Otherwise every fight you
-- finish re-equips your gear, forever.
equips = {}
eq(Valuate:TryAutoEquipOnLevelUp(true), false, "leaving combat with nothing waiting does nothing")
eq(#equips, 0, "no gear was touched")

-- A permanent refusal must NOT leave something pending, or it fires at the end of an
-- unrelated fight much later - gear swapping for no reason the player can connect to.
equips = {}
IN_COMBAT = false
OPTIONS.autoEquipOnLevelUp = nil
Valuate:TryAutoEquipOnLevelUp(false)
OPTIONS.autoEquipOnLevelUp = true
eq(Valuate:TryAutoEquipOnLevelUp(true), false,
   "a level gained while the option was OFF does not equip when a later fight ends")
eq(#equips, 0, "nothing swapped out of nowhere")

-- No active scale is a permanent refusal too, named rather than silent.
equips = {}
Valuate.GetPrimaryScale = function() return nil, nil end
eq(Valuate:TryAutoEquipOnLevelUp(false), false, "with no active scale it refuses")
saysAbout(select(2, Valuate:TryAutoEquipOnLevelUp(false)), "scale", "and says so")
Valuate.GetPrimaryScale = function() return {}, "Dps" end

return failures, checks
`,
  "equipsettest",
  "saving best-in-slot as an equipment set"
);
