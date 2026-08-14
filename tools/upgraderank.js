#!/usr/bin/env node
/*
 * @gate The "biggest upgrades" list is act-on-able and stably ordered
 *
 * Runs the real Valuate:RankAvailableUpgrades against a built best-equipment table.
 *
 * Two things here have bitten this project before and are both silent:
 *
 *   BANK DATA reaching a path that tells you to act. Equip All cannot reach the bank, so a
 *   banked item at the top of "what should I do next" is advice you cannot take - and the
 *   deletion protections exist because bank data reaching the wrong loop is how gear gets
 *   destroyed. Excluding it is not a nicety.
 *
 *   AN UNSTABLE SORT. Ties are ordinary here: rings and trinkets tie constantly. pairs()
 *   order is undefined and table.sort is not stable, so without a unique second key the
 *   same list reorders itself between runs and "your biggest upgrade" changes identity
 *   while nothing about your gear did.
 *
 * Usage:  node tools/upgraderank.js
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
  /^function Valuate:RankAvailableUpgrades\([\s\S]*?\r?\nend/m,
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

ns = {}
` + slots[0] + `

Valuate = {}
local SCALES = { Dps = { DisplayName = "Dps", Visible = true, Values = { Strength = 1.0 } } }
function Valuate:GetScales() return SCALES end

local BEST = { Dps = {} }
function Valuate:GetBestEquipment() return BEST end

local EQUIPPED, EQUIPPED_SCORE = {}, {}
function GetInventoryItemLink(_, slotId) return EQUIPPED[slotId] end
function Valuate:GetEquippedItemScoreBySlotId(slotId) return EQUIPPED_SCORE[slotId] or 0 end

local function link(id) return "|Hitem:" .. id .. ":0:0:0:0:0:0:0:80|h[Item " .. id .. "]|h" end

` + sliced.join("\n") + `

local function names(list)
    local out = {}
    for _, u in ipairs(list or {}) do out[#out + 1] = u.slotName end
    return table.concat(out, ",")
end

-- ---- ranked by gain, biggest first -----------------------------------------
BEST.Dps[1]  = { itemLink = link(101), score = 110 }   -- Head:  +10
BEST.Dps[5]  = { itemLink = link(105), score = 150 }   -- Chest: +50
BEST.Dps[7]  = { itemLink = link(107), score = 120 }   -- Legs:  +20
EQUIPPED[1], EQUIPPED_SCORE[1] = link(1), 100
EQUIPPED[5], EQUIPPED_SCORE[5] = link(5), 100
EQUIPPED[7], EQUIPPED_SCORE[7] = link(7), 100

local ranked = Valuate:RankAvailableUpgrades("Dps")
ok(ranked ~= nil, "upgrades are found")
eq(names(ranked), "Chest,Legs,Head", "ranked by gain, biggest first")
eq(ranked[1].gain, 50, "the gain is best minus what you are wearing")

-- ---- BANK gear is excluded ---------------------------------------------------
-- Equip All cannot reach it, so it is not something you can act on now.
BEST.Dps[5].source = "bank"
local noBank = Valuate:RankAvailableUpgrades("Dps")
eq(names(noBank), "Legs,Head", "a banked best-in-slot is never offered as your next upgrade")
BEST.Dps[5].source = nil

-- ---- gear you are already wearing is not an upgrade to itself ----------------
--
-- The live score is deliberately LOWER than the recorded one (118 vs 120). Ascension scales
-- items, so a score recomputed now can drift from the one the scan stored - and then the
-- gain is positive and the list says "+2.0, equip the chestpiece you are already wearing".
-- Giving both sides the same number here would let the "gain > 0" filter mask the identity
-- check entirely, which is how a mutation removing that check survived the first run.
EQUIPPED[7], EQUIPPED_SCORE[7] = link(107), 118
eq(names(Valuate:RankAvailableUpgrades("Dps")), "Chest,Head",
   "the slot whose best you already wear drops out, even if its score has drifted")

-- Matched by item ID, so the enchanted copy on your body is still recognised.
EQUIPPED[7] = "|cffa335ee|Hitem:107:2343:41285:0:0:0:0:0:80|h[Item 107]|h|r"
eq(names(Valuate:RankAvailableUpgrades("Dps")), "Chest,Head",
   "...even when your copy carries enchants the scanned link did not")
EQUIPPED[7], EQUIPPED_SCORE[7] = link(7), 100

-- ---- a zero or negative gain is not an upgrade -------------------------------
BEST.Dps[1].score = 100      -- exactly what you are wearing
eq(names(Valuate:RankAvailableUpgrades("Dps")), "Chest,Legs", "a tie is not an upgrade")
BEST.Dps[1].score = 90       -- worse than what you are wearing
eq(names(Valuate:RankAvailableUpgrades("Dps")), "Chest,Legs", "nor is a downgrade")
BEST.Dps[1].score = 110

-- ---- an empty slot is flagged, not just ranked -------------------------------
-- The gain is the item's whole score, so it always ranks high; the reason is "you are
-- wearing nothing", not "this item is remarkable", and the list has to say which.
EQUIPPED[2], EQUIPPED_SCORE[2] = nil, 0
BEST.Dps[2] = { itemLink = link(102), score = 40 }
local withEmpty = Valuate:RankAvailableUpgrades("Dps")
local neck
for _, u in ipairs(withEmpty) do if u.slotName == "Neck" then neck = u end end
ok(neck ~= nil and neck.emptySlot == true, "a slot you are wearing nothing in is marked empty")
ok(ranked[1].emptySlot == false or ranked[1].emptySlot == nil,
   "a slot you have something in is not")
BEST.Dps[2] = nil

-- ---- ties break on slot id, every time ---------------------------------------
-- Rings and trinkets tie constantly. table.sort is not stable, so a tie without a unique
-- second key gives a different "biggest upgrade" on consecutive runs of the same data.
-- Back (slot 15) and Chest (slot 5). ns.EQUIP_SLOTS reads like a character sheet, so Back
-- is VISITED FIRST while Chest sorts first - the only pair that separates "sorted by slot"
-- from "left in the order we happened to find them". Ring 1 and Ring 2, which the first
-- draft used, are already in slot order either way and proved nothing.
BEST.Dps[15] = { itemLink = link(115), score = 130 }
BEST.Dps[5]  = { itemLink = link(105), score = 130 }
EQUIPPED[15], EQUIPPED_SCORE[15] = link(15), 100
EQUIPPED[5],  EQUIPPED_SCORE[5]  = link(5), 100
BEST.Dps[1], BEST.Dps[7] = nil, nil
local first = names(Valuate:RankAvailableUpgrades("Dps"))
for _ = 1, 20 do
    eq(names(Valuate:RankAvailableUpgrades("Dps")), first, "the same data ranks the same way every time")
end
eq(first, "Chest,Back", "tied slots come out in SLOT order, not the order they were found")

-- ---- refusals ----------------------------------------------------------------
ok(Valuate:RankAvailableUpgrades("NoSuchScale") == nil, "an unknown scale is nil, not a crash")
SCALES.Empty = { DisplayName = "Empty", Visible = true }
ok(Valuate:RankAvailableUpgrades("Empty") == nil, "a scale with no weights has nothing to rank")

BEST.Dps = {}
ok(Valuate:RankAvailableUpgrades("Dps") == nil,
   "nothing better anywhere returns nil, so the caller can say so plainly")

return failures, checks
`,
  "upgraderank",
  "the ranked upgrade list"
);
