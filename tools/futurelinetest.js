#!/usr/bin/env node
/*
 * @gate The future-upgrade tooltip line never invents a level
 *
 * Runs the REAL source of BuildFutureLine from Valuate.lua.
 *
 * This is the line that appears when you hover something you cannot use yet but will. The
 * addon has known that since future upgrades existed and has been quietly acting on it -
 * IsProtectedFromDelete keeps such items, so auto-delete has been sparing them without ever
 * saying why. The line exists so the decision at a vendor with a full bag is an informed one.
 *
 * Which makes what it CLAIMS the thing worth testing:
 *
 *   * The level must be the LOWEST requirement across the scales that want the item. It is
 *     one item; the earliest level is the true answer to "when can I wear this".
 *   * When there is no usable level - the item is held back by a proficiency rather than a
 *     level - it must drop the promise rather than print "at level 0". A tooltip that names
 *     a level you already passed is worse than one that stays vague.
 *   * nil when there is nothing to say, so callers can add it unconditionally.
 *
 * Usage:  node tools/futurelinetest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const m = lua.match(/^function Valuate:BuildFutureLine\(([\s\S]*?)\r?\nend\r?\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `function Valuate:BuildFutureLine` in Valuate.lua - " +
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
local function has(text, needle, what)
    checks = checks + 1
    if not text or not string.find(text, needle, 1, true) then
        table.insert(failures, what .. " (got " .. tostring(text) .. ", wanted it to contain " .. needle .. ")")
    end
end
local function hasnt(text, needle, what)
    checks = checks + 1
    if text and string.find(text, needle, 1, true) then
        table.insert(failures, what .. " (got " .. tostring(text) .. ", which must NOT contain " .. needle .. ")")
    end
end

tinsert = table.insert

-- The file-local the slice does not carry. Links here are "|Hitem:<id>|h[name]|h".
function GetItemIdFromLink(link)
    if not link then return nil end
    return tonumber(string.match(link, "|Hitem:(%d+)"))
end

local SCALES = {
    Melee = { DisplayName = "Melee",  Color = "FF8040" },
    Tank  = { DisplayName = "Tanking", Color = "4080FF" },
}
local FUTURE_SCALES = nil
local BEST = {}

Valuate = {
    GetFutureUpgradeScales = function() return FUTURE_SCALES end,
    GetBestEquipment = function() return BEST end,
    GetScales = function() return SCALES end,
}

` + m[0] + `

local LINK = "|Hitem:1234|h[Big Axe]|h"

-- ---- nothing to say ------------------------------------------------------------
FUTURE_SCALES = nil
eq(Valuate:BuildFutureLine(LINK), nil, "not a future upgrade: no line at all")
FUTURE_SCALES = {}
eq(Valuate:BuildFutureLine(LINK), nil, "an empty scale list is also no line")

-- ---- the ordinary case ----------------------------------------------------------
FUTURE_SCALES = { "Melee" }
BEST = { Melee = { future = { [16] = { itemLink = LINK, reqLevel = 42 } } } }
local line = Valuate:BuildFutureLine(LINK)
has(line, "level 42", "names the level the item unlocks at")
has(line, "Melee", "names the scale it is an upgrade for")
has(line, "FF8040", "...in that scale's colour")

-- ---- the LOWEST requirement wins -------------------------------------------------
-- Two scales, two recorded requirements for the same item. It is one item, so the earlier
-- level is the true answer; taking the higher one would tell you to wait longer than you
-- have to.
FUTURE_SCALES = { "Melee", "Tank" }
BEST = {
    Melee = { future = { [16] = { itemLink = LINK, reqLevel = 45 } } },
    Tank  = { future = { [16] = { itemLink = LINK, reqLevel = 40 } } },
}
line = Valuate:BuildFutureLine(LINK)
has(line, "level 40", "the lowest requirement across scales is the one reported")
hasnt(line, "level 45", "...and the higher one is not")
has(line, "Melee", "both scales are named")
has(line, "Tanking", "...using their display names")

-- ---- THE honesty case: no usable level --------------------------------------------
-- reqLevel 0 means the item is held back by something a level will not fix, most often an
-- untrained proficiency. "Upgrade at level 0" names a level you passed long ago and reads
-- as a bug; the line has to drop the promise instead.
FUTURE_SCALES = { "Melee" }
BEST = { Melee = { future = { [16] = { itemLink = LINK, reqLevel = 0 } } } }
line = Valuate:BuildFutureLine(LINK)
ok(line ~= nil, "still says the item is worth keeping")
hasnt(line, "level 0", "never claims 'at level 0'")
hasnt(line, "at level", "...and drops the level promise entirely rather than guessing")
has(line, "Melee", "but still names the scale")

-- A missing reqLevel behaves the same as zero: unknown is not a level.
BEST = { Melee = { future = { [16] = { itemLink = LINK } } } }
line = Valuate:BuildFutureLine(LINK)
hasnt(line, "at level", "a missing reqLevel does not become a claim either")

-- ---- a future record for a DIFFERENT item is not ours -----------------------------
-- The lookup walks every slot in the future table, so it has to match on item id rather
-- than take the first level it finds.
FUTURE_SCALES = { "Melee" }
BEST = { Melee = { future = {
    [1]  = { itemLink = "|Hitem:9999|h[Someone Else]|h", reqLevel = 11 },
    [16] = { itemLink = LINK, reqLevel = 42 },
} } }
line = Valuate:BuildFutureLine(LINK)
has(line, "level 42", "matches on the item, not on whatever record came first")
hasnt(line, "level 11", "...and does not report another item's level")

-- ---- a scale that no longer exists --------------------------------------------------
-- GetFutureUpgradeScales names a scale; the scales table is the authority on whether it is
-- still there. A deleted scale must not put an empty entry in the list.
FUTURE_SCALES = { "Ghost" }
BEST = { Ghost = { future = { [16] = { itemLink = LINK, reqLevel = 42 } } } }
eq(Valuate:BuildFutureLine(LINK), nil, "a scale that no longer exists produces no line")

return failures, checks
`,
  "futurelinetest",
  "the future-upgrade tooltip line"
);
