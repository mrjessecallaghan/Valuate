#!/usr/bin/env node
/*
 * @gate Every slash command is listed in /valuate help
 *
 * `tools/options.js` already checks that every OPTION is reachable from the UI or a command,
 * on the grounds that an option nothing can switch on is dead weight. Commands had no such
 * check, and the same rot had set in: 30 commands dispatched, 19 listed in help.
 *
 * The eleven missing ones were not an even spread. They were the automation toggles and
 * every command that DELETES or SELLS - including `deletepreview`, which is the one the
 * addon itself tells you to run before enabling deletion. Someone reading `/valuate help`
 * in the game could not discover that any of it existed. The README documented them, which
 * is not where you look when you are standing at a vendor.
 *
 * This is the eighth hand-maintained list in this project to drift, and the argument is the
 * same every time: the list is edited far less often than the thing it describes, so the
 * drift is structural rather than careless.
 *
 * Usage:  node tools/commands.js
 * Exits non-zero if a command has no help line.
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");
const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const dispatchStart = core.indexOf('SlashCmdList["VALUATE"]');
if (dispatchStart < 0) {
  console.error("ERROR  could not find the slash command handler in Valuate.lua");
  process.exit(2);
}
const dispatch = core.slice(dispatchStart);

/*
 * Every shape the dispatcher uses to recognise a command. Collected from the handler itself
 * rather than listed here - a hardcoded command list would be the exact problem this gate
 * exists to catch, and it would go stale the same way.
 */
const commands = new Set();
for (const m of dispatch.matchAll(/command == "([a-z]+)"/g)) commands.add(m[1]);
for (const m of dispatch.matchAll(/strsub\(command, 1, \d+\) == "([a-z]+)\s?"/g)) commands.add(m[1]);
for (const m of dispatch.matchAll(/command:match\("\^([a-z]+)/g)) commands.add(m[1]);

if (commands.size < 15) {
  console.error(
    `ERROR  only found ${commands.size} commands - the dispatcher's shape changed, so this ` +
      "gate would pass by seeing nothing"
  );
  process.exit(2);
}

/*
 * A command is documented if `/valuate <name>` appears in a help print line.
 *
 * The colour-code prefix has to be tolerated. `deletepreview` is highlighted in orange
 * precisely BECAUSE it is the safety command, and the first version of this pattern reported
 * it as undocumented for having been emphasised. A gate that punishes the thing it exists to
 * encourage gets the emphasis removed rather than the gate fixed.
 */
const helped = new Set();
for (const m of core.matchAll(/print\("[^"]*?\/valuate ([a-z]+)/g)) helped.add(m[1]);

/*
 * Deliberately undocumented, each with a reason. Not a convenience list - anything here is a
 * command a user cannot discover, so the bar is that discovering it would not help them.
 */
const HIDDEN = {
  pulse: "previews the minimap animation; a development aid, not a feature",
  ui: "an alias for bare /valuate, which the first help line already covers",
  rollcheck: "the `why` command handles both spellings; `why` is the documented one",
};

const missing = [...commands]
  .filter((c) => !helped.has(c) && !HIDDEN[c])
  .sort();

if (missing.length) {
  console.error("Commands with no line in /valuate help:");
  for (const c of missing) console.error(`  /valuate ${c}`);
  console.error(
    `\n${missing.length} undocumented command(s). Add a help line, or add it to HIDDEN in ` +
      "tools/commands.js with a reason someone would accept."
  );
  process.exit(1);
}

// A stale HIDDEN entry is its own small lie: it claims a command exists and is deliberately
// undocumented, when the command may have been renamed or removed.
const staleHidden = Object.keys(HIDDEN).filter((c) => !commands.has(c));
if (staleHidden.length) {
  console.error(
    "HIDDEN names commands that no longer exist: " + staleHidden.join(", ") +
      " - remove them so the exemption list stays honest."
  );
  process.exit(1);
}

/*
 * Every automation heartbeat is shown by /valuate report.
 *
 * README: "Every automated path has a diagnostic that explains why it did NOTHING - that's
 * what the *check/preview commands are for", and `report` is described as saying when each
 * automation last ran and what it concluded.
 *
 * `questAccept` had been recorded since auto-accept existed and was never in the report's
 * list, so its outcome was captured and thrown away every time. That is the worst version of
 * this: not missing data, but data collected and discarded, which nobody notices because the
 * recording side looks correct.
 *
 * Same family as the check above - two lists that have to agree, edited at different times.
 */
const marked = new Set(
  [...core.matchAll(/MarkAutomation\("(\w+)"/g)].map((m) => m[1])
);
const reportBlock = core.match(/local HEARTBEATS = \{[\s\S]*?\n    \}/);
if (!reportBlock) {
  console.error("ERROR  could not find the HEARTBEATS list in the report");
  process.exit(2);
}
const shown = new Set(
  [...reportBlock[0].matchAll(/key = "(\w+)"/g)].map((m) => m[1])
);

const unshown = [...marked].filter((k) => !shown.has(k)).sort();
if (unshown.length) {
  console.error("Automations that record a heartbeat nothing ever displays:");
  for (const k of unshown) console.error(`  ${k}`);
  console.error(
    "\nAdd them to HEARTBEATS in /valuate report. Recording an outcome and never showing " +
      "it is worse than not recording it: the code looks like it works."
  );
  process.exit(1);
}

const phantom = [...shown].filter((k) => !marked.has(k)).sort();
if (phantom.length) {
  console.error(
    "The report lists automations that never record a heartbeat: " + phantom.join(", ") +
      " - they will always read 'not yet this session', which is a lie by omission."
  );
  process.exit(1);
}

/*
 * Every command the README names has to be a command that exists.
 *
 * Same failure as the scale list's empty state, which told new users to click "New Blank
 * Scale" and "+" for several releases after both were renamed. Documentation naming a thing
 * that is not there is worse than no documentation: it sends someone confident in the wrong
 * direction, and they blame themselves rather than the file.
 *
 * The README is edited far less often than the dispatcher, so this drifts structurally.
 */
const readme = fs.readFileSync(path.join(ADDON_ROOT, "README.md"), "utf8");
// Exactly ONE space, not \s+. The command block aligns its descriptions in a column, so
// "/valuate                  open the UI" would otherwise read as a command called "open" -
// this gate reporting a bug in its own first run, which is how a checker teaches people to
// ignore it.
const readmeCommands = new Set(
  [...readme.matchAll(/\/valuate ([a-z]+)/g)].map((m) => m[1])
);
const phantomInReadme = [...readmeCommands].filter((c) => !commands.has(c)).sort();
if (phantomInReadme.length) {
  console.error("README.md names commands that do not exist:");
  for (const c of phantomInReadme) console.error(`  /valuate ${c}`);
  console.error(
    "\nRename or remove them. A command that was renamed still reads as real to anyone " +
      "following the README, and they will assume they typed it wrong."
  );
  process.exit(1);
}

console.log(
  `OK  all ${commands.size} slash commands are documented in /valuate help ` +
    `(${Object.keys(HIDDEN).length} deliberately hidden); ` +
    `all ${marked.size} automation heartbeats are shown by /valuate report.`
);
