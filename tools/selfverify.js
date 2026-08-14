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

local EQUIPPED, BAGS = {}, {}
function GetInventoryItemLink(_, slotId) return EQUIPPED[slotId] end
function GetContainerNumSlots(bagId) return BAGS[bagId] and 16 or 0 end
function GetContainerItemLink(bagId, slotId) return BAGS[bagId] and BAGS[bagId][slotId] end

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

-- ---- the shape of the report -------------------------------------------------
local all = Valuate:RunSelfVerify()
eq(#all, 3, "every check reports, none silently dropped")
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
eq(#Valuate:RunSelfVerify(), 4, "and it is reported, not dropped")

return failures, checks
`,
  "selfverify",
  "the self-verifying checks"
);
