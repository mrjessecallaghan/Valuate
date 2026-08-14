#!/usr/bin/env node
/*
 * @gate Empty sockets are counted, and filled ones are not
 *
 * Runs the real Valuate:FindEmptySockets against mocked tooltips.
 *
 * The whole feature is one distinction: an EMPTY socket draws a line that begins with the
 * socket's name, and a FILLED one draws the gem's own text instead. Get that wrong in
 * either direction and the answer is quietly useless -
 *
 *   over-counting  every gemmed item reports sockets you have already filled, so the
 *                  number never reaches zero and you stop believing it
 *   under-counting  the reminder never fires and the feature may as well not exist
 *
 * The dangerous case is a gem whose NAME contains a socket colour - "Runed Scarlet Ruby"
 * sits in a red socket - which is why matching is anchored at the start of the line rather
 * than searched anywhere in it.
 *
 * Usage:  node tools/sockets.js
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
  /^local equipmentSwapPending = false/m,
  /^local function EmptySocketStrings\([\s\S]*?\r?\nend/m,
  /^local function CountEmptySockets\([\s\S]*?\r?\nend/m,
  /^function Valuate:FindEmptySockets\([\s\S]*?\r?\nend/m,
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

-- The client's own strings. Present here, so the fallbacks are NOT what is being tested -
-- a gate that only ever exercised the English defaults would pass on a build where the
-- globals exist and say something else.
EMPTY_SOCKET_RED = "Red Socket"
EMPTY_SOCKET_YELLOW = "Yellow Socket"
EMPTY_SOCKET_BLUE = "Blue Socket"
EMPTY_SOCKET_META = "Meta Socket"
EMPTY_SOCKET_PRISMATIC = "Prismatic Socket"

local TOOLTIP_LINES = {}
local currentSlot = nil
local TIP = {}
function TIP:ClearLines() end
function TIP:SetInventoryItem(_, slotId) currentSlot = slotId end
-- Faithful indexing: TextLeft<i> IS line i, and line 1 is the item NAME. The real loop
-- starts at 2 to skip it, so an off-by-one here would silently test a different tooltip
-- than the client draws. Every fixture below therefore starts with a name line.
function TIP:NumLines()
    local l = TOOLTIP_LINES[currentSlot]
    return l and #l or 0
end
ValuatePrivateTooltip = TIP
function Valuate:GetPrivateTooltip() return TIP end
function getglobal(name)
    local i = tonumber(name:match("TextLeft(%d+)$"))
    local l = TOOLTIP_LINES[currentSlot]
    if not i or not l or not l[i] then return nil end
    return { GetText = function() return l[i] end }
end

local EQUIPPED = {}
function GetInventoryItemLink(_, slotId) return EQUIPPED[slotId] end

` + sliced.join("\n") + `

local function summary(list)
    local out = {}
    for _, e in ipairs(list or {}) do out[#out + 1] = e.slotName .. ":" .. e.sockets end
    return table.concat(out, ",")
end

-- ---- nothing socketed --------------------------------------------------------
EQUIPPED[1] = "head"
TOOLTIP_LINES[1] = { "Head of Testing", "+40 Strength" }
local none, total = Valuate:FindEmptySockets()
ok(none == nil, "gear with no sockets reports nothing")
eq(total, 0, "and a total of zero")

-- ---- empty sockets are counted ----------------------------------------------
TOOLTIP_LINES[1] = { "Head of Testing", "Meta Socket", "Red Socket", "+40 Strength" }
local list, n = Valuate:FindEmptySockets()
eq(summary(list), "Head:2", "two empty sockets on one item are counted")
eq(n, 2, "and totalled")

-- ---- a FILLED socket shows the GEM, not the socket name ---------------------
-- This is the whole feature. A filled socket draws the gem's own text, so counting it
-- would mean the number never reaches zero and you stop believing it.
TOOLTIP_LINES[1] = { "Head of Testing", "+12 Critical Strike Rating", "Red Socket" }
eq(select(2, Valuate:FindEmptySockets()), 1, "a filled socket is not counted, only the empty one")

-- The dangerous one: a gem NAMED after a socket colour. "Runed Scarlet Ruby" sits in a red
-- socket and its tooltip line mentions neither - but plenty of gem lines do contain colour
-- words, and a search-anywhere match would count the socket it just filled.
TOOLTIP_LINES[1] = { "Head of Testing", "Socketed with a Red Socket Gem of Power" }
eq(select(2, Valuate:FindEmptySockets()), 0,
   "a line MENTIONING a socket colour mid-sentence is not an empty socket")

TOOLTIP_LINES[1] = { "Head of Testing", "Red Socket" }
eq(select(2, Valuate:FindEmptySockets()), 1, "...while a line that STARTS with it is")

-- ---- every socket colour, and the item name line is skipped -----------------
TOOLTIP_LINES[1] = { "Head of Testing",
    "Red Socket", "Yellow Socket", "Blue Socket", "Meta Socket", "Prismatic Socket" }
eq(select(2, Valuate:FindEmptySockets()), 5, "all five socket colours are recognised")

-- The name line is never read. An item literally called "Red Socket" would otherwise count
-- itself, which is absurd but free to rule out.
TOOLTIP_LINES[1] = { "Red Socket", "+40 Strength" }
eq(select(2, Valuate:FindEmptySockets()), 0, "the item's NAME line is skipped, whatever it says")

-- ---- ranked, and stably ------------------------------------------------------
EQUIPPED[5], EQUIPPED[7] = "chest", "legs"
TOOLTIP_LINES[1] = { "Head", "Red Socket" }
TOOLTIP_LINES[5] = { "Chest", "Red Socket", "Blue Socket", "Meta Socket" }
TOOLTIP_LINES[7] = { "Legs", "Red Socket" }
local ranked = Valuate:FindEmptySockets()
eq(ranked[1].slotName, "Chest", "the item with most empty sockets comes first")
local first = summary(ranked)
for _ = 1, 20 do
    eq(summary(Valuate:FindEmptySockets()), first, "and the same gear ranks the same way every time")
end

-- Ties must break on SLOT ID, and proving that needs two tied items where iteration order
-- and slot order DISAGREE. ns.EQUIP_SLOTS reads like a character sheet, so Back (slot 15)
-- is visited before Chest (slot 5) - the only pair in the list that separates "sorted" from
-- "left in the order we happened to find them". Head and Legs, which the first draft used,
-- are already in slot order either way and prove nothing.
EQUIPPED[1], EQUIPPED[7] = nil, nil
EQUIPPED[15], EQUIPPED[5] = "back", "chest"
TOOLTIP_LINES[15] = { "Back", "Red Socket" }
TOOLTIP_LINES[5] = { "Chest", "Blue Socket" }
local tied = summary(Valuate:FindEmptySockets())
eq(tied, "Chest:1,Back:1",
   "tied items come out in SLOT order (Chest 5 before Back 15), not the order they were found")

-- ---- an empty slot contributes nothing --------------------------------------
-- Back and Chest are the two socketed items at this point, one socket each.
EQUIPPED[5] = nil
eq(select(2, Valuate:FindEmptySockets()), 1, "a slot you are wearing nothing in is skipped")
EQUIPPED[5] = "chest"

-- ---- the in-transit guard is read, never relaxed -----------------------------
equipmentSwapPending = true
ok(Valuate:FindEmptySockets() == nil, "mid equipment swap it reports nothing rather than reading")
eq(select(2, Valuate:FindEmptySockets()), 0, "and totals zero rather than a stale count")
equipmentSwapPending = false

return failures, checks
`,
  "sockets",
  "empty socket counting"
);
