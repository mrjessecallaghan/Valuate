#!/usr/bin/env node
/*
 * @gate Nothing is soulbound on your behalf without intent you gave
 *
 * Runs the real Valuate:HandleBindConfirm, Valuate:MarkEquipIntent and
 * Valuate:ConfirmAutoLootRoll from Valuate.lua.
 *
 * Binding is PERMANENT. A bind-on-equip item that binds is unsellable and untradeable for the
 * rest of its life, and there is no undo anywhere in the game for it. That puts this function
 * in the same class as delete and sell, and it had no gate at all.
 *
 * One check stands between you and a silently soulbound BoE: HasEquipIntent(). Valuate answers
 * an equip-bind prompt ONLY when Valuate started the equip. Take that check away and the addon
 * confirms the prompt raised by an item you picked up to look at - no click, no message, and
 * the item is bound. Nothing errors, nothing appears in a log, and the item is worth a fraction
 * of what it was a second earlier. That is the assertion this gate exists for.
 *
 * The intent is deliberately TIME-BOUNDED rather than a flag cleared on completion. An equip
 * that never finishes would leave a flag armed forever, and "forever" on this particular action
 * is the worst possible failure. So the gate pins the expiry too: a version that armed intent
 * permanently would pass every other check here.
 *
 * Three separate consents, and merging any two of them is a bug:
 *
 *   EQUIP_BIND_CONFIRM / AUTOEQUIP_BIND_CONFIRM   Valuate's own equip -> equip intent
 *   LOOT_BIND_CONFIRM                             YOUR looting -> its own opt-in setting
 *   USE_BIND_CONFIRM                              never answered, at all
 *
 * The third is not an oversight and must never be "fixed". Using an item is a protected path,
 * so an addon calling ConfirmBindOnUse taints it and the client then blocks the actual use -
 * which broke Ascension's vanity sync. A regression that helpfully handles it does not merely
 * fail; it stops bind-on-use items working at all.
 *
 * Usage:  node tools/bindconfirm.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local equipIntentUntil = 0/m,
  /^function Valuate:MarkEquipIntent\([\s\S]*?\r?\nend/m,
  /^local function HasEquipIntent\([\s\S]*?\r?\nend/m,
  /^function Valuate:HandleBindConfirm\([\s\S]*?\r?\nend/m,
  /^function Valuate:ConfirmAutoLootRoll\([\s\S]*?\r?\nend/m,
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

Valuate = {}
OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end

-- Time under our control, so the expiry can actually be walked past rather than assumed.
NOW = 1000
function GetTime() return NOW end

-- Every confirmation the client offers, recorded rather than performed.
BOUND = {}
function EquipPendingItem(slot) BOUND[#BOUND + 1] = { how = "equip", slot = slot } end
function ConfirmLootSlot(slot) BOUND[#BOUND + 1] = { how = "loot", slot = slot } end
function ConfirmBindOnUse(slot) BOUND[#BOUND + 1] = { how = "use", slot = slot } end
function ConfirmLootRoll(id, rollType) BOUND[#BOUND + 1] = { how = "roll", slot = id, roll = rollType } end

` + sliced.join("\n") + `

local function reset()
    BOUND = {}
    OPTIONS = {}
    equipIntentUntil = 0
end

-- ---- THE ONE THAT MATTERS ---------------------------------------------------------------------
-- No intent means Valuate did not start this equip - so the prompt belongs to something YOU did,
-- and answering it binds an item you only picked up to look at. Permanently. Silently.
reset()
Valuate:HandleBindConfirm("EQUIP_BIND_CONFIRM", 5)
eq(#BOUND, 0, "with no equip intent, an equip-bind prompt is NOT answered")
Valuate:HandleBindConfirm("AUTOEQUIP_BIND_CONFIRM", 5)
eq(#BOUND, 0, "and neither is the auto-equip flavour of it")

-- The pair: with intent it must actually work, or the check is just a switch stuck off.
reset()
Valuate:MarkEquipIntent(8)
Valuate:HandleBindConfirm("EQUIP_BIND_CONFIRM", 5)
eq(#BOUND, 1, "an equip Valuate DID start is confirmed")
eq(BOUND[1].how, "equip", "through the equip api")

-- The slot is passed straight through. Slot semantics differ per event, and confirming the
-- wrong one binds a different item than the prompt was about - which looks like nothing at all
-- went wrong until you find the bound item later.
eq(BOUND[1].slot, 5, "and for the slot the prompt was actually about")
reset()
Valuate:MarkEquipIntent(8)
Valuate:HandleBindConfirm("EQUIP_BIND_CONFIRM", 12)
eq(BOUND[1] and BOUND[1].slot, 12, "a different slot is passed through unchanged, not remembered")

-- ---- intent EXPIRES ------------------------------------------------------------------------------
-- Time-bounded rather than cleared on completion, deliberately: an equip that never finishes
-- would leave a flag armed forever, and forever is the worst possible duration for this one.
reset()
Valuate:MarkEquipIntent(8)
NOW = NOW + 20
Valuate:HandleBindConfirm("EQUIP_BIND_CONFIRM", 5)
eq(#BOUND, 0, "intent EXPIRES - a stale one does not answer prompts hours later")
NOW = 1000

-- ---- three separate consents ---------------------------------------------------------------------
-- Looting is something YOU did, so Valuate's own equip intent must not authorise it. Merging
-- the two would mean an Equip All quietly consenting to bind whatever you loot next.
reset()
Valuate:MarkEquipIntent(8)
Valuate:HandleBindConfirm("LOOT_BIND_CONFIRM", 3)
eq(#BOUND, 0, "equip intent does NOT authorise binding something you looted")

reset()
OPTIONS.autoConfirmBindOnLoot = true
Valuate:HandleBindConfirm("LOOT_BIND_CONFIRM", 3)
eq(#BOUND, 1, "loot binding has its own opt-in, and honours it")
eq(BOUND[1].how, "loot", "through the loot api")
eq(BOUND[1].slot, 3, "for the slot it was given")

reset()
OPTIONS.autoConfirmBindOnLoot = false
Valuate:HandleBindConfirm("LOOT_BIND_CONFIRM", 3)
eq(#BOUND, 0, "and with the opt-in off, nothing is bound")

-- ---- USE_BIND_CONFIRM is never answered ------------------------------------------------------------
-- Not an oversight. Using an item is a protected path, so calling ConfirmBindOnUse taints it and
-- the client then blocks the actual use - which broke Ascension's vanity sync. A regression that
-- helpfully handles this does not merely fail: it stops bind-on-use items working at all.
reset()
OPTIONS.autoConfirmBindOnLoot = true
Valuate:MarkEquipIntent(8)
Valuate:HandleBindConfirm("USE_BIND_CONFIRM", 1)
eq(#BOUND, 0,
   "USE_BIND_CONFIRM is never answered, with every consent granted and intent fresh")

-- ---- an event nobody wired ---------------------------------------------------------------------------
reset()
Valuate:MarkEquipIntent(8)
OPTIONS.autoConfirmBindOnLoot = true
Valuate:HandleBindConfirm("SOMETHING_ELSE", 1)
eq(#BOUND, 0, "an unrelated event confirms nothing")

-- ---- the client may not have the api ------------------------------------------------------------------
-- These vary across 3.3.5 builds, which is why each is feature-detected. Erroring here would
-- leave the prompt on screen with a Lua error on top of it.
reset()
Valuate:MarkEquipIntent(8)
local realEquip, realLoot = EquipPendingItem, ConfirmLootSlot
EquipPendingItem, ConfirmLootSlot = nil, nil
OPTIONS.autoConfirmBindOnLoot = true
ok(pcall(Valuate.HandleBindConfirm, Valuate, "EQUIP_BIND_CONFIRM", 5),
   "a client without EquipPendingItem does not error")
ok(pcall(Valuate.HandleBindConfirm, Valuate, "LOOT_BIND_CONFIRM", 5),
   "nor one without ConfirmLootSlot")
EquipPendingItem, ConfirmLootSlot = realEquip, realLoot

-- ---- rolling on loot ------------------------------------------------------------------------------------
-- Same family: confirming a Need roll on a bind-on-pickup item binds it the moment you win.
reset()
Valuate:ConfirmAutoLootRoll(7, 1)
eq(#BOUND, 0, "a loot roll is not confirmed while auto-roll is off")

reset()
OPTIONS.autoRollLoot = true
Valuate:ConfirmAutoLootRoll(7, 1)
eq(#BOUND, 1, "and is confirmed when it is on")
eq(BOUND[1].slot, 7, "for the roll it was given")
eq(BOUND[1].roll, 1, "with the roll type passed through - Need and Greed bind differently")

reset()
OPTIONS.autoRollLoot = true
Valuate:ConfirmAutoLootRoll(nil, 1)
eq(#BOUND, 0, "no roll id confirms nothing rather than guessing at one")

return failures, checks
`,
  "bindconfirm",
  "bind confirmations"
);
