#!/usr/bin/env node
/*
 * @gate A settings snapshot carries preferences, never one character's identity
 *
 * Runs the real SaveSettingsSnapshot / LoadSettingsSnapshot against mocked options.
 *
 * The snapshot copies your settings onto your other characters, and the whole risk is what
 * it copies BY MISTAKE. Two categories must never travel:
 *
 *   THINGS THAT NAME A SCALE. "Arms (PvP)" exists on your Warrior and not on your
 *   Necromancer. Copied across, that character points at a scale that is not there - and
 *   for pvpScale specifically it would switch to nothing every time it zoned into a
 *   battleground, which looks exactly like the feature being broken.
 *
 *   IN-FLIGHT STATE. pvpScaleRestore records which scale to switch BACK to. It is
 *   bookkeeping from the middle of one character's battleground, and copying it makes an
 *   alt "restore" to a scale it was never using.
 *
 * pvpScale shipped in v0.109.0a and was not added to the exclusion list until v0.111.0a.
 * Nothing caught it because nothing tested this, which is what this file is for.
 *
 * Usage:  node tools/snapshottest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local SNAPSHOT_EXCLUDED = \{[\s\S]*?\r?\n\}/m,
  /^function Valuate:SaveSettingsSnapshot\([\s\S]*?\r?\nend/m,
  /^function Valuate:HasSettingsSnapshot\([\s\S]*?\r?\nend/m,
  /^function Valuate:LoadSettingsSnapshot\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return m[0];
});

/* The exclusion list is a claim about correctness, so it is also checked STATICALLY: every
 * option whose name says it points at a scale must be excluded. A future pvpScale2 would
 * otherwise repeat the exact bug this gate was written for. */
const excludedBlock = lua.match(/^local SNAPSHOT_EXCLUDED = \{[\s\S]*?\r?\n\}/m)[0];
const MUST_EXCLUDE = ["characterWindowScale", "pvpScale", "pvpScaleRestore"];
const missing = MUST_EXCLUDE.filter((k) => !new RegExp(`^\\s*${k}\\s*=\\s*true`, "m").test(excludedBlock));
if (missing.length) {
  console.error(
    "These options name a scale (or scale bookkeeping) and MUST be excluded from settings\n" +
      "snapshots, or an alt ends up pointing at a scale it does not have:\n" +
      missing.map((k) => "  " + k).join("\n")
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

Valuate = {}
local OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end
function Valuate:ResetTooltips() end
function Valuate:ScanBestEquipment() end
function Valuate:ApplyMinimapButtonOptions() end

-- Every key the loader will accept has to look like a real option.
--
-- The excluded keys carry NON-NIL defaults on purpose. Written as "pvpScale = nil" they are
-- simply absent from the table, so the loader's first condition (is this still a real
-- option?) refuses them and the exclusion check never runs - which let a mutation deleting
-- that exclusion survive. The two guards must be independently exercised.
DEFAULT_OPTIONS = {
    autoRelease = false, autoQueuePvP = false, keepFreeSlots = 4, showBestFor = true,
    characterWindowScale = "", pvpScale = "", pvpScaleRestore = "",
    uiPosition = "", professionOverrides = "",
    -- A table option that is NOT excluded, so the "never copy tables" rule has something to
    -- do. Every table in the first draft was also excluded by name, so that check was dead.
    windowLayout = "",
}

` + sliced.join("\n") + `

-- ---- what travels ------------------------------------------------------------
OPTIONS = {
    autoRelease = true,
    autoQueuePvP = true,
    keepFreeSlots = 8,
    showBestFor = false,
    -- must NOT travel
    characterWindowScale = "Arms",
    pvpScale = "Arms (PvP)",
    pvpScaleRestore = "Arms",
    uiPosition = { x = 1, y = 2 },
    professionOverrides = { Blacksmithing = true },
    -- Not excluded by name; kept out purely because it is a table. Copying it would alias
    -- two characters' settings to one object, so editing one would silently edit the other.
    windowLayout = { cols = 3 },
}
local saved = Valuate:SaveSettingsSnapshot()
ok(saved > 0, "a snapshot is taken")
eq(ValuateSettingsSnapshot.autoRelease, true, "plain preferences travel")
eq(ValuateSettingsSnapshot.keepFreeSlots, 8, "numbers too")
eq(ValuateSettingsSnapshot.showBestFor, false, "including ones set to false")

-- The whole point of the exclusion list.
eq(ValuateSettingsSnapshot.characterWindowScale, nil, "the active scale name does not travel")
eq(ValuateSettingsSnapshot.pvpScale, nil, "nor does the PvP scale name")
eq(ValuateSettingsSnapshot.pvpScaleRestore, nil, "nor mid-battleground bookkeeping")
eq(ValuateSettingsSnapshot.uiPosition, nil, "nor where you dragged the window")
eq(ValuateSettingsSnapshot.professionOverrides, nil, "nor this character's professions")
eq(ValuateSettingsSnapshot.windowLayout, nil,
   "and a table that is NOT on the exclusion list is still kept out, because sharing the " ..
   "object would alias two characters' settings")

-- Counted honestly: a count that includes keys it then drops is how the minimap-angle bug
-- looked correct for several releases.
local n = 0
for _ in pairs(ValuateSettingsSnapshot) do n = n + 1 end
eq(saved, n, "the reported count matches what was actually saved")

-- ---- loading onto another character ------------------------------------------
OPTIONS = {
    autoRelease = false,
    keepFreeSlots = 2,
    characterWindowScale = "Necro Frost",
    pvpScale = "Necro Frost (PvP)",
}
local okLoad, applied = Valuate:LoadSettingsSnapshot()
eq(okLoad, true, "the snapshot loads")
eq(OPTIONS.autoRelease, true, "preferences are applied")
eq(OPTIONS.keepFreeSlots, 8, "including numbers")

-- The alt's own scales are untouched. This is the failure that would look like the addon
-- breaking: zoning into a battleground and switching to a scale that does not exist.
eq(OPTIONS.characterWindowScale, "Necro Frost", "the target character keeps ITS active scale")
eq(OPTIONS.pvpScale, "Necro Frost (PvP)", "and ITS own PvP scale")
eq(applied, 4, "only the four real preferences were applied")

-- A key that is no longer an option cannot be reintroduced by an old snapshot.
ValuateSettingsSnapshot.someRemovedOption = 99
Valuate:LoadSettingsSnapshot()
eq(OPTIONS.someRemovedOption, nil, "a dead option in an old snapshot is ignored")

-- Even if an excluded key somehow got into an older snapshot, loading must refuse it.
ValuateSettingsSnapshot.pvpScale = "Arms (PvP)"
Valuate:LoadSettingsSnapshot()
eq(OPTIONS.pvpScale, "Necro Frost (PvP)",
   "an excluded key present in an old snapshot is still refused on load")

-- ---- nothing saved yet --------------------------------------------------------
ValuateSettingsSnapshot = nil
local none, why = Valuate:LoadSettingsSnapshot()
eq(none, false, "loading with nothing saved fails")
ok(type(why) == "string" and why ~= "", "and says so rather than silently doing nothing")

return failures, checks
`,
  "snapshottest",
  "the settings snapshot"
);
