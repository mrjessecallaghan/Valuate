#!/usr/bin/env node
/*
 * @gate Every help group is reachable, and bare help stays short
 *
 * Runs the real help branch out of Valuate.lua.
 *
 * 74 commands printed as one flat list is seven screens of chat scrollback - the same as
 * having no help at all, because the top has gone by the time the bottom arrives. Grouping
 * them fixes that and introduces a new way to fail: a group that is listed but cannot be
 * SELECTED. Every command still appears in the source, so commands.js - which reads the text -
 * would go on passing while the commands themselves had become unreachable.
 *
 * That is exactly what happened when this was written: a mutation disabling topic selection
 * survived, because nothing anywhere ran the branch.
 *
 * Usage:  node tools/helptest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

// The branch, from its `if` to the `elseif` that ends it. Sliced rather than copied: a copy
// would keep passing after the real help changed underneath it.
const m = lua.match(
  /\n(\s*)if strsub\(command, 1, 4\) == "help" then\r?\n([\s\S]*?)\r?\n\s*elseif command == "version" then/
);
if (!m) {
  console.error("  SLICE  could not find the help branch in Valuate.lua - this gate tests nothing");
  process.exit(1);
}
const body = m[2];

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

function strtrim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end

local out = {}
local realPrint = print
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    out[#out + 1] = table.concat(parts, " ")
end

local function help(topic)
    out = {}
    local command = topic and ("help " .. topic) or "help"
` + body + `
    return out
end

local bare = help(nil)
print = realPrint

-- ---- bare help is an overview, not a wall ----------------------------------------
-- The whole reason for grouping. A user typing /valuate help should be able to read what
-- came back without scrolling.
ok(#bare <= 12, "bare help is short enough to read at once - got " .. #bare .. " lines")
local bareText = table.concat(bare, "\\n")
eq(bareText:find("/valuate scan", 1, true), nil,
   "and does not dump individual commands - that is what the topics are for")

-- ---- every group named in the overview can be SELECTED ---------------------------
-- The failure this gate exists for. A group listed but unreachable leaves its commands
-- invisible, while commands.js - which reads the source text - goes on passing.
local topics = {}
for line in bareText:gmatch("[^\\n]+") do
    local key = line:match("/valuate help (%a+)")
    if key then topics[#topics + 1] = key end
end
ok(#topics >= 5, "the overview lists its topics - found " .. #topics)

print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    out[#out + 1] = table.concat(parts, " ")
end
for _, key in ipairs(topics) do
    local lines = help(key)
    local text = table.concat(lines, "\\n")
    ok(text:find("/valuate ", 1, true) ~= nil,
       "topic '" .. key .. "' lists actual commands rather than bouncing to the overview")
    eq(text:find("No help topic", 1, true), nil, "topic '" .. key .. "' is recognised")
end

-- ---- all, and a topic that does not exist ---------------------------------------
local allText = table.concat(help("all"), "\\n")
ok(allText:find("/valuate scan", 1, true) ~= nil, "help all lists everything")
ok(#help("all") > #bare, "and is longer than the overview, which is the point of the split")

local bogus = table.concat(help("nosuchtopic"), "\\n")
ok(bogus:find("No help topic", 1, true) ~= nil,
   "an unknown topic says so rather than silently showing the overview")
ok(bogus:find("/valuate help ", 1, true) ~= nil, "and still offers the real ones")
print = realPrint

return failures, checks
`,
  "helptest",
  "the grouped help"
);
