#!/usr/bin/env node
/*
 * @gate The AdiBags junk hook only ever widens the junk set, and fails closed
 *
 * Runs the real mod:HookJunkModule from Valuate-AdiBags.
 *
 * This reaches into ANOTHER addon and replaces one of its methods. AdiBags' Junk module decides
 * what counts as junk; Valuate wraps that decision so gear the scan has marked surplus counts
 * too. Valuate's own auto-sell and auto-delete then read junk classification.
 *
 * So a bug here is not a display problem. It is the shortest path in this whole project from a
 * wrong answer to an item leaving your bags, and the one time this addon has actually cost
 * somebody something it was down this line: junk selling items that were upgrades.
 *
 * Valuate-AdiBags has no suite of its own. Until now its entire coverage was tools/api.js,
 * which checks that its calls into Valuate RESOLVE - not that any of them behave.
 *
 * Three properties, and the third is the one that matters:
 *
 *   ADDITIVE ONLY   the wrapper returns AdiBags' own verdict first and never contradicts it.
 *                   It can widen the junk set, never narrow it - Valuate does not get to
 *                   overrule the host addon about the host addon's own feature.
 *   IDEMPOTENT      installing twice would chain the wrapper around itself, so every check
 *                   runs the surplus test again per layer, on a path that runs per item per
 *                   bag repaint.
 *   FAILS CLOSED    IsSurplusGear reads scan data that may not be there. An error must mean
 *                   "not junk", because the alternative is an item being sold on the strength
 *                   of a read that did not happen - the exact shape of the bug this project
 *                   has now hit four times in other places.
 *
 * Usage:  node tools/junkhook.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const SRC = path.join(ADDON_ROOT, "..", "Valuate-AdiBags", "Valuate-AdiBags.lua");
if (!fs.existsSync(SRC)) {
  console.error("  SLICE  Valuate-AdiBags is not installed beside Valuate - nothing to check");
  process.exit(1);
}
const lua = fs.readFileSync(SRC, "utf8");

const m = lua.match(/^function mod:HookJunkModule\([\s\S]*?\r?\nend/m);
if (!m) {
  console.error(
    "  SLICE  could not find mod:HookJunkModule in Valuate-AdiBags.lua - it was renamed or " +
      "removed, so this gate is testing nothing"
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

-- The file-local the hook uses to remember it has run. Declared here because the slice below
-- refers to it, exactly as the real file does above the function.
local junkModule

mod = {}

-- What AdiBags itself thinks, and what Valuate thinks. Kept apart so an assertion can tell
-- which of the two produced an answer.
HOST_JUNK, SURPLUS, SURPLUS_ERRORS = {}, {}, false
HOST_CALLS, SURPLUS_CALLS = 0, 0

function mod:IsSurplusGear(itemId)
    SURPLUS_CALLS = SURPLUS_CALLS + 1
    if SURPLUS_ERRORS then error("no scan data") end
    return SURPLUS[itemId] or false
end

local function freshModule()
    return {
        ExtendedCheckItem = function(_, itemId)
            HOST_CALLS = HOST_CALLS + 1
            return HOST_JUNK[itemId] or false
        end,
    }
end

MODULE = nil
AdiBags = {
    GetModule = function(_, name) if name == "Junk" then return MODULE end return nil end,
}

` + m[0] + `

local function install(mod_)
    junkModule = nil
    MODULE = freshModule()
    mod:HookJunkModule()
    return MODULE
end

-- ---- ADDITIVE ONLY --------------------------------------------------------------------------
-- AdiBags' own verdict is returned first and is never contradicted. Valuate does not get to
-- overrule the host addon about the host addon's own feature.
local jm = install()
HOST_JUNK[11] = true
eq(jm:ExtendedCheckItem(11), true, "what AdiBags already calls junk is still junk")
eq(SURPLUS_CALLS, 0, "and Valuate is not even asked - the host's yes is final")

SURPLUS_CALLS = 0
SURPLUS[22] = true
eq(jm:ExtendedCheckItem(22), true, "gear Valuate marks surplus is added to the junk set")
ok(SURPLUS_CALLS > 0, "which required asking Valuate")

eq(jm:ExtendedCheckItem(33), false, "and something neither of them calls junk is not junk")

-- The direction that must NOT be possible: Valuate cannot un-junk something.
HOST_JUNK[44], SURPLUS[44] = true, false
eq(jm:ExtendedCheckItem(44), true,
   "Valuate saying 'not surplus' does NOT overrule AdiBags saying 'junk'")

-- ---- FAILS CLOSED ------------------------------------------------------------------------------
-- IsSurplusGear reads scan data that may not be there. An error must mean "not junk": the
-- alternative is an item being sold on the strength of a read that never happened.
jm = install()
SURPLUS_ERRORS = true
HOST_JUNK[55] = false
local okCall, verdict = pcall(jm.ExtendedCheckItem, jm, 55)
ok(okCall, "an error inside the surplus check does not escape into AdiBags")
eq(verdict, false, "and the item is NOT junk - a failed read never adds to the sell list")

-- The pair, so "always false" cannot pass: with the check working again it must still say yes.
SURPLUS_ERRORS = false
SURPLUS[55] = true
eq(jm:ExtendedCheckItem(55), true, "and a working check still marks surplus gear")

-- ---- IDEMPOTENT ---------------------------------------------------------------------------------
-- Chaining the wrapper around itself would run the surplus test once per layer, on a path that
-- runs per item per bag repaint.
jm = install()
mod:HookJunkModule()
mod:HookJunkModule()
SURPLUS_CALLS, HOST_CALLS = 0, 0
SURPLUS[66] = false
jm:ExtendedCheckItem(66)
eq(HOST_CALLS, 1, "hooking three times still calls the host's check exactly once")
eq(SURPLUS_CALLS, 1, "and the surplus check exactly once")

-- ---- a host that offers nothing to hook ----------------------------------------------------------
-- Feature-detected because AdiBags builds differ. Erroring here would break the bag addon at
-- load, which is a far worse outcome than the feature quietly not applying.
junkModule = nil
MODULE = nil
ok(pcall(mod.HookJunkModule, mod), "no Junk module at all is survivable")

junkModule = nil
MODULE = { }  -- present, but without the method this hook needs
ok(pcall(mod.HookJunkModule, mod), "a Junk module without ExtendedCheckItem is survivable")
eq(MODULE.ExtendedCheckItem, nil, "and nothing is installed onto it")

junkModule = nil
local savedGet = AdiBags.GetModule
AdiBags.GetModule = nil
ok(pcall(mod.HookJunkModule, mod), "an AdiBags with no GetModule is survivable")
AdiBags.GetModule = savedGet

return failures, checks
`,
  "junkhook",
  "the AdiBags junk hook"
);
