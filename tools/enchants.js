#!/usr/bin/env node
/*
 * @gate Unenchanted gear is spotted, and "cannot read it" is not called "unenchanted"
 *
 * Runs the real Valuate:FindMissingEnchants against mocked equipment.
 *
 * An item link is |Hitem:ID:ENCHANT:gem:gem:gem:gem:suffix:unique:level|h, so the whole
 * feature is reading field TWO and knowing what zero means. Three ways to get that wrong,
 * all of which produce a list that looks perfectly reasonable:
 *
 *   reading field ONE     the item ID is never 0, so nothing is ever reported and the
 *                         command silently always says "all good"
 *   nil treated as zero   an unreadable link sends you to an enchanter for nothing
 *   wrong slot set        nagging about rings, which need Enchanting, or about a slot the
 *                         character cannot enchant at all - which is how a useful list
 *                         becomes one you stop reading
 *
 * Usage:  node tools/enchants.js
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
  /^local ENCHANTABLE_SLOTS = \{[\s\S]*?\r?\n\}/m,
  /^local function LinkEnchantId\([\s\S]*?\r?\nend/m,
  /^function Valuate:FindMissingEnchants\([\s\S]*?\r?\nend/m,
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
local EQUIPPED = {}
function GetInventoryItemLink(_, slotId) return EQUIPPED[slotId] end

-- A real link, with the enchant in field two. The item ID is deliberately NOT zero and NOT
-- the same as the enchant, so reading the wrong field is visible rather than a coincidence.
local function link(enchantId)
    return "|cffa335ee|Hitem:40592:" .. enchantId .. ":0:0:0:0:0:0:80|h[Item]|h|r"
end

` + sliced.join("\n") + `

local function names(list)
    local out = {}
    for _, e in ipairs(list or {}) do out[#out + 1] = e.slotName end
    return table.concat(out, ",")
end

-- ---- the basic reading -------------------------------------------------------
eq(LinkEnchantId(link(3818)), 3818, "the enchant is read from field two")
eq(LinkEnchantId(link(0)), 0, "an unenchanted item reads zero")
eq(LinkEnchantId("not a link"), nil, "a string that is not a link reads nil, not zero")
eq(LinkEnchantId(nil), nil, "nil is handled rather than crashing")

-- Field ONE is the item id, which is never zero - reading it would mean nothing is ever
-- reported and the command silently always says everything is fine.
ok(LinkEnchantId(link(0)) ~= 40592, "field two is read, not the item id")

-- ---- enchanted vs not --------------------------------------------------------
EQUIPPED[5] = link(3832)
eq(Valuate:FindMissingEnchants(), nil, "an enchanted chest reports nothing")

EQUIPPED[5] = link(0)
eq(names(Valuate:FindMissingEnchants()), "Chest", "an unenchanted chest is reported")
eq(select(2, Valuate:FindMissingEnchants()), 1, "and counted")

-- ---- an unreadable link is NOT 'unenchanted' ---------------------------------
-- The two look identical in a list and lead to completely different actions: one is a trip
-- to an enchanter, the other is a bug in the addon.
EQUIPPED[5] = "some string that is not an item link"
eq(Valuate:FindMissingEnchants(), nil, "a link that cannot be read is not called unenchanted")
EQUIPPED[5] = link(0)

-- ---- only slots that plainly take an enchant ---------------------------------
-- Rings need Enchanting; nagging every character about them is how a list stops being read.
EQUIPPED[11], EQUIPPED[12] = link(0), link(0)
eq(names(Valuate:FindMissingEnchants()), "Chest", "rings are not reported - they need Enchanting")

EQUIPPED[2] = link(0)   -- Neck takes no enchant at all
eq(names(Valuate:FindMissingEnchants()), "Chest", "a slot that takes no enchant is never listed")

EQUIPPED[13], EQUIPPED[17], EQUIPPED[18] = link(0), link(0), link(0)
eq(names(Valuate:FindMissingEnchants()), "Chest",
   "nor trinkets, off-hand or ranged - conditional slots are left out on purpose")

-- ---- the slots that ARE checked, in character-sheet order --------------------
EQUIPPED = {}
for _, slotId in ipairs({ 1, 3, 15, 5, 9, 10, 7, 8, 16 }) do EQUIPPED[slotId] = link(0) end
local all = Valuate:FindMissingEnchants()
eq(select(2, Valuate:FindMissingEnchants()), 9, "all nine enchantable slots are checked")
-- Character-sheet order, so Back (15) comes before Chest (5) - the same ordering that made
-- two tiebreak tests meaningless in v0.103.0a until they used exactly this pair.
eq(names(all), "Head,Shoulder,Back,Chest,Wrist,Hands,Legs,Feet,Main Hand",
   "and listed in character-sheet order, not slot-id order")

-- Waist (6) is NOT enchantable and must not have crept in above.
EQUIPPED[6] = link(0)
eq(select(2, Valuate:FindMissingEnchants()), 9, "waist is not enchantable and is not counted")

-- ---- an empty slot contributes nothing ---------------------------------------
EQUIPPED = { [5] = link(0) }
eq(select(2, Valuate:FindMissingEnchants()), 1, "slots you are wearing nothing in are skipped")

return failures, checks
`,
  "enchants",
  "missing enchant detection"
);
