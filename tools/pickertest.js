#!/usr/bin/env node
/*
 * @gate The template picker offers every class the templates define
 *
 * Builds the real full template picker from ui/Pickers.lua and checks what it put on screen.
 *
 * This gate exists because of a bug a user found in the game that nothing here could see.
 * The picker localised ns.CLASS_SPEC_TEMPLATES at file load and populated three columns from
 * a hand-typed list of nine class names:
 *
 *     local column1Classes = {"Warrior", "Paladin", "Hunter"}
 *     local column2Classes = {"Rogue", "Priest", "Shaman"}
 *     local column3Classes = {"Mage", "Warlock", "Druid"}
 *
 * So the one screen whose entire job is choosing a spec offered nine of thirty-one classic
 * options - Death Knight silently vanished the day it was added - and NONE of Conquest of
 * Azeroth's 21. All of it built, documented, wizard-matched, and unreachable.
 *
 * Every gate passed the whole time. They checked that the templates existed, that the wizard
 * matched them, that the data was consistent - and none checked that the picker OFFERS them.
 * "The screen draws" and "the screen draws the right things" are different claims.
 *
 * Usage:  node tools/pickertest.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Pickers.lua",
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

-- The set the picker should be reading, swapped per test.
local SET, SET_NAME = ns.CLASS_SPEC_TEMPLATES, "classic"
Valuate.GetTemplateSet = function() return SET, SET_NAME end
Valuate.GetScales = function() return {} end

local CLASS = "Warrior"
function UnitClass() return CLASS, CLASS:upper() end

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end

-- Every class name that ended up drawn, whatever widget carried it. The picker writes class
-- headers as font strings, so the text is the evidence that a class is reachable.
local function drawnClasses()
    local seen = {}
    for _, f in ipairs(__frames) do
        for _, region in ipairs(f.__regions or {}) do
            local text = region.GetText and region:GetText()
            if text then seen[text] = true end
        end
        if f.label and f.label.GetText then
            local t = f.label:GetText()
            if t then seen[t] = true end
        end
    end
    return seen
end

local function missingFrom(set)
    local seen = drawnClasses()
    local missing = {}
    for _, entry in ipairs(set) do
        if not seen[entry.class] then missing[#missing + 1] = entry.class end
    end
    return missing
end

-- ---- the classic set ---------------------------------------------------------
ValuateUI_ShowFullTemplatePicker()
local missingClassic = missingFrom(ns.CLASS_SPEC_TEMPLATES)
eq(#missingClassic, 0,
   "every classic class appears in the picker (missing: " .. table.concat(missingClassic, ", ") .. ")")

-- Death Knight specifically: it was added to the templates and the hand-typed column list
-- was never updated, so it was absent from this screen for its whole existence.
ok(drawnClasses()["Death Knight"] ~= nil,
   "Death Knight is offered - the class the hardcoded nine-name list silently dropped")

-- The CoA half is a SEPARATE gate, tools/pickercoa.js, for the reason wizardroles.js is
-- separate from wizarduitest.js: the picker builds its frame once and reuses it, so one
-- harness can be a classic character or a CoA one but never both. Reaching in to reset the
-- file-local frame would be testing a thing no player can do.
ok(ns.COA_CLASS_SPEC_TEMPLATES ~= nil, "the CoA set exists (offered by tools/pickercoa.js)")

return failures, checks
`,
  "pickertest",
  "the template picker's class coverage"
);
