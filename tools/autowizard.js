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
  /^function Valuate:FindUpdatableAutoScale\([\s\S]*?\r?\nend/m,
  /^local MATCH_UNSURE = [\d.]+/m,
  /^local MATCH_CLOSE_MARGIN = [\d.]+/m,
  /^function Valuate:PlanAutoScale\([\s\S]*?\r?\nend/m,
  /^function Valuate:CommitAutoScale\([\s\S]*?\r?\nend/m,
  /^local DRIFT_TTL = \d+/m,
  /^local driftCache, driftAt = [^\r\n]*/m,
  /^function Valuate:GetAutoScaleDrift\([\s\S]*?\r?\nend/m,
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

-- ---- a hand-edited wizard scale is UPDATED, not duplicated ---------------------------
-- Edit a wizard-made scale and run the wizard again on the same gear: the weights now differ
-- from what the template says, so this is the "same build, drifted" case. It offers to
-- replace it rather than adding a near-identical second scale.
--
-- Replacing edits is only acceptable because the preview NAMES what it is replacing - the
-- button reads "Update it" next to the weights it would write. Silent would be wrong.
SCALES[plan3.name].Values = { Intellect = 1.0, SpellPower = 0.4 }
local plan4 = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = casterGear })
eq(plan4.updates, plan3.name, "an edited scale from the SAME spec is offered as an update")
eq(plan4.duplicateOf, nil, "and not as a duplicate, because the weights differ")
eq(plan4.name, plan3.name, "keeping its name rather than becoming a (2)")

local beforeUpdate = 0
for _ in pairs(SCALES) do beforeUpdate = beforeUpdate + 1 end

local updated, updatedWhy = Valuate:CommitAutoScale(plan4)
eq(updatedWhy, "updated", "committing reports that it updated rather than created")
ok(updated ~= nil, "and returns the scale")

local afterUpdate = 0
for _ in pairs(SCALES) do afterUpdate = afterUpdate + 1 end
eq(afterUpdate, beforeUpdate, "the scale count does not grow")
eq(SCALES[plan3.name].Values.Intellect ~= 1.0 or SCALES[plan3.name].Values.SpellPower ~= 0.4,
    true, "and the stale hand-edited weights are gone")

-- A DIFFERENT build must never be offered as an update. Wanting a tank scale AND a dps scale
-- is completely ordinary, and replacing one with the other would be destructive.
local tankish = Valuate:PlanAutoScale({ templates = TEMPLATES, totals = plateMelee, role = "TANK" })
ok(tankish ~= nil, "a tank plan exists")
eq(tankish.updates, nil, "a different spec is never offered as an update to an existing scale")

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

-- ---------------------------------------------------------------------------
-- Staleness: does the addon know its OWN scale has fallen behind your gear?
--
-- The update path is only reachable if something tells you an update is available. This
-- is the read-only question the scale list asks to decide what its wizard button says.
-- ---------------------------------------------------------------------------
for k in pairs(SCALES) do SCALES[k] = nil end

local clock = 100
function GetTime() return clock end
local EQUIPPED = plateMelee
function Valuate:GetCachedEquippedStatTotals() return EQUIPPED end
function Valuate:GetTemplateSet() return TEMPLATES end

eq(Valuate:GetAutoScaleDrift(), nil, "with no scales at all, nothing has drifted")

-- The cheap pre-check: someone who has never run the wizard must not pay for a template
-- match on every repaint of the scale list.
SCALES["Mine"] = { DisplayName = "Mine", Color = "FF0000", Values = { Strength = 1.0 } }
local realPlan = Valuate.PlanAutoScale
local planCalls = 0
Valuate.PlanAutoScale = function(self, o) planCalls = planCalls + 1 return realPlan(self, o) end
clock = clock + 100
eq(Valuate:GetAutoScaleDrift(), nil, "a scale you built yourself is never called stale")
eq(planCalls, 0, "and with no wizard scale present the template match is skipped entirely")

for k in pairs(SCALES) do SCALES[k] = nil end
clock = clock + 100
local made = Valuate:CommitAutoScale(
    Valuate:PlanAutoScale({ templates = TEMPLATES, totals = plateMelee }))
ok(made ~= nil, "the wizard makes one to go stale")
clock = clock + 100
eq(Valuate:GetAutoScaleDrift(), nil, "the scale it just made is not stale")
ok(planCalls > 0, "but a wizard scale DOES cost the template match")

-- Hand-edit it into disagreeing with what the gear implies. This is the levelling case in
-- miniature: same spec, weights that no longer match.
local savedStr = made.Values.Strength
made.Values.Strength = 0.11
clock = clock + 100
local drifted = Valuate:GetAutoScaleDrift()
eq(drifted, made.DisplayName, "an out-of-date scale is reported BY NAME, not as a boolean")

-- The TTL is what stops this being a per-repaint cost. Proven by changing the answer and
-- requiring the OLD one back until the window passes.
made.Values.Strength = savedStr
eq(Valuate:GetAutoScaleDrift(), drifted, "the answer is cached inside the TTL")
clock = clock + 100
eq(Valuate:GetAutoScaleDrift(), nil, "and recomputed once the TTL has passed")

-- The distinction the whole feature rests on: a DIFFERENT build is not a stale one.
for k in pairs(SCALES) do SCALES[k] = nil end
clock = clock + 100
local tankScale = Valuate:CommitAutoScale(
    Valuate:PlanAutoScale({ templates = TEMPLATES, totals = plateMelee, role = "TANK" }))
ok(tankScale ~= nil, "a tank scale exists to be left alone")
EQUIPPED = casterGear
clock = clock + 100
eq(Valuate:GetAutoScaleDrift(), nil,
   "standing in caster gear does NOT report your tank scale as stale")

-- A clock that went backwards (a /reload resets GetTime) must not pin the cache.
EQUIPPED = plateMelee
for k in pairs(SCALES) do SCALES[k] = nil end
clock = 5
local reloaded = Valuate:CommitAutoScale(
    Valuate:PlanAutoScale({ templates = TEMPLATES, totals = plateMelee }))
reloaded.Values.Strength = 0.11
eq(Valuate:GetAutoScaleDrift(), reloaded.DisplayName,
   "a backwards clock recomputes rather than serving a stale cached answer")

return failures, checks
`,
  "autowizard",
  "the scale wizard"
);
