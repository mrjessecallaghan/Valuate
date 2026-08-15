-- ui/Enhance.lua
-- Item enhancements (enchants, leg armor, spellthread, scopes...) per slot, read LIVE.
--
-- WHY LIVE, and what that costs.
--
-- There is no trustworthy static catalogue of enhancements for this server. AtlasLoot ships
-- ~4,100 crafting spellIDs grouped by slot, but they are retail Wrath's, with no stats, no
-- source, no cost and no required level - and Ascension is a custom server that changes all
-- four. Shipping that table would produce a confident list of things that may not exist here.
--
-- So this reads what the CLIENT confirms, and nothing else. The cost is coverage: the client
-- only tells you about recipes you know, and only while the relevant window is open. An empty
-- panel therefore means "I have not been shown any yet", which is a different statement from
-- "there are none" - and the panel has to say which, because those two look identical and the
-- addon has made that exact mistake three times already (see CLAUDE.md).
--
-- WHAT THE CLIENT EXPOSES is itself unknown. AscensionEnchantAdvisor, the one addon here that
-- tries, probes FIVE different global names for Ascension's enchant collection API and takes
-- whichever answers. That is not a criticism of it - it is evidence that nobody knows. So the
-- first thing in this file is a probe that reports what actually exists, rather than code
-- written against a guess.

local _, ns = ...

-- ---------------------------------------------------------------------------------------
-- What can this client actually tell us?
-- ---------------------------------------------------------------------------------------
--
-- Named individually rather than counted, for the same reason the lint rules are: a probe
-- that reports "3 of 5 sources available" tells you nothing you can act on. Each entry says
-- what it is, so a missing one is a specific thing to go and find out about.
-- The names other addons have guessed at for Ascension's enchant API. Kept as data so the
-- probe can report on all of them at once rather than testing whichever one this file
-- happened to be written against.
ns.MYSTIC_PROVIDERS = {
    "C_MysticEnchant", "C_MysticEnchants", "MysticEnchantUtil",
    "MysticEnchantCollection", "EnchantCollection",
}

local SOURCES = {
    {
        key = "tradeskill",
        label = "Your open profession window",
        why = "The only source that reports what you can actually MAKE, with reagents.",
        test = function()
            return type(GetNumTradeSkills) == "function"
                and type(GetTradeSkillInfo) == "function"
                and type(GetTradeSkillRecipeLink) == "function"
        end,
        live = function()
            -- Zero is the honest answer when no window is open; it is not an error.
            return type(GetNumTradeSkills) == "function" and (GetNumTradeSkills() or 0) or 0
        end,
    },
    {
        key = "craft",
        label = "The Craft window (Enchanting on 3.3.5)",
        why = "Enchanting uses the CRAFT api rather than TradeSkill on this client version, " ..
              "so a build that only read tradeskills would miss enchants entirely.",
        test = function()
            return type(GetNumCrafts) == "function" and type(GetCraftInfo) == "function"
        end,
        live = function()
            return type(GetNumCrafts) == "function" and (GetNumCrafts() or 0) or 0
        end,
    },
    {
        key = "mystic",
        label = "Ascension's own enchant collection",
        why = "Custom to this server and undocumented. Five different global names have been " ..
              "guessed at by other addons; this reports which, if any, is real.",
        test = function()
            for _, name in ipairs(ns.MYSTIC_PROVIDERS) do
                if type(_G[name]) == "table" then return true end
            end
            return false
        end,
        live = function()
            local found = 0
            for _, name in ipairs(ns.MYSTIC_PROVIDERS) do
                if type(_G[name]) == "table" then found = found + 1 end
            end
            return found
        end,
    },
    {
        key = "spellinfo",
        label = "Spell name/description lookup",
        why = "Turns a recipe into a name and the stats it grants. Without it a list of " ..
              "enhancements cannot be scored or even labelled.",
        test = function() return type(GetSpellInfo) == "function" end,
        live = function() return 1 end,
    },
    {
        key = "merchant",
        label = "Merchant and trainer windows",
        why = "Where recipes are bought. Cost is recorded as you encounter it, because no " ..
              "data on this machine says where anything is sold or for how much.",
        test = function()
            return type(GetMerchantNumItems) == "function"
                and type(GetMerchantItemInfo) == "function"
        end,
        live = function()
            if type(GetMerchantNumItems) ~= "function" then return 0 end
            local ok, n = pcall(GetMerchantNumItems)
            return (ok and n) or 0
        end,
    },
}


