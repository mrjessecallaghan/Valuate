#!/usr/bin/env node
/*
 * @gate No gate quietly mocks away a return value it was written to check
 *
 * A mock that returns fewer values than the real function can never catch a multi-return bug.
 * The gate passes, and the second return - which is usually the entire point of the release
 * that added it - is never once seen.
 *
 * That cost two defects in four days:
 *
 *   todopanel.js   Valuate.BuildTodoList = function() return ITEMS end        real returns 2
 *   todotest.js    function Valuate:FindEmptySockets() return nil, SOCKETS    real returns 3
 *
 * Both times the dropped value carried the distinction the work was about - what the to-do list
 * could not read, and whether the socket reader had been refused - and both times a full green
 * suite said everything was fine.
 *
 * WHY THIS IS AN ALLOWLIST AND NOT A HARD RULE
 *
 * A thin mock is not automatically wrong. Most of the entries below are fine: the code under
 * test reads only the first value, and writing out the rest would be noise pretending to be
 * rigour. A gate that failed on all twenty would be ignored inside a week, and this project has
 * written that lesson down more than once.
 *
 * What the list buys is the MOMENT. Adding a name here is the point at which somebody has to
 * ask "does the code under test read the value I am dropping?" - which is the question nobody
 * asked in either case above. Being on the list means that question was asked and answered.
 *
 * Reviewed explicitly, because it sits on the destructive path: Valuate:IsUpgradeForAnyScale
 * returns isUpgrade, bestDelta, bestScaleName, and every caller in the delete and sell paths
 * reads the boolean alone. Only Valuate.lua:7266 uses the delta, and that is the bag-upgrade
 * notifier rather than anything that removes an item.
 *
 * WHAT IT READS
 *
 * Valuate's own gates and every sibling addon's suite - Valuate's in JavaScript, the siblings'
 * in Lua. Mocks look the same in both, so one matcher covers them.
 *
 * The first version read only ONE-LINE mocks, which meant it could not see the sibling suites at
 * all, because they write theirs across several lines. Its header claimed the coverage anyway.
 * That was caught by breaking the sibling mock on purpose and watching the gate stay green -
 * a rule silently covering half of what it claims is precisely the failure this file exists to
 * stop, one level up, and there is now a mutation pinning that case.
 *
 * A body that cannot be read confidently reports NOTHING rather than a guessed arity. Depth is
 * counted from Lua keywords, which is a heuristic, and a checker that is confidently wrong is
 * worse than one that stays quiet.
 *
 * Usage:  node tools/mockarity.js
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDON_ROOT = path.join(__dirname, "..");
const NL = String.fromCharCode(10);

/* Thin mocks that have been looked at. Keyed "gate.js:Valuate.Name" - the gate AND the name,
 * so the same function mocked thinly somewhere new still has to be justified there. */
const REVIEWED = new Set([
  "arrowtest.js:Valuate.IsItemLinkUpgrade",
  // SetArrow reads the boolean and nothing else - the delta and scale name go unused there.
  "arrowmark.js:Valuate.IsItemLinkUpgrade",
  // ParseScaleTag really returns name, data, errorMessage, versionMessage. The first three are
  // all exercised here - the error one on the failure path. The fourth is destructured by
  // ParseMultipleScaleTags and then never read, so there is nothing for a wider mock to reach.
  "bulkimport.js:Valuate.ParseScaleTag",
  "autowizard.js:Valuate.GetCachedEquippedStatTotals",
  "autowizard.js:Valuate.GetTemplateSet",
  "autowizard.js:Valuate.PlanAutoScale",
  "deletetest.js:Valuate.IsUpgradeForAnyScale", // destructive path - checked, boolean only
  "dungeonloot.js:Valuate.GetScaledStatsForItem",
  "dungeonloot.js:Valuate.IsUpgradeForAnyScale",
  "enhancepanel.js:ns.LookupVendorNote",
  "hitcap.js:Valuate.GetCachedEquippedStatTotals",
  "settingstest.js:Valuate.GetProfessionOverrideChoices",
  "tabtest.js:Valuate.GetProfessionOverrideChoices",
  "tabtest.js:Valuate.GetAutomationHeartbeat",
  "todotest.js:Valuate.CountEquippableUpgrades",
  "wizarduitest.js:Valuate.GetCachedEquippedStatTotals",
]);

/* Present when multi-line mock detection was added, and accepted as the state of the world
 * rather than audited one by one. Saying so matters: REVIEWED above means somebody asked
 * whether the dropped value is read, and folding this list into that one would quietly stop
 * that claim being true of most of it.
 *
 * Nearly all of these are do-nothing stubs for side-effecting functions - ScanBestEquipment,
 * ShowConfirmDialog - where the return was never the point. But a zero-return stub is not
 * automatically harmless: the TSM suite mocked ScheduleWork that way, its caller checks the
 * value, and that cost a release. So they stay in scope, and the next one must be justified.
 *
 * The list only shrinks. Anything leaving it should move into REVIEWED with a reason, or be
 * fixed by widening the mock. */
