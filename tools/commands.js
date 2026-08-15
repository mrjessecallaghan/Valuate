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
/*
 * Scoped to the HELP BRANCH, not the whole file.
 *
 * This used to scan every print in Valuate.lua, which meant any command that printed its own
 * usage - `/valuate trivial <levels> - 0 accepts everything`, printed by /valuate trivial
 * itself - documented itself. The claim on the tin is "documented in /valuate help"; what was
 * actually checked was "mentioned in a print somewhere". Deleting a real help line did not
 * fail this gate.
 *
 * Same shape as the options gate accepting a READ as proof an option was reachable: a check
 * that quietly tests something adjacent to its claim.
 */
// Both forms accepted: the branch gained topic support (`/valuate help gear`) in v0.148.0a,
// so it tests a PREFIX rather than equality. What this gate claims - every dispatched command
// appears in the help branch - has not changed, only where that branch begins.
const helpBranch = core.match(
  /\n\s*if (?:command == "help"|strsub\(command, 1, 4\) == "help") then\r?\n([\s\S]*?)\r?\n\s*elseif command == /
);
if (!helpBranch) {
  console.error(
    "Could not find the /valuate help branch in Valuate.lua.\n" +
      "Without it this gate cannot tell documented commands from undocumented ones."
  );
  process.exit(1);
}
const helped = new Set();
// A STRING LITERAL in the help branch, whether it is printed directly or held in the grouped
// table the branch prints from. Matching only `print(` stopped finding anything the moment
// those lines moved into a table - the text a user reads was identical, and this gate
// reported all 69 commands undocumented.
//
// Deliberately still anchored on a quote rather than searching the branch freely: a command
// name in a COMMENT here must not count as documentation.
for (const m of helpBranch[1].matchAll(/"[^"]*?\/valuate ([a-z]+)/g)) helped.add(m[1]);

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

/*
 * Every command the ADDON ITSELF suggests has to exist too.
 *
 * The health check, the error messages and the tooltips all say things like "run
 * /valuate scan" or "try /valuate deletepreview". Those are remedies handed to someone who
 * is already stuck, which makes them the worst possible place for a stale command name: the
 * user types exactly what they were told, gets "unknown command", and concludes the addon is
 * broken in some deeper way than it is.
 *
 * Same rule as the README check above, applied to the strings that reach the chat window.
 */
const luaFiles = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (/^(libs|tools|\.git)$/i.test(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith(".lua")) luaFiles.push(full);
  }
})(ADDON_ROOT);

/*
 * Only what a print() actually puts in the chat window.
 *
 * Scanning every occurrence in the source was the first attempt and it reported four
 * "problems", all wrong, in three different ways:
 *   - a COMMENT mentioning /valuate minimap
 *   - the in-game changelog panel correctly recording "Removed /valuate cache and
 *     /valuate clearcache commands" - historical text that it would be a lie to change
 *   - the help line "/valuate or /val - Open the configuration UI", where "or" is English
 *
 * A gate that fires on correct content trains people to ignore it, so the scope is now the
 * one surface the rule is actually about: strings printed to the user.
 */
const suggested = new Map();
for (const file of luaFiles) {
  let src = fs.readFileSync(file, "utf8");

  // Comments are for us, not the user. A comment mentioning a removed command is history,
  // and MinimapButton.lua has exactly that.
  src = src.replace(/--\[\[[\s\S]*?\]\]/g, " ").replace(/--[^\n]*/g, " ");

  // The in-game changelog legitimately records commands that were REMOVED - "Removed
  // /valuate cache and /valuate clearcache commands" is true and must stay true. Changing
  // it to satisfy a checker would falsify the changelog.
  src = src.replace(/CreateChangeText\(([\s\S]*?)\n\s*\)/g, " ");

  // \b before the lookahead matters: without it the greedy [a-z]+ matches "or", the
  // lookahead rejects it, and the engine backtracks to "o" - which then passes and gets
  // reported as a command called "o". The "or /val" idiom is the BARE command written out.
  for (const m of src.matchAll(/\/valuate ([a-z]+)\b(?! \/val)/g)) {
    if (!commands.has(m[1])) {
      const rel = path.relative(ADDON_ROOT, file).replace(/\\/g, "/");
      if (!suggested.has(m[1])) suggested.set(m[1], new Set());
      suggested.get(m[1]).add(rel);
    }
  }
}

if (suggested.size) {
  console.error("The addon tells users to run commands that do not exist:");
  for (const [cmd, files] of [...suggested].sort()) {
    console.error(`  /valuate ${cmd}   <- ${[...files].join(", ")}`);
  }
  console.error(
    "\nThese are printed to someone who is already stuck. They will type exactly what they " +
      "were told, get 'unknown command', and conclude something worse is wrong."
  );
  process.exit(1);
}

console.log(
  `OK  all ${commands.size} slash commands are documented in /valuate help ` +
    `(${Object.keys(HIDDEN).length} deliberately hidden); ` +
    `all ${marked.size} automation heartbeats are shown by /valuate report.`
);
