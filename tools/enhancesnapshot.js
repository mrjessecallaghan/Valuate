#!/usr/bin/env node
/*
 * @gate A profession book read once is remembered, and says how old it is
 *
 * Runs the REAL snapshot layer from ui/Enhance.lua against a mocked Craft/TradeSkill api.
 *
 * This is the missing half of the Enhance tab. GetNumCrafts and GetNumTradeSkills only answer
 * while their window is open, so until now the tab worked exactly once: with Enchanting open,
 * you had to then open Valuate and reach the tab without closing it. Any other order - the
 * obvious order - said "I have not been shown any enhancements yet", which was true and
 * useless.
 *
 * The assertions that matter are the ones about being WRONG rather than empty:
 *
 *   * a window that has opened but not populated reports zero rows for a tick. Storing that
 *     would replace a good book with an empty one, and the feature would look like it had
 *     forgotten your professions - worse than being a tick late.
 *   * re-reading a book REPLACES it. Merging would leave an unlearned profession's
 *     enhancements on offer forever, with nothing on screen to explain why.
 *   * the index is never stored. It moves the moment the list is filtered or collapsed, so a
 *     stored one points at a different recipe - a wrong answer rather than a missing one.
 *   * the age is rounded DOWN and never to "just now" past a minute, because the number exists
 *     to make you distrust old data.
 *
 * Usage:  node tools/enhancesnapshot.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Enhance.lua",
]);

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

local ns = __ns

-- ---- the clock, driven ---------------------------------------------------------------------
local NOW = 1000000
time = function() return NOW end

-- ---- a mocked pair of profession windows -----------------------------------------------------
local CRAFTS, TRADES = {}, {}
local CRAFT_BOOK, TRADE_BOOK = "Enchanting", "Leatherworking"

CRAFT_COUNT = nil
GetNumCrafts = function() return CRAFT_COUNT or #CRAFTS end
GetCraftName = function() return CRAFT_BOOK end
GetCraftInfo = function(i) return CRAFTS[i], nil, "" end
GetCraftItemLink = function() return nil end

GetNumTradeSkills = function() return #TRADES end
GetTradeSkillLine = function() return TRADE_BOOK end
GetTradeSkillInfo = function(i) return TRADES[i], "" end
GetTradeSkillItemLink = function() return nil end

-- Stats come from the addon's own parser against its own tooltip; both are stubbed, because
-- tools/enhance.js already proves the parsing and re-testing it here is a second opinion.
Valuate.GetPrivateTooltip = function()
    return { ClearLines = function() end,
             SetCraftSpell = function() end,
             SetTradeSkillItem = function() end,
             NumLines = function() return 0 end }
end
Valuate.ParseStatsFromTooltip = function() return { Agility = 10 } end

local function reset()
    ValuateEnhanceSnapshot = nil
    ns.ResetEnhanceCache()
    CRAFTS, TRADES = {}, {}
end

-- ---- reading a book that is open -------------------------------------------------------------
reset()
CRAFTS = { "Enchant Boots - Greater Assault", "Enchant Cloak - Superior Agility" }
local stored, total = ns.SnapshotOpenBook()
eq(#stored, 1, "one open book is stored")
eq(stored[1], "Enchanting", "under the name the client gave it")
eq(total, 2, "with both of its enchants")

-- THE POINT OF ALL THIS: close the window, and it is still known.
CRAFTS = {}
local bySlot = ns.CollectEnhancements()
ok(bySlot[8] ~= nil, "with the window CLOSED the boot enchant is still known")
ok(bySlot[15] ~= nil, "and the cloak one")

-- ---- an index is never stored -----------------------------------------------------------------
-- It is a position in a list that reorders when filtered or collapsed. Stored, it points at a
-- different recipe later, which is a wrong answer rather than a missing one.
local entry = bySlot[8][1]
eq(entry.index, nil, "no index is kept, because it stops meaning anything once the window shuts")
eq(entry.link, nil, "nor a link, for the same reason")
ok(entry.name ~= nil and entry.stats ~= nil and entry.slots ~= nil,
   "what IS kept is the part that stays true: name, stats and slot")

-- ---- an empty read must not clobber a good book -------------------------------------------------
-- THE REAL SHAPE OF IT, which the first version of this check got wrong. Nothing-open is the
-- easy case and BookNameFor already refuses it, so asserting that proved a different guard.
--
-- What actually happens is a window that answers its COUNT before it answers its rows:
-- GetNumCrafts says "six" and GetCraftInfo returns nil for every one of them. The book is
-- open and named, and there is nothing in it yet. Storing that replaces a good book with an
-- empty one, and the feature looks like it forgot your professions - which is much worse than
-- being a tick late.
CRAFT_COUNT = 6
CRAFTS = {}
stored, total = ns.SnapshotOpenBook()
eq(#stored, 0, "a window that has not filled its rows in yet stores nothing")
CRAFT_COUNT = nil

bySlot = ns.CollectEnhancements()
ok(bySlot[8] ~= nil, "and the book already remembered survives it")

-- The easy case too, for completeness: nothing open at all.
stored, total = ns.SnapshotOpenBook()
eq(#stored, 0, "a read with nothing open stores nothing either")
bySlot = ns.CollectEnhancements()
ok(bySlot[8] ~= nil, "and still survives that")

-- ---- re-reading REPLACES, it does not merge ------------------------------------------------------
-- Merging would leave an unlearned profession's enhancements on offer forever, with nothing on
-- screen to explain where they came from.
NOW = NOW + 100
CRAFTS = { "Enchant Gloves - Major Strength" }
ns.SnapshotOpenBook()
CRAFTS = {}
bySlot = ns.CollectEnhancements()
ok(bySlot[10] ~= nil, "the newly read enchant is there")
eq(bySlot[8], nil, "and the one that is no longer in the book is GONE, not merged")

-- ---- two books, kept apart --------------------------------------------------------------------
NOW = NOW + 100
CRAFTS = { "Enchant Boots - Greater Assault" }
TRADES = { "Icescale Leg Armor" }
stored, total = ns.SnapshotOpenBook()
eq(#stored, 2, "both apis answering means both books are stored")
CRAFTS, TRADES = {}, {}
bySlot = ns.CollectEnhancements()
ok(bySlot[8] ~= nil, "the enchant survives")
ok(bySlot[7] ~= nil, "and so does the leg armour, from the other profession")

local books = ns.SnapshotBooks()
eq(#books, 2, "both are listed")
-- Newest first, and both were written at the same NOW, so the tie-break decides - and it must
-- decide the same way every time or the panel reshuffles between openings.
local first = ns.SnapshotBooks()[1].name
eq(ns.SnapshotBooks()[1].name, first, "the listing order is stable")
eq(ns.SnapshotBooks()[2].name, ns.SnapshotBooks()[2].name, "for both entries")

-- ---- unreadable rows are remembered too ------------------------------------------------------
-- "I saw these and could not classify them" is information, and the panel shows it. A book
-- that yields ONLY unreadable rows is still stored, or that information is lost.
reset()
CRAFTS = { "Arcanum of Torment" }   -- no slot pattern matches it
stored, total = ns.SnapshotOpenBook()
eq(#stored, 1, "a book with nothing classifiable is still stored")
eq(total, 0, "with no usable entries")
CRAFTS = {}
local _, unreadable = ns.CollectEnhancements()
eq(#unreadable, 1, "and the thing it could not read is still reported after the window shuts")
eq(unreadable[1].name, "Arcanum of Torment", "by name")

-- ---- the age, which is what turns a cache into a claim ------------------------------------------
reset()
CRAFTS = { "Enchant Boots - Greater Assault" }
ns.SnapshotOpenBook()
eq(ns.SnapshotAge(NOW), 0, "a book just read is zero seconds old")
eq(ns.SnapshotAge(NOW + 7200), 7200, "and ages from when it was read")

-- Rounded DOWN at every step. The number exists to make you distrust old data, so rounding 3
-- days down to "recently" is the failure this guards against; rounding 23 hours up is not.
eq(ns.DescribeAge(0), "just now", "seconds are just now")
eq(ns.DescribeAge(59), "just now", "and so is anything under a minute")
eq(ns.DescribeAge(60), "1 minute ago", "a minute is named, singular")
eq(ns.DescribeAge(3599), "59 minutes ago", "and stays minutes right up to the hour")
eq(ns.DescribeAge(3600), "1 hour ago", "an hour, singular")
eq(ns.DescribeAge(86399), "23 hours ago", "and stays hours right up to the day")
eq(ns.DescribeAge(86400), "1 day ago", "a day, singular")
eq(ns.DescribeAge(86400 * 9), "9 days ago", "and days after that")
eq(ns.DescribeAge(nil), "just now", "no age at all does not error")

-- ---- book order is SORTED, not pairs() -----------------------------------------------------------
-- Two professions can name the same enhancement, so which one wins would otherwise change
-- between sessions - and so would the order of the "could not read" list, which is on screen.
--
-- EIGHT books, not two. With two, pairs() lands on the sorted order half the time by luck and
-- the assertion passes without the sort existing at all - which is exactly what happened when
-- this was written with two.
reset()
local WANT = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel" }
snap = ns.GetEnhanceSnapshot()
for i = #WANT, 1, -1 do
    -- Inserted backwards, so insertion order is not the sorted order either.
    snap.books[WANT[i]] = {
        at = 1, source = "craft", entries = {},
        unreadable = { { name = WANT[i] .. " thing", why = "could not tell which slot" } },
    }
end

local _, unread = ns.CollectEnhancements()
eq(#unread, #WANT, "every book contributes its unreadable rows")
local inOrder = true
for i = 1, #WANT do
    if unread[i].name ~= WANT[i] .. " thing" then inOrder = false end
end
ok(inOrder, "and they arrive in sorted book order, the same order every session")

-- ---- the schema, discarded rather than migrated ---------------------------------------------------
ValuateEnhanceSnapshot = { schema = 999, books = { Enchanting = { entries = { {} } } } }
local snap = ns.GetEnhanceSnapshot()
eq(snap.schema, ns.ENHANCE_SNAPSHOT_SCHEMA, "a snapshot from another schema is discarded")
eq(next(snap.books), nil, "along with its contents, rather than half-read")

ValuateEnhanceSnapshot = "not a table"
snap = ns.GetEnhanceSnapshot()
eq(type(snap.books), "table", "and a saved variable of the wrong type entirely does not throw")

-- ---- bounded --------------------------------------------------------------------------------------
-- Neither cap should be reachable by a real character; a saved-variables file with no ceiling
-- is a problem nobody notices until it is one.
reset()
snap = ns.GetEnhanceSnapshot()
for i = 1, ns.SNAPSHOT_BOOK_CAP + 5 do
    snap.books["Book" .. i] = { at = i, source = "craft", entries = {}, unreadable = {} }
end
local dropped = ns.TrimSnapshotBooks(snap)
eq(dropped, 5, "over the cap, the excess is evicted")
local left = 0
for _ in pairs(snap.books) do left = left + 1 end
eq(left, ns.SNAPSHOT_BOOK_CAP, "leaving exactly the cap")
eq(snap.books["Book1"], nil, "the OLDEST goes first")
ok(snap.books["Book" .. (ns.SNAPSHOT_BOOK_CAP + 5)] ~= nil, "and the newest stays")

-- ---- the diagnostic must describe the CURRENT data model ---------------------------------------
-- /valuate enhancecheck probes the live apis, and with no profession window open every one of
-- them answers zero. Before the snapshot existed that was the whole truth. After it, a bare
-- "0" and a verdict of "nothing at all" are both true about the wrong question - and this is
-- the command people are told to run when the tab looks empty, so being misleading here sends
-- them to exactly the wrong conclusion.
reset()
__printed = {}
ns.PrintEnhanceProbe()
local said = table.concat(__printed, "\\n")
ok(said:find("Nothing remembered yet", 1, true) ~= nil,
   "with nothing stored, the probe says so and says how to fix it")
ok(said:find("just opening it is enough", 1, true) ~= nil, "naming the one action that helps")

-- Now something IS remembered, with every window shut.
CRAFTS = { "Enchant Boots - Greater Assault", "Enchant Cloak - Superior Agility" }
ns.SnapshotOpenBook()
CRAFTS = {}
NOW = NOW + 7200

__printed = {}
ns.PrintEnhanceProbe()
said = table.concat(__printed, "\\n")
ok(said:find("Remembered from earlier", 1, true) ~= nil,
   "with a window shut but a book stored, the probe reports the book")
ok(said:find("Enchanting", 1, true) ~= nil, "by name")
ok(said:find("2 hours ago", 1, true) ~= nil, "and says how old it is, so it is read as a record")

-- THE VERDICT. "Nothing at all" is a hard statement that the feature cannot work here, and it
-- must not be said to someone whose snapshot is full.
eq(said:find("Nothing at all", 1, true), nil,
   "and never says the client can tell it nothing while it is holding a full book")

-- The live count says LIVE, so a zero beside it is not read as "nothing known".
ok(said:find("open right now", 1, true) ~= nil,
   "the live count is labelled as what is open, not as what is known")
-- THE VERDICT, on a client whose apis are gone. "Nothing at all - this is not a client Valuate
-- can read enhancements from" is a hard statement that the feature cannot work here, and it
-- must not be said to someone whose snapshot is full. Rare, and the cheap branch to get right:
-- a book read under one patch outlives an api that gets renamed under the next.
local realCraft, realTrade = GetNumCrafts, GetNumTradeSkills
local realCraftInfo, realTradeInfo = GetCraftInfo, GetTradeSkillInfo
GetNumCrafts, GetNumTradeSkills = nil, nil
GetCraftInfo, GetTradeSkillInfo = nil, nil

__printed = {}
ns.PrintEnhanceProbe()
said = table.concat(__printed, "\\n")
eq(said:find("Nothing at all", 1, true), nil,
   "with no live api but a book remembered, it does not declare the client useless")
ok(said:find("Remembered from earlier", 1, true) ~= nil, "it reports the book instead")

-- ...and it DOES say it on a client that can tell it nothing and has nothing stored, or the
-- check above would pass on a verdict that had simply been deleted.
reset()
__printed = {}
ns.PrintEnhanceProbe()
said = table.concat(__printed, "\\n")
ok(said:find("Nothing at all", 1, true) ~= nil,
   "and still says it when there is genuinely nothing, live or remembered")

GetNumCrafts, GetNumTradeSkills = realCraft, realTrade
GetCraftInfo, GetTradeSkillInfo = realCraftInfo, realTradeInfo

-- ---- the count the to-do list shares -----------------------------------------------------------
-- The Enhance tab and the To Do list used to answer the same question differently. They share
-- this function now, so it is worth proving it answers what the tab shows rather than what the
-- old to-do line counted.
reset()
Valuate.GetPrimaryScale = function() return { Values = { Agility = 1 } }, "Dps" end
Valuate.CalculateItemScore = function(_, stats) return (stats and stats.Agility) or 0 end
GetInventoryItemLink = function(_, slot)
    if slot == 8 then return "|Hitem:100:0|h[Boots]|h" end       -- bare, and I know a boot enchant
    if slot == 1 then return "|Hitem:200:0|h[Helm]|h" end        -- bare, nothing known for heads
    if slot == 5 then return "|Hitem:300:555|h[Chest]|h" end     -- already enchanted
    return nil
end
GetItemInfo = function() return "Item", nil, nil, 60 end

CRAFTS = { "Enchant Boots - Greater Assault" }
ns.SnapshotOpenBook()
CRAFTS = {}

local canDo, bare = ns.CountEnhanceTodo()
eq(canDo, 1, "one slot has something that could go on it right now")
eq(bare, 1, "and one is bare with nothing known - counted separately, not as work")

-- No scale, no ranking, and therefore no honest number.
Valuate.GetPrimaryScale = function() return nil, nil end
canDo, bare = ns.CountEnhanceTodo()
eq(canDo, 0, "with no active scale there is nothing to rank, so nothing is claimed")
eq(bare, 0, "in either column")

-- ---- advice that names YOUR professions ---------------------------------------------------------
-- "Open Enchanting or a crafting profession" is useless to a miner-skinner, and worse than
-- useless: it implies the feature would work if they went and did something, when for them it
-- never will. Four different characters, four different sentences.
reset()

local SKILLS = nil
ns.KnownProfessions = function() return SKILLS end

-- 1. BLIND. GetSkillLineInfo returns nothing when the skill headers are collapsed - the same
-- quirk the Settings overrides exist for. An empty read means "I could not see", and saying
-- "you have none" on the back of it would be a confident lie.
SKILLS = nil
local text = ns.EnhanceAdviceText()
ok(text:find("crafting profession", 1, true) ~= nil,
   "with the skill list unreadable it falls back to the generic advice")
eq(text:find("None of your professions", 1, true), nil,
   "and never concludes you have none from a read that failed")

-- 2. HAS THEM, NONE READ. Name them, and only the ones that make something wearable.
SKILLS = { Leatherworking = true, Blacksmithing = true, Mining = true, Cooking = true }
text = ns.EnhanceAdviceText()
ok(text:find("Leatherworking", 1, true) ~= nil, "it names the profession you actually have")
ok(text:find("Blacksmithing", 1, true) ~= nil, "and the second one")
eq(text:find("Mining", 1, true), nil, "not the gathering one, which makes nothing wearable")
eq(text:find("Cooking", 1, true), nil, "nor the one that makes food")
eq(text:find("Enchanting", 1, true), nil, "and not a profession you do not have")

-- 3. HAS THEM, ALREADY READ. A different answer from "go and open something", and the only
-- honest one: everything it could read has been read and still came to nothing.
SKILLS = { Leatherworking = true }
CRAFT_BOOK = "Leatherworking"
TRADES = { "Nothing Useful" }
TRADE_BOOK = "Leatherworking"
ns.SnapshotOpenBook()
TRADES = {}
text = ns.EnhanceAdviceText()
ok(text:find("already read", 1, true) ~= nil,
   "once the book has been read it stops telling you to open it")
ok(text:find("Leatherworking", 1, true) ~= nil, "still naming which")

-- 4. HAS NONE. Say so, and say what it means, rather than sending them on an errand that
-- cannot help. And hedge, because detection is the thing that can be wrong here.
reset()
ns.KnownProfessions = function() return SKILLS end
SKILLS = { Mining = true, Skinning = true, Cooking = true }
text = ns.EnhanceAdviceText()
ok(text:find("None of your professions", 1, true) ~= nil,
   "a character with no enhancing profession is told so plainly")
ok(text:find("someone else", 1, true) ~= nil, "and where the enchants would have to come from")
ok(text:find("collapsed", 1, true) ~= nil,
   "with the one way this detection is known to be wrong named, not hidden")
eq(text:find("just opening it is enough", 1, true), nil,
   "and is never sent to open a book that cannot contain one")

return failures, checks
`,
  "enhancesnapshot",
  "the profession snapshot"
);
