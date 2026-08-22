#!/usr/bin/env node
/*
 * @gate The to-do list does not vouch for what it never read
 *
 * Runs the real ns.TodoEmptyText and ns.TodoCoverageLine from ui/TodoPanel.lua.
 *
 * An empty to-do list is the most consequential thing this addon says. Nobody reads it as "no
 * rows"; they read it as "you are done", and they act on it by not acting. The sentence under
 * it used to be fixed text:
 *
 *     "Nothing outstanding. Your gear, gems and enchants are all up to date for the scale
 *      you are using."
 *
 * Three specific claims, printed whether or not any of the three had been looked at. Mid
 * equipment swap the sockets are not read at all, and the panel vouched for your gems anyway.
 *
 * Two ways of arriving at empty already turn into to-do items - no scale, and never scanned -
 * because a list built on nothing must not look like a list with nothing on it. This is the
 * third way, and the one that comes and goes: a source that failed on THIS refresh.
 *
 * Three things have to hold at once, and each is easy to get right at the cost of another:
 *
 *   1. with nothing unread, the confident sentence is unchanged. A panel that hedges on every
 *      refresh has just moved the lie to the other side.
 *   2. with something unread, the specific claims are gone. Not softened - gone. "Your gems
 *      are up to date, probably" is the same claim.
 *   3. it never reads as a fault. Nothing is broken, a swap finishes on its own, and dressing
 *      a transient gap as an error sends people hunting for one.
 *
 * Usage:  node tools/todounread.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const NL = String.fromCharCode(10);
const src = fs.readFileSync(path.join(ADDON_ROOT, "ui", "TodoPanel.lua"), "utf8");

function slice(name) {
  const start = src.indexOf("function ns." + name + "(");
  if (start < 0) {
    console.error(
      "  SLICE  could not find function ns." + name + " in ui/TodoPanel.lua - it was renamed " +
        "or inlined back into the panel, so this gate is testing nothing"
    );
    process.exit(1);
  }
  const end = src.indexOf(NL + "end" + NL, start);
  if (end < 0) {
    console.error("  SLICE  ns." + name + " has no closing end - this gate is testing nothing");
    process.exit(1);
  }
  return src.slice(start, end + 5);
}

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function eq(got, want, what)
    checks = checks + 1
    if got ~= want then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end
local function has(text, needle, what)
    ok(type(text) == "string" and text:lower():find(needle:lower(), 1, true) ~= nil, what)
end
local function lacks(text, needle, what)
    ok(type(text) == "string" and text:lower():find(needle:lower(), 1, true) == nil, what)
end

local ns = {}
` + slice("TodoEmptyText") + `
` + slice("TodoCoverageLine") + `

-- ---- nothing unread: the confident sentence is UNCHANGED ------------------------------------
-- The failure mode on this side is a panel that hedges every time, which has not fixed the
-- lie so much as moved it. A character who really is done should be told so plainly.
local clean = ns.TodoEmptyText(nil)
has(clean, "all up to date", "with nothing unread it still says your gear is up to date")
lacks(clean, "could check", "and does not hedge about coverage it did not lose")
eq(ns.TodoEmptyText({}), clean, "an empty unread list behaves exactly like no list at all")

-- ---- THE ONE THAT MATTERS: something went unread ---------------------------------------------
local partial = ns.TodoEmptyText({ "empty sockets (an item is still being swapped)" })
lacks(partial, "all up to date",
      "when a source went unread, the blanket claim is GONE - not softened, gone")
has(partial, "sockets", "and what was missed is named, so it can be judged")
has(partial, "swapped", "including why, in the words the source itself gave")
ok(partial ~= clean, "the two states do not produce the same sentence")

-- "Your gems are up to date, probably" is the same claim wearing a hat. The specific nouns
-- from the confident sentence must not survive into the partial one.
lacks(partial, "gems are all up to date", "no half-claim about gems survives")

-- ---- it is never worded as a fault -----------------------------------------------------------
-- Nothing is broken. A swap finishes on its own, and an item finishes loading. Telling someone
-- to fix a thing that is not wrong is how a panel stops being read.
for _, word in ipairs({ "error", "failed", "failure", "broken", "problem" }) do
    lacks(partial, word, "a transient gap is not reported as a " .. word)
end

-- ---- more than one source ---------------------------------------------------------------------
local two = ns.TodoEmptyText({ "empty sockets (swapping)", "2 worn slots still loading" })
has(two, "sockets", "both sources are named -- the first")
has(two, "still loading", "-- and the second")

-- ---- the line shown beside a NON-empty list ---------------------------------------------------
-- Said on a failing refresh too. A list of three jobs is just as much a statement about partial
-- coverage as a clean bill is, and it is the more dangerous of the two to over-read: you do the
-- three things, come back, see nothing, and take that as the window being finished with you.
eq(ns.TodoCoverageLine(nil), nil, "with nothing unread there is no extra furniture")
eq(ns.TodoCoverageLine({}), nil, "and an empty list is the same as none")
local line = ns.TodoCoverageLine({ "empty sockets (swapping)" })
ok(line ~= nil, "with something unread there IS a line")
has(line, "sockets", "naming it")
for _, word in ipairs({ "error", "failed", "broken" }) do
    lacks(line, word, "and not as a " .. word)
end

-- ---- bad input does not take the panel down ---------------------------------------------------
-- Both of these run while the window is drawing. Erroring here loses the tab.
ok(pcall(ns.TodoEmptyText), "TodoEmptyText survives being called with nothing")
ok(pcall(ns.TodoEmptyText, "not a table"), "and with the wrong type")
ok(pcall(ns.TodoCoverageLine, 7), "TodoCoverageLine survives the wrong type too")
has(ns.TodoEmptyText("not a table"), "all up to date",
    "an unusable unread value is treated as nothing unread, not as everything unread")

return failures, checks
`,
  "todounread",
  "the to-do list's coverage sentences"
);
