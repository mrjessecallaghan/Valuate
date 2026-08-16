#!/usr/bin/env node
/*
 * @gate A locked slot survives a scan with its item still in it
 *
 * Runs the REAL ns.ResetScanResults from Valuate.lua.
 *
 * Locking a slot and pressing Scan EMPTIED it. The reset at the top of ScanBestEquipment
 * replaced each scale's table wholesale and copied only `.locks` back, and every assignment
 * site downstream reads `if not locks[slotId]` before writing - so the locked slot was cleared
 * and then deliberately not refilled. Five guards, all working exactly as written, all
 * protecting a slot that had been emptied a few hundred lines earlier.
 *
 * That is the shape worth naming: the bug was not in the code that mentions locks. Everything
 * that mentions locks was right. It was in the one line that did not.
 *
 * The lock has a single promise - "keep what is here" - so that is what this file asserts, in
 * both directions:
 *
 *   * a locked slot keeps its item across a scan;
 *   * an unlocked slot does NOT, or the reset has stopped resetting and every scan result is
 *     whatever the first scan found.
 *
 * The second matters as much as the first. "Preserve everything" would pass a naive version of
 * this gate and would quietly freeze best-in-slot forever.
 *
 * Usage:  node tools/locktest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^function ns\.ResetScanResults\(([\s\S]*?)\nend\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `function ns.ResetScanResults` in Valuate.lua - it was renamed, " +
      "moved or inlined back into ScanBestEquipment, so this gate is testing nothing"
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

local ns = {}
` + m[0] + `

-- ---- the promise: a locked slot keeps its item ------------------------------------------
local store = {
    Dps = {
        locks = { [5] = true },
        [5] = { itemLink = "|Hitem:100|h[Locked Chest]|h", score = 42 },
        [1] = { itemLink = "|Hitem:200|h[Old Helm]|h", score = 10 },
    },
}
ns.ResetScanResults(store, { "Dps" })

ok(store.Dps[5] ~= nil, "the locked slot still holds something after a scan reset")
eq(store.Dps[5] and store.Dps[5].itemLink, "|Hitem:100|h[Locked Chest]|h", "and it is the same item")
eq(store.Dps[5] and store.Dps[5].score, 42, "with its score intact, so the panel does not redraw it as blank")
eq(store.Dps.locks[5], true, "and the lock itself is still on")

-- ---- the other half: everything else IS cleared -------------------------------------------
-- Without this, "preserve the locked slot" and "preserve everything" both pass, and the second
-- freezes best-in-slot at whatever the first scan of the session found.
eq(store.Dps[1], nil, "an UNLOCKED slot is cleared, so the scan can actually rescan")

-- ---- a lock with nothing under it -----------------------------------------------------------
-- You can lock an empty slot. Nothing to carry, and it must not invent an entry - a slot
-- holding a nil record is what the panel reads as "best-in-slot" and the sell path reads as
-- protected.
store = { Dps = { locks = { [9] = true } } }
ns.ResetScanResults(store, { "Dps" })
eq(store.Dps[9], nil, "locking an empty slot does not conjure an entry into it")
eq(store.Dps.locks[9], true, "though the lock is kept")

-- ---- a lock explicitly turned OFF ------------------------------------------------------------
-- The UI writes locks[slotId] = newLockState or nil, so false should not occur - but a
-- falsey value must never be read as locked, or unlocking a slot would stop it rescanning
-- while showing an open padlock.
store = {
    Dps = {
        locks = { [5] = false },
        [5] = { itemLink = "|Hitem:100|h[Chest]|h", score = 42 },
    },
}
ns.ResetScanResults(store, { "Dps" })
eq(store.Dps[5], nil, "a lock set to false is not a lock, and the slot is cleared")

-- ---- more than one scale ----------------------------------------------------------------------
-- Locks are per scale. One scale's lock must not hold another scale's slot, and must not fail
-- to hold its own.
store = {
    Dps  = { locks = { [5] = true }, [5] = { itemLink = "dps-chest", score = 1 } },
    Tank = { [5] = { itemLink = "tank-chest", score = 2 } },
}
ns.ResetScanResults(store, { "Dps", "Tank" })
eq(store.Dps[5] and store.Dps[5].itemLink, "dps-chest", "the scale with the lock keeps its item")
eq(store.Tank[5], nil, "the scale without one does not")

-- A scale that has never been scanned starts empty rather than erroring.
store = {}
ns.ResetScanResults(store, { "Fresh" })
ok(type(store.Fresh) == "table", "a scale with no previous results gets a fresh table")
eq(store.Fresh.locks, nil, "and no locks table it never had")

-- ---- weapons, which have their own assignment path --------------------------------------------
-- Slots 16 and 17 are written from the weapon-set logic, guarded by locks[16]/locks[17]. Same
-- reset, so the same bug applied: a locked main hand was cleared and then skipped.
store = {
    Dps = {
        locks = { [16] = true },
        [16] = { itemLink = "|Hitem:300|h[Locked Axe]|h", score = 99 },
        [17] = { itemLink = "|Hitem:400|h[Shield]|h", score = 20 },
        activeWeaponSet = "OneHandShield",
    },
}
ns.ResetScanResults(store, { "Dps" })
eq(store.Dps[16] and store.Dps[16].itemLink, "|Hitem:300|h[Locked Axe]|h", "a locked main hand keeps its weapon")
eq(store.Dps[17], nil, "the unlocked off-hand is cleared for the rescan")
-- activeWeaponSet is recomputed from the new scan, so it is deliberately NOT carried over -
-- a stale one would name a set that no longer matches the slots beside it.
eq(store.Dps.activeWeaponSet, nil, "the active weapon set is left to be recomputed")

-- ---- bad input does not throw ------------------------------------------------------------------
-- This runs at the top of every scan, including the first one of a session.
ns.ResetScanResults(nil, { "Dps" })
ns.ResetScanResults({}, nil)
ns.ResetScanResults({}, {})
ok(true, "no store, no scale list and an empty list are all survivable")

return failures, checks
`,
  "locktest",
  "the slot lock"
);
