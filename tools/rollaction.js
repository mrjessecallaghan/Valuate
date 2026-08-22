#!/usr/bin/env node
/*
 * @gate Need is only rolled on something actually wanted, and an uncached item retries once
 *
 * Runs the REAL Valuate:AutoRollOnLoot, with the REAL DecideRollType inside it, against a
 * mocked loot roll.
 *
 * The third thing this addon does on your behalf that cannot be taken back - after deleting an
 * item and taking a quest reward. A wrong Need costs someone else the item and costs you the
 * reputation, and neither is recoverable by any means the game offers.
 *
 * tools/rolltest.js proves the classification: what counts as a learnable recipe, what counts
 * as a useful trade good. This proves what is DONE with those answers, which is the same split
 * that left auto-delete's bound and the quest-reward action untested.
 *
 * Two properties carry the file:
 *
 *   * NEED IS NEVER ROLLED ON SOMETHING NOT WANTED. Greed on a bad guess is a shrug; Need on
 *     one is a fight. The rule is `wants and canNeed`, and both halves matter - Need is
 *     frequently not offered for a recipe above your skill, and Greed still wins it.
 *   * AN UNCACHED ITEM RETRIES EXACTLY ONCE. Rolls expire, so there is one grace period and no
 *     more; without the isRetry guard an item the client never caches would defer forever and
 *     the roll would be lost by inaction, which looks identical to the addon being off.
 *
 * Usage:  node tools/rollaction.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

function slice(header, what) {
  const hit = lua.match(new RegExp("^" + header + "\\([\\s\\S]*?\\r?\\nend\\r?\\n", "m"));
  if (!hit) {
    console.error("  SLICE  could not find " + what + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return hit[0];
}

const decide = slice("local function DecideRollType", "DecideRollType");
const action = slice("function Valuate:AutoRollOnLoot", "AutoRollOnLoot");

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

-- ---- the loot roll ------------------------------------------------------------------------------
CAN_NEED, CAN_GREED = true, true
LINK = "|Hitem:100:0|h[Some Item]|h"
CACHED = true
ROLLED = nil            -- { id, type } - or nil if RollOnLoot was never called
DEFERRED = nil          -- the callback ValuateAfter was handed, so the retry can be driven

GetLootRollItemInfo = function(id) return nil, "Some Item", nil, nil, nil, CAN_NEED, CAN_GREED end
GetLootRollItemLink = function(id) return LINK end
GetItemInfo = function(link) if CACHED then return "Some Item" end return nil end
RollOnLoot = function(id, rollType) ROLLED = { id = id, type = rollType } end
ValuateAfter = function(_, fn) DEFERRED = fn end

-- Classification is stubbed: rolltest.js already proves what counts as a recipe or a useful
-- trade good, and re-deriving it here would be a second opinion rather than a new one. What is
-- untested is what gets DONE with the three answers.
UPGRADE, RECIPE, MATERIAL = false, false, false
RECIPE_CALLS, MATERIAL_CALLS = 0, 0

Valuate.GetStatsForTooltipSetter = function() return { Agility = 10 } end
Valuate.IsUpgradeForAnyScale = function() return UPGRADE, 12.5, "Dps" end
Valuate.IsLearnableRecipe = function()
    RECIPE_CALLS = RECIPE_CALLS + 1
    return RECIPE, "Leatherworking"
end
Valuate.IsUsefulTradeGood = function()
    MATERIAL_CALLS = MATERIAL_CALLS + 1
    return MATERIAL, "Blacksmithing"
end
HEARTBEAT = nil
Valuate.MarkAutomation = function(_, _, detail) HEARTBEAT = detail end

OPTIONS = {}
Valuate.GetOptions = function() return OPTIONS end

local function fresh()
    ROLLED, DEFERRED, HEARTBEAT = nil, nil, nil
    RECIPE_CALLS, MATERIAL_CALLS = 0, 0
    UPGRADE, RECIPE, MATERIAL = false, false, false
    CAN_NEED, CAN_GREED, CACHED = true, true, true
    LINK = "|Hitem:100:0|h[Some Item]|h"
    __printed = {}
end

local NEED, GREED, PASS = 1, 2, 0

` + decide + `
` + action + `

-- ---- NEED IS ONLY ROLLED ON SOMETHING WANTED -------------------------------------------------
-- Greed on a bad guess is a shrug. Need on one costs someone else the item and costs you the
-- reputation, and the game offers no way back from either.
OPTIONS = { autoRollLoot = true }

fresh()
UPGRADE = true
Valuate:AutoRollOnLoot(7)
eq(ROLLED and ROLLED.type, NEED, "an upgrade is rolled Need")
eq(ROLLED and ROLLED.id, 7, "on the roll it was asked about")

fresh()
Valuate:AutoRollOnLoot(7)
eq(ROLLED and ROLLED.type, GREED, "something that is not an upgrade is rolled GREED, never Need")

fresh()
RECIPE = true
Valuate:AutoRollOnLoot(7)
eq(ROLLED and ROLLED.type, NEED, "an unlearned recipe for one of your professions is Need")

fresh()
MATERIAL = true
Valuate:AutoRollOnLoot(7)
eq(ROLLED and ROLLED.type, NEED, "so is a material a profession of yours consumes")

-- ---- ...AND ONLY WHEN NEED IS ACTUALLY OFFERED --------------------------------------------------
-- Need is frequently not offered for something you cannot use yet - a recipe above your skill
-- is exactly that - and Greed still wins it. Both halves of wants and canNeed matter.
fresh()
UPGRADE, CAN_NEED = true, false
Valuate:AutoRollOnLoot(7)
eq(ROLLED and ROLLED.type, GREED, "wanting something Need is not offered on falls back to Greed")

fresh()
UPGRADE, CAN_NEED, CAN_GREED = true, false, false
Valuate:AutoRollOnLoot(7)
eq(ROLLED and ROLLED.type, PASS, "and with neither on offer it passes rather than doing nothing")

-- It ALWAYS answers the roll. A roll left unanswered expires, which loses you the item by
-- inaction and looks exactly like the addon being switched off.
fresh()
CAN_NEED, CAN_GREED = false, false
Valuate:AutoRollOnLoot(7)
ok(ROLLED ~= nil, "even a pass is an answer, rather than letting the roll expire")

-- ---- AN UNCACHED ITEM RETRIES EXACTLY ONCE -------------------------------------------------------
-- Item data may not have arrived, which makes the stat parse unreliable. Rolls expire, so there
-- is one grace period and no more: without the isRetry guard an item the client never caches
-- would defer forever and the roll would be lost.
fresh()
CACHED = false
Valuate:AutoRollOnLoot(7)
eq(ROLLED, nil, "an uncached item does not roll on the first pass")
ok(DEFERRED ~= nil, "it schedules one retry")

-- Drive the retry. Still uncached - the client may simply never answer - and it must roll
-- anyway rather than deferring again.
local retry = DEFERRED
DEFERRED = nil
retry()
ok(ROLLED ~= nil, "the retry rolls even if the item is still uncached")
eq(DEFERRED, nil, "and schedules no further retry, because rolls expire")

-- Cached from the start: no delay at all.
fresh()
Valuate:AutoRollOnLoot(7)
eq(DEFERRED, nil, "a cached item is not deferred")
ok(ROLLED ~= nil, "and is rolled immediately")

-- ---- THE FEATURE SWITCH, AND A CLIENT THAT CANNOT ROLL ---------------------------------------------
fresh()
OPTIONS = { autoRollLoot = false }
Valuate:AutoRollOnLoot(7)
eq(ROLLED, nil, "switched off, it never rolls")

fresh()
OPTIONS = { autoRollLoot = true }
Valuate:AutoRollOnLoot(nil)
eq(ROLLED, nil, "and a missing roll id is not rolled on")

-- Switched ON and unable to work is the case worth recording: without it the feature sits at
-- "not yet this session" forever on a client with no roll API, which is indistinguishable from
-- one where you have simply not been in a group.
fresh()
local realRoll = RollOnLoot
RollOnLoot = nil
Valuate:AutoRollOnLoot(7)
ok(HEARTBEAT ~= nil and HEARTBEAT:find("no loot%-roll API") ~= nil,
   "a client with no roll API records why it cannot work, rather than looking idle")
RollOnLoot = realRoll

-- ---- THE TWO CLASSIFICATION SWITCHES ------------------------------------------------------------------
-- Both default ON, so ~= false rather than a truthiness test: an unset option must not switch
-- the behaviour off.
fresh()
OPTIONS = { autoRollLoot = true }
Valuate:AutoRollOnLoot(7)
eq(RECIPE_CALLS, 1, "the recipe check runs when its option has never been set")
eq(MATERIAL_CALLS, 1, "and so does the trade-good check")

fresh()
OPTIONS = { autoRollLoot = true, autoRollRecipes = false }
Valuate:AutoRollOnLoot(7)
eq(RECIPE_CALLS, 0, "turning the recipe option off skips that check")

fresh()
OPTIONS = { autoRollLoot = true, autoRollTradeGoods = false }
Valuate:AutoRollOnLoot(7)
eq(MATERIAL_CALLS, 0, "and turning off trade goods skips that one")

-- A recipe is not also asked about as a material. Both use the same private tooltip and the
-- second call repoints it, so asking twice is not merely wasteful - it is a different answer
-- about a different thing.
fresh()
OPTIONS = { autoRollLoot = true }
RECIPE = true
Valuate:AutoRollOnLoot(7)
eq(MATERIAL_CALLS, 0, "something already identified as a recipe is not re-asked as a material")

-- ---- IT SAYS WHY ----------------------------------------------------------------------------------------
-- A Greed on a learnable recipe looks like the feature failing, unless it says Need was not
-- offered. That distinction is the whole reason the line exists.
fresh()
OPTIONS = { autoRollLoot = true, chatMessages = true }
RECIPE, CAN_NEED = true, false
Valuate:AutoRollOnLoot(7)
local said = table.concat(__printed, "\\n")
ok(said:find("recipe", 1, true) ~= nil, "the reason names what it thought the item was")
ok(said:find("Need not offered", 1, true) ~= nil,
   "and says Need was unavailable, so a Greed does not read as a failure")

fresh()
OPTIONS = { autoRollLoot = true, chatMessages = true }
UPGRADE = true
Valuate:AutoRollOnLoot(7)
said = table.concat(__printed, "\\n")
ok(said:find("upgrade", 1, true) ~= nil, "an upgrade says so")
ok(said:find("Dps", 1, true) ~= nil, "and which scale wanted it")

return failures, checks
`,
  "rollaction",
  "the loot roll action"
);
