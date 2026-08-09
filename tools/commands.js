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

console.log(
  `OK  all ${commands.size} slash commands are documented in /valuate help ` +
    `(${Object.keys(HIDDEN).length} deliberately hidden).`
);
