#!/usr/bin/env node
/*
 * @gate Scan results are never thrown away because the scales failed to load
 *
 * Runs the real Valuate:GetScales, Valuate:MigrateToPerCharacter and
 * Valuate:CleanupOrphanedBestEquipment from Valuate.lua.
 *
 * MigrateToPerCharacter is in that list because leaving it out is what made the first version
 * of this gate worthless. It passed every assertion while the protection it was written for
 * never fired once in the client - see THE ORDER THE CLIENT ACTUALLY WALKS at the bottom.
 *
 * This deletes the scan results of any scale it cannot find, and it runs on EVERY login.
 *
 * That is right when you deleted a scale. Removing a scale deliberately leaves its scan behind
 * - ui/ScaleList.lua just nils the entry - and this is the tidy-up that follows at next login.
 *
 * It is catastrophic when the scales simply did not load. Every scan looks orphaned, all of it
 * goes, and the saved variable is written without it when you log out. What that costs you is a
 * re-scan of every bag and bank you own, assuming you notice at all; nothing errors and nothing
 * is printed under the old rule unless chat messages happened to be on.
 *
 * The two states arrive here as the SAME empty table, because GetScales hands back a table it
 * invented when ValuateScales is nil rather than admitting it was missing. So it records having
 * invented one, and this refuses to delete on the strength of a read that did not happen. It is
 * the same distinction as everywhere else in this addon - "I could not look" is not "there is
 * nothing there" - applied to the one path that destroys data.
 *
 * The assertions are paired throughout, because failing closed too eagerly is its own bug: a
 * version that never cleaned anything up would pass a one-sided test and quietly hoard the scan
 * data of every scale you have ever deleted.
 *
 * Usage:  node tools/orphancleanup.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^function Valuate:GetScales\([\s\S]*?\r?\nend/m,
  // Sliced in because the client reaches the cleanup THROUGH this, and what it does on the
  // way is the difference between the protection working and being decorative.
  /^function Valuate:MigrateToPerCharacter\([\s\S]*?\r?\nend/m,
  /^function Valuate:CleanupOrphanedBestEquipment\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error(
      "  SLICE  could not find " + re + " in Valuate.lua - this gate is testing nothing"
    );
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
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function saidAny(needle)
    for _, l in ipairs(SAID) do
        if l:lower():find(needle:lower(), 1, true) then return true end
    end
    return false
end

ns = {}
Valuate = {}
SAID = {}
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    SAID[#SAID + 1] = table.concat(parts, " ")
end

-- Models the real GetOptions rather than just answering: it materialises ValuateOptions when
-- that is nil, and MigrateToPerCharacter now leans on exactly that. A stub that only returned a
-- table would let a migration which quietly stopped initialising options pass unnoticed - the
-- same shape of gap that let this whole release's bug through.
function Valuate:GetOptions()
    if not ValuateOptions then ValuateOptions = {} end
    ValuateOptions.chatMessages = true
    return ValuateOptions
end
function Valuate:GetBestEquipment()
    if not ValuateBestEquipment then ValuateBestEquipment = {} end
    return ValuateBestEquipment
end

` + sliced.join("\n") + `

-- Puts the world back the way a fresh login finds it: saved variables as given, and no memory
-- of a previous run's invented table.
local function login(scales, best)
    ValuateScales, ValuateBestEquipment, ValuateOptions = scales, best, nil
    ns.scalesWereCreated = nil
    SAID = {}
end

-- ---- the ordinary tidy-up still happens ------------------------------------------------------
-- Deleting a scale leaves its scan behind on purpose. If this stopped cleaning up, the addon
-- would hoard the scan data of every scale you have ever deleted - a slower failure, but a
-- failure, and one a one-sided "never delete" fix would introduce.
login({ Dps = {} }, { Dps = {}, OldTank = {}, Gone = {} })
eq(Valuate:CleanupOrphanedBestEquipment(), 2, "scans for scales that no longer exist ARE removed")
ok(ValuateBestEquipment.Dps ~= nil, "and the living scale's scan is kept")
eq(ValuateBestEquipment.OldTank, nil, "while the deleted one's is gone")
eq(count(ValuateBestEquipment), 1, "leaving exactly what is still in use")

-- ---- THE ONE THAT MATTERS: the scales never loaded ---------------------------------------------
-- ValuateScales nil means GetScales invents a table. Every scan then looks orphaned and, under
-- the old rule, every one of them was deleted on a login where nothing looked wrong.
login(nil, { Dps = {}, Tank = {}, Healer = {} })
eq(Valuate:CleanupOrphanedBestEquipment(), 0,
   "with the scales unread, NOTHING is deleted")
eq(count(ValuateBestEquipment), 3, "every scan is still there")
ok(saidAny("could not be read"), "and you are told why the tidy-up did not run")
ok(saidAny("Nothing has been deleted"), "and told plainly that nothing was lost")

-- ---- the pair: an empty table you made yourself IS a decision -------------------------------------
-- Delete your last scale and the table is empty because you emptied it. That is not a failed
-- read, and refusing here would hoard the data forever. This is the assertion that stops the
-- fix above from being "never clean up".
login({}, { Dps = {}, Tank = {} })
eq(Valuate:CleanupOrphanedBestEquipment(), 2,
   "an empty scales table you emptied YOURSELF still cleans up")
eq(count(ValuateBestEquipment), 0, "because that is a decision, not a failure to read")

-- ---- a brand-new character falls straight through --------------------------------------------------
-- No scales table either, but nothing to lose. The refusal must be about the data at RISK, not
-- about the missing table on its own, or every new character gets a warning about nothing.
login(nil, nil)
eq(Valuate:CleanupOrphanedBestEquipment(), 0, "a new character cleans up nothing")
eq(#SAID, 0, "and is warned about nothing, because it had nothing to lose")

-- ---- GetScales admits what it did ---------------------------------------------------------------------
login(nil, nil)
Valuate:GetScales()
eq(ns.scalesWereCreated, true, "GetScales records having invented the table")
eq(type(ValuateScales), "table", "and still returns a usable one")

login({ Dps = {} }, nil)
Valuate:GetScales()
eq(ns.scalesWereCreated, nil, "a table that was really there is not reported as invented")

-- ---- it survives being called on nothing --------------------------------------------------------------
-- This runs during login, before much else exists. An error here would take the rest of
-- initialisation with it.
login(nil, nil)
ok(pcall(Valuate.CleanupOrphanedBestEquipment, Valuate), "cleanup on an empty world does not error")

-- ---- THE ORDER THE CLIENT ACTUALLY WALKS -------------------------------------------------------
--
-- Everything above calls GetScales directly. The client does not: Valuate:Initialize runs
--
--     MigrateToPerCharacter()  ->  GetScales()  ->  CleanupOrphanedBestEquipment()
--
-- and MigrateToPerCharacter used to carry its OWN copy of the nil-check:
--
--     if not ValuateScales then ValuateScales = {} end
--
-- which materialised the table before anything could observe it had been missing. The flag was
-- therefore never set, the refusal never fired, and every assertion above passed anyway -
-- because every assertion above skipped the step that broke it.
--
-- A protection is only as good as the ORDER it is reached in, so this drives the real one.
local function initialize()
    Valuate:MigrateToPerCharacter()
    Valuate:GetScales()
    return Valuate:CleanupOrphanedBestEquipment()
end

login(nil, { Dps = {}, Tank = {}, Healer = {} })
eq(initialize(), 0,
   "reached the way the client reaches it, an unread scales table STILL deletes nothing")
eq(count(ValuateBestEquipment), 3, "and every scan survives the login")
ok(saidAny("could not be read"), "with the reason said out loud")

-- The pair, through the same door: a genuine tidy-up must still happen on the real path.
login({ Dps = {} }, { Dps = {}, Gone = {} })
eq(initialize(), 1, "and a scale you really deleted is still cleaned up on that same path")
eq(count(ValuateBestEquipment), 1, "leaving what is still in use")

-- Migration must not swallow the fact either. It exists only to make sure the tables are
-- there, and the two functions that do that are the two that know why it matters.
login(nil, nil)
Valuate:MigrateToPerCharacter()
eq(ns.scalesWereCreated, true,
   "MigrateToPerCharacter goes through GetScales, so the missing table is still recorded")
eq(type(ValuateOptions), "table", "and options are initialised too")

return failures, checks
`,
  "orphancleanup",
  "orphaned scan cleanup"
);
