#!/usr/bin/env node
/*
 * @gate The to-do list is short, ordered by what unblocks what, and empty when it should be
 *
 * Runs the real Valuate:BuildTodoList against mocked sources.
 *
 * This composes four subsystems that are each gate-tested on their own, so what is left to
 * get wrong is the composition - and all three ways are the kind that make a list useless
 * rather than broken:
 *
 *   WRONG ORDER. A stale scale has to come first, because everything under it is scored BY
 *   that scale. Put upgrades on top and the list confidently tells you to equip things
 *   chosen by weights you have outgrown.
 *
 *   TOO LONG. Seventeen slots' worth of upgrades is the Best Equipment panel, not an answer
 *   to "what should I do next".
 *
 *   NEVER EMPTY. A to-do list that always has something in it is one you stop opening. When
 *   there is nothing to do it must say nothing, not print a heading over an empty space.
 *
 * Usage:  node tools/todotest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const m = lua.match(/^function Valuate:BuildTodoList\([\s\S]*?\r?\nend/m);
if (!m) {
  console.error("  SLICE  could not find Valuate:BuildTodoList in Valuate.lua - this gate tests nothing");
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

Valuate = {}

local DRIFT, UPGRADES, SOCKETS, ENCHANTS = nil, nil, 0, 0
function Valuate:GetAutoScaleDrift() return DRIFT end
function Valuate:GetPrimaryScale() return {}, "Dps" end
function Valuate:RankAvailableUpgrades() return UPGRADES end
function Valuate:FindEmptySockets() return nil, SOCKETS end
function Valuate:FindMissingEnchants() return nil, ENCHANTS end

` + m[0] + `

local function kinds(items)
    local out = {}
    for _, i in ipairs(items or {}) do out[#out + 1] = i.kind end
    return table.concat(out, ",")
end

-- ---- nothing to do -----------------------------------------------------------
eq(#Valuate:BuildTodoList(), 0, "with nothing to act on the list is EMPTY")

-- ---- each source contributes independently -----------------------------------
DRIFT = "Auto - Str/Crit"
eq(kinds(Valuate:BuildTodoList()), "scale", "a stale scale alone is one item")
DRIFT = nil

SOCKETS = 3
eq(kinds(Valuate:BuildTodoList()), "sockets", "empty sockets alone is one item")
local socketItem = Valuate:BuildTodoList()[1]
ok(socketItem.text:find("3", 1, true) ~= nil, "and it reports how many")
SOCKETS = 0

ENCHANTS = 2
eq(kinds(Valuate:BuildTodoList()), "enchants", "missing enchants alone is one item")
ENCHANTS = 0

-- Zero must never produce a line. "Fill 0 empty sockets" is the failure that makes a list
-- always non-empty and therefore never read.
SOCKETS, ENCHANTS = 0, 0
eq(#Valuate:BuildTodoList(), 0, "a count of zero produces no line at all")

-- ---- the order IS the argument -----------------------------------------------
-- A stale scale first, because the upgrades below it are chosen BY that scale.
DRIFT = "Auto - Str/Crit"
UPGRADES = { { itemLink = "[Chest]", slotName = "Chest", gain = 40 } }
SOCKETS, ENCHANTS = 2, 1
eq(kinds(Valuate:BuildTodoList()), "scale,upgrade,sockets,enchants",
   "stale scale, then upgrades, then sockets, then enchants")

local first = Valuate:BuildTodoList()[1]
ok(first.detail and first.detail:find("scored by this scale", 1, true) ~= nil,
   "and the scale item says WHY it is first, rather than just being first")

-- ---- three upgrades, not seventeen -------------------------------------------
DRIFT = nil
SOCKETS, ENCHANTS = 0, 0
UPGRADES = {}
for i = 1, 17 do
    UPGRADES[i] = { itemLink = "[Item " .. i .. "]", slotName = "Slot " .. i, gain = 100 - i }
end
local many = Valuate:BuildTodoList()
eq(#many, 3, "at most three upgrades - this is a to-do list, not the whole panel")
ok(many[1].text:find("Item 1", 1, true) ~= nil, "and they are the BIGGEST three, in order")
ok(many[3].text:find("Item 3", 1, true) ~= nil, "third is the third biggest")

-- Fewer than three is fine; it must not pad.
UPGRADES = { { itemLink = "[Only]", slotName = "Chest", gain = 5 } }
eq(#Valuate:BuildTodoList(), 1, "one upgrade produces one item, not three")

-- An empty slot is called out, because the whole score being the gain makes it rank high
-- for a reason that is not "this item is remarkable".
UPGRADES = { { itemLink = "[Neck]", slotName = "Neck", gain = 30, emptySlot = true } }
local emptySlotItem = Valuate:BuildTodoList()[1]
ok(emptySlotItem.detail and emptySlotItem.detail:find("empty", 1, true) ~= nil,
   "an empty slot says so")

UPGRADES = { { itemLink = "[Neck]", slotName = "Neck", gain = 30, emptySlot = false } }
eq(Valuate:BuildTodoList()[1].detail, nil, "a slot you have something in does not")

-- ---- every item can be acted on ----------------------------------------------
DRIFT = "Auto - Str/Crit"
SOCKETS, ENCHANTS = 1, 1
for _, item in ipairs(Valuate:BuildTodoList()) do
    ok(type(item.text) == "string" and item.text ~= "", "every item says what to do: " .. item.kind)
    ok(type(item.command) == "string" and item.command:find("/valuate", 1, true) == 1,
       "and where to go for detail: " .. item.kind)
end

-- ---- a client missing the newer helpers still produces a list -----------------
-- These arrived across four separate releases; an older core without them must degrade to a
-- shorter list rather than erroring out of the command entirely.
Valuate.FindEmptySockets = nil
Valuate.FindMissingEnchants = nil
Valuate.GetAutoScaleDrift = nil
local degraded
ok(pcall(function() degraded = Valuate:BuildTodoList() end),
   "missing helpers are handled rather than crashing")
eq(kinds(degraded), "upgrade", "and what remains still reports")

return failures, checks
`,
  "todotest",
  "the gear to-do list"
);
