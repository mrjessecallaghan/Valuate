#!/usr/bin/env node
/*
 * @gate The About panel sizes itself to its content, and its content still fits the window
 *
 * Builds the real About panel and measures what it came out to.
 *
 * The panel used to be a hardcoded 400px with no scroll frame, and carried its own warning:
 *
 *     -- NOTE: this panel has a FIXED 400px height and no scroll frame, so keep this
 *     -- list to roughly its current length or it will overflow the panel.
 *
 * That comment is why the feature list went stale. Every feature added over a year was left
 * off rather than risk clipping the Discord and Ko-fi lines underneath it - the list did
 * exactly what it was told and drifted a year behind the addon. A container that cannot grow
 * makes staleness the safe option, which is how a hand-maintained list rots without anyone
 * making a mistake.
 *
 * So the panel now measures itself. This gate holds both ends of that:
 *
 *   IT REPORTS A REAL HEIGHT, not a constant. A panel that reports 400 forever satisfies any
 *   fits-the-window check on any content, which is exactly the state it was already in.
 *
 *   THE CONTENT STILL FITS. Self-sizing removes the clipping risk only while something is
 *   watching the total; without this, "it grows" quietly becomes "it grows off the screen".
 *
 * Usage:  node tools/aboutfits.js
 */
"use strict";

const { load } = require("./luaharness.js");

// The smallest window this panel has to live inside. Taken from the UI's own minimum rather
// than picked: a panel that only fits when the window is dragged large is not one that fits.
const MIN_WINDOW = 500;

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/InfoPanels.lua",
]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end

local ns = __ns
Valuate.GetOptions = function() return {} end

local parent = CreateFrame("Frame")
local about = ns.CreateAboutPanel(parent)
ok(about ~= nil, "the About panel builds")

-- ---- it measured itself -------------------------------------------------------
local h = about and about.contentHeight
ok(type(h) == "number" and h > 0, "the panel reports how tall its content came out")

-- Not the old constant. A panel that reports 400 forever passes any fits check on any
-- content, which is the state this gate was written to get out of.
ok(h ~= 400, "the reported height is measured, not the hardcoded 400 it used to be")

-- A LOWER bound as well as an upper one. "Does it fit" is satisfied by any height that is
-- small enough, including one that ignores the text entirely - a harness returning a flat
-- 12 per string reports this panel at about seventy pixels and passes happily. The feature
-- list alone is twenty lines - 240px on its own - so a total under 300 means the measurement
-- is not reading the content. A flat 12-per-string harness lands at 224, which is why the
-- bound is not lower: it has to sit above what the tautology produces, not merely above zero.
ok(h and h >= 300, string.format(
    "the reported height reflects the amount of text - got %d, too small for a " ..
    "twenty-line feature list plus a paragraph. Something is measuring the NUMBER of font " ..
    "strings rather than what they say.", h or -1))

-- ---- and it fits -----------------------------------------------------------------
ok(h and h <= ${MIN_WINDOW}, string.format(
    "the About content fits a %dpx window - got %d. Self-sizing stops it CLIPPING, not " ..
    "growing off the screen; trim the feature list or give this panel a scroll frame.",
    ${MIN_WINDOW}, h or -1))

-- ---- the list is not obviously a year behind --------------------------------------
-- Not a completeness check - there is no honest way to derive "every feature" from the
-- source. This names a handful of things that are unmissable in the addon today and were
-- absent from the list while the panel could not grow, so the specific rot that happened
-- cannot happen again silently.
local text = {}
for _, f in ipairs(__frames) do
    for _, region in ipairs(f.__regions or {}) do
        if region.GetText then
            local t = region:GetText()
            if t then text[#text+1] = t end
        end
    end
end
local blob = table.concat(text, "\\n")
for _, word in ipairs({ "Make me a scale", "Conquest of Azeroth", "Bank-aware", "Dungeon" }) do
    ok(blob:find(word, 1, true) ~= nil,
       "the feature list mentions " .. word .. " - it was missing while the panel could not grow")
end

return failures, checks
`,
  "aboutfits",
  "the About panel measures itself and still fits"
);
