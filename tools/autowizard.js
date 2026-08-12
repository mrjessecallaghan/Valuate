#!/usr/bin/env node
/*
 * @gate The wizard plans without writing, and commits a usable scale
 *
 * End to end: read the gear, match a template, normalise it, name it, create it, and leave
 * you on a scale that is actually in use. This gate runs that whole path against the REAL
 * CLASS_SPEC_TEMPLATES.
 *
 * The split is the thing being protected. PlanAutoScale must change nothing at all - the
 * wizard shows the plan and you can close the window - and CommitAutoScale must be the only
 * half that writes. A wizard that creates as it goes leaves half-made scales behind when
 * you back out, and this one is aimed squarely at people who WILL back out.
 *
 * Usage:  node tools/autowizard.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const data = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Data.lua"), "utf8");
const abbrev = fs
  .readFileSync(path.join(ADDON_ROOT, "StatDefinitions.lua"), "utf8")
  .match(/ValuateStatAbbreviations = \{[\s\S]*?\n\}/)[0];

const templates = data.match(/local CLASS_SPEC_TEMPLATES = \{[\s\S]*?\n\}\r?\n/);
if (!templates) {
  console.error("  SLICE  could not find CLASS_SPEC_TEMPLATES in ui/Data.lua");
  process.exit(1);
}

// Constants before the functions that close over them: a local spliced in below its reader
// compiles to a nil global, silently.
const pieces = [
  /^local MATCH_IGNORED_STATS = \{[\s\S]*?\n\}/m,
  /^local function StatVectorSimilarity\([\s\S]*?\r?\nend/m,
  /^function Valuate:MatchTemplateToStats\([\s\S]*?\r?\nend/m,
  /^local NORMALIZE_FLOOR = [\d.]+/m,
  /^function Valuate:NormalizeWeights\([\s\S]*?\r?\nend/m,
  /^local AUTO_NAME_PREFIX = "[^"]*"/m,
  /^local AUTO_NAME_COUNT = \d+/m,
  /^function Valuate:BuildAutoScaleName\([\s\S]*?\r?\nend/m,
  /^function Valuate:BuildUniqueAutoScaleName\([\s\S]*?\r?\nend/m,
  /^local AUTO_SCALE_COLOR = "[0-9A-Fa-f]{6}"/m,
  /^local function WeightsMatch\([\s\S]*?\r?\nend/m,
  /^function Valuate:FindMatchingAutoScale\([\s\S]*?\r?\nend/m,
  /^local MATCH_UNSURE = [\d.]+/m,
  /^local MATCH_CLOSE_MARGIN = [\d.]+/m,
  /^function Valuate:PlanAutoScale\([\s\S]*?\r?\nend/m,
  /^function Valuate:CommitAutoScale\([\s\S]*?\r?\nend/m,
];
const sliced = [];
for (const re of pieces) {
  const m = core.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  sliced.push(m[0]);
}

/* The wizard's colour has to stay distinguishable from the scales you make by hand, which
 * take a class or spec colour. Checked here rather than by eye, because the template list
 * grows and a collision would silently defeat the whole point of having one colour. */
const wizardColor = core.match(/^local AUTO_SCALE_COLOR = "([0-9A-Fa-f]{6})"/m)[1].toUpperCase();
const templateColors = new Set(
  [...templates[0].matchAll(/color = "([0-9A-Fa-f]{6})"/g)].map((m) => m[1].toUpperCase())
);
if (templateColors.has(wizardColor)) {
  console.error(
    `The wizard colour #${wizardColor} is also a class or spec colour. Generated scales are ` +
      "supposed to be identifiable at a glance; pick one nothing else uses."
  );
  process.exit(1);
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

Valuate = {}
local OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end
local SCALES = {}
function Valuate:GetScales() return SCALES end
local rescans = 0
function Valuate:ScanBestEquipment() rescans = rescans + 1 end

` + abbrev + `
` + templates[0] + `
` + sliced.join("\n") + `

local TEMPLATES = CLASS_SPEC_TEMPLATES
local plateMelee = {
    Strength = 900, Stamina = 1200, Armor = 18000, AttackPower = 400,
    CritRating = 300, HitRating = 250, ExpertiseRating = 120,
}

-- ---- planning changes NOTHING ---------------------------------------------------
local plan, why = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = plateMelee })
ok(plan ~= nil, "a plan is produced for real gear: " .. tostring(why))
eq(next(SCALES), nil, "planning creates no scale")
eq(next(OPTIONS), nil, "planning changes no option")
eq(rescans, 0, "planning triggers no rescan")

-- ---- the plan says everything the confirm screen needs --------------------------
ok(string.sub(plan.name, 1, 7) == "Auto - ", "the plan is named for the build: " .. plan.name)
ok(plan.color == "` + wizardColor + `" or plan.color == "` + wizardColor.toLowerCase() + `",
    "the plan carries the wizard colour")
ok(type(plan.icon) == "string" and plan.icon ~= "", "and an icon from the matched spec")
ok(type(plan.basedOn) == "string" and plan.basedOn ~= "", "and says what it was based on: " .. tostring(plan.basedOn))
ok(type(plan.confidence) == "number" and plan.confidence > 0, "and how confident the match was")
ok(plan.alternative ~= nil, "and names the runner-up, which for this gear really was close")
ok(next(plan.weights) ~= nil, "and carries the weights it intends to use")

