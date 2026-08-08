#!/usr/bin/env node
/*
 * @gate Lua syntax + 11 lint rules
 *
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
    // Valuate-TSM is hook-only, and the constraint its whole design rests on is that
    // `#rt.headCols` stays 8. TSM does index arithmetic off that length in three
    // places (the price-per-unit right-click toggle and the on-show price relabel in
    // AuctionResultsTable.lua, and the "% Market Value" relabel in Shopping's
    // Util.lua). Appending even one column silently retargets all three onto OUR
    // columns - TSM keeps working, just on the wrong data.
    //
    // That is why the integration keeps its headers in rt.valuateHeadCols and its
    // cells in row.valuateCols. The rule was written down in Core.lua and enforced by
    // nothing, which is the exact shape of most of the bugs found in this project.
    //
    // Reads are fine and common (`#rt.headCols`, `rt.headCols[i]:SetWidth(...)`);
    // only ASSIGNMENT is banned.
    name: "no-tsm-headcols-write",
    why: "TSM does index arithmetic off #rt.headCols in three places - appending to it silently retargets them onto Valuate's columns. Put headers in rt.valuateHeadCols and cells in row.valuateCols instead. See the design note in Valuate-TSM/Core.lua.",
    test: (l) =>
      /\btinsert\s*\(\s*[\w.]*\brt\.headCols\b/.test(l) ||
      /\btable\.insert\s*\(\s*[\w.]*\brt\.headCols\b/.test(l) ||
      /\brt\.headCols\s*\[[^\]]*\]\s*=[^=]/.test(l) ||
      /\brt\.headCols\s*=[^=]/.test(l),
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

/*
 * Rules implemented OUTSIDE the RULES array, because one line of context is not enough
 * for them - they need the AST, or a whole file of accumulated state.
 *
 * Named rather than counted. This was "RULES.length + 3", a magic number that had to be
 * remembered every time a structural rule was added and which silently under-reported
 * the moment it was not. Listing them makes the reported count derived, and doubles as
 * the only index of what these rules are.
 */
const STRUCTURAL_RULES = [
  "settings-anchor-chain",
  "sort-needs-tiebreaker",
  "no-bank-in-destructive-path",
  "pairs-list-needs-sort",
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
  let ast = null;
  try {
    ast = luaparse.parse(src, { luaVersion: "5.1", locations: true });
  } catch (e) {
    const loc = e.line ? `:${e.line}:${e.column || 0}` : "";
    console.error(`FAIL   ${rel}${loc}  ${e.message}`);
    parseFailures++;
    continue; // don't lint a file that doesn't parse
  }

  // --- 2. Lint ---
  const lines = src.split(/\r?\n/);
  const anchorTargets = new Map(); // settings-anchor-chain

  /*
   * --- pairs-list-needs-sort (AST, not line-based) -----------------------------
   *
   * A function that builds a LIST inside a pairs() loop and then returns it is
   * returning an arbitrary order, because pairs() has none. Every caller that indexes
   * [1], renders the list in order, or picks a "first" is then arbitrary too - and it
   * looks completely stable right up until a reload, a scale rename, or a different
   * machine.
   *
   * This is the most persistent bug class in the project: six unstable table.sort
   * comparators, then Valuate:GetActiveScales, which built the active-scale list this
   * way. Its order decided the Best Equipment column layout AND, through
   * GetPrimaryScale taking element [1], which scale drove the upgrade arrows, the
   * character-sheet score and the auto-roll baseline.
   *
   * sort-needs-tiebreaker catches only the half that already calls table.sort. This
   * catches the half that never sorts at all.
   *
   * Narrow on purpose: it needs an ARRAY APPEND (tinsert / table.insert) inside a
   * pairs() loop, and the same local returned. Populating a keyed table is a set, where
   * order is meaningless, and is not flagged. Across the whole addon it currently fires
   * on nothing, and fires on GetActiveScales the moment its sort is removed.
   */
  if (ast) {
    const walk = (node, visit) => {
      if (!node || typeof node !== "object") return;
      visit(node);
      for (const k of Object.keys(node)) {
        if (k === "loc") continue;
        const v = node[k];
        if (Array.isArray(v)) v.forEach((n) => walk(n, visit));
        else if (v && typeof v === "object") walk(v, visit);
      }
    };
    const isInsertCall = (n) =>
      n.type === "CallExpression" && n.base &&
      (n.base.name === "tinsert" ||
        (n.base.type === "MemberExpression" && n.base.identifier &&
          n.base.identifier.name === "insert"));

    walk(ast, (fn) => {
      if (fn.type !== "FunctionDeclaration") return;
      const appended = new Set(), sorted = new Set(), returned = new Set();

      walk(fn, (n) => {
        if (n.type === "ForGenericStatement") {
          const it = (n.iterators || [])[0];
          if (it && it.type === "CallExpression" && it.base && it.base.name === "pairs") {
            walk(n.body, (b) => {
              if (isInsertCall(b)) {
                const t = (b.arguments || [])[0];
                if (t && t.type === "Identifier") appended.add(t.name);
              }
            });
          }
        }
        if (n.type === "CallExpression" && n.base && n.base.type === "MemberExpression" &&
            n.base.identifier && n.base.identifier.name === "sort") {
          const t = (n.arguments || [])[0];
          if (t && t.type === "Identifier") sorted.add(t.name);
        }
        if (n.type === "ReturnStatement") {
          for (const a of n.arguments || []) if (a.type === "Identifier") returned.add(a.name);
        }
      });

      for (const name of appended) {
        if (!returned.has(name) || sorted.has(name)) continue;
        const lineNo = (fn.loc && fn.loc.start.line) || 0;
        if (isIgnored(lines[lineNo - 1] || "", lines[lineNo - 2] || "", "pairs-list-needs-sort")) continue;
        console.error(
          `LINT   ${rel}:${lineNo}  [pairs-list-needs-sort] Builds '${name}' from pairs() and returns it, so its order is arbitrary - every caller that indexes it, renders it in order, or takes a "first" inherits that. Sort before returning.`
        );
        console.error(`         ${(lines[lineNo - 1] || "").trim()}`);
        lintFailures++;
      }
    });
  }

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
  `OK  ${files.length} Lua file(s) parsed cleanly; ${RULES.length + STRUCTURAL_RULES.length} lint rules passed.`
);
