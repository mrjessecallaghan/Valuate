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

/* ---- how many values does the REAL function return? ------------------------------------- */

const srcFiles = ["Valuate.lua", "ValuateUI.lua", "ImportExport.lua"]
  .concat(
    fs
      .readdirSync(path.join(ADDON_ROOT, "ui"))
      .filter((f) => f.endsWith(".lua"))
      .map((f) => "ui/" + f)
  )
  .filter((f) => fs.existsSync(path.join(ADDON_ROOT, f)));

const realArity = new Map();
for (const rel of srcFiles) {
  const lines = fs.readFileSync(path.join(ADDON_ROOT, rel), "utf8").split(NL);
  let name = null;
  let best = 0;
  const flush = () => {
    if (name && best > (realArity.get(name) || 0)) realArity.set(name, best);
    name = null;
    best = 0;
  };
  for (const line of lines) {
    const d = line.match(/^(?:local\s+)?function\s+((?:ns|Valuate)[.:]\w+)\s*\(/);
    if (d) {
      flush();
      name = d[1].replace(":", ".");
      continue;
    }
    if (!name) continue;
    if (/^end\b/.test(line)) {
      flush();
      continue;
    }
    const r = line.match(/^\s*return\s+(.+?)\s*$/);
    if (r && !r[1].startsWith("--")) {
      const n = topLevelCount(r[1]);
      if (n > best) best = n;
    }
  }
  flush();
}

if (realArity.size < 50) {
  console.error(
    "  SCAN  only " + realArity.size + " function(s) found in the addon sources - this gate is " +
      "reading the wrong files and proving nothing"
  );
  process.exit(1);
}

/* ---- how many does each gate's mock return? ---------------------------------------------- */

const problems = [];
const seen = new Set();
let mocksRead = 0;

for (const g of fs.readdirSync(path.join(__dirname)).filter((f) => f.endsWith(".js"))) {
  if (g === path.basename(__filename)) continue;
  const lines = fs.readFileSync(path.join(__dirname, g), "utf8").split(NL);
  lines.forEach((line, i) => {
    const m = line.match(
      /^\s*(?:function\s+(Valuate[.:]\w+|ns\.\w+)\s*\([^)]*\)|(Valuate\.\w+|ns\.\w+)\s*=\s*function\s*\([^)]*\))\s*(.*)$/
    );
    if (!m) return;
    const name = (m[1] || m[2]).replace(":", ".");
    const body = m[3] || "";
    const r = body.match(/\breturn\s+(.+?)\s*(?:end\s*)?$/);
    if (!r) return;
    mocksRead++;

    const mockN = topLevelCount(r[1].replace(/\s*end\s*$/, ""));
    const realN = realArity.get(name);
    if (!realN || mockN >= realN) return;

    const key = g + ":" + name;
    seen.add(key);
    if (REVIEWED.has(key)) return;
    problems.push(
      "tools/" + g + ":" + (i + 1) + "  " + name + " is mocked returning " + mockN +
        " value(s), but really returns " + realN + ". If the code under test reads the " +
        "value(s) being dropped, this gate cannot see them - which is how the to-do list and " +
        "the socket reader each shipped a broken second return past a green suite. Widen the " +
        "mock, or add \"" + key + "\" to REVIEWED here once you have checked it is unused."
    );
  });
}

/* An entry that no longer matches anything is a note about a mock that has since been widened
 * or deleted. Harmless, but it makes the list read as bigger than the debt actually is - and a
 * list nobody prunes is a list nobody trusts. */
const stale = [...REVIEWED].filter((k) => !seen.has(k));
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
  "OK  " + mocksRead + " mock(s) checked against " + realArity.size + " real function(s); " +
    REVIEWED.size + " thin mock(s) reviewed and accepted, none new."
);
