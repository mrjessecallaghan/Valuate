#!/usr/bin/env node
/*
 * @gate The Support choice appears for a CoA character, and only then
 *
 * Conquest of Azeroth has six support specs; the classic ten classes have none. So the
 * wizard's Support button has to be conditional: drawn when the active template set can
 * answer it, absent when it cannot.
 *
 * tools/wizarduitest.js covers the negative case — it builds the wizard against the classic
 * set and requires the button to be missing. It cannot cover the positive one, because the
 * wizard builds its screens ONCE per session and that test has already opened it as a classic
 * character by the time the CoA table exists.
 *
 * Hence a separate run: a fresh session that is CoA from the start.
 *
 * Usage:  node tools/wizardroles.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Wizard.lua",
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

-- A CoA character, established BEFORE the wizard is opened for the first time. The screens
-- are built once, so the template set has to be right at that moment.
ns.COA_CLASS_SPEC_TEMPLATES = {
    {
        class = "Testcaller", color = "FFFFFF", description = "t",
        specs = {
            { name = "Hits", role = "DAMAGER", icon = "x", weights = { Intellect = 1.0 } },
            { name = "Holds", role = "TANK", icon = "x", weights = { Stamina = 1.0 } },
            { name = "Mends", role = "HEALER", icon = "x", weights = { Spirit = 1.0 } },
            { name = "Helps", role = "SUPPORT", icon = "x", weights = { HasteRating = 1.0 } },
        },
    },
}
ns.CLASS_SPEC_TEMPLATES = {
    { class = "Warrior", color = "FFFFFF", description = "t", specs = {
        { name = "Arms", role = "DAMAGER", icon = "x", weights = { Strength = 1.0 } } } },
}

UnitClass = function() return "Testcaller" end

local OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end
local SCALES = {}
function Valuate:GetScales() return SCALES end
function Valuate:ScanBestEquipment() end
function Valuate:GetCachedEquippedStatTotals()
    return { Intellect = 900, HasteRating = 400, Stamina = 800 }
end

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:SetText() end
function GameTooltip:AddLine() end
function GameTooltip:Show() end
function GameTooltip:Hide() end

-- The selector has to agree first, or the button test proves nothing about CoA.
local _, which = Valuate:GetTemplateSet()
eq(which, "coa", "the character is treated as CoA")

local opened, err = pcall(function() Valuate:ShowScaleWizard() end)
ok(opened, "the wizard opens for a CoA character: " .. tostring(err))

local buttons = {}
for _, f in ipairs(__frames) do
    if f.__scripts and f.__scripts.OnClick and f.label and f.label.__text then
        buttons[f.label.__text] = f
    end
end

ok(buttons["Support"] ~= nil, "the Support choice is offered when support specs exist")
ok(buttons["Tank"] ~= nil and buttons["Healer"] ~= nil and buttons["Damage"] ~= nil,
    "and the other three are still there")

-- Clicking must not error. This gate loads only the ui/ modules, so Valuate:PlanAutoScale is
-- absent - which makes this a test of the guard in ns.WizardPlan rather than of planning.
-- That planning honours a role at all is autowizard.js's job, and duplicating it here would
-- mean splicing half of Valuate.lua for no extra coverage.
local support = buttons["Support"]
local clicked, clickErr = pcall(function() support.__scripts.OnClick(support) end)
ok(clicked, "clicking Support does not error even with the core absent: " .. tostring(clickErr))

return failures, checks
`,
  "wizardroles",
  "the wizard's role choices"
);
