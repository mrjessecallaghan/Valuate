#!/usr/bin/env node
/*
 * @gate The gates themselves are not silently broken
 *
 * Eighty-three gates guard twenty Lua files. Nothing guarded the eighty JavaScript files
 * doing the guarding, and a gate that is quietly wrong is worse than no gate: it reports OK,
 * and the thing it named goes unwatched while everybody believes it is watched.
 *
 * Three ways that has actually happened here.
 *
 * 1. A STRIPPED BACKSLASH.
 *
 *    This shell removes backslashes from heredocs and from `node -e` strings. It has done so
 *    perhaps nine times in this project, and every other time it produced a syntax error that
 *    stopped the work immediately. Once it did not: in mutations.js the pattern meant to pull
 *    a version out of the .toc lost both of its escapes, becoming a pattern that matches the
 *    LETTER d rather than a digit - so it matched no version string that has ever existed.
 *
 *    That would have been fine if it threw. It did not: the result fed an `||` fallback, so
 *    every run quietly substituted a hardcoded version, which is the exact thing the function
 *    was written to stop doing. Its own comment recorded that the literal had already drifted
 *    into uselessness twice. It had come back, invisibly, and no gate could see it because no
 *    gate reads JavaScript.
 *
 *    Only the high-confidence shape is flagged: a bare class letter with a quantifier, inside
 *    something that is unambiguously a regex literal rather than a division. A checker that
 *    guesses at the rest would cry wolf on arithmetic, and a gate people learn to ignore
 *    protects nothing at all.
 *
 * 2. A GATE THAT IS NEVER RUN.
 *
 *    gates.js discovers by finding an "@gate" line in the first 2000 bytes. A gate whose
 *    header comment grows past that window, or whose marker gets reworded, is dropped from
 *    the run silently - it does not error, it does not appear, and the total ticks down by
 *    one where nobody is counting. So every file here must be a discovered gate or named
 *    below as infrastructure. There is no third category.
 *
 * 3. A MUTATION POINTED AT A GATE THAT DOES NOT EXIST.
 *
 *    mutate.js already catches this through its baseline pass, which is the right place for
 *    it. Checked here too because it costs one statSync and gives the mistake a sentence that
 *    says what is wrong, instead of an ENOENT surfacing as "this gate fails on clean source".
 *
 * Usage:  node tools/toolsource.js
 */
"use strict";

const fs = require("fs");
const path = require("path");

const TOOLS_DIR = __dirname;

/* Not gates, and correctly so: shared machinery and the runners themselves.
 *
 * Spelled out rather than pattern-matched. A new file that is neither a gate nor on this list
 * is the case worth catching, and any rule loose enough to excuse it in advance would excuse
 * a broken gate header too. */
const INFRASTRUCTURE = new Set([
  "backup.js", // writes the bundles; nothing to assert
  "gates.js", // the runner
  "luaharness.js", // the mocked WoW API every gate loads
  "mutate.js", // the mutation runner
  "mutations.js", // the mutation table
]);

const problems = [];
let scanned = 0;
let regexesRead = 0;

/* ---- 1. stripped backslashes ------------------------------------------------------------ */

/* Characters that can legally sit in front of a regex literal. Anything else - an identifier
 * character, a closing bracket, a dot - means the slash is division, and every false positive
 * this gate could produce comes from confusing the two. `)` is deliberately treated as
 * division: `if (x) /re/.test(y)` is legal and essentially never written, while `(a + b) / c`
 * is on several lines of this very directory. */
function isRegexPosition(src, slashAt) {
  let i = slashAt - 1;
  while (i >= 0 && /\s/.test(src[i])) i--;
  if (i < 0) return true;
  return !/[A-Za-z0-9_$)\].]/.test(src[i]);
}

/* The shapes a stripped backslash leaves behind. A quantifier is required on every one: a
 * bare `d` or `w` inside a character class is a perfectly ordinary literal letter, and it is
 * the quantified form that has no innocent reading. */
const STRIPPED = [
  { re: /\([dswDSW]\+\)/, why: "a capture group of a bare class letter" },
  { re: /\([dswDSW]\*\)/, why: "a capture group of a bare class letter" },
  { re: /\^[dswDSW]\+/, why: "an anchored bare class letter" },
  { re: /[dswDSW]\+\$/, why: "a bare class letter at the end" },
];