const BASELINE = new Set([
  "firstrun.js:Valuate.ScanBestEquipment",
  "inferred.js:Valuate.ScanBestEquipment",
  "inferred.js:Valuate.ShowConfirmDialog",
  "rollaction.js:Valuate.IsLearnableRecipe",
  "scalelisttest.js:Valuate.ClearBestEquipmentForScale",
  "settingstest.js:Valuate.LoadSettingsSnapshot",
  "settingstest.js:Valuate.RestoreDefaultOptions",
  "settingstest.js:Valuate.SaveSettingsSnapshot",
  "settingstest.js:Valuate.ScanBestEquipment",
  "settingstest.js:Valuate.ShowConfirmDialog",
  "snapshottest.js:Valuate.ScanBestEquipment",
  "statsearchtest.js:Valuate.ScanBestEquipment",
  "statsearchtest.js:Valuate.ShowConfirmDialog",
  "tabtest.js:Valuate.LoadSettingsSnapshot",
  "tabtest.js:Valuate.RestoreDefaultOptions",
  "tabtest.js:Valuate.SaveSettingsSnapshot",
  "tabtest.js:Valuate.ScanBestEquipment",
  "tabtest.js:Valuate.ShowConfirmDialog",
  "tests.lua:ns.Redraw",
  "wizardroles.js:Valuate.GetCachedEquippedStatTotals",
  "wizardroles.js:Valuate.ScanBestEquipment",
]);

/* Splits a return expression on top-level commas only, so a call carrying its own arguments
 * counts as one value rather than as its argument count. */
function topLevelCount(expr) {
  let depth = 0;
  let parts = 1;
  let inStr = null;
  for (let i = 0; i < expr.length; i++) {
    const c = expr[i];
    if (inStr) {
      if (c === inStr && expr[i - 1] !== "\\") inStr = null;
      continue;
    }
    if (c === '"' || c === "'") {
      inStr = c;
      continue;
    }
    if (c === "(" || c === "{" || c === "[") depth++;
    else if (c === ")" || c === "}" || c === "]") depth--;
    else if (c === "," && depth === 0) parts++;
  }
  return parts;
}

/* How many values a mock returns, whether it is written on one line or many.
 *
 * One-liners are how most fixtures write a mock, and matching only those is what the first
 * version of this gate did - which meant it could not see the sibling suites at all, since they
 * write theirs across several lines. A rule that silently covers half of what its own header
 * claims is the thing this gate exists to prevent, one level up.
 *
 * Returns nil when the body cannot be read confidently. Depth here is counted from Lua
 * keywords, which is a heuristic; when it does not resolve inside a short window the honest
 * answer is to say nothing rather than to guess an arity and report on it.
 */
function mockReturnCount(lines, i, inlineBody) {
  const countOf = (s, re) => (s.match(re) || []).length;

  const inline = inlineBody.match(/\breturn\s+(.+?)\s*(?:end\s*)?$/);
  if (inline) return topLevelCount(inline[1].replace(/\s*end\s*$/, ""));
  // An explicit bare `return` or an immediate `end` is a mock returning nothing at all.
  if (/\breturn\s*end\s*$/.test(inlineBody) || /^\s*end\s*$/.test(inlineBody)) return 0;

  let depth = 1;
  let best = null;
  for (let j = i + 1; j < Math.min(i + 40, lines.length); j++) {
    const line = lines[j];
    const code = line.replace(/--.*$/, "");
    const r = code.match(/^\s*return\s+(.+?)\s*$/);
    if (r) {
      const n = topLevelCount(r[1]);
      if (best === null || n > best) best = n;
    } else if (/^\s*return\s*$/.test(code)) {
      if (best === null) best = 0;
    }
    depth += countOf(code, /\bfunction\b/g) + countOf(code, /\bthen\b/g) + countOf(code, /\bdo\b/g);
    depth -= countOf(code, /\bend\b/g);
    if (depth <= 0) return best === null ? 0 : best;
  }
  return null; // never resolved - say nothing rather than guess
}

/* ---- one addon at a time -----------------------------------------------------------------
 *
 * Per addon, deliberately. Valuate and every sibling put their own functions on a table called
 * `ns`, so a single shared map would have Valuate-TSM's ns.Enqueue and Valuate's ns.Something
 * colliding under one name and comparing a mock against the wrong function's arity - a checker
 * that is confidently wrong, which is worse than one that says nothing.
 */
const ADDONS = [
  { name: "Valuate", root: ADDON_ROOT, suite: __dirname },
  { name: "Valuate-TSM", root: path.join(ADDON_ROOT, "..", "Valuate-TSM") },
  { name: "Valuate-LootCollector", root: path.join(ADDON_ROOT, "..", "Valuate-LootCollector") },
  { name: "Valuate-AdiBags", root: path.join(ADDON_ROOT, "..", "Valuate-AdiBags") },
  { name: "Valuate-PassLoot", root: path.join(ADDON_ROOT, "..", "Valuate-PassLoot") },
];

