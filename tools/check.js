#!/usr/bin/env node
/*
 * @gate Lua syntax + 14 lint rules
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
/*
 * Methods and namespaces added after Interface 30300, with the version each arrived.
 *
 * Matched as METHOD CALLS (`:Name(`) or namespace reads, so a local variable that happens
 * to share a name is not flagged. Every one of these is absent from the addon today; the
 * list exists so that stays true.
 */
const RETAIL_ONLY = [
  /:\s*SetColorTexture\s*\(/, //          7.0  - use SetTexture(r, g, b, a), via ns.SetSolidColor
  /:\s*SetShown\s*\(/, //                 5.0  - use Show() / Hide()
  /:\s*SetAtlas\s*\(/, //                 6.0  - no atlases on 3.3.5a; use a texture path
  /:\s*SetMaskTexture\s*\(/, //           6.0
  /:\s*SetResizeBounds\s*\(/, //          9.0  - use SetMinResize / SetMaxResize
  /:\s*SetIgnoreParentAlpha\s*\(/, //     7.0
  /:\s*SetIgnoreParentScale\s*\(/, //     7.0
  /:\s*SetPropagateKeyboardInput\s*\(/, // 4.0
  /\bC_Container\s*\./, //                10.0 - GetContainerItemInfo etc. are global here
  /\bC_Item\s*\./, //                     8.0
  /\bC_EquipmentSet\s*\./, //             8.0  - GetEquipmentSetInfo is global here
  /\bCreateFromMixins\s*\(/, //           6.0
  /\bsecurecallfunction\s*\(/, //         8.0
  /\bGetSpecialization\s*\(/, //          5.0  - and meaningless on a classless server
  /\bUnitEffectiveLevel\s*\(/, //         7.0
];

/*
 * The rule checks itself before it checks anything else.
 *
 * A lint rule is code nobody lints. This one is a list of regexes matched against source
 * text, where the plausible failures are silent in both directions: a pattern that matches
 * nothing passes every file forever, and one that matches too much fails correct code -
 * `destructive-paths-reverify` did exactly that earlier and was caught only because a
 * mutation run happened to re-check the baseline.
 *
 * The negatives matter more than the positives here. `SetTexture(1, 1, 1, 1)` is the
 * CORRECT 3.3.5a form and must never be flagged, and `C_Timer` is feature-detected in
 * Valuate.lua on purpose, so it is deliberately absent from the list above - a fact worth
 * pinning, because "add C_Timer, it's a C_ namespace" is an obvious-looking change that
 * would break a working detection.
 */
const RETAIL_ONLY_SAMPLES = [
  ["accent:SetColorTexture(1, 1, 1, 1)", true],
  ["f:SetShown(true)", true],
  ["local info = C_Container.GetContainerItemInfo(1, 1)", true],
  ["tex:SetAtlas('foo')", true],
  ["local spec = GetSpecialization()", true],
  // Correct 3.3.5a calls, and near-misses that must stay clean.
  ["colorPreview:SetTexture(1, 1, 1, 1)", false],
  ["local shown = frame:IsShown()", false],
  ["ns.SetSolidColor(tex, 1, 1, 1, 1)", false],
  ["local after = C_Timer and C_Timer.After", false],
  ["local id = GetSpecializationInfoName", false],
];
for (const [line, shouldMatch] of RETAIL_ONLY_SAMPLES) {
  if (RETAIL_ONLY.some((re) => re.test(line)) !== shouldMatch) {
    console.error(
      `ERROR  no-retail-only-api self-check failed: "${line}" should ` +
        `${shouldMatch ? "" : "NOT "}match. The rule is broken, so its silence means nothing.`
    );
    process.exit(2);
  }
}

/*
 * Lua allows at most 200 local variables in one function scope, and a file's top level IS
 * a function scope.
 *
 * luaparse does not enforce it, so a file that crosses the line passes every gate here and
 * then fails to COMPILE in the client - which for an addon means it silently does not load
 * at all. Valuate.lua is 7,900 lines and sits at just over half the budget, so this is not
 * urgent; it is cheap, and the failure it prevents is the worst kind (everything is green,
 * nothing works).
 *
 * Warned at 180 rather than 200 so there is room to land whatever change is in flight.
 */
const LOCAL_LIMIT = 200;
const LOCAL_WARN_AT = 180;

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
    /*
     * ui/Dialog.lua registers ValuateConfirmDialog for Escape-to-close, and says in a
     * comment that this is "safe because no caller passes onCancel - cancelling is purely
     * close-without-acting, which is exactly what hiding does."
     *
     * That is true today and it is a coupling, not an observation: Escape hides the frame
     * without running anything, so the day a caller needs cleanup on cancel, Escape starts
     * skipping it silently. The dialog is what asks "delete this scale?", so the cleanup
     * being skipped is the kind that matters.
     *
     * Enforced rather than trusted. To use onCancel, remove the RegisterEscapeClose line
     * first (or route Escape through the cancel handler) - the comment in Dialog.lua says
     * as much, and this makes ignoring it impossible rather than merely rude.
     */
    name: "no-dialog-oncancel-with-escape",
    why: "ValuateConfirmDialog is registered for Escape-to-close, which hides it WITHOUT running onCancel - so cancel cleanup would be skipped whenever Escape is used. Drop the RegisterEscapeClose in ui/Dialog.lua first, or handle cancel some other way.",
    test: (l, file) =>
      /\bonCancel\b/.test(l) &&
      path.resolve(file) !== path.resolve(ADDON_ROOT, "ui", "Dialog.lua"),
  },
  {
    name: "no-protected-calls",
    why: "Automating item use is a protected path; the client blocks the use and blames Valuate. Let the user answer that popup.",
    test: (l) => /\bConfirmBindOnUse\s*\(/.test(l),
  },
  {
    /*
     * APIs that do not exist on Interface 30300.
     *
     * Written after SetColorTexture turned up in 22 places. That one arrived in Legion
     * (7.0); this addon targets WotLK, where the solid-colour setter is
     * SetTexture(r, g, b, a). Exactly one call site used the 3.3.5 form, which is what a
     * habit looks like rather than a decision - and on a client without the method each
     * call raises, which in Lua means the rest of the enclosing function never runs. The
     * symptom is a half-built panel, not a missing line.
     *
     * Sweeping for the rest of the class found nothing else: SetShown appears only in a
     * comment saying not to use it, and C_Timer already has explicit flavour detection in
     * Valuate.lua. So this rule is not cleaning up a mess - it is making sure a mess that
     * happened once cannot happen quietly again, which is cheap while every name is
     * absent.
     *
     * The list is a floor, not a survey of the whole API. Add to it whenever one is
     * noticed; a name here costs a regex and buys a whole class of silent breakage.
     */
    name: "no-retail-only-api",
    why:
      "This API does not exist on Interface 30300 (see the version in the rule). On a client without it the call raises and the rest of the function never runs. Feature-detect it, or use the 3.3.5a equivalent.",
    test: (l, file) => {
      // ui/Shared.lua holds the feature detection, so it is the one file allowed to name
      // these. Compared by resolved PATH rather than basename - the same trap that let
      // Valuate-PassLoot's own Valuate.lua get flagged by another rule.
      if (path.resolve(file) === path.resolve(ADDON_ROOT, "ui", "Shared.lua")) return false;
      return RETAIL_ONLY.some((re) => re.test(l));
    },
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
    // Companion to raw-onupdate-needs-reason, and it exists for the same reason: an
    // animation nothing can replace is one that outlives the data it was started for.
    //
    // Two bugs came from bare Anim.tween calls, both in code written AFTER Anim.owned
    // was added to prevent exactly this:
    //
    //   * the Best Equipment score count-ups captured the score they started with and
    //     wrote to a POOLED label, so re-revealing the tab left the old run painting
    //     the previous scan's number - and the staggered delays meant it could finish
    //     LAST and win.
    //   * the stat-editor commit flash kept painting a row after the grid had been
    //     repopulated for a different scale.
    //
    // Anim.owned(frame, propKey, opts) makes re-triggering replace rather than stack,
    // and works on any table - so there is no excuse involving Blizzard frames.
    // ui/Animations.lua is the engine itself and is exempt by definition.
    //
    // A genuinely one-shot animation on something that cannot be re-triggered is fine;
    // it just has to say so. There are currently zero such sites.
    name: "anim-tween-needs-owner",
    why: "A bare Anim.tween cannot be replaced, so re-triggering stacks and the older run can finish last and win - twice now that meant a stale value left on screen. Use Anim.owned(frame, propKey, opts), which works on any table - or annotate with -- valuate-lint-ignore: anim-tween-needs-owner  <why it can never be re-triggered>.",
    test: (l, file) =>
      path.basename(file) !== "Animations.lua" && /\bAnim\.tween\s*\(/.test(l),
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
  "delete-protections-complete",
  "destructive-paths-reverify",
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

  // --- top-level local budget (see LOCAL_LIMIT) ---
  {
    let topLevelLocals = 0;
    for (const node of ast.body) {
      if (node.type === "LocalStatement") topLevelLocals += node.variables.length;
      else if (node.type === "FunctionDeclaration" && node.isLocal) topLevelLocals += 1;
    }
    if (topLevelLocals >= LOCAL_WARN_AT) {
      console.error(
        `LINT   ${rel}  [top-level-local-budget] ${topLevelLocals} top-level locals; Lua allows ` +
          `${LOCAL_LIMIT} per scope. Past that this file will not COMPILE, which means the addon ` +
          `silently does not load - and luaparse will not tell you. Group related values into one ` +
          `table, or move a section into its own file.`
      );
      lintFailures++;
    }
  }

  /*
   * --- delete-protections-complete ---------------------------------------------
   *
   * The README and the in-game tooltip both promise deletion never touches six
   * things. Deletion is the only irreversible thing this addon does, so that promise
   * is the most load-bearing sentence in the project - and it was verified by hand
   * once, which is a guarantee with a shelf life.
   *
   * Each promised category has a branch in IsProtectedFromDelete returning its own
   * reason string, and those strings are user-visible: the tooltip cleanup verdict
   * prints them verbatim as "Junk, but kept: <reason>". So checking the branches
   * exist is the same as checking the promise is kept.
   *
   * Deliberately checks for the REASON STRINGS rather than the logic, and that is now
   * half the job rather than all of it: `deletetest.js` executes this function and proves
   * each protection actually FIRES, one at a time. The split is worth keeping. This rule
   * catches a branch deleted or renamed, which is a promise broken in the docs and the
   * tooltip as much as in the code; that one catches a branch still present and no longer
   * working. Neither failure is visible to the other.
   */
  // Matched by full PATH, not basename: Valuate-PassLoot ships its own Valuate.lua,
  // and a basename check flagged it for not containing a function it has no business
  // having.
  if (path.resolve(file) === path.resolve(ADDON_ROOT, "Valuate.lua")) {
    const fn = src.match(/local function IsProtectedFromDelete[\s\S]*?\n end\n|local function IsProtectedFromDelete[\s\S]*?\nend\n/);
    if (!fn) {
      console.error(
        `LINT   ${rel}  [delete-protections-complete] IsProtectedFromDelete not found - the deletion safety promise cannot be verified`
      );
      lintFailures++;
    } else {
      const REQUIRED = [
        "quest item",
        "in an equipment set",
        "weapon-set member",
        "best-in-slot",
        "future upgrade",
        "an upgrade",
      ];
      for (const reason of REQUIRED) {
        if (!fn[0].includes(`return true, "${reason}`)) {
          console.error(
            `LINT   ${rel}  [delete-protections-complete] IsProtectedFromDelete no longer protects "${reason}", which the README and the in-game tooltip both promise it does. Deletion is irreversible - restore the branch, or change the promise.`
          );
          lintFailures++;
        }
      }
    }
  }

  /*
   * --- destructive-paths-reverify ----------------------------------------------
   *
   * The other half of the deletion safety promise: "both re-verify a slot still holds
   * the vetted item immediately before acting."
   *
   * Both paths queue candidates and act on them later - deletion in a loop, selling in
   * batches across several ticks. Bags shift in between: another addon moves something,
   * a stack merges, you drag an item while it is selling. Without the re-check, the
   * bag/slot pair is just coordinates, and coordinates point at whatever is there NOW.
   *
   * Deleting is irreversible, and UseContainerItem on the wrong item at a merchant can
   * USE it rather than sell it - so the failure is destroying something that was never
   * vetted.
   *
   * Requires, in each act path: the link re-read, a comparison against the stored
   * `c.link`, and the locked check - alongside the destructive call. The point is that
   * removing a guard while leaving the action cannot pass.
   */
  if (path.resolve(file) === path.resolve(ADDON_ROOT, "Valuate.lua")) {
    const PATHS = [
      { name: "Valuate:AutoDeleteJunk", start: /function Valuate:AutoDeleteJunk\b/, action: "DeleteCursorItem" },
      { name: "SellNextBatch", start: /local function SellNextBatch\b/, action: "UseContainerItem" },
    ];
    for (const p of PATHS) {
      const at = src.search(p.start);
      if (at < 0) {
        console.error(`LINT   ${rel}  [destructive-paths-reverify] ${p.name} not found - its safety guard cannot be verified`);
        lintFailures++;
        continue;
      }
      // To the next top-level `end` (these are both top-level functions).
      const rest = src.slice(at);
      const stop = rest.search(/\r?\nend\r?\n/);
      const body = stop < 0 ? rest : rest.slice(0, stop);

      /*
       * Strip comments before locating the call.
       *
       * Both functions MENTION their destructive call in a comment near the top, well
       * above the guards - so searching the raw text found the comment, took a window
       * before it that contained nothing, and reported all three guards missing on
       * perfectly good code. Caught by re-running the mutation test and noticing the
       * BASELINE had started failing, which is the only reason to always restore and
       * re-check rather than trusting the mutations alone.
       *
       * Blanked rather than deleted so every offset still lines up with the original.
       */
      const code = body.replace(/--[^\r\n]*/g, (m) => " ".repeat(m.length));

      const actionAt = code.indexOf(p.action + "(");
      if (actionAt < 0) continue; // action gone; nothing destructive left to guard

      /*
       * Look only at the window immediately BEFORE the destructive call, not the whole
       * function.
       *
       * The first version searched the entire body, and AutoDeleteJunk calls
       * GetContainerItemInfo in its SCAN loop as well - so deleting the act-time locked
       * check still passed, because the scan-time one was found instead. The rule looked
       * correct and was answering a weaker question, which is the exact failure it exists
       * to catch. Verified by removing that guard and watching the rule stay silent.
       */
      const guard = code.slice(Math.max(0, actionAt - 700), actionAt);

      const missing = [];
      if (!guard.includes("GetContainerItemLink")) missing.push("re-read the slot's link");
      if (!/[~=]=\s*c\.link|c\.link\s*[~=]=/.test(guard)) missing.push("compare it against the vetted c.link");
      if (!/GetContainerItemInfo/.test(guard)) missing.push("check the slot is not locked");

      for (const m of missing) {
        console.error(
          `LINT   ${rel}  [destructive-paths-reverify] ${p.name} calls ${p.action} but does not ${m}. Bags shift between vetting and acting - without this it destroys whatever is in the slot now.`
        );
        lintFailures++;
      }
    }
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