function scanForStrippedEscapes(name, src) {
  const lines = src.split(String.fromCharCode(10));
  lines.forEach((line, idx) => {
    const trimmed = line.trim();
    // Comments carry examples of the very mistake being looked for, including in this file.
    if (trimmed.startsWith("//") || trimmed.startsWith("*") || trimmed.startsWith("/*")) return;

    for (let i = 0; i < line.length; i++) {
      const ch = line[i];

      // Strings are skipped whole, and this is not a nicety. A gate that prints a pattern in
      // its own error message, or a mutation carrying one as replacement text, is QUOTING a
      // pattern rather than using one - and the files most likely to hold such a quote are the
      // ones discussing this exact bug, so reading inside strings would make this gate fire
      // first and loudest on its own documentation. It did, on the first run.
      if (ch === '"' || ch === "'" || ch === "`") {
        for (i++; i < line.length; i++) {
          if (line[i] === "\\") {
            i++;
            continue;
          }
          if (line[i] === ch) break;
        }
        continue;
      }

      if (ch !== "/") continue;
      if (line[i + 1] === "/" || line[i + 1] === "*") break; // trailing comment
      if (!isRegexPosition(line, i)) continue;

      // Walk to the closing slash, honouring escapes and character classes.
      let j = i + 1;
      let inClass = false;
      let closed = false;
      for (; j < line.length; j++) {
        const c = line[j];
        if (c === "\\") {
          j++;
          continue;
        }
        if (c === "[") inClass = true;
        else if (c === "]") inClass = false;
        else if (c === "/" && !inClass) {
          closed = true;
          break;
        }
      }
      if (!closed) continue;

      const body = line.slice(i + 1, j);
      if (!body) continue;
      regexesRead++;

      // Remove every VALID escape first, so a correct \d+ cannot be mistaken for a bare one.
      const bare = body.replace(/\\[\s\S]/g, "");
      for (const s of STRIPPED) {
        if (s.re.test(bare)) {
          problems.push(
            `tools/${name}:${idx + 1} has ${s.why} in /${body}/ - a backslash was eaten, ` +
              `and the pattern now matches a literal letter instead of a character class`
          );
          break;
        }
      }
      i = j;
    }
  });
}

/* ---- 1b. an assertion whose arguments are the wrong way round --------------------------- */

/* Every gate here writes `ok(condition, "what it means")`. The sibling suites write the
 * opposite - `Check("what it means", condition)` - and moving a block from one to the other by
 * renaming the call is how you get `ok("what it means", condition)`.
 *
 * That form CANNOT FAIL. A non-empty string is truthy in Lua, so the assertion passes whatever
 * the condition says, and a whole block of them reads exactly like coverage while testing
 * nothing at all. It happened in v0.219.0a: fifteen assertions about what the wizard claims it
 * did, every one of them decorative, caught only because two mutations survived.
 *
 * A string LITERAL as the first argument is the signal. A variable there is an ordinary
 * assertion that something is non-nil and is left alone. */
