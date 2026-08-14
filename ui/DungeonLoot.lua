-- ui/DungeonLoot.lua
-- Which bosses in this dungeon can still drop something you would wear.
--
-- The ask: while auto-queueing dungeons, know whether anything left in here is an upgrade,
-- and say so once the last boss that could drop one is dead. Deadmines where only Mr Smite
-- has something for you should stay quiet until Smite is looted, then offer to leave.
--
-- ============================================================================
-- ABOUT THIS DATA - READ BEFORE EXTENDING IT
-- ============================================================================
-- Every item id below is a CLAIM about a server I cannot query, and a wrong id is worse
-- than a missing one: a missing id makes the addon say nothing, while a wrong one makes it
-- confidently tell you to leave a dungeon that had your boots in it.
--
-- So this table is deliberately SMALL and deliberately INCOMPLETE, and the code around it
-- is built so that incompleteness is safe:
--
--   A dungeon that is not listed produces NO ADVICE AT ALL. Not "nothing here for you" -
--   silence. The absence of data must never read as the presence of a negative answer.
--
--   A boss with an empty item list is treated as UNKNOWN, not as empty. Same reason.
--
-- Ascension is a modified server on top of 3.3.5, so even ids that are right for stock WotLK
-- may be wrong here. /valuate dungeon says exactly what is known for where you are standing,
-- so a wrong entry is visible rather than silently steering you.
--
-- Extending it: add a dungeon by the name GetInstanceInfo() reports, bosses in kill order,
-- and only ids you have actually seen drop. An id you are unsure of belongs in no list.

local _, ns = ...

ns.DUNGEON_LOOT = {
    -- Seeded with the example from the request so the mechanism has something real to run
    -- against. The item ids here are the ones this addon has been TOLD about rather than
    -- ones it verified; treat the list as a starting point and correct it from what you see.
    ["The Deadmines"] = {
        level = { 15, 25 },
        bosses = {
            { name = "Rhahk'Zor" },              -- no verified ids yet: unknown, not empty
            { name = "Sneed's Shredder" },
            { name = "Gilnid" },
            { name = "Mr. Smite" },
            { name = "Captain Greenskin" },
            { name = "Edwin VanCleef" },
        },
    },
}

-- What the addon knows about where you are standing.
--
-- Returns nil when it knows nothing, which every caller must treat as "say nothing" rather
-- than "there is nothing here". That distinction is the whole safety property of this file.
function ns.GetDungeonLoot(instanceName)
    if type(instanceName) ~= "string" or instanceName == "" then return nil end
    return ns.DUNGEON_LOOT[instanceName]
end

-- Has this boss got a list we can actually reason about?
--
-- A boss entry with no items is a boss nobody has filled in, NOT a boss that drops nothing.
-- Reading it as the latter is how a half-written table starts telling people to leave.
function ns.BossLootKnown(boss)
    return type(boss) == "table" and type(boss.items) == "table" and #boss.items > 0
end

-- Of the bosses still alive, how many could drop something you would wear?
--
-- `isUpgrade(itemId)` answers for one item and has THREE answers, not two:
--   true   this beats what you are wearing
--   false  it does not
--   nil    could not tell - the client has never seen this item, so it is not in its cache
--
-- That third answer is not pedantry. GetItemInfo returns nothing for an item you have never
-- encountered, and on a fresh login that is most of them. Reading "not cached" as "not an
-- upgrade" would make the addon most confident about leaving exactly when it knows least.
--
-- Returns:
--   remaining   how many bosses are still up
--   upgrades    how many of those have a known item that beats your gear
--   unknown     how many cannot be answered for - no loot data, or loot that would not resolve
--
-- The caller may only advise leaving when unknown is 0. With even one unanswerable boss left,
-- "no upgrades remain" is a guess wearing the clothes of a fact.
function ns.CountRemainingUpgrades(dungeon, killed, isUpgrade)
    if type(dungeon) ~= "table" or type(dungeon.bosses) ~= "table" then return nil end
    killed = killed or {}

    local remaining, upgrades, unknown = 0, 0, 0
    for _, boss in ipairs(dungeon.bosses) do
        if not killed[boss.name] then
            remaining = remaining + 1
            if not ns.BossLootKnown(boss) then
                unknown = unknown + 1   -- no list at all
            else
                local found, unresolved = false, false
                for _, itemId in ipairs(boss.items) do
                    local answer = isUpgrade(itemId)
                    if answer == true then
                        found = true
                        break
                    elseif answer == nil then
                        unresolved = true
                    end
                end
                -- An upgrade found outright settles the boss whatever else did not resolve:
                -- there is a reason to stay, and that is all the caller needs to know.
                if found then
                    upgrades = upgrades + 1
                elseif unresolved then
                    unknown = unknown + 1
                end
            end
        end
    end

    return remaining, upgrades, unknown
end
