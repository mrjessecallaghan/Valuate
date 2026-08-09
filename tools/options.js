#!/usr/bin/env node
/*
 * @gate Options are reachable, and every automation defaults to off
 *
 * Unreachable-option checker.
 *
 * Every option in DEFAULT_OPTIONS should be reachable by the user: a control in the
 * Settings panel, or a slash command. An option with neither is dead weight - it
 * exists, it changes behaviour, and nothing can turn it on.
 *
 * This is the third time in one session a hand-maintained list drifted from the
 * options table (the /valuate report toggles, the Instructions tab, the selftest
 * method list). Options are added far more often than the surfaces that expose
 * them, so the drift is structural rather than careless - which makes it worth a
 * gate rather than more care.
 *
 * Usage:  node tools/options.js
 * Exits non-zero if an option is unreachable.
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");

function read(rel) {
  try {
    return fs.readFileSync(path.join(ADDON_ROOT, rel), "utf8");
  } catch (e) {
    return "";
  }
}

const core = read("Valuate.lua");

// Pull the DEFAULT_OPTIONS block and take its keys.
const block = core.match(/local DEFAULT_OPTIONS\s*=\s*\{([\s\S]*?)\n\}/);
if (!block) {
  console.error("ERROR  couldn't find DEFAULT_OPTIONS in Valuate.lua");
  process.exit(2);
}
const keys = [];
for (const line of block[1].split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z_]\w*)\s*=/);
  if (m) keys.push(m[1]);
}

// Every surface a user could reach an option through, DISCOVERED rather than
// listed. A hardcoded file list would be the same hand-maintained-list problem this
// checker exists to catch - and it already bit once: omitting ValuateUI.lua made
// the window-position option look unreachable when it is used throughout.
function collectLua(dir, out) {
  let entries;
  try {
    entries = fs.readdirSync(path.join(ADDON_ROOT, dir), { withFileTypes: true });
  } catch (e) {
    return out;
  }
  for (const entry of entries) {
    const rel = dir ? `${dir}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      if (!/^(libs|tools|\.git)$/i.test(entry.name)) collectLua(rel, out);
    } else if (entry.name.endsWith(".lua") && entry.name !== "Valuate.lua") {
      out.push(rel);
    }
  }
  return out;
}
const surfaces = collectLua("", []).map(read).join("\n");

// Slash commands and the report live in the core file, so a key mentioned there
// OUTSIDE the defaults block still counts as reachable.
const coreOutsideDefaults = core.replace(block[0], "");

const unreachable = [];
for (const key of keys) {
  const re = new RegExp(`\\b${key}\\b`);
  if (!re.test(surfaces) && !re.test(coreOutsideDefaults)) {
    unreachable.push(key);
  }
}

if (unreachable.length) {
  console.error("Options with no Settings control and no slash command:");
  for (const key of unreachable) console.error(`  ${key}`);
  console.error(
    `\n${unreachable.length} unreachable option(s). Add a control, add a command, or delete the option.`
  );
  process.exit(1);
}

/*
 * "Every automation feature is opt-in and off by default."
 *
 * That is stated in the README and it is the promise a new install rests on: you add
 * the addon and it does not start deleting, selling, rolling or accepting on your
 * behalf until you say so. Verified by hand and found sound - which is exactly the
 * kind of check that rots, because it only takes one default flipped during a
 * debugging session to make the README a lie about an irreversible feature.
 *
 * So: a BOOLEAN option whose name begins "auto" or "notify" must default to false.
 *
 * The exceptions are modifiers, not features - they widen something already switched
 * on and cannot act by themselves. Each must name the parent that gates it, so the
 * exemption stays justified rather than becoming a dumping ground.
 */
const GATED_MODIFIERS = {
  autoRollRecipes: "autoRollLoot",
  autoRollTradeGoods: "autoRollLoot",
};

const defaultedOn = [];
for (const line of block[1].split(/\r?\n/)) {
  const m = line.match(/^\s*(\w+)\s*=\s*(true|false)\s*,/);
  if (!m) continue;
  const [, name, value] = m;
  if (value !== "true") continue;
  if (!/^(auto|notify)/.test(name)) continue;

  const parent = GATED_MODIFIERS[name];
  if (!parent) {
    defaultedOn.push(`  ${name} defaults to TRUE and nothing gates it`);
  } else if (!new RegExp(`\\bnot\\s+options\\.${parent}\\b`).test(core)) {
    // The exemption claims a parent; make sure that parent actually guards something.
    defaultedOn.push(
      `  ${name} is exempted as gated by ${parent}, but no "not options.${parent}" guard exists`
    );
  }
}

