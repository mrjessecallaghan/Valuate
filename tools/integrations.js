#!/usr/bin/env node
/*
 * @gate The report names a missing integration, and stays quiet about ones you never installed
 *
 * Runs the REAL ns.IntegrationStatus and Valuate:PrintIntegrations from Valuate.lua.
 *
 * Four addons extend this one, and each of them fails silently. If Valuate-AdiBags does not
 * load - a Lua error, an unticked box at the character screen, a renamed folder - you keep
 * AdiBags and lose the Valuate filter inside it, with nothing anywhere saying so. Your bags
 * stop sorting the way they used to and you assume you changed something.
 *
 * The pairing is the whole design. An integration is only interesting when its HOST is present:
 *
 *   host + integration   working
 *   host, no integration MISSING - the only state worth acting on
 *   no host              idle - not a fault, and must not be reported as one
 *   integration, no host orphan - odd, harmless, worth one grey line
 *
 * Reporting "Valuate-TSM: not loaded" to someone who has never installed TSM is crying wolf,
 * and a report that cries wolf is one you stop reading - which costs you the line that
 * mattered. So half these assertions are about staying quiet.
 *
 * Usage:  node tools/integrations.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const NL = String.fromCharCode(10);

function sliceFrom(header) {
  const start = lua.indexOf(header);
  if (start < 0) {
    console.error("  SLICE  could not find " + header + " in Valuate.lua - testing nothing");
    process.exit(1);
  }
  const end = lua.indexOf(NL + "end" + NL, start);
  return lua.slice(start, end + 5);
}

const declStart = lua.indexOf("ns.INTEGRATIONS = {");
if (declStart < 0) {
  console.error("  SLICE  could not find ns.INTEGRATIONS in Valuate.lua - testing nothing");
  process.exit(1);
}
const declEnd = lua.indexOf(NL + "}" + NL, declStart);
const decl = lua.slice(declStart, declEnd + 3);
const statusFn = sliceFrom("function ns.IntegrationStatus()");
const printFn = sliceFrom("function Valuate:PrintIntegrations()");

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

local ns = {}
LOADED = {}
IsAddOnLoaded = function(name) return LOADED[name] == true end

` + decl + `
` + statusFn + `
` + printFn + `

local function stateOf(rows, addon)
    for _, row in ipairs(rows) do if row.addon == addon then return row.state end end
end

-- ---- the state worth acting on ----------------------------------------------------------------
LOADED = { AdiBags = true }
local rows, idle = ns.IntegrationStatus()
eq(stateOf(rows, "Valuate-AdiBags"), "MISSING",
   "the host is loaded and the integration is not, which is the one state worth a warning")

__printed = {}
Valuate:PrintIntegrations()
local said = table.concat(__printed, NL)
ok(said:find("Valuate%-AdiBags is NOT loaded") ~= nil, "the report names the addon that is missing")
ok(said:find("AdiBags", 1, true) ~= nil, "and the host that makes it relevant")
ok(said:find("bag sorting", 1, true) ~= nil, "and what you are losing by it")
ok(said:find("character%-select") ~= nil, "with the first thing to check")

-- ---- and the states that must stay QUIET --------------------------------------------------------
-- Reporting an integration you never installed, for a host you never installed, is how a report
-- becomes one you stop reading.
LOADED = {}
rows, idle = ns.IntegrationStatus()
eq(idle, 4, "with no hosts installed, all four are idle")
for _, row in ipairs(rows) do
    eq(row.state, "idle", row.addon .. " is idle rather than missing")
end

__printed = {}
local shown = Valuate:PrintIntegrations()
eq(shown, 0, "and nothing is listed")
said = table.concat(__printed, NL)
eq(said:find("NOT loaded", 1, true), nil, "nothing is described as not loaded")
ok(said:find("nothing here applies", 1, true) ~= nil, "it says so once, plainly, and stops")

-- ---- working, which is also quiet-ish ------------------------------------------------------------
LOADED = { AdiBags = true, ["Valuate-AdiBags"] = true }
rows = ns.IntegrationStatus()
eq(stateOf(rows, "Valuate-AdiBags"), "working", "both loaded is working")
__printed = {}
Valuate:PrintIntegrations()
said = table.concat(__printed, NL)
eq(said:find("NOT loaded", 1, true), nil, "a working integration is never called missing")
ok(said:find("Valuate%-AdiBags") ~= nil, "but it is confirmed, so silence is not the only signal")

-- ---- the orphan --------------------------------------------------------------------------------
-- Odd and harmless: the integration loaded with nothing to extend. Worth a grey line rather
-- than a warning, because there is nothing to fix.
LOADED = { ["Valuate-TSM"] = true }
rows = ns.IntegrationStatus()
eq(stateOf(rows, "Valuate-TSM"), "orphan", "an integration with no host is an orphan")
__printed = {}
Valuate:PrintIntegrations()
said = table.concat(__printed, NL)
ok(said:find("doing nothing", 1, true) ~= nil, "said plainly")
eq(said:find("NOT loaded", 1, true), nil, "and never as a failure, because nothing is broken")

-- ---- mixed, which is the real world --------------------------------------------------------------
LOADED = { AdiBags = true, ["Valuate-AdiBags"] = true, LootCollector = true }
rows, idle = ns.IntegrationStatus()
eq(stateOf(rows, "Valuate-AdiBags"), "working", "one working")
eq(stateOf(rows, "Valuate-LootCollector"), "MISSING", "one missing")
eq(idle, 2, "and two idle, counted rather than named")
__printed = {}
Valuate:PrintIntegrations()
said = table.concat(__printed, NL)
ok(said:find("2 other integration", 1, true) ~= nil,
   "the idle ones are counted, not listed - naming addons you never installed is the noise")
eq(said:find("TradeSkillMaster", 1, true), nil, "so a host you do not have is never mentioned")

-- ---- order is the declaration order --------------------------------------------------------------
-- Not sorted by state: the same integration on the same line every time is what makes this
-- readable at a glance rather than re-parsed each run.
LOADED = { AdiBags = true, PassLoot = true, TradeSkillMaster = true, LootCollector = true }
local first = ns.IntegrationStatus()
local second = ns.IntegrationStatus()
for i = 1, #first do
    eq(second[i].addon, first[i].addon, "the listing order is stable at position " .. i)
end

-- ---- a client with no addon api at all -------------------------------------------------------------
IsAddOnLoaded = nil
rows, idle = ns.IntegrationStatus()
eq(idle, 4, "with no IsAddOnLoaded it reports everything idle rather than erroring")

return failures, checks
`,
  "integrations",
  "the integration report"
);
