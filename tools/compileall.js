#!/usr/bin/env node
/*
 * @gate Every Lua file COMPILES under a real Lua 5.1, not just a permissive parser
 *
 * Compiles - does not run - every .lua file in the addon and its companions through fengari.
 *
 * WHY THIS IS NOT check.js
 * ------------------------
 * check.js parses with luaparse, and luaparse is more permissive than the game. That is not a
 * theoretical difference. In v0.138.0a the in-game changelog list reached exactly 200 chained
 * `..` operators, which is Lua 5.1's hard ceiling on expression nesting. luaparse accepted the
 * file. The client would not have loaded it, and an addon that fails to compile does not
 * report an error - it is simply absent.
 *
 * check.js printed "31 Lua files parsed cleanly" that day. It was caught only because two
 * unrelated gates happened to load that particular module under fengari for their own reasons.
 *
 * WHAT THAT LEFT UNCOVERED
 * ------------------------
 * loadtime.js loads ui/*.lua, so those were safe by accident. Nothing compiled the rest:
 * Valuate.lua - eight thousand lines, the largest file here - is only ever SLICED, so gates
 * compile fragments of it and never the whole. ValuateUI.lua, MinimapButton.lua,
 * StatDefinitions.lua, ImportExport.lua and all three companion addons had nothing at all.
 *
 * Any of them could have crossed a compile-time limit and shipped silent.
 *
 * COMPILE, NOT EXECUTE
 * --------------------
 * Running Valuate.lua would need the whole client mocked, and that is what the other gates are
 * for. Compiling is enough: every limit this exists to catch - expression nesting, locals per
 * scope, upvalues, constants - is enforced when the chunk is compiled, before a line of it
 * runs. It is also fast, which is why it can afford to cover everything.
 *
 * Usage:  node tools/compileall.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { lua, lauxlib, to_luastring, to_jsstring } = require("fengari");

const TOOLS_DIR = __dirname;
const ADDON_ROOT = path.resolve(TOOLS_DIR, "..");
const ADDONS_DIR = path.resolve(ADDON_ROOT, "..");

// The same roots check.js scans, so the two cannot disagree about what "every file" means.
const SCAN_ROOTS = [
  ADDON_ROOT,
  path.join(ADDONS_DIR, "Valuate-AdiBags"),
  path.join(ADDONS_DIR, "Valuate-PassLoot"),
  path.join(ADDONS_DIR, "Valuate-TSM"),
  path.join(ADDONS_DIR, "Valuate-LootCollector"),
];
const SKIP_DIR = /(^|[\\/])(libs|node_modules|\.git|_Valuate_Original_Archive.*|_Valuate_Handoff)([\\/]|$)/i;

function collect(dir, out) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (e) {
    return out;
  }
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (!SKIP_DIR.test(full)) collect(full, out);
    } else if (entry.name.endsWith(".lua")) {
      out.push(full);
    }
  }
  return out;
}

const files = [];
for (const root of SCAN_ROOTS) collect(root, files);

if (files.length === 0) {
  console.error("  SCAN  found no Lua files at all - this gate would pass by testing nothing");
  process.exit(1);
}

const L = lauxlib.luaL_newstate();

/*
 * The gate checks itself before it checks anything else.
 *
 * Everything below rests on luaL_loadbuffer returning non-OK for a chunk the client would
 * refuse. If that ever stopped being true - a fengari change, a wrong status constant, a
 * compile that quietly succeeds - this file would report every source clean forever, and the
 * failure would be indistinguishable from the good news it is meant to deliver.
 *
 * check.js makes the same argument about its regex rules: a rule that matches nothing passes
 * every file, silently. The two samples are the two things this gate claims to do - reject
 * what the client rejects, and accept what it accepts - because a self-check that only proves
 * the first would be satisfied by a function that rejects everything.
 */
const SELF_SAMPLES = [
  // A Lua 5.1 compile LIMIT, not a syntax error. This is the exact shape that shipped: 210
  // chained concatenations, which luaparse accepts and the client does not.
  ['local x = ""' + ' .. "x"'.repeat(210), false, "a 210-deep concat chain"],
  // An ordinary syntax error, to prove the check is not keyed to that one message.
  ["local = = 3", false, "a plain syntax error"],
  // And valid code must still compile, or a gate that rejects everything would pass this.
  ["local x = 1 + 1 return x", true, "ordinary valid Lua"],
];
for (const [src, shouldCompile, what] of SELF_SAMPLES) {
  const st = lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@selfcheck"));
  const compiled = st === lua.LUA_OK;
  lua.lua_settop(L, 0);
  if (compiled !== shouldCompile) {
    console.error(
      "ERROR  compileall self-check failed: " + what + " should " +
        (shouldCompile ? "" : "NOT ") + "compile. The gate is broken, so its silence means nothing."
    );
    process.exit(2);
  }
}

let failures = 0;

for (const file of files) {
  const rel = path.relative(ADDONS_DIR, file);
  const source = fs.readFileSync(file, "utf8");

  // luaL_loadbuffer compiles and pushes the chunk. It does NOT call it, which is the whole
  // point: the limits worth catching are enforced here, and running would need a client.
  const status = lauxlib.luaL_loadbuffer(
    L,
    to_luastring(source),
    null,
    to_luastring("@" + rel)
  );

  if (status !== lua.LUA_OK) {
    const message = to_jsstring(lua.lua_tostring(L, -1));
    console.error("COMPILE  " + rel);
    console.error("         " + message);
    // The two that luaparse cannot see, named where someone hitting them will read it.
    if (/too many/i.test(message)) {
      console.error(
        "         This is a Lua 5.1 compile limit, not a syntax error. luaparse accepts it " +
          "and the client does not, so check.js will stay green while the addon fails to load."
      );
    }
    failures++;
  }
  lua.lua_settop(L, 0);
}

if (failures > 0) {
  console.error(
    "\n" + failures + " file(s) will not compile in the client. An addon that fails to " +
      "compile does not report an error - it is simply absent."
  );
  process.exit(1);
}

console.log(
  "OK  all " + files.length + " Lua file(s) compile under Lua 5.1 - including the ones no " +
    "other gate loads."
);
