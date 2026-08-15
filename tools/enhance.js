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

return failures, checks
`,
  "enhance",
  "the enhancement source probe"
);
