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

` + m[0] + NL + note[0] + `

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

return failures, checks
`,
  "bestequiptest",
  "the slot comparison states"
);
