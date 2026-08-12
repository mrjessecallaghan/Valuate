#!/usr/bin/env node
/*
 * @gate Every class and spec has a template, with a role the wizard can ask for
 *
 * The templates are the wizard's entire source of intelligence: it matches your gear against
 * them and proposes the closest. A class that is missing from this table cannot be proposed
 * to anyone, ever, and nothing anywhere says so - the wizard simply hands out the nearest
 * OTHER build and looks like it worked.
 *
 * Two defects found the day this was written, both of exactly that shape:
 *
 *   - Death Knight was absent entirely. Nine classes, 28 specs. A plate-and-Strength tank
 *     asking for a tank scale got Protection Warrior or Protection Paladin, because Blood
 *     did not exist to compete.
 *
 *   - Paladin Retribution carried role = "SUPPORT". The wizard offers Tank, Healer and
 *     Damage, so Retribution could not be matched by role AT ALL - not a wrong answer, an
 *     unreachable one.
 *
 * Neither is visible by reading the file: it is 1700 lines and the gap is a thing that is
 * not there. Hence a gate.
 *
 * Usage:  node tools/speccoverage.js
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Data.lua"), "utf8");

const block = src.slice(
  src.indexOf("local CLASS_SPEC_TEMPLATES"),
  src.indexOf("ns.CLASS_SPEC_TEMPLATES")
);
if (!block) {
  console.error("ERROR  could not find CLASS_SPEC_TEMPLATES in ui/Data.lua");
  process.exit(2);
}

/*
 * The 3.3.5 class and spec list. Druid is four rather than three because Feral is two
 * genuinely different builds - a cat and a bear want opposite gear, and one template for
 * both would propose something neither wants.
 */
const EXPECTED = {
  Warrior: ["Arms", "Fury", "Protection"],
  Paladin: ["Holy", "Protection", "Retribution"],
  Hunter: ["Beast Mastery", "Marksmanship", "Survival"],
  Rogue: ["Assassination", "Combat", "Subtlety"],
  Priest: ["Discipline", "Holy", "Shadow"],
  "Death Knight": ["Blood", "Frost", "Unholy"],
  Shaman: ["Elemental", "Enhancement", "Restoration"],
  Mage: ["Arcane", "Fire", "Frost"],
  Warlock: ["Affliction", "Demonology", "Destruction"],
  Druid: ["Balance", "Feral DPS", "Feral Tank", "Restoration"],
};

// The roles the wizard actually offers. A spec outside this set is unreachable by role.
const ROLES = new Set(["TANK", "HEALER", "DAMAGER"]);

const chunks = block.split(/class = "/).slice(1);
const found = {};
const problems = [];

for (const chunk of chunks) {
  const className = chunk.slice(0, chunk.indexOf('"'));
  const specNames = [...chunk.matchAll(/name = "([^"]+)"/g)].map((m) => m[1]);
  const roles = [...chunk.matchAll(/role = "(\w+)"/g)].map((m) => m[1]);
  const weightBlocks = [...chunk.matchAll(/weights = \{/g)].length;
  const icons = [...chunk.matchAll(/icon = "([^"]+)"/g)].length;

  found[className] = specNames;

  for (const role of roles) {
    if (!ROLES.has(role)) {
      problems.push(
        `${className}: role "${role}" is not one the wizard offers (${[...ROLES].join(", ")}), ` +
          "so that spec can never be matched by role"
      );
    }
  }
  if (roles.length !== specNames.length) {
    problems.push(`${className}: ${specNames.length} spec(s) but ${roles.length} role(s)`);
  }
  if (weightBlocks !== specNames.length) {
    problems.push(
      `${className}: ${specNames.length} spec(s) but ${weightBlocks} weight table(s) - a spec ` +
        "with no weights matches nothing and would score every item zero"
    );
  }
  if (icons !== specNames.length) {
    problems.push(`${className}: ${specNames.length} spec(s) but ${icons} icon(s)`);
  }
}

for (const [className, specs] of Object.entries(EXPECTED)) {
  if (!found[className]) {
    problems.push(
      `${className} has NO template at all - the wizard can never propose it, and will hand ` +
        "out the nearest other build instead while appearing to work"
    );
    continue;
  }
  for (const spec of specs) {
    if (!found[className].includes(spec)) {
      problems.push(`${className} is missing its "${spec}" spec`);
    }
  }
}

if (problems.length) {
  console.error("Class/spec template coverage problems:");
  for (const p of problems) console.error("  " + p);
  console.error(
    "\nThe templates are the only thing the wizard matches against. A gap here is silent: " +
      "the closest OTHER build gets proposed and nothing says a better one was missing."
  );
  process.exit(1);
}

const specCount = Object.values(found).reduce((a, s) => a + s.length, 0);
const expectedCount = Object.values(EXPECTED).reduce((a, s) => a + s.length, 0);
console.log(
  `OK  all ${Object.keys(EXPECTED).length} classes and ${expectedCount} specs have templates ` +
    `(${specCount} total defined); every role is one the wizard can ask for.`
);
