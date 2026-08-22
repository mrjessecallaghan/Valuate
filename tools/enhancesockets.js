#!/usr/bin/env node
/*
 * @gate An unread socket is not reported as a filled one
 *
 * Runs the real ns.SocketsBySlot from ui/Enhance.lua.
 *
 * The Enhance tab was asked to show "which item enhancement each slot should be getting right
 * now" and answered only about enchants. An empty socket is exactly that question, and the
 * addon already knew the answer per slot - the tab simply never asked. This is the layer that
 * turns Valuate:FindEmptySockets into something a row can read.
 *
 * What is actually at risk here is not the mapping. It is one distinction:
 *
 *     nil, 0   "you have no empty sockets"
 *     nil, 0   "I was not able to look"
 *
 * Those were the same two values. For the to-do list that never mattered - the entry is absent
 * either way, and an absent line claims nothing. For a panel drawing one row per slot it
 * matters a great deal, because silence on a row reads as that slot being FINE. Mid equipment
 * swap that is the wrong answer, delivered in the most reassuring possible way. It is the junk
 * bug's shape exactly: two causes collapsing into one result, and the result being the
 * comfortable one.
 *
 * So every assertion below is paired. A reason must appear when nothing could be read, and
 * must NOT appear when the honest answer is zero - a gate that only checked the first half
 * would pass an implementation that blamed a swap on every fully-gemmed character.
 *
 * Usage:  node tools/enhancesockets.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const NL = String.fromCharCode(10);
const src = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Enhance.lua"), "utf8");

const start = src.indexOf("function ns.SocketsBySlot(");
if (start < 0) {
  console.error(
    "  SLICE  could not find function ns.SocketsBySlot in ui/Enhance.lua - it was renamed or " +
      "inlined into the panel, so this gate is testing nothing"
  );
  process.exit(1);
}
const end = src.indexOf(NL + "end" + NL, start);
if (end < 0) {
  console.error("  SLICE  ns.SocketsBySlot has no closing end - this gate is testing nothing");
  process.exit(1);
}
const fn = src.slice(start, end + 5);

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
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local ns = {}
Valuate = {}

-- Stands in for Valuate:FindEmptySockets. Set REPLY to whatever the real one would return.
local REPLY = {}
function Valuate:FindEmptySockets()
    return REPLY[1], REPLY[2], REPLY[3]
end

` + fn + `

-- ---- the ordinary case -------------------------------------------------------------------
REPLY = { {
    { slotId = 5,  slotName = "Chest", itemLink = "chest", sockets = 3 },
    { slotId = 15, slotName = "Back",  itemLink = "back",  sockets = 1 },
}, 4, nil }
local map, total, blocked = ns.SocketsBySlot()
eq(total, 4, "the total comes straight through")
eq(blocked, nil, "and nothing is blamed when the read worked")
eq(map[5], 3, "the chest's sockets are keyed by ITS slot")
eq(map[15], 1, "and the back's by its own")
eq(map[1], nil, "a slot with no entry is absent rather than zero")
eq(count(map), 2, "and nothing else is invented")

-- ---- THE ONE THAT MATTERS: could not look --------------------------------------------------
-- Same first two values as a genuine zero. If the reason is dropped here, every row falls
-- silent and every silent row reads as a finished slot.
REPLY = { nil, 0, "an item is still being swapped" }
map, total, blocked = ns.SocketsBySlot()
ok(blocked ~= nil, "when nothing could be read, the caller is TOLD so")
ok(type(blocked) == "string" and blocked:find("swap", 1, true) ~= nil,
   "and told why, in words a panel can print without inventing any")
eq(total, 0, "the total is zero rather than stale")
eq(count(map), 0, "and no slot carries a leftover count from the previous read")

-- ---- the pair: a real zero blames nobody ----------------------------------------------------
-- Without this, an implementation that reported "could not read" on every fully-gemmed
-- character would pass - and it would be wrong in the direction that nags people who are done.
REPLY = { nil, 0, nil }
map, total, blocked = ns.SocketsBySlot()
eq(blocked, nil, "a genuine zero is an ANSWER, not a failure to look")
eq(total, 0, "with a zero total")
eq(count(map), 0, "and an empty map")

-- ---- the reader is not loaded at all --------------------------------------------------------
-- Same rule one level up. Absent is not empty.
local saved = Valuate.FindEmptySockets
Valuate.FindEmptySockets = nil
map, total, blocked = ns.SocketsBySlot()
ok(blocked ~= nil, "with no socket reader present it says so instead of answering zero")
eq(count(map), 0, "and offers no counts")
Valuate.FindEmptySockets = saved

-- ---- malformed entries do not take the panel down -------------------------------------------
-- map[nil] is a runtime error in Lua, and this runs while the window is being drawn. An entry
-- without a slot is unusable, but losing the whole tab over one is a far worse trade.
REPLY = { {
    { slotName = "no slot id at all", sockets = 2 },
    { slotId = 7, sockets = nil },
    { slotId = 10, sockets = 2 },
}, 4, nil }
local fine, err = pcall(function() return ns.SocketsBySlot() end)
ok(fine, "an entry with no slotId does not error the refresh (" .. tostring(err) .. ")")
map = ns.SocketsBySlot()
eq(map[10], 2, "the usable entries still land")
eq(map[7], 0, "a missing count reads as zero rather than nil, so the row simply says nothing")
eq(count(map), 2, "and the unusable one is dropped rather than guessed at")

return failures, checks
`,
  "enhancesockets",
  "sockets keyed by slot"
);
