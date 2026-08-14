#!/usr/bin/env node
/*
 * @gate A bag repaint stays cheap as scales and items multiply
 *
 * Every other gate here asks whether the answer is RIGHT. This one asks what the answer
 * COST, because nothing else can: the static gates see structure, the runtime gates see
 * behaviour, and neither notices a correct function that got ten times more expensive.
 *
 * The measured path is the one AdiBags drives. Its filter runs once per item per repaint
 * and calls Valuate:IsBestInSlot and Valuate:GetFutureUpgradeScales for each - so opening
 * a full bag is a burst of a couple of hundred calls into this code, and the roadmap has
 * flagged it as the likeliest hot spot since before there was a way to check.
 *
 * Counts, not milliseconds. Wall-clock under fengari says nothing about Lua 5.1 in the
 * client, but "how many times did we sort a list that cannot have changed" transfers
 * exactly. The budgets below are ceilings the current code sits under; a change that
 * blows one has made a bag repaint measurably worse and should have to say so out loud.
 *
 * Usage:  node tools/hotpath.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local EquipSlotToInvNumber = \{[\s\S]*?\r?\n\}/m,
  /^local function GetItemIdFromLink\([\s\S]*?\r?\nend/m,
  // The cache locals must come BEFORE the function that reads them, or they slice into
  // nil globals and the TTL comparison blows up on the first call.
  /^local cacheStats = \{[^\r\n]*\}/m,
  /^function Valuate:GetCacheStats\([\s\S]*?\r?\nend/m,
  /^local ACTIVE_SCALES_TTL = \d+/m,
  /^local activeScalesCache, activeScalesAt = [^\r\n]*/m,
  /^function Valuate:InvalidateActiveScales\([\s\S]*?\r?\nend/m,
  /^function Valuate:GetActiveScales\([\s\S]*?\r?\nend/m,
  /^local targetSlotsCache = \{\}/m,
  /^local function TargetSlotsForItem\([\s\S]*?\r?\nend/m,
  /^function Valuate:GetBestForInfo\([\s\S]*?\r?\nend/m,
  /^function Valuate:IsBestInSlot\([\s\S]*?\r?\nend/m,
  /^function Valuate:GetFutureUpgradeScales\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate measures nothing");
    process.exit(1);
  }
  return m[0];
});

// One full bag of gear, against a realistic number of scales. Both numbers are the point:
// a per-item cost that also scales with the scale count is the shape worth catching.
const ITEMS = 120;
const SCALES = 6;

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function budget(name, got, ceiling)
    checks = checks + 1
    if got > ceiling then
        table.insert(failures, string.format(
            "%s: %d, over the budget of %d - a bag repaint just got more expensive", name, got, ceiling))
    end
end

-- ---- counting instruments --------------------------------------------------
local counts = { sorts = 0, getItemInfo = 0, scaleWalks = 0, activeCalls = 0 }
local realSort = table.sort
table.sort = function(t, cmp) counts.sorts = counts.sorts + 1 return realSort(t, cmp) end

Valuate = {}

local SCALES_TABLE = {}
for i = 1, ${SCALES} do
    SCALES_TABLE["Scale" .. i] = {
        DisplayName = "Scale " .. i, Visible = true, Values = { Strength = 1.0 },
    }
end
function Valuate:GetScales()
    counts.scaleWalks = counts.scaleWalks + 1
    return SCALES_TABLE
end

local BEST = {}
for name in pairs(SCALES_TABLE) do BEST[name] = { future = {} } end
function Valuate:GetBestEquipment() return BEST end
function Valuate:IsItemExcludedFromEvaluation() return false end

-- A clock the test drives, so the TTL can be made to lapse and to run backwards.
local clock = 0
function GetTime() return clock end

-- Items the client has not received from the server yet. GetItemInfo returns nothing at
-- all for these, which is a different answer from "this goes nowhere".
local UNCACHED = {}
-- Half the bag is not gear at all - potions, reagents, quest items. That is the REALISTIC
-- shape, and it is also the branch that remembers "this goes nowhere": a first draft of
-- this gate made every item a chest piece, so that branch was never taken and a mutation
-- deleting it passed cleanly.
local NONGEAR = {}
function GetItemInfo(link)
    counts.getItemInfo = counts.getItemInfo + 1
    if UNCACHED[link] then return nil end
    if NONGEAR[link] then
        return "Potion", link, 1, 80, 70, "Consumable", "Potion", 20, ""
    end
    return "Item", link, 4, 80, 70, "Armor", "Plate", 1, "INVTYPE_CHEST"
end

` + sliced.join("\n") + `

-- Wrap AFTER slicing so the sliced source is the shipped source, not an instrumented copy.
local realActive = Valuate.GetActiveScales
Valuate.GetActiveScales = function(self)
    counts.activeCalls = counts.activeCalls + 1
    return realActive(self)
end

-- ---- correctness first: an optimisation that changes the answer is a bug ----
local LINKS = {}
for i = 1, ${ITEMS} do
    LINKS[i] = "|cffa335ee|Hitem:" .. (40000 + i) .. ":0:0:0:0:0:0:0:80|h[Item " .. i .. "]|h|r"
end

-- The back half of the bag is not equippable. The named items below stay gear so the
-- correctness checks keep meaning what they say.
for i = 61, ${ITEMS} do NONGEAR[LINKS[i]] = true end

-- Item 1 is best-in-slot for two scales; item 2 is a future upgrade for one. Everything
-- else is neither, which is the common case and the one that must stay cheapest.
local firstId = 40001
BEST.Scale1[5] = { itemLink = LINKS[1] }
BEST.Scale2[5] = { itemLink = LINKS[1] }
BEST.Scale3.future[5] = { itemLink = LINKS[2] }

local best1 = Valuate:IsBestInSlot(LINKS[1])
ok(best1 ~= nil and #best1 == 2, "item 1 is best-in-slot for exactly two scales")
ok(Valuate:IsBestInSlot(LINKS[3]) == nil, "an ordinary item is best for nothing")
local fut = Valuate:GetFutureUpgradeScales(LINKS[2])
ok(fut ~= nil and #fut == 1, "item 2 is a future upgrade for exactly one scale")
ok(Valuate:GetFutureUpgradeScales(LINKS[3]) == nil, "an ordinary item has no future scales")

-- ---- now the measurement ---------------------------------------------------
-- One repaint, driven exactly as Valuate-AdiBags:Filter drives it.
-- From COLD. A repaint usually follows a gear scan, which invalidates the list, so the
-- honest measurement pays for one build rather than inheriting a warm cache from the
-- correctness checks above.
Valuate:InvalidateActiveScales()
for k in pairs(targetSlotsCache) do targetSlotsCache[k] = nil end
counts = { sorts = 0, getItemInfo = 0, scaleWalks = 0, activeCalls = 0 }
for i = 1, ${ITEMS} do
    Valuate:IsBestInSlot(LINKS[i])
    Valuate:GetFutureUpgradeScales(LINKS[i])
end
local cold = counts

-- And again, warm - which is what every repaint after the first one actually is.
counts = { sorts = 0, getItemInfo = 0, scaleWalks = 0, activeCalls = 0 }
for i = 1, ${ITEMS} do
    Valuate:IsBestInSlot(LINKS[i])
    Valuate:GetFutureUpgradeScales(LINKS[i])
end
local warm = counts

__report = string.format(
    "  |  %d items x %d scales. Cold repaint: %d GetActiveScales (%.1f/item), %d sorts, " ..
    "%d scale walks, %d GetItemInfo.  Warm repaint: %d sorts, %d GetItemInfo.",
    ${ITEMS}, ${SCALES}, cold.activeCalls, cold.activeCalls / ${ITEMS}, cold.sorts,
    cold.scaleWalks, cold.getItemInfo, warm.sorts, warm.getItemInfo)

counts = cold

-- The active-scale list is derived from the scales table alone. It cannot change while a
-- repaint is in flight, so rebuilding and re-SORTING it per item is work with no possible
-- effect on the answer. One sort per repaint is the honest ceiling; the budget allows a
-- handful of misses rather than demanding a perfect cache.
budget("sorts per repaint", counts.sorts, 8)
budget("scale-table walks per repaint", counts.scaleWalks, 8)

-- GetItemInfo is the expensive one in the client: for an item the server has not sent yet
-- it misses entirely. The filter asks two questions per item and both need the same
-- immutable fact - where the item is worn - so ONE call per item is the ceiling cold, and
-- none at all once seen. An item's equip location cannot change, so a warm repaint has
-- nothing left to ask.
budget("GetItemInfo, cold repaint", cold.getItemInfo, ${ITEMS})
budget("GetItemInfo, warm repaint", warm.getItemInfo, 0)
budget("sorts, warm repaint", warm.sorts, 1)

-- And the cache must not have broken the answers it speeds up.
local again = Valuate:IsBestInSlot(LINKS[1])
ok(again ~= nil and #again == 2, "still best for two scales after a full repaint")

-- A scale turned off mid-session must take effect. This is the one thing a cached list
-- can get wrong, and getting it wrong marks gear as surplus that is not.
SCALES_TABLE.Scale1.Visible = false
SCALES_TABLE.Scale2.Visible = false
Valuate:InvalidateActiveScales()
local afterHide = Valuate:IsBestInSlot(LINKS[1])
ok(afterHide == nil, "hiding both its scales stops item 1 being best for anything")

SCALES_TABLE.Scale1.Visible = true
Valuate:InvalidateActiveScales()
local afterShow = Valuate:IsBestInSlot(LINKS[1])
ok(afterShow ~= nil and #afterShow == 1, "showing one again brings it back for that one")

-- A brand new scale is an addition, not an edit - the cache must notice it too.
SCALES_TABLE.Scale7 = { DisplayName = "Scale 7", Visible = true, Values = { Agility = 1.0 } }
BEST.Scale7 = { future = {} }
BEST.Scale7[5] = { itemLink = LINKS[1] }
Valuate:InvalidateActiveScales()
local afterAdd = Valuate:IsBestInSlot(LINKS[1])
ok(afterAdd ~= nil and #afterAdd == 2, "a newly created scale counts immediately")

-- ---- the TTL, which is the safety net rather than the mechanism --------------
-- Explicit invalidation is how this is SUPPOSED to stay correct. The TTL exists for the
-- path nobody routed through ResetTooltips, and a stale active list marks gear as surplus
-- that is not - which feeds auto-delete. So the net has to actually be there.
clock = 1000
local baseline = #Valuate:GetActiveScales()
SCALES_TABLE.Scale8 = { DisplayName = "Scale 8", Visible = true, Values = { Spirit = 1.0 } }
ok(#Valuate:GetActiveScales() == baseline,
   "inside the TTL, a change that skipped invalidation is not seen yet")
clock = 1005
ok(#Valuate:GetActiveScales() == baseline + 1,
   "once the TTL lapses the list self-heals with no explicit invalidation")

-- A /reload resets GetTime, so the clock can run BACKWARDS. Serving the cache then would
-- pin a stale list for as long as the difference - minutes, not one second.
clock = 3
SCALES_TABLE.Scale9 = { DisplayName = "Scale 9", Visible = true, Values = { Spirit = 1.0 } }
ok(#Valuate:GetActiveScales() == baseline + 2,
   "a backwards clock rebuilds rather than serving a stale list")

-- ---- the one thing the slot cache must never remember: a miss ---------------
-- GetItemInfo returns nothing for an item the server has not sent yet. Storing that as
-- "goes nowhere" would leave the item unequippable in Valuate's eyes until a /reload -
-- and the items most likely to be uncached are the ones that just dropped.
for k in pairs(targetSlotsCache) do targetSlotsCache[k] = nil end
UNCACHED[LINKS[50]] = true
BEST.Scale3[5] = { itemLink = LINKS[50] }
ok(Valuate:IsBestInSlot(LINKS[50]) == nil,
   "an item the client has not cached yet is nobody's best, for now")

UNCACHED[LINKS[50]] = nil
local nowKnown = Valuate:IsBestInSlot(LINKS[50])
ok(nowKnown ~= nil and #nowKnown == 1,
   "and once the client has it, it is evaluated - the miss was not remembered")

-- A genuine "this is not equippable" IS worth remembering, and must not cost a second call.
local before = counts.getItemInfo
Valuate:IsBestInSlot(LINKS[50])
ok(counts.getItemInfo == before, "a known equip location is never looked up twice")

-- ---- the counters /valuate profile reports ---------------------------------
-- These are the only evidence that will ever exist from inside the client, so they have to
-- agree with what this gate independently measured. A counter that never moves would report
-- a healthy "not used yet" forever while the cache quietly missed every time.
local cs = Valuate:GetCacheStats()
ok(cs.activeHit > 0 and cs.activeBuild > 0,
   "the active-scale counters recorded both hits and builds")
ok(cs.slotHit > 0 and cs.slotMiss > 0,
   "the slot-lookup counters recorded both hits and misses")

-- The independent check: the gate counted 120 GetItemInfo calls across the cold repaint,
-- and a miss is the ONLY thing that calls it. If the counter disagrees it is not measuring
-- what it claims to.
ok(cs.slotMiss >= ${ITEMS},
   "slot misses account for at least the one-per-item the cold repaint had to pay")
ok(cs.activeHit > cs.activeBuild,
   "the active-scale list is served far more often than it is rebuilt")

return failures, checks
`,
  "hotpath",
  "a bag repaint"
);