function luaSources(root) {
  const out = [];
  if (!fs.existsSync(root)) return out;
  for (const f of fs.readdirSync(root)) {
    if (f.endsWith(".lua")) out.push(path.join(root, f));
  }
  const ui = path.join(root, "ui");
  if (fs.existsSync(ui)) {
    for (const f of fs.readdirSync(ui)) if (f.endsWith(".lua")) out.push(path.join(ui, f));
  }
  return out;
}

function arityOf(files) {
  const map = new Map();
  for (const file of files) {
    const lines = fs.readFileSync(file, "utf8").split(NL);
    let name = null;
    let best = 0;
    const flush = () => {
      if (name && best > (map.get(name) || 0)) map.set(name, best);
      name = null;
      best = 0;
    };
    for (const line of lines) {
      const d = line.match(/^(?:local\s+)?function\s+((?:ns|Valuate)[.:]\w+)\s*\(/);
      if (d) { flush(); name = d[1].replace(":", "."); continue; }
      if (!name) continue;
      if (/^end\b/.test(line)) { flush(); continue; }
      const r = line.match(/^\s*return\s+(.+?)\s*$/);
      if (r && !r[1].startsWith("--")) {
        const n = topLevelCount(r[1]);
        if (n > best) best = n;
      }
    }
    flush();
  }
  return map;
}

/* A suite is this addon's own tools directory. Valuate's is JavaScript; the siblings write
 * theirs in Lua. Mocks look the same in both - `ns.Name = function() ... end` - so one matcher
 * covers them, and the first thing this rule caught outside Valuate's own tools was in a
 * sibling: Valuate-TSM's ScheduleWork mock returned nothing where the real one returns a
 * boolean, which tells every caller that scheduling failed. */
function suiteFiles(addon) {
  const dir = addon.suite || path.join(addon.root, "tools");
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".js") || f.endsWith(".lua"))
    .map((f) => ({ dir, file: f }));
}

const problems = [];
const seen = new Set();
let mocksRead = 0;
let functionsKnown = 0;

for (const addon of ADDONS) {
  const real = arityOf(luaSources(addon.root));
  functionsKnown += real.size;
  if (addon.name === "Valuate" && real.size < 50) {
    console.error(
      "  SCAN  only " + real.size + " function(s) found in " + addon.name + " - this gate is " +
        "reading the wrong files and proving nothing"
    );
    process.exit(1);
  }

  for (const { dir, file } of suiteFiles(addon)) {
    if (dir === __dirname && file === path.basename(__filename)) continue;
    const lines = fs.readFileSync(path.join(dir, file), "utf8").split(NL);
    lines.forEach((line, i) => {
      const m = line.match(
        /^\s*(?:function\s+(Valuate[.:]\w+|ns\.\w+)\s*\([^)]*\)|(Valuate\.\w+|ns\.\w+)\s*=\s*function\s*\([^)]*\))\s*(.*)$/
      );
      if (!m) return;
      const name = (m[1] || m[2]).replace(":", ".");
      const mockN = mockReturnCount(lines, i, m[3] || "");
      if (mockN === null) return; // body could not be read confidently - say nothing
      mocksRead++;

      const realN = real.get(name);
      if (!realN || mockN >= realN) return;

      const key = file + ":" + name;
      seen.add(key);
      if (REVIEWED.has(key) || BASELINE.has(key)) return;
      problems.push(
        addon.name + "/" + file + ":" + (i + 1) + "  " + name + " is mocked returning " + mockN +
          " value(s), but really returns " + realN + ". If the code under test reads the " +
          "value(s) being dropped, this gate cannot see them - which is how the to-do list and " +
          "the socket reader each shipped a broken second return past a green suite. Widen the " +
          "mock, or add \"" + key + "\" to REVIEWED here once you have checked it is unused."
      );
    });
  }
}

/* An entry that no longer matches anything is a note about a mock that has since been widened
 * or deleted. Harmless, but it makes the list read as bigger than the debt actually is - and a
 * list nobody prunes is a list nobody trusts. */
const stale = [...REVIEWED, ...BASELINE].filter((k) => !seen.has(k));
for (const k of stale) {
  problems.push(
    "REVIEWED lists \"" + k + "\", but nothing there mocks it thinly any more - the mock was " +
      "widened or removed. Delete the entry so the list keeps meaning what it says."
  );
}

if (problems.length) {
  console.error("Mock arity: " + problems.length + " problem(s):");
  for (const p of problems) console.error("  - " + p);
  process.exit(1);
}

console.log(
  "OK  " + mocksRead + " mock(s) checked against " + functionsKnown + " real function(s); " +
    REVIEWED.size + " reviewed and " + BASELINE.size + " baselined thin mock(s), none new."
);
