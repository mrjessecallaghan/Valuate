#!/usr/bin/env node
/*
 * @gate Future upgrades group by the level that actually unlocks them
 *
 * Runs the REAL source of GroupFutureUpgrades from Valuate.lua.
 *
 * This is a levelling tool: it answers "is this worth carrying for another eight levels".
 * Two things make it worth executing rather than reading.
 *
 * One: an item can sit in the future list for reasons a LEVEL does not fix - an unmet weapon
 * proficiency, most often. Reporting those under "you'll get this at 42" is a promise the
 * addon cannot keep, so they come back in a separate list. Getting that split wrong is
 * invisible: the output still looks like a tidy plan.
 *
 * Two: an item that is a future upgrade for three scales is one line naming three, not three
 * lines. The de-duplication is keyed on the item link, and the level reported has to be the
 * LOWEST of the requirements seen, because that is the true answer to "when can I wear this".
 *
 * Usage:  node tools/futuretest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^local function GroupFutureUpgrades\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `local function GroupFutureUpgrades` in Valuate.lua - " +
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

tinsert = table.insert

` + m[0] + `

-- ---- nothing to say ------------------------------------------------------------
local byLevel, blocked = GroupFutureUpgrades({}, { "Melee" }, 30)
eq(#byLevel, 0, "no future data means no levels to report")
eq(#blocked, 0, "...and nothing blocked")

byLevel, blocked = GroupFutureUpgrades(nil, nil, 30)
eq(#byLevel, 0, "nil inputs are handled rather than raising")

-- ---- the ordinary case ----------------------------------------------------------
local BE = {
    Melee = { future = {
        [1]  = { itemLink = "|Hitem:1|h[Helm]|h",   reqLevel = 42 },
        [5]  = { itemLink = "|Hitem:2|h[Chest]|h",  reqLevel = 50 },
        [11] = { itemLink = "|Hitem:3|h[Ring]|h",   reqLevel = 42 },
    } },
}
byLevel, blocked = GroupFutureUpgrades(BE, { "Melee" }, 30)
eq(#byLevel, 2, "two distinct unlock levels")
eq(byLevel[1].level, 42, "the nearest level comes first")
eq(byLevel[2].level, 50, "...then the later one")
eq(#byLevel[1].items, 2, "both level-42 items are grouped together")
eq(#blocked, 0, "nothing is blocked by anything but level")

-- Sorted within a level too, so the list does not reshuffle between identical runs.
eq(byLevel[1].items[1].link, "|Hitem:1|h[Helm]|h", "items within a level are ordered")
eq(byLevel[1].items[2].link, "|Hitem:3|h[Ring]|h", "...deterministically")

-- ---- THE split: level met, still not wearable -----------------------------------
-- reqLevel 20 with a level-30 character means the level is not what is holding it back.
-- Reporting it as "you'll get this at 20" would be a promise the addon cannot keep.
BE = {
    Melee = { future = {
        [1]  = { itemLink = "|Hitem:1|h[Helm]|h", reqLevel = 42 },
        [16] = { itemLink = "|Hitem:9|h[Axe]|h",  reqLevel = 20 },
    } },
}
byLevel, blocked = GroupFutureUpgrades(BE, { "Melee" }, 30)
eq(#byLevel, 1, "only the genuinely-future item is listed by level")
eq(byLevel[1].level, 42, "...at its own level")
eq(#blocked, 1, "the one whose level is already met is reported separately")
-- Guarded: with the split broken, blocked is empty and a bare blocked[1].link dies with an
-- index error instead of naming the problem. A gate that crashes is worth less than one that
-- says what went wrong.
eq(blocked[1] and blocked[1].link, "|Hitem:9|h[Axe]|h", "...and it is the right item")

-- Exactly at your level counts as met: you are level 30 and it needs 30.
BE = { Melee = { future = { [1] = { itemLink = "|Hitem:5|h[X]|h", reqLevel = 30 } } } }
byLevel, blocked = GroupFutureUpgrades(BE, { "Melee" }, 30)
eq(#byLevel, 0, "a requirement exactly equal to your level is not 'future'")
eq(#blocked, 1, "...it is blocked by something else")

-- ---- one item, several scales ----------------------------------------------------
BE = {
    Melee = { future = { [1] = { itemLink = "|Hitem:7|h[Cloak]|h", reqLevel = 40 } } },
    Tank  = { future = { [1] = { itemLink = "|Hitem:7|h[Cloak]|h", reqLevel = 40 } } },
    Heal  = { future = { [1] = { itemLink = "|Hitem:7|h[Cloak]|h", reqLevel = 40 } } },
}
byLevel = GroupFutureUpgrades(BE, { "Melee", "Tank", "Heal" }, 30)
eq(#byLevel, 1, "one unlock level")
eq(#byLevel[1].items, 1, "the same item across three scales is ONE line, not three")
eq(#byLevel[1].items[1].scales, 3, "...naming all three scales")
eq(byLevel[1].items[1].scales[1], "Heal", "the scale names are sorted")
eq(byLevel[1].items[1].scales[3], "Tank", "...so the line does not reshuffle")

-- If two scales disagree about the requirement, the LOWEST wins: it is the same item, and
-- the earlier level is the true answer to "when can I wear this".
BE = {
    Melee = { future = { [1] = { itemLink = "|Hitem:8|h[Y]|h", reqLevel = 45 } } },
    Tank  = { future = { [1] = { itemLink = "|Hitem:8|h[Y]|h", reqLevel = 40 } } },
}
byLevel = GroupFutureUpgrades(BE, { "Melee", "Tank" }, 30)
eq(byLevel[1].level, 40, "the lowest requirement wins when scales disagree")

-- ---- inactive scales are not consulted -------------------------------------------
-- The caller passes the ACTIVE list; a scale you switched off should not put items on your
-- levelling plan.
BE = {
    Melee = { future = { [1] = { itemLink = "|Hitem:1|h[A]|h", reqLevel = 40 } } },
    Off   = { future = { [2] = { itemLink = "|Hitem:2|h[B]|h", reqLevel = 40 } } },
}
byLevel = GroupFutureUpgrades(BE, { "Melee" }, 30)
eq(#byLevel[1].items, 1, "only active scales contribute")
eq(byLevel[1] and byLevel[1].items[1].link, "|Hitem:1|h[A]|h", "...and it is the active one's item")

-- ---- junk in the data ------------------------------------------------------------
BE = {
    Melee = { future = {
        [1] = { reqLevel = 40 },                                  -- no link
        [2] = { itemLink = "|Hitem:3|h[C]|h" },                    -- no reqLevel
        [3] = { itemLink = "|Hitem:4|h[D]|h", reqLevel = 40 },
    } },
}
byLevel, blocked = GroupFutureUpgrades(BE, { "Melee" }, 30)
local total = #blocked
for _, g in ipairs(byLevel) do total = total + #g.items end
eq(total, 2, "an entry with no link is skipped; the rest survive")
-- A missing reqLevel reads as 0, which is met, so it lands in blocked rather than inventing
-- a level to promise.
eq(#blocked, 1, "a missing reqLevel does not become a fictional unlock level")

return failures, checks
`,
  "futuretest",
  "future upgrade grouping"
);
