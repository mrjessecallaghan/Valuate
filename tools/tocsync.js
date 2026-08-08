#!/usr/bin/env node
/*
 * Verifies the .toc's ui\*.lua list matches what's actually in ui/.
 *
 * This exists because of a real incident: a shell edit stripped the backslashes from
 * the .toc, producing "uiPickers.lua" and silently dropping ui\InfoPanels.lua from the
 * load order. Both files still parsed cleanly - they just never loaded. That failure is
 * invisible to a syntax check and only shows up in-game as a missing panel.
 *
 * Usage:  node tools/tocsync.js        (run from the addon root or tools/)
 * Exits non-zero on any mismatch.
 */
"use strict";

const fs = require("fs");
const path = require("path");

// Work from the addon root whether invoked there or from tools/.
const ADDON_ROOT = fs.existsSync("Valuate.toc")
  ? "."
  : path.resolve(__dirname, "..");

const tocPath = path.join(ADDON_ROOT, "Valuate.toc");
const uiDir = path.join(ADDON_ROOT, "ui");

if (!fs.existsSync(tocPath)) {
  console.error("Valuate.toc not found (run from the addon root or tools/).");
  process.exit(2);
}

const toc = fs.readFileSync(tocPath, "utf8");
const listed = [...toc.matchAll(new RegExp("^ui\\\\([A-Za-z]+\\.lua)", "gm"))].map(
  (m) => m[1]
);
const onDisk = fs.existsSync(uiDir)
  ? fs.readdirSync(uiDir).filter((f) => f.endsWith(".lua"))
  : [];

let ok = true;
for (const f of listed) {
  if (!fs.existsSync(path.join(uiDir, f))) {
    console.error("  MISSING FILE   .toc lists ui\\" + f + " but it is not on disk");
    ok = false;
  }
}
for (const f of onDisk) {
  if (!listed.includes(f)) {
    console.error(
      "  NEVER LOADED   ui/" + f + " exists but is absent from the .toc"
    );
    ok = false;
  }
}

// A malformed entry (backslash stripped) shows up as a ui-looking line we didn't match.
for (const line of toc.split(/\r?\n/)) {
  const t = line.trim();
  if (/^ui[A-Za-z]+\.lua$/.test(t)) {
    console.error("  MALFORMED      '" + t + "' - missing the ui\\ separator");
    ok = false;
  }
}

/*
 * Doc drift: CLAUDE.md carries a table of the ui/ modules, and it has gone stale twice
 * already - once when the split created it, once when CharacterWindow was added. Stale
 * guidance is worse than none, because it is what a fresh session trusts instead of
 * re-deriving. So the docs are checked like code.
 */
const claudeMd = path.join(ADDON_ROOT, "CLAUDE.md");
if (fs.existsSync(claudeMd)) {
  const doc = fs.readFileSync(claudeMd, "utf8");
  const undocumented = onDisk.filter(
    (f) => !doc.includes("`" + f + "`")
  );
  if (undocumented.length) {
    for (const f of undocumented) {
      console.error(
        "  UNDOCUMENTED   ui/" + f + " is not listed in CLAUDE.md's module table"
      );
    }
    ok = false;
  }
}

// README version vs .toc version.
//
// The README states the current version in its "This is a fork" note, and that
// line has silently gone ten releases stale once already. It is the repo's front
// page, so a wrong version there is the first thing anyone reads - and it is the
// sixth hand-maintained thing in this project to drift.
try {
  const tocVersion = (toc.match(/^##\s*Version:\s*(\S+)/m) || [])[1];
  const readme = fs.readFileSync(path.join(ADDON_ROOT, "README.md"), "utf8");
  const readmeVersion = (readme.match(/currently \*\*v([^*]+)\*\*/) || [])[1];

  if (tocVersion && readmeVersion && tocVersion !== readmeVersion) {
    console.error(
      `MISMATCH  README says v${readmeVersion}, .toc says ${tocVersion}`
    );
    ok = false;
  }
} catch (e) {
  // No README, or it doesn't state a version: not a sync failure.
}

/*
 * The /valuate verify checklist.
 *
 * It is a hand-maintained list, which in this project is a category with a track
 * record: six of them have silently drifted (report toggles, the Instructions tab, the
 * options table, the selftest method list, the README version, the changelog). This one
 * is worse than most if it rots, because its entire purpose is telling someone what to
 * trust - a checklist that names a version nobody shipped is actively misleading.
 *
 * Two things are checkable without judgement:
 *   - every `since` names a real CHANGELOG release
 *   - every `id` is unique, since /valuate verify <id> takes the FIRST match and a
 *     duplicate would silently shadow the other entry
 */
try {
  const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
  const block = lua.match(/local VERIFY_CHECKS = \{([\s\S]*?)\n\}/);
  if (block) {
    const changelog = fs.readFileSync(path.join(ADDON_ROOT, "CHANGELOG.md"), "utf8");
    const released = new Set(
      [...changelog.matchAll(/^## \[([^\]]+)\]/gm)].map((m) => m[1])
    );

    const entries = [...block[1].matchAll(/id = "([^"]+)", since = "([^"]+)"/g)];
    if (!entries.length) {
      console.error("  VERIFY  VERIFY_CHECKS parsed to zero entries - the shape changed");
      ok = false;
    }

    const seen = new Set();
    for (const [, id, since] of entries) {
      if (seen.has(id)) {
        console.error(
          "  VERIFY  duplicate check id '" + id +
            "' - /valuate verify " + id + " would only ever reach the first"
        );
        ok = false;
      }
      seen.add(id);

      if (!released.has(since)) {
        console.error(
          "  VERIFY  check '" + id + "' says since v" + since +
            ", which is not a release in CHANGELOG.md"
        );
        ok = false;
      }
    }
    if (ok) {
      console.log(
        "OK  /valuate verify: " + entries.length +
          " behavioural checks, all ids unique and all versions real."
      );
    }
  }
} catch (e) {
  // No Valuate.lua or no CHANGELOG: covered by other checks.
}

if (!ok) {
  console.error("\n.toc / ui/ / CLAUDE.md are OUT OF SYNC.");
  process.exit(1);
}
console.log(
  "OK  .toc, ui/ and CLAUDE.md in sync (" + listed.length + " modules): " +
    listed.join(" -> ")
);
