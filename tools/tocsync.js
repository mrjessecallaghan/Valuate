#!/usr/bin/env node
/*
 * @gate .toc / ui/ / CLAUDE.md / the verify list stay in step
 *
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

// CHANGELOG's newest entry vs .toc version.
//
// The gap that let v0.176.0a AND v0.176.1a both ship with the .toc still reading 0.175.0a.
// Everything else here compares the hand-maintained files to the .toc, and they all agreed -
// because the release forgot the .toc, so all three stayed wrong together. The CHANGELOG is
// the one file a release cannot skip, which makes it the right thing to check the .toc against
// rather than the other way round.
//
// The version the client reports is the .toc's. Getting it wrong means a bug report names a
// build that never had the bug, which is worse than no version at all.
try {
  const tocVersion = (toc.match(/^##\s*Version:\s*(\S+)/m) || [])[1];
  const changelog = fs.readFileSync(path.join(ADDON_ROOT, "CHANGELOG.md"), "utf8");
  const newest = (changelog.match(/^##\s*\[([^\]]+)\]/m) || [])[1];

  if (tocVersion && newest && tocVersion !== newest) {
    console.error(
      `MISMATCH  CHANGELOG's newest entry is ${newest}, .toc says ${tocVersion}. ` +
        "The .toc is the version the client reports and every bug report quotes."
    );
    ok = false;
  }
} catch (e) {
  // No CHANGELOG: not a sync failure.
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
 * Three things are checkable without judgement:
 *   - every `since` names a real CHANGELOG release
 *   - every `id` is unique, since /valuate verify <id> takes the FIRST match and a
 *     duplicate would silently shadow the other entry
 *   - no `id` collides with a verb of the command itself. RunVerify tests the verbs
 *     BEFORE it searches the list, so a check called "next" or "reset" could never be
 *     opened by name - and the wrong thing would happen instead, which is worse than
 *     nothing happening. The verbs are read out of RunVerify rather than listed here,
 *     because a hand-maintained list is the exact thing this file exists to catch.
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

    const runVerify = lua.match(/function Valuate:RunVerify[\s\S]*?\nend\n/);
    const verbs = new Set(
      runVerify ? [...runVerify[0].matchAll(/verb == "(\w+)"/g)].map((m) => m[1]) : []
    );
    if (!verbs.size) {
      console.error("  VERIFY  found no verbs in RunVerify - the shape changed, so ids are unguarded");
      ok = false;
    }

    const seen = new Set();
    for (const [, id, since] of entries) {
      if (verbs.has(id)) {
        console.error(
          "  VERIFY  check id '" + id + "' is also a /valuate verify verb - " +
            "the verb wins, so that check could never be opened by name"
        );
        ok = false;
      }

      if (seen.has(id)) {
        console.error(
          "  VERIFY  duplicate check id '" + id +
            "' - /valuate verify " + id + " would only ever reach the first"
        );
        ok = false;
      }
      seen.add(id);

      // A check that names a gate is telling the reader "the logic is already proven, you
      // are only looking at the screen" - which makes it a SMALLER ask, and a wrong one is
      // therefore worse than no claim at all. The file has to exist.
      const gateClaim = block[1].match(
        new RegExp('id = "' + id + '"[\\s\\S]{0,400}?gate = "([^"]+)"')
      );
      if (gateClaim && !fs.existsSync(path.join(ADDON_ROOT, gateClaim[1]))) {
        console.error(
          "  VERIFY  check '" + id + "' says its logic is proven by " + gateClaim[1] +
            ", which does not exist - that claim makes the check look safe to skip"
        );
        ok = false;
      }

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
          " behavioural checks, all ids unique, all versions real, " +
          "none shadowed by the " + verbs.size + " command verbs."
      );
    }
  }
} catch (e) {
  // No Valuate.lua or no CHANGELOG: covered by other checks.
}

/*
 * "N of them execute real Lua."
 *
 * README.md and ARCHITECTURE.md both make that claim, and it is the load-bearing one in
 * both files: it is how a reader decides which parts of this addon are behaviour-tested
 * and which are merely known to parse. It said "Four" while five gates were running -
 * the eighth hand-maintained list here to drift, and the fifth to drift by ADDING
 * something rather than removing it, which is the direction nobody re-reads for.
 *
 * A gate is a runtime gate if it pulls in the shared fengari harness. Counted, not
 * listed. Number words are accepted because the prose reads better with them, and a
 * rule that quietly ignores "Four" would be no rule at all.
 */