-- Returns available, missing - two arrays of source entries.
function ns.ProbeEnhanceSources()
    local available, missing = {}, {}
    for _, src in ipairs(SOURCES) do
        local ok, present = pcall(src.test)
        if ok and present then
            local fine, count = pcall(src.live)
            available[#available + 1] = {
                key = src.key, label = src.label, why = src.why,
                count = (fine and count) or 0,
            }
        else
            missing[#missing + 1] = { key = src.key, label = src.label, why = src.why }
        end
    end
    return available, missing
end

function ns.PrintEnhanceProbe()
    local available, missing = ns.ProbeEnhanceSources()

    print("|cFF00FF00[Valuate]|r What this client can tell me about enhancements:")
    for _, s in ipairs(available) do
        print(string.format("  |cFF00FF00yes|r  %s |cFFAAAAAA(%d right now)|r", s.label, s.count))
    end
    for _, s in ipairs(missing) do
        print(string.format("  |cFFFF4040no|r   %s", s.label))
        print("        |cFFAAAAAA" .. s.why .. "|r")
    end

    -- The Ascension one is the one that decides how much of this feature is possible, so it
    -- gets named specifically rather than counted among the rest.
    local found = {}
    for _, name in ipairs(ns.MYSTIC_PROVIDERS) do
        if type(_G[name]) == "table" then found[#found + 1] = name end
    end
    if #found > 0 then
        print("  |cFF00FF00Ascension enchant API:|r " .. table.concat(found, ", "))
        for _, name in ipairs(found) do
            local supported = {}
            for _, m in ipairs({ "GetUnlockedEnchants", "GetKnownEnchants",
                                 "GetOwnedEnchants", "GetEnchants" }) do
                if type(_G[name][m]) == "function" then supported[#supported + 1] = m end
            end
            print(string.format("      %s -> %s", name,
                #supported > 0 and table.concat(supported, ", ") or "|cFFFF8800no known methods|r"))
        end
    else
        print("  |cFFFF8800Ascension enchant API: none of the five guessed names exists.|r")
        print("        |cFFAAAAAAEnhancements will come from your profession windows only, " ..
              "which means only ones you can already make.|r")
    end

    if #available == 0 then
        print("  |cFFFF4040Nothing at all.|r This is not a client Valuate can read enhancements from.")
    end
    return #available, #missing
end

-- ---------------------------------------------------------------------------------------
-- Which slot does an enhancement apply to?
-- ---------------------------------------------------------------------------------------
--
-- From the recipe NAME, because that is all a live recipe gives - "Enchant Boots - Greater
-- Assault" names its slot and nothing else does. Matched longest-first so "Enchant 2H Weapon"
-- cannot be swallowed by the "weapon" pattern, and so "Enchant Bracer" does not match on the
-- "race" inside it.
--
-- Order matters and is the whole correctness of this table, which is why the gate walks real
-- recipe names rather than the patterns.
local SLOT_PATTERNS = {
    { pattern = "2h weapon",  slots = { 16 } },
    { pattern = "two%-handed", slots = { 16 } },
    { pattern = "shield",     slots = { 17 } },
    { pattern = "off%-hand",  slots = { 17 } },
    { pattern = "shoulder",   slots = { 3 } },
    { pattern = "bracer",     slots = { 9 } },
    { pattern = "wrist",      slots = { 9 } },
    { pattern = "boot",       slots = { 8 } },
    { pattern = "feet",       slots = { 8 } },
    { pattern = "glove",      slots = { 10 } },
    { pattern = "hands",      slots = { 10 } },
    { pattern = "cloak",      slots = { 15 } },
    { pattern = "back",       slots = { 15 } },
    { pattern = "chest",      slots = { 5 } },
    { pattern = "leg",        slots = { 7 } },
    { pattern = "pants",      slots = { 7 } },
    { pattern = "head",       slots = { 1 } },
    { pattern = "helm",       slots = { 1 } },
    -- Rings take an enchant only for enchanters, but that is a question about whether YOU can
    -- apply it, not about which slot it belongs to. Both fingers, because an enchant that
    -- fits one fits the other.
    { pattern = "ring",       slots = { 11, 12 } },
    { pattern = "finger",     slots = { 11, 12 } },
    -- Last: "weapon" is a substring of nothing above it by this point, and putting it any
    -- earlier would claim every two-handed and off-hand recipe as a main-hand one.
    { pattern = "weapon",     slots = { 16, 17 } },
    { pattern = "staff",      slots = { 16 } },
}

-- KNOWN GAP, stated rather than papered over.
--
-- A whole family of enhancements names its slot nowhere: "Arcanum of Torment" is a head
-- enchant, "Earthen Leg Armor" happens to contain "leg" and is caught by luck rather than by
-- design, and Ascension may well have its own naming entirely. These return nil.
--
-- Nil is the right answer - guessing a slot puts an enhancement on gear it cannot go on,
-- which is worse than not offering it - but it is NOT the same as "this enhancement does not
-- exist", and the panel has to show these somewhere rather than drop them. That is the
-- "couldn't read these" section: an enhancement nobody could classify is still one you might
-- want, and silently discarding it would make the list look complete when it is not.
--
-- Returns an array of slotIds this enhancement can go on, or nil.
function ns.EnhancementSlots(name)
    if type(name) ~= "string" or name == "" then return nil end
    local lower = name:lower()
    for _, entry in ipairs(SLOT_PATTERNS) do
        if lower:find(entry.pattern) then return entry.slots end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------
-- Collecting what this character can actually apply
-- ---------------------------------------------------------------------------------------
--
-- TWO APIS, because 3.3.5 splits them: Enchanting lives behind the CRAFT api (GetNumCrafts,
-- GetCraftInfo) and every other profession behind TRADESKILL (GetNumTradeSkills). A build
-- that read one of them would silently miss the profession this feature is mostly about, and
-- would look like it was working the whole time.
--
-- Both only answer while their window is open. That is the price of live-only data and it is
-- the honest price: what comes back is what this character can genuinely do right now, rather
-- than a retail list that may not describe this server at all.

-- Stats come from the addon's OWN parser, against the addon's own hidden tooltip.
--
-- Writing a second parser for enchant descriptions was the obvious move and the wrong one.
-- ParseStatsFromTooltip already handles this server's stat wording, its abbreviations and its
-- oddities, and it is the thing every other number in this addon is built on. A second parser
-- would drift from it, and the drift would show up as enchants scored on a different basis
-- from the gear they go on - the one comparison this panel exists to make.
local function StatsFromTooltip(setter, index)
    if not Valuate.GetPrivateTooltip or not Valuate.ParseStatsFromTooltip then return nil end
    local tip = Valuate:GetPrivateTooltip()
    if not tip or type(tip[setter]) ~= "function" then return nil end

    local ok, stats = pcall(function()
        tip:ClearLines()
        tip[setter](tip, index)
        return Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
    end)
    if not ok then return nil end
    -- An EMPTY table is not the same as a failure to read. The caller distinguishes them:
    -- one is "this enhancement grants no weighted stats", the other is "I could not tell".
    return stats
end

-- The link is decoration - a hover target - never a fact the panel depends on. Some clients
-- return nil for a craft that produces no item (an enchant is cast, not made), and a few
-- error rather than returning nil, so this is wrapped and its failure is not interesting.
function ns.SafeLink(fn, index)
    if type(fn) ~= "function" then return nil end
    local ok, link = pcall(fn, index)
    return ok and link or nil
end

-- Returns bySlot, unreadable.
--
--   bySlot[slotId]  = { { name, slots, stats, source, index, link }, ... }
--   unreadable      = { { name, why }, ... }
--
-- `unreadable` is the whole reason this returns two things. An enhancement whose slot cannot
-- be worked out, or whose stats will not parse, is still one you might want - and dropping it
-- would make the panel look complete when it is not. It goes in its own section instead.
function ns.CollectEnhancements()
    local bySlot, unreadable = {}, {}
    local seen = {}

    local function consider(name, source, index, link)
        if type(name) ~= "string" or name == "" then return end
        -- Recipes appear in both lists on some clients, and a header row repeats its
        -- children's names. Keyed on name+source so the same enchant learned twice is one
        -- entry, while a genuinely different recipe of the same name from the other api
        -- is not silently swallowed.
        local key = name .. "\001" .. source
        if seen[key] then return end
        seen[key] = true

        local slots = ns.EnhancementSlots(name)
        if not slots then
            unreadable[#unreadable + 1] = { name = name, why = "could not tell which slot" }
            return
        end

        local stats = StatsFromTooltip(
            source == "craft" and "SetCraftSpell" or "SetTradeSkillItem", index)
        if not stats then
            unreadable[#unreadable + 1] = { name = name, why = "could not read its stats" }
            return
        end

        local entry = {
            name = name, slots = slots, stats = stats,
            source = source, index = index, link = link,
        }
        for _, slotId in ipairs(slots) do
            bySlot[slotId] = bySlot[slotId] or {}
            local list = bySlot[slotId]
            list[#list + 1] = entry
        end
    end

    -- Enchanting, via the Craft window.
    if type(GetNumCrafts) == "function" and type(GetCraftInfo) == "function" then
        for i = 1, (GetNumCrafts() or 0) do
            local ok, name, _, craftType = pcall(GetCraftInfo, i)
            -- A header is a category label, not something you can make. Its name is often a
            -- slot word too, so letting one through would put "Enchant Boots" in the list as
            -- if it were an enchant in its own right.
            if ok and name and craftType ~= "header" then
                consider(name, "craft", i, ns.SafeLink(GetCraftItemLink, i))
            end
        end
    end

    -- Leatherworking, Tailoring, Blacksmithing, Engineering - anything that makes an
    -- attachable enhancement rather than casting one.
    if type(GetNumTradeSkills) == "function" and type(GetTradeSkillInfo) == "function" then
        for i = 1, (GetNumTradeSkills() or 0) do
            local ok, name, skillType = pcall(GetTradeSkillInfo, i)
            if ok and name and skillType ~= "header" then
                consider(name, "tradeskill", i, ns.SafeLink(GetTradeSkillItemLink, i))
            end
        end
    end

    return bySlot, unreadable
end

-- ---------------------------------------------------------------------------------------
-- Ranking: best, then better-than-nothing
-- ---------------------------------------------------------------------------------------
--
-- The ordering the panel exists for. A +8 Armor enchant is worth having over an empty slot
-- even when it is nowhere near the best available, so the list does not stop at the winner -
-- it ranks everything you can apply and marks which is which. The second-best is not a
-- consolation prize; on a levelling character it is frequently the only one you can afford.

-- Effects that are not stats.
--
-- "Tuskarr's Vitality" grants movement speed. "Crusher" is a proc. Neither parses as a stat
-- and neither is worth zero, so scoring them at zero would rank them below a +4 Spirit enchant
-- for every character on the server.
--
-- These numbers are JUDGEMENT, not measurement, and are labelled as such wherever they reach
-- the screen. They exist so an effect enchant sorts sanely against a stat one - not to claim
-- a movement speed enchant is worth exactly 40 of anything. The alternative was to score them
-- zero, which is also a judgement, just a worse one that pretends not to be.
--
-- Keyed on words that appear in the enchant's NAME, because that is the only text guaranteed
-- to be there. Per-role rather than flat: a threat reduction is worth something real to a
-- damage dealer and actively unwanted by a tank.
ns.EFFECT_VALUES = {
    -- word,            dps,  tank, healer,  why
    { "tuskarr",         35,   35,   35,   "movement speed helps everyone equally" },
    { "speed",           30,   30,   30,   "movement or attack speed, and the name rarely says which" },
    { "crusher",         45,   25,    0,   "a melee damage proc" },
    { "berserking",      50,   20,    0,   "a large melee proc, at some survivability cost" },
    { "mongoose",        50,   25,    0,   "agility proc" },
    { "executioner",     45,   20,    0,   "armour penetration proc" },
    { "accuracy",        40,   30,    0,   "hit and crit, useful anywhere they are not capped" },
    { "spellpower",      40,    5,   40,   "flat spell damage and healing" },
    { "battlemaster",    10,   45,   20,   "a survivability proc" },
    { "stoneshield",      5,   50,    0,   "armour, which only a tank is really buying" },
    { "titanguard",       5,   45,    5,   "stamina, weighted toward the role that stacks it" },
    { "threat",          25,    0,   15,   "threat REDUCTION - wanted by damage, unwanted by tanks" },
    { "subtlety",        25,    0,   15,   "the older name for threat reduction" },
    { "greater",          5,    5,    5,   "a nudge, so 'Greater X' outranks plain 'X' on a tie" },
}

-- Which of the three columns above to read.
--
-- Derived from the SCALE rather than from a class, because this server is classless and the
-- scale is the only statement of intent the addon has. A scale that weights dodge and armour
-- is a tank's whether or not its owner calls it one.
function ns.RoleForScale(scale)
    if type(scale) ~= "table" or type(scale.Values) ~= "table" then return "dps" end
    local v = scale.Values
    local function w(...)
        local total = 0
        for _, key in ipairs({ ... }) do total = total + (tonumber(v[key]) or 0) end
        return total
    end
    local defensive = w("Dodge", "DodgeRating", "Parry", "ParryRating", "BlockValue",
                        "BlockRating", "Defense", "DefenseRating", "Armor", "Resilience")
    local healing = w("Healing", "HealingPower", "Mp5", "ManaRegen", "Spirit")
    local offensive = w("AttackPower", "SpellPower", "Crit", "CritRating", "Haste",
                        "HasteRating", "Agility", "Strength", "Intellect")

    -- Compared against the offensive weight rather than each other, because almost every
    -- scale carries some of all three. What separates a tank's scale is that its defensive
    -- weights are comparable to its offensive ones, not that it has any at all.
    if defensive > offensive * 0.6 then return "tank" end
    if healing > offensive * 0.6 then return "healer" end
    return "dps"
end

-- Returns score, estimated.
--
-- `estimated` is true when any part of the score came from the judgement table above. The
-- panel shows it, because a number derived from someone's opinion about movement speed should
-- not sit in the same column as one derived from your own stat weights without saying so.
function ns.ScoreEnhancement(entry, scale, scaleName)
    if not entry then return 0, false end

    local score = 0
    if entry.stats and Valuate.CalculateItemScore and scaleName then
        local ok, value = pcall(Valuate.CalculateItemScore, Valuate, entry.stats, scaleName)
        if ok and type(value) == "number" then score = value end
    end

    local role = ns.RoleForScale(scale)
    local column = (role == "tank" and 3) or (role == "healer" and 4) or 2
    local estimated = false
    local lower = (entry.name or ""):lower()
    for _, effect in ipairs(ns.EFFECT_VALUES) do
        if lower:find(effect[1], 1, true) then
            score = score + effect[column]
            estimated = true
        end
    end

    return score, estimated
end

-- Ranks what can go in one slot. Returns an array, best first.
function ns.RankForSlot(bySlot, slotId, scale, scaleName)
    local list = bySlot and bySlot[slotId]
    if not list then return {} end

    local out = {}
    for _, entry in ipairs(list) do
        local score, estimated = ns.ScoreEnhancement(entry, scale, scaleName)
        out[#out + 1] = { entry = entry, score = score, estimated = estimated }
    end

    -- Tie-broken on NAME, which is unique per slot, because the source order is whatever the
    -- profession window happened to list and would reshuffle the panel between openings.
    table.sort(out, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return (a.entry.name or "") < (b.entry.name or "")
    end)
    return out
end
