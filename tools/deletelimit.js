#!/usr/bin/env node
/*
 * @gate Auto-delete removes only as much as the setting asks for, and preview predicts it
 *
 * Runs the REAL Valuate:AutoDeleteJunk against a mocked bag.
 *
 * tools/deletetest.js proves the PROTECTIONS - which items may never be touched. This proves
 * the other half, which had no gate at all: how many are destroyed, in what order, and whether
 * the preview tells the truth about it. Deletion is the only irreversible thing this addon
 * does; WoW has no undo and no buyback for a deleted item.
 *
 * Four properties, each of which has a bad day attached:
 *
 *   * IT STOPS AT THE TARGET. `needed = keepFree - free`, so being two slots short deletes two
 *     items, not the whole junk pile. "Delete now" means "run the normal cleanup immediately",
 *     not "empty my bags" - and the on-demand path must obey the same bound, which is the one
 *     place a reasonable person might have made an exception.
 *   * PREVIEW PREDICTS IT EXACTLY. The queue is sorted cheapest-first with bag and slot
 *     breaking ties, because table.sort is not stable and equal vendor prices are the norm
 *     among junk. Without a total order the preview can rank a different item than the delete
 *     removes, which makes the preview worse than nothing.
 *   * IT RE-CHECKS THE SLOT. Bags shift between the scan and the delete - another addon, a
 *     stack merging - so a slot whose contents changed, or which is mid-move, is skipped.
 *   * IT NEVER ANSWERS THE CONFIRMATION POPUP. That dialog exists to prevent exactly this kind
 *     of accident. If one intercepts the delete the item is still on the cursor, and the right
 *     response is to put it back and say so.
 *
 * Usage:  node tools/deletelimit.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^function Valuate:AutoDeleteJunk\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find Valuate:AutoDeleteJunk in Valuate.lua - it was renamed or " +
      "reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

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

-- ---- the helpers this function leans on ------------------------------------------------------
-- Stubbed rather than sliced. Each has its own gate - the protections in deletetest.js, the junk
-- classification in the AdiBags integration - and re-testing them here would be a second
-- opinion rather than a new one. What is untested is the arithmetic BETWEEN them.
equipmentSwapPending, recentEquipmentChange = false, false
autoDeleteSessionCount = 0

FREE = 0
function CountFreeBagSlots() return FREE end

PROTECTED = {}
function IsProtectedFromDelete(bag, slot, link)
    if PROTECTED[link] then return true, "protected for the test" end
    return false
end

function ResolveAdiBagsJunk() return nil, nil end
JUNK = {}
function IsItemJunk(_, _, itemId) return JUNK[itemId] ~= false end
function GetItemIdFromLink(link) return tonumber(link:match("item:(%d+)")) end

-- ---- the bag: TWO of them ----------------------------------------------------------------------
-- Two, because the sort breaks ties on bag and then slot. With everything in bag 0 the bag
-- comparison never decides anything, the slot one did all the work, and the mutation that
-- deletes the bag tie-break survived - the fixture was tidier than any real character's bags.
BAGS = { [0] = {}, [1] = {} }
LOCKED = {}
READS = {}

GetContainerNumSlots = function(bag) return BAGS[bag] and #BAGS[bag] or 0 end

-- Counts reads per slot, so the test can model a bag that SHIFTS between the scan and the
-- delete. The scan reads every slot once in order; the delete loop reads a candidate again just
-- before destroying it. Swapping on the second read is exactly the race being guarded against.
SWAP_AFTER_SCAN = nil
GetContainerItemLink = function(bag, slot)
    local e = BAGS[bag] and BAGS[bag][slot]
    if not e then return nil end
    local key = bag .. ":" .. slot
    READS[key] = (READS[key] or 0) + 1
    if SWAP_AFTER_SCAN == key and READS[key] > 1 then
        return "|Hitem:999:0|h[Something Else]|h"
    end
    return e.link
end
GetContainerItemInfo = function(bag, slot)
    local e = BAGS[bag] and BAGS[bag][slot]
    if not e then return nil end
    return nil, e.count or 1, LOCKED[bag .. ":" .. slot] or false
end
GetItemInfo = function(link) return "Item", nil, 0 end
GetCoinTextureString = function(v) return tostring(v) .. "c" end

Valuate.GetItemUnitValue = function(_, link)
    for b = 0, 1 do
        for _, e in ipairs(BAGS[b]) do if e.link == link then return e.value or 1, "vendor" end end
    end
    return 1, "vendor"
end
HEARTBEAT = nil
Valuate.MarkAutomation = function(_, _, detail) HEARTBEAT = detail end

-- ---- the cursor, and what actually got destroyed -------------------------------------------------
DELETED = {}
CURSOR = nil
CONFIRM_LINK = nil   -- a link whose delete is intercepted by a confirmation popup
PickupContainerItem = function(bag, slot)
    local e = BAGS[bag] and BAGS[bag][slot]
    CURSOR = e and e.link or nil
end
CursorHasItem = function() return CURSOR ~= nil end
ClearCursor = function() CURSOR = nil end
DeleteCursorItem = function()
    -- A confirmation dialog leaves the item ON the cursor. The addon must never answer it.
    if CURSOR == CONFIRM_LINK then return end
    DELETED[#DELETED + 1] = CURSOR
    CURSOR = nil
end

OPTIONS = {}
Valuate.GetOptions = function() return OPTIONS end

local function junkItem(id, value)
    return { link = "|Hitem:" .. id .. ":0|h[Junk " .. id .. "]|h", value = value or 10, count = 1 }
end
local function bagsOf(zero, one)
    BAGS = { [0] = zero or {}, [1] = one or {} }
    LOCKED, DELETED, CURSOR, READS = {}, {}, nil, {}
    SWAP_AFTER_SCAN, HEARTBEAT = nil, nil
    __printed = {}
end

` + m[0] + `

-- ---- IT STOPS AT THE TARGET --------------------------------------------------------------------
-- The bound on an irreversible action. Three slots short of the target deletes three items, not
-- the whole pile - and there are eight here so that "it deleted everything" and "it deleted the
-- right number" cannot be the same answer.
OPTIONS = { autoDeleteJunk = true, autoDeleteKeepFree = 4, autoDeleteMaxQuality = 2 }
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30), junkItem(4, 40),
         junkItem(5, 50), junkItem(6, 60), junkItem(7, 70), junkItem(8, 80) })
FREE = 1
Valuate:AutoDeleteJunk()
eq(#DELETED, 3, "three slots short of the target deletes exactly three")

FREE = 3
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30), junkItem(4, 40) })
Valuate:AutoDeleteJunk()
eq(#DELETED, 1, "one slot short deletes exactly one")

-- At the target it does nothing - and SAYS it did nothing, which is the observable difference.
-- Without that second assertion, deleting the free-slot gate entirely still removes zero items
-- (needed comes out at zero anyway), so "nothing was deleted" proved nothing about the gate.
FREE = 4
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
Valuate:AutoDeleteJunk()
eq(#DELETED, 0, "at the target it deletes nothing, whatever else is in the bag")
ok(HEARTBEAT ~= nil and HEARTBEAT:find("no action", 1, true) ~= nil,
   "and records that it ran and correctly did nothing, rather than scanning the bag first")
ok(HEARTBEAT:find("4 free", 1, true) ~= nil, "naming the numbers it decided on")

FREE = 9
bagsOf({ junkItem(1, 10), junkItem(2, 20) })
Valuate:AutoDeleteJunk({ force = true })
eq(#DELETED, 0, "on-demand with plenty of room deletes nothing")
local said = table.concat(__printed, "\\n")
ok(said:find("Nothing to do", 1, true) ~= nil, "and says why rather than failing silently")

-- ---- ON-DEMAND OBEYS THE SAME BOUND --------------------------------------------------------------
-- "/valuate deletenow" means "run the normal cleanup immediately", NOT "delete all my junk".
-- This is the one place a reasonable person might have made an exception, and the worst place
-- to make one.
FREE = 1
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30), junkItem(4, 40),
         junkItem(5, 50), junkItem(6, 60) })
Valuate:AutoDeleteJunk({ force = true })
eq(#DELETED, 3, "on-demand still stops at the free-slot target")

OPTIONS.autoDeleteJunk = false
FREE = 2
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
Valuate:AutoDeleteJunk({ force = true })
eq(#DELETED, 2, "on-demand runs even with the automation switched off")

bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
Valuate:AutoDeleteJunk()
eq(#DELETED, 0, "with the automation off and no force, nothing happens")
OPTIONS.autoDeleteJunk = true

-- ---- PREVIEW DESTROYS NOTHING ---------------------------------------------------------------------
FREE = 0
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
Valuate:AutoDeleteJunk({ preview = true })
eq(#DELETED, 0, "a preview deletes nothing at all")

FREE = 20
bagsOf({ junkItem(1, 10), junkItem(2, 20) })
Valuate:AutoDeleteJunk({ preview = true })
eq(#DELETED, 0, "still nothing, and it ran rather than bailing on the free-slot gate")
ok(table.concat(__printed, "\\n"):find("Delete preview", 1, true) ~= nil,
   "a preview runs even when the bags are fine, because inspecting rules is not an action")

FREE = 0
OPTIONS.autoDeleteDryRun = true
bagsOf({ junkItem(1, 10), junkItem(2, 20) })
Valuate:AutoDeleteJunk()
eq(#DELETED, 0, "dry-run mode deletes nothing either")
OPTIONS.autoDeleteDryRun = nil

-- ---- CHEAPEST FIRST, WITH A TOTAL ORDER ACROSS BAGS ------------------------------------------------
-- table.sort is not stable and equal vendor prices are the norm among junk - whole stacks, many
-- greys sharing a price. Without bag AND slot breaking the tie, deletepreview can rank a
-- different item than deletenow removes, and deletion is irreversible.
--
-- The three cheapest are deliberately all worth 5 and spread ACROSS bags, so bag order is the
-- thing being tested rather than slot order standing in for it.
FREE = 1
bagsOf({ junkItem(1, 90), junkItem(2, 5) }, { junkItem(3, 5), junkItem(4, 5), junkItem(5, 50) })
Valuate:AutoDeleteJunk()
eq(#DELETED, 3, "three deleted")
eq(DELETED[1], BAGS[0][2].link, "the tied item in the LOWER BAG goes first")
eq(DELETED[2], BAGS[1][1].link, "then the lower slot of the higher bag")
eq(DELETED[3], BAGS[1][2].link, "then its neighbour, in slot order")
ok(DELETED[1] ~= BAGS[0][1].link and DELETED[2] ~= BAGS[0][1].link
   and DELETED[3] ~= BAGS[0][1].link, "and the most valuable junk survives longest")

local firstRun = { DELETED[1], DELETED[2], DELETED[3] }
FREE = 1
bagsOf({ junkItem(1, 90), junkItem(2, 5) }, { junkItem(3, 5), junkItem(4, 5), junkItem(5, 50) })
Valuate:AutoDeleteJunk()
eq(DELETED[1], firstRun[1], "the same bags delete the same items in the same order")
eq(DELETED[2], firstRun[2], "second")
eq(DELETED[3], firstRun[3], "third")

-- ---- THE IN-TRANSIT GUARD ---------------------------------------------------------------------------
FREE = 0
bagsOf({ junkItem(1, 10), junkItem(2, 20) })
equipmentSwapPending = true
Valuate:AutoDeleteJunk()
eq(#DELETED, 0, "nothing is deleted while gear is still moving")
equipmentSwapPending = false

bagsOf({ junkItem(1, 10), junkItem(2, 20) })
recentEquipmentChange = true
Valuate:AutoDeleteJunk()
eq(#DELETED, 0, "nor just after an equipment change")
recentEquipmentChange = false

-- ---- A LOCKED SLOT IS LEFT ALONE, AND THE PREVIEW SAYS SO -------------------------------------------
-- Mid-move, mid-split, or waiting on the server. Transient, so the next run picks it up.
--
-- Asserted through the PREVIEW, which is the only place the scan-time check is observable: in a
-- real delete the re-verify below catches a locked slot too, so either guard could be deleted
-- without changing what got destroyed. The preview never re-verifies, so a locked slot counted
-- as deletable there is a preview promising something the delete refuses.
FREE = 0
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
LOCKED["0:1"] = true
Valuate:AutoDeleteJunk({ preview = true })
said = table.concat(__printed, "\\n")
ok(said:find("2 deletable", 1, true) ~= nil,
   "the preview counts a locked slot as protected, not as deletable")
ok(said:find("mid%-move") ~= nil, "and says which way it is unavailable")

bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
LOCKED["0:1"] = true
Valuate:AutoDeleteJunk()
ok(#DELETED > 0, "the rest of the bag is still processed")
for _, gone in ipairs(DELETED) do
    ok(gone ~= BAGS[0][1].link, "and the locked slot is never one of the deleted")
end

-- ---- THE SLOT IS RE-CHECKED JUST BEFORE THE DELETE --------------------------------------------------
-- Bags shift between the scan and here: another addon moves something, a stack merges. A slot
-- whose contents changed is skipped rather than destroyed on the strength of a stale read.
--
-- Modelled by READ COUNT: the scan reads each slot once, the delete loop reads a candidate
-- again just before destroying it, so swapping on the second read is exactly the race.
FREE = 0
bagsOf({ junkItem(1, 10), junkItem(2, 20) })
SWAP_AFTER_SCAN = "0:1"
Valuate:AutoDeleteJunk()
for _, gone in ipairs(DELETED) do
    ok(gone ~= "|Hitem:999:0|h[Something Else]|h",
       "an item that moved into the slot after the scan is never deleted")
    ok(gone ~= BAGS[0][1].link,
       "nor the item that was there at scan time and has since moved on")
end
eq(#DELETED, 1, "the untouched slot is still processed")
SWAP_AFTER_SCAN = nil

-- ---- THE CONFIRMATION POPUP IS NEVER ANSWERED --------------------------------------------------------
-- It exists to prevent exactly this kind of accident. If it intercepts the delete the item is
-- still on the cursor, and the right response is to put it back and say so.
FREE = 0
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
CONFIRM_LINK = BAGS[0][1].link
Valuate:AutoDeleteJunk()
for _, gone in ipairs(DELETED) do
    ok(gone ~= CONFIRM_LINK, "an item behind a confirmation dialog is not deleted")
end
eq(CURSOR, nil, "and it is put back rather than left on the cursor")
said = table.concat(__printed, "\\n")
ok(said:find("needs manual confirmation", 1, true) ~= nil,
   "with a line saying which item was skipped and why")
CONFIRM_LINK = nil

-- ---- PROTECTED ITEMS NEVER REACH THE QUEUE ------------------------------------------------------------
-- deletetest.js proves WHICH items are protected. This proves the protection is consulted at
-- all - a queue built without asking would delete a best-in-slot on the first cleanup.
FREE = 0
bagsOf({ junkItem(1, 10), junkItem(2, 20), junkItem(3, 30) })
PROTECTED = { [BAGS[0][1].link] = true, [BAGS[0][2].link] = true }
Valuate:AutoDeleteJunk()
eq(#DELETED, 1, "only the unprotected item is deleted")
eq(DELETED[1], BAGS[0][3].link, "and it is the right one")
PROTECTED = {}

return failures, checks
`,
  "deletelimit",
  "the auto-delete bound"
);
