#!/usr/bin/env node
/*
 * @gate Selftest-listed methods exist, and integration addons call real ones
 *
 * Selftest method-list checker.
 *
 * /valuate selftest verifies a curated list of method NAMES exist on the Valuate
 * table. Those names are plain strings, so a typo or a stale entry left behind by a
 * rename produces an in-game failure that reads like a broken build - "method
 * GetScaelLibrary" - rather than pointing at the list.
 *
 * This checks the other direction to the selftest itself: every name IN the list is
 * actually defined in the source.
 *
 * Deliberately NOT "every method must be listed". That list is curated - it covers
 * the load-bearing API, not all ~70 methods - and demanding completeness would
 * produce noise instead of signal.
 *
 * Usage:  node tools/api.js
 * Exits non-zero if a listed method does not exist.
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");

function readAll() {
  const out = [];
  (function walk(dir) {
    let entries;
    try {
      entries = fs.readdirSync(path.join(ADDON_ROOT, dir), { withFileTypes: true });
    } catch (e) {
      return;
    }
    for (const e of entries) {
      const rel = dir ? `${dir}/${e.name}` : e.name;
      if (e.isDirectory()) {
        if (!/^(libs|tools|\.git)$/i.test(e.name)) walk(rel);
      } else if (e.name.endsWith(".lua")) {
        out.push(fs.readFileSync(path.join(ADDON_ROOT, rel), "utf8"));
      }
    }
  })("");
  return out.join("\n");
}

const source = readAll();

// The selftest's curated list: `local methods = { "A", "B", ... }`.
const listMatch = source.match(/local methods\s*=\s*\{([\s\S]*?)\n\s*\}/);
if (!listMatch) {
  console.error("ERROR  couldn't find the selftest's `local methods = {` list");
  process.exit(2);
}

const listed = [];
const nameRe = /"([A-Za-z_]\w*)"/g;
let m;
while ((m = nameRe.exec(listMatch[1]))) listed.push(m[1]);

// Every way a method can be attached to the Valuate table.
const defined = new Set();
const defRe = /function\s+Valuate[:.]([A-Za-z_]\w*)\s*\(/g;
while ((m = defRe.exec(source))) defined.add(m[1]);
const assignRe = /\bValuate\.([A-Za-z_]\w*)\s*=\s*function/g;
while ((m = assignRe.exec(source))) defined.add(m[1]);

const missing = listed.filter((name) => !defined.has(name));

if (missing.length) {
  console.error("Selftest lists methods that are not defined anywhere:");
  for (const name of missing) console.error(`  Valuate:${name}`);
  console.error(
    `\n${missing.length} phantom method(s). Fix the name, or drop it from the list.`
  );
  process.exit(1);
}

/*
 * The integration addons call INTO Valuate, and nothing checked that those calls land.
 *
 * Valuate-AdiBags and Valuate-PassLoot live in separate folders with their own load
 * cycle, so a method renamed here breaks them silently - and not at load, but at loot
 * time or on the next bag repaint, which is the worst possible moment to discover it.
 * They are also the two least-visited parts of this project: PassLoot went a whole
 * session untouched while Valuate's API moved underneath it.
 *
 * Guarded calls (`if Valuate.X then`) are checked too. A defensive guard means the
 * caller degrades instead of erroring - it does not mean the name may be wrong.
 */
const ADDONS_DIR = path.resolve(ADDON_ROOT, "..");

// DISCOVERED, not listed.
//
// This was a hardcoded array of three, and a fourth integration was added without anyone
// remembering to extend it - so Valuate-LootCollector's calls into Valuate went unchecked from
// the day it was written. Exactly the failure this file exists to prevent, one level up: a
// method renamed here would have broken it silently, at loot time, with no gate objecting.
//
// Any sibling folder named Valuate-* is an integration by construction, so the next one is
// covered the day it exists rather than the day somebody remembers.
const INTEGRATIONS = (function () {
  let entries = [];
  try {
    entries = fs.readdirSync(ADDONS_DIR, { withFileTypes: true });
  } catch (e) {
    return [];
  }
  return entries
    .filter((e) => e.isDirectory() && e.name.startsWith("Valuate-"))
    .map((e) => e.name)
    .sort();
})();

const CALL_RE = /\bValuate[:.]([A-Za-z_]\w*)\s*\(/g;
const crossMissing = [];
let crossChecked = 0;
let integrationsSeen = 0;

for (const addon of INTEGRATIONS) {
  const dir = path.join(ADDONS_DIR, addon);
  let files;
  try {
    files = fs.readdirSync(dir).filter((f) => f.endsWith(".lua"));
  } catch (e) {
    continue; // not installed here; not this gate's business
  }
  integrationsSeen++;

  for (const file of files) {
    const src = fs.readFileSync(path.join(dir, file), "utf8");
    const seen = new Set();
    let m;
    while ((m = CALL_RE.exec(src))) {
      const name = m[1];
      if (seen.has(name)) continue;
      seen.add(name);
      crossChecked++;
      if (!defined.has(name)) {
        crossMissing.push(`${addon}/${file}  calls Valuate:${name}()`);
      }
    }
  }
}

if (crossMissing.length) {
  console.error("Integration addons call Valuate methods that do not exist:");
  for (const line of crossMissing) console.error("  " + line);
  console.error(
    "\nThese fail at loot time or on a bag repaint, not at load. Rename the call, " +
    "or restore the method."
  );
  process.exit(1);
}

/*
 * A method the DOCS present as public API must be in the selftest list.
 *
 * The list is deliberately a subset - 60 of 131 methods - so "every method must be listed"
 * would be the wrong rule. But documenting one is the moment you claim other people can rely
 * on it, and that is exactly the claim `/valuate selftest` exists to verify at load.
 *
 * The whole scale wizard missed this for eleven releases: seven public methods, none listed,
 * so selftest reported all-clear while the subsystem a new user meets FIRST could have been
 * entirely absent. Adding them by hand fixes today; this stops the next subsystem repeating
 * it, because the docs get written either way.
 */
const docs = ["README.md", "ARCHITECTURE.md"]
  .map((f) => {
    try {
      return fs.readFileSync(path.join(ADDON_ROOT, f), "utf8");
    } catch (e) {
      return "";
    }
  })
  .join("\n");

const listedSet = new Set(listed);
const documented = new Set(
  [...docs.matchAll(/Valuate:(\w+)\s*\(/g)].map((m) => m[1])
);

const undocumentedInSelftest = [...documented]
  .filter((m) => defined.has(m) && !listedSet.has(m))
  .sort();

if (undocumentedInSelftest.length) {
  console.error("Methods the docs present as public API but /valuate selftest never checks:");
  for (const m of undocumentedInSelftest) console.error(`  Valuate:${m}`);
  console.error(
    "\nAdd them to the methods list in RunSelfTest. Documenting a method is the moment you " +
      "tell people they can rely on it, and selftest is what proves it is still there."
  );
  process.exit(1);
}

console.log(
  `OK  all ${listed.length} selftest-listed methods exist (${defined.size} defined in total); ` +
  `${crossChecked} call(s) from ${integrationsSeen} integration addon(s) all resolve; ` +
  `${documented.size} documented method(s) are all self-tested.`
);
