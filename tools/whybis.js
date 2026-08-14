#!/usr/bin/env node
/*
 * @gate "Why isn't this my best-in-slot?" gives a true answer, not a plausible one
 *
 * Runs the real Valuate:ExplainBestInSlot against a built best-equipment table.
 *
 * This is the addon's core output finally getting a diagnostic, and a diagnostic that
 * lies is worse than none: you act on it. The distinctions it has to keep straight all
 * look the same from outside - an item that loses on points, one that scores nothing at
 * all, one whose scale has no weights, and one that WOULD win but arrived after the last
 * scan. The old behaviour for every one of those was silence.
 *
 * The "unscanned" verdict is the one worth the most care. Reporting it as "beaten" would
 * be a confident lie about an item you should go and equip.
 *
 * Usage:  node tools/whybis.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local EquipSlotToInvNumber = \{[\s\S]*?\r?\n\}/m,
  /^local function GetItemIdFromLink\([\s\S]*?\r?\nend/m,
  // The in-transit guard, read (never relaxed) by GetScaledStatsForItem.
  /^local equipmentSwapPending = false/m,
  /^local cacheStats = \{[^\r\n]*\}/m,
  /^local ACTIVE_SCALES_TTL = \d+/m,
  /^local activeScalesCache, activeScalesAt = [^\r\n]*/m,
  /^function Valuate:InvalidateActiveScales\([\s\S]*?\r?\nend/m,
  /^function Valuate:GetActiveScales\([\s\S]*?\r?\nend/m,
  /^local targetSlotsCache = \{\}/m,
  /^local function TargetSlotsForItem\([\s\S]*?\r?\nend/m,
  // The shared reader. Its pcall and its rejection of an empty parse are why the arrows,
  // quest rewards and roll decision are correct; GetScaledStatsForItem goes through it
  // rather than hand-rolling both again.
  /^function Valuate:GetStatsForTooltipSetter\([\s\S]*?\r?\nend/m,
  /^function Valuate:GetScaledStatsForItem\([\s\S]*?\r?\nend/m,
  /^function Valuate:ExplainBestInSlot\([\s\S]*?\r?\nend/m,
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

Valuate = {}
function GetTime() return 0 end

local SCALES = {
    Dps  = { DisplayName = "Dps",  Visible = true, Values = { Strength = 1.0, CritRating = 0.5 } },
    Tank = { DisplayName = "Tank", Visible = true, Values = { Stamina = 1.0 } },
    Empty= { DisplayName = "Empty",Visible = true, Values = {} },
}
function Valuate:GetScales() return SCALES end

local BEST = { Dps = {}, Tank = {}, Empty = {} }
function Valuate:GetBestEquipment() return BEST end

-- The real scoring function is not sliced: this gate is about the VERDICTS, and a stub
-- keeps the arithmetic in the test where it can be read.
function Valuate:CalculateItemScore(stats, scale)
    local total = 0
    for stat, weight in pairs(scale.Values or {}) do
        total = total + (stats[stat] or 0) * weight
    end
    return total
end

function GetItemInfo(link)
    if link:find("nongear") then return "Bag", link, 1, 1, 1, "Container", "Bag", 1, "" end
    if link:find("ring") then return "Ring", link, 4, 80, 70, "Armor", "Miscellaneous", 1, "INVTYPE_FINGER" end
    return "Chest", link, 4, 80, 70, "Armor", "Plate", 1, "INVTYPE_CHEST"
end

local function link(id) return "|Hitem:" .. id .. ":0:0:0:0:0:0:0:80|h[Item]|h" end

-- ---- the world an item can be found in --------------------------------------
-- SCALED stats come from SetBagItem/SetInventoryItem; BASE stats from the link. The whole
-- point of GetScaledStatsForItem is telling those apart, so the mock must too.
local EQUIPPED, BAGS = {}, { [0] = {} }
local readSource = nil
local FAKE_TOOLTIP = { ClearLines = function() readSource = nil end }
function FAKE_TOOLTIP:SetInventoryItem(_, slotId) readSource = "equipped:" .. slotId end
function FAKE_TOOLTIP:SetBagItem(bagId, slotId) readSource = "bag:" .. bagId .. ":" .. slotId end
function GetPrivateTooltip() return FAKE_TOOLTIP end
function Valuate:GetPrivateTooltip() return FAKE_TOOLTIP end
-- A tooltip that has not populated yet parses to an EMPTY table, not to nil. Treating that
-- as a valid read would score a perfectly good item at zero.
local EMPTY_PARSE = {}
function Valuate:ParseStatsFromTooltip()
    if not readSource then return nil end
    if EMPTY_PARSE[readSource] then return {} end
    return { Strength = 500, __from = readSource }  -- scaled: deliberately different
end
function Valuate:GetStatsForItemLink() return { Strength = 10, __from = "link" } end

function GetInventoryItemLink(_, slotId) return EQUIPPED[slotId] end
function GetContainerNumSlots(bagId) return BAGS[bagId] and 16 or 0 end
function GetContainerItemLink(bagId, slotId) return BAGS[bagId] and BAGS[bagId][slotId] end

` + sliced.join("\n") + `

local INCUMBENT = link(1000)
local CANDIDATE = link(2000)

-- Chest is slot 5. The incumbent is recorded as best for both real scales.
BEST.Dps[5]  = { itemLink = INCUMBENT, score = 100 }
BEST.Tank[5] = { itemLink = INCUMBENT, score = 100 }
BEST.Empty[5]= { itemLink = INCUMBENT, score = 0 }

local function verdictFor(result, name)
    for _, e in ipairs(result or {}) do
        if e.scaleName == name then return e end
    end
    return nil
end

-- ---- beaten on points -------------------------------------------------------
local weak = Valuate:ExplainBestInSlot(CANDIDATE, { Strength = 10, Stamina = 10 })
ok(weak ~= nil, "an equippable item gets an explanation")
local d = verdictFor(weak, "Dps")
eq(d.verdict, "beaten", "scoring under the incumbent reads as beaten")
eq(d.score, 10, "its own score is reported")
eq(d.bestScore, 100, "so is the score it lost to")
eq(d.gap, 90, "and the gap is the difference, not a ratio or a percentage")
eq(d.bestLink, INCUMBENT, "the winner is named, so you can go and look at it")

-- ---- it IS the best ---------------------------------------------------------
local same = Valuate:ExplainBestInSlot(INCUMBENT, { Strength = 100 })
eq(verdictFor(same, "Dps").verdict, "best", "the recorded best item says so")

-- Matched by item ID, not by link: the recorded link carries the enchants and gems it
-- had when scanned, and comparing the strings would call your own gear an impostor.
local enchanted = "|cffa335ee|Hitem:1000:2343:41285:0:0:0:0:0:80|h[Item]|h|r"
eq(verdictFor(Valuate:ExplainBestInSlot(enchanted, { Strength = 100 }), "Dps").verdict, "best",
   "the same item with different enchants is still recognised as the best")

-- ---- would win, but the scan has not caught up ------------------------------
-- This is the verdict that must not be reported as "beaten": it is an item you should go
-- and equip, and calling it beaten is a confident lie.
local strong = Valuate:ExplainBestInSlot(CANDIDATE, { Strength = 500 })
local s = verdictFor(strong, "Dps")
eq(s.verdict, "unscanned", "outscoring the incumbent without being recorded is NOT 'beaten'")
eq(s.gap, 400, "and the gap says how far ahead it is")

-- ---- scores nothing ---------------------------------------------------------
local useless = Valuate:ExplainBestInSlot(CANDIDATE, { Spirit = 999 })
eq(verdictFor(useless, "Dps").verdict, "unscored",
   "an item whose stats the scale does not weight can never win, and says so")

-- ---- a scale with no weights at all -----------------------------------------
eq(verdictFor(weak, "Empty").verdict, "noweights",
   "a scale with no weights explains itself rather than reporting a 0-0 draw")

-- ---- every active scale is covered, and only active ones --------------------
eq(#weak, 3, "one entry per active scale")
SCALES.Tank.Visible = false
Valuate:InvalidateActiveScales()
eq(#Valuate:ExplainBestInSlot(CANDIDATE, { Strength = 10 }), 2, "a hidden scale is not explained")
SCALES.Tank.Visible = true
Valuate:InvalidateActiveScales()

-- ---- non-gear gets nil, not a fabricated verdict ----------------------------
ok(Valuate:ExplainBestInSlot("|Hitem:9:0:0:0:0:0:0:0:80|h[nongear]|h", { Strength = 10 }) == nil,
   "something that goes in no slot cannot be best AT anything")
ok(Valuate:ExplainBestInSlot(nil, { Strength = 1 }) == nil, "no link is handled, not crashed")
ok(Valuate:ExplainBestInSlot(CANDIDATE, nil) == nil, "no stats is handled, not crashed")

-- ---- SCALED vs BASE: the v0.94.0a bug --------------------------------------
-- v0.94.0a scored the item from its LINK (base stats) and compared that against best
-- equipment scores built from the bag/inventory tooltip (Ascension's scaled stats). Two
-- different numbers for one item, subtracted and reported to three significant figures.
-- On a scaling realm the gap was fiction, and "would win" could fire for an item that
-- would not.
local FOUND = link(4000)

EQUIPPED[5] = FOUND
local s1, scaled1 = Valuate:GetScaledStatsForItem(FOUND)
eq(s1.__from, "equipped:5", "an EQUIPPED item is read from its inventory slot, not its link")
eq(scaled1, true, "and is reported as scaled")
EQUIPPED[5] = nil

BAGS[0][7] = FOUND
local s2, scaled2 = Valuate:GetScaledStatsForItem(FOUND)
eq(s2.__from, "bag:0:7", "an item in your BAGS is read from the bag slot")
eq(scaled2, true, "and is reported as scaled")

-- Equipped wins when the item is in both places: that is the copy the best-equipment
-- table was built from.
EQUIPPED[5] = FOUND
eq(Valuate:GetScaledStatsForItem(FOUND).__from, "equipped:5",
   "equipped is preferred when the same item is in both")
EQUIPPED[5] = nil

-- A chat link for something you do not have: base stats are all there is, and the caller
-- MUST be told so rather than being handed numbers that look comparable.
BAGS[0][7] = nil
local s3, scaled3 = Valuate:GetScaledStatsForItem(FOUND)
eq(s3.__from, "link", "an item you do not have falls back to the link")
eq(scaled3, false, "and says the numbers are base values")

-- An item whose tooltip has not populated parses to an EMPTY table. Accepting that as a
-- scaled read would score a good item at zero and report "scores nothing" about it - a
-- confident wrong answer, which is the failure this whole diagnostic exists to avoid.
BAGS[0][9] = FOUND
EMPTY_PARSE["bag:0:9"] = true
local s4, scaled4 = Valuate:GetScaledStatsForItem(FOUND)
eq(scaled4, false, "a tooltip that parsed to nothing is not accepted as a scaled read")
eq(s4.__from, "link", "...it falls back to the link rather than scoring the item as zero")
EMPTY_PARSE["bag:0:9"] = nil
BAGS[0][9] = nil

-- The in-transit guard is READ, never relaxed. Touching SetBagItem mid-swap is what it
-- exists to prevent, so a pending swap must fall back rather than read.
BAGS[0][7] = FOUND
equipmentSwapPending = true
eq(select(2, Valuate:GetScaledStatsForItem(FOUND)), false,
   "a pending equipment swap falls back to base rather than touching the bag tooltip")
equipmentSwapPending = false
BAGS[0][7] = nil

-- ---- two slots: you displace the WEAKER one ---------------------------------
-- Rings and trinkets occupy either of two slots. Comparing against the stronger one would
-- report a good second ring as beaten while you are wearing junk in the other hand - the
-- same rule GetUpgradeBaseline uses, so both answers come from one rule rather than two.
local RING = "|Hitem:3000:0:0:0:0:0:0:0:80|h[ring]|h"
BEST.Dps[11] = { itemLink = "|Hitem:3001:0:0:0:0:0:0:0:80|h[ring]|h", score = 200 }
BEST.Dps[12] = { itemLink = "|Hitem:3002:0:0:0:0:0:0:0:80|h[ring]|h", score = 40 }
local r = verdictFor(Valuate:ExplainBestInSlot(RING, { Strength = 70 }), "Dps")
eq(r.bestScore, 40, "the incumbent is the WEAKER of the two rings - the one you'd replace")
eq(r.verdict, "unscanned", "so a ring worth 70 beats the 40 you are wearing, not the 200")

local worseRing = verdictFor(Valuate:ExplainBestInSlot(RING, { Strength = 30 }), "Dps")
eq(worseRing.verdict, "beaten", "and one worth less than the weaker ring is genuinely beaten")
eq(worseRing.gap, 10, "measured against the ring it would have replaced")

-- ---- an empty slot ----------------------------------------------------------
-- Wearing nothing means the incumbent scores 0, so anything positive would win. It must
-- read as 'unscanned' (go equip it), never as 'beaten' by an item that does not exist.
BEST.Dps[5] = nil
local intoEmpty = verdictFor(Valuate:ExplainBestInSlot(CANDIDATE, { Strength = 5 }), "Dps")
eq(intoEmpty.verdict, "unscanned", "an item for an empty slot is not 'beaten' by nothing")
ok(intoEmpty.bestLink == nil, "and no phantom winner is named")

return failures, checks
`,
  "whybis",
  "the best-in-slot explanation"
);
