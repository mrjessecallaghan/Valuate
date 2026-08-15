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

/*
 * Reachable means the user can CHANGE it, not that the code reads it.
 *
 * This used to accept any mention of the key anywhere outside the defaults - which every
 * option satisfies by definition, since something has to read it. The check was therefore
 * close to vacuous for anything living in the core file, and it waved through `todoOnLogin`
 * in v0.113.0a, an option with no control and no command at all.
 *
 * So: an option is reachable when something ASSIGNS to it - `options.key =`, or an explicit
 * `["key"] =`. A checkbox handler and a slash toggle both do; a comparison like
 * `options.key == false` does not, which is exactly the distinction that was missing.
 *
 * `==` is excluded deliberately: `=[^=]` would otherwise match the first character of `==`.
 */
/*
 * Two ways to be reachable, because there are two ways this codebase builds a control.
 *
 * ASSIGNED - `options.key = x`, or `options.a, options.b = ...` where it is not the last
 * name on the left. That is a checkbox handler or a slash toggle.
 *
 * DECLARED AS DATA - the key appears as a quoted string. The Settings panel builds its
 * battleground toggles from a table of `{ key = "autoRelease", label = ... }` and assigns
 * through `GetOptions()[toggle.key]`, which no amount of regex will see as an assignment
 * to a specific option. The declaration is the control.
 *
 * `==` is excluded deliberately: a bare `=[^=]` would match the first character of `==`,
 * which is how the old rule counted `if options.key == false` as a way to change it.
 */
