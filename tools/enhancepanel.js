#!/usr/bin/env node
/*
 * @gate The Enhance tab lists EVERY worn slot and each row says which of seven states it is in
 *
 * Builds ui/EnhancePanel.lua against a mocked WoW API.
 *
 * tools/enhance.js owns the hard questions - which slot an enhancement belongs to, how it
 * scores, what order they rank in. This gate does not repeat any of that. It asks the ones
 * that only exist once the answer is on screen:
 *
 *   - is there a row for every slot, including the ones with nothing to offer? That is the
 *     whole redesign: a panel that draws only what it found tells you nothing about what it
 *     missed, and four completely different situations all rendered as "absent";
 *   - does each of the seven states say its OWN thing, and never another one's? The states
 *     exist to be distinguished, so the assertions are written as "X says this and does not
 *     say what Y says";
 *   - do the runners-up stay visible, since "second best still beats nothing" is the whole
 *     ordering argument;
 *   - is an estimated score MARKED, rather than sitting silently beside a measured one;
 *   - and the one this project keeps getting wrong: does an empty panel distinguish "I have
 *     not been shown any yet" from "you have already done every slot"?
 *
 * That last is the third repeat of the same mistake in this codebase (see CLAUDE.md), so it
 * is the assertion this file exists for.
 *
 * Usage:  node tools/enhancepanel.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Enhance.lua",
  "ui/EnhancePanel.lua",
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

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:Hide() end
function GameTooltip:Show() end

-- ---- the state machine, before any of it reaches a frame -----------------------------------
-- Seven states, and the reason there are seven is that each is a different thing to tell you.
-- Walked directly rather than inferred from the screen, because a wrong branch here shows up
-- on screen as a plausible sentence about the wrong slot.
local function state(t) return ns.EnhanceSlotState(t) end

eq(state({ slotId = 8, hasItem = false }), "empty",
   "a slot with nothing in it is empty, whatever else is true of it")
eq(state({ slotId = 8, hasItem = false, known = 5, shown = 5, usable = 5 }), "empty",
   "and stays empty even when options exist - you cannot enchant a bare foot")

-- "none" and "unknown" are the pair this panel exists to separate. Trinkets take nothing;
-- boots take something I have simply never been shown.
eq(state({ slotId = 13, hasItem = true }), "none",
   "a slot no enhancement can go on says so")
eq(state({ slotId = 8, hasItem = true, known = 0 }), "unknown",
   "a slot that CAN take one but has none collected is a different answer")

-- ...unless it is already done. "None shown to me yet" reads as a job, and a slot with an
-- enchant on it is the one kind of slot that definitely is not one. Whether I happen to know
-- of any enchants for that slot is a fact about ME, not about your gear.
--
-- This ordering shipped wrong: the known-count check came first, so an enchanted slot on a
-- character whose professions had never been opened reported "none shown to me yet" for every
-- slot including the finished ones. Found by counting - the to-do list claimed two slots
-- needed attention when one of them was done.
eq(state({ slotId = 8, hasItem = true, hasEnchant = true, known = 0 }), "enhanced",
   "an enchanted slot is finished even when nothing is known for that slot")
ok(ns.ENHANCEABLE_SLOTS[8] and not ns.ENHANCEABLE_SLOTS[13],
   "and the two are decided by the pattern table, not by a second hand-written list")

eq(state({ slotId = 8, hasItem = true, hasEnchant = true, known = 3, shown = 3, usable = 3 }),
   "enhanced", "a slot with an enchant already on it is done")
-- Enchanted beats every complaint below it: an enchanted slot is not a problem to solve.
eq(state({ slotId = 8, hasItem = true, hasEnchant = true, known = 3, shown = 0, usable = 0 }),
   "enhanced", "even when the filter is hiding everything that could go on it")
eq(state({ slotId = 8, hasItem = true, hasEnchant = true, known = 3, shown = 3, usable = 0 }),
   "enhanced", "and even when nothing known is applicable at this item level")

-- Filtered before blocked. Both leave you looking at an empty list, and only one of them is a
-- fact about your character; calling a filtered slot "blocked" blames your gear for a button.
eq(state({ slotId = 8, hasItem = true, known = 4, shown = 0, usable = 0 }), "filtered",
   "options hidden by the profession filter say THAT")
eq(state({ slotId = 8, hasItem = true, known = 4, shown = 4, usable = 0 }), "blocked",
   "options that exist but need better gear are a different answer again")
eq(state({ slotId = 8, hasItem = true, known = 4, shown = 4, usable = 2 }), "recommend",
   "and one you can actually apply is the only state that is a recommendation")

-- Only two of the seven are jobs. A character with every slot enchanted is finished, not
-- seventeen-jobs-outstanding.
ok(ns.EnhanceStateIsActionable("recommend"), "a recommendation is something to do")
ok(ns.EnhanceStateIsActionable("blocked"), "so is a slot waiting only on better gear")
ok(not ns.EnhanceStateIsActionable("enhanced"), "an enhanced slot is not")
ok(not ns.EnhanceStateIsActionable("none"), "nor is one nothing goes on")
ok(not ns.EnhanceStateIsActionable("empty"), "nor an empty one")
ok(not ns.EnhanceStateIsActionable("unknown"), "nor one I have never been shown options for")
ok(not ns.EnhanceStateIsActionable("filtered"), "nor one the filter is hiding")

-- The two patterns added because listing every slot made their absence visible: a belt buckle
-- and a scope were being read correctly and then filed under "couldn't read these".
eq(ns.EnhancementSlots("Eternal Belt Buckle")[1], 6, "a belt buckle goes on the waist")
eq(ns.EnhancementSlots("Heartseeker Scope")[1], 18, "a scope goes on the ranged slot")

-- ---- the panel ------------------------------------------------------------------------------
-- What is on the character. Slot 8 (Feet) unenchanted, slot 5 (Chest) already enchanted, and
-- everything else bare.
local WORN = {
    [8] = "|Hitem:100:0|h[Boots]|h",
    [5] = "|cff1eff00|Hitem:200:12345|h[Chestplate]|h",
}
GetInventoryItemLink = function(_, slotId) return WORN[slotId] end

-- The worn item's EFFECTIVE level, from the TOOLTIP - which on a scaling server is a
-- different number from GetItemInfo's index 4, and index 4 is the template's.
--
-- TEMPLATE_LEVEL is deliberately set to something the tooltip disagrees with, so a reader
-- that went back to GetItemInfo would produce visibly wrong answers rather than the same
-- ones. The fixture used to supply one number through both routes, which is exactly how
-- this bug survived being written.
local WORN_LEVEL = 60
local TEMPLATE_LEVEL = 1
GetItemInfo = function() return "Item", nil, nil, TEMPLATE_LEVEL end
Valuate.GetStatsForTooltipSetter = function(_, setter, slotId)
    if setter ~= "SetInventoryItem" then return nil end
    return WORN_LEVEL and { ItemLevel = WORN_LEVEL } or nil
end

Valuate.GetPrimaryScale = function() return { Values = { Agility = 1 } }, "Dps" end
Valuate.CalculateItemScore = function(_, stats) return (stats and stats.Agility or 0) end

-- The collector is stubbed: this gate is about the PANEL, and tools/enhance.js already
-- proves the collecting against the real thing.
local COLLECTED, UNREADABLE = {}, {}
ns.CollectEnhancements = function() return COLLECTED, UNREADABLE end

-- The tab badge. Lives in ValuateUI.lua, which this gate does not load, so without a stub the
-- whole branch is skipped and any number at all would "pass".
local tabCount
ns.SetTabCount = function(_, n) tabCount = n end

local host = CreateFrame("Frame")
host:SetWidth(800)
host:SetHeight(500)

local function texts()
    local out = {}
    for _, f in ipairs(__frames) do
        for _, r in ipairs(f.__regions or {}) do
            if r.GetText and r:GetText() and r:IsShown() then out[#out + 1] = r:GetText() end
        end
    end
    return table.concat(out, "\\n")
end

local function visibleRows()
    local n = 0
    for _, f in ipairs(__frames) do
        if f.__enhanceRow and f:IsShown() then n = n + 1 end
    end
    return n
end

-- The text of one slot's row, so an assertion can say "the Feet row says X" rather than
-- "the panel somewhere contains X" - which was true of the whole panel for almost anything.
local function rowFor(slotName)
    for _, f in ipairs(__frames) do
        if f.__enhanceRow and f:IsShown() and f.slotName:GetText() == slotName then
            return (f.slotName:GetText() or "") .. "\\n" .. (f.worn:GetText() or "") .. "\\n" ..
                   (f.note:GetText() or "") .. "\\n" .. (f.best:GetText() or "") .. "\\n" ..
                   (f.alts:GetText() or "") .. "\\n" .. (f.score:GetText() or "")
        end
    end
    return nil
end

-- ---- nothing collected: "I have not looked" ---------------------------------------------
-- The distinction this project has got wrong three separate times. Not knowing any
-- enhancements and having already done every slot are OPPOSITE states that both produce an
-- empty list, and a panel that says the same thing for both is lying to one of them.
local panel = ns.CreateEnhancePanel(host)
ok(panel ~= nil, "the panel builds")
ok(type(ns.RefreshEnhancePanel) == "function", "and publishes a way to refresh it")

-- EVERY slot, even with nothing collected at all. This is the redesign: the old panel drew
-- zero rows here and the emptiness carried no information.
eq(visibleRows(), #ns.EQUIP_SLOTS, "every equipment slot gets a row, not only the useful ones")

-- And the sentence that used to live in the no-rows message still gets said. There are always
-- rows now, so leaving it there made the most important line in the panel unreachable:
-- seventeen slots each reading "none shown to me yet" states the problem and never the fix.
local said = texts()
ok(said:find("not been shown any", 1, true) ~= nil,
   "it says it has not been shown any yet, rather than that there are none")
ok(said:find("enhancecheck", 1, true) ~= nil,
   "pointing at the command that says what this client will tell it")
ok(said:find("Enchanting or a crafting profession", 1, true) ~= nil,
   "and at where they come from")
-- The promise the snapshot makes. Opening the window used to be necessary AND not sufficient:
-- you had to keep it open and then click through to this tab, which is nobody's instinct.
ok(said:find("just opening it is enough", 1, true) ~= nil,
   "telling you that opening it once is the whole job, because now it is")
ok(rowFor("Head") ~= nil, "including ones with nothing collected for them")
ok(rowFor("Trinket 1") ~= nil, "and ones no enhancement can go on")

-- Each of those two says its own thing. Head is worn-nothing here, so check the pair that
-- matters on a bare character: an unworn slot never claims to be missing an enchant.
ok(rowFor("Head"):find("nothing equipped", 1, true) ~= nil,
   "a slot with no item says nothing is equipped")
eq(rowFor("Head"):find("none shown to me yet", 1, true), nil,
   "and does not also claim I have not been shown options for it")

-- ---- options for a worn slot ---------------------------------------------------------------
COLLECTED = {
    [8] = {
        { name = "Enchant Boots - Greater Assault", slots = { 8 }, stats = { Agility = 32 }, source = "craft" },
        { name = "Enchant Boots - Assault",         slots = { 8 }, stats = { Agility = 20 }, source = "craft" },
        { name = "Enchant Boots - Minor Agility",   slots = { 8 }, stats = { Agility = 4 },  source = "craft" },
    },
    -- Slot 5 is worn AND already enchanted; slot 9 has options but nothing is worn there.
    [5] = {
        { name = "Enchant Chest - Powerful Stats", slots = { 5 }, stats = { Agility = 10 }, source = "craft" },
    },
    [9] = {
        { name = "Enchant Bracer - Superior Spellpower", slots = { 9 }, stats = { Agility = 8 }, source = "craft" },
    },
}
ns.RefreshEnhancePanel()

eq(visibleRows(), #ns.EQUIP_SLOTS, "still every slot")
local feet = rowFor("Feet")
ok(feet:find("Greater Assault", 1, true) ~= nil, "the best option is named on the Feet row")
ok(feet:find("Boots", 1, true) ~= nil, "beside the item it would go on")

-- THE ordering argument. A +8 armour enchant beats an empty slot even when it is nowhere near
-- best, so the runners-up stay on screen rather than hiding behind the winner.
ok(feet:find("Enchant Boots - Assault", 1, true) ~= nil, "the second best is still shown")
ok(feet:find("Minor Agility", 1, true) ~= nil, "and the third, because it still beats nothing")

-- The already-enchanted slot is a row now, and it neither hides nor overclaims. "Already
-- enhanced" is the most the item link supports: it says an enchant is present, not which one.
local chest = rowFor("Chest")
ok(chest ~= nil, "an already-enhanced slot has a row of its own")
ok(chest:find("already enhanced", 1, true) ~= nil, "which says the slot is done")
ok(chest:find("best I know for this slot", 1, true) ~= nil,
   "offering what it would pick, phrased as what it knows")
eq(chest:find("upgrade", 1, true), nil,
   "and never calling it an upgrade, which the link cannot support")

-- The tab badge counts JOBS, not rows. Every slot has a row now, so a row count would read
-- seventeen forever - a badge that never changes is a decoration.
eq(tabCount, 1, "the tab badge counts what there is to do, not how many rows were drawn")
ok(tabCount ~= visibleRows(), "which on this character is not the same number")

-- A slot with options but nothing worn is still not a recommendation. The row exists; the
-- enchant is not offered on it.
local wrist = rowFor("Wrist")
ok(wrist ~= nil, "a slot with options but no item still gets a row")
eq(wrist:find("Superior Spellpower", 1, true), nil,
   "but is not offered the enchant, because there is nothing to put it on")
ok(wrist:find("nothing equipped", 1, true) ~= nil, "it says why instead")

-- The coverage line, which is the panel read without reading it.
said = texts()
ok(said:find(tostring(#ns.EQUIP_SLOTS) .. " slots", 1, true) ~= nil,
   "a coverage line counts every slot")
ok(said:find("1 to enhance", 1, true) ~= nil, "and how many are jobs")
ok(said:find("1 already done", 1, true) ~= nil, "and how many are finished")
-- Only what happened. A summary listing six zeroes is a form, not a description. Named
-- categories rather than a bare "0 ", which would also match a score or a two-digit count.
for _, label in ipairs({ "to enhance", "waiting on better gear", "not shown to me yet",
                         "already done", "filtered out", "empty", "take none" }) do
    eq(said:find("0 " .. label, 1, true), nil, "no category is listed at zero: " .. label)
end

-- ---- "nothing goes here" and "none shown to me yet" ---------------------------------------
-- The pair the whole redesign turns on, now WORN so both render. A trinket takes no
-- enhancement and never will; a helm takes one I have simply never been shown. Before this
-- panel listed every slot they were both drawn the same way: not at all.
WORN[13] = "|Hitem:300:0|h[Figurine of the Colossus]|h"
WORN[1] = "|Hitem:400:0|h[Helm]|h"
ns.RefreshEnhancePanel()

local trinket = rowFor("Trinket 1")
ok(trinket:find("nothing goes here", 1, true) ~= nil,
   "a worn trinket says no enhancement goes on it")
eq(trinket:find("none shown to me yet", 1, true), nil,
   "and does not send you looking for one that cannot exist")

local head = rowFor("Head")
ok(head:find("none shown to me yet", 1, true) ~= nil,
   "a worn helm says I have not been shown any head enhancements")
eq(head:find("nothing goes here", 1, true), nil,
   "and does not claim the head slot takes none")
eq(head:find("nothing equipped", 1, true), nil,
   "nor that the slot is empty, which it is not")

ok(texts():find("1 not shown to me yet", 1, true) ~= nil,
   "the coverage line counts the two separately")
ok(texts():find("1 take none", 1, true) ~= nil, "one of each")

WORN[13], WORN[1] = nil, nil
ns.RefreshEnhancePanel()

-- ---- no scale means no ranking, and it says so -----------------------------------------------
-- Every number on this panel is your stat weights applied to an enchant. With no active scale
-- there are no weights, so everything lands on the same score and the list falls back to its
-- tiebreaker - alphabetical - under a heading promising "best first".
--
-- Said as the whole answer rather than a footnote, because the ordering IS the panel: with
-- nothing to rank by there is nothing here worth reading.
local realScale = Valuate.GetPrimaryScale
Valuate.GetPrimaryScale = function() return nil, nil end
ns.RefreshEnhancePanel()
eq(visibleRows(), 0, "with no scale there are no rows at all")
said = texts()
ok(said:find("nothing to rank these against", 1, true) ~= nil,
   "and it says why, rather than showing an ordering built on nothing")
ok(said:find("wizard", 1, true) ~= nil, "pointing at the thing that fixes it")

-- Distinct from the OTHER two empty states. Three different reasons for an empty panel, and a
-- panel that says the same thing for all of them is lying to two of the three.
eq(said:find("not been shown any", 1, true), nil,
   "not confused with never having been shown any enhancements")
eq(said:find("Nothing to do", 1, true), nil,
   "nor with having already done every slot")
-- And the coverage line goes with it: counting slots into categories built from a ranking
-- that does not exist would be the same false confidence in a smaller font.
eq(said:find("slots:", 1, true), nil, "and the coverage line is withdrawn too")

Valuate.GetPrimaryScale = realScale
ns.RefreshEnhancePanel()
ok(visibleRows() > 0, "and the rows come back once there is a scale again")

-- ---- an enchant you cannot apply is not a better one -----------------------------------------
-- Enchants carry an item-level floor. Offering a level-60 one for a level-20 chest is a
-- recommendation that cannot be acted on at all, which is the specific thing this panel exists
-- to save you from.
--
-- SORTED BELOW, not removed. The requirement is read from tooltip wording this code has never
-- seen on Ascension, so a wrong parse would silently delete real options. Demoting a usable
-- enchant is a visible annoyance; hiding one is invisible.
WORN_LEVEL = 20
COLLECTED = {
    [8] = {
        { name = "Enchant Boots - Greater Assault", slots = { 8 }, stats = { Agility = 32 },
          source = "craft", reqLevel = 60 },
        { name = "Enchant Boots - Minor Agility", slots = { 8 }, stats = { Agility = 4 },
          source = "craft", reqLevel = 1 },
    },
}
ns.RefreshEnhancePanel()

-- Which one is FIRST, not merely which appear. Both are on the row either way - one as the
-- recommendation, the other among the alternatives - so "Minor Agility is shown" was true
-- with the usable-first rule deleted entirely.
local lowGear = ns.RankForSlot(COLLECTED, 8, { Values = { Agility = 1 } }, "Dps", 20)
eq(lowGear[1].entry.name, "Enchant Boots - Minor Agility",
   "the weaker but USABLE enchant is the recommendation")
eq(lowGear[1].tooHigh, false, "and it is marked usable")
eq(lowGear[2].entry.name, "Enchant Boots - Greater Assault",
   "the stronger one you cannot apply sits below it")
eq(lowGear[2].tooHigh, true, "marked as out of reach")
ok(rowFor("Feet"):find("needs item level 60", 1, true) ~= nil,
   "and the row says what it needs, so its position is not arbitrary")

-- Every option out of reach is its own state, and it blames the gear rather than the addon.
COLLECTED = {
    [8] = {
        { name = "Enchant Boots - Greater Assault", slots = { 8 }, stats = { Agility = 32 },
          source = "craft", reqLevel = 60 },
    },
}
ns.RefreshEnhancePanel()
feet = rowFor("Feet")
ok(feet:find("needs item level 60", 1, true) ~= nil,
   "a slot whose every option is out of reach still names the option")
eq(feet:find("none shown to me yet", 1, true), nil,
   "and does not pretend it has never been shown one")
ok(texts():find("waiting on better gear", 1, true) ~= nil,
   "the coverage line counts it as waiting on gear, not as a job you can do")

-- Once the gear is good enough, the better one wins again.
WORN_LEVEL = 80
COLLECTED = {
    [8] = {
        { name = "Enchant Boots - Greater Assault", slots = { 8 }, stats = { Agility = 32 },
          source = "craft", reqLevel = 60 },
        { name = "Enchant Boots - Minor Agility", slots = { 8 }, stats = { Agility = 4 },
          source = "craft", reqLevel = 1 },
    },
}
ns.RefreshEnhancePanel()
local ranked80 = ns.RankForSlot(COLLECTED, 8, { Values = { Agility = 1 } }, "Dps", 80)
eq(ranked80[1].entry.name, "Enchant Boots - Greater Assault",
   "on gear that can take it, the strongest is first again")

-- An UNREADABLE requirement counts as usable. The alternative is demoting everything the
-- moment the tooltip wording differs from what this code expects.
local ranked = ns.RankForSlot({
    [8] = { { name = "Unknown Req", slots = { 8 }, stats = { Agility = 50 }, source = "craft" } },
}, 8, { Values = { Agility = 1 } }, "Dps", 5)
eq(ranked[1].tooHigh, false,
   "an enhancement with no readable requirement is treated as usable, not demoted on a guess")

-- And with no item level known - the client has not cached the item yet - nothing is demoted.
local uncached = ns.RankForSlot(COLLECTED, 8, { Values = { Agility = 1 } }, "Dps", nil)
eq(uncached[1].tooHigh, false, "an uncached item level demotes nothing")

WORN_LEVEL = 60
COLLECTED = {
    [8] = {
        { name = "Enchant Boots - Greater Assault", slots = { 8 }, stats = { Agility = 32 }, source = "craft" },
        { name = "Enchant Boots - Assault",         slots = { 8 }, stats = { Agility = 20 }, source = "craft" },
        { name = "Enchant Boots - Minor Agility",   slots = { 8 }, stats = { Agility = 4 },  source = "craft" },
    },
    [5] = {
        { name = "Enchant Chest - Powerful Stats", slots = { 5 }, stats = { Agility = 10 }, source = "craft" },
    },
}
ns.RefreshEnhancePanel()

-- ---- the 'only what I can act on' filter ------------------------------------------------------
-- Off by default: the panel's job is the whole picture, and a filter that hid most of it by
-- default would be the old behaviour under a new name.
eq(ns.EnhanceFilters.onlyActionable, false, "the panel shows everything until you ask it not to")

ns.EnhanceFilters.onlyActionable = true
ns.RefreshEnhancePanel()
eq(visibleRows(), 1, "ticked, only the slot with something to do survives")
ok(rowFor("Feet") ~= nil, "and it is the right one")
eq(rowFor("Chest"), nil, "the already-enhanced slot is gone")
eq(rowFor("Trinket 1"), nil, "so is the one nothing goes on")

ns.EnhanceFilters.onlyActionable = false
ns.RefreshEnhancePanel()
eq(visibleRows(), #ns.EQUIP_SLOTS, "unticking brings all of them back")

-- Every slot already done is NOT the same as knowing nothing, and must not say so. With the
-- filter on there is nothing to show, and the message has to name the right reason.
ns.EnhanceFilters.onlyActionable = true
WORN[8] = "|Hitem:100:999|h[Boots]|h"
ns.RefreshEnhancePanel()
eq(visibleRows(), 0, "with every slot enhanced there is nothing to act on")
said = texts()
ok(said:find("Nothing to do", 1, true) ~= nil,
   "and it says THAT, not that it has never been shown any")
eq(said:find("Nothing to act on, because", 1, true), nil,
   "the two empty states do not share a message")
WORN[8] = "|Hitem:100:0|h[Boots]|h"

-- And the other way round: nothing collected at all, with the filter on. Both are an empty
-- list and only one of them is about your character. Claiming "every slot is already
-- enhanced" to someone who has never opened a profession window is the exact mistake this
-- file exists to prevent, told backwards.
local realCollected = COLLECTED
COLLECTED = {}
ns.RefreshEnhancePanel()
eq(visibleRows(), 0, "nothing collected and the filter on leaves no rows")
said = texts()
ok(said:find("Nothing to act on, because", 1, true) ~= nil,
   "and it blames not having looked")
eq(said:find("already enhanced, takes", 1, true), nil,
   "not your character, whose slots it knows nothing about")
COLLECTED = realCollected

ns.EnhanceFilters.onlyActionable = false
ns.RefreshEnhancePanel()

-- ---- the profession filter ---------------------------------------------------------------------
-- A filtered-out slot says the filter did it. Reporting "none shown to me yet" would send you
-- to open a profession window you have already opened, to look for something the addon has.
ns.EnhanceFilters.source = "tradeskill"
ns.RefreshEnhancePanel()
feet = rowFor("Feet")
ok(feet:find("hidden by the profession filter", 1, true) ~= nil,
   "filtering to crafted tells you the enchanting options are hidden")
eq(feet:find("none shown to me yet", 1, true), nil,
   "rather than claiming it has never seen any")
eq(feet:find("Greater Assault", 1, true), nil, "and the hidden option is genuinely not shown")

ns.EnhanceFilters.source = "craft"
ns.RefreshEnhancePanel()
ok(rowFor("Feet"):find("Greater Assault", 1, true) ~= nil,
   "and filtering to enchanting shows them again")
ns.EnhanceFilters.source = "all"
ns.RefreshEnhancePanel()

-- ---- an estimated score is ADMITTED ------------------------------------------------------------
-- A number partly derived from someone's judgement about what a movement-speed proc is worth
-- should not sit in the same column as one derived from your own stat weights in silence.
COLLECTED = {
    [8] = { { name = "Enchant Boots - Tuskarr's Vitality", slots = { 8 }, stats = {}, source = "craft" } },
}
ns.RefreshEnhancePanel()
ok(rowFor("Feet"):find("~", 1, true) ~= nil,
   "a score built on the effect table is marked as an estimate")

-- ---- what could not be read is shown, not dropped -----------------------------------------------
UNREADABLE = {
    { name = "Arcanum of Torment", why = "could not tell which slot" },
    { name = "Dream Shard", why = "could not tell which slot" },
}
ns.RefreshEnhancePanel()
said = texts()
ok(said:find("could not read", 1, true) ~= nil, "the unreadable ones get their own section")
ok(said:find("Arcanum of Torment", 1, true) ~= nil,
   "and are NAMED - one nobody could classify is still one you might want")

UNREADABLE = {}
ns.RefreshEnhancePanel()
eq(texts():find("could not read", 1, true), nil,
   "and the section is gone when there is nothing in it")

-- ---- rows grow to fit BOTH their columns --------------------------------------------------------
-- Shipped as a flat 46px, which is the same defect fixed in the To Do panel three releases
-- earlier and then written again in a file created after that fix.
--
-- Both columns here wrap, independently: the left one carries the slot, the item on it and
-- where you saw the recipe (a seller, a subzone, a zone and a price), the right one the
-- recommendation and its runners-up with scores. Sizing to one of them puts the other through
-- the bottom of the row.
UNREADABLE = {}
COLLECTED = {
    [8] = { { name = "Enchant Boots - Assault", slots = { 8 }, stats = { Agility = 20 }, source = "craft" } },
}
ns.RefreshEnhancePanel()
local function feetHeight()
    for _, f in ipairs(__frames) do
        if f.__enhanceRow and f:IsShown() and f.slotName:GetText() == "Feet" then
            return f:GetHeight()
        end
    end
end
local plain = feetHeight()
ok(plain ~= nil, "a plain row has a height")

-- Now the LEFT column runs long: a vendor note with a seller, a subzone and a zone.
ns.LookupVendorNote = function()
    return 120000, "Alara the Enchantress", "The Threads of Fate, Dalaran"
end
ns.RefreshEnhancePanel()
local withNote = feetHeight()
ok(withNote > plain,
   "a row whose vendor note wraps is taller than one without (" .. tostring(plain) ..
   " vs " .. tostring(withNote) .. ")")
ns.LookupVendorNote = function() return nil end

-- And now the RIGHT column: three alternatives with scores, on one line.
COLLECTED = {
    [8] = {
        { name = "Enchant Boots - Greater Assault", slots = { 8 }, stats = { Agility = 32 }, source = "craft" },
        { name = "Enchant Boots - Tuskarr's Vitality", slots = { 8 }, stats = { Agility = 20 }, source = "craft" },
        { name = "Enchant Boots - Greater Vitality", slots = { 8 }, stats = { Agility = 12 }, source = "craft" },
        { name = "Enchant Boots - Superior Agility", slots = { 8 }, stats = { Agility = 4 }, source = "craft" },
    },
}
ns.RefreshEnhancePanel()
local withAlts = feetHeight()
ok(withAlts > plain,
   "a row whose alternatives wrap is taller too (" .. tostring(plain) ..
   " vs " .. tostring(withAlts) .. ")")

-- The list has to account for it, or the rows below run off the panel.
local listFrame
for _, f in ipairs(__frames) do
    if f.__enhanceRow then listFrame = listFrame or f:GetParent() end
end
ok(listFrame and listFrame:GetHeight() >= withAlts,
   "the list is at least as tall as the row it holds")

-- ---- seventeen rows do not fit, so the panel scrolls ---------------------------------------------
-- The old panel drew three and let anything past the bottom of the window run off it, which
-- was survivable at three and is not at seventeen.
local scroll, scrollBar
for _, f in ipairs(__frames) do
    if f.GetScrollChild and f:GetScrollChild() then scroll = scroll or f end
end
ok(scroll ~= nil, "the rows live inside a scroll frame")
ok(scroll:GetScrollChild():GetHeight() > listFrame:GetHeight() - 1,
   "whose child is tall enough to hold the whole list")
for _, f in ipairs(__frames) do
    if f.__template == "UIPanelScrollBarTemplate" then scrollBar = scrollBar or f end
end
ok(scrollBar ~= nil, "with a scrollbar")
local lo, hi = scrollBar:GetMinMaxValues()
eq(lo, 0, "that starts at the top")
ok(hi > 0, "and can reach the bottom of a list taller than the frame (" .. tostring(hi) .. ")")

-- How far there is to scroll depends on TWO numbers, and only one of them changes when the
-- list does. The other is the height of the frame you are reading it through - and that moves
-- on its own: the window animates to its tab height AFTER the refresh that computed the range,
-- and it is user-resizable besides. Computed once, the range is whatever fitted the PREVIOUS
-- tab, and the last row or two are unreachable.
local before = select(2, scrollBar:GetMinMaxValues())
scroll:SetHeight(scroll:GetHeight() - 120)
local after = select(2, scrollBar:GetMinMaxValues())
ok(after > before,
   "shrinking the frame lengthens the scroll range without waiting for a refresh (" ..
   tostring(before) .. " -> " .. tostring(after) .. ")")

scroll:SetHeight(scroll:GetHeight() + 120)
eq(select(2, scrollBar:GetMinMaxValues()), before, "and growing it back restores the range")

-- A bar that cannot move reads as a list that failed to load, so it goes away instead.
scroll:SetHeight(100000)
eq(select(2, scrollBar:GetMinMaxValues()), 0, "a frame taller than its list has nothing to scroll")
ok(not scrollBar:IsShown(), "and the scroll bar is hidden rather than sitting there inert")
scroll:SetHeight(200)
ok(scrollBar:IsShown(), "it comes back the moment there is something to scroll")

-- The thumb cannot be left parked past the new end of a shorter list.
scrollBar:SetValue(select(2, scrollBar:GetMinMaxValues()))
scroll:SetHeight(100000)
ok(scrollBar:GetValue() <= 0, "a bar scrolled to the bottom is pulled back when the list fits")
scroll:SetHeight(200)

-- ---- THE SCALED ITEM LEVEL ------------------------------------------------------------------
-- The bug this project already had once, in a feature written after the fix for it.
--
-- On a server that scales gear to your level, GetItemInfo's index 4 is the item TEMPLATE's
-- number and the tooltip is what the client renders for THIS character. Reading the template
-- demotes an enchant that says "requires a level 60 or higher item" on a chest the client is
-- displaying as item level 60 - buried under worse options, with a reason that reads as fact.
--
-- TEMPLATE_LEVEL is 1 throughout this file, so any reader that went back to GetItemInfo would
-- demote everything with a requirement.
COLLECTED = {
    [8] = {
        { name = "Enchant Boots - Greater Assault", slots = { 8 }, stats = { Agility = 32 },
          source = "craft", reqLevel = 60 },
        { name = "Enchant Boots - Minor Agility", slots = { 8 }, stats = { Agility = 4 },
          source = "craft", reqLevel = 1 },
    },
}
WORN_LEVEL = 60
ns.RefreshEnhancePanel()
feet = rowFor("Feet")
ok(feet:find("Greater Assault", 1, true) ~= nil,
   "an enchant the SCALED item can take is the recommendation")
eq(feet:find("needs item level", 1, true), nil,
   "and nothing is marked out of reach, because the client says the item is level 60")

-- The tooltip is unreadable: no constraint could be read, so nothing is demoted. Permissive on
-- purpose - an enchant wrongly offered sits at the top and does not work, which you can see. An
-- enchant wrongly demoted is buried under worse ones and looks like a considered ranking.
WORN_LEVEL = nil
ns.RefreshEnhancePanel()
eq(rowFor("Feet"):find("needs item level", 1, true), nil,
   "an unreadable item level demotes nothing, rather than falling back to the template number")
WORN_LEVEL = 60

-- ...and a genuinely low-level item still demotes, or the check has simply been switched off.
WORN_LEVEL = 20
ns.RefreshEnhancePanel()
ok(rowFor("Feet"):find("needs item level 60", 1, true) ~= nil,
   "gear the client really does show as low still demotes what it cannot take")
WORN_LEVEL = 60

-- ---- rows are pooled, not recreated ----------------------------------------------------------------
local before = #__frames
for _ = 1, 5 do ns.RefreshEnhancePanel() end
eq(#__frames, before, "refreshing does not create new frames")

-- ---- empty sockets, drawn on the row for the slot they are in -----------------------------------
--
-- This whole seam was unexercised. The fixture never supplied Valuate.FindEmptySockets, so
-- ns.SocketsBySlot answered "the socket reader is not loaded" on every refresh and the panel
-- ran permanently in its could-not-read state. Every assertion above was therefore made against
-- the degraded path, and the socket feature shipped in v0.202.0a had no gate touching the half
-- that reaches a screen.
--
-- The same shape as the v0.210.0a bug one level down: the gate entered through a door the
-- client does not use.
SOCKET_LIST, SOCKET_TOTAL, SOCKET_BLOCK = nil, 0, nil
Valuate.FindEmptySockets = function() return SOCKET_LIST, SOCKET_TOTAL, SOCKET_BLOCK end

SOCKET_LIST = { { slotId = 5, slotName = "Chest", sockets = 2 } }
SOCKET_TOTAL = 2
ns.RefreshEnhancePanel()

local chest = rowFor("Chest")
ok(chest ~= nil, "the chest row is drawn")
ok(chest and chest:find("2 empty sockets", 1, true) ~= nil,
   "a socketed item says how many of its sockets are bare, on its own row")

-- The pair. A slot with nothing to say must say nothing, or the note is decoration.
local feet = rowFor("Feet")
ok(feet ~= nil, "the feet row is drawn")
eq(feet and feet:find("empty socket", 1, true), nil,
   "a fully gemmed slot says nothing about sockets rather than claiming zero")

-- Asserted on the SUMMARY-ONLY half of that line. "2 empty sockets" also appears on the
-- chest row, so matching it here passed whether or not the summary said anything at all -
-- a mutation deleting the summary clause survived until this was pinned to the pointer,
-- which nothing else on the panel prints.
said = texts()
ok(said:find("/valuate sockets", 1, true) ~= nil,
   "and the summary carries the total, with the command to see them")

-- ---- could not read is not the same as none ---------------------------------------------------
-- Silence on a row reads as that slot being fine. Mid equipment swap that is the wrong answer,
-- delivered in the most reassuring possible way - so every worn row says so instead.
SOCKET_LIST, SOCKET_TOTAL, SOCKET_BLOCK = nil, 0, "an item is still being swapped"
ns.RefreshEnhancePanel()
chest = rowFor("Chest")
ok(chest and chest:find("sockets not read", 1, true) ~= nil,
   "when the sockets could not be read, a worn row SAYS so rather than falling silent")
said = texts()
ok(said:find("swapped", 1, true) ~= nil, "and the summary carries the reason")

-- A slot with nothing equipped has no socket claim either way - there is no item to have them.
local bareWrist = rowFor("Wrist")
if bareWrist then
    eq(bareWrist:find("sockets not read", 1, true), nil,
       "an empty slot is not reported as unreadable - there is nothing in it to read")
end

-- ---- back to a clean read ------------------------------------------------------------------------
SOCKET_LIST, SOCKET_TOTAL, SOCKET_BLOCK = nil, 0, nil
ns.RefreshEnhancePanel()
said = texts()
eq(said:find("sockets not read", 1, true), nil, "a clean read withdraws the warning")
eq(said:find("empty socket", 1, true), nil, "and claims no sockets when there are none")

return failures, checks
`,
  "enhancepanel",
  "the Enhance tab"
);
