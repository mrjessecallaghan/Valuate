#!/usr/bin/env node
/*
 * @gate Nothing unbacked has drifted ahead of its backup
 *
 * Some sibling addons are git repositories with NO REMOTE. Everything committed to them exists
 * on exactly one disk, and `tools/backup.js` writes a git bundle of each to OneDrive so there
 * is a second copy.
 *
 * That script has been self-discovering and correct for a long time. What it was not is RUN.
 * Checked on the day this gate was written:
 *
 *     Valuate-LootCollector    no previous backup at all
 *     Valuate-TSM              5 commits behind, including two releases from that same day
 *
 * backup.js says it out loud in its own header - "a thing you have to remember to do is a thing
 * that stops being done" - and then relied on somebody remembering to do it. The fix for that
 * everywhere else in this toolchain is to make the check part of the run, so here it is.
 *
 * READ ONLY, deliberately. Gates in this project never act, and a gate that quietly wrote
 * backups would hide the very drift it exists to report: the run would go green having just
 * fixed the thing, and nobody would learn that it had been drifting. This one fails and names
 * the command.
 *
 * It fails rather than warns. The window it protects is small - one disk failure - and the cost
 * of satisfying it is one command, so there is no reason to let a release go out with work that
 * exists nowhere else.
 *
 * A repo WITH a remote is not this gate's business: `git push` already put it somewhere else.
 *
 * WHAT MUTATION TESTING CANNOT REACH HERE, AND WHY IT IS SAID OUT LOUD
 *
 * This gate has no fixture. It reads the real disk, so a mutation can only exercise the paths
 * the disk happens to be in right now - and two of its branches are therefore not provable:
 *
 *   the missing-bundle branch   unreachable while both bundles exist, so deleting it changes
 *                               nothing and the mutation reports SURVIVED
 *   a broken needsBackup        an empty candidate list is this gate's SUCCESS message, and no
 *                               predicate can check itself for being wrong
 *
 * Both were written, both survived, and both were removed rather than left in the file looking
 * like protection. A mutation that cannot fail is decorative, and this project treats that as
 * the finding rather than as a formality.
 *
 * The missing-bundle branch WAS verified once by hand - the bundle was moved aside, the gate
 * failed with the right message, and it was moved back. What guards `needsBackup` is that it is
 * three lines long and mirrors backup.js, which is a weaker guarantee than a test, and saying
 * so is better than implying otherwise.
 *
 * Usage:  node tools/backupfresh.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ADDON_ROOT = path.resolve(__dirname, "..");
const ADDONS_DIR = path.resolve(ADDON_ROOT, "..");
const BACKUP_DIR = path.resolve(
  process.env.USERPROFILE || process.env.HOME || ".",
  "OneDrive",
  "Downloads",
  "valuate-backups"
);

function git(cwd, args) {
  try {
    return execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] })
      .trim();
  } catch (e) {
    return null;
  }
}

/* The same rule backup.js applies, spelled the same way. If the two ever disagree about what
 * needs backing up, this gate is reporting on a set nobody is bundling - which is worse than
 * not checking, because it reads as coverage. */
function needsBackup(dir) {
  if (git(dir, ["rev-parse", "--is-inside-work-tree"]) !== "true") return false;
  return !git(dir, ["remote"]);
}

const siblings = fs
  .readdirSync(ADDONS_DIR, { withFileTypes: true })
  .filter((e) => e.isDirectory() && /^Valuate-/.test(e.name))
  .map((e) => ({ name: e.name, dir: path.join(ADDONS_DIR, e.name) }));

/* Zero siblings means this is looking in the wrong place, not that everything is fine.
 *
 * The distinction matters because "nothing needs backing up" is this gate's success message,
 * and a broken directory scan produces it too - so the gate would pass loudest at the exact
 * moment it had stopped checking anything. Every unbacked repo on the disk would then drift in
 * silence behind a green run. */
if (!siblings.length) {
  console.error(
    `  SCAN  no Valuate-* addons found beside ${ADDON_ROOT} - this gate is looking in the wrong ` +
      `place, and "nothing to back up" from here would be a green run over an unchecked disk`
  );
  process.exit(1);
}

const candidates = siblings.filter((c) => needsBackup(c.dir));

if (!candidates.length) {
  console.log("OK  every sibling Valuate-* addon has a git remote; nothing depends on a bundle.");
  process.exit(0);
}

const problems = [];
const fine = [];
let dirtyNote = null;

for (const { name, dir } of candidates) {
  const head = git(dir, ["rev-parse", "HEAD"]);
  if (!head) {
    problems.push(`${name} is a git repo with no commits and no remote - nothing to back up yet`);
    continue;
  }

  const bundle = path.join(BACKUP_DIR, `${name}.bundle`);
  if (!fs.existsSync(bundle)) {
    problems.push(
      `${name} has NO backup at all and no remote - its entire history is on this one disk`
    );
    continue;
  }

  const heads = git(dir, ["bundle", "list-heads", bundle]) || "";
  const prev = (heads.split(/\r?\n/)[0] || "").split(/\s+/)[0];
  if (prev === head) {
    fine.push(name);
    continue;
  }

  const behind = prev ? git(dir, ["rev-list", "--count", `${prev}..HEAD`]) : null;
  problems.push(
    `${name} is ${behind ? behind + " commit(s)" : ""} ahead of its backup - that work exists ` +
      `on this disk only`
  );

  /* Reported, never failed on. Uncommitted work cannot be in a bundle no matter how recently
   * one was written, so treating it as staleness would make this gate impossible to satisfy
   * while you are mid-edit - and a gate you cannot satisfy is one you start ignoring. */
  const dirty = (git(dir, ["status", "--porcelain"]) || "").split(/\r?\n/).filter(Boolean).length;
  if (dirty > 0) {
    dirtyNote = `${name} also has ${dirty} uncommitted change(s), which no bundle can capture`;
  }
}

if (problems.length) {
  console.error(`${problems.length} unbacked addon(s) have drifted:`);
  for (const p of problems) console.error(`  - ${p}`);
  if (dirtyNote) console.error(`  note: ${dirtyNote}`);
  console.error("");
  console.error("  Fix:  node tools/backup.js");
  console.error(
    "  A bundle is a stopgap and only helps if this disk survives. A private GitHub remote " +
      "on each would end the problem for good."
  );
  process.exit(1);
}

console.log(
  `OK  ${fine.length} unbacked addon(s) are current in ${BACKUP_DIR}: ${fine.join(", ")}.`
);
