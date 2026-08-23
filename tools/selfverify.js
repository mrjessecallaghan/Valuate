#!/usr/bin/env node
/*
 * @gate Self-verify tells the truth about what it could and could not test
 *
 * Runs the real self-check bodies against a mocked client.
 *
 * These are the only checks that will ever produce evidence from inside the game, so a
 * wrong verdict here is worse than no verdict: it is a green line about a subsystem that
 * is broken. Three distinctions carry all the risk, and all three look identical to a
 * careless implementation -
 *
 *   PASS   the client agreed with what the addon assumed
 *   FAIL   it did not
 *   SKIP   the situation was never present to test
 *
 * SKIP collapsing into PASS is the dangerous direction. "No item you own carries Mastery"
 * would then read as "Mastery parsing works", which is the exact assumption that has gone
 * untested since v0.72.0a - the wording of those tooltip lines was GUESSED.
 *
 * Usage:  node tools/selfverify.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local equipmentSwapPending = false/m,
  /^local SELF_VERIFY_MIN_HITS = \d+/m,
  /^local NEW_SECONDARIES = \{[^\r\n]*\}/m,
  /^local function SelfCheckTemplateSet\([\s\S]*?\r?\nend/m,
  /^local function SelfCheckNewSecondaries\([\s\S]*?\r?\nend/m,
  /^local function SelfCheckCaches\([\s\S]*?\r?\nend/m,
  /^local SCORE_AGREEMENT_TOLERANCE = [\d.]+/m,
  /^local function SelfCheckScoreAgreement\([\s\S]*?\r?\nend/m,
  /^local QUEUE_AUTOMATION_NEEDS = \{[\s\S]*?\r?\n\}/m,
  /^local function SelfCheckAutomationsCanRun\([\s\S]*?\r?\nend/m,
  /^local function SelfCheckDungeonItems\([\s\S]*?\r?\nend/m,
  /^local function SelfCheckDungeonKeys\([\s\S]*?\r?\nend/m,
  // These two live on `ns` rather than as file locals: Valuate.lua sits at the
  // top-level-local budget, so the newest checks had to go somewhere costing no slot.
  /^function ns\.SelfCheckEnhanceSources\([\s\S]*?\r?\nend/m,
  /^function ns\.SelfCheckUILayout\([\s\S]*?\r?\nend/m,
  /^local SELF_CHECKS = \{[\s\S]*?\r?\n\}/m,
  /^function Valuate:RunSelfVerify\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
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
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- ---- the mocked client -------------------------------------------------------
local CLASS = "Warrior"
function UnitClass() return CLASS end

local TEMPLATES, SET_NAME = { { class = "Warrior" } }, "classic"
function Valuate:GetTemplateSet() return TEMPLATES, SET_NAME end

local CACHE = { activeHit = 0, activeBuild = 0, slotHit = 0, slotMiss = 0 }
function Valuate:GetCacheStats() return CACHE end

local OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end

-- A tooltip is a list of text lines plus whatever the parser makes of them. Keeping those
-- two independent is the point: the check exists to notice when the text says "Mastery" and
-- the parse does not.
local LINES, PARSED = {}, {}
local TIP = {}
function TIP:ClearLines() end
function TIP:NumLines() return #LINES + 1 end
function TIP:SetInventoryItem() end
function TIP:SetBagItem() end
function Valuate:GetPrivateTooltip() return TIP end
function Valuate:ParseStatsFromTooltip() return PARSED end
function getglobal(name)
    local i = tonumber(name:match("TextLeft(%d+)$"))
    if not i or not LINES[i - 1] then return nil end
    return { GetText = function() return LINES[i - 1] end }
end

-- The two scoring routes, kept independent on purpose: the check exists to notice when they
-- disagree, so a mock that computes both from one number would test nothing.
ns = {}
-- Defined up here, before the first RunSelfVerify call. A recorder installed later would
-- miss every pass that happened before it existed - and the assertions below would then be
-- about an empty list rather than about what the checks actually recorded.
SELF_TICKS = {}
ns.SetSelfVerified = function(id) SELF_TICKS[#SELF_TICKS + 1] = id end
ns.EQUIP_SLOTS = { { slotId = 5, name = "Chest" }, { slotId = 7, name = "Legs" } }
local PRIMARY = { DisplayName = "Dps", Values = { Strength = 1.0 } }
function Valuate:GetPrimaryScale() return PRIMARY, "Dps" end
function Valuate:IsItemExcludedFromEvaluation() return false end

local VIA_SLOT, VIA_LINK, LINK_SCALED = {}, {}, {}
function Valuate:GetEquippedItemScoreBySlotId(slotId) return VIA_SLOT[slotId] or 0 end
function Valuate:GetScaledStatsForItem(link)
    local slotId = tonumber(link:match("slot(%d+)"))
    if LINK_SCALED[slotId] == false then return { base = true }, false end
    return { slotId = slotId }, true
end
function Valuate:CalculateItemScore(stats) return VIA_LINK[stats.slotId] or 0 end

local EQUIPPED, BAGS = {}, {}
function GetInventoryItemLink(_, slotId) return EQUIPPED[slotId] end
function GetContainerNumSlots(bagId) return BAGS[bagId] and 16 or 0 end
function GetContainerItemLink(bagId, slotId) return BAGS[bagId] and BAGS[bagId][slotId] end

-- The dungeon loot table and the client's view of it. ns already exists above.
local ITEMS_EXIST = {}
function GetItemInfo(id) return ITEMS_EXIST[id] and ("Item " .. id) or nil end
local INSTANCE_NAME, INSTANCE_TYPE = "Nowhere", "none"
function GetInstanceInfo() return INSTANCE_NAME, INSTANCE_TYPE end

` + sliced.join("\n") + `

local function resultFor(id)
    for _, r in ipairs(Valuate:RunSelfVerify()) do if r.id == id then return r end end
end

-- ---- the template set: the assumption all 70 CoA builds rest on --------------
eq(resultFor("templates").status, "pass", "a class present in the matched set passes")

CLASS = "Necromancer"
TEMPLATES, SET_NAME = { { class = "Necromancer" }, { class = "Starcaller" } }, "coa"
eq(resultFor("templates").status, "pass", "a CoA class matched against the CoA set passes")

-- The failure the whole feature rests on: UnitClass returns something no set contains, so
-- GetTemplateSet silently falls back and every build for the class is unreachable.
CLASS = "Necromancer"
TEMPLATES, SET_NAME = { { class = "Warrior" } }, "classic"
local fell = resultFor("templates")
eq(fell.status, "fail", "a class in NO template set is a failure, not a quiet fallback")
ok(fell.detail:find("Necromancer", 1, true) ~= nil, "and the detail names what the client actually said")

CLASS = ""
eq(resultFor("templates").status, "fail", "an empty class name fails rather than passing vacuously")
CLASS = "Warrior"
TEMPLATES, SET_NAME = { { class = "Warrior" } }, "classic"

-- ---- the guessed tooltip wording --------------------------------------------
-- Nothing owned that mentions these stats: SKIP. This must never read as PASS - it is the
-- difference between "the guess is right" and "the guess has never been tested".
LINES, PARSED = { "+40 Strength" }, { Strength = 40 }
EQUIPPED[5] = "chest"
eq(resultFor("newstats").status, "skip", "no item carrying the new stats is a SKIP, not a pass")

-- The text says Mastery and the parser agrees: the guess was right.
LINES = { "+40 Strength", "+12 Mastery Rating" }
PARSED = { Strength = 40, MasteryRating = 12 }
local good = resultFor("newstats")
eq(good.status, "pass", "text and parse agreeing is a pass")
ok(good.detail:find("12", 1, true) ~= nil, "and it reports the value it actually got")

-- The text says Mastery and the parser got nothing. This is the bug that would otherwise be
-- silent, and the entire reason this check exists.
PARSED = { Strength = 40 }
local bad = resultFor("newstats")
eq(bad.status, "fail", "text without a parsed value is a FAIL")
ok(bad.detail:find("Mastery", 1, true) ~= nil, "naming the stat that did not parse")

-- Bare wording, no "Rating" suffix - the other half of the guess.
LINES = { "+8 Leech" }
PARSED = { Leech = 8 }
eq(resultFor("newstats").status, "pass", "the bare wording is accepted too")

-- Found in BAGS as well as on your body, or a bank alt with empty slots tests nothing.
EQUIPPED[5] = nil
BAGS[0] = { [3] = "some item" }
LINES, PARSED = { "+15 Versatility" }, { Versatility = 15 }
eq(resultFor("newstats").status, "pass", "an item in your bags counts, not just what you wear")

-- Mid-swap, the honest answer is "could not look", not a verdict.
equipmentSwapPending = true
eq(resultFor("newstats").status, "skip", "an equipment swap in flight is a skip, not a fail")
equipmentSwapPending = false

-- ---- the caches --------------------------------------------------------------
CACHE = { activeHit = 0, activeBuild = 0, slotHit = 0, slotMiss = 0 }
eq(resultFor("caches").status, "skip", "nothing measured yet is a skip")

CACHE = { activeHit = 5, activeBuild = 1, slotHit = 4, slotMiss = 1 }
eq(resultFor("caches").status, "skip", "and so is too little to be meaningful")

CACHE = { activeHit = 90, activeBuild = 5, slotHit = 90, slotMiss = 5 }
eq(resultFor("caches").status, "pass", "a high hit rate over enough lookups passes")

CACHE = { activeHit = 20, activeBuild = 40, slotHit = 20, slotMiss = 40 }
local cold = resultFor("caches")
eq(cold.status, "fail", "a low hit rate fails - the optimisation is not real on this client")
ok(cold.detail:find("%%") ~= nil, "and reports the rate it measured")

-- ---- two scoring paths must agree --------------------------------------------
-- The check that would have caught v0.94.0a in the client: two pieces of code reading one
-- item's stats from different sources. No gate can see that, because a fixture hands both
-- sides the same numbers. Here they are deliberately separate.
EQUIPPED[5], EQUIPPED[7] = "slot5", "slot7"
VIA_SLOT[5], VIA_LINK[5] = 100, 100
VIA_SLOT[7], VIA_LINK[7] = 200, 200
eq(resultFor("agreement").status, "pass", "two routes landing on the same number passes")

-- A hair apart is rounding, not a bug.
VIA_LINK[7] = 200.5
eq(resultFor("agreement").status, "pass", "a quarter of a percent is tolerated as rounding")

-- Meaningfully apart is the bug, and the detail has to name the slot and both numbers so it
-- can be acted on rather than just believed.
VIA_LINK[7] = 240
local disagree = resultFor("agreement")
eq(disagree.status, "fail", "a 20% divergence between the two routes is a failure")
ok(disagree.detail:find("Legs", 1, true) ~= nil, "naming the slot it found")
ok(disagree.detail:find("200", 1, true) and disagree.detail:find("240", 1, true),
   "and both numbers, so it can be checked by hand")
VIA_LINK[7] = 200

-- An item whose second route could only get BASE stats is skipped, not compared. Comparing
-- base against scaled would report exactly the mismatch this check hunts, on an item where
-- it is expected and harmless - a false alarm that would teach you to ignore a real one.
LINK_SCALED[7] = false
VIA_LINK[7] = 999
eq(resultFor("agreement").status, "pass", "an item that only has base stats is not compared")
LINK_SCALED[7] = nil
VIA_LINK[7] = 200

EQUIPPED[5], EQUIPPED[7] = nil, nil
eq(resultFor("agreement").status, "skip", "nothing equipped is a skip, not a vacuous pass")
EQUIPPED[5] = "slot5"

PRIMARY = { DisplayName = "Dps", Values = {} }
eq(resultFor("agreement").status, "skip", "a scale with no weights has nothing to compare")
PRIMARY = { DisplayName = "Dps", Values = { Strength = 1.0 } }

equipmentSwapPending = true
eq(resultFor("agreement").status, "skip", "mid-swap is a skip - the guard is read, not relaxed")
equipmentSwapPending = false

-- ---- a toggle that is on but cannot possibly fire ----------------------------
-- /valuate queuecheck answers this, but only if you think to ask - and the moment you would
-- think to ask is after it has already failed to do something.
RepopMe = function() end
LeaveBattlefield = function() end
GetBattlefieldWinner = function() end

OPTIONS.autoRelease = nil
eq(resultFor("canrun").status, "skip", "with nothing switched on it says nothing")

OPTIONS.autoRelease = true
eq(resultFor("canrun").status, "pass", "an automation whose API exists passes")

-- The case worth catching: switched on, and the client simply cannot do it. The toggle sits
-- there looking armed and never fires, which is indistinguishable from "nothing happened yet".
RepopMe = nil
local cannot = resultFor("canrun")
eq(cannot.status, "fail", "switched on with the API missing is a failure")
ok(cannot.detail:find("RepopMe", 1, true) ~= nil, "and names the API that is missing")
ok(cannot.detail:find("Auto-release", 1, true) ~= nil, "and which feature needs it")

-- An automation you have NOT switched on must not be reported, however broken the client is.
OPTIONS.autoRelease = nil
OPTIONS.autoLeaveBattleground = true
eq(resultFor("canrun").status, "pass",
   "a missing API for a feature you are not using is not your problem")
RepopMe = function() end

-- Every API a feature needs is checked, not just the first.
OPTIONS.autoLeaveBattleground = true
LeaveBattlefield = nil
ok(resultFor("canrun").detail:find("LeaveBattlefield", 1, true) ~= nil,
   "a later API in the list is checked too, not only the first")
LeaveBattlefield = function() end
OPTIONS.autoLeaveBattleground = nil

-- ---- can this client tell me about enchants at all? --------------------------
-- The Enhance tab reads live data, so what it can show depends entirely on which apis this
-- client answers - and one of them is custom to Ascension and undocumented.
local SOURCES = {}
ns.ProbeEnhanceSources = function() return SOURCES, {} end

SOURCES = {}
eq(resultFor("enhancesrc").status, "fail",
   "a client exposing nothing at all is a failure - the tab cannot work")

-- 3.3.5 puts Enchanting behind the CRAFT api. Without it, enchants never appear however many
-- professions you open, and every other source being present does not make up for it.
SOURCES = { { key = "tradeskill", count = 40 }, { key = "spellinfo", count = 1 } }
local noCraft = resultFor("enhancesrc")
eq(noCraft.status, "fail", "no Craft api is a failure even with everything else present")
ok(noCraft.detail:find("Enchanting", 1, true) ~= nil, "and says what that costs you")

-- Zero open recipes is the NORMAL state with no window open. Calling it a failure would teach
-- people to ignore this check, which is worse than not having it at all.
SOURCES = { { key = "craft", count = 0 }, { key = "tradeskill", count = 0 } }
eq(resultFor("enhancesrc").status, "skip",
   "no profession window open is UNTESTED, not broken")

SOURCES = { { key = "craft", count = 12 }, { key = "tradeskill", count = 30 } }
local live = resultFor("enhancesrc")
eq(live.status, "pass", "an open window with readable recipes passes")
ok(live.detail:find("42", 1, true) ~= nil, "reporting how many it can actually read")

-- ---- and is anything drawn where it does not belong? -------------------------
local UI_PROBLEMS, UI_EXAMINED = nil, 0
ns.RunUICheck = function() return UI_PROBLEMS, UI_EXAMINED end

-- The window not being open is not a verdict. Crucially the check must not OPEN it either:
-- a diagnostic that changes what is on your screen in order to measure it is measuring
-- something you did not have.
UI_PROBLEMS = nil
eq(resultFor("uilayout").status, "skip", "a closed window is untested, not clean")

UI_PROBLEMS, UI_EXAMINED = 0, 340
eq(resultFor("uilayout").status, "pass", "nothing out of place passes")

UI_PROBLEMS = 3
local broken = resultFor("uilayout")
eq(broken.status, "fail", "things drawn outside their frames is a failure")
ok(broken.detail:find("uicheck", 1, true) ~= nil, "and points at the command that names them")

UI_PROBLEMS, UI_EXAMINED = 0, 340

-- ---- the shape of the report -------------------------------------------------
local all = Valuate:RunSelfVerify()
-- Counted, not merely iterated. A check dropped from the list is exactly the failure this
-- gate exists for, and "every result has a status" is true of a list with one entry in it.
eq(#all, 9, "every check reports, none silently dropped")
for _, r in ipairs(all) do
    ok(r.status == "pass" or r.status == "fail" or r.status == "skip",
       "every status is one of the three, never nil: " .. tostring(r.id))
    ok(type(r.detail) == "string" and r.detail ~= "",
       "every result explains itself: " .. tostring(r.id))
end

-- ---- a check that cannot answer at all ---------------------------------------
-- Every check above always returns a status, so the fallback for one that returns NOTHING
-- was never exercised - and a mutation making that default to "pass" survived. Defaulting a
-- silent check to pass reports all-clear for a subsystem that could not even be asked.
table.insert(SELF_CHECKS, { id = "silent", title = "a check that returns nothing", run = function() end })
local silent = resultFor("silent")
eq(silent.status, "fail", "a check that returns nothing is a FAILURE, not a pass")
ok(type(silent.detail) == "string" and silent.detail ~= "", "and still says something")
eq(#Valuate:RunSelfVerify(), 10, "and it is reported, not dropped")

-- ---- the harvested dungeon item ids -------------------------------------------
-- This check is the only thing that will ever settle whether 2,918 ids taken out of
-- AtlasLoot are real on THIS server. Its whole difficulty is that a nil from GetItemInfo
-- means both "does not exist" and "not fetched yet", and those are opposite answers.
ns.DUNGEON_LOOT = {
    ["Testmines"] = { bosses = {
        { name = "A", items = { 101, 102, 103, 104 } },
        { name = "B", items = { 105, 106, 107, 108 } },
    } },
}

-- Cold cache: nothing resolves. This must NOT read as "the table is wrong" with certainty,
-- but it must also not pass - a green line here would be a lie about untested data.
ITEMS_EXIST = {}
local cold = resultFor("dungeonids")
eq(cold.status, "fail", "not one id resolving is a failure, not a quiet pass")
ok(cold.detail:find("again", 1, true) ~= nil,
   "and it says to re-run, because asking is what caches them")

-- Everything resolves: the harvest is good for this server.
for i = 101, 108 do ITEMS_EXIST[i] = true end
local warm = resultFor("dungeonids")
eq(warm.status, "pass", "ids that all resolve is a pass")
ok(warm.detail:find("100%%") ~= nil or warm.detail:find("100", 1, true) ~= nil,
   "and it reports the rate rather than just saying 'ok'")

-- Half resolving is the ambiguous middle, and it must stay ambiguous rather than picking a
-- side. Reported as SKIP with instructions, not as pass and not as fail.
ITEMS_EXIST = { [101] = true, [102] = true, [103] = true, [104] = true }
local half = resultFor("dungeonids")
eq(half.status, "skip", "a partial rate is undecided, not a verdict")
ok(half.detail:find("again", 1, true) ~= nil, "and says how to decide it")

-- An empty table is a broken generator, and that IS a definite failure.
ns.DUNGEON_LOOT = { ["Empty"] = { bosses = { { name = "A", items = {} } } } }
local none = resultFor("dungeonids")
eq(none.status, "fail", "a table with no ids at all is a failure")
-- Same STATUS as a cold cache, deliberately different message. Asserting only the status let
-- a mutation delete this branch entirely and survive: both paths said "fail" and the gate
-- could not tell "your client has not fetched these yet" from "the generator is broken",
-- which are the two things a reader most needs told apart.
ok(none.detail:find("harvested nothing", 1, true) ~= nil,
   "and it blames the GENERATOR rather than telling you to wait for a cache that will never fill")

-- ---- the dungeon name matching --------------------------------------------------
-- The feature hangs on a string match, and a mismatch is silent BY DESIGN - so without
-- this, a wrong key looks exactly like the feature being switched off.
ns.DUNGEON_LOOT = { ["The Deadmines"] = { bosses = { { name = "A", items = { 1 } } } } }

INSTANCE_NAME, INSTANCE_TYPE = "Elwynn Forest", "none"
eq(resultFor("dungeonkey").status, "skip", "standing in the open world is a skip, not a verdict")

INSTANCE_NAME, INSTANCE_TYPE = "The Deadmines", "party"
eq(resultFor("dungeonkey").status, "pass", "a name that matches an entry passes")

INSTANCE_NAME = "Deadmines"
local missed = resultFor("dungeonkey")
eq(missed.status, "fail", "a near-miss name is a FAILURE - this is the silent case")
ok(missed.detail:find("Deadmines", 1, true) ~= nil,
   "and it prints what the client actually called it, so the fix is obvious")

INSTANCE_NAME, INSTANCE_TYPE = "The Deadmines", "raid"
eq(resultFor("dungeonkey").status, "skip", "a raid is not this feature's business")

-- ---- what a pass RECORDS ------------------------------------------------------------------
--
-- Two of these self-checks settle a /valuate verify item on their own, and passing one now
-- writes a tick into a SEPARATE store from the human ones. That store exists so machine
-- evidence can never be counted as somebody having run the steps - see ns.VerifyEvidence.
--
-- The rule that carries the risk: only a PASS records anything. Skip is the commonest answer
-- these checks give - fifteen of their twenty-three returns - and it means "the situation was
-- never present to test". A skip that ticked a check would retire it on the strength of never
-- having looked, which is the one failure this whole checklist exists to prevent.

-- Cleared first. This gate drives RunSelfVerify many times over with different fixtures, so
-- the recorder has ticks in it from scenarios that are no longer the world - and comparing
-- those against THIS run's statuses is an assertion about the wrong thing entirely.
SELF_TICKS = {}
local passes = Valuate:RunSelfVerify()
local byId = {}
for _, r in ipairs(passes) do byId[r.id] = r end

ok(byId.newstats ~= nil, "the secondaries check still runs")
ok(byId.caches ~= nil, "and the cache check")
eq(byId.newstats.proves, "newstats", "the secondaries check names the verify item it settles")
eq(byId.caches.proves, "cachehit", "and the cache check names its own")

-- Every tick recorded came from a check that PASSED, and named the item that check proves.
for _, id in ipairs(SELF_TICKS) do
    local from
    for _, r in ipairs(passes) do if r.proves == id then from = r end end
    ok(from ~= nil, "a recorded tick traces back to a check that claims it: " .. tostring(id))
    ok(from and from.status == "pass",
       "and that check PASSED - a skip or a failure never records: " .. tostring(id))
end

-- A check with nothing to prove records nothing, whatever it returns.
for _, r in ipairs(passes) do
    if not r.proves then
        for _, id in ipairs(SELF_TICKS) do
            ok(id ~= r.id, "a check that proves no verify item records nothing: " .. r.id)
        end
    end
end

-- A SKIP must record nothing, and this is the assertion that makes that rule load-bearing.
--
-- Skip is the commonest answer these checks give and it means "the situation was never present
-- to test". Without driving one, a rule written as "not a failure" instead of "a pass" looks
-- identical here - and it would retire a check on the strength of never having looked, which is
-- the single thing this checklist exists to prevent.
local savedStats = Valuate.GetCacheStats
Valuate.GetCacheStats = nil            -- makes SelfCheckCaches skip
SELF_TICKS = {}
local skipped = Valuate:RunSelfVerify()
local cacheResult
for _, r in ipairs(skipped) do if r.id == "caches" then cacheResult = r end end
eq(cacheResult and cacheResult.status, "skip", "the cache check skips with no stats to read")
for _, id in ipairs(SELF_TICKS) do
    ok(id ~= "cachehit", "a SKIPPED self-check records no tick for the item it would prove")
end
Valuate.GetCacheStats = savedStats

return failures, checks
`,
  "selfverify",
  "the self-verifying checks"
);
