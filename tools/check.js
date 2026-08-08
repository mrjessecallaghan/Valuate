#!/usr/bin/env node
/*
 * Valuate syntax + lint gate.
 *
 * 1. Parses every Lua file with a Lua 5.1 parser. A WoW addon with a syntax error
 *    simply fails to load, so this catches the worst failure mode review can miss.
 * 2. Enforces lint rules that encode bugs we actually shipped (see CLAUDE.md).
 *
 * Neither step proves BEHAVIOUR - there is no Lua runtime here.
 *
 * Usage:  node tools/check.js
 * Exits non-zero if any file fails to parse or violates a rule.
 * Bypass a rule on one line with:  -- valuate-lint-ignore: <rule-name>
 */
"use strict";

const fs = require("fs");
const path = require("path");

let luaparse;
try {
  luaparse = require("luaparse");
} catch (e) {
  console.error("luaparse is not installed. Run:  cd tools && npm install");
  process.exit(2);
}

const TOOLS_DIR = __dirname;
const ADDON_ROOT = path.resolve(TOOLS_DIR, "..");
const ADDONS_DIR = path.resolve(ADDON_ROOT, "..");

const SCAN_ROOTS = [
  ADDON_ROOT,
  path.join(ADDONS_DIR, "Valuate-AdiBags"),
  path.join(ADDONS_DIR, "Valuate-PassLoot"),
  path.join(ADDONS_DIR, "Valuate-TSM"),
];
const SKIP_DIR = /(^|[\\/])(libs|node_modules|\.git|_Valuate_Original_Archive.*|_Valuate_Handoff)([\\/]|$)/i;

/*
 * Lint rules. Each encodes a real defect - see CLAUDE.md for the full story.
 * `test(line, file)` returns true when the line VIOLATES the rule.
 */
