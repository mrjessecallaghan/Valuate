#!/usr/bin/env node
/*
 * Break the code on purpose, and check the gates notice.
 *
 * A passing gate tells you the code does something. It does not tell you the gate would
 * NOTICE if the code stopped doing it - and an assertion that notices nothing reads exactly
 * like one that works. This is the only tool here that can tell those apart.
 *
 * Every mutation in tools/mutations.js applies one plausible break and names the gate that
 * must fail. A "SURVIVED" line is the finding: that assertion is decorative.
 *
 * Usage:
 *   node tools/mutate.js              every mutation
 *   node tools/mutate.js whybis       just one gate's
 *
 * SAFETY. This edits real source files. Originals are held in memory, restored after every
 * mutation, and verified byte-for-byte at the end; an interrupt restores before exiting. If
 * restoration ever fails it says so loudly and exits non-zero - `git checkout -- .` is the
 * recovery, which is also why this is not part of `node tools/gates.js`.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ADDON_ROOT = path.resolve(__dirname, "..");
const MUTATIONS = require("./mutations.js");

const only = process.argv[2];
const selected = only ? MUTATIONS.filter((m) => m.gate === only) : MUTATIONS;

if (selected.length === 0) {
  const gates = [...new Set(MUTATIONS.map((m) => m.gate))].sort();
  console.error(
    only
      ? `No mutations for gate "${only}". Known: ${gates.join(", ")}`
      : "tools/mutations.js is empty."
  );
  process.exit(1);
}

// Originals, read once. Every restore compares against these rather than re-reading, so a
// partial write cannot become the new baseline.
const originals = new Map();
for (const m of selected) {
  const abs = path.join(ADDON_ROOT, m.file);
  if (!originals.has(abs)) originals.set(abs, fs.readFileSync(abs, "utf8"));
}

function restoreAll() {
  for (const [abs, text] of originals) {
    try {
      if (fs.readFileSync(abs, "utf8") !== text) fs.writeFileSync(abs, text);
    } catch (e) {
      console.error(`  RESTORE FAILED for ${abs}: ${e.message}`);
    }
  }
}

process.on("SIGINT", () => {
  console.error("\ninterrupted - restoring sources");
  restoreAll();
  process.exit(130);
});

/* Apply one mutation. Returns null on success, or a reason the mutation could not be made -
 * which is itself a failure: a mutation that cannot be applied is testing nothing, and the
 * usual cause is that the code moved and nobody updated the entry. */
function apply(m) {
  const abs = path.join(ADDON_ROOT, m.file);
  const orig = originals.get(abs);

  let start = 0;
  let end = orig.length;
  if (m.scope) {
    start = orig.indexOf(m.scope.start);
    if (start < 0) return `scope start not found: ${m.scope.start}`;
    end = orig.indexOf(m.scope.end, start);
    if (end < 0) return `scope end not found: ${m.scope.end}`;
  }

  const body = orig.slice(start, end);
  if (!body.includes(m.from)) return `anchor not found${m.scope ? " in scope" : ""}: ${m.from}`;

  fs.writeFileSync(abs, orig.slice(0, start) + body.replace(m.from, m.to) + orig.slice(end));
  return null;
}

/* A gate that is ALREADY failing reports every mutation as "caught", and the run comes back
 * green while testing nothing. That is not hypothetical - a stray backtick in a gate's Lua
 * block made it a syntax error, and this tool cheerfully confirmed all six of its mutations.
 * So establish the baseline first: every gate must pass on untouched source. */
const gates = [...new Set(selected.map((m) => m.gate))].sort();
const unhealthy = [];
for (const g of gates) {
  try {
    execFileSync(process.execPath, [path.join(__dirname, `${g}.js`)], {
      cwd: ADDON_ROOT,
      stdio: "pipe",
    });
  } catch (e) {
    unhealthy.push(g);
  }
}
if (unhealthy.length) {
  console.error(
    `These gates FAIL on untouched source, so every mutation would look "caught":\n` +
      unhealthy.map((g) => `  tools/${g}.js`).join("\n") +
      "\n\nFix them first - a mutation run against a broken gate proves nothing."
  );
  process.exit(1);
}

let caught = 0;
const survived = [];
const broken = [];

console.log(
  `Mutating ${selected.length} assertion(s)${only ? ` for ${only}` : ""} - each must make its gate FAIL.\n`
);

for (const m of selected) {
  let problem;
  try {
    problem = apply(m);
    if (problem) {
      broken.push({ m, problem });
      console.log(`  UNAPPLIED  [${m.gate}] ${m.label}`);
      continue;
    }
    try {
      execFileSync(process.execPath, [path.join(__dirname, `${m.gate}.js`)], {
        cwd: ADDON_ROOT,
        stdio: "pipe",
      });
      survived.push(m);
      console.log(`  SURVIVED   [${m.gate}] ${m.label}`);
    } catch (e) {
      caught++;
      console.log(`  caught     [${m.gate}] ${m.label}`);
    }
  } finally {
    restoreAll();
  }
}

// Byte-for-byte, not "probably fine". This tool's whole risk is leaving a source file broken.
let restored = true;
for (const [abs, text] of originals) {
  if (fs.readFileSync(abs, "utf8") !== text) {
    restored = false;
    console.error(`\n  !! ${path.relative(ADDON_ROOT, abs)} was NOT restored. Run: git checkout -- .`);
  }
}

console.log("");
if (broken.length) {
  console.error(`${broken.length} mutation(s) could not be applied - they are testing nothing:`);
  for (const { m, problem } of broken) console.error(`  [${m.gate}] ${m.label}\n      ${problem}`);
  console.error("");
}
if (survived.length) {
  console.error(`${survived.length} mutation(s) SURVIVED. Those assertions protect nothing:`);
  for (const m of survived) console.error(`  [${m.gate}] ${m.label}`);
  console.error("\nEither the gate is missing an assertion, or its fixture is tidier than the game.");
}

if (!survived.length && !broken.length && restored) {
  console.log(`All ${caught} mutation(s) caught, sources restored.`);
}

// A green run after a failed restore would be the worst possible outcome, so it gates the code.
process.exit(survived.length || broken.length || !restored ? 1 : 0);