if (defaultedOn.length) {
  console.error("Automation options must default to OFF (README: every automation feature is opt-in):");
  for (const line of defaultedOn) console.error(line);
  console.error(
    "\nIf one is a modifier rather than a feature, add it to GATED_MODIFIERS naming the option that gates it."
  );
  process.exit(1);
}

/*
 * Two ways the options TABLE can diverge from itself, both silent in Lua.
 *
 * (A) A key declared twice. Lua keeps the last one, so editing the first is a no-op that
 *     reads as a fix. showUpgradeArrows was declared twice with the same value, which is
 *     harmless right up until someone changes one of them.
 *
 * (B) A key written into the saved options table but never declared here. That one is not
 *     cosmetic: SaveSettingsSnapshot copies whatever it finds in the live table, but
 *     LoadSettingsSnapshot only applies keys present in DEFAULT_OPTIONS. An undeclared
 *     option is therefore saved, counted in the "saved N settings" total, and then dropped
 *     on load - the same collected-and-discarded shape as the questAccept heartbeat.
 *     minimapButtonAngle sat in that hole: you dragged the button, saved a snapshot, and
 *     the alt used the default while every other setting transferred.
 */
const seenKeys = new Set();
const dupes = [];
for (const line of block[1].split(/\r?\n/)) {
  const m = line.match(/^ {4}(\w+)\s*=/);
  if (!m) continue;
  if (seenKeys.has(m[1])) dupes.push(m[1]);
  seenKeys.add(m[1]);
}
if (dupes.length) {
  console.error("Options declared twice in DEFAULT_OPTIONS: " + dupes.join(", "));
  console.error(
    "\nLua keeps the LAST declaration, so editing the earlier line silently does nothing. " +
      "Delete one."
  );
  process.exit(1);
}

/*
 * Deliberately undeclared, with a reason. characterWindowScale has no honest default: it
 * names a scale, and "unset" is a real state the readers test for. Declaring it as "" would
 * not express that, because an empty string is truthy in Lua and every "if scale then" check
 * would start passing. It is excluded from the snapshot instead.
 */
const LAZY_OK = {
  characterWindowScale: "no honest default - an empty string would read as truthy in Lua",
};

const allLua = collectLua("", []).concat(["Valuate.lua"]);
const persisted = new Map();
for (const rel of allLua) {
  const src = read(rel);
  // GetOptions().X = is unambiguous. A bare options.X = only counts in a file that binds
  // `options` to the real table - otherwise `opts.includeInactive` and friends, which are
  // caller-supplied argument tables rather than settings, would be reported as options.
  const patterns = [/GetOptions\(\)\.(\w+)\s*=[^=]/g];
  if (/\boptions\s*=\s*(?:Valuate|self):GetOptions\(\)/.test(src)) {
    patterns.push(/\boptions\.(\w+)\s*=[^=]/g);
  }
  for (const re of patterns) {
    for (const m of src.matchAll(re)) {
      if (!seenKeys.has(m[1]) && !LAZY_OK[m[1]]) {
        persisted.set(m[1], (persisted.get(m[1]) || new Set()).add(rel));
      }
    }
  }
}

if (persisted.size) {
  console.error("Options written to the saved table but never declared in DEFAULT_OPTIONS:");
  for (const [key, files] of persisted) {
    console.error(`  ${key}  <- ${[...files].join(", ")}`);
  }
  console.error(
    "\nThese are saved by the settings snapshot and then silently dropped when it is loaded, " +
      "because LoadSettingsSnapshot only applies keys that exist in DEFAULT_OPTIONS. Declare " +
      "them with a default, or add them to LAZY_OK with a reason."
  );
  process.exit(1);
}

// A snapshot exclusion naming a key nothing declares OR writes is a claim of protection over
// something that does not exist - the same small lie as a stale HIDDEN entry in commands.js.
const excludedBlock = core.match(/local SNAPSHOT_EXCLUDED = \{([\s\S]*?)\n\}/);
if (excludedBlock) {
  const written = new Set(
    allLua.flatMap((rel) => [...read(rel).matchAll(/(?:GetOptions\(\)|options)\.(\w+)\s*=[^=]/g)].map((m) => m[1]))
  );
  const stale = [...excludedBlock[1].matchAll(/^ {4}(\w+)\s*=\s*true/gm)]
    .map((m) => m[1])
    .filter((k) => !seenKeys.has(k) && !written.has(k));
  if (stale.length) {
    console.error(
      "SNAPSHOT_EXCLUDED names options that no longer exist: " + stale.join(", ") +
        " - the exclusion protects nothing, and hides that the real key is unprotected."
    );
    process.exit(1);
  }
}

console.log(
  `OK  all ${keys.length} options are reachable from the UI or a command; ` +
  `every automation defaults to off; none declared twice; ` +
  `every persisted option is declared (${Object.keys(LAZY_OK).length} deliberately lazy).`
);
