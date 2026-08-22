#!/usr/bin/env node
/*
 * @gate Enhancements land on the right slot, and the probe reports what the client really has
 *
 * Runs ui/Enhance.lua against a mocked WoW API.
 *
 * The enhancement data is read LIVE, because there is no trustworthy static catalogue for
 * this server - AtlasLoot's ~4,100 crafting spellIDs are retail Wrath's, with no stats, no
 * source and no cost, and Ascension changes all of those. A live recipe gives one usable
 * fact: its NAME. So the slot has to be read out of "Enchant Boots - Greater Assault", and
 * that classification is the whole correctness of the feature.
 *
 * It is a first-match-wins pattern list, which means ORDER IS THE BEHAVIOUR. "weapon" is a
 * substring of the two-handed and off-hand recipe names, so placed too early it claims all of
 * them for the main hand. These cases are real recipe names for exactly that reason: a test
 * written against the patterns would agree with whatever order they happen to be in.
 *
 * The probe is checked for the property that makes it worth having: it must report a source
 * as MISSING rather than erroring when the client does not have it, because the client this
 * runs on is the unknown quantity and a probe that throws tells you nothing.
 *
 * Usage:  node tools/enhance.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load(["ui/Shared.lua", "ui/Enhance.lua"]);

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

local function slotsOf(name)
    local s = ns.EnhancementSlots(name)
    if not s then return "nil" end
    local out = {}
    for _, id in ipairs(s) do out[#out + 1] = tostring(id) end
    return table.concat(out, ",")
end

-- ---- real recipe names, one per slot ----------------------------------------------------
-- Taken from the shapes AtlasLoot records, which is what the live client returns too.
local CASES = {
    { "Enchant Boots - Greater Assault",        "8"     },
    { "Enchant Bracer - Superior Spellpower",   "9"     },
    { "Enchant Chest - Powerful Stats",         "5"     },
    { "Enchant Cloak - Greater Speed",          "15"    },
    { "Enchant Gloves - Crusher",               "10"    },
    { "Enchant Shoulder - Greater Inscription", "3"     },
    { "Enchant Ring - Assault",                 "11,12" },
    { "Icescale Leg Armor",                     "7"     },
    { "Arcanum of Torment",                     "nil"   },
}
for _, c in ipairs(CASES) do
    eq(slotsOf(c[1]), c[2], "slot for: " .. c[1])
end

-- ---- ORDER is the behaviour ---------------------------------------------------------------
-- "weapon" appears inside the two-handed and off-hand names. Placed above them it would claim
-- every one of those for the main hand, and every case above would still pass.
eq(slotsOf("Enchant 2H Weapon - Massacre"), "16",
   "a two-handed enchant is main-hand only, not 'weapon'")
eq(slotsOf("Enchant Weapon - Berserking"), "16,17",
   "a plain weapon enchant fits either hand")
eq(slotsOf("Enchant Shield - Greater Intellect"), "17",
   "a shield enchant is off-hand, not 'weapon'")
eq(slotsOf("Enchant Off-Hand - Superior Intellect"), "17", "off-hand is off-hand")

-- "Bracer" contains "race"; "Gloves" contains "love". A pattern list matched loosely against
-- the wrong field is how those become bugs, so they are pinned.
eq(slotsOf("Enchant Bracer - Greater Stats"), "9", "bracer is wrist and nothing else")
eq(slotsOf("Enchant Gloves - Greater Assault"), "10", "gloves are hands")

-- ---- things that are not enhancements ------------------------------------------------------
-- Returning a slot for these would put reagents and unrelated crafts into the panel.
eq(slotsOf("Dream Shard"), "nil", "a reagent belongs to no slot")
eq(slotsOf(""), "nil", "an empty name belongs to no slot")
eq(slotsOf(nil), "nil", "a nil name does not error")
eq(slotsOf(42), "nil", "a non-string does not error")

-- ---- the probe reports rather than throws ---------------------------------------------------
-- This is the point of it. The client is the unknown quantity - one of the five names it
-- looks for is Ascension's own undocumented API - so a probe that errors on a missing source
-- tells you nothing about the client you are trying to learn about.
GetNumTradeSkills = nil
GetTradeSkillInfo = nil
GetTradeSkillRecipeLink = nil
GetNumCrafts = nil
GetCraftInfo = nil
GetSpellInfo = nil
GetMerchantNumItems = nil
GetMerchantItemInfo = nil

local available, missing = ns.ProbeEnhanceSources()
eq(#available, 0, "with a client that exposes nothing, nothing is reported as available")
ok(#missing > 0, "and every source is reported missing rather than the probe failing")
for _, m in ipairs(missing) do
    ok(m.label and m.label ~= "", "each missing source is named: " .. tostring(m.key))
    ok(m.why and m.why ~= "", "and says why it matters: " .. tostring(m.key))
end

-- ---- and reports what IS there ----------------------------------------------------------------
GetSpellInfo = function() return "Enchant Boots - Assault" end
GetNumTradeSkills = function() return 7 end
GetTradeSkillInfo = function() return "x" end
GetTradeSkillRecipeLink = function() return "|Hspell:1|h" end

available = ns.ProbeEnhanceSources()
local byKey = {}
for _, a in ipairs(available) do byKey[a.key] = a end
ok(byKey.tradeskill ~= nil, "an available source is reported available")
eq(byKey.tradeskill.count, 7, "with a live count, so 'yes but empty' is distinguishable")
ok(byKey.craft == nil, "and a source that is still absent stays absent")

-- Zero open recipes is not the same as no tradeskill API. Both say "nothing to show", and
-- only one of them is something the player can fix by opening a window.
GetNumTradeSkills = function() return 0 end
available = ns.ProbeEnhanceSources()
byKey = {}
for _, a in ipairs(available) do byKey[a.key] = a end
ok(byKey.tradeskill ~= nil, "an empty profession window is still an AVAILABLE source")
eq(byKey.tradeskill.count, 0, "reporting zero, which is a different answer from missing")

-- ---- the Ascension API list is data, not a guess baked into a branch -------------------------
ok(#ns.MYSTIC_PROVIDERS >= 5,
   "all the guessed Ascension API names are probed, not just the one this file assumed")

-- Per-name, so different enchants can carry different stats and the ranking has something to
-- rank. A single shared stat table made every option score identically, which is how the
-- ordering assertions came to prove nothing.
local STATS_BY_NAME = {
    ["Enchant Boots - Greater Assault"] = { Agility = 32 },
    ["Enchant Boots - Assault"]         = { Agility = 20 },
    ["Enchant Boots - Minor Agility"]   = { Agility = 4 },
    ["Enchant Cloak - Superior Agility"] = { Agility = 16 },
    -- Berserking is the case that matters for effect scoring: a real enchant that grants NO
    -- parseable stat at all. Scoring it zero would rank it below Minor Agility.
    ["Enchant Weapon - Berserking"]     = {},
    ["Icescale Leg Armor"]              = { Agility = 22 },
    -- The header carries stats too, deliberately. Without them it was excluded because its
    -- stats would not parse rather than because it is a header, and the header check could
    -- be deleted with nothing noticing.
    ["Enchant Boots"]                   = { Agility = 99 },
}
local CURRENT_NAME
Valuate.GetPrivateTooltip = function()
    return { ClearLines = function() end,
             SetCraftSpell = function() end,
             SetTradeSkillItem = function() end }
end
Valuate.ParseStatsFromTooltip = function() return STATS_BY_NAME[CURRENT_NAME] end

-- ---- collecting from BOTH apis --------------------------------------------------------------
-- 3.3.5 splits them: Enchanting lives behind Craft, everything else behind TradeSkill. A build
-- that read one would silently miss the profession this feature is mostly about, and would
-- look like it was working the whole time.
--
-- THREE boot enchants, not one. With a single option there is no order to get wrong, and the
-- ranking assertions below passed with the comparator removed entirely - a slot with one
-- entry is sorted no matter what you do to it.
local CRAFTS = {
    { "Enchant Boots", "header" },
    { "Enchant Boots - Greater Assault", "" },
    { "Enchant Boots - Assault", "" },
    { "Enchant Boots - Minor Agility", "" },
    { "Enchant Cloak - Superior Agility", "" },
    { "Enchant Weapon - Berserking", "" },
}
local TRADES = {
    { "Icescale Leg Armor", "" },
    { "Dream Shard", "" },
}
GetNumCrafts = function() return #CRAFTS end
GetCraftInfo = function(i) CURRENT_NAME = CRAFTS[i][1] return CRAFTS[i][1], nil, CRAFTS[i][2] end
GetNumTradeSkills = function() return #TRADES end
GetTradeSkillInfo = function(i) CURRENT_NAME = TRADES[i][1] return TRADES[i][1], TRADES[i][2] end
GetCraftItemLink = function() return nil end
GetTradeSkillItemLink = function() return nil end

-- The addon's own tooltip and parser, stubbed. This gate is about COLLECTION, not about stat
-- parsing - that has its own gate, and re-testing it here would just be a second opinion.


local bySlot, unreadable = ns.CollectEnhancements()
ok(bySlot[8] ~= nil, "a craft-api enchant reaches its slot (boots)")
ok(bySlot[7] ~= nil, "and a tradeskill-api one reaches its slot (leg armor)")
ok(bySlot[15] ~= nil, "cloak too")

-- A header is a category label, not something you can make - and its name is a slot word, so
-- letting one through would list "Enchant Boots" as an enchant in its own right.
local bootNames = {}
for _, e in ipairs(bySlot[8]) do bootNames[#bootNames + 1] = e.name end
eq(#bootNames, 3, "the three real boot enchants are collected (" ..
   table.concat(bootNames, ", ") .. ")")
for _, n in ipairs(bootNames) do
    ok(n ~= "Enchant Boots",
       "the bare header row is not among them - it is a category label, and its name is a " ..
       "slot word, so letting it through lists it as an enchant in its own right")
end

-- A weapon enchant fits either hand, so it appears under both.
ok(bySlot[16] ~= nil and bySlot[17] ~= nil, "a weapon enchant appears for both hands")

-- ---- what could not be read is REPORTED, not dropped ------------------------------------------
-- Dropping it would make the panel look complete when it is not. An enhancement nobody could
-- classify is still one you might want.
local sawReagent = false
for _, u in ipairs(unreadable) do
    if u.name == "Dream Shard" then sawReagent = true end
    ok(u.why and u.why ~= "", "each unreadable entry says why: " .. tostring(u.name))
end
ok(sawReagent, "something with no recognisable slot is reported rather than silently dropped")

-- ---- ranking: best first, and the rest still listed --------------------------------------------
-- The whole point of the ordering. A +8 armour enchant beats an empty slot even when it is
-- nowhere near best, and on a levelling character it is frequently the only one affordable.
Valuate.CalculateItemScore = function(_, stats)
    return (stats and stats.Agility or 0) * 1.0
end
local SCALE = { Values = { Agility = 1, AttackPower = 1 } }
local ranked = ns.RankForSlot(bySlot, 8, SCALE, "Dps")
ok(#ranked >= 1, "the slot ranks its options")
-- NAMED, not merely 'first has the highest score'. That weaker form was also true of a plain
-- alphabetical sort of these three, so it passed with the score comparison removed entirely.
eq(ranked[1].entry.name, "Enchant Boots - Greater Assault", "the highest scoring option is first")
eq(ranked[#ranked].entry.name, "Enchant Boots - Minor Agility", "and the weakest is last")

-- Ordering is stable. The source order is whatever the profession window happened to list,
-- so an unsorted tie would reshuffle the panel between openings.
local first = ranked[1].entry.name
for _ = 1, 4 do
    eq(ns.RankForSlot(bySlot, 8, SCALE, "Dps")[1].entry.name, first,
       "and in the same order every time")
end

-- ---- effect enchants do not score zero ----------------------------------------------------------
-- "Berserking" grants no parseable stat. Scoring it zero would rank it below a +4 Spirit
-- enchant for every character on the server, which is worse than an admitted estimate.
local weapon = ns.RankForSlot(bySlot, 16, SCALE, "Dps")
ok(#weapon >= 1, "a weapon enchant is ranked")
ok(weapon[1].score > 0, "an effect enchant with no parseable stats still scores above nothing")
ok(weapon[1].estimated, "and is MARKED as estimated, because that number is a judgement")

-- ---- role comes from the scale, not from a class --------------------------------------------------
-- This server is classless. The scale is the only statement of intent the addon has.
eq(ns.RoleForScale({ Values = { AttackPower = 10, Agility = 8 } }), "dps",
   "a scale full of offence is a damage scale")
eq(ns.RoleForScale({ Values = { Dodge = 10, Armor = 8, Defense = 6, AttackPower = 2 } }), "tank",
   "a scale that weights avoidance and armour is a tank's, whatever its owner calls it")
eq(ns.RoleForScale({ Values = { Healing = 10, Mp5 = 8, Spirit = 6, SpellPower = 2 } }), "healer",
   "and one that weights healing and regen is a healer's")
eq(ns.RoleForScale(nil), "dps", "no scale falls back rather than erroring")

-- Threat reduction is the case that proves the columns are read separately: real value to a
-- damage dealer, actively unwanted by a tank.
local threat
for _, e in ipairs(ns.EFFECT_VALUES) do
    if e[1] == "threat" then threat = e end
end
ok(threat ~= nil, "threat reduction is valued")
ok(threat[2] > threat[3], "worth more to damage than to a tank, who does not want it at all")

-- ---- vendor notes, taken while you stand in front of one ----------------------------------
-- Nothing on this machine knows where a recipe is sold, so the only honest answer to "where
-- do I learn this" is one written down at the time.
ValuateVendorNotes = nil
time = function() return 1000 end
GetRealZoneText = function() return "Dalaran" end
GetSubZoneText = function() return "The Threads of Fate" end
UnitName = function() return "Alara" end

eq(ns.RecordVendorNote("Formula: Enchant Boots - Assault", 12000, "Alara", "Dalaran", 1000), 1,
   "a recipe is noted")
local cost, seller, where = ns.LookupVendorNote("Formula: Enchant Boots - Assault")
eq(cost, 12000, "with its price")
eq(seller, "Alara", "who sold it")
eq(where, "Dalaran", "and where they were standing")

-- NARROW on purpose. The alternative is a note on every grey shirt and stack of arrows in
-- the game, which would blow the cap on one trip to a city and evict what mattered.
eq(ns.RecordVendorNote("Linen Cloth", 50, "Alara", "Dalaran", 1000), 0,
   "an ordinary vendor item is not noted")
eq(ns.RecordVendorNote("Icescale Leg Armor", 500, "Alara", "Dalaran", 1000), 1,
   "but an enhancement sold directly is, because it names its slot like a recipe does")
eq(ns.LookupVendorNote("Linen Cloth"), nil, "and the ordinary item was never written")

-- Prices differ by reputation and by server, so a note that already exists is UPDATED. The
-- one worth keeping is the one describing what you would pay.
ns.RecordVendorNote("Formula: Enchant Boots - Assault", 9000, "Alara", "Dalaran", 1100)
eq(select(1, ns.LookupVendorNote("Formula: Enchant Boots - Assault")), 9000,
   "seeing it again at a different price updates the note rather than keeping the old one")

-- ---- the cap, which is the part that can quietly go wrong -----------------------------------
-- "Record everything you ever see" is how a saved-variables file becomes a problem nobody
-- notices until it is one.
ValuateVendorNotes = nil
for i = 1, ns.VENDOR_NOTE_CAP + 50 do
    -- Ascending timestamps, so the oldest are unambiguous.
    ns.RecordVendorNote("Formula: Number " .. i, 100, "Alara", "Dalaran", i)
end
local kept = 0
for k in pairs(ns.GetVendorNotes()) do
    if k ~= "__schema" then kept = kept + 1 end
end
eq(kept, ns.VENDOR_NOTE_CAP, "the list is bounded at the cap")
eq(ns.LookupVendorNote("Formula: Number 1"), nil, "the oldest note was evicted")
ok(ns.LookupVendorNote("Formula: Number " .. (ns.VENDOR_NOTE_CAP + 50)) ~= nil,
   "and the newest was kept")

-- ---- capturing a whole merchant --------------------------------------------------------------
ValuateVendorNotes = nil
local STOCK = {
    { "Formula: Enchant Cloak - Greater Speed", 45000 },
    { "Roasted Quail", 25 },
    { "Pattern: Icescale Leg Armor", 60000 },
}
GetMerchantNumItems = function() return #STOCK end
GetMerchantItemInfo = function(i) return STOCK[i][1], nil, STOCK[i][2] end
eq(ns.CaptureMerchant(1000), 2, "a merchant's recipes are noted and its food is not")
ok(ns.LookupVendorNote("Formula: Enchant Cloak - Greater Speed") ~= nil, "the formula is there")
eq(ns.LookupVendorNote("Roasted Quail"), nil, "the quail is not")

-- Where, at subzone precision, because that is as close as this client will say.
local _, _, place = ns.LookupVendorNote("Formula: Enchant Cloak - Greater Speed")
ok(place and place:find("Threads of Fate", 1, true) ~= nil,
   "the note carries the subzone, not just the zone (" .. tostring(place) .. ")")

-- ---- and a trainer, which is where most enchants actually come from ----------------------------
ValuateVendorNotes = nil
local SERVICES = { { "Enchant Boots - Greater Assault" }, { "Journeyman Enchanting" } }
GetNumTrainerServices = function() return #SERVICES end
GetTrainerServiceInfo = function(i) return SERVICES[i][1] end
GetTrainerServiceCost = function() return 3000 end
eq(ns.CaptureTrainer(1000), 1, "a trainer's enchants are noted and its rank-ups are not")

-- ---- what a tab click COSTS ----------------------------------------------------------------------
-- Every other check here asks whether the answer is right. This one asks what it cost, because
-- nothing else can - and this path is exposed to a number the addon does not control.
--
-- Collecting parses a TOOLTIP per recipe: ClearLines, then a setter, then the full stat parser.
-- An enchanter with a filled book has a few hundred, and the Enhance tab rebuilds on every
-- arrival INCLUDING a re-click, because a profession window that was shut last time makes a
-- stale list worse than none. So one click was one tooltip parse per recipe, every time.
GetNumCrafts = function() return #CRAFTS end
GetCraftInfo = function(i) CURRENT_NAME = CRAFTS[i][1] return CRAFTS[i][1], nil, CRAFTS[i][2] end
GetNumTradeSkills = function() return #TRADES end
GetTradeSkillInfo = function(i) CURRENT_NAME = TRADES[i][1] return TRADES[i][1], TRADES[i][2] end

local parses = 0
local realParse = Valuate.ParseStatsFromTooltip
Valuate.ParseStatsFromTooltip = function(...)
    parses = parses + 1
    return realParse(...)
end

ns.ResetEnhanceCache()
parses = 0
ns.CollectEnhancements()
local cold = parses
ok(cold > 0, "the first collection reads tooltips (" .. cold .. ")")

parses = 0
for _ = 1, 5 do ns.CollectEnhancements() end
eq(parses, 0,
   "five more collections read NONE - an enchant's stats do not change, so re-reading them " ..
   "on every tab click is work nobody asked for")

-- The cache has to CLEAR when the book changes, or learning a recipe leaves it invisible
-- until you log out - which reads as the feature not seeing it at all.
ns.ResetEnhanceCache()
parses = 0
ns.CollectEnhancements()
eq(parses, cold, "and clearing it makes them readable again")

-- ...and it clears on the events that mean the book CHANGED, not just on demand.
--
-- Wired to both apis and both of their update events. A window OPENING is when it first has
-- contents; an UPDATE is what fires when you learn something with it already open. Miss either
-- and a newly-learned enchant stays invisible until you log out, which reads as the feature
-- not seeing it at all - a far worse failure than the re-reading the cache avoids.
local watcher
for _, f in ipairs(__frames) do
    if f.__events and f.__events["MERCHANT_SHOW"] then watcher = f end
end
ok(watcher ~= nil, "the capture frame is reachable")
if watcher then
    for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE",
                         "CRAFT_SHOW", "CRAFT_UPDATE", "LEARNED_SPELL_IN_TAB" }) do
        ok(watcher.__events[e], "the cache is cleared on " .. e)
    end

    -- Driven, not merely registered. A handler that ignores the event it asked for is the
    -- same defect with an extra step.
    ns.CollectEnhancements()
    parses = 0
    ns.CollectEnhancements()
    eq(parses, 0, "warm before the event")

    -- LEARNING SOMETHING, end to end. The event clears the stats cache and re-reads the book
    -- in the same breath, so a recipe you just learned is in the snapshot immediately rather
    -- than the next time you happen to open the Enhance tab with the window still up.
    --
    -- This asserts the OUTCOME. It used to assert the mechanism - that the cache went cold -
    -- which stopped being true the moment the event started re-reading, even though the thing
    -- the user cares about got better rather than worse.
    Valuate.ParseStatsFromTooltip = function(...) parses = parses + 1 return realParse(...) end
    STATS_BY_NAME["Enchant Gloves - Major Strength"] = { Strength = 40 }
    CRAFTS[#CRAFTS + 1] = { "Enchant Gloves - Major Strength", "" }
    parses = 0
    watcher.__scripts.OnEvent(watcher, "CRAFT_UPDATE")
    ok(parses > 0, "the event re-reads the book cold, rather than only marking it stale")

    local afterLearn = ns.CollectEnhancements()
    local foundNew = false
    for _, e in ipairs(afterLearn[10] or {}) do
        if e.name == "Enchant Gloves - Major Strength" then foundNew = true end
    end
    ok(foundNew, "and the recipe you just learned is there, without opening the tab first")

    -- WHAT THE CACHE RESET IS ACTUALLY FOR, which is not the case above.
    --
    -- statsCache is keyed on the recipe's NAME, so something newly learned is a cache MISS and
    -- would be read whether or not the cache was cleared - the assertion above passed with the
    -- reset deleted entirely. What the reset protects is a name ALREADY cached whose stats have
    -- changed: a server that retunes an enchant, or a tooltip that parsed partially the first
    -- time and reads properly now.
    STATS_BY_NAME["Enchant Boots - Greater Assault"] = { Agility = 999 }
    watcher.__scripts.OnEvent(watcher, "CRAFT_UPDATE")
    local reread = ns.CollectEnhancements()
    local changed
    for _, e in ipairs(reread[8] or {}) do
        if e.name == "Enchant Boots - Greater Assault" then changed = e end
    end
    eq(changed and changed.stats and changed.stats.Agility, 999,
       "a recipe whose stats CHANGED is re-read, not served from a cache keyed on its name")

    -- Put the fixture back: a later check reads this same enchant and expects its real value.
    -- A test that quietly leaves the world different is a test that breaks its neighbours.
    STATS_BY_NAME["Enchant Boots - Greater Assault"] = { Agility = 32 }
    watcher.__scripts.OnEvent(watcher, "CRAFT_UPDATE")
    ns.CollectEnhancements()
end

-- A FAILED read is not remembered.
--
-- The usual reason a parse comes back nil is that the tooltip was not ready yet - a moment,
-- not a fact about the recipe. Caching it makes that moment permanent for the session, and the
-- enchant then sits in "could not read its stats" forever with nothing to explain why.
ns.ResetEnhanceCache()
Valuate.ParseStatsFromTooltip = function() return nil end
local _, failedFirst = ns.CollectEnhancements()
local sawFailure = false
for _, u in ipairs(failedFirst) do
    if u.why and u.why:find("stats", 1, true) then sawFailure = true end
end
ok(sawFailure, "a recipe whose stats will not parse is reported as unreadable")

Valuate.ParseStatsFromTooltip = function() return STATS_BY_NAME[CURRENT_NAME] end
local recovered = ns.CollectEnhancements()
ok(recovered[8] ~= nil and #recovered[8] > 0,
   "and is read properly on the next attempt, rather than being stuck as unreadable")

-- Its STATS, not merely its presence. A cached failure stored as an empty table comes back
-- looking like a perfectly good read of an enchant that grants nothing - present, scoreable,
-- and worth zero. Checking the row exists cannot tell those apart.
local best
for _, e in ipairs(recovered[8] or {}) do
    if e.name == "Enchant Boots - Greater Assault" then best = e end
end
ok(best ~= nil, "the boot enchant is back")
eq(best and best.stats and best.stats.Agility, 32,
   "with its real stats, not the empty table a cached failure would have left")

Valuate.ParseStatsFromTooltip = realParse

-- ---- the item-level floor, read out of the same tooltip -------------------------------------
-- Enchants carry one: "Requires a level 60 or higher item". The WORDING is not verified
-- against Ascension, which is why an unrecognised line must yield nil - "no requirement I
-- could read" - rather than zero. Zero would read as "no requirement", and the panel would
-- then confidently offer enchants that cannot be applied.
ns.ResetEnhanceCache()
local REQ_LINES = {}
ValuatePrivateTooltip = { NumLines = function() return #REQ_LINES end }
_G.ValuatePrivateTooltip = ValuatePrivateTooltip
getglobal = function(name)
    local i = tonumber(name:match("TextLeft(%d+)$") or "")
    local text = i and REQ_LINES[i]
    if not text then return nil end
    return { GetText = function() return text end }
end

Valuate.ParseStatsFromTooltip = function() return STATS_BY_NAME[CURRENT_NAME] end
Valuate.GetPrivateTooltip = function()
    return { ClearLines = function() end,
             SetCraftSpell = function() end,
             SetTradeSkillItem = function() end }
end

local function reqFor(...)
    REQ_LINES = { ... }
    ns.ResetEnhanceCache()
    local bySlot = ns.CollectEnhancements()
    for _, e in ipairs(bySlot[8] or {}) do
        if e.name == "Enchant Boots - Greater Assault" then return e.reqLevel end
    end
end

eq(reqFor("Enchant Boots", "Requires a level 60 or higher item"), 60,
   "the common wording is read")
eq(reqFor("Enchant Boots", "Requires item level 35 or higher"), 35,
   "and the other shape this client might use")
eq(reqFor("Enchant Boots", "+32 Agility"), nil,
   "a tooltip with no requirement yields nil, not zero")
eq(reqFor("Enchant Boots", "Requires Enchanting (375)"), nil,
   "a SKILL requirement is not an item-level one")
eq(reqFor(), nil, "an empty tooltip does not error")

-- Line 1 is the name. A recipe called "Enchant Boots - level 60 or higher item" would
-- otherwise supply its own requirement out of its title.
eq(reqFor("Requires a level 99 or higher item", "+32 Agility"), nil,
   "the name line is skipped, whatever it happens to say")

-- ---- a client that has neither api does not error ------------------------------------------------
GetMerchantNumItems = nil
GetNumTrainerServices = nil
eq(ns.CaptureMerchant(1000), 0, "no merchant api means nothing written, not an error")
eq(ns.CaptureTrainer(1000), 0, "and the same for trainers")

return failures, checks
`,
  "enhance",
  "the enhancement source probe"
);
