#!/usr/bin/env node
/*
 * @gate A pasted string cannot quietly replace scales you already have
 *
 * Runs the real Valuate:IsValidScaleTagName, ParseMultipleScaleTags and ImportMultipleScales
 * from ImportExport.lua.
 *
 * This is the one place in the addon that takes UNTRUSTED INPUT and writes user data with it.
 * Somebody pastes a string out of guild chat and these three decide what lands in your scale
 * list. None of them had a gate; a corrected coverage scan turned them up, along with 66 other
 * published symbols the old scan could not see.
 *
 * The safety property is all-or-nothing, and it is easy to lose by making the code *more*
 * helpful. Without `overwrite`, a single name you already have blocks the ENTIRE import and
 * returns the conflicting names so the caller can ask you first. Importing "the ones that do
 * not clash" would look like an improvement and would mean a paste silently half-applied - and
 * a scale you spent an evening tuning is not something to replace on a guess.
 *
 * Three things carry the risk:
 *
 *   NOTHING IS WRITTEN ON A CONFLICT. Not the clashing scale, and not its innocent neighbours
 *   in the same paste either.
 *   A MALFORMED TAG IS COUNTED, NOT DROPPED. "3 imported" out of five, with two errors nobody
 *   mentioned, is worse than a refusal.
 *   A NAME IS NOT A KEY UNTIL IT IS CHECKED. Braces and pipes are the tag's own syntax, so a
 *   name carrying them can break every later parse of the same string.
 *
 * Usage:  node tools/bulkimport.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const NL = String.fromCharCode(10);
const src = fs.readFileSync(path.join(ADDON_ROOT, "ImportExport.lua"), "utf8");

function slice(name) {
  const start = src.indexOf("function Valuate:" + name + "(");
  if (start < 0) {
    console.error(
      "  SLICE  could not find Valuate:" + name + " in ImportExport.lua - it was renamed or " +
        "removed, so this gate is testing nothing"
    );
    process.exit(1);
  }
  const end = src.indexOf(NL + "end", start);
  return src.slice(start, end + 4);
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
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

strtrim = strtrim or function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

Valuate = {}
SCALES = {}
function Valuate:GetScales() return SCALES end

-- ParseScaleTag is gated separately in tools/importtest.js. Stubbed here so these three are
-- tested on their own terms: what they do with what it hands back, rather than re-testing it.
PARSED = {}
function Valuate:ParseScaleTag(tag)
    local p = PARSED[tag]
    if not p then return nil, nil, "unreadable tag" end
    return p.name, p.data
end

` + slice("IsValidScaleTagName") + `
` + slice("ParseMultipleScaleTags") + `
` + slice("ImportMultipleScales") + `

-- ---- a name is not a key until it is checked --------------------------------------------------
-- Braces and pipes are the tag format's own syntax. A name carrying one does not merely look odd
-- in a list: it can break every later parse of the same string.
ok(Valuate:IsValidScaleTagName("Tank"), "an ordinary name is fine")
eq(Valuate:IsValidScaleTagName(""), false, "an empty name is refused")
eq(Valuate:IsValidScaleTagName("   "), false, "and so is one that is only spaces")
eq(Valuate:IsValidScaleTagName(nil), false, "and a name that is not a string at all")
eq(Valuate:IsValidScaleTagName("Dps{"), false, "a name carrying a brace is refused")
eq(Valuate:IsValidScaleTagName("Dps}"), false, "either brace")
eq(Valuate:IsValidScaleTagName("Dps|cff00ff00"), false, "and one carrying a pipe")
ok(select(2, Valuate:IsValidScaleTagName("")) ~= nil, "a refusal says why")

-- ---- a malformed tag is COUNTED, not dropped ----------------------------------------------------
-- "3 imported" out of five, with two errors nobody mentioned, is worse than a refusal: you go
-- away believing you have scales that are not there.
local good = "{Valuate:GOOD}}"
local bad  = "{Valuate:BAD}}"
PARSED[good] = { name = "Fresh", data = { Values = { Agility = 1 } } }
local parsed, errors = Valuate:ParseMultipleScaleTags(good .. " " .. bad)
eq(#parsed, 1, "the readable tag is parsed")
eq(#errors, 1, "and the unreadable one is reported rather than skipped in silence")

eq(#(select(1, Valuate:ParseMultipleScaleTags(nil))), 0, "no text parses to nothing")
ok(pcall(Valuate.ParseMultipleScaleTags, Valuate, 42), "and a non-string is survivable")

-- ---- NOTHING IS WRITTEN ON A CONFLICT -------------------------------------------------------------
-- The property that matters. A scale you spent an evening tuning is not something to replace
-- because a string in guild chat happened to use the same name.
SCALES = { Fresh = { Values = { Strength = 99 }, mine = true } }
local okCount, failCount, existing = Valuate:ImportMultipleScales(good, false)
eq(okCount, 0, "an import that would clash writes nothing")
eq(existing and #existing, 1, "and hands back the name that clashed")
eq(existing and existing[1], "Fresh", "-- by name, so you can be asked about it")
eq(SCALES.Fresh.mine, true, "your scale is untouched")
eq(SCALES.Fresh.Values.Strength, 99, "right down to its weights")

-- ITS INNOCENT NEIGHBOURS TOO. Importing "the ones that do not clash" would look like an
-- improvement and would mean a paste silently half-applied.
local other = "{Valuate:OTHER}}"
PARSED[other] = { name = "Brand New", data = { Values = { Agility = 5 } } }
SCALES = { Fresh = { mine = true } }
okCount, failCount, existing = Valuate:ImportMultipleScales(good .. " " .. other, false)
eq(okCount, 0, "one clash blocks the WHOLE paste")
eq(SCALES["Brand New"], nil, "so the non-clashing scale in it is not written either")
eq(count(SCALES), 1, "nothing was added at all")

-- ---- the pair: with no clash it DOES import -------------------------------------------------------
-- Without this, "never write anything" would pass every assertion above.
SCALES = {}
okCount, failCount, existing = Valuate:ImportMultipleScales(good .. " " .. other, false)
eq(okCount, 2, "with nothing in the way, both scales import")
eq(existing and #existing or 0, 0, "and nothing is reported as clashing")
ok(SCALES.Fresh ~= nil and SCALES["Brand New"] ~= nil, "both are actually there")

-- ---- and overwrite means overwrite ------------------------------------------------------------------
-- You asked. The guard exists to make it a decision, not to make it impossible.
SCALES = { Fresh = { mine = true } }
okCount = Valuate:ImportMultipleScales(good, true)
eq(okCount, 1, "with overwrite asked for, the import proceeds")
eq(SCALES.Fresh.mine, nil, "and the old scale is genuinely replaced")

-- ---- an empty paste ----------------------------------------------------------------------------------
SCALES = {}
okCount, failCount = Valuate:ImportMultipleScales("nothing useful here", false)
eq(okCount, 0, "a string with no tags in it imports nothing")
eq(count(SCALES), 0, "and writes nothing")

return failures, checks
`,
  "bulkimport",
  "bulk scale import"
);
