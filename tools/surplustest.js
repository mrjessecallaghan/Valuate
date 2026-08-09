#!/usr/bin/env node
/*
 * @gate Surplus-gear marking says no unless it is certain
 *
 * Runs the REAL source of ComputeSurplusGear from Valuate-AdiBags.
 *
 * This is the one uncovered decision in the project that can end in gear being DELETED.
 * "Mark surplus gear as junk" routes anything that is neither best-in-slot nor a future
 * upgrade into AdiBags' Junk section, and the Junk section is what auto-delete and auto-sell
 * consume. A wrong "yes" here is not a mislabelled bag icon; it is an item destroyed.
 *
 * The asymmetry is the whole design and it is what these checks are about. A wrong "no"
 * leaves clutter in your bags. A wrong "yes" is irreversible - so every uncertainty must
 * answer NO: no best-in-slot data yet, item not in the client's cache, Valuate has no
 * opinion about the slot, part of a saved equipment set, above the quality ceiling, or
 * excluded from evaluation at all.
 *
 * Sliced rather than loaded: the file is an AceAddon module and needs AdiBags to exist, and
 * this function needs none of that - only a `self` with a profile on it.
 *
 * NOTE: the source lives in a SIBLING addon, not in this repository. That is unusual for a
 * gate here and worth knowing before trusting a green run: on a machine with only Valuate
 * checked out this SKIPS rather than fails, because a gate that failed for being unable to
 * find optional code would train people to ignore it. `Valuate-AdiBags` has no git remote
 * yet, so nothing else guards it at all.
 *
 * Usage:  node tools/surplustest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const SRC = path.resolve(ADDON_ROOT, "..", "Valuate-AdiBags", "Valuate-AdiBags.lua");
if (!fs.existsSync(SRC)) {
  console.log("SKIP  Valuate-AdiBags is not installed next to this addon; nothing to check.");
  process.exit(0);
}

const lua = fs.readFileSync(SRC, "utf8");
// CRLF-tolerant: the integration addons ship with Windows line endings and tab
// indentation, unlike the core, so a slice anchored on "\nend\n" finds nothing.
const m = lua.match(/^function mod:ComputeSurplusGear\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `function mod:ComputeSurplusGear` in Valuate-AdiBags.lua - " +
      "it was renamed or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end

-- The upvalues the sliced function reads. Declared here because the slice does not carry
-- them; each is a guard, and each gets switched off one at a time below.
local bestDataUsable = true
local equipmentSetItems = {}
local slotHasBest = true
local function SlotHasBest() return slotHasBest end

local mod = { db = { profile = { markNonBestMaxQuality = 2 } } }

-- The world, set to "this item IS surplus" so that every check below can turn exactly one
-- thing off and watch the answer flip to no.
local ITEM = 1234
local itemQuality, itemEquipLoc, itemKnown = 1, "INVTYPE_HEAD", true
local bestList, futureList, excluded = nil, nil, false

function GetItemInfo(id)
    if not itemKnown then return nil end
    return "Thing", "|Hitem:" .. tostring(id) .. "|h[Thing]|h", itemQuality, 0, 0, "", "", 1, itemEquipLoc
end

Valuate = {
    IsBestInSlot = function(_, link) return bestList end,
    GetFutureUpgradeScales = function(_, link) return futureList end,
    IsItemExcludedFromEvaluation = function(_, link) return excluded end,
}

` + m[0] + `

local function reset()
    bestDataUsable = true
    equipmentSetItems = {}
    slotHasBest = true
    mod.db.profile.markNonBestMaxQuality = 2
    itemQuality, itemEquipLoc, itemKnown = 1, "INVTYPE_HEAD", true
    bestList, futureList, excluded = nil, nil, false
end

-- ---- the baseline: this item really is surplus --------------------------------
-- Everything below turns ONE thing off. If this case ever stops answering yes, the rest of
-- the file proves nothing, because every check would pass for the wrong reason.
reset()
ok(mod:ComputeSurplusGear(ITEM) == true,
   "an ordinary green helm that is nobody's best is surplus")

-- ---- and every uncertainty says no ---------------------------------------------
reset(); bestDataUsable = false
ok(mod:ComputeSurplusGear(ITEM) == false,
   "no trustworthy best-in-slot data yet: says no")

reset(); itemKnown = false
ok(mod:ComputeSurplusGear(ITEM) == false,
   "the client has not cached the item yet: says no")

reset(); itemEquipLoc = ""
ok(mod:ComputeSurplusGear(ITEM) == false,
   "not gear at all: says no")

reset(); slotHasBest = false
ok(mod:ComputeSurplusGear(ITEM) == false,
   "Valuate holds no best for that slot, so its absence means nothing: says no")

reset(); equipmentSetItems[ITEM] = true
ok(mod:ComputeSurplusGear(ITEM) == false,
   "part of a saved equipment set: says no")

reset(); itemQuality = 3
ok(mod:ComputeSurplusGear(ITEM) == false,
   "above the quality ceiling: says no")

reset(); excluded = true
ok(mod:ComputeSurplusGear(ITEM) == false,
   "excluded from evaluation (fishing poles, profession tools): says no")

reset(); bestList = { "Melee" }
ok(mod:ComputeSurplusGear(ITEM) == false,
   "best-in-slot for a scale: says no")

reset(); futureList = { "Melee" }
ok(mod:ComputeSurplusGear(ITEM) == false,
   "a future upgrade you cannot equip yet: says no")

-- ---- the empty-table trap --------------------------------------------------------
-- IsBestInSlot and GetFutureUpgradeScales return a TABLE. An empty one means "best for
-- nothing", and \`if best then\` is true for {} in Lua - so a naive check would protect every
-- item ever asked about and the feature would silently do nothing. The opposite mistake to
-- the dangerous one, but it makes the guard meaningless either way.
reset(); bestList = {}
ok(mod:ComputeSurplusGear(ITEM) == true,
   "an EMPTY best-for list does not protect: it means best for nothing")

reset(); futureList = {}
ok(mod:ComputeSurplusGear(ITEM) == true,
   "...and neither does an empty future list")

-- ---- the quality ceiling is a ceiling ---------------------------------------------
reset(); mod.db.profile.markNonBestMaxQuality = 2; itemQuality = 2
ok(mod:ComputeSurplusGear(ITEM) == true, "quality exactly at the ceiling is allowed")
reset(); mod.db.profile.markNonBestMaxQuality = 2; itemQuality = 3
ok(mod:ComputeSurplusGear(ITEM) == false, "one above the ceiling is not")
reset(); mod.db.profile.markNonBestMaxQuality = 0; itemQuality = 1
ok(mod:ComputeSurplusGear(ITEM) == false, "a ceiling of grey excludes white")

-- A missing quality is an unknown, and an unknown must say no.
reset(); itemQuality = nil
ok(mod:ComputeSurplusGear(ITEM) == false, "unknown quality: says no")

return failures, checks
`,
  "surplustest",
  "surplus-gear marking"
);
