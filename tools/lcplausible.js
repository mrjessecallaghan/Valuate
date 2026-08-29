#!/usr/bin/env node
/*
 * @gate The sanity filter judges only where it has grounds to
 *
 * Runs the REAL Plausible.lua from Valuate-LootCollector.
 *
 * This module hides rows on the strength of a level table somebody typed. Two failures follow
 * from that and they are not symmetric:
 *
 *   a wrong KEEP   one implausible row stays on screen. You glance at it.
 *   a wrong HIDE   a real worldforged find silently never appears, and the only evidence that
 *                  it existed is an absence, which nobody can look at.
 *
 * So the assertions below are mostly about NOT judging: an item the client has not cached, a
 * zone the table has never heard of, an item with no level to read. Each of those is a
 * separate reason for having no opinion, and every one of them must leave the row alone.
 *
 * THE CENTRAL CLAIM, and the one thing here worth breaking on purpose: quality is never
 * evidence. An epic in a starter zone is the whole reason LootCollector exists on Ascension -
 * worldforged gear is generated and drops anywhere - so a filter that hid epics in starter
 * zones would hide precisely the finds the addon is for. Quality is what the complaint
 * NOTICED; level is what makes an entry wrong. The gate holds that line, because "hide epics
 * in low zones" is the obvious edit somebody makes later and it would gut the addon.
 *
 * WHY A LEVEL TABLE AT ALL. The real saved database on this account - 3,227 discoveries over
 * 121 zones - was taken apart before this module was written, and four cheaper signals were
 * tested against the entries a person would call obviously wrong. The item string's link
 * level: median 1 everywhere, it records the linker. Stock-Blizzard item ids: there are none,
 * every entry is an Ascension custom id. Item-id bands as level tiers: mean zone level came
 * out 20, 28, 30, 38, 43 - no relationship. Provenance: the suspects share the same finders,
 * observers and CONFIRMED status as everything else. Nothing LootCollector stores separates
 * them, which is why they are still there. The level lives in the client, and that is the
 * whole reason this module costs a GetItemInfo.
 *
 * NOTE: the source is in a SIBLING addon. This skips rather than fails when it is absent -
 * see tools/tsmratiotest.js for the argument.
 *
 * Usage:  node tools/lcplausible.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const SRC = path.resolve(ADDON_ROOT, "..", "Valuate-LootCollector", "Plausible.lua");
if (!fs.existsSync(SRC)) {
  console.log("SKIP  Valuate-LootCollector is not installed next to this addon; nothing to check.");
  process.exit(0);
}

const run = load([]);
const lua = fs.readFileSync(SRC, "utf8");

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

local ns = {}
local compile = loadstring or load
local chunk = assert(compile(${JSON.stringify(lua)}, "@Valuate-LootCollector/Plausible.lua"))
chunk("Valuate-LootCollector", ns)

local ELWYNN, NORTHSHIRE, EPL, MOLTEN = 31, 1238, 24, 697
local UNTAUGHT = 99999

-- ---- the four ways of having no opinion ------------------------------------------------------
--
-- Four different situations, one answer, and none of them is "hide it". Each is written out
-- separately because collapsing them is exactly how a filter starts treating "I could not
-- tell" as "no".
eq((ns.PlausibleVerdict(ELWYNN, 60, 200, false)), ns.UNKNOWN,
   "an item the client has not cached is not judged, however wrong it looks")
eq((ns.PlausibleVerdict(UNTAUGHT, 60, 200, true)), ns.UNKNOWN,
   "a zone the table has never been taught gets no opinion rather than a guess")
eq((ns.PlausibleVerdict(nil, 60, 200, true)), ns.UNKNOWN,
   "and neither does an entry with no zone on it at all")
eq((ns.PlausibleVerdict(ELWYNN, 0, 0, true)), ns.UNKNOWN,
   "an item with neither a requirement nor a level leaves nothing to compare")

-- Every one of those says WHY. A row that disappears with no reason is indistinguishable from
-- a broken addon, and this module hides things a person may reasonably disagree about.
for _, case in ipairs({
    { ELWYNN, 60, 200, false, "cached" },
    { UNTAUGHT, 60, 200, true, "zone" },
    { ELWYNN, 0, 0, true, "compare" },
}) do
    local _, why = ns.PlausibleVerdict(case[1], case[2], case[3], case[4])
    ok(type(why) == "string" and #why > 10,
       "not judging is explained, not silent: " .. tostring(case[5]))
end

-- ---- the complaint this module exists for ----------------------------------------------------
-- A level-60 requirement in a level 1-10 zone. This is the case that was reported.
local verdict, why = ns.PlausibleVerdict(ELWYNN, 60, 100, true)
eq(verdict, "implausible", "a level 60 requirement in Elwynn Forest could not have dropped there")
ok(why and why:find("60", 1, true) ~= nil, "and the reason quotes the item's requirement")
ok(why and why:find("10", 1, true) ~= nil, "and the zone's range, so the judgement can be argued with")

eq((ns.PlausibleVerdict(NORTHSHIRE, 40, 0, true)), "implausible",
   "the same in a starting valley, which is the tightest case there is")

-- ---- GENEROUS, on purpose --------------------------------------------------------------------
--
-- The request was for OBVIOUSLY incorrect entries. Every degree of aggression past that starts
-- hiding real finds, and a hidden find leaves no evidence that it was hidden.
eq((ns.PlausibleVerdict(ELWYNN, 10, 0, true)), "ok", "a level 10 requirement in a 1-10 zone is fine")
eq((ns.PlausibleVerdict(ELWYNN, 20, 0, true)), "ok",
   "and so is 20 - world drops routinely run above the zone")
eq((ns.PlausibleVerdict(ELWYNN, 25, 0, true)), "ok",
   "the margin is inclusive at its own boundary: exactly ceiling plus margin survives")
eq((ns.PlausibleVerdict(ELWYNN, 26, 0, true)), "implausible", "one past it does not")

-- Not just the starter zones. A high-level zone tolerates high-level gear.
eq((ns.PlausibleVerdict(EPL, 60, 0, true)), "ok", "level 60 gear in Eastern Plaguelands is ordinary")
eq((ns.PlausibleVerdict(MOLTEN, 60, 0, true)), "ok", "and in Molten Core it is the point")

-- ---- QUALITY IS NEVER EVIDENCE ---------------------------------------------------------------
--
-- THE ONE THAT MATTERS. Worldforged gear is generated and drops anywhere, so an epic in a
-- starter zone is the whole reason the addon this plugs into exists. "Hide epics in low zones"
-- is the obvious edit somebody makes later; it would gut the addon, and it would look right.
--
-- The proof is structural rather than argumentative: the function is not given quality at all.
-- A level-appropriate item in a starter zone survives no matter what colour it is, because
-- there is no parameter through which its colour could be known.
eq((ns.PlausibleVerdict(ELWYNN, 8, 15, true)), "ok",
   "a level-appropriate find in a starter zone survives - epic or not, it cannot tell")
eq((ns.PlausibleVerdict(NORTHSHIRE, 5, 12, true)), "ok",
   "and in a starting valley too")

-- ---- item level, the weaker signal ------------------------------------------------------------
-- Used ONLY when there is no requirement to read - rings and trinkets frequently have none -
-- and given more than twice the room, because the relationship to the zone is loose.
eq((ns.PlausibleVerdict(ELWYNN, 0, 200, true)), "implausible",
   "with no requirement, an item level of 200 in a 1-10 zone is still absurd")
eq((ns.PlausibleVerdict(ELWYNN, 0, 45, true)), "ok",
   "but 45 is inside the wider margin item level is given")
eq((ns.PlausibleVerdict(ELWYNN, 0, 50, true)), "ok", "-- and so is exactly the boundary")
eq((ns.PlausibleVerdict(ELWYNN, 0, 51, true)), "implausible", "-- one past it is not")

-- A readable requirement OUTRANKS item level. Worldforged gear can carry an item level far
-- above its requirement, and judging on the higher of the two would hide the good drops.
eq((ns.PlausibleVerdict(ELWYNN, 9, 300, true)), "ok",
   "a requirement you can meet settles it, whatever the item level says")

-- ---- what the filter does with a verdict --------------------------------------------------------
ok(ns.KeepPlausible(false, "implausible"), "switched off, it hides nothing at all")
ok(ns.KeepPlausible(true, "ok"), "switched on, a plausible row stays")
ok(ns.KeepPlausible(true, ns.UNKNOWN), "and so does one it could not judge")
ok(ns.KeepPlausible(true, nil), "and one nothing has looked at yet")
ok(not ns.KeepPlausible(true, "implausible"), "only a positive judgement hides anything")

-- ---- the count on the button ----------------------------------------------------------------
-- The NUMBER is what tells you whether to trust it. Two hidden in a zone reads as the filter
-- working; two hundred reads as the level table being wrong about that zone.
eq(ns.CountImplausible({ "ok", "ok" }), 0, "nothing hidden counts zero")
eq(ns.CountImplausible({ "implausible", "ok", "implausible" }), 2, "two hidden count two")
eq(ns.CountImplausible({}), 0, "an empty list counts zero")
eq(ns.CountImplausible(nil), 0, "and no list at all does not error")

-- ---- the table itself ---------------------------------------------------------------------------
-- Typed by hand from the game world, so the shape is worth checking mechanically.
local zones, worst = 0, nil
for zoneId, band in pairs(ns.ZONE_LEVELS) do
    zones = zones + 1
    if type(zoneId) ~= "number" or type(band) ~= "table" or #band ~= 2
       or type(band[1]) ~= "number" or type(band[2]) ~= "number"
       or band[1] < 1 or band[2] > 60 or band[1] > band[2] then
        worst = tostring(zoneId)
    end
end
eq(worst, nil, "every zone band is a sane 1-60 pair with its floor below its ceiling")
ok(zones > 90, "the table covers most of the world a level 1-60 character walks through")
eq(ns.ZoneCoverage(), zones, "and it can say how much, for the status report")

-- The eight racial starting areas by id, because they are the zones the complaint named and a
-- typo in one of them would quietly switch this whole module off exactly where it is wanted.
for _, id in ipairs({ 1238, 1244, 1240, 1243, 1239, 1245, 1241, 1242 }) do
    local band = ns.ZONE_LEVELS[id]
    ok(band ~= nil, "the starting valley " .. id .. " is in the table")
    ok(band and band[2] <= 10, "-- and is banded as low-level content")
end

-- Cities are deliberately ABSENT rather than banded 1-60. A wide band would read as a
-- judgement that happens never to fire; absence says plainly that there is no opinion.
eq(ns.ZONE_LEVELS[1519], nil, "Stormwind carries no band rather than a meaningless wide one")

return failures, checks
`,
  "lcplausible",
  "the discovery sanity filter"
);
