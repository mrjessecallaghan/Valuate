#!/usr/bin/env node
/*
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

console.log(
  `OK  all ${listed.length} selftest-listed methods exist (${defined.size} defined in total).`
);
