#!/usr/bin/env node
/*
 * @gate An empty slot reads as empty, not as "no comparison"
 *
 * Runs the REAL source of SlotCompareState from ui/BestEquipment.lua.
 *
 * That function decides what a slot's best item is compared against, and it has three
 * answers which are not interchangeable: nothing equipped, something equipped this scale
 * cannot score, and a real number to subtract. It was written inline as
 *
 *     if score > 0 ... elseif score == 0 or not score then "--" else "New"
 *
 * where the "New" arm was unreachable - a bare slot has no stats, so `not score` caught it
 * one branch earlier. Every empty ring, neck and trinket rendered as a grey "--" meaning
 * "no comparison available", on precisely the slots where the comparison is easiest and
 * the gain is largest, and it contradicted the summary line directly above it, which
 * counts an empty slot's whole score as an upgrade.
 *
 * Nothing caught that for eighteen releases because it is not a crash, a nil call or a
 * missing symbol - it is a correct-looking branch in the wrong order. A gate that reads
 * structure cannot see it. This one runs it.
 *
 * The row and its tooltip used to carry a copy of the branch each; they now share this
 * function, so the states below are checked once for both.
 *
 * Usage:  node tools/bestequiptest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const src = fs.readFileSync(path.join(ADDON_ROOT, "ui", "BestEquipment.lua"), "utf8");
const m = src.match(/^local function SlotCompareState\(([\s\S]*?)\nend\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `local function SlotCompareState` in ui/BestEquipment.lua - " +
      "it was renamed, moved or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

// The lock note, sliced too: it is a claim about the user's own gear, made on a tooltip that
// simultaneously claims something else, so it has to be right in every combination.
const NL = String.fromCharCode(10);
const noteStart = src.indexOf("function ns.WeaponSetLockNote(");
const noteEnd = noteStart < 0 ? -1 : src.indexOf(NL + "end" + NL, noteStart);
const note = noteStart < 0 || noteEnd < 0 ? null : [src.slice(noteStart, noteEnd + 5)];
if (!note) {
  console.error(
    "  SLICE  could not find `function ns.WeaponSetLockNote` in ui/BestEquipment.lua - " +
      "this gate is testing nothing"
  );
  process.exit(1);
}

/* The bank planner lives in Valuate.lua, not in ui/BestEquipment.lua - but it answers the same
 * question this gate already owns: which item belongs in which slot, and where is it. */
const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const WITHDRAW = (function () {
  const parts = ["ns = ns or {}"];
  for (const n of ["BankWithdrawPlan", "BankWithdrawBlocked"]) {
    const at = core.indexOf("function ns." + n + "(");
    if (at < 0) { console.error("  SLICE  ns." + n + " is gone - this gate would test nothing"); process.exit(1); }
    parts.push(core.slice(at, core.indexOf(String.fromCharCode(10) + "end" + String.fromCharCode(10), at) + 5));
  }
  return parts.join(String.fromCharCode(10));
})();
const run = load([]);