-- ---- refusals explain themselves, rather than producing a junk scale --------------
local none, reason = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = {} })
eq(none, nil, "no gear produces no plan")
ok(type(reason) == "string" and reason ~= "", "and says why in words a person can act on: " .. tostring(reason))

local noTemplates, reason2 = Valuate:PlanAutoScale({ templates = nil, totals = plateMelee })
eq(noTemplates, nil, "no templates produces no plan")
ok(type(reason2) == "string" and reason2 ~= "", "with its own reason: " .. tostring(reason2))
eq(Valuate:PlanAutoScale(), nil, "no arguments at all is handled rather than crashing")

-- ---- committing is the half that writes -------------------------------------------
local scale = Valuate:CommitAutoScale(plan)
ok(scale ~= nil, "the plan commits")
ok(SCALES[plan.name] ~= nil, "the scale exists under its own name")
eq(SCALES[plan.name], scale, "and is the object that was returned")
eq(scale.DisplayName, plan.name, "the display name matches")
eq(scale.Color, plan.color, "the wizard colour is carried onto the scale")
eq(scale.Icon, plan.icon, "so is the icon")
ok(type(scale.Unusable) == "table", "and it has the unusable table every scale needs")

local weightCount = 0
for stat, w in pairs(scale.Values) do
    weightCount = weightCount + 1
    eq(w, plan.weights[stat], "weight for " .. stat .. " is carried across intact")
end
ok(weightCount >= 4, "the committed scale has real weights (" .. weightCount .. ")")

-- ---- it ends on a scale that is actually IN USE -----------------------------------
eq(OPTIONS.characterWindowScale, plan.name,
    "the new scale is made primary, rather than leaving you to go and select it")
eq(rescans, 1, "and gear is rescanned, so the scale means something immediately")

-- ---- the plan is a snapshot, not a live reference ----------------------------------
-- The wizard shows the plan again on its last screen; if Values were the same table, a
-- later edit to either would silently change the other.
plan.weights.Strength = 999
ok(scale.Values.Strength ~= 999, "editing the plan afterwards does not alter the saved scale")

-- ---- running it twice cannot destroy the first result -------------------------------
-- Same gear, same answer. Building a second identical scale and suffixing it "(2)" leaves
-- two rows nobody can tell apart, so the wizard recognises the one it already made.
local plan2 = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = plateMelee })
eq(plan2.duplicateOf, plan.name, "a second run recognises the scale it already made")
eq(plan2.name, plan.name, "and describes that one rather than inventing a (2)")

local reused, why2 = Valuate:CommitAutoScale(plan2)
eq(why2, "reused", "committing it reuses rather than creates")
eq(reused, SCALES[plan.name], "returning the scale that already existed")
eq(OPTIONS.characterWindowScale, plan.name, "and still leaves you on it")

local afterSecond = 0
for _ in pairs(SCALES) do afterSecond = afterSecond + 1 end
eq(afterSecond, 1, "so no near-identical twin is added")

-- Different gear must NOT be mistaken for it, or the wizard would refuse to build anything
-- new once you owned one scale.
local casterGear = {
    Intellect = 900, Stamina = 1100, Armor = 4000, SpellPower = 1200,
    CritRating = 300, HitRating = 200, HasteRating = 250,
}
local plan3 = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = casterGear })
eq(plan3.duplicateOf, nil, "different gear is not mistaken for the scale you already have")
ok(plan3.name ~= plan.name, "and gets its own name: " .. plan3.name)
Valuate:CommitAutoScale(plan3)

local afterThird = 0
for _ in pairs(SCALES) do afterThird = afterThird + 1 end
eq(afterThird, 2, "a genuinely different build still adds a scale")
ok(SCALES[plan.name] ~= nil, "and the first one is untouched")

-- A subset is not a match: matching one way round would call a scale with three extra
-- stats identical to one with three fewer.
local subset = { Strength = 1.0 }
eq(Valuate:FindMatchingAutoScale(subset, SCALES), nil,
    "a scale whose weights are a subset of another is not called identical")

-- ---- a NAME collision that is not a duplicate -----------------------------------------
-- The name records only the top five stats, so two different builds can share one. Edit a
-- generated scale by hand and you have exactly that: same name, different weights. It is
-- not the same scale, so reuse would be wrong - and without the uniqueness suffix the next
-- run would silently overwrite your edits.
SCALES[plan3.name].Values = { Intellect = 1.0, SpellPower = 0.4 }
local plan4 = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = casterGear })
eq(plan4.duplicateOf, nil, "a hand-edited scale with the same name is not treated as a duplicate")
ok(plan4.name ~= plan3.name,
    "so the plan takes a different name rather than overwriting it: " .. plan4.name)

Valuate:CommitAutoScale(plan4)
eq(SCALES[plan3.name].Values.Intellect, 1.0, "and the hand-edited scale keeps its weights")
eq(SCALES[plan3.name].Values.SpellPower, 0.4, "all of them")
ok(SCALES[plan4.name] ~= nil, "while the new one is created alongside it")

