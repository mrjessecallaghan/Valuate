#!/usr/bin/env node
/*
 * @gate Auto-roll never Needs what it does not want, and never Passes for free
 *
 * Runs the REAL source of DecideRollType from Valuate.lua, over its entire input space.
 *
 * This decision is taken automatically, in a group, on your behalf, and other people see the
 * result. Two properties carry all the weight:
 *
 *   * NEVER Need on something we do not want. Needing on gear you cannot use is the thing
 *     people get removed from groups for, and nobody asked you before it happened.
 *   * NEVER Pass when Greed is available. Passing costs you the item and gains nobody
 *     anything; if the addon is going to act by itself, the floor is "no worse than Greed".
 *
 * Three booleans is eight cases, so they are enumerated rather than sampled - the lesson
 * from the tooltip percentage, where hand-picked cases missed the branch that mattered. The
 * two properties above are then asserted over every one of the eight, so a ninth combination
 * (a fourth flag, say) cannot slip past them either.
 *
 * Usage:  node tools/rolltest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^local function DecideRollType\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `local function DecideRollType` in Valuate.lua - " +
      "it was renamed, moved or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

const run = load([]);

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

` + m[0] + `

local NEED, GREED, PASS = 1, 2, 0
local function label(b) return b and "yes" or "no" end

-- ---- the whole input space -------------------------------------------------
local cases = {}
for _, wants in ipairs({ true, false }) do
    for _, canNeed in ipairs({ true, false }) do
        for _, canGreed in ipairs({ true, false }) do
            cases[#cases + 1] = { wants = wants, canNeed = canNeed, canGreed = canGreed }
        end
    end
end
eq(#cases, 8, "eight combinations, all of them")

for _, c in ipairs(cases) do
    local roll, name = DecideRollType(c.wants, c.canNeed, c.canGreed)
    local where = "(want " .. label(c.wants) .. ", canNeed " .. label(c.canNeed) ..
                  ", canGreed " .. label(c.canGreed) .. ")"

    -- PROPERTY 1: Need only ever for something we want.
    if roll == NEED then
        ok(c.wants, "never Needs something it does not want " .. where)
        ok(c.canNeed, "never Needs when Need is not on offer " .. where)
    end

    -- PROPERTY 2: Pass only when there is genuinely nothing better.
    if roll == PASS then
        ok(not c.canGreed, "never Passes while Greed is available " .. where)
        ok(not (c.wants and c.canNeed), "never Passes something it wants and could Need " .. where)
    end

    -- The label always matches the number it was returned with; the chat line prints one
    -- and RollOnLoot gets the other, so disagreement would be a message that lies.
    local expected = (roll == NEED and "Need") or (roll == GREED and "Greed") or "Pass"
    eq(name, expected, "the printed label matches the roll actually made " .. where)

    -- And it always decides something.
    ok(roll == NEED or roll == GREED or roll == PASS, "always returns a real roll type " .. where)
end

-- ---- the specific answers, spelled out ---------------------------------------
-- The properties above would still hold if it Greeded everything, so the actual behaviour
-- is pinned too.
eq(select(1, DecideRollType(true, true, true)), NEED, "wanted and Need offered: Need")
eq(select(1, DecideRollType(true, true, false)), NEED, "Need offered without Greed: still Need")
eq(select(1, DecideRollType(true, false, true)), GREED,
   "wanted but Need not offered - a recipe above your skill - takes Greed")
eq(select(1, DecideRollType(true, false, false)), PASS, "wanted but nothing offered: Pass")
eq(select(1, DecideRollType(false, true, true)), GREED, "not wanted, Need offered anyway: Greed")
eq(select(1, DecideRollType(false, true, false)), PASS, "not wanted and only Need offered: Pass, not Need")
eq(select(1, DecideRollType(false, false, true)), GREED, "not wanted: Greed")
eq(select(1, DecideRollType(false, false, false)), PASS, "nothing offered at all: Pass")

-- ---- nil is not true ------------------------------------------------------------
-- GetLootRollItemInfo returns these flags straight from the client, and a nil canNeed must
-- behave as "not offered" rather than sneaking through a truthiness check.
eq(select(1, DecideRollType(true, nil, true)), GREED, "a nil canNeed is not an offer")
eq(select(1, DecideRollType(true, nil, nil)), PASS, "nil everywhere: Pass")
eq(select(1, DecideRollType(nil, true, true)), GREED, "a nil want is not a want")

return failures, checks
`,
  "rolltest",
  "the auto-roll decision"
);
