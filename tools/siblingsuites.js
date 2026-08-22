#!/usr/bin/env node
/*
 * @gate Every sibling addon's own test suite actually runs
 *
 * Some of the integration addons ship their own headless suite rather than being gated from
 * here. Valuate-TSM has 162 assertions of its own, covering the circuit breaker that stops
 * the client freeze and the price filter that decides what you can afford - and none of them
 * were in `node tools/gates.js`, so "all 74 gates pass" was a true sentence that left them
 * out.
 *
 * A suite outside the gate run is a suite that silently stops being run. Nobody decides to
 * stop running it; it just quietly falls out of the habit, and the first sign is a bug in the
 * thing it covered. That is the same failure as a stale checklist, and this project has now
 * had both.
 *
 * So: find them, run them, and make their result part of the one number that gets quoted.
 *
 * ABSENT IS FINE, BROKEN IS NOT. A sibling that is not installed is skipped and named. A
 * sibling that IS installed and whose suite fails - or whose suite has gone missing while the
 * addon is still here - fails this gate, because both of those are someone's coverage
 * quietly evaporating.
 *
 * Usage:  node tools/siblingsuites.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ADDONS_DIR = path.resolve(__dirname, "..", "..");

// Each sibling that owns a suite, and where it lives. A sibling with no suite is not listed:
// this gate is about suites that exist and are not being run, not about coverage that was
// never written.
const SUITES = [
  { addon: "Valuate-TSM", script: path.join("tools", "test.js") },
];

// Siblings with no suite of their own, gated from Valuate/tools instead. Listed so that
// "which addon is covered how" is answerable from one place rather than by grepping.
const GATED_FROM_HERE = {
  "Valuate-AdiBags": "tools/api.js",
  "Valuate-PassLoot": "tools/passloottest.js",
  "Valuate-LootCollector": "tools/lctest.js + tools/lchook.js",
};

let ok = true;
const ran = [];
const skipped = [];

for (const { addon, script } of SUITES) {
  const dir = path.join(ADDONS_DIR, addon);
  if (!fs.existsSync(dir)) {
    skipped.push(`${addon} (not installed)`);
    continue;
  }

  const abs = path.join(dir, script);
  if (!fs.existsSync(abs)) {
    // The addon is here and its suite is not. That is not "nothing to do" - it is coverage
    // that used to exist and does not, which is exactly what this gate is for.
    console.error(
      `  MISSING  ${addon} is installed but ${script} is gone. Its assertions are not ` +
        "running anywhere, and nothing else would have told you."
    );
    ok = false;
    continue;
  }

  try {
    // Run it from its own tools directory: its README documents `cd tools && node test.js`,
    // and its requires resolve from there.
    const out = execFileSync(process.execPath, [path.basename(script)], {
      cwd: path.dirname(abs),
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    const counts = out.match(/(\d+)\s+passed,\s+(\d+)\s+failed/);
    ran.push(`${addon}: ${counts ? counts[1] + " checks" : "passed"}`);
  } catch (e) {
    const out = ((e.stdout || "") + (e.stderr || "")).trim();
    console.error(`  FAILED  ${addon}'s own suite:\n${out.split(/\r?\n/).slice(-12).join("\n")}`);
    ok = false;
  }
}

if (!ok) process.exit(1);

const parts = [];
if (ran.length) parts.push(ran.join("; "));
if (skipped.length) parts.push("skipped " + skipped.join(", "));
console.log(
  "OK  sibling suites run inside the gate run (" + (parts.join(" | ") || "none installed") +
    "). Gated from here instead: " +
    Object.keys(GATED_FROM_HERE).map((a) => a.replace("Valuate-", "")).join(", ") + "."
);
