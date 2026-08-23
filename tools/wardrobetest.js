#!/usr/bin/env node
/*
 * @gate Wardrobe collecting acts only on what it positively knows
 *
 * The wardrobe API is Ascension's, not Blizzard's. It was read out of PastLoot rather than
 * guessed at, but I have never run it - and an hour before this was written, a font object
 * built against an API surface nobody confirmed stopped the whole UI opening. So the rule
 * here is that every uncertain answer means DO NOTHING.
 *
 * What that has to mean concretely, and what this gate pins down:
 *
 *   - No wardrobe API at all -> return a reason, never an error. Most clients are not this
 *     one.
 *   - IsAppearanceCollected errors or returns nil -> the appearance is NOT treated as
 *     uncollected. "I could not find out" and "you do not have it" are different answers,
 *     and only one of them justifies acting.
 *   - Two items sharing an appearance -> collected once. IsAppearanceCollected will not have
 *     caught up within a single pass, so the naive version collects the second redundantly.
 *   - The slot changed since the list was built -> skip it. Same re-verify-before-acting rule
 *     the delete and sell paths follow.
 *   - The automatic pass does nothing while the option is off, which is its default.
 *
 * Usage:  node tools/wardrobetest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

// Constants before the functions that close over them.
const pieces = [
  /^local APPEARANCE_THROTTLE = \d+/m,
  /^local lastAppearancePass = \d+/m,
  /^local function AppearanceApiReady\(\)[\s\S]*?\r?\nend/m,
  /^function Valuate:GetUncollectedAppearances\([\s\S]*?\r?\nend/m,
  /^function Valuate:LearnUncollectedAppearances\([\s\S]*?\r?\nend/m,
  /^function Valuate:AutoLearnAppearances\([\s\S]*?\r?\nend/m,
];
const sliced = [];
for (const re of pieces) {
  const m = core.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  sliced.push(m[0]);
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
local OPTIONS = { autoLearnAppearances = false }
function Valuate:GetOptions() return OPTIONS end
local marks = {}
function Valuate:MarkAutomation(key, outcome) marks[key] = outcome end

-- ---- a mock bag, and the Ascension wardrobe API -----------------------------------
local BAGS = {}          -- [bag][slot] = { link, id, guid }
local COLLECTED = {}     -- [appearanceId] = true
local APPEARANCE = {}    -- [itemId] = appearanceId
local collectCalls = {}
local failIsCollected = false

function GetContainerNumSlots(bag) return BAGS[bag] and #BAGS[bag] or 0 end
function GetContainerItemLink(bag, slot)
    local e = BAGS[bag] and BAGS[bag][slot]
    return e and e.link or nil
end
function GetContainerItemGUID(bag, slot)
    local e = BAGS[bag] and BAGS[bag][slot]
    return e and e.guid or nil
end

C_Appearance = {
    GetItemAppearanceID = function(itemId) return APPEARANCE[itemId] end,
}
C_AppearanceCollection = {
    IsAppearanceCollected = function(id)
        if failIsCollected then error("server said no") end
        return COLLECTED[id] == true
    end,
    CollectItemAppearance = function(guid)
        table.insert(collectCalls, guid)
        return true
    end,
}

local __now = 1000
function GetTime() return __now end

local function item(id, guid) return { link = "|Hitem:" .. id .. ":0|h[Item " .. id .. "]|h", id = id, guid = guid } end

local function reset()
    BAGS = { [0] = { item(100, "g100"), item(200, "g200") } }
    COLLECTED = { [55] = true }
    APPEARANCE = { [100] = 11, [200] = 55 }
    collectCalls = {}
    failIsCollected = false
    marks = {}
end
reset()

` + sliced.join("\n") + `

-- ---- the ordinary case ---------------------------------------------------------------
local pending = Valuate:GetUncollectedAppearances()
eq(pending and #pending, 1, "one uncollected appearance found")
eq(pending and pending[1].itemId, 100, "and it is the item whose look is not collected")
eq(#collectCalls, 0, "listing them collects nothing")

local collected = Valuate:LearnUncollectedAppearances()
eq(collected, 1, "collecting takes the one item")
eq(collectCalls[1], "g100", "by its GUID, not its bag slot")

-- ---- an appearance you already have is left alone ------------------------------------
reset()
COLLECTED = { [11] = true, [55] = true }
eq(#Valuate:GetUncollectedAppearances(), 0, "nothing to do when you have them all")
local none, whyNone = Valuate:LearnUncollectedAppearances()
eq(none, 0, "and collecting takes nothing")
ok(type(whyNone) == "string" and whyNone ~= "", "saying so in words: " .. tostring(whyNone))

-- ---- two items, one appearance -------------------------------------------------------
-- IsAppearanceCollected cannot catch up inside a single pass, so without a dedupe the
-- second item is collected redundantly.
reset()
APPEARANCE = { [100] = 11, [200] = 11 }
COLLECTED = {}
eq(#Valuate:GetUncollectedAppearances(), 1, "two items sharing one appearance count once")
eq(Valuate:LearnUncollectedAppearances(), 1, "and are collected once")
eq(#collectCalls, 1, "one call, not two")

-- ---- an answer we did not get is not an answer ----------------------------------------
reset()
COLLECTED = {}
failIsCollected = true
local unknown = Valuate:GetUncollectedAppearances()
eq(unknown and #unknown, 0,
    "an errored IsAppearanceCollected leaves the item alone rather than assuming uncollected")
eq(#collectCalls, 0, "so nothing is collected on an answer that never arrived")

-- ---- nil is not "no" ---------------------------------------------------------------------
-- Likelier than an error, and the case the errored test above does NOT cover: the API answers,
-- but with nothing. A mutation that treated a falsy result as "uncollected" survived until
-- this existed, because an errored pcall hands back the error STRING, which is truthy.
reset()
COLLECTED = {}
local savedIs = C_AppearanceCollection.IsAppearanceCollected
C_AppearanceCollection.IsAppearanceCollected = function() return nil end
local nilAnswer = Valuate:GetUncollectedAppearances()
eq(#nilAnswer, 0, "an appearance whose collected-state is nil is left alone")
eq(Valuate:LearnUncollectedAppearances(), 0, "and nothing is collected on a nil answer")
eq(#collectCalls, 0, "not one call")
C_AppearanceCollection.IsAppearanceCollected = savedIs

-- ---- an appearance ID we did not get is not an ID ------------------------------------------
--
-- The other half of the same rule, and the half nothing covered: GetItemAppearanceID is pcall'd
-- for the same reason IsAppearanceCollected is - this is Ascension's API and nobody here has
-- run it - but the fixture never made it fail, so the guard on its result was never exercised.
--
-- It matters more than the collected-check guard, and in the opposite direction. An errored
-- pcall hands back the error STRING, which is truthy: collected == false rejects that on its
-- own, but if appearanceId then would happily accept it and go on to use an error message as
-- an appearance id - looking it up, deduping on it, and collecting against it.
reset()
COLLECTED = {}
local savedGet = C_Appearance.GetItemAppearanceID
C_Appearance.GetItemAppearanceID = function() error("no such appearance") end
local noId = Valuate:GetUncollectedAppearances()
eq(noId and #noId, 0, "an errored appearance-id read leaves the item alone")
eq(Valuate:LearnUncollectedAppearances(), 0, "and collects nothing")
eq(#collectCalls, 0, "not one call against an id that is really an error message")
C_Appearance.GetItemAppearanceID = savedGet

-- The pair, so "always nothing" cannot pass: with the read working again it must still find it.
reset()
COLLECTED = {}
local works = Valuate:GetUncollectedAppearances()
ok(works and #works > 0, "and a working appearance-id read still finds uncollected items")

-- ---- no wardrobe API at all ------------------------------------------------------------
reset()
local savedAppearance = C_Appearance
C_Appearance = nil
local absent, whyAbsent = Valuate:GetUncollectedAppearances()
eq(absent, nil, "a client with no wardrobe API returns nothing")
ok(type(whyAbsent) == "string" and whyAbsent ~= "", "with a reason: " .. tostring(whyAbsent))
eq(Valuate:LearnUncollectedAppearances(), 0, "and collecting is a no-op rather than an error")
C_Appearance = savedAppearance

-- ---- the slot changed under us ----------------------------------------------------------
reset()
COLLECTED = {}
-- The list is captured FIRST, then the bag changes, then the stale list is handed back -
-- which is the only way the re-verify can matter. Called with no list, this function scans
-- and acts in one breath and nothing can move in between.
local stale = Valuate:GetUncollectedAppearances()
ok(#stale >= 1, "something was pending")
for i = 1, #BAGS[0] do BAGS[0][i] = item(999, "g999") end   -- everything moved
local moved, whyMoved = Valuate:LearnUncollectedAppearances(stale)
eq(moved, 0, "an item that moved since the list was built is not collected")
ok(type(whyMoved) == "string", "and that is reported rather than silent: " .. tostring(whyMoved))

-- A partially-stale list still collects the part that is still there.
reset()
COLLECTED = {}
local twoPending = Valuate:GetUncollectedAppearances()
eq(#twoPending, 2, "two items pending")
BAGS[0][2] = item(999, "g999")   -- only the second moved
eq(Valuate:LearnUncollectedAppearances(twoPending), 1,
    "the item still in place is collected, the one that moved is skipped")

-- ---- the automatic pass ------------------------------------------------------------------
reset()
COLLECTED = {}
OPTIONS.autoLearnAppearances = false
Valuate:AutoLearnAppearances()
eq(#collectCalls, 0, "the automatic pass does nothing while the option is off")
eq(marks.wardrobe, nil, "and records no heartbeat, because it never ran")

OPTIONS.autoLearnAppearances = true
Valuate:AutoLearnAppearances()
eq(#collectCalls, 2, "switched on, it collects both uncollected items")
ok(marks.wardrobe ~= nil, "and records what it concluded: " .. tostring(marks.wardrobe))

-- Throttled. The clock is ours, so this tests the throttle rather than whatever GetTime
-- happens to return.
reset()
COLLECTED = {}
OPTIONS.autoLearnAppearances = true
Valuate:AutoLearnAppearances()
eq(#collectCalls, 0, "a second pass within the throttle window does nothing")

__now = __now + 6
reset()
COLLECTED = {}
OPTIONS.autoLearnAppearances = true
Valuate:AutoLearnAppearances()
eq(#collectCalls, 2, "once the window passes it runs again")

-- A clock that went backwards (a /reload resets GetTime) must not pin it shut forever.
__now = 1
reset()
COLLECTED = {}
OPTIONS.autoLearnAppearances = true
Valuate:AutoLearnAppearances()
eq(#collectCalls, 2, "a backwards clock does not lock the pass out")

return failures, checks
`,
  "wardrobetest",
  "wardrobe collecting"
);
