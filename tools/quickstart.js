#!/usr/bin/env node
/*
 * @gate Quick setup switches on only the settings that cannot cost you anything
 *
 * Runs the real ns.QUICK_TELLS / QUICK_ACTS / QUICK_COSTS and ns.ApplyQuickSetup.
 *
 * Twenty-odd automations, every one off by default. That is the right default and a poor first
 * hour: the settings that only change what the addon DRAWS sit in the same list as the ones
 * that sell your gear, and telling them apart means reading each one.
 *
 * `/valuate quickstart` sorts them once, by WHAT IS AT STAKE IF THEY GO WRONG:
 *
 *   TELLS   changes only what Valuate draws or remembers. Wrong, you see a wrong number.
 *   ACTS    reaches into the game world - spends gold, accepts, equips, rolls. Wrong,
 *           something happened that you did not do.
 *   COSTS   destroys or binds. Wrong, an item is gone and no undo exists anywhere in the game.
 *
 * Only the first tier is ever switched on. The whole value of the command rests on that being
 * true, so it is the thing this gate exists to hold: a convenience feature that quietly enabled
 * auto-sell would be worse than no convenience feature, and it would be an easy edit to make by
 * moving one line between two lists.
 *
 * The tiering is a JUDGEMENT and the gate does not pretend otherwise - it cannot know whether
 * `autoRepair` belongs in ACTS. What it can know, and does:
 *
 *   - nothing from ACTS or COSTS is ever written
 *   - nothing is ever switched OFF, so this is a way in rather than a rearrangement
 *   - every option named really exists, because a typo would set a key nothing reads
 *   - no option sits in two tiers, so nothing is both safe and not
 *   - everything that ACTS or COSTS says WHY, since that is the half worth reading
 *
 * Usage:  node tools/quickstart.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const NL = String.fromCharCode(10);
const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

function sliceTable(name) {
  const m = lua.match(new RegExp("^ns\\." + name + " = \\{[\\s\\S]*?\\r?\\n\\}", "m"));
  if (!m) {
    console.error(
      "  SLICE  could not find ns." + name + " in Valuate.lua - this gate is testing nothing"
    );
    process.exit(1);
  }
  return m[0];
}

const applyStart = lua.indexOf("function ns.ApplyQuickSetup(");
if (applyStart < 0) {
  console.error("  SLICE  could not find ns.ApplyQuickSetup in Valuate.lua");
  process.exit(1);
}
const apply = lua.slice(applyStart, lua.indexOf(NL + "end" + NL, applyStart) + 5);

/* The declared options, read from the source rather than listed again here. A second copy of
 * this list is a second thing to forget, which is the failure this whole toolchain is about. */
const defaults = lua.match(/^local DEFAULT_OPTIONS = \{[\s\S]*?\r?\n\}/m);
if (!defaults) {
  console.error("  SLICE  could not find DEFAULT_OPTIONS in Valuate.lua");
  process.exit(1);
}
const declared = new Set(
  [...defaults[0].matchAll(/^\s{4}(\w+)\s*=/gm)].map((m) => m[1])
);

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
` + sliceTable("QUICK_TELLS") + `
` + sliceTable("QUICK_ACTS") + `
` + sliceTable("QUICK_COSTS") + `
` + apply + `

-- ---- the tiers are populated and distinct ------------------------------------------------------
ok(#ns.QUICK_TELLS > 0, "there is something safe to switch on")
ok(#ns.QUICK_ACTS > 0, "and something that acts, left off")
ok(#ns.QUICK_COSTS > 0, "and something that costs, left off")

local seen = {}
for _, tier in ipairs({ ns.QUICK_TELLS, ns.QUICK_ACTS, ns.QUICK_COSTS }) do
    for _, e in ipairs(tier) do
        ok(type(e.option) == "string" and e.option ~= "", "every entry names an option")
        ok(type(e.label) == "string" and e.label ~= "", "and says what it does in words")
        ok(seen[e.option] == nil,
           "no option sits in two tiers - nothing is both safe and not: " .. tostring(e.option))
        seen[e.option] = true
    end
end

-- Everything that reaches into the game says WHY it is left off. That explanation is the useful
-- half of the command: the switching is the small part, being told what the addon deliberately
-- will not decide for you is the rest.
for _, tier in ipairs({ ns.QUICK_ACTS, ns.QUICK_COSTS }) do
    for _, e in ipairs(tier) do
        ok(type(e.why) == "string" and #e.why > 10,
           "an option left off explains why: " .. tostring(e.option))
    end
end

-- ---- THE ONE THAT MATTERS: only TELLS is ever written --------------------------------------------
-- A convenience feature that quietly enabled auto-sell would be worse than no convenience
-- feature at all, and it is one line moved between two lists.
local opts = {}
local turnedOn, alreadyOn = ns.ApplyQuickSetup(opts)
eq(#turnedOn, #ns.QUICK_TELLS, "a fresh character has every safe setting switched on")
eq(#alreadyOn, 0, "and none of them were already on")

for _, e in ipairs(ns.QUICK_ACTS) do
    eq(opts[e.option], nil, "quickstart never switches on something that ACTS: " .. e.option)
end
for _, e in ipairs(ns.QUICK_COSTS) do
    eq(opts[e.option], nil, "and never something that COSTS: " .. e.option)
end
for _, e in ipairs(ns.QUICK_TELLS) do
    eq(opts[e.option], true, "while every safe one IS on: " .. e.option)
end

-- ---- nothing is ever switched OFF ------------------------------------------------------------------
-- A way in, not a rearrangement. Somebody who has already tuned their settings and then runs
-- this out of curiosity must not lose anything.
opts = { autoSellJunk = true, autoDeleteJunk = true, showUpgradeArrows = true }
turnedOn, alreadyOn = ns.ApplyQuickSetup(opts)
eq(opts.autoSellJunk, true, "an option you had switched on yourself stays on, even a costly one")
eq(opts.autoDeleteJunk, true, "-- both of them")
eq(opts.showUpgradeArrows, true, "and a safe one you already had stays on too")
eq(#alreadyOn, 1, "the one already on is reported as already on")
eq(alreadyOn[1].option, "showUpgradeArrows", "-- by name")
ok(#turnedOn == #ns.QUICK_TELLS - 1, "and only the rest are counted as newly switched on")

-- Run twice: the second time changes nothing at all.
local second, secondAlready = ns.ApplyQuickSetup(opts)
eq(#second, 0, "running it again switches nothing on")
eq(#secondAlready, #ns.QUICK_TELLS, "because everything safe is already on")

-- ---- it survives being handed nothing ----------------------------------------------------------------
ok(pcall(ns.ApplyQuickSetup, nil), "no options table is survivable")
eq(#(select(1, ns.ApplyQuickSetup(nil))), 0, "and switches nothing on")

return failures, checks
`,
  "quickstart",
  "quick setup"
);

/* ---- every option named really exists ------------------------------------------------------
 *
 * Checked in JavaScript against DEFAULT_OPTIONS rather than in Lua, because the answer is about
 * the SOURCE agreeing with itself. A typo here would set a key nothing ever reads: the command
 * would report the setting switched on, and it would do nothing at all, forever. */
const named = [...lua.matchAll(/^\s{4}\{ option = "(\w+)",/gm)].map((m) => m[1]);
const bogus = named.filter((n) => !declared.has(n));
if (bogus.length) {
  console.error(
    "Quick setup names " + bogus.length + " option(s) that do not exist in DEFAULT_OPTIONS: " +
      bogus.join(", ") + ".\n" +
      "  The command would report them switched on and nothing would ever read the key."
  );
  process.exit(1);
}