const unreachable = [];
for (const key of keys) {
  const assigned = new RegExp(
    `\\.${key}\\b\\s*(,[^=\\n]*)?=(?!=)|\\[\\s*["']${key}["']\\s*\\]\\s*=(?!=)`
  );
  const declared = new RegExp(`["']${key}["']`);
  const reachable =
    assigned.test(surfaces) || assigned.test(coreOutsideDefaults) ||
    declared.test(surfaces) || declared.test(coreOutsideDefaults);
  if (!reachable) unreachable.push(key);
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

/*
 * FINDABLE, not merely reachable.
 *
 * The check above asks whether an option can be changed at all. It counts a slash command,
 * correctly - an option with a command is not dead weight. But a command you would have to
 * already know exists is not something anyone finds, and this addon has repeatedly shipped
 * features that were complete, documented, and invisible: the battleground automations were
 * command-only for four releases, and `autoEquipOnLevelUp` - which puts gear on your
 * character without asking twice - was command-only from the day it landed.
 *
 * "A feature nobody can find is a feature that does not exist" is the argument that added the
 * Battlegrounds & Dungeons section. This makes it a rule instead of a thing I remember.
 *
 * So: every option a USER holds an opinion about needs a Settings control. Persisted state
 * does not - a window position is not a preference, and putting it on a settings page would
 * be worse than leaving it out.
 */
const NOT_A_PREFERENCE = {
  uiPosition: "where you dragged the window to - state, not an opinion",
  minimapButtonAngle: "where you dragged the minimap button to",
  verifiedChecks: "which /valuate verify items you have ticked off",
  pvpScale: "nominated BY NAME, so a checkbox cannot express it - /valuate pvpscale",
  pvpScaleRestore: "internal bookkeeping for restoring the scale after a battleground",
  characterWindowScale: "which scale the character window shows - chosen in that window",
  autoAcceptTrivialBelow: "a level threshold, set with /valuate trivial <n>",
};

/*
 * Every automation appears in the "what is running" line.
 *
 * ns.AUTOMATION_LABELS drives the summary at the top of Settings. A label missing there means
 * an automation runs without ever being listed as running - which is worse than not having
 * the line, because the line reads as complete.
 *
 * This is the fifth hand-maintained list in this project to be given a rule rather than
 * trusted: the About panel, the verify checklist, the report toggles and the in-game manual
 * all drifted first.
 */
const labels = core.match(/ns\.AUTOMATION_LABELS = \{([\s\S]*?)\n\}/);
if (labels) {
  const labelled = new Set([...labels[1].matchAll(/^\s*(\w+)\s*=/gm)].map((m) => m[1]));
  const NOT_A_RUNNING_AUTOMATION = {
    autoDeleteIntervalSecs: "how often junk cleanup runs, not a thing that runs",
    autoRepairGuildFirst: "which purse auto-repair uses, once auto-repair is on",
    autoAcceptSkipTrivial: "which quests auto-accept skips, once auto-accept is on",
    autoRollRecipes: "widens auto-roll, cannot act alone",
    autoRollTradeGoods: "widens auto-roll, cannot act alone",
    autoScan: "WHEN scanning happens, not whether",
    notifyBagUpgradeMode: "which upgrades the prompt covers, once it is on",
    notifyBagUpgradeStyle: "chat or dialog, once the prompt is on",
    notifyUpgradeSound: "whether the prompt makes a noise",
    notifyOtherSpecUpgrades: "widens the prompt to other specs",
    autoConfirmBindOnLoot: "answers a dialog for an equip you asked for",
    autoDeleteDryRun: "makes auto-delete report instead of act",
    autoDeleteKeepFree: "how many slots auto-delete leaves free",
    autoDeleteMinValue: "the floor auto-delete will not go below",
    autoDeleteValueSource: "which price auto-delete reads",
    autoDeleteMaxQuality: "the quality ceiling auto-delete will not pass",
    autoDeleteMaxValue: "the value ceiling auto-delete will not pass",
  };
  const automations = keys.filter(
    (k) => /^(auto|notify)/.test(k) && !NOT_A_PREFERENCE[k] && !NOT_A_RUNNING_AUTOMATION[k]
  );
  /*
   * The other half of that table: the beat each automation writes to.
   *
   * A wrong beat key is silent in the worst way. It does not error - GetAutomationHeartbeat
   * returns nil, the UI says "not yet this session", and that is exactly what an automation
   * which is genuinely idle looks like. So the one line that exists to tell you whether
   * something is working would confidently say it has never run.
   *
   * This is the same failure as autoRoll/autoRollLoot, which this file caught minutes after
   * both were written. That one was a key that did not exist; a beat key that does not exist
   * is worse, because the label still shows up and reads as informed.
   */
  const recorded = new Set(
    [...core.matchAll(/MarkAutomation\(\s*["'](\w+)["']/g)].map((m) => m[1])
  );
  const beats = [...labels[1].matchAll(/^\s*(\w+)\s*=.*?beat\s*=\s*["'](\w+)["']/gm)];
  const missingBeat = automations.filter(
    (k) => labelled.has(k) && !beats.some((b) => b[1] === k)
  );
  if (missingBeat.length) {
    console.error(
      "Automations in ns.AUTOMATION_LABELS with no beat:\n  " + missingBeat.join("\n  ") +
        "\n\nEvery automation has to be able to say what it last did, including when what it\n" +
        "did was nothing. Add beat = \"<key>\" and a MarkAutomation call on every exit path."
    );
    process.exit(1);
  }
  const phantom = beats.filter((b) => !recorded.has(b[2]));
  if (phantom.length) {
    console.error(
      "Beat keys nothing ever records:\n  " +
        phantom.map((b) => `${b[1]} -> "${b[2]}"`).join("\n  ") +
        "\n\nGetAutomationHeartbeat returns nil for these, so the UI reports 'not yet this\n" +
        "session' forever - which is indistinguishable from an automation that is idle."
    );
    process.exit(1);
  }

  const unlisted = automations.filter((k) => !labelled.has(k));
  if (unlisted.length) {
    console.error(
      "Automations missing from ns.AUTOMATION_LABELS:\n  " + unlisted.join("\n  ") +
        "\n\nThe Settings summary lists what is running. An automation absent from " +
        "that table runs without ever appearing there, and the line reads as complete " +
        "either way."
    );
    process.exit(1);
  }
}

const settingsPanel = read("ui/Settings.lua");
const unfindable = keys.concat(Object.keys(LAZY_OK)).filter(
  (k) => !NOT_A_PREFERENCE[k] && !settingsPanel.includes(k)
);
if (unfindable.length) {
  console.error(
    "Options with no control in the Settings panel:\n  " + unfindable.join("\n  ") +
      "\n\nA slash command counts as REACHABLE but not as findable. Add a checkbox, or add the\n" +
      "key to NOT_A_PREFERENCE with a reason someone would accept - persisted state and\n" +
      "things chosen next to what they affect both qualify."
  );
  process.exit(1);
}

// A NOT_A_PREFERENCE entry for an option that no longer exists is the same small lie as a
// stale SNAPSHOT_EXCLUDED entry: it reads as a considered decision about a live option.
const staleExempt = Object.keys(NOT_A_PREFERENCE).filter(
  (k) => !keys.includes(k) && !LAZY_OK[k]
);
if (staleExempt.length) {
  console.error(
    "NOT_A_PREFERENCE names options that do not exist: " + staleExempt.join(", ") +
      " - remove them, or the exemption looks like a decision about something real."
  );
  process.exit(1);
}

console.log(
  `OK  all ${keys.length} options are reachable from the UI or a command; ` +
  `every automation defaults to off; none declared twice; ` +
  `every persisted option is declared (${Object.keys(LAZY_OK).length} deliberately lazy); ` +
  `every preference has a Settings control (${Object.keys(NOT_A_PREFERENCE).length} are state, not preferences).`
);
