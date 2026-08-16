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
    -- Two slots this table simply never covered, found by listing every slot on the panel
    -- instead of only the ones that already had options: a belt buckle adds a socket to the
    -- waist and a scope goes on a ranged weapon. Both were being read out of the profession
    -- window correctly and then filed under "couldn't read these" for want of a pattern.
    --
    -- Safe at the bottom because neither word appears in any pattern above and no pattern
    -- above appears in a buckle or scope name, so the order carries no risk either way.
    { pattern = "buckle",     slots = { 6 } },
    { pattern = "scope",      slots = { 18 } },
}

-- Which slots any enhancement could land on, DERIVED from the table above rather than written
-- out again beside it. A second hand-maintained list is a second thing to forget: adding
-- "buckle" above and not adding Waist here would make the panel say the belt slot takes
-- nothing while simultaneously offering it a buckle.
--
-- Membership only, so pairs order never reaches the screen.
ns.ENHANCEABLE_SLOTS = {}
for _, entry in ipairs(SLOT_PATTERNS) do
    for _, slotId in ipairs(entry.slots) do ns.ENHANCEABLE_SLOTS[slotId] = true end
end

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
-- Read once per recipe, not once per tab click.
--
-- The tab rebuilds on every arrival including a re-click - deliberately, because a profession
-- window that was shut last time makes a stale list worse than none. That meant one full
-- tooltip parse per recipe every time, and an enchanter with a filled book has a few hundred
-- of them. Correct, and needlessly expensive on a path a person clicks.
--
-- Safe to cache because an enchant's stats do not change. Keyed on NAME rather than index:
-- the index moves when the profession window is filtered or collapsed, and a cache keyed on a
-- moving number returns another recipe's stats rather than a miss.
local statsCache = {}

function ns.ResetEnhanceCache()
    statsCache = {}
end

-- What item level this enhancement needs.
--
-- Enchants carry a floor: "Requires a level 60 or higher item". Offering one for a level 20
-- chest is a recommendation that cannot be acted on at all, which is the specific thing this
-- panel exists to save you from.
--
-- THE WORDING IS NOT VERIFIED against Ascension. Two shapes are tried, and an unrecognised
-- line yields NIL - meaning "no requirement I could read", never zero and never a guess. The
-- panel shows a nil anyway, because hiding something real on an unverified parse is a worse
-- failure than showing something you cannot use.
local function RequiredItemLevel(tooltipName)
    local tip = _G[tooltipName]
    if not tip or not tip.NumLines then return nil end
    for i = 2, tip:NumLines() do
        local line = getglobal(tooltipName .. "TextLeft" .. i)
        local text = line and line.GetText and line:GetText()
        if text then
            local level = text:match("level (%d+) or higher item")
                or text:match("item level (%d+) or higher")
            if level then return tonumber(level) end
        end
    end
    return nil
end

