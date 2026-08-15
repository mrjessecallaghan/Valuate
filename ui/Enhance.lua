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