run(
  `
local ns = {}
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function eq(got, want, what)
    checks = checks + 1
    if got ~= want then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end

` + m[0] + NL + note[0] + NL + WITHDRAW + `

local STATS = { Strength = 10 }

-- Nothing equipped. The regression: this is the state that was unreachable.
eq(SlotCompareState(nil, nil), "new", "no stats and no score means the slot is empty")

-- Equipped, but the scale bans one of its stats, so CalculateItemScore returned nil.
-- Same nil score as an empty slot, completely different answer.
eq(SlotCompareState(STATS, nil), "unusable", "stats but no score means unusable for this scale")

-- A real score. All three of these used to be handled by two different arms.
eq(SlotCompareState(STATS, 42), "delta", "a positive score compares normally")
eq(SlotCompareState(STATS, 0), "delta", "a ZERO score is a real number, not a missing one")
eq(SlotCompareState(STATS, -5), "delta", "a NEGATIVE score is real too - scales can have negative weights")

-- An empty stats TABLE is not the same as no stats: you are wearing something, it just
-- has nothing on it this scale wants. Lua treats {} as truthy, and that is the behaviour
-- wanted here - it must not read as an empty slot.
eq(SlotCompareState({}, 0), "delta", "an item with no relevant stats still counts as equipped")
eq(SlotCompareState({}, nil), "unusable", "...and is unusable rather than empty when unscorable")

-- ---- what a weapon set is NOT describing --------------------------------------------------------
-- A lock pins a slot; weapon SETS are recomputed every scan, because a set is a comparison
-- between configurations and a pinned slot is not part of any comparison. So the Main Hand row
-- can show your locked axe while the set panel underneath claims this configuration's main hand
-- is something else. Both true, contradicting each other on screen.
--
-- Rather than fold locks into the set arithmetic - where a pinned two-hander would have to
-- invalidate the dual-wield set entirely, and "best set" would stop meaning anything - the sets
-- keep saying what they mean and the tooltip says which half you have overridden.
local note = ns.WeaponSetLockNote

eq(note(nil), nil, "no best-equipment data at all is not a note")
eq(note({}), nil, "nor a scale with no locks table")
eq(note({ locks = {} }), nil, "nor an empty one")
eq(note({ locks = { [5] = true } }), nil,
   "and a locked CHEST says nothing here - a weapon set does not describe your chest")

local mhOnly = note({ locks = { [16] = true }, [16] = { itemName = "Bonebiter" } })
ok(mhOnly ~= nil, "a locked main hand produces a note")
ok(mhOnly:find("Main Hand", 1, true) ~= nil, "naming which slot")
ok(mhOnly:find("Bonebiter", 1, true) ~= nil, "and which weapon, so it matches the row above")
eq(mhOnly:find("Off Hand", 1, true), nil, "and it does not claim the off hand is locked too")

local ohOnly = note({ locks = { [17] = true }, [17] = { itemName = "Bulwark" } })
ok(ohOnly:find("Off Hand", 1, true) ~= nil, "a locked off hand names that slot instead")
eq(ohOnly:find("Main Hand", 1, true), nil, "and not the main hand")

local both = note({
    locks = { [16] = true, [17] = true },
    [16] = { itemName = "Bonebiter" }, [17] = { itemName = "Bulwark" },
})
ok(both:find("Bonebiter", 1, true) ~= nil and both:find("Bulwark", 1, true) ~= nil,
   "both locked names both")
ok(both:find("neither", 1, true) ~= nil,
   "and says the set describes NEITHER, rather than reading as two separate half-truths")

-- A lock on a slot holding nothing. You can lock an empty slot, and the note must not invent an
-- item name or blank out mid-sentence.
local empty = note({ locks = { [16] = true } })
ok(empty ~= nil and empty:find("Main Hand", 1, true) ~= nil,
   "a lock on an empty slot still says the slot is pinned")

-- ---- what to take out of the bank -----------------------------------------------------------------
--
-- Best Equipment already knew a banked item was best-in-slot and tagged it source = "bank". What
-- the addon then said was "Bank gear is excluded (Equip All cannot reach it)" - true, and the end
-- of the sentence. It knew the answer and left you to find the items yourself in a bank of
-- several hundred.
local function idFrom(link) return tonumber(link:match("item:(%d+)")) end

local BEST = {
    Dps = {
        [1] = { source = "bank", itemLink = "|Hitem:11|h[Helm]|h",  slotName = "Head" },
        [5] = { source = "bags", itemLink = "|Hitem:22|h[Chest]|h", slotName = "Chest" },
        [7] = { source = "bank", itemLink = "|Hitem:33|h[Legs]|h",  slotName = "Legs" },
        -- In your BAGS, and a copy of it also sits in the bank. The only thing separating this
        -- from a withdrawal is the source tag, so without it this entry sends you to the bank
        -- for something already on your person.
        [15] = { source = "bags", itemLink = "|Hitem:44|h[Cloak]|h", slotName = "Back" },
    },
    Tank = {
        [1] = { source = "bank", itemLink = "|Hitem:11|h[Helm]|h",  slotName = "Head" },
        [8] = { source = "bank", itemLink = "|Hitem:99|h[Boots]|h", slotName = "Feet" },
    },
}
local BANK = { [11] = true, [33] = true, [99] = true, [44] = true }

local plan, why = ns.BankWithdrawPlan(BEST, BANK, { Dps = true, Tank = true }, idFrom)
eq(#plan, 3, "every banked best-in-slot is listed")
eq(why, nil, "with nothing to explain away")

-- Only what is IN the bank. An item already on your body or in your bags is not a trip.
local bagsOnly = ns.BankWithdrawPlan({ Dps = { [5] = BEST.Dps[5] } }, BANK, { Dps = true }, idFrom)
eq(#bagsOnly, 0, "an item that is not in the bank is never listed")

-- The sharper version: a bags item whose twin IS in the bank. Only the source tag separates
-- them, so this is the assertion that makes that tag load-bearing.
for _, e in ipairs(plan) do
    ok(e.slotId ~= 15, "gear already in your bags is not listed, even when the bank has one too")
end

-- ONE PER SLOT. Two scales wanting the same banked piece is one withdrawal, not two.
local heads = 0
for _, e in ipairs(plan) do if e.slotId == 1 then heads = heads + 1 end end
eq(heads, 1, "two scales wanting the same slot produce ONE entry")

-- Stable between runs: the scale names are walked sorted, not in pairs() order.
local again = ns.BankWithdrawPlan(BEST, BANK, { Dps = true, Tank = true }, idFrom)
for i = 1, #plan do eq(again[i].slotId, plan[i].slotId, "the same bank produces the same list") end

-- A best-equipment entry the snapshot has never seen is STALE. Sending you to fetch something
-- that is not there is worse than saying nothing.
local stale = ns.BankWithdrawPlan(BEST, { [11] = true }, { Dps = true, Tank = true }, idFrom)
eq(#stale, 1, "an item missing from the snapshot is not listed")

-- Inactive scales are not ranked, so their best-in-slot is not a reason to walk to the bank.
local inactive = ns.BankWithdrawPlan(BEST, BANK, { Tank = true }, idFrom)
eq(#inactive, 2, "only the active scale's picks are offered")
eq(#(select(1, ns.BankWithdrawPlan(BEST, BANK, {}, idFrom))), 0, "with no active scale, nothing")
ok(select(2, ns.BankWithdrawPlan(BEST, BANK, {}, idFrom)) ~= nil, "and it says why")

ok(pcall(ns.BankWithdrawPlan, nil, nil, nil, idFrom), "no scan at all is survivable")
eq(#(select(1, ns.BankWithdrawPlan(nil, nil, nil, idFrom))), 0, "and lists nothing")

-- ---- and whether it can act ---------------------------------------------------------------------
-- Refused AS A WHOLE rather than moving what fits. A half-done withdrawal leaves you believing
-- you have your gear when some of it is still in the bank.
eq(ns.BankWithdrawBlocked(3, 5, true, false), true, "with room and the bank open, it can move")
eq(ns.BankWithdrawBlocked(3, 2, true, false), false, "two free slots is not enough for three items")
ok(select(2, ns.BankWithdrawBlocked(3, 2, true, false)):find("3", 1, true) ~= nil,
   "and it says how many are needed")
eq(ns.BankWithdrawBlocked(3, 5, false, false), false, "the bank has to be open")
eq(ns.BankWithdrawBlocked(0, 5, true, false), false, "nothing to withdraw is not an action")

-- The in-transit guard, READ and never relaxed: moving slots while items are in flight is how
-- things vanish. It outranks everything else, including having plenty of room.
eq(ns.BankWithdrawBlocked(1, 20, true, true), false, "mid equipment swap it refuses")
ok(select(2, ns.BankWithdrawBlocked(1, 20, true, true)):find("moving", 1, true) ~= nil,
   "and says the items are still settling rather than blaming your bags")

return failures, checks
`,
  "bestequiptest",
  "the slot comparison states"
);
