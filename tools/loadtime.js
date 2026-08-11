#!/usr/bin/env node
/*
 * @gate Nothing risky runs at file scope, where a failure has no way out
 *
 * Written the same day a file-scope call broke the addon in the client.
 *
 * v0.74.0a built font objects at file scope in ui/Shared.lua. The client refused the font,
 * the guard meant to catch that could not fire, and the first SetText threw while the window
 * was being constructed - so the UI would not open at all, and relogging did not help because
 * the same code ran again on every login. Nothing headless caught it: the mock answers
 * SetFont happily, so 25 gate checks passed against a fiction.
 *
 * File-scope code is uniquely unforgiving:
 *   - it runs on EVERY login, before any of the addon's own error handling exists
 *   - there is no way for the user to avoid it - no setting, no command, no /reload
 *   - a mock cannot tell you whether THIS client has the function you are calling
 *
 * Everything else in this addon runs inside a function, called after load, where a failure is
 * one broken feature rather than a dead addon. So the rule is narrow and strict: at file
 * scope, call only what every 3.3.5 client is guaranteed to have.
 *
 * Uses the AST rather than line matching, and deliberately does NOT descend into function
 * bodies - those run later, and a call inside one is not a load-time call.
 *
 * Usage:  node tools/loadtime.js
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

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");

/*
 * Callable at file scope. Short on purpose: each entry is a promise that the function exists
 * on every client this addon runs on, and that a failure inside it is not silent.
 *
 * CreateFrame and IsAddOnLoaded have been in the API since 1.x. Lua's own library is fine -
 * it does not depend on the client at all.
 */
const ALLOWED = new Set([
  "CreateFrame",
  "IsAddOnLoaded",
  "GetAddOnMetadata",
  // The addon's own table. Valuate.lua is first in the .toc, so by the time any ui/ file is
  // evaluated it exists; a missing Valuate would be a .toc bug that tocsync.js already catches.
  "Valuate",
  // Lua standard library, present regardless of client.
  "type", "tostring", "tonumber", "pairs", "ipairs", "select", "unpack", "next",
  "setmetatable", "getmetatable", "rawget", "rawset", "assert", "error", "pcall",
  "table", "string", "math", "bit", "print", "format", "strsplit", "strjoin", "wipe",
  "tinsert", "tremove", "tContains", "max", "min", "abs", "floor", "ceil",
]);

const FILES = fs
  .readdirSync(path.join(ADDON_ROOT, "ui"))
  .filter((f) => f.endsWith(".lua"))
  .map((f) => path.join("ui", f))
  .concat(["ValuateUI.lua", "MinimapButton.lua", "StatDefinitions.lua", "ImportExport.lua", "Valuate.lua"]);

const findings = [];
let scanned = 0;
let callsChecked = 0;

for (const rel of FILES) {
  const full = path.join(ADDON_ROOT, rel);
  if (!fs.existsSync(full)) continue;
  scanned++;

  let ast;
  try {
    ast = luaparse.parse(fs.readFileSync(full, "utf8"), { luaVersion: "5.1", locations: true });
  } catch (e) {
    console.error(`ERROR  ${rel} does not parse: ${e.message}`);
    process.exit(2);
  }

  /*
   * Names declared as locals anywhere in the file.
   *
   * A call on a local is not the risk this gate is about. `animDriver:SetScript(...)` at file
   * scope is calling a method on a frame that CreateFrame just returned - it exists because
   * the line above made it. What can fail on an unknown client is a call through a GLOBAL that
   * may not be there at all, which is exactly what the font bug was.
   *
   * Collected from the whole file rather than by scope, so a local in some function shadowing
   * a global name silences that name here too. That errs toward silence, which is the right
   * direction for a gate whose false positives would otherwise be constant - and the class it
   * targets (an unknown global, called at load) is untouched by the imprecision.
   */
  const locals = new Set();
  (function collectLocals(node) {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) {
      for (const child of node) collectLocals(child);
      return;
    }
    if (node.type === "LocalStatement" && Array.isArray(node.variables)) {
      for (const v of node.variables) if (v.name) locals.add(v.name);
    }
    if (node.type === "FunctionDeclaration" && node.isLocal && node.identifier &&
        node.identifier.name) {
      locals.add(node.identifier.name);
    }
    for (const key of Object.keys(node)) {
      if (key === "loc" || key === "range") continue;
      collectLocals(node[key]);
    }
  })(ast.body);

  // Walks a node WITHOUT entering function bodies. A call inside a function runs later, when
  // the addon is alive and a failure is recoverable; only what executes during the file's own
  // evaluation counts here.
  function walk(node) {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) {
      for (const child of node) walk(child);
      return;
    }
    if (node.type === "FunctionDeclaration") return;

    if (node.type === "CallExpression" || node.type === "StringCallExpression" ||
        node.type === "TableCallExpression") {
      callsChecked++;
      const callee = node.base;
      let name = null;
      if (callee && callee.type === "Identifier") {
        name = callee.name;
      } else if (callee && callee.type === "MemberExpression" && callee.base) {
        // C_Appearance.GetItemAppearanceID(...) and the like: judge on the ROOT table, since
        // that is what may not exist on a given client.
        let root = callee.base;
        while (root && root.type === "MemberExpression") root = root.base;
        if (root && root.type === "Identifier") name = root.name;
      }
      if (name && !ALLOWED.has(name) && !locals.has(name)) {
        findings.push({
          file: rel,
          line: node.loc ? node.loc.start.line : 0,
          name,
        });
      }
    }

    for (const key of Object.keys(node)) {
      if (key === "loc" || key === "range") continue;
      walk(node[key]);
    }
  }

  walk(ast.body);
}

if (scanned < 10) {
  console.error(
    `ERROR  only scanned ${scanned} file(s) - the file list is wrong, so this gate would pass ` +
      "by looking at nothing"
  );
  process.exit(2);
}

if (findings.length) {
  console.error("Calls that run at FILE SCOPE, where a failure stops the addon loading:");
  for (const f of findings) {
    console.error(`  ${f.file}:${f.line}  ${f.name}(...)`);
  }
  console.error(
    "\nThis code runs on every login, before any error handling exists, and the user cannot\n" +
      "avoid it - there is no setting or command to switch it off, and relogging just runs it\n" +
      "again. A headless mock cannot tell you whether THIS client has the function.\n\n" +
      "Move it inside a function that runs after load, so a failure costs one feature instead\n" +
      "of the whole addon. If it genuinely must run at load AND is guaranteed on every 3.3.5\n" +
      "client, add it to ALLOWED with that reasoning."
  );
  process.exit(1);
}

console.log(
  `OK  ${scanned} file(s): every one of the ${callsChecked} file-scope call(s) is an API ` +
    `guaranteed on this client.`
);
