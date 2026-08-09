#!/usr/bin/env node
/*
 * @gate The wizard matches a build to the right template, and normalises it usably
 *
 * Ascension is classless, so the wizard cannot ask "what class are you" and cannot show a
 * spec list. What it CAN do is compare the gear you already wear against the 28 hand-tuned
 * CLASS_SPEC_TEMPLATES and propose the one you most resemble - detect and confirm, rather
 * than interrogate.
 *
 * This runs that matching against the REAL template data rather than a fixture. A fixture
 * would let the maths pass while the actual templates produced nonsense, and the templates
 * are the whole reason the result is any good.
 *
 * The two failure modes worth gating:
 *   - Stamina, Armor and Health scale with item level rather than with what you are
 *     building. Left in the comparison they dominate it and every build matches the same
 *     template, which looks like it is working.
 *   - Templates carry weights as low as 0.005 as tiebreakers. Those are invisible when
 *     scoring but they reach the stat editor, and forty near-zero rows is what makes a
 *     generated scale feel like a mess rather than a build.
 *
 * Usage:  node tools/automatch.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const data = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Data.lua"), "utf8");

const templates = data.match(/local CLASS_SPEC_TEMPLATES = \{[\s\S]*?\n\}\r?\n/);
if (!templates) {
  console.error("  SLICE  could not find CLASS_SPEC_TEMPLATES in ui/Data.lua");
  process.exit(1);
}

// Order matters, and getting it wrong is silent. A local spliced in BELOW a function that
// reads it compiles to a nil GLOBAL - the trap this codebase has hit before. Every constant
// therefore precedes the function that closes over it.
const pieces = [
  /^local MATCH_IGNORED_STATS = \{[\s\S]*?\n\}/m,
  /^local function StatVectorSimilarity\([\s\S]*?\r?\nend/m,
  /^function Valuate:MatchTemplateToStats\([\s\S]*?\r?\nend/m,
  /^local NORMALIZE_FLOOR = [\d.]+/m,
  /^function Valuate:NormalizeWeights\([\s\S]*?\r?\nend/m,
  /^local AUTO_NAME_PREFIX = "[^"]*"/m,
  /^local AUTO_NAME_COUNT = \d+/m,
  /^function Valuate:BuildAutoScaleName\([\s\S]*?\r?\nend/m,
];
const sliced = [];
for (const re of pieces) {
  const m = core.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate is testing nothing");
    process.exit(1);
  }
  sliced.push(m[0]);
}

const abbrev = fs
  .readFileSync(path.join(ADDON_ROOT, "StatDefinitions.lua"), "utf8")
  .match(/ValuateStatAbbreviations = \{[\s\S]*?\n\}/)[0];

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

Valuate = {}
` + abbrev + `
` + templates[0] + `
` + sliced.join("\n") + `

local TEMPLATES = CLASS_SPEC_TEMPLATES

-- ---- the real data is present and the shape held ------------------------------
local specCount = 0
for _, class in ipairs(TEMPLATES) do
    for _, spec in ipairs(class.specs or {}) do
        specCount = specCount + 1
        ok(type(spec.weights) == "table" and next(spec.weights) ~= nil,
            "every spec carries weights (" .. tostring(class.class) .. "/" .. tostring(spec.name) .. ")")
        ok(type(spec.role) == "string", "every spec declares a role")
    end
end
ok(specCount >= 25, "the real template list is loaded, not a stub (" .. specCount .. " specs)")

-- ---- matching a plate melee profile --------------------------------------------
-- Deliberately the raw shape of worn gear: lots of Stamina and Armor, because everything
-- has those, plus the stats that actually say what this build is.
local plateMelee = {
    Strength = 900, Stamina = 1200, Armor = 18000, AttackPower = 400,
    CritRating = 300, HitRating = 250, ExpertiseRating = 120,
}
local spec, score, runnerUp, class = Valuate:MatchTemplateToStats(TEMPLATES, plateMelee)
ok(spec ~= nil, "a plate melee profile matches something")
ok(score > 0.5, "and matches it with confidence (got " .. tostring(score) .. ")")
ok((spec.weights.Strength or 0) > (spec.weights.Intellect or 0),
    "the match values Strength over Intellect, like the gear does")
ok(runnerUp ~= nil, "a runner-up is offered, so a close call can be shown rather than hidden")

-- ---- a caster profile must NOT land on the same answer ---------------------------
local caster = {
    Intellect = 900, Stamina = 1100, Armor = 4000, SpellPower = 1200,
    CritRating = 300, HitRating = 200, HasteRating = 250,
}
local casterSpec = Valuate:MatchTemplateToStats(TEMPLATES, caster)
ok(casterSpec ~= nil, "a caster profile matches something")
ok((casterSpec.weights.Intellect or 0) > (casterSpec.weights.Strength or 0),
    "the caster match values Intellect over Strength")
ok(casterSpec ~= spec, "a caster and a plate melee do not match the same template")

-- This is the check that catches the bug worth catching. Stamina and Armor scale with
-- item level, not with intent; if they count, every profile converges on one answer and
-- the wizard looks like it is working while proposing nonsense.
local staminaHeavy = {
    Intellect = 900, SpellPower = 1200, CritRating = 300, HitRating = 200,
    HasteRating = 250, Stamina = 999999, Armor = 999999, Health = 999999,
}
local drowned = Valuate:MatchTemplateToStats(TEMPLATES, staminaHeavy)
eq(drowned, casterSpec, "burying a caster in Stamina and Armor does not change the match")

-- ---- role filtering --------------------------------------------------------------
local tank = Valuate:MatchTemplateToStats(TEMPLATES, plateMelee, "TANK")
ok(tank ~= nil, "asking for a TANK returns a tank template")
eq(tank.role, "TANK", "and it really is one")
ok(tank ~= spec, "the tank answer differs from the unfiltered one for the same gear")
ok(Valuate:MatchTemplateToStats(TEMPLATES, plateMelee, "NOSUCHROLE") == nil,
    "an unknown role matches nothing rather than falling back to anything")

-- ---- no gear yet -------------------------------------------------------------------
local none, noneScore = Valuate:MatchTemplateToStats(TEMPLATES, {})
eq(none, nil, "no equipped stats matches nothing")
eq(noneScore, 0, "and reports zero confidence rather than a made-up number")
eq(Valuate:MatchTemplateToStats(nil, plateMelee), nil, "no templates is handled, not crashed")

-- ---- determinism -------------------------------------------------------------------
local firstPick = Valuate:MatchTemplateToStats(TEMPLATES, plateMelee)
local stable = true
for _ = 1, 20 do
    if Valuate:MatchTemplateToStats(TEMPLATES, plateMelee) ~= firstPick then stable = false end
end
ok(stable, "the same gear always proposes the same template")

-- The real templates do not happen to produce an exact tie, so repeating the call above
-- proves nothing about the tiebreaker. This constructs one.
--
-- The risk is not pairs() here - the class list is an array walked with ipairs. It is that
-- WITHOUT a tiebreak the winner falls out of the order the templates happen to sit in, so
-- reordering ui/Data.lua would silently change which build the wizard proposes to everyone.
local tiedTemplates = {
    { class = "Zeta", specs = {
        { name = "Same", role = "DAMAGER", weights = { Strength = 1.0, CritRating = 0.5 } },
    } },
    { class = "Alpha", specs = {
        { name = "Same", role = "DAMAGER", weights = { Strength = 1.0, CritRating = 0.5 } },
    } },
}
local _, tieScore, _, tieClass = Valuate:MatchTemplateToStats(tiedTemplates, plateMelee)
ok(tieScore > 0, "the constructed tie actually matches, so this check is live")
eq(tieClass.class, "Alpha",
    "an exact tie breaks on the class/spec key, not on where the template sits in the file")

-- ---- normalising into something usable ---------------------------------------------
local normalized = Valuate:NormalizeWeights(spec.weights)
local top, rows, tiny = 0, 0, 0
for _, w in pairs(normalized) do
    if w > top then top = w end
    rows = rows + 1
    if w < 0.05 then tiny = tiny + 1 end
end
eq(top, 1.0, "the leading stat normalises to exactly 1.0")
eq(tiny, 0, "no weight survives below the floor")
ok(rows >= 4, "enough stats survive to be a real scale (" .. rows .. ")")
ok(rows <= 14, "but not so many that the editor is a wall of rows (" .. rows .. ")")

local rawRows = 0
for _ in pairs(spec.weights) do rawRows = rawRows + 1 end
ok(rows < rawRows, "normalising drops the tiebreaker noise (" .. rawRows .. " -> " .. rows .. ")")

-- Rounding, because 0.8333333 in a stat editor reads as a bug rather than a weight.
for stat, w in pairs(normalized) do
    ok(math.abs(w * 100 - math.floor(w * 100 + 0.5)) < 0.0001,
        "weights are rounded to two places (" .. stat .. " = " .. tostring(w) .. ")")
end

-- The real templates divide evenly, so the loop above never sees a repeating decimal and
-- proves nothing about the rounding. This is the case that does.
local repeating = Valuate:NormalizeWeights({ Strength = 0.6, CritRating = 0.5 })
eq(repeating.CritRating, 0.83, "a weight that does not divide evenly is rounded, not left at 0.8333...")
eq(repeating.Strength, 1.0, "and the leader is still exactly 1.0")

eq(next(Valuate:NormalizeWeights({})), nil, "nothing in, nothing out")
eq(next(Valuate:NormalizeWeights({ Spirit = -1 })), nil, "a negative-only set normalises to empty")

-- ---- and the whole point: this produces a named, usable scale -----------------------
local name = Valuate:BuildAutoScaleName(normalized)
ok(string.sub(name, 1, 7) == "Auto - ", "the matched build names itself: " .. name)
ok(not string.find(name, "Rating", 1, true),
    "the name uses abbreviations rather than raw stat keys: " .. name)

return failures, checks
`,
  "automatch",
  "wizard template matching"
);
