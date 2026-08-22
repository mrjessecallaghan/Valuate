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

const NL = String.fromCharCode(10);
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
// Sliced by walking lines, not by regex: these files ship CRLF, and an escape written
// through the shell has been lost every time it was tried today.
const srcLines = lua.split(NL);
const callerStart = srcLines.findIndex(function (l) {
  return l.indexOf("function mod:IsSurplusGear(") === 0;
});
let callerEnd = callerStart;
const CR = String.fromCharCode(13);
while (callerEnd < srcLines.length &&
       srcLines[callerEnd].split(CR).join("") !== "end") callerEnd++;
if (callerStart < 0 || callerEnd >= srcLines.length) {
  console.error(
    "  SLICE  could not find function mod:IsSurplusGear in Valuate-AdiBags.lua - " +
      "the memoisation is untested"
  );
  process.exit(1);
}
const caller = [srcLines.slice(callerStart, callerEnd + 1).join(NL)];

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

` + "surplusCache = {}" + NL + m[0] + NL + caller[0] + `

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

-- ---- the memo, which had no test at all --------------------------------------------------------
-- Only the decision was covered; the caller that caches it was not. This is where the feature
-- either works quietly or silently does nothing, and the two are indistinguishable from outside.
--
-- Driven through the fixture's own itemKnown flag rather than by overriding GetItemInfo: the
-- first version of this block reached around the fixture and inherited whatever state the checks
-- above had left behind, which is how a test ends up asserting the wrong baseline.
reset()
mod.db.profile.markNonBestAsJunk = true

local computes = 0
local realCompute = mod.ComputeSurplusGear
mod.ComputeSurplusGear = function(self, id) computes = computes + 1 return realCompute(self, id) end

-- A decided answer is remembered, or every bag repaint re-derives it for every item.
surplusCache = {}
computes = 0
eq(mod:IsSurplusGear(ITEM), true, "a surplus item is reported as surplus")
mod:IsSurplusGear(ITEM)
eq(computes, 1, "and computed once, then remembered")

-- AN UNCACHED ITEM IS NOT REMEMBERED. GetItemInfo returns nothing for one, so the answer is
-- "not yet" rather than "no" - and storing it makes the no permanent for the session. The item
-- would finish loading and never be reconsidered, which is the feature silently doing nothing
-- for exactly the items that were slow to arrive.
reset()
surplusCache = {}
computes = 0
itemKnown = false
eq(mod:IsSurplusGear(ITEM), false, "an item the client has not cached is not surplus")
mod:IsSurplusGear(ITEM)
eq(computes, 2, "and the answer is NOT remembered, so it is asked again")

-- ...and once it loads, the real answer comes through rather than a stale no.
itemKnown = true
eq(mod:IsSurplusGear(ITEM), true, "once the item loads, the real answer is reached")

-- ---- the switch --------------------------------------------------------------------------------
-- Off means off, and means not computing either: this runs per item per bag repaint.
reset()
surplusCache = {}
computes = 0
mod.db.profile.markNonBestAsJunk = false
eq(mod:IsSurplusGear(ITEM), false, "with the option off nothing is surplus")
eq(computes, 0, "and nothing is even computed, on a path that runs per item per repaint")
mod.db.profile.markNonBestAsJunk = true

-- No item, no answer. Called from a filter that sees whatever is in the bag.
eq(mod:IsSurplusGear(nil), false, "no item id is not surplus")

mod.ComputeSurplusGear = realCompute

return failures, checks
`,
  "surplustest",
  "surplus-gear marking"
);
