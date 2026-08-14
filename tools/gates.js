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
const os = require("os");
const { spawn } = require("child_process");

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

/*
 * Gates run in PARALLEL, output in list order.
 *
 * Every gate is a separate node process reading source and running fengari; none of them
 * write anything (only backup.js and mutate.js do, and neither is a gate). So 48 of them
 * one after another was 48 node startups of pure queueing on a machine with six cores.
 *
 * This matters more than a developer's patience: a pre-commit hook runs this, so its
 * wall-clock is a tax on every change. It has been as high as 198 seconds on a loaded box,
 * which is long enough that the honest thing to do is stop running it.
 *
 * Results are COLLECTED and printed in the original order. Finishing order is whatever the
 * scheduler decides, and a pass list that shuffles itself between runs is unreadable - the
 * same "pairs() order is not an order" rule the addon itself follows.
 */
const CONCURRENCY = Math.max(2, Math.min(gates.length, (os.cpus().length || 2) - 1));

function runGate(g) {
  return new Promise((resolve) => {
    const at = Date.now();
    const child = spawn(process.execPath, [g.file], {
      cwd: path.resolve(TOOLS_DIR, ".."),
    });
    let out = "";
    child.stdout.on("data", (d) => (out += d));
    child.stderr.on("data", (d) => (out += d));
    child.on("close", (status) => {
      resolve({ g, status, out: out.trimEnd(), ms: Date.now() - at });
    });
  });
}

async function runAll() {
  const results = new Array(gates.length);
  let next = 0;

  async function worker() {
    while (next < gates.length) {
      const i = next++;
      results[i] = await runGate(gates[i]);
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));
  return results;
}

// Wrapped rather than top-level await: this is CommonJS, where top-level await is a syntax
// error, and a runner that will not parse takes every gate down with it.
(async function main() {
  const started = Date.now();
  const results = await runAll();
  let failed = 0;

  for (const r of results) {
    if (r.status === 0) {
      // One line each on success. Nine gates that each print a paragraph is a wall
      // nobody reads, and an unread pass is the same as no pass.
      const lastLine = r.out.split(/\r?\n/).filter(Boolean).pop() || "OK";
      console.log("  " + lastLine);
    } else {
      failed++;
      console.error("\n===== " + r.g.name + " FAILED =====");
      console.error(r.out || "(no output; exit code " + r.status + ")");
    }
  }

  const elapsed = ((Date.now() - started) / 1000).toFixed(1);

  if (failed) {
    console.error("\n" + failed + " of " + gates.length + " gates FAILED in " + elapsed + "s.");
    process.exit(1);
  }

  // The slowest few, so a gate that has quietly become pathological is visible rather than
  // hidden inside one total. Without this the only symptom is "the hook feels slow lately".
  const slowest = results.slice().sort((a, b) => b.ms - a.ms).slice(0, 3);
  const slowLine = slowest.map((r) => `${r.g.name} ${(r.ms / 1000).toFixed(1)}s`).join(", ");

  console.log(`\nAll ${gates.length} gates passed in ${elapsed}s ` +
              `(${CONCURRENCY} at a time; slowest: ${slowLine}).`);
})();