-- Returns stats, requiredItemLevel.
--
-- Both out of ONE tooltip pass. Opening it twice per recipe is exactly the cost this file
-- spent a release removing, and the requirement is sitting in the same lines as the stats.
local function StatsFromTooltip(setter, index, name)
    local hit = name and statsCache[name]
    if hit then return hit.stats, hit.reqLevel end
    if not Valuate.GetPrivateTooltip or not Valuate.ParseStatsFromTooltip then return nil end
    local tip = Valuate:GetPrivateTooltip()
    if not tip or type(tip[setter]) ~= "function" then return nil end

    local ok, stats, reqLevel = pcall(function()
        tip:ClearLines()
        tip[setter](tip, index)
        return Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip"),
            RequiredItemLevel("ValuatePrivateTooltip")
    end)
    if not ok then return nil end

    -- Only a real read is remembered. A FAILED one is not cached, because the usual reason is
    -- that the tooltip was not ready yet - and caching that would make one bad moment
    -- permanent for the session.
    if name and stats then statsCache[name] = { stats = stats, reqLevel = reqLevel } end

    -- An EMPTY table is not the same as a failure to read. The caller distinguishes them:
    -- one is "this enhancement grants no weighted stats", the other is "I could not tell".
    return stats, reqLevel
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

        local stats, reqLevel = StatsFromTooltip(
            source == "craft" and "SetCraftSpell" or "SetTradeSkillItem", index, name)
        if not stats then
            unreadable[#unreadable + 1] = { name = name, why = "could not read its stats" }
            return
        end

        local entry = {
            name = name, slots = slots, stats = stats, reqLevel = reqLevel,
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
--
-- wornLevel, when given, is the item level of the thing in that slot. An enhancement needing
-- more than that CANNOT be applied - it is not a weaker option, it is not an option - so it
-- sorts below everything usable rather than competing on score.
--
-- Sorted below rather than REMOVED, deliberately. The requirement is read from tooltip wording
-- this code has never seen on Ascension, so a parse that is wrong would silently delete real
-- options. Demoting a usable enchant is a visible annoyance; hiding one is invisible.
function ns.RankForSlot(bySlot, slotId, scale, scaleName, wornLevel)
    local list = bySlot and bySlot[slotId]
    if not list then return {} end

    local out = {}
    for _, entry in ipairs(list) do
        local score, estimated = ns.ScoreEnhancement(entry, scale, scaleName)
        -- nil requirement means "none I could read", which is not the same as "none". It
        -- counts as usable, because the alternative is demoting everything on a parse failure.
        local tooHigh = (wornLevel and entry.reqLevel and entry.reqLevel > wornLevel) or false
        out[#out + 1] = {
            entry = entry, score = score, estimated = estimated, tooHigh = tooHigh,
        }
    end

    -- Tie-broken on NAME, which is unique per slot, because the source order is whatever the
    -- profession window happened to list and would reshuffle the panel between openings.
    table.sort(out, function(a, b)
        -- Usable first, whatever it scores. An enchant you cannot apply is not a weaker
        -- recommendation than one you can; it is not a recommendation.
        if a.tooHigh ~= b.tooHigh then return b.tooHigh end
        if a.score ~= b.score then return a.score > b.score end
        return (a.entry.name or "") < (b.entry.name or "")
    end)
    return out
end

-- What is this slot's situation, in one word.
--
-- The panel now draws a row for EVERY slot rather than only the ones with something to offer,
-- which turns "is there a row here" into a question the row itself has to answer. Five answers,
-- and the whole point is that they are five and not two - the previous panel collapsed all of
-- these into "shown" or "not shown", so a slot that takes no enhancement, a slot whose options
-- you have not learned yet and a slot you are wearing nothing in all looked identical: absent.
--
--   "empty"      nothing equipped. Cannot enhance what you are not wearing.
--   "none"       this slot takes no enhancement I have ever had a pattern for.
--   "unknown"    it takes one, but I have not been shown any yet. NOT the same as "none",
--                and the distinction is the one this project has got wrong three times.
--   "enhanced"   already has one on it.
--   "filtered"   options exist and the profession filter is hiding them. NOT "unknown":
--                that one sends you to open a profession window you already opened.
--   "blocked"    nothing on it, options exist, but every one needs a higher item level.
--   "recommend"  nothing on it, and here is what to put on.
--
-- A TABLE, not six positional arguments. Three of them are booleans and three are counts, so
-- positionally there are several wrong orders that type-check perfectly and silently answer a
-- different question.
--
--   slotId, hasItem, hasEnchant, known (before filtering), shown (after), usable (of shown)
--
-- Pure: no globals, no client. Everything it needs is an argument, so the gate can walk every
-- branch without a profession window.
function ns.EnhanceSlotState(info)
    info = info or {}
    if not info.hasItem then return "empty" end
    -- Asked before "have I seen any", because a slot with no pattern will never have any and
    -- reporting it as "not shown any yet" invites you to go and look for something that does
    -- not exist.
    if not ns.ENHANCEABLE_SLOTS[info.slotId] then return "none" end
    if (info.known or 0) <= 0 then return "unknown" end
    -- Before both of the checks below: an enchanted slot is done regardless of what the filter
    -- is hiding or what your item level allows, and either of those words would read as a
    -- problem to go and solve.
    if info.hasEnchant then return "enhanced" end
    -- Before "blocked", because the filter has already emptied the list the item-level count
    -- was taken from - so a filtered-out slot would otherwise report itself as blocked, which
    -- is a statement about your gear rather than about the button you just pressed.
    if (info.shown or 0) <= 0 then return "filtered" end
    if (info.usable or 0) <= 0 then return "blocked" end
    return "recommend"
end

-- Only "recommend" and "blocked" are things to go and do; the rest are statements of fact.
-- Used for the tab's count and the coverage line, so that a character with every slot enchanted
-- reads as finished rather than as seventeen outstanding jobs.
function ns.EnhanceStateIsActionable(state)
    return state == "recommend" or state == "blocked"
end

-- ---------------------------------------------------------------------------------------
-- Where a recipe was sold, and for how much - recorded as you meet it
-- ---------------------------------------------------------------------------------------
--
-- Nothing on this machine knows where anything is sold. AtlasLoot's crafting tables are
-- spellIDs and icons; there is no source, no cost, no coordinates. So the only honest way to
-- answer "where do I learn this" is to write it down when you are standing in front of it.
--
-- ACCOUNT-WIDE, unlike everything else this addon saves. Where a vendor stands is a fact about
-- the world, not about a character - a formula your enchanter found is still in the same shop
-- when your alt goes looking, and making each character rediscover it would be busywork the
-- addon exists to remove.
--
-- BOUNDED, because "record everything you ever see" is how a saved-variables file becomes a
-- problem nobody notices until it is one. Two things keep it small: only recipe-shaped items
-- are recorded at all, and the oldest entries are evicted past a cap.
ns.VENDOR_NOTE_CAP = 400
ns.VENDOR_NOTES_SCHEMA = 1

-- The words a teachable recipe carries in its name on this client. Deliberately narrow: the
-- alternative is a note on every grey shirt and stack of arrows in the game, which would blow
-- the cap in a single trip to a city and evict the notes actually worth keeping.
local RECIPE_WORDS = {
    "formula", "pattern", "plans", "design", "recipe", "schematic", "technique", "manual",
}

local function LooksLikeRecipe(name)
    if type(name) ~= "string" or name == "" then return false end
    local lower = name:lower()
    for _, word in ipairs(RECIPE_WORDS) do
        if lower:find(word, 1, true) then return true end
    end
    -- An enhancement sold directly rather than as a recipe - leg armor, a scope, a spellthread
    -- - is worth a note too, and those name their slot the same way a recipe does.
    return ns.EnhancementSlots(name) ~= nil
end

function ns.GetVendorNotes()
    if type(ValuateVendorNotes) ~= "table" then ValuateVendorNotes = {} end
    if ValuateVendorNotes.__schema ~= ns.VENDOR_NOTES_SCHEMA then
        for k in pairs(ValuateVendorNotes) do ValuateVendorNotes[k] = nil end
        ValuateVendorNotes.__schema = ns.VENDOR_NOTES_SCHEMA
    end
    return ValuateVendorNotes
end

-- Evicts the oldest notes once the cap is passed.
--
-- Oldest-first rather than least-used, because the addon has no idea which of these you care
-- about and inventing a usefulness score would be a guess dressed up as a policy. A note you
-- wrote three months ago is the one most likely to be about a vendor you have moved on from.
local function TrimVendorNotes(notes)
    local count = 0
    for k in pairs(notes) do
        if k ~= "__schema" then count = count + 1 end
    end
    if count <= ns.VENDOR_NOTE_CAP then return 0 end

    local ordered = {}
    for k, v in pairs(notes) do
        if k ~= "__schema" then ordered[#ordered + 1] = { key = k, at = v.at or 0 } end
    end
    -- Tie-broken on the key, because two notes written in the same second would otherwise
    -- evict in pairs() order and a different one would go each time the game loaded.
    table.sort(ordered, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.key < b.key
    end)

    local removed = 0
    for i = 1, count - ns.VENDOR_NOTE_CAP do
        notes[ordered[i].key] = nil
        removed = removed + 1
    end
    return removed
end

-- Returns how many notes were written or updated.
function ns.RecordVendorNote(name, cost, seller, where, when)
    if not LooksLikeRecipe(name) then return 0 end
    local notes = ns.GetVendorNotes()

    -- Updated rather than skipped when it already exists: prices differ by reputation and by
    -- server, and the note that matters is the one describing what YOU would pay.
    notes[name] = {
        cost = tonumber(cost) or 0,
        seller = seller,
        where = where,
        at = tonumber(when) or 0,
    }
    TrimVendorNotes(notes)
    return 1
end

-- Everything the merchant in front of you is selling that is worth remembering.
function ns.CaptureMerchant(now)
    if type(GetMerchantNumItems) ~= "function" or type(GetMerchantItemInfo) ~= "function" then
        return 0
    end
    local seller = (type(UnitName) == "function" and UnitName("npc")) or nil
    local where = ns.CurrentPlace()
    local written = 0
    local ok, total = pcall(GetMerchantNumItems)
    if not ok then return 0 end

    for i = 1, (total or 0) do
        local fine, name, _, price = pcall(GetMerchantItemInfo, i)
        if fine and name then
            written = written + ns.RecordVendorNote(name, price, seller, where, now)
        end
    end
    return written
end

-- And the trainer, which is where most enchanting recipes actually come from.
function ns.CaptureTrainer(now)
    if type(GetNumTrainerServices) ~= "function" or type(GetTrainerServiceInfo) ~= "function" then
        return 0
    end
    local seller = (type(UnitName) == "function" and UnitName("npc")) or nil
    local where = ns.CurrentPlace()
    local written = 0
    local ok, total = pcall(GetNumTrainerServices)
    if not ok then return 0 end

    for i = 1, (total or 0) do
        local fine, name = pcall(GetTrainerServiceInfo, i)
        if fine and name then
            local cost = 0
            if type(GetTrainerServiceCost) == "function" then
                local gotCost, value = pcall(GetTrainerServiceCost, i)
                if gotCost then cost = value or 0 end
            end
            written = written + ns.RecordVendorNote(name, cost, seller, where, now)
        end
    end
    return written
end

-- Zone plus subzone, which is as precise as this client will say without coordinates.
function ns.CurrentPlace()
    local zone = (type(GetRealZoneText) == "function" and GetRealZoneText()) or nil
    local sub = (type(GetSubZoneText) == "function" and GetSubZoneText()) or nil
    if sub and sub ~= "" and zone and zone ~= "" then return sub .. ", " .. zone end
    return zone or sub or nil
end

-- Returns cost, seller, where - or nil when this has never been seen.
function ns.LookupVendorNote(name)
    local notes = type(ValuateVendorNotes) == "table" and ValuateVendorNotes or nil
    local note = notes and name and notes[name]
    if not note then return nil end
    return note.cost, note.seller, note.where
end

-- The only thing in this file that does anything on its own.
--
-- Passive by design: it writes down what is already on screen in front of you and never
-- opens, buys or trains anything. There is no toggle because there is nothing to opt out of -
-- no gold moves, no item changes, and the cost of being wrong is a few hundred bytes.
local capture = CreateFrame("Frame")
capture:RegisterEvent("MERCHANT_SHOW")
capture:RegisterEvent("TRAINER_SHOW")

-- The stats cache is cleared whenever the book could have changed.
--
-- Without this, learning a recipe leaves it scored from whatever was cached before it existed
-- - or, more often, absent until you log out. That reads as the feature not seeing your new
-- enchant at all, which is a far worse failure than the re-reading the cache exists to avoid.
--
-- Both apis, and both of their update events: a window OPENING is when it first has contents,
-- and an UPDATE is what fires when you learn something with it already open.
capture:RegisterEvent("TRADE_SKILL_SHOW")
capture:RegisterEvent("TRADE_SKILL_UPDATE")
capture:RegisterEvent("CRAFT_SHOW")
capture:RegisterEvent("CRAFT_UPDATE")
capture:RegisterEvent("LEARNED_SPELL_IN_TAB")

capture:SetScript("OnEvent", function(_, event)
    if event ~= "MERCHANT_SHOW" and event ~= "TRAINER_SHOW" then
        ns.ResetEnhanceCache()
        return
    end
    -- Deferred by a tick. Both frames populate their lists AFTER the event fires, so reading
    -- immediately gets zero items and writes nothing - which looks exactly like a vendor with
    -- nothing worth noting.
    local now = (type(time) == "function" and time()) or 0
    local after = ns.ValuateAfter or (Valuate and Valuate.After)
    local function run()
        local written = 0
        if event == "MERCHANT_SHOW" then
            written = ns.CaptureMerchant(now)
        else
            written = ns.CaptureTrainer(now)
        end
        if written > 0 and Valuate.MarkAutomation then
            Valuate:MarkAutomation("vendorNotes", written .. " recipe(s) noted")
        end
    end
    if type(after) == "function" then after(0.2, run) else run() end
end)
