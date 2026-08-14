#!/usr/bin/env node
/*
 * @gate Every spec's scale values survivability, at least a little
 *
 * Runs the real Valuate:ApplyDefensiveFloor over EVERY spec in both template sets.
 *
 * The gap this closes, measured before the fix: all 31 classic specs weight Stamina and a
 * token amount of Armor - Arms carries Stamina 0.2 and Armor 0.05 against a 1.0 top stat -
 * and all 52 Conquest of Azeroth specs carried NONE. Scored strictly, a CoA damage spec
 * treated two otherwise identical chestpieces as equal when one had 300 more stamina, which
 * is not what anybody means by "my best chest".
 *
 * The floors are the classic convention rather than a number someone liked: 0.20 and 0.05,
 * as a fraction of that spec's OWN top weight, so a spec whose weights are scaled differently
 * gets a proportionate floor instead of a wrong absolute one.
 *
 * Two things matter as much as the floor itself:
 *   IT ONLY RAISES. A tank at Stamina 1.0 keeps it; an author who deliberately valued Armor
 *   keeps that. A floor that can lower a weight is overruling a decision, not filling a gap.
 *   IT DOES NOT MUTATE THE TEMPLATE. Templates are shared, read many times per session, and
 *   a floor written back into one would compound on every later read.
 *
 * Usage:  node tools/defensive.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load(["ui/Shared.lua", "ui/Data.lua"]);

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
Valuate = Valuate or {}

` + require("fs").readFileSync(
      require("path").join(require("./luaharness.js").ADDON_ROOT, "Valuate.lua"), "utf8"
    ).match(/^local DEFENSIVE_FLOORS = \{[\s\S]*?\r?\n\}/m)[0] + `
` + require("fs").readFileSync(
      require("path").join(require("./luaharness.js").ADDON_ROOT, "Valuate.lua"), "utf8"
    ).match(/^function Valuate:ApplyDefensiveFloor\([\s\S]*?\r?\nend/m)[0] + `

local function topWeight(t)
    local top = 0
    for _, w in pairs(t) do if type(w) == "number" and w > top then top = w end end
    return top
end

-- ---- every spec in every set -------------------------------------------------
local sets = {
    { name = "classic", data = ns.CLASS_SPEC_TEMPLATES },
    { name = "CoA", data = ns.COA_CLASS_SPEC_TEMPLATES },
}

local specCount, thin = 0, {}
for _, set in ipairs(sets) do
    ok(set.data ~= nil, set.name .. " templates exist")
    for _, class in ipairs(set.data or {}) do
        for _, spec in ipairs(class.specs or {}) do
            specCount = specCount + 1
            local floored = Valuate:ApplyDefensiveFloor(spec.weights, spec.role)
            local top = topWeight(floored)

            -- The requirement, stated as the user did: SOMETHING defensive is taken into
            -- account. Checked on every spec rather than a sample, because "all templates"
            -- is the claim and 101 of them is exactly the sort of list a spot-check misses.
            local stam = floored.Stamina or 0
            local armor = floored.Armor or 0
            if top > 0 and (stam + armor) <= 0 then
                thin[#thin + 1] = class.class .. "/" .. spec.name
            end
        end
    end
end

ok(specCount >= 100, "all specs were examined, got " .. specCount)
eq(#thin, 0, "every spec values survivability (bare: " .. table.concat(thin, ", ") .. ")")

-- ---- the floor is proportionate, and a minimum rather than a target ----------
local dps = { Strength = 1.0, CritRating = 0.8 }
local floored = Valuate:ApplyDefensiveFloor(dps, "DAMAGER")
eq(floored.Stamina, 0.2, "a DPS spec gets Stamina at 20% of its top weight")
eq(floored.Armor, 0.05, "and Armor at 5%")
eq(floored.Strength, 1.0, "its own weights are untouched")
eq(floored.CritRating, 0.8, "all of them")

-- Proportionate: a spec scaled to 10 gets 2, not 0.2. An absolute floor would be invisible
-- here and overwhelming on a spec scaled to 0.1.
local big = Valuate:ApplyDefensiveFloor({ Agility = 10, HitRating = 6 }, "DAMAGER")
eq(big.Stamina, 2, "the floor follows the spec's own scale, not an absolute number")
eq(big.Armor, 0.5, "for Armor too")

-- ---- it only ever raises ------------------------------------------------------
local sturdy = Valuate:ApplyDefensiveFloor({ Strength = 1.0, Stamina = 0.9, Armor = 0.4 }, "DAMAGER")
eq(sturdy.Stamina, 0.9, "a weight already above the floor is left alone")
eq(sturdy.Armor, 0.4, "including Armor")

-- Tanks are the case where a floor is meaningless at best: their weights already ARE the
-- defensive ones, and flooring against an offensive top stat would be actively wrong.
local tank = Valuate:ApplyDefensiveFloor({ Stamina = 1.0, DefenseRating = 0.8 }, "TANK")
eq(tank.Stamina, 1.0, "a tank keeps its own Stamina")
eq(tank.Armor, nil, "and gains nothing it did not ask for")

-- ---- the template itself is never modified -----------------------------------
-- Templates are shared and read many times a session. A floor written back would compound.
local source = { Strength = 1.0 }
Valuate:ApplyDefensiveFloor(source, "DAMAGER")
eq(source.Stamina, nil, "the source table is not mutated")
eq(next(source), "Strength", "and gains no keys at all")

local first = Valuate:ApplyDefensiveFloor(source, "DAMAGER")
local second = Valuate:ApplyDefensiveFloor(source, "DAMAGER")
eq(first.Stamina, second.Stamina, "so applying it twice gives the same answer")

-- ---- refusals -----------------------------------------------------------------
eq(Valuate:ApplyDefensiveFloor(nil, "DAMAGER"), nil, "nil weights are handled, not crashed on")
local empty = Valuate:ApplyDefensiveFloor({}, "DAMAGER")
eq(next(empty), nil, "an empty table gains nothing - there is no top weight to scale from")
local zeroed = Valuate:ApplyDefensiveFloor({ Strength = 0 }, "DAMAGER")
eq(zeroed.Stamina, nil, "all-zero weights gain nothing either")

return failures, checks
`,
  "defensive",
  "the defensive floor on every spec"
);
