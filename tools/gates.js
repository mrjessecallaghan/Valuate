#!/usr/bin/env node
/*
 * Runs every gate. The single entry point - nothing else should list them.
 *
 * The list of gates had reached four copies: package.json's check script, CLAUDE.md,
 * README.md, and whatever I happened to type at the shell. Seven hand-maintained lists
 * in this project have drifted, and a gate list is the worst possible one to lose an
 * entry from: the missing gate does not complain, it just stops running, and everything
 * keeps reporting OK.
 *
 * So gates DISCOVER themselves. A file in tools/ is a gate if its header comment
 * contains an "@gate" line. Adding a gate means writing the gate; there is no second
 * step to forget, and no central list to fall out of date.
 *
 * Usage:  node tools/gates.js          (run from the addon root or tools/)
 *         node tools/gates.js --list   (just show what would run)
 * Exits non-zero if any gate fails.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const TOOLS_DIR = __dirname;
const SELF = path.basename(__filename);

function discoverGates() {
  const found = [];
  for (const name of fs.readdirSync(TOOLS_DIR)) {
    if (!name.endsWith(".js") || name === SELF) continue;
    const full = path.join(TOOLS_DIR, name);
    if (!fs.statSync(full).isFile()) continue;
    // Only the header: an "@gate" mentioned in prose further down is discussion,
    // not a declaration.
    const head = fs.readFileSync(full, "utf8").slice(0, 2000);
    const m = head.match(/^\s*\*\s*@gate\s+(.+)$/m);
    if (m) found.push({ name, file: full, description: m[1].trim() });
  }

  // check.js first: it is the only one that proves the Lua parses at all, and every
  // other gate's failure is noise if it does not. The rest alphabetically, which is a
  // rule rather than a preference, so the order never needs maintaining.
  found.sort((a, b) => {
    if (a.name === "check.js") return -1;
    if (b.name === "check.js") return 1;
    return a.name.localeCompare(b.name);
  });
  return found;
}

const gates = discoverGates();

/*
 * A discovery bug must be LOUD. If this silently found nothing, every commit would
 * sail through a green "0 gates passed" - the exact failure mode a gate runner exists
 * to prevent, and one that would be invisible for weeks.
 */
if (gates.length < 5) {
  console.error(
    "gates.js discovered only " + gates.length + " gate(s), which cannot be right.\n" +
    "Every gate needs an '@gate <description>' line in its header comment.\n" +
    "Refusing to report success on a list this short."
  );
  process.exit(2);
}

if (process.argv.includes("--list")) {
  for (const g of gates) console.log("  " + g.name.padEnd(16) + g.description);
  process.exit(0);
}

let failed = 0;
const started = Date.now();

for (const g of gates) {
  const res = spawnSync(process.execPath, [g.file], {
    cwd: path.resolve(TOOLS_DIR, ".."),
    encoding: "utf8",
  });
  const out = ((res.stdout || "") + (res.stderr || "")).trimEnd();

  if (res.status === 0) {
    // One line each on success. Nine gates that each print a paragraph is a wall
    // nobody reads, and an unread pass is the same as no pass.
    const lastLine = out.split(/\r?\n/).filter(Boolean).pop() || "OK";
    console.log("  " + lastLine);
  } else {
    failed++;
    console.error("\n===== " + g.name + " FAILED =====");
    console.error(out || "(no output; exit code " + res.status + ")");
  }
}

const elapsed = ((Date.now() - started) / 1000).toFixed(1);

if (failed) {
  console.error("\n" + failed + " of " + gates.length + " gates FAILED in " + elapsed + "s.");
  process.exit(1);
}
console.log("\nAll " + gates.length + " gates passed in " + elapsed + "s.");
