#!/usr/bin/env node
/*
 * Valuate syntax gate.
 *
 * Parses every Lua file in the addon (and the sibling integration modules) with a
 * Lua 5.1 parser and reports the first parse error per file as file:line:col. A WoW
 * addon with a Lua *syntax* error simply fails to load, so this catches the worst
 * failure mode that code review can miss. It does NOT verify behaviour.
 *
 * Usage:  node tools/check.js
 * Exits non-zero if any file fails to parse.
 */
"use strict";

const fs = require("fs");
const path = require("path");

let luaparse;
try {
  luaparse = require("luaparse");
} catch (e) {
  console.error("luaparse is not installed. Run:  cd tools && npm install");
  process.exit(2);
}

// tools/ lives inside the addon folder; the addon root is its parent, and the
// integration modules are siblings of the addon root.
const TOOLS_DIR = __dirname;
const ADDON_ROOT = path.resolve(TOOLS_DIR, "..");
const ADDONS_DIR = path.resolve(ADDON_ROOT, "..");

// Scan the main addon plus the integration modules, skipping vendored libraries
// (they're third-party and already ship working) and node_modules.
const SCAN_ROOTS = [
  ADDON_ROOT,
  path.join(ADDONS_DIR, "Valuate-AdiBags"),
  path.join(ADDONS_DIR, "Valuate-PassLoot"),
];
const SKIP_DIR = /(^|[\\/])(libs|node_modules|\.git|_Valuate_Original_Archive.*|_Valuate_Handoff)([\\/]|$)/i;

function collectLuaFiles(root, out) {
  let entries;
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch (e) {
    return; // missing optional module dir is fine
  }
  for (const entry of entries) {
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) {
      if (!SKIP_DIR.test(full)) collectLuaFiles(full, out);
    } else if (entry.isFile() && entry.name.endsWith(".lua")) {
      if (!SKIP_DIR.test(full)) out.push(full);
    }
  }
}

const files = [];
for (const root of SCAN_ROOTS) collectLuaFiles(root, files);
files.sort();

let failed = 0;
for (const file of files) {
  const rel = path.relative(ADDONS_DIR, file);
  let src;
  try {
    src = fs.readFileSync(file, "utf8");
  } catch (e) {
    console.error(`ERROR  ${rel}: cannot read (${e.message})`);
    failed++;
    continue;
  }
  try {
    // WoW runs Lua 5.1; luaparse must match, and WoW allows the vararg/`...`
    // addon-table idiom at chunk scope, which luaTable-5.1 mode accepts.
    luaparse.parse(src, { luaVersion: "5.1" });
  } catch (e) {
    const loc = e.line ? `:${e.line}:${e.column || 0}` : "";
    console.error(`FAIL   ${rel}${loc}  ${e.message}`);
    failed++;
  }
}

if (failed > 0) {
  console.error(`\n${failed} file(s) failed to parse.`);
  process.exit(1);
}
console.log(`OK  ${files.length} Lua file(s) parsed cleanly.`);