function scanForSwappedAssertions(name, src) {
  src.split(String.fromCharCode(10)).forEach((line, idx) => {
    if (!/^\s*ok\(\s*"/.test(line)) return;
    problems.push(
      `tools/${name}:${idx + 1} calls ok() with a string first - the arguments are reversed. ` +
        `A non-empty string is truthy, so this assertion passes no matter what the condition ` +
        `says. Write ok(condition, "message")`
    );
  });
}

/* ---- 2. every file is a gate or infrastructure ------------------------------------------ */

/* The same rule gates.js applies, spelled the same way. If discovery changes, this has to
 * change with it - and a gate that disagrees with the runner about what a gate IS would be
 * its own kind of quiet wrong. */
function isDiscoverable(src) {
  return /^\s*\*\s*@gate\s+(.+)$/m.test(src.slice(0, 2000));
}

/* ---- run --------------------------------------------------------------------------------- */

const names = fs
  .readdirSync(TOOLS_DIR)
  .filter((n) => n.endsWith(".js"))
  .filter((n) => fs.statSync(path.join(TOOLS_DIR, n)).isFile())
  .sort();

if (names.length < 20) {
  console.error(
    `  SCAN  only ${names.length} tool(s) found in ${TOOLS_DIR} - this gate is looking in the ` +
      `wrong place and proving nothing`
  );
  process.exit(1);
}

let gateCount = 0;
for (const name of names) {
  const src = fs.readFileSync(path.join(TOOLS_DIR, name), "utf8");
  scanned++;
  scanForStrippedEscapes(name, src);
  scanForSwappedAssertions(name, src);

  const discoverable = isDiscoverable(src);
  if (discoverable) gateCount++;
  if (!discoverable && !INFRASTRUCTURE.has(name)) {
    problems.push(
      `tools/${name} is neither a discovered gate nor listed as infrastructure - gates.js ` +
        `will not run it, so whatever it checks is unwatched. Add an "@gate" line to its ` +
        `header comment within the first 2000 bytes, or add it to INFRASTRUCTURE here`
    );
  }
  if (discoverable && INFRASTRUCTURE.has(name)) {
    problems.push(
      `tools/${name} is listed as infrastructure but declares "@gate", so it runs as one - ` +
        `the two lists disagree about what it is`
    );
  }
}

const MUTATIONS = require("./mutations.js");

/* ---- 3. mutations name gates that exist -------------------------------------------------- */

let mutationsChecked = 0;
const seenGates = new Set();
for (const m of MUTATIONS) {
  if (!m || !m.gate || seenGates.has(m.gate)) continue;
  seenGates.add(m.gate);
  mutationsChecked++;
  if (!fs.existsSync(path.join(TOOLS_DIR, `${m.gate}.js`))) {
    problems.push(
      `a mutation names gate "${m.gate}", but tools/${m.gate}.js does not exist - every ` +
        `mutation pointed at it can only ever report "caught"`
    );
  }
}

/* ---- 3b. a multi-line anchor pointed at a CRLF file --------------------------------------- */

/* A mutation whose `from` spans lines cannot match a file with Windows line endings: the anchor
 * carries "\n" and the file has "\r\n". It does not fail loudly - mutate.js reports UNAPPLIED,
 * which is easy to read as "that one is stale" rather than "this file is different from its
 * neighbours".
 *
 * It has cost two sessions now. Once when a git checkout rewrote a source file as CRLF and
 * silently broke three anchors at once, and again on ui/UpgradeArrows.lua, which is CRLF while
 * every file beside it is LF.
 *
 * The fix at the call site is always the same and always available: anchor on ONE line, and use
 * `scope` if that line is not unique. So this does not ask anyone to normalise line endings - it
 * points at the anchor that is about to stop working. */
{
  const crlf = new Map();
  for (const m of MUTATIONS) {
    if (!m || typeof m.from !== "string" || !m.from.includes("\n")) continue;
    const target = path.join(TOOLS_DIR, "..", m.file || "");
    if (!fs.existsSync(target)) continue;
    if (!crlf.has(target)) {
      crlf.set(target, fs.readFileSync(target, "utf8").includes("\r\n"));
    }
    if (!crlf.get(target)) continue;
    problems.push(
      `a mutation for gate "${m.gate}" anchors across lines in ${m.file}, which has CRLF line ` +
        `endings - the anchor carries a bare newline and cannot match. It will report ` +
        `UNAPPLIED rather than fail. Anchor on a single line, with a scope if that line is not ` +
        `unique: "${String(m.label || "").slice(0, 60)}"`
    );
  }
}

/* ---- 4. a gate nothing has ever tried to break ------------------------------------------ */

/* A gate proves the code does something. A MUTATION proves the gate would notice if it
 * stopped. Without one, a gate is a claim about itself.
 *
 * That is not theoretical here. In v0.219.0a fifteen assertions in a passing gate had their
 * arguments reversed and could not fail; two surviving mutations were the only reason anyone
 * looked. The gate reported OK the whole time.
 *
 * The nineteen below had no mutation when this rule was written, and are recorded as the
 * state of the world rather than as approved. They are not equally urgent - most guard
 * appearance or data-file agreement rather than an action - which is why this is a baseline
 * and not a failure: nineteen red lines on every run would be ignored inside a week.
 *
 * What it stops is the list GROWING. A gate written from today has to come with something
 * that breaks it, which is the moment its author finds out whether the assertions bite.
 *
 * The list only shrinks. Removing a name means writing a mutation for it. */
const UNPROVEN_AT_BASELINE = new Set([
  "animtest",
  "arrowtest",
  "automatch",
  "autoname",
  "charwindowtest",
  "datatest",
  "futurelinetest",
  "genloot",
  "iconpickertest",
  "loadtime",
  "pickercoa",
  "pickertest",
  "sharetest",
  "statsearchtest",
  "tooltiptest",
  "tsmratiotest",
  "typescale",
  "wizardroles",
]);

{
  const mutatedGates = new Set(MUTATIONS.map((m) => m && m.gate).filter(Boolean));
  const discovered = names.filter((n) => {
    const src = fs.readFileSync(path.join(TOOLS_DIR, n), "utf8");
    return isDiscoverable(src);
  });
  for (const file of discovered) {
    const gate = file.replace(/\.js$/, "");
    if (mutatedGates.has(gate)) continue;
    if (UNPROVEN_AT_BASELINE.has(gate)) continue;
    problems.push(
      `tools/${file} is a gate that no mutation has ever tried to break. A passing gate ` +
        `proves the code does something; only a mutation proves the gate would NOTICE if it ` +
        `stopped. Add an entry to tools/mutations.js with gate: "${gate}", or add it to ` +
        `UNPROVEN_AT_BASELINE here and say why it can wait.`
    );
  }
  /* An entry that has since gained a mutation is a note about work already done. Left in, the
   * list reads as more debt than exists - and a list nobody prunes is a list nobody trusts. */
  for (const gate of UNPROVEN_AT_BASELINE) {
    if (mutatedGates.has(gate)) {
      problems.push(
        `UNPROVEN_AT_BASELINE lists "${gate}", but it has a mutation now. Delete the entry ` +
          `so the list keeps meaning what it says.`
      );
    }
  }
}
if (problems.length) {
  console.error(`The tooling has ${problems.length} problem(s):`);
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}

console.log(
  `OK  ${scanned} tool(s) checked (${gateCount} gates, ${INFRASTRUCTURE.size} infrastructure); ` +
    `${regexesRead} regex literal(s) carry their backslashes; ` +
    `${mutationsChecked} named gate(s) all exist.`
);