const RULES = [
  {
    name: "no-staticpopup",
    why: "StaticPopup frames are recycled; showing ours taints them and blocks secure dialogs (e.g. ConfirmBindOnUse). Use Valuate:ShowConfirmDialog.",
    test: (l) => /\bStaticPopup_(Show|Hide)\s*\(|\bStaticPopupDialogs\s*\[/.test(l),
  },
  {
    name: "no-blizzard-ui-writes",
    why: "Writing Blizzard UI fields or calling their handlers taints the frame; the client then blocks actions like Complete Quest. Draw your own highlight instead.",
    test: (l) =>
      /\b(QuestInfoFrame|QuestRewardScrollFrame|MerchantFrame|CharacterFrame)\s*\.\s*\w+\s*=[^=]/.test(l) ||
      /\bQuestInfoItem_OnClick\s*\(/.test(l),
  },
  {
    name: "no-protected-calls",
    why: "Automating item use is a protected path; the client blocks the use and blames Valuate. Let the user answer that popup.",
    test: (l) => /\bConfirmBindOnUse\s*\(/.test(l),
  },
  {
    // The nastiest bug class in the split: `local EditingScaleName = ns.EditingScaleName`
    // looks identical to the (correct) pattern used for constants, but for MUTABLE
    // state it silently breaks - the local copy gets assigned, other files keep reading
    // the old value, and nothing ever errors. Must always be ns.X at every read/write.
    name: "no-relocalised-shared-state",
    why: "This is shared MUTABLE state - re-localising it silently desyncs files (the copy is assigned, others keep the old value, no error). Use ns.X directly at every read and write. See CLAUDE.md.",
    test: (l) =>
      /^\s*local\s+[\w,\s]*\b(ValuateUIFrame|EditingScaleName|CurrentSelectedScale|ScaleEditorFrame|ScaleListButtons|ValuateUI_OnTemplateOverwrite|IsDraggingFrame)\b/.test(
        l
      ) && /=/.test(l),
  },
  {
    // Two bugs in one session came from a raw OnUpdate while a shared animation
    // engine and a shared timer helper both already existed:
    //
    //   * MinimapButton's pulse and its drag handler both wrote the button's single
    //     OnUpdate slot, so whichever wrote second silently discarded the other's
    //     cleanup - leaving a starburst glow stuck on screen at 1.14x scale.
    //   * ui/Widgets.lua cancelled a hover fade with SetScript("OnUpdate", nil).
    //     That worked before tweens moved onto the shared driver and became a no-op
    //     afterwards, with nothing to notice: clearing a script slot that was never
    //     set raises no error. Pressed buttons stopped showing a pressed state.
    //
    // Neither is visible to a parser, and both look completely ordinary in review.
    // So: a raw OnUpdate is allowed, but it has to be a decision someone wrote down.
    // Animations belong on ns.Anim (Anim.owned / Anim.cancelProp own a named
    // property rather than the frame's one script slot); delays belong on
    // ValuateAfter. What is left is drivers and throttles, which are real - annotate
    // them and the gate holds the line against the next accidental one.
    name: "raw-onupdate-needs-reason",
    why: "A frame has ONE OnUpdate slot, so two features that both use it silently overwrite each other, and cancelling via it is a no-op for anything on the shared animation driver. Use Anim.owned/Anim.cancelProp for animation and ValuateAfter for delays - or annotate this line with -- valuate-lint-ignore: raw-onupdate-needs-reason  <why it must be raw>.",
    test: (l) => /:SetScript\s*\(\s*["']OnUpdate["']/.test(l),
  },
  {
    name: "no-duplicate-junk-logic",
    why: "Junk classification must go through the single IsItemJunk() helper - duplicating it is how the '0 junk found' bug survived two fixes.",
    test: (l, file) =>
      path.basename(file) === "Valuate.lua" &&
      /:CheckItem\s*\(|:IsJunk\s*\(/.test(l) &&
      !/function\s+IsItemJunk|IsItemJunk\s*\(/.test(l),
  },
];

// Rules that are allowed to match inside the shared helper / rule definitions
// themselves. Keyed by rule name -> regex describing an exempt context line.
// An ignore directive may sit on the offending line or on the line directly above it
// (kinder to long lines). Format: -- valuate-lint-ignore: <rule-name>  [reason]
function isIgnored(line, prevLine, ruleName) {
  const re = /--\s*valuate-lint-ignore:\s*([\w-]+)/;
  for (const l of [line, prevLine || ""]) {
    const m = l.match(re);
    if (m && m[1] === ruleName) return true;
  }
  return false;
}

function collectLuaFiles(root, out) {
  let entries;
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch (e) {
    return;
  }
  for (const entry of entries) {
    const full = path.join(root, entry.name);
    if (entry.isDirectory()) {
      if (!SKIP_DIR.test(full)) collectLuaFiles(full, out);
    } else if (entry.isFile() && entry.name.endsWith(".lua")) {
      if (!SKIP_DIR.test(full)) out.push(full);
    }
  }
}

const files = [];
for (const root of SCAN_ROOTS) collectLuaFiles(root, files);
files.sort();

let parseFailures = 0;
let lintFailures = 0;

for (const file of files) {
  const rel = path.relative(ADDONS_DIR, file);
  let src;
  try {
    src = fs.readFileSync(file, "utf8");
  } catch (e) {
    console.error(`ERROR  ${rel}: cannot read (${e.message})`);
    parseFailures++;
    continue;
  }

  // --- 1. Syntax ---
  try {
    luaparse.parse(src, { luaVersion: "5.1" });
  } catch (e) {
    const loc = e.line ? `:${e.line}:${e.column || 0}` : "";
    console.error(`FAIL   ${rel}${loc}  ${e.message}`);
    parseFailures++;
    continue; // don't lint a file that doesn't parse
  }

  // --- 2. Lint ---
  const lines = src.split(/\r?\n/);
  const anchorTargets = new Map(); // settings-anchor-chain

  lines.forEach((line, i) => {
    const lineNo = i + 1;
    const prevLine = i > 0 ? lines[i - 1] : "";

    // Comments are documentation, not code - don't lint them.
    const code = line.replace(/--.*$/, "");
    if (!code.trim()) return;

    for (const rule of RULES) {
      if (isIgnored(line, prevLine, rule.name)) continue;
      if (rule.test(code, file)) {
        console.error(`LINT   ${rel}:${lineNo}  [${rule.name}] ${rule.why}`);
        console.error(`         ${line.trim()}`);
        lintFailures++;
      }
    }

    // settings-anchor-chain: two controls anchored to the same frame+point overlap.
    const anchor = code.match(
      /:SetPoint\(\s*"TOPLEFT"\s*,\s*(\w+)\s*,\s*"BOTTOMLEFT"/
    );
    if (anchor && !isIgnored(line, prevLine, "settings-anchor-chain")) {
      const key = anchor[1];
      if (anchorTargets.has(key)) {
        console.error(
          `LINT   ${rel}:${lineNo}  [settings-anchor-chain] "${key}" is already used as an anchor at line ${anchorTargets.get(
            key
          )} - two controls on one anchor render on top of each other. Anchor to the PREVIOUS control.`
        );
        lintFailures++;
      } else {
        anchorTargets.set(key, lineNo);
      }
    }
  });

  // --- no-bank-in-destructive-path ---------------------------------------
  // The bank snapshot exists so banked gear can be considered for best-in-slot.
  // It must NEVER reach a path that deletes, sells, or counts free space:
  //   - deletion is irreversible, and bank slots are where people store the gear
  //     they most care about;
  //   - "keep N slots free" is a promise about BAGS, and counting bank slots
  //     towards it would silently stop the cleanup that promise depends on.
  // Bank containers are also unreadable unless the bank frame is open, so any
  // such code would misbehave differently depending on where the player stood.
  const GUARDED_FNS = /\b(?:function\s+Valuate:(AutoDeleteJunk|AutoSellJunk)|local\s+function\s+(CountFreeBagSlots))\s*\(/g;
  let gm;
  while ((gm = GUARDED_FNS.exec(src))) {
    const fnName = gm[1] || gm[2];
    const kw = /\b(function|if|while|for|end)\b/g;
    kw.lastIndex = gm.index + gm[0].length;
    let depth = 1;
    let body = null;
    let km;
    while ((km = kw.exec(src))) {
      if (km[1] === "end") {
        if (--depth === 0) {
          body = src.slice(gm.index, km.index);
          break;
        }
      } else depth++;
    }
    if (body === null) continue;

    const offender = body
      .replace(/--.*$/gm, "")
      .match(/\b(GetBankCache|ValuateBankCache|BANK_CONTAINER\w*|FIRST_BANK_BAG|LAST_BANK_BAG)\b/);
    if (!offender) continue;

    const lineNo = src.slice(0, gm.index + body.indexOf(offender[0])).split(/\r?\n/).length;
    console.error(
      `LINT   ${rel}:${lineNo}  [no-bank-in-destructive-path] ${fnName} references '${offender[0]}'. The bank snapshot must never reach a delete/sell/free-slot path - deletion is irreversible and "keep N slots free" is a promise about BAGS.`
    );
    lintFailures++;
  }

  // --- sort-needs-tiebreaker ---------------------------------------------
  // table.sort is NOT stable. A comparator that answers a tie with "false"
  // leaves equal elements in whatever order they arrived in - and that order
  // usually traces back to pairs(), which is undefined. The result is a "best"
  // item, a tooltip line order, or a deletion queue that changes between runs.
  // Every comparator must define a TOTAL order: compare the primary key, then
  // fall through to a unique tiebreaker (itemId, bag/slot, scale name).
  // Detected shape: a comparator whose body is a single `return` with no branch.
  const SORT_CALL = /\b(?:table\.sort|tsort)\s*\(\s*[^,()]+,\s*function\s*\([^)]*\)/g;
  let sm;
  while ((sm = SORT_CALL.exec(src))) {
    const bodyStart = sm.index + sm[0].length;
    // Walk to the comparator's own `end`, tracking nested block keywords.
    const kw = /\b(function|if|while|for|end)\b/g;
    kw.lastIndex = bodyStart;
    let depth = 1;
    let body = null;
    let km;
    while ((km = kw.exec(src))) {
      if (km[1] === "end") {
        if (--depth === 0) {
          body = src.slice(bodyStart, km.index);
          break;
        }
      } else depth++;
    }
    if (body === null) continue;

    const bodyCode = body.replace(/--.*$/gm, "");
    const returns = (bodyCode.match(/\breturn\b/g) || []).length;
    if (returns > 1 || /\bif\b/.test(bodyCode)) continue; // has a tiebreaker

    const lineNo = src.slice(0, sm.index).split(/\r?\n/).length;
    const line = lines[lineNo - 1] || "";
    if (isIgnored(line, lines[lineNo - 2] || "", "sort-needs-tiebreaker")) continue;
    console.error(
      `LINT   ${rel}:${lineNo}  [sort-needs-tiebreaker] Comparator has no tiebreaker, so equal elements sort in an arbitrary (pairs-derived) order and the result changes between runs. Compare the primary key, then fall through to a unique key.`
    );
    console.error(`         ${line.trim()}`);
    lintFailures++;
  }
}

if (parseFailures || lintFailures) {
  console.error(
    `\n${parseFailures} parse failure(s), ${lintFailures} lint violation(s).`
  );
  process.exit(1);
}
console.log(
  `OK  ${files.length} Lua file(s) parsed cleanly; ${RULES.length + 3} lint rules passed.`
);