const WORD_NUMBERS = { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7,
                       eight: 8, nine: 9, ten: 10 };
try {
  const toolFiles = fs.readdirSync(path.join(ADDON_ROOT, "tools"))
    .filter((n) => n.endsWith(".js") && n !== "gates.js" && n !== "luaharness.js");
  const runtimeGates = toolFiles.filter((n) => {
    const src = fs.readFileSync(path.join(ADDON_ROOT, "tools", n), "utf8");
    return /require\(\s*["'][^"']*luaharness/.test(src) && /@gate\s/.test(src.slice(0, 2000));
  });

  const claim = /(\w+)\s+(?:of\s+(?:them|these)\s+)?\**execute real Lua|(\w+)\s+subsystems\b/gi;
  for (const rel of ["README.md", "ARCHITECTURE.md"]) {
    const text = fs.readFileSync(path.join(ADDON_ROOT, rel), "utf8");
    let m, found = 0;
    claim.lastIndex = 0;
    while ((m = claim.exec(text))) {
      const word = (m[1] || m[2] || "").toLowerCase();
      const stated = WORD_NUMBERS[word] !== undefined ? WORD_NUMBERS[word] : parseInt(word, 10);
      if (isNaN(stated)) continue;
      found++;
      if (stated !== runtimeGates.length) {
        console.error(
          "  GATES  " + rel + " says " + word + " gate(s) execute real Lua, but " +
            runtimeGates.length + " do: " + runtimeGates.join(", ")
        );
        ok = false;
      }
    }
    if (!found) {
      console.error(
        "  GATES  " + rel + " no longer states how many gates execute real Lua - " +
          "either restore the claim or drop this rule; a claim nobody checks is worse than none"
      );
      ok = false;
    }
  }
  if (ok) {
    console.log(
      "OK  " + runtimeGates.length + " gate(s) execute real Lua, and both docs say so."
    );
  }
} catch (e) {
  console.error("  GATES  could not count the runtime gates: " + e.message);
  ok = false;
}

/*
 * The IN-GAME changelog (ui/InfoPanels.lua).
 *
 * It had drifted seventeen releases behind the .toc before anyone looked, which is
 * worse than shipping no changelog at all: a user opening that tab sees a history
 * ending at 0.17.2a and concludes nothing has happened since. Every other
 * version-bearing surface here is already checked - the .toc, the README - and this
 * one, the only one a USER sees, was not.
 *
 * The rule is just "the newest version named there is the current one". The panel is
 * a curated summary rather than one entry per patch, so this costs a single line per
 * release and makes a seventeen-release gap impossible.
 */
try {
  const tocVersion = (toc.match(/^##\s*Version:\s*(\S+)/m) || [])[1];
  const panel = fs.readFileSync(path.join(ADDON_ROOT, "ui", "InfoPanels.lua"), "utf8");

  if (tocVersion && /Version\s+\d+\.\d+/.test(panel)) {
    // "(Current)" marks the entry the panel presents as newest.
    //
    // Matched inside a QUOTED STRING, not anywhere in the file. There is a Lua comment two
    // lines above the real header carrying the same words, and the old pattern matched that
    // first - so bumping the comment while leaving the header alone passed cleanly, and the
    // in-game "what is new" heading sat one version behind with nothing objecting. Which is
    // exactly what happened in v0.197.0a.
    //
    // A comment cannot contain a double quote followed by that text; the header always does.
    const current = panel.match(/"Version\s+(\d+\.\d+\.\d+[a-z]?)\s*\(Current\)/);
    if (!current) {
      console.error(
        "  CHANGELOG  ui/InfoPanels.lua has no \"Version X (Current)\" entry - " +
          "the in-game changelog cannot say what it is current AT"
      );
      ok = false;
    } else if (current[1] !== tocVersion) {
      console.error(
        "  CHANGELOG  in-game changelog says v" + current[1] +
          " is current, but the .toc says " + tocVersion
      );
      ok = false;
    } else {
      /*
       * And it is still a SUMMARY.
       *
       * The panel's own comment says "deliberately a SUMMARY, not one entry per patch - the
       * full history lives in CHANGELOG.md; what belongs here is what a user would notice".
       * Nothing enforced that, and in one day of releases it grew to 68 bullets - several of
       * them "FIXED: X" describing states that lasted a couple of hours and never reached
       * anybody's game. Telling a user about a bug they never had is not news.
       *
       * A generous ceiling, because this covers well over a hundred releases and pruning
       * older entries is a judgement nobody should be forced into by a build failure. It
       * catches the drift that actually happened: a bullet appended per release, forever.
       */
      /*
       * The in-game manual still describes the automations that exist.
       *
       * The Instructions panel's Automation section documented five of them while the addon
       * had twenty - it stopped at quest rewards, so the hit cap, auto-equip, the junk rescue
       * and every queue automation were absent from the only manual inside the game. That is
       * the same drift the About panel had, and the same drift the verify checklist had: a
       * hand-maintained list nobody was checking.
       *
       * The authority is the help's own "auto" group, which commands.js already proves is
       * complete. If a command is documented there as an automation, the manual has to at
       * least name it.
       */
      const core2 = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
      const autoGroup = core2.match(/key = "auto",[\s\S]*?\n\s*\} \},/);
      if (autoGroup) {
        const autoCmds = [...autoGroup[0].matchAll(/\/valuate (\w+)/g)].map((x) => x[1]);
        const missing = autoCmds.filter((c) => !panel.includes("/valuate " + c));
        // A ceiling rather than zero: several automations are described by NAME in prose
        // without their command, which is fine for a manual. What is not fine is the manual
        // falling silently behind as automations are added - which is what happened.
        if (missing.length > autoCmds.length / 2) {
          console.error(
            "  MANUAL  the Instructions panel names only " +
              (autoCmds.length - missing.length) + " of " + autoCmds.length +
              " automation commands. Missing: " + missing.join(", ") +
              "\n             The in-game manual is drifting behind the automations. It is the " +
              "only documentation inside the game."
          );
          ok = false;
        }
      }

      const NEWS_BULLET_LIMIT = 60;
      // Scoped to the CURRENT-version block. Counting bullets across the whole file swept up
      // every historical section too and reported 221 against a limit of 60 - a rule firing
      // on prose nobody is being asked to change is a rule that gets switched off.
      const newsBlock = panel.match(
        /Version[^\n]*\(Current\)[\s\S]*?table\.concat\(\{([\s\S]*?)\n\s*\}, "\\n"\)/
      );
      const bullets = newsBlock ? (newsBlock[1].match(/^\s*"•/gm) || []).length : 0;
      if (bullets > NEWS_BULLET_LIMIT) {
        console.error(
          "  CHANGELOG  the in-game 'what is new' list has " + bullets + " bullets, over the " +
            NEWS_BULLET_LIMIT + " this panel is meant to hold. It is a summary of what a user " +
            "would NOTICE, not one entry per release - the full history is CHANGELOG.md. " +
            "Fold the recent ones together, or make the case for raising the limit."
        );
        ok = false;
      } else {
        console.log(
          "OK  in-game changelog is current at v" + tocVersion +
            " (" + bullets + " bullets, still a summary)."
        );
      }
    }
  }
} catch (e) {
  // No InfoPanels.lua: covered by the module checks above.
}

if (!ok) {
  console.error("\n.toc / ui/ / CLAUDE.md are OUT OF SYNC.");
  process.exit(1);
}
console.log(
  "OK  .toc, ui/ and CLAUDE.md in sync (" + listed.length + " modules): " +
    listed.join(" -> ")
);