-- ---- a plan with nothing in it is refused rather than committed ---------------------
eq(Valuate:CommitAutoScale(nil), nil, "committing nothing is refused")
eq(Valuate:CommitAutoScale({}), nil, "so is a plan with no name")
eq(Valuate:CommitAutoScale({ name = "" }), nil, "and one with an empty name")

-- ---- the runner-up is named only when it REALLY was close ---------------------------
-- "X was close" about something that scored far lower is a false statement, and a confirm
-- screen is the worst place to make one.
local twins = {
    { class = "A", specs = {
        { name = "One", role = "DAMAGER", weights = { Strength = 1.0, CritRating = 0.5 } } } },
    { class = "B", specs = {
        { name = "Two", role = "DAMAGER", weights = { Strength = 1.0, CritRating = 0.5 } } } },
}
local closePlan = Valuate:PlanAutoScale({ templates = twins, totals = plateMelee })
ok(closePlan ~= nil and closePlan.alternative ~= nil,
    "a runner-up that scored identically is named")

local farApart = {
    { class = "A", specs = {
        { name = "Fits", role = "DAMAGER",
          weights = { Strength = 1.0, AttackPower = 0.8, CritRating = 0.6 } } } },
    { class = "B", specs = {
        { name = "Wrong", role = "DAMAGER", weights = { Spirit = 1.0, Mp5 = 0.9 } } } },
}
local farPlan = Valuate:PlanAutoScale({ templates = farApart, totals = plateMelee })
ok(farPlan ~= nil, "a lopsided template list still plans")
eq(farPlan.alternative, nil, "a runner-up that scored far lower is NOT called close")

-- ---- a weak match admits it ----------------------------------------------------------
-- Mixed gear, levelling greens and half-finished sets all land here, and those are exactly
-- the people who cannot tell a good answer from a bad one.
local weak = {
    { class = "A", specs = {
        { name = "Barely", role = "DAMAGER",
          weights = { Spirit = 1.0, Mp5 = 1.0, HolySpellPower = 1.0, Strength = 0.2 } } } },
}
local weakPlan = Valuate:PlanAutoScale({
    templates = weak,
    totals = { Strength = 100, CritRating = 500, HitRating = 400 },
})
ok(weakPlan ~= nil, "a weak match still produces a plan rather than a dead end")
ok(weakPlan.caution ~= nil, "and admits it is a rough guess")
ok(weakPlan.caution and string.find(weakPlan.caution, "role", 1, true) ~= nil,
    "pointing at the thing that would do better")

-- Stated as the rule rather than a hardcoded expectation, so this stays true if the
-- templates or the threshold move: the caution appears exactly when confidence is low.
ok((plan.confidence >= 0.55) == (plan.caution == nil),
    "a confident match carries no caution, and only a confident one")

-- ---- role still steers the answer ---------------------------------------------------
local tankPlan = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = plateMelee, role = "TANK" })
ok(tankPlan ~= nil, "asking for a tank plan works")
eq(tankPlan.role, "TANK", "and it really is a tank build")
ok(tankPlan.name ~= plan.name, "which names itself differently: " .. tankPlan.name)

-- ---- the template's banned stats reach the scale ----------------------------------
-- Every wizard-made scale used to get an EMPTY Unusable table, so a two-hander-only build
-- scored daggers and wands as ordinary candidates. The templates ban them deliberately.
local banned = {
    { class = "Bantest", specs = {
        { name = "TwoHandOnly", role = "DAMAGER", icon = "x",
          weights = { Strength = 1.0, CritRating = 0.5 },
          unusable = { IsDagger = true, IsWand = true, IsStaff = true } } } },
}
local banPlan = Valuate:PlanAutoScale({ templates = banned, totals = plateMelee })
ok(banPlan ~= nil, "a template with banned stats plans")
ok(banPlan.unusable ~= nil, "and the plan carries them")

local banScale = Valuate:CommitAutoScale(banPlan)
ok(banScale ~= nil, "it commits")
eq(banScale.Unusable.IsDagger, true, "the created scale bans daggers as the template did")
eq(banScale.Unusable.IsWand, true, "and wands")
eq(banScale.Unusable.IsStaff, true, "and staves")

-- Copied, not shared: the plan is shown again on the last screen.
banPlan.unusable.IsSword = true
eq(banScale.Unusable.IsSword, nil, "editing the plan afterwards does not change the scale")

-- A template with no banned stats still produces a usable empty table rather than nil.
local free = {
    { class = "Freetest", specs = {
        { name = "Anything", role = "DAMAGER", icon = "x",
          weights = { Strength = 1.0 } } } },
}
local freePlan = Valuate:PlanAutoScale({ templates = free, totals = plateMelee })
local freeScale = Valuate:CommitAutoScale(freePlan)
ok(type(freeScale.Unusable) == "table", "a template with no bans still gets an Unusable table")
eq(next(freeScale.Unusable), nil, "and it is empty rather than invented")

return failures, checks
`,
  "autowizard",
  "the scale wizard"
);
