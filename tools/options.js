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

console.log(
  `OK  all ${keys.length} options are reachable from the UI or a command; ` +
  `every automation defaults to off.`
);
