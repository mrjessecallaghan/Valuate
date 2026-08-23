#!/usr/bin/env node
/*
 * Backs up the sibling integration addons that have no git remote.
 *
 * NOT a gate - it performs an action, and gates only ever read. Run it with:
 *
 *     node tools/backup.js
 *
 * Two sibling addons are git repositories with real history and NO REMOTE. Everything committed
 * to them exists on exactly one disk.
 *
 * WHICH TWO HAS CHANGED, AND THAT IS THE POINT. When this was written it was Valuate-AdiBags
 * and Valuate-PassLoot; both have remotes now. Today it is Valuate-TSM and
 * Valuate-LootCollector, neither of which existed then. The list below is DISCOVERED for
 * exactly that reason - a hand-written one would still be bundling the two addons that no
 * longer need it while ignoring the two that do.
 *
 * The right fix is a private GitHub repo for each, which needs a person - `gh` is not installed
 * here and creating them is not something a script should do on someone's behalf. Until then, a
 * git bundle is a complete, verifiable, single-file clone source: `git clone
 * Valuate-PassLoot.bundle` restores the entire history.
 *
 * This exists because the manual version drifted. The bundles were written by hand on 29 July
 * and not again until 9 August, by which point AdiBags was EIGHT commits ahead of its backup
 * and PassLoot one. A thing you have to remember to do is a thing that stops being done - the
 * same argument behind every self-discovering list in this toolchain.
 *
 * And then it drifted again anyway, because being self-discovering does not make it RUN: on
 * 23 August, Valuate-LootCollector had no bundle at all and Valuate-TSM was five commits
 * behind. tools/backupfresh.js is the gate that closes that loop - it fails the ordinary gate
 * run when anything here has drifted, and names this script.
 *
 * Reports how stale each backup was before refreshing it, so running it tells you whether you
 * needed to.
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");
const ADDONS_DIR = path.resolve(ADDON_ROOT, "..");
const BACKUP_DIR = path.resolve(
  process.env.USERPROFILE || process.env.HOME || ".",
  "OneDrive",
  "Downloads",
  "valuate-backups"
);

function git(cwd, args) {
  try {
    return execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
  } catch (e) {
    return null;
  }
}

// A sibling addon worth backing up: it is a git repo, and nothing else is holding a copy.
function needsBackup(dir) {
  if (git(dir, ["rev-parse", "--is-inside-work-tree"]) !== "true") return false;
  const remotes = git(dir, ["remote"]);
  return !remotes; // has a remote => already backed up somewhere that is not this disk
}

const candidates = fs
  .readdirSync(ADDONS_DIR, { withFileTypes: true })
  .filter((e) => e.isDirectory() && /^Valuate-/.test(e.name))
  .map((e) => ({ name: e.name, dir: path.join(ADDONS_DIR, e.name) }))
  .filter((c) => needsBackup(c.dir));

if (!candidates.length) {
  console.log("Nothing to back up: every sibling Valuate-* addon has a git remote.");
  process.exit(0);
}

fs.mkdirSync(BACKUP_DIR, { recursive: true });

let failed = 0;
for (const { name, dir } of candidates) {
  const bundle = path.join(BACKUP_DIR, `${name}.bundle`);
  const head = git(dir, ["rev-parse", "HEAD"]);

  // How far behind was the existing backup? Reported BEFORE overwriting it, because that
  // number is the whole argument for this script existing.
  let staleness = "no previous backup";
  if (fs.existsSync(bundle)) {
    const heads = git(dir, ["bundle", "list-heads", bundle]) || "";
    const prev = (heads.split(/\r?\n/)[0] || "").split(/\s+/)[0];
    if (prev === head) {
      staleness = "already current";
    } else if (prev) {
      const behind = git(dir, ["rev-list", "--count", `${prev}..HEAD`]);
      staleness = behind ? `was ${behind} commit(s) behind` : "was out of date";
    }
  }

  const dirty = (git(dir, ["status", "--porcelain"]) || "").split(/\r?\n/).filter(Boolean).length;

  if (git(dir, ["bundle", "create", bundle, "--all"]) === null) {
    console.error(`  FAIL  could not bundle ${name}`);
    failed++;
    continue;
  }
  // A bundle that cannot be verified is not a backup, so this is checked rather than assumed.
  if (git(dir, ["bundle", "verify", bundle]) === null) {
    console.error(`  FAIL  ${name} bundle did not verify - do not rely on it`);
    failed++;
    continue;
  }

  console.log(
    `OK  ${name}: bundled at ${head.slice(0, 8)} (${staleness})` +
      (dirty ? `  |  ${dirty} UNCOMMITTED file(s) are NOT in the bundle` : "")
  );
}

if (failed) process.exit(1);

console.log(`\nBundles in ${BACKUP_DIR}`);
console.log("Restore any of them with:  git clone <name>.bundle <dir>");
console.log(
  "This is a stopgap. Two private GitHub repos would end the problem; a bundle only helps " +
    "if the disk it is on survives."
);
