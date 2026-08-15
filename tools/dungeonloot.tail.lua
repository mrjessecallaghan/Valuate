-- ============================================================================
-- The functions below are HAND-WRITTEN and appended verbatim by tools/genloot.js.
-- Edit them here, in tools/dungeonloot.tail.lua - not in the generated file.
-- ============================================================================

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
--
-- `extra` sections (trash tables, quest items, vendor lists) are checked for upgrades but are
-- NEVER counted as remaining. They cannot be killed, so counting them would leave the dungeon
-- permanently unfinished and the prompt would never fire at all.
function ns.CountRemainingUpgrades(dungeon, killed, isUpgrade)
    if type(dungeon) ~= "table" or type(dungeon.bosses) ~= "table" then return nil end
    killed = killed or {}

    -- Does any item in this list beat your gear?  true / false / nil for "cannot tell".
    local function listHasUpgrade(items)
        local unresolved = false
        for _, itemId in ipairs(items) do
            local answer = isUpgrade(itemId)
            if answer == true then return true end
            if answer == nil then unresolved = true end
        end
        if unresolved then return nil end
        return false
    end

    local remaining, upgrades, unknown = 0, 0, 0
    for _, boss in ipairs(dungeon.bosses) do
        if not killed[boss.name] then
            remaining = remaining + 1
            if not ns.BossLootKnown(boss) then
                unknown = unknown + 1   -- no list at all
            else
                local answer = listHasUpgrade(boss.items)
                -- An upgrade found outright settles the boss whatever else did not resolve:
                -- there is a reason to stay, and that is all the caller needs to know.
                if answer == true then
                    upgrades = upgrades + 1
                elseif answer == nil then
                    unknown = unknown + 1
                end
            end
        end
    end

    -- Trash and the like. Counted only as a reason to stay, never as something to finish.
    for _, section in ipairs(dungeon.extra or {}) do
        if ns.BossLootKnown(section) then
            local answer = listHasUpgrade(section.items)
            if answer == true then
                upgrades = upgrades + 1
            elseif answer == nil then
                unknown = unknown + 1
            end
        end
    end

    return remaining, upgrades, unknown
end
