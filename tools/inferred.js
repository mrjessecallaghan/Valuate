#!/usr/bin/env node
/*
 * @gate "These weights are a guess" survives the click that creates the scale
 *
 * Runs the real creation paths and the real editor summary against a mocked client.
 *
 * v0.122.0a made the picker's tooltip admit that six specs have weights nobody ever
 * published. That warning had a lifetime of ONE HOVER. Both paths that turn a template into
 * a scale - "From Template" and the wizard - dropped the flag on the floor, so the instant
 * you clicked, the scale was indistinguishable from one built on researched numbers and
 * stayed that way for as long as you used it.
 *
 * A warning you see once, before you have done the thing, is barely a warning. The screen
 * where you would act on it is the scale editor, days later, wondering why this build scores
 * oddly - and that screen said nothing.
 *
 * So this gate checks the flag SURVIVES, end to end, on both paths:
 *
 *   template.inferred -> scale.Inferred -> the editor says so, in the editor, every time.
 *
 * And that it does NOT appear on the ninety-five specs that were researched. A caveat on
 * everything is a caveat on nothing, and a warning that cannot discriminate is decoration.
 *
 * Usage:  node tools/inferred.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

// Constants FIRST. PlanAutoScale compares `score < MATCH_UNSURE`, and an unspliced constant
// is nil rather than absent - the slice loads clean and then dies mid-comparison.
const PIECES = [
  /^local MATCH_UNSURE = [\d.]+/m,
  /^local MATCH_CLOSE_MARGIN = [\d.]+/m,
  /^local AUTO_SCALE_COLOR = "[0-9A-Fa-f]{6}"/m,
  /^function Valuate:PlanAutoScale\([\s\S]*?\r?\nend/m,
  /^function Valuate:CommitAutoScale\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return m[0];
});

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/ScaleList.lua",
  "ui/ScaleEditor.lua",
]);

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

local SCALES = {}
Valuate.GetScales = function() return SCALES end
Valuate.GetOptions = function() return { decimalPlaces = 1 } end
Valuate.ShowConfirmDialog = function() end
-- The defensive floor is autowizard.js and defensive.js's subject, not this one. Stubbed to
-- the identity so a change in how it works cannot make this gate fail for an unrelated reason.
Valuate.ApplyDefensiveFloor = function(_, w) return w end
Valuate.CalculateTotalEquippedScore = function() return 0 end
Valuate.ResetTooltips = function() end
Valuate.ScanBestEquipment = function() end
Valuate.RefreshBestEquipmentDisplay = function() end

-- ---- the flag exists in the data at all ---------------------------------------
-- If this ever goes to zero the rest of the gate is checking a rule with no subjects,
-- and would keep passing while protecting nothing.
local inferredSpec, solidSpec = nil, nil
for _, class in ipairs(ns.COA_CLASS_SPEC_TEMPLATES) do
    for _, spec in ipairs(class.specs or {}) do
        if spec.inferred and not inferredSpec then inferredSpec = spec end
        if not spec.inferred and not solidSpec then solidSpec = spec end
    end
end
ok(inferredSpec ~= nil, "at least one spec is still marked inferred")
ok(solidSpec ~= nil, "and at least one is not, so the warning has something to discriminate against")

-- ---- path 1: From Template ------------------------------------------------------
SCALES = {}
local madeName = ValuateUI_CreateScaleFromTemplate(inferredSpec)
ok(madeName ~= nil, "From Template creates a scale from an inferred spec")
local made = SCALES[madeName]
ok(made ~= nil, "and the scale is saved")
eq(made and made.Inferred, true,
   "the guess flag SURVIVES the click - this is the whole point of the feature")

SCALES = {}
local solidName = ValuateUI_CreateScaleFromTemplate(solidSpec)
local solid = SCALES[solidName]
ok(solid ~= nil, "a researched spec also creates a scale")
eq(solid and solid.Inferred, nil,
   "and carries NO flag - a caveat on everything is a caveat on nothing")

-- ---- path 2: the wizard ---------------------------------------------------------
-- The other door into the same room. A warning that survives one path and not the other is
-- the sort of inconsistency nobody can explain afterwards.
` + sliced.join("\n") + `

Valuate.NormalizeWeights = Valuate.NormalizeWeights or function(w) return w end
Valuate.FindMatchingAutoScale = function() return nil end
Valuate.FindUpdatableAutoScale = function() return nil end
Valuate.BuildAutoScaleName = function() return "Auto - Test" end
Valuate.BuildUniqueAutoScaleName = function() return "Auto - Test" end

-- Match against exactly the spec we want, so the plan is about the flag rather than about
-- how well the matcher works - which automatch.js already covers.
local WANTED = inferredSpec
Valuate.MatchTemplateToStats = function()
    return WANTED, 1.0, nil, { class = "Son of Arugal" }, 0
end

local plan = Valuate:PlanAutoScale({ totals = { Agility = 100 }, templates = {} })
ok(plan ~= nil, "the wizard produces a plan for an inferred spec")
eq(plan and plan.inferred, true, "and the plan carries the flag rather than losing it mid-flight")

SCALES = {}
local wizScale = Valuate:CommitAutoScale(plan, SCALES)
ok(wizScale ~= nil, "committing the plan makes a scale")
eq(wizScale and wizScale.Inferred, true, "which also keeps the flag - both doors, same room")

WANTED = solidSpec
local solidPlan = Valuate:PlanAutoScale({ totals = { Agility = 100 }, templates = {} })
eq(solidPlan and solidPlan.inferred, nil, "a researched spec produces a plan with no flag")
SCALES = {}
local solidWiz = Valuate:CommitAutoScale(solidPlan, SCALES)
eq(solidWiz and solidWiz.Inferred, nil, "and a scale with no flag")

-- ---- the editor actually says it ------------------------------------------------
-- Storing the flag and never showing it would be worse than not storing it: the code would
-- look like it works, and every assertion above would still pass.
local shown, hidden = 0, 0
local said = nil
ns.ScaleEditorFrame = nil
ValuateUI_ShowScaleEditor = ValuateUI_ShowScaleEditor  -- may not exist; the editor is built below

local editor = ns.CreateScaleEditor and ns.CreateScaleEditor(CreateFrame("Frame"))
ok(editor ~= nil, "the scale editor builds")

-- Find the font string the summary writes into, by watching what changes.
SCALES = { ["Guessy"] = { DisplayName = "Guessy", Inferred = true,
             Values = { Agility = 1.0 }, Unusable = {} },
           ["Solid"]  = { DisplayName = "Solid",
             Values = { Agility = 1.0 }, Unusable = {} } }

local function editorSays()
    local out = {}
    for _, f in ipairs(__frames) do
        for _, region in ipairs(f.__regions or {}) do
            if region.GetText and region.__shown ~= false then
                local t = region:GetText()
                if t and t ~= "" then out[#out + 1] = t end
            end
        end
    end
    return table.concat(out, "\\n")
end

ns.EditingScaleName = "Guessy"
ns.UpdateScaleEditorSummary()
local guessyText = editorSays()
ok(guessyText:find("guess", 1, true) ~= nil,
   "editing a guessed scale, the editor says the weights are a guess")
ok(guessyText:find("published", 1, true) ~= nil,
   "and explains that nothing was ever published for it")

ns.EditingScaleName = "Solid"
ns.UpdateScaleEditorSummary()
local solidText = editorSays()
eq(solidText:find("guess", 1, true), nil,
   "editing a researched scale, the editor says nothing of the sort")

return failures, checks
`,
  "inferred",
  "the guess warning outlives the click that creates the scale"
);
