#!/usr/bin/env node
/*
 * @gate Every running automation can say what it last did
 *
 * Runs the REAL ns.AUTOMATION_LABELS, MarkAutomation, GetAutomationHeartbeat and
 * ActiveAutomationDetail against a mocked WoW API.
 *
 * The heartbeat exists because every silent-automation bug found in this project looked
 * identical from the outside: nothing happening, no error, nothing to point at. Recording
 * "ran, and here is what I concluded" - including when the conclusion was to do nothing -
 * is what makes a working-but-quiet automation distinguishable from a broken one.
 *
 * That recording was only ever readable through /valuate report. It now drives a hover in
 * Settings, which is what makes this worth a runtime gate: the pairing of an automation
 * with its beat is a lookup through two levels of table, and when it is wrong the result is
 * not an error. GetAutomationHeartbeat returns nil, the UI says "no occasion yet", and that
 * is exactly what a genuinely idle automation looks like.
 *
 * tools/options.js checks the same table statically - every automation has a beat, and every
 * beat is one that MarkAutomation somewhere records. This checks the half a text search
 * cannot: that the lookup joining them returns the right outcome for the right label.
 *
 * Usage:  node tools/heartbeat.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

// The constant BEFORE its readers: a slice that splices them the other way round leaves the
// table nil at definition time and every lookup silently returns nothing.
const labels = lua.match(/^ns\.AUTOMATION_LABELS = \{[\s\S]*?\n\}/m);
if (!labels) {
  console.error(
    "  SLICE  could not find `ns.AUTOMATION_LABELS = {` in Valuate.lua - it was renamed or " +
      "reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

// HeartbeatState lives on ns, so it is matched separately from the Valuate: methods below.
const stateFn = lua.match(/^function ns\.HeartbeatState\([\s\S]*?\r?\nend/m);
if (!stateFn) {
  console.error("  SLICE  could not find ns.HeartbeatState - this gate tests nothing");
  process.exit(1);
}

const fns = ["MarkAutomation", "GetAutomationHeartbeat", "ActiveAutomations", "ActiveAutomationDetail"]
  .map(function (name) {
    const hit = lua.match(
      new RegExp("^function Valuate:" + name + "\\([\\s\\S]*?\\r?\\nend", "m")
    );
    if (!hit) {
      console.error("  SLICE  could not find Valuate:" + name + " - this gate tests nothing");
      process.exit(1);
    }
    return hit[0];
  })
  .join("\n");

// automationHeartbeat is a file-local in Valuate.lua, declared just above MarkAutomation.
// Declared here rather than sliced: the slice regex is anchored on `function`, so a bare
// `local automationHeartbeat = {}` would not travel with it, and without the declaration
// both functions would read and write a global of the same name - which happens to work,
// and would therefore hide a real change from `local` to global if one were ever made.
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
Valuate = {}
local now = 1000
GetTime = function() return now end

-- Declared, not sliced: see the note in the JS above. If Valuate.lua ever stops declaring
-- this as a file-local, both sliced functions here would fall through to a global of the
-- same name and keep working - so the local has to exist on this side too, or the gate
-- would quietly stop testing the thing it is named after.
local automationHeartbeat = {}

${labels}
${fns.replace(/\$/g, "$$$$")}
${stateFn[0].replace(/\$/g, "$$$$")}

local OPTIONS = {}
Valuate.GetOptions = function() return OPTIONS end

-- ---- the table itself -------------------------------------------------------------------
-- Both halves are load-bearing and neither errors when wrong: a missing label drops an
-- automation out of the "what is running" line, a missing beat makes it permanently mute.
local labelCount, beatCount = 0, 0
for key, entry in pairs(ns.AUTOMATION_LABELS) do
    labelCount = labelCount + 1
    if type(entry) == "table" and entry.label then beatCount = beatCount + 1 end
    ok(type(entry) == "table", "every entry is a table, not a bare string: " .. key)
    ok(entry.label and entry.label ~= "", "every automation has a label: " .. key)
    ok(entry.beat and entry.beat ~= "", "every automation has a beat: " .. key)
end
ok(labelCount >= 18, "the table still holds every automation (" .. labelCount .. ")")
eq(beatCount, labelCount, "and none of them lost their label in the reshape")

-- Beats must be DISTINCT per automation, or one switching on would report the other's
-- outcome. Quest turn-in shared questReward until it was given its own.
local seenBeat = {}
for key, entry in pairs(ns.AUTOMATION_LABELS) do
    ok(seenBeat[entry.beat] == nil,
       "no two automations share a beat (" .. tostring(entry.beat) .. " on " ..
       tostring(seenBeat[entry.beat]) .. " and " .. key .. ")")
    seenBeat[entry.beat] = key
end

-- ---- nothing on -------------------------------------------------------------------------
eq(#Valuate:ActiveAutomationDetail(), 0, "with everything off the detail list is empty")

-- ---- one on, never run ------------------------------------------------------------------
OPTIONS.autoRepair = true
local d = Valuate:ActiveAutomationDetail()
eq(#d, 1, "switching one on puts exactly one entry in the list")
eq(d[1].label, "repair", "named by its label rather than its option key")
eq(d[1].ago, nil, "and with no timing, because it has had no occasion to run")
eq(d[1].outcome, nil, "and no outcome to report")

-- ---- one on, having run -----------------------------------------------------------------
-- The join under test: option key -> beat -> recorded outcome. Every step of it is a table
-- lookup that returns nil rather than failing when it is wrong.
Valuate:MarkAutomation("autoRepair", "nothing was damaged")
now = now + 30
d = Valuate:ActiveAutomationDetail()
eq(d[1].ago, 30, "once it has run, the list carries how long ago")
eq(d[1].outcome, "nothing was damaged",
   "and the outcome it recorded - which for a healthy automation is usually 'did nothing, because'")

-- The wrong beat is the failure this is here for, and it is SILENT: a key nothing records
-- reads back as nil, which is what an idle automation looks like.
Valuate:MarkAutomation("autoRepairs", "typo'd beat key")
d = Valuate:ActiveAutomationDetail()
eq(d[1].outcome, "nothing was damaged", "a beat nobody reads does not leak into the list")

-- ---- outcomes stay with their own automation --------------------------------------------
OPTIONS.autoSellJunk = true
Valuate:MarkAutomation("junkSell", "no merchant open")
d = Valuate:ActiveAutomationDetail()
eq(#d, 2, "two switched on gives two entries")
local byLabel = {}
for _, a in ipairs(d) do byLabel[a.label] = a end
eq(byLabel["repair"].outcome, "nothing was damaged", "each keeps its own outcome")
eq(byLabel["sell junk"].outcome, "no merchant open", "and does not pick up its neighbour's")

-- ---- ordering is stable ------------------------------------------------------------------
-- The source is pairs(), whose order is undefined, so an unsorted list would reshuffle
-- between openings of the panel.
ok(d[1].label < d[2].label, "the list comes back sorted")
local first = d[1].label
for _ = 1, 5 do
    eq(Valuate:ActiveAutomationDetail()[1].label, first, "and in the same order every time")
end

-- ---- ActiveAutomations still agrees with it ----------------------------------------------
-- Two functions reading one table. They are separate because the line needs only names and
-- the hover needs everything, and they must not disagree about what is on.
local names = Valuate:ActiveAutomations()
eq(#names, #d, "the short list and the detailed list count the same automations")
for i = 1, #names do
    eq(names[i], d[i].label, "and name them in the same order (" .. i .. ")")
end

-- ---- how each beat is described in the report ---------------------------------------------
-- Twenty-two lines all reading "not yet this session" is a wall, not a report - and it makes
-- the one line that matters look exactly like the twenty around it.
--
-- The distinction is "stalled": switched ON and never once recorded anything. That is either
-- "no occasion yet" or "quietly broken", and nothing here can tell which - but reporting it
-- identically to the ones off by choice buries it, and calling it plain "not yet" quietly
-- asserts the harmless one of the two.
eq(ns.HeartbeatState(42, true), "ran", "having run is the whole answer, on or off")
eq(ns.HeartbeatState(42, false), "ran", "even for one since switched off")
eq(ns.HeartbeatState(nil, false), "off", "off by choice is not news")
eq(ns.HeartbeatState(nil, true), "stalled",
   "switched ON and never run is called out - it is the one line worth reading")

-- nil enabled is a THIRD thing, not a falsy second. The gear scan and the bank snapshot have
-- no option behind them, so "on but has not run yet" would be a nonsense verdict about them.
eq(ns.HeartbeatState(nil, nil), "idle",
   "a beat with no option behind it is idle, not stalled")

-- Zero is a real elapsed time - something that ran this instant. Treating it as "never" would
-- report the most recent run of all as the one that never happened.
eq(ns.HeartbeatState(0, true), "ran", "ran a moment ago is still having run")

return failures, checks
`,
  "heartbeat",
  "the automation heartbeat"
);
