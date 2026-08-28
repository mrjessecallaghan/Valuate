#!/usr/bin/env node
/*
 * @gate Auto-roll never Needs what it does not want, and never Passes for free
 *
 * Runs the REAL source of DecideRollType from Valuate.lua, over its entire input space.
 *
 * This decision is taken automatically, in a group, on your behalf, and other people see the
 * result. Two properties carry all the weight:
 *
 *   * NEVER Need on something we do not want. Needing on gear you cannot use is the thing
 *     people get removed from groups for, and nobody asked you before it happened.
 *   * NEVER Pass when Greed is available. Passing costs you the item and gains nobody
 *     anything; if the addon is going to act by itself, the floor is "no worse than Greed".
 *
 * Three booleans is eight cases, so they are enumerated rather than sampled - the lesson
 * from the tooltip percentage, where hand-picked cases missed the branch that mattered. The
 * two properties above are then asserted over every one of the eight, so a ninth combination
 * (a fourth flag, say) cannot slip past them either.
 *
 * Usage:  node tools/rolltest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^local function DecideRollType\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `local function DecideRollType` in Valuate.lua - " +
      "it was renamed, moved or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

const NL2 = String.fromCharCode(10);
const APPEARANCE = (function () {
  const ready = lua.match(/^local function AppearanceApiReady\([\s\S]*?\r?\nend/m);
  if (!ready) { console.error("  SLICE  AppearanceApiReady is gone"); process.exit(1); }
  const parts = ["ns = ns or {}", ready[0]];
  for (const n of ["AppearanceWantedForLink","UndeclaredRollers","NotePassMessage","ForgetRollPasses","AppearanceRollChoice"]) {
    const at = lua.indexOf("function ns." + n + "(");
    if (at < 0) { console.error("  SLICE  ns." + n + " is gone - this gate would test nothing"); process.exit(1); }
    parts.push(lua.slice(at, lua.indexOf(NL2 + "end" + NL2, at) + 5));
  }
  return parts.join(String.fromCharCode(10));
})();

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
ns = ns or {}
local function eq(got, want, what)
    checks = checks + 1
    if got ~= want then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end

` + m[0] + `
` + APPEARANCE + `

local NEED, GREED, PASS = 1, 2, 0
local function label(b) return b and "yes" or "no" end

-- ---- the whole input space -------------------------------------------------
local cases = {}
for _, wants in ipairs({ true, false }) do
    for _, canNeed in ipairs({ true, false }) do
        for _, canGreed in ipairs({ true, false }) do
            cases[#cases + 1] = { wants = wants, canNeed = canNeed, canGreed = canGreed }
        end
    end
end
eq(#cases, 8, "eight combinations, all of them")

for _, c in ipairs(cases) do
    local roll, name = DecideRollType(c.wants, c.canNeed, c.canGreed)
    local where = "(want " .. label(c.wants) .. ", canNeed " .. label(c.canNeed) ..
                  ", canGreed " .. label(c.canGreed) .. ")"

    -- PROPERTY 1: Need only ever for something we want.
    if roll == NEED then
        ok(c.wants, "never Needs something it does not want " .. where)
        ok(c.canNeed, "never Needs when Need is not on offer " .. where)
    end

    -- PROPERTY 2: Pass only when there is genuinely nothing better.
    if roll == PASS then
        ok(not c.canGreed, "never Passes while Greed is available " .. where)
        ok(not (c.wants and c.canNeed), "never Passes something it wants and could Need " .. where)
    end

    -- The label always matches the number it was returned with; the chat line prints one
    -- and RollOnLoot gets the other, so disagreement would be a message that lies.
    local expected = (roll == NEED and "Need") or (roll == GREED and "Greed") or "Pass"
    eq(name, expected, "the printed label matches the roll actually made " .. where)

    -- And it always decides something.
    ok(roll == NEED or roll == GREED or roll == PASS, "always returns a real roll type " .. where)
end

-- ---- the specific answers, spelled out ---------------------------------------
-- The properties above would still hold if it Greeded everything, so the actual behaviour
-- is pinned too.
eq(select(1, DecideRollType(true, true, true)), NEED, "wanted and Need offered: Need")
eq(select(1, DecideRollType(true, true, false)), NEED, "Need offered without Greed: still Need")
eq(select(1, DecideRollType(true, false, true)), GREED,
   "wanted but Need not offered - a recipe above your skill - takes Greed")
eq(select(1, DecideRollType(true, false, false)), PASS, "wanted but nothing offered: Pass")
eq(select(1, DecideRollType(false, true, true)), GREED, "not wanted, Need offered anyway: Greed")
eq(select(1, DecideRollType(false, true, false)), PASS, "not wanted and only Need offered: Pass, not Need")
eq(select(1, DecideRollType(false, false, true)), GREED, "not wanted: Greed")
eq(select(1, DecideRollType(false, false, false)), PASS, "nothing offered at all: Pass")

-- ---- nil is not true ------------------------------------------------------------
-- GetLootRollItemInfo returns these flags straight from the client, and a nil canNeed must
-- behave as "not offered" rather than sneaking through a truthiness check.
eq(select(1, DecideRollType(true, nil, true)), GREED, "a nil canNeed is not an offer")
eq(select(1, DecideRollType(true, nil, nil)), PASS, "nil everywhere: Pass")
eq(select(1, DecideRollType(nil, true, true)), GREED, "a nil want is not a want")

-- ---- rolling for an APPEARANCE ------------------------------------------------------------------
--
-- An item can be worth having for its LOOK when it is worth nothing for its stats. Greed is the
-- polite roll for that, and Greed loses to anybody who Needs - so an appearance you may never see
-- again goes to somebody who wanted the stats.
--
-- Need is fair when nobody else wants it, and the question is how you know. 3.3.5 announces a
-- PASS the moment it happens; it does NOT announce a Need or a Greed until the roll RESOLVES, by
-- which point your own roll was cast long ago. So "everyone greeded" cannot be known in time and
-- the feature does not pretend otherwise. "Everyone else passed" can be.
--
-- THE ASYMMETRY IS THE DESIGN. Every uncertain answer is Greed. Greeding something nobody wanted
-- loses you a transmog; Needing something somebody did is a thing you cannot take back and other
-- people remember.
local NEED, GREED = 1, 2

eq(ns.AppearanceRollChoice({ enabled = false, appearanceWanted = true, canNeed = true }), nil,
   "switched off, it does not touch the roll")
eq(ns.AppearanceRollChoice({ enabled = true, isUpgrade = true, appearanceWanted = true, canNeed = true }), nil,
   "an item wanted for its STATS is left to the ordinary roller")
eq(ns.AppearanceRollChoice({ enabled = true, appearanceWanted = false, canNeed = true }), nil,
   "an appearance you already have is not its business")

-- THE ONE THAT MATTERS. Undeclared is not "does not want it": Needing here takes an item from
-- somebody who may have been about to Need it themselves.
eq(ns.AppearanceRollChoice({
    enabled = true, appearanceWanted = true, canNeed = true, groupSize = 5, othersUndeclared = 1 }), GREED,
   "one player still to declare means GREED, not Need")
eq(ns.AppearanceRollChoice({
    enabled = true, appearanceWanted = true, canNeed = true, groupSize = 5, othersUndeclared = 4 }), GREED,
   "and so does a whole group that has said nothing")

eq(ns.AppearanceRollChoice({
    enabled = true, appearanceWanted = true, canNeed = true, groupSize = 5, othersUndeclared = 0 }), NEED,
   "with every other player passed, Need is free")
eq(ns.AppearanceRollChoice({
    enabled = true, appearanceWanted = true, canNeed = true, groupSize = 1, othersUndeclared = 0 }), NEED,
   "solo, the question does not arise")
eq(ns.AppearanceRollChoice({
    enabled = true, appearanceWanted = true, canNeed = false, groupSize = 1 }), GREED,
   "with Need not on offer it greeds, whatever else is true")

-- ---- counting who has not declared ---------------------------------------------------------------
PARTY, RAID = 0, 0
GetNumPartyMembers = function() return PARTY end
GetNumRaidMembers = function() return RAID end
ns.rollPasses = {}

local un, size = ns.UndeclaredRollers(1, ns.rollPasses)
eq(size, 1, "alone, the group is one")
eq(un, 0, "and there is nobody left to declare")

PARTY = 4
un, size = ns.UndeclaredRollers(1, ns.rollPasses)
eq(size, 5, "a party of four plus you is five")
eq(un, 4, "and with nobody passed yet, all four are undeclared")

ns.rollPasses[1] = { Ana = true, Bo = true }
eq(ns.UndeclaredRollers(1, ns.rollPasses), 2, "two passes leave two undeclared")
ns.rollPasses[1].Cy, ns.rollPasses[1].Di = true, true
eq(ns.UndeclaredRollers(1, ns.rollPasses), 0, "and when every other player has passed, none are")
eq(ns.UndeclaredRollers(2, ns.rollPasses), 4, "a DIFFERENT roll starts with everyone undeclared")

PARTY, RAID = 0, 10
un, size = ns.UndeclaredRollers(3, ns.rollPasses)
eq(size, 10, "in a raid the size comes from the raid count")
eq(un, 9, "with everyone else undeclared")
PARTY, RAID = 0, 0

-- ---- the pass message ------------------------------------------------------------------------------
LOOT_ROLL_PASSED = "%s passed on: %s"
ns.rollPasses = {}
eq(ns.NotePassMessage("Ana passed on: [Hat]", 9), "Ana", "a pass line is recognised")
ok(ns.rollPasses[9] and ns.rollPasses[9].Ana == true, "and recorded against that roll")
eq(ns.NotePassMessage("Ana rolled Need on: [Hat]", 9), nil, "a line that is not a pass is ignored")
eq(ns.NotePassMessage(nil, 9), nil, "and so is no line at all")
eq(ns.NotePassMessage("Ana passed on: [Hat]", nil), nil, "a pass with no roll id is not recorded")
ns.ForgetRollPasses(9)
eq(ns.rollPasses[9], nil, "a finished roll forgets who passed, because roll ids are reused")

-- ---- is the appearance actually wanted -----------------------------------------------------------------
-- Only an explicit "no, not collected" counts. An errored pcall hands back the error STRING,
-- which is truthy, and nil means the client did not say - and this decides whether to take an
-- item off somebody.
GetItemIdFromLink = function(link) return link and 42 or nil end
C_Appearance = { GetItemAppearanceID = function() return 7 end }
C_AppearanceCollection = {
    IsAppearanceCollected = function() return false end,
    CollectItemAppearance = function() end,
}
GetContainerItemGUID = function() return "guid" end

eq(ns.AppearanceWantedForLink("|Hitem:42|h[Hat]|h"), true, "an uncollected appearance is wanted")
eq(ns.AppearanceWantedForLink(nil), false, "no item is not wanted")

C_AppearanceCollection.IsAppearanceCollected = function() return true end
eq(ns.AppearanceWantedForLink("|Hitem:42|h[Hat]|h"), false, "one you already have is not")

C_AppearanceCollection.IsAppearanceCollected = function() return nil end
eq(ns.AppearanceWantedForLink("|Hitem:42|h[Hat]|h"), false,
   "a collected-state of NIL is not an answer, so it is not wanted")

C_AppearanceCollection.IsAppearanceCollected = function() error("no") end
eq(ns.AppearanceWantedForLink("|Hitem:42|h[Hat]|h"), false,
   "and a check that ERRORS never turns Greed into Need")

C_AppearanceCollection.IsAppearanceCollected = function() return false end
C_Appearance.GetItemAppearanceID = function() error("no") end
eq(ns.AppearanceWantedForLink("|Hitem:42|h[Hat]|h"), false, "nor does an unreadable appearance id")

C_Appearance.GetItemAppearanceID = function() return 7 end
eq(ns.AppearanceWantedForLink("|Hitem:42|h[Hat]|h"), true, "and a clear answer still comes through")

return failures, checks
`,
  "rolltest",
  "the auto-roll decision"
);
