#!/usr/bin/env node
/*
 * @gate Cross-checks spec templates against the stat definitions
 *
 * Cross-checks ui/Data.lua's class/spec templates against StatDefinitions.lua.
 *
 * Both files are pure data with no WoW API calls, and between them they hold roughly a
 * thousand stat keys typed by hand across ~45 spec templates. Every one is a plain
 * string, and a typo in any of them is completely silent: creating a scale from that
 * template produces a weight under a key nothing ever matches, so the stat simply does
 * not count. The template looks fine, the scale looks fine, and the scores are wrong.
 *
 * Nothing else can see this. luaparse is happy - it is a valid table. globals.js is
 * happy - they are table KEYS, not identifiers. Only comparing the two files catches
 * it, which is precisely the kind of hand-maintained agreement that has drifted seven
 * times in this project already.
 *
 * Usage:  node tools/datatest.js         (run from the addon root or tools/)
 * Exits non-zero on any mismatch.
 */
"use strict";

const { load } = require("./luaharness");

const run = load(["StatDefinitions.lua", "ui/Shared.lua", "ui/Data.lua"]);

const TESTS = `
local ns = __ns
local failures = {}
local checks = 0

local function ok(cond, msg)
    checks = checks + 1
    if not cond then table.insert(failures, msg) end
end

-- Valid stat-weight keys: everything the stat editor lays out in a column.
local validStats = {}
for _, cat in ipairs(ValuateStatCategories or {}) do
    for _, s in ipairs(cat.stats or {}) do validStats[s] = true end
end

-- Equipment-type rows: IsWand, IsShield, IsLibram and friends.
local validBans = {}
for _, cat in ipairs(ValuateEquipmentCategories or {}) do
    for _, s in ipairs(cat.stats or {}) do validBans[s] = true end
end

-- What "unusable" may contain is EVERY row the editor draws, not just the equipment
-- ones: the ban checkbox sits on each stat row too, so a plate-wearing spec bans
-- Intellect and SpellPower exactly the way it bans IsWand. Both category lists are
-- laid out as rows by the same code, which is why they share one ban namespace.
local validRows = {}
for k in pairs(validStats) do validRows[k] = true end
for k in pairs(validBans) do validRows[k] = true end

local nStats, nBans = 0, 0
for _ in pairs(validStats) do nStats = nStats + 1 end
for _ in pairs(validBans) do nBans = nBans + 1 end
ok(nStats > 20, "expected a substantial stat list; found " .. nStats)
ok(nBans > 5, "expected a substantial equipment-ban list; found " .. nBans)

-- ------------------------------------------------ every stat has a display name
-- The editor renders (ValuateStatNames[stat] or stat), so a missing entry does not
-- error - it shows the raw key. "ArmorPenetration" in a UI that says "Crit Rating"
-- everywhere else reads as a bug in the addon rather than a missing translation.
for stat in pairs(validStats) do
    ok(ValuateStatNames[stat] ~= nil,
        "stat '" .. stat .. "' is in a category but has no ValuateStatNames entry - the UI would show the raw key")
end

-- ...and no display name refers to a stat that no longer exists. That direction is
-- harmless at runtime but means the list is stale, which is how the first direction
-- goes wrong later.
for stat in pairs(ValuateStatNames or {}) do
    ok(validStats[stat] or validBans[stat],
        "ValuateStatNames has an entry for '" .. stat .. "', which is in no category - stale leftover?")
end

-- --------------------------------------------- template weights and bans resolve
local templates = ns.CLASS_SPEC_TEMPLATES
ok(type(templates) == "table" and #templates > 0, "CLASS_SPEC_TEMPLATES did not load")

local specCount, weightCount = 0, 0
for _, class in ipairs(templates or {}) do
    ok(type(class.class) == "string" and class.class ~= "", "a class entry has no name")
    ok(type(class.specs) == "table" and #class.specs > 0,
        "class '" .. tostring(class.class) .. "' has no specs")

    for _, spec in ipairs(class.specs or {}) do
        specCount = specCount + 1
        local where = tostring(class.class) .. "/" .. tostring(spec.name)

        ok(type(spec.name) == "string" and spec.name ~= "", where .. " has no spec name")
        ok(type(spec.icon) == "string" and spec.icon:find("Interface"), where .. " has no usable icon path")
        ok(type(spec.weights) == "table", where .. " has no weights table")

        -- Weights may reference ANY editor row, equipment types included. A libram is
        -- worth something to a paladin, and "IsLibram = 0.3" is how that is expressed:
        -- ValuateRelicTypePatterns turns a libram into stats.IsLibram at parse time, so
        -- the weight has something real to multiply. Checking weights against the stat
        -- categories alone flagged ten correct templates.
        local anyWeight = false
        for stat, value in pairs(spec.weights or {}) do
            weightCount = weightCount + 1
            ok(validRows[stat],
                where .. " weights '" .. stat ..
                "', which is no row the editor draws - it would silently never be scored")
            ok(type(value) == "number",
                where .. " weights '" .. stat .. "' with a " .. type(value) .. ", not a number")
            if type(value) == "number" and value ~= 0 then anyWeight = true end
        end
        ok(anyWeight, where .. " has no non-zero weight at all - the template would produce a scale that scores everything 0")

        for ban, value in pairs(spec.unusable or {}) do
            ok(validRows[ban],
                where .. " bans '" .. ban .. "', which is no row the editor draws - the ban would do nothing")
            ok(value == true, where .. " bans '" .. ban .. "' with " .. tostring(value) .. " rather than true")
        end

        -- A colour that HexToRGB cannot read now falls back to white rather than
        -- erroring, so a bad one here would be invisible - every spec the same shade.
        ok(type(spec.color) == "string" and #spec.color == 6 and not spec.color:find("[^0-9A-Fa-f]"),
            where .. " has colour '" .. tostring(spec.color) .. "', which is not six hex digits")
    end
end

ok(specCount > 20, "expected templates for many specs; found " .. specCount)
ok(weightCount > 200, "expected a lot of weights across the templates; found " .. weightCount)

-- ------------------------------------------------------------- the icon list
-- Every entry is offered in the icon picker, so a broken path is a blank button.
local icons = ns.SCALE_ICON_LIST
ok(type(icons) == "table" and #icons > 0, "SCALE_ICON_LIST did not load")
-- Exactly one empty entry, and it must come first: that is the "no icon" option that
-- clears a selection. A second one would be a dead cell in the grid; a missing one
-- would leave no way to remove an icon once set.
local emptyCount = 0
for i, entry in ipairs(icons or {}) do
    if entry == "" then
        emptyCount = emptyCount + 1
        ok(i == 1, "the empty 'no icon' entry must be first, but one is at position " .. i)
    else
        ok(type(entry) == "string" and entry:find("Interface"),
            "icon list entry " .. i .. " is not an Interface path: " .. tostring(entry))
    end
end
ok(emptyCount == 1, "expected exactly one empty 'no icon' entry; found " .. emptyCount)

-- NOT checked: duplicate icons. The same icon appears under more than one heading on
-- purpose - Trade_Engineering is under both "Gems & Crafting" and "Misc Useful Icons"
-- so it is findable either way. A gate that fails on a deliberate choice is worse than
-- no gate, which this project has already learned once from settings-anchor-chain.

return failures, checks
`;

run(TESTS, "datatest", "ui/Data.lua vs StatDefinitions.lua");
