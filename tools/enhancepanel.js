#!/usr/bin/env node
/*
 * @gate The Enhance tab shows what each worn slot could still have, and admits what it cannot
 *
 * Builds ui/EnhancePanel.lua against a mocked WoW API.
 *
 * tools/enhance.js owns the hard questions - which slot an enhancement belongs to, how it
 * scores, what order they rank in. This gate does not repeat any of that. It asks the ones
 * that only exist once the answer is on screen:
 *
 *   - is a row built for a worn slot that has options, and not for one that has none;
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

-- What is on the character. Slot 8 (Feet) unenchanted, slot 5 (Chest) already enchanted.
local WORN = {
    [8] = "|Hitem:100:0|h[Boots]|h",
    [5] = "|Hitem:200:12345|h[Chestplate]|h",
}
GetInventoryItemLink = function(_, slotId) return WORN[slotId] end

Valuate.GetPrimaryScale = function() return { Values = { Agility = 1 } }, "Dps" end
Valuate.CalculateItemScore = function(_, stats) return (stats and stats.Agility or 0) end

-- The collector is stubbed: this gate is about the PANEL, and tools/enhance.js already
-- proves the collecting against the real thing.
local COLLECTED, UNREADABLE = {}, {}
ns.CollectEnhancements = function() return COLLECTED, UNREADABLE end

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

-- ---- nothing collected: "I have not looked" ---------------------------------------------
-- The distinction this project has got wrong three separate times. Not knowing any
-- enhancements and having already done every slot are OPPOSITE states that both produce an
-- empty list, and a panel that says the same thing for both is lying to one of them.
local panel = ns.CreateEnhancePanel(host)
ok(panel ~= nil, "the panel builds")
ok(type(ns.RefreshEnhancePanel) == "function", "and publishes a way to refresh it")

eq(visibleRows(), 0, "with nothing collected there are no rows")
local said = texts()
ok(said:find("not been shown any", 1, true) ~= nil,
   "and it says it has not been shown any yet, rather than that there are none")
ok(said:find("enhancecheck", 1, true) ~= nil,
   "pointing at the command that says what this client will tell it")

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

eq(visibleRows(), 1, "one row: the worn, unenchanted slot with options")
said = texts()
ok(said:find("Greater Assault", 1, true) ~= nil, "the best option is named")

-- THE ordering argument. A +8 armour enchant beats an empty slot even when it is nowhere near
-- best, so the runners-up stay on screen rather than hiding behind the winner.
ok(said:find("Enchant Boots - Assault", 1, true) ~= nil, "the second best is still shown")
ok(said:find("Minor Agility", 1, true) ~= nil, "and the third, because it still beats nothing")

-- A slot with options but nothing worn is not a row. An enchant for gear you do not have on
-- is a shopping catalogue, and this panel is a to-do list.
eq(said:find("Superior Spellpower", 1, true), nil,
   "a slot with nothing equipped in it is not offered")

-- ---- the 'only missing' filter -------------------------------------------------------------
ns.EnhanceFilters.onlyMissing = false
ns.RefreshEnhancePanel()
eq(visibleRows(), 2, "unticked, the already-enchanted slot appears too")
ok(texts():find("already enhanced", 1, true) ~= nil, "and says it already has one")

ns.EnhanceFilters.onlyMissing = true
ns.RefreshEnhancePanel()
eq(visibleRows(), 1, "and ticking it back hides that slot again")

-- Every slot already done is NOT the same as knowing nothing, and must not say so.
WORN[8] = "|Hitem:100:999|h[Boots]|h"
ns.RefreshEnhancePanel()
eq(visibleRows(), 0, "with every slot enhanced there is nothing to offer")
said = texts()
ok(said:find("already has an enhancement", 1, true) ~= nil,
   "and it says THAT, not that it has never been shown any")
eq(said:find("not been shown any", 1, true), nil,
   "the two empty states do not share a message")
WORN[8] = "|Hitem:100:0|h[Boots]|h"

-- ---- the profession filter -------------------------------------------------------------------
ns.EnhanceFilters.source = "tradeskill"
ns.RefreshEnhancePanel()
eq(visibleRows(), 0, "filtering to crafted hides the enchanting-only options")
ns.EnhanceFilters.source = "craft"
ns.RefreshEnhancePanel()
eq(visibleRows(), 1, "and filtering to enchanting shows them")
ns.EnhanceFilters.source = "all"

-- ---- an estimated score is ADMITTED ------------------------------------------------------------
-- A number partly derived from someone's judgement about what a movement-speed proc is worth
-- should not sit in the same column as one derived from your own stat weights in silence.
COLLECTED = {
    [8] = { { name = "Enchant Boots - Tuskarr's Vitality", slots = { 8 }, stats = {}, source = "craft" } },
}
ns.RefreshEnhancePanel()
ok(texts():find("~", 1, true) ~= nil, "a score built on the effect table is marked as an estimate")

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

-- ---- rows are pooled, not recreated ----------------------------------------------------------------
local before = #__frames
for _ = 1, 5 do ns.RefreshEnhancePanel() end
eq(#__frames, before, "refreshing does not create new frames")

return failures, checks
`,
  "enhancepanel",
  "the Enhance tab"
);
