#!/usr/bin/env node
/*
 * @gate The type scale has real, distinct, descending sizes
 *
 * There were six font tokens and three fonts. FONT_H1 and FONT_BODY were the same object,
 * and FONT_H2, FONT_H3 and FONT_SMALL were all a second one - so a section heading was
 * exactly the size of the paragraph beneath it, and a sub-heading was the size of small
 * print. Together with a heading colour that measured dimmer than body text (see
 * tools/contrast.js), that is the entire reason these panels read as flat.
 *
 * This runs ui/Shared.lua for real and checks what the tokens actually resolved to, which
 * matters more than it sounds: DefineFont falls back to the stock template if the client
 * refuses the font, and a silent fallback would restore the old flat scale while every
 * other gate still passed. The check that the tokens are NOT the stock names is the one
 * doing the work here.
 *
 * Usage:  node tools/typescale.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

/*
 * The fallback is what stands between a font this client dislikes and every panel rendering
 * nothing at all, so it must stay reachable rather than being tidied away once the scale
 * works on one machine.
 */
// Targets the SPECIFIC guard, not just any "return fallbackTemplate". There are three
// fallback branches; matching loosely meant deleting the one that matters still passed.
const shared = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Shared.lua"), "utf8");
if (!/if not applied or \(font\.GetFont and not font:GetFont\(\)\) then[\s\S]{0,80}return fallbackTemplate/.test(shared)) {
  console.error(
    "DefineFont no longer falls back to a stock template. A font path this client refuses " +
      "would then leave every panel drawing invisible text - worse than the flat scale this " +
      "replaced."
  );
  process.exit(1);
}

const run = load(["ui/Shared.lua"]);

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

local ns = __ns

-- ---- the tokens resolved to OUR fonts, not the stock fallbacks -------------------
-- If DefineFont took its fallback branch, every assertion below about sizes would be
-- checking a font object that does not exist, and pass by accident.
local TOKENS = { "FONT_TITLE", "FONT_H1", "FONT_H2", "FONT_H3", "FONT_BODY", "FONT_SMALL" }
for _, token in ipairs(TOKENS) do
    local name = ns[token]
    ok(type(name) == "string" and name ~= "", token .. " is a font name")
    ok(name and string.sub(tostring(name), 1, 7) == "Valuate",
        token .. " resolved to a real font object rather than falling back to a stock template (got "
        .. tostring(name) .. ")")
end

-- ---- and those objects carry the sizes we asked for --------------------------------
-- Returns 0 rather than nil for a token that never became a font object. A nil here made
-- the comparisons below crash with "attempt to compare two nil values", which aborts the
-- run and hides the named assertions that actually explain what went wrong.
local function sizeOf(token)
    local obj = _G[ns[token]]
    if not obj or not obj.__font then return 0 end
    return obj.__font[2] or 0
end

eq(sizeOf("FONT_TITLE"), 16, "title size")
eq(sizeOf("FONT_H1"), 14, "h1 size")
eq(sizeOf("FONT_H2"), 13, "h2 size")
eq(sizeOf("FONT_H3"), 12, "h3 size")
eq(sizeOf("FONT_BODY"), 12, "body size")
eq(sizeOf("FONT_SMALL"), 10, "small size")

-- ---- the scale actually descends ----------------------------------------------------
-- The rule that was broken: a heading must be LARGER than the body text under it.
ok(sizeOf("FONT_TITLE") > sizeOf("FONT_H1"), "the window title is larger than a section header")
ok(sizeOf("FONT_H1") > sizeOf("FONT_H2"), "h1 is larger than h2")
ok(sizeOf("FONT_H2") > sizeOf("FONT_H3"), "h2 is larger than h3")
ok(sizeOf("FONT_H1") > sizeOf("FONT_BODY"),
    "a section header is LARGER than the body text under it - the defect this gate exists for")
ok(sizeOf("FONT_BODY") > sizeOf("FONT_SMALL"), "body is larger than small print")

-- Every step has to be visible. Two tokens one point apart read as a mistake rather than a
-- hierarchy, except where they are deliberately equal (h3 and body).
ok(sizeOf("FONT_TITLE") - sizeOf("FONT_H1") >= 2, "title and h1 are clearly different sizes")
ok(sizeOf("FONT_BODY") - sizeOf("FONT_SMALL") >= 2, "body and small are clearly different sizes")

return failures, checks
`,
  "typescale",
  "the type scale"
);
