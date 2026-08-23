#!/usr/bin/env node
/*
 * @gate The wizard's screens build and click through end to end
 *
 * ui/Wizard.lua is only the screens - the decisions live in Valuate.lua and are gated by
 * autoname/automatch/autowizard. What THIS gate exists for is the other failure mode: a
 * screen that calls a shared helper the way you assumed it worked.
 *
 * Writing this file caught three of those, all of which would have been a Lua error in the
 * client the first time anyone opened the wizard:
 *   - Anim.staggerFor returns the GAP between items, not a function of the index. Calling
 *     the number would have errored while laying out the first screen.
 *   - ns.ShowTooltipSafe(frame, anchorType) claims the tooltip; it does not take title and
 *     body text. The hints would have silently vanished.
 *   - Valuate:ToggleUI() takes no arguments and TOGGLES - so "Fine-tune it" would have
 *     closed the main window for anyone who already had it open.
 *
 * A parse check and a globals check both pass on all three, because each is a real function
 * called with the wrong contract. Only running it finds them.
 *
 * Usage:  node tools/wizarduitest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const abbrev = fs
  .readFileSync(path.join(ADDON_ROOT, "StatDefinitions.lua"), "utf8")
  .match(/ValuateStatAbbreviations = \{[\s\S]*?\n\}/)[0];
const data = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Data.lua"), "utf8");
const templates = data.match(/local CLASS_SPEC_TEMPLATES = \{[\s\S]*?\n\}\r?\n/)[0];

// Constants before their readers - a local spliced below a function that reads it becomes a
// nil global, silently.
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
  // PlanAutoScale floors the template weights before normalising them.
  /^local DEFENSIVE_FLOORS = \{[\s\S]*?\r?\n\}/m,
  /^function Valuate:ApplyDefensiveFloor\([\s\S]*?\r?\nend/m,
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

// The real UI modules load for real; only the decision half of Valuate.lua is spliced.
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

` + abbrev + `
` + templates + `
` + sliced.join("\n") + `

-- What the wizard reads from the rest of the addon.
local OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end
local SCALES = {}
function Valuate:GetScales() return SCALES end
local rescans = 0
function Valuate:ScanBestEquipment() rescans = rescans + 1 end
local pulses = 0
function Valuate:PulseMinimapButton() pulses = pulses + 1 end
local showUICalls = 0
function Valuate:ShowUI() showUICalls = showUICalls + 1 end

ns.CLASS_SPEC_TEMPLATES = CLASS_SPEC_TEMPLATES

local EQUIPPED = {
    Strength = 900, Stamina = 1200, Armor = 18000, AttackPower = 400,
    CritRating = 300, HitRating = 250, ExpertiseRating = 120,
}
function Valuate:GetCachedEquippedStatTotals() return EQUIPPED end

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:SetText(t) self.__shownText = t end
function GameTooltip:AddLine(t) self.__shownLine = t end
function GameTooltip:Show() self.__visible = true end
function GameTooltip:Hide() self.__visible = false end

-- ---- it opens ------------------------------------------------------------------
local built, err = pcall(function() Valuate:ShowScaleWizard() end)
ok(built, "the wizard opens without erroring: " .. tostring(err))

local frame = _G["ValuateWizardFrame"]
ok(frame ~= nil, "the frame exists under the name UISpecialFrames closes by")
ok(frame:IsShown(), "and it is shown")

local escapeRegistered = false
for _, name in ipairs(UISpecialFrames or {}) do
    if name == "ValuateWizardFrame" then escapeRegistered = true end
end
ok(escapeRegistered, "Escape closes it")

-- ---- the first screen offers the choices, primary first --------------------------
local buttons = {}
for _, f in ipairs(__frames) do
    -- A styled button keeps its text on btn.label, not on the button.
    if f.__scripts and f.__scripts.OnClick and f.label and f.label.__text then
        buttons[f.label.__text] = f
    end
end
ok(buttons["Build it for me"] ~= nil, "the recommended action is on the first screen")
ok(buttons["Tank"] ~= nil and buttons["Healer"] ~= nil and buttons["Damage"] ~= nil,
    "and the role overrides are there too")

-- ---- no dead Support button on a realm that has no support specs -------------------
-- CoA has six support specs; the classic ten classes have none. Drawing the button anyway
-- would give a control whose only possible answer is "nothing resembles what you are
-- wearing" - a control that cannot succeed is its own kind of bug.
--
-- This wizard was built against the CLASSIC set, so the button must be absent.
eq(buttons["Support"], nil,
    "no Support button when the active template set has no support specs")

local roleButtons = 0
for label in pairs(buttons) do
    if label == "Build it for me" or label == "Tank" or label == "Healer"
        or label == "Damage" or label == "Support" then
        roleButtons = roleButtons + 1
    end
end
eq(roleButtons, 4, "four choices on a classic realm, not five")

-- The hint tooltips. This is one of the contracts that was wrong: ShowTooltipSafe claims
-- the tooltip, it does not take the text.
local primary = buttons["Build it for me"]
primary.__scripts.OnEnter(primary)
eq(GameTooltip.__shownText, "Build it for me", "hovering a choice sets the tooltip title")
ok(GameTooltip.__shownLine ~= nil, "and its explanatory line")

-- ---- clicking it plans, and plans WITHOUT creating anything ----------------------
local planned, planErr = pcall(function() primary.__scripts.OnClick(primary) end)
ok(planned, "clicking the recommended action does not error: " .. tostring(planErr))
eq(next(SCALES), nil, "reaching the preview screen has created no scale")
eq(rescans, 0, "and rescanned nothing")

-- ---- the preview says what it will make ------------------------------------------
local previewText = nil
for _, f in ipairs(__frames) do
    if f.__text and string.sub(tostring(f.__text), 1, 7) == "Auto - " then previewText = f.__text end
end
ok(previewText ~= nil, "the preview shows the name it would create: " .. tostring(previewText))

-- ---- creating it -------------------------------------------------------------------
local create = buttons["Create it"]
ok(create ~= nil, "the preview has a create button")
local committed, commitErr = pcall(function() create.__scripts.OnClick(create) end)
ok(committed, "creating does not error: " .. tostring(commitErr))

local madeName, made = next(SCALES)
ok(made ~= nil, "a scale was created")
eq(madeName, previewText, "and it is the one the preview named")
eq(made.Color, "3FE0C8", "carrying the wizard colour")
eq(OPTIONS.characterWindowScale, madeName, "and it is now the primary scale")
eq(rescans, 1, "gear was rescanned once")
eq(pulses, 1, "and the minimap button acknowledged it")

-- ---- the last screen, and its escape hatch -------------------------------------------
local tweak = nil
for _, f in ipairs(__frames) do
    if f.label and f.label.__text == "Fine-tune it" then tweak = f end
end
ok(tweak ~= nil, "the done screen offers a way into the editor")

-- Fine-tuning has to land on the scale it just made. Opening the window and leaving you to
-- find the new row is the same "now go and do it yourself" the wizard exists to remove -
-- and the row is one of several all starting "Auto - ".
local selected = nil
ns.ScaleListButtons = {}
ns.ScaleListButtons[madeName] = CreateFrame("Button")
ns.ScaleListButtons[madeName]:SetScript("OnClick", function() selected = madeName end)

tweak.__scripts.OnClick(tweak)
eq(showUICalls, 1, "which SHOWS the main window")
eq(selected, madeName, "and selects the scale it just made, rather than leaving you to find it")
eq(frame:IsShown(), false, "and closes the wizard behind it")

-- Toggling would have CLOSED the main window for anyone who already had it open, which is
-- the opposite of what the button says. Shown, not toggled.
ok(Valuate.ToggleUI == nil or showUICalls == 1, "the button does not toggle the main window")

-- ---- reopening is clean --------------------------------------------------------------
Valuate:ShowScaleWizard()
ok(frame:IsShown(), "the wizard reopens")
local before = 0
for _ in pairs(SCALES) do before = before + 1 end
primary.__scripts.OnClick(primary)
local after = 0
for _ in pairs(SCALES) do after = after + 1 end
eq(after, before, "reopening and planning again still creates nothing until you confirm")

-- A second real run on the SAME gear reuses what it already made, and the button says so
-- rather than offering to create a twin.
eq(create.label.__text, "Use it", "the button offers to use the existing scale, not create one")
create.__scripts.OnClick(create)
local total = 0
for _ in pairs(SCALES) do total = total + 1 end
eq(total, 1, "a second run on identical gear adds no near-identical twin")

-- Different gear must still be able to create, or owning one scale would block the wizard.
EQUIPPED = {
    Intellect = 900, Stamina = 1100, Armor = 4000, SpellPower = 1200,
    CritRating = 300, HitRating = 200, HasteRating = 250,
}
Valuate:ShowScaleWizard()
primary.__scripts.OnClick(primary)
eq(create.label.__text, "Create it", "a different build offers to create again")
create.__scripts.OnClick(create)
local grown = 0
for _ in pairs(SCALES) do grown = grown + 1 end
eq(grown, 2, "and a genuinely different build does add one")

-- ---- the preview's weight rows are pooled, so leftovers are the risk -------------------
-- Rows are built once and repopulated. The classic pool bug is a row still showing the
-- PREVIOUS run's stat after a shorter list is displayed, which here would mean the preview
-- claims weights the scale does not have.
local previewScreen = nil
for _, f in ipairs(__frames) do
    if f.rows and f.rows[1] then previewScreen = f end
end
ok(previewScreen ~= nil, "the preview screen keeps a pool of weight rows")
eq(#previewScreen.rows, 6, "six of them: five stats plus an 'and N more' line")

-- A full build fills every row.
EQUIPPED = {
    Strength = 900, Stamina = 1200, Armor = 18000, AttackPower = 400,
    CritRating = 300, HitRating = 250, ExpertiseRating = 120,
}
Valuate:ShowScaleWizard()
primary.__scripts.OnClick(primary)
local filled = 0
for _, row in ipairs(previewScreen.rows) do
    if row:IsShown() and row.__text ~= "" then filled = filled + 1 end
end
ok(filled >= 5, "a full build fills the rows (" .. filled .. ")")

-- Now a build with only two weights. Anything still showing is a leftover.
ns.CLASS_SPEC_TEMPLATES = {
    -- A TANK, deliberately. Since v0.118.0a every non-tank build gains a Stamina and Armor
    -- floor, so a two-stat damage spec now legitimately previews as four rows - which would
    -- make this a test of the floor rather than of row clearing. Tanks are exempt from the
    -- floor, so a two-stat tank still previews as exactly two rows and the thing being
    -- guarded here (a pooled row still showing the PREVIOUS build) stays visible.
    { class = "Tiny", specs = {
        -- Has to be a DAMAGER weighting stats the test's gear actually has. A spec that
        -- shares nothing with the equipped vector scores zero similarity and is not matched
        -- at all, which leaves the PREVIOUS build on screen and fails this test for a reason
        -- that has nothing to do with row clearing. Both other shapes were tried.
        { name = "Two", role = "DAMAGER", icon = "x",
          weights = { Strength = 1.0, CritRating = 0.5 } },
    } },
}
primary.__scripts.OnClick(primary)

local stillShowing, texts = 0, {}
for i, row in ipairs(previewScreen.rows) do
    if row:IsShown() and row.__text ~= "" then
        stillShowing = stillShowing + 1
        table.insert(texts, i .. "=" .. tostring(row.__text))
    end
end
-- FOUR, not two: since v0.118.0a a non-tank build also carries the Stamina and Armor floor,
-- so a two-weight damage template legitimately previews as four rows. The row-clearing guard
-- is unaffected - the previous build filled all six, so rows 5 and 6 must still be cleared,
-- which is the leftover this test exists to catch.
eq(stillShowing, 4, "a two-stat build shows two stats plus the defensive floor: " .. table.concat(texts, " "))

for i = 5, 6 do
    eq(previewScreen.rows[i].__text, "",
        "row " .. i .. " is cleared rather than left showing the previous build")
    eq(previewScreen.rows[i]:IsShown(), false, "and hidden")
end

-- ---- the step dots --------------------------------------------------------------------
ok(frame.stepDots ~= nil and #frame.stepDots == 3,
    "the window has three step dots that outlive whichever screen is showing")

ns.CLASS_SPEC_TEMPLATES = CLASS_SPEC_TEMPLATES
EQUIPPED = {
    Strength = 900, Stamina = 1200, Armor = 18000, AttackPower = 400,
    CritRating = 300, HitRating = 250, ExpertiseRating = 120,
}

-- ---- no gear, no dead end --------------------------------------------------------------
EQUIPPED = {}
local naked, nakedErr = pcall(function() primary.__scripts.OnClick(primary) end)
ok(naked, "clicking with no readable gear does not error: " .. tostring(nakedErr))
-- The reason has to arrive IN the wizard. It used to be printed to chat and the window was
-- left on the screen you were already on - a button that appears to do nothing, with the
-- explanation behind the window that just failed to respond. The likeliest way to reach this
-- is also the worst place to be lost: a new character wearing nothing, on the first screen of
-- an addon they installed a minute ago.
local shown = ""
for _, f in ipairs(__frames) do
    for _, region in ipairs(f.__regions or {}) do
        if region.GetText and region.__shown ~= false then
            local t = region:GetText()
            if t then shown = shown .. " | " .. t end
        end
    end
end
ok(shown:find("put something on", 1, true) ~= nil,
   "the reason is shown in the wizard, not printed behind it")
ok(shown:find("could not build", 1, true) ~= nil,
   "under a heading that says the attempt failed")
ok(shown:find("Nothing was created", 1, true) ~= nil,
   "and it says nothing was changed - the first question after a failure is what it did to you")

-- A way onward, not just a wall. The usual fix is one screen back.
local hasRetry = false
for _, f in ipairs(__frames) do
    if f.label and f.label.GetText and f.label:GetText() == "Try again" then hasRetry = true end
end
ok(hasRetry, "and it offers a way back rather than only a Close button")

-- ---- the right template set for the character -------------------------------------
-- Detected from the CLASS, not the realm name: realm names change and a second CoA realm
-- would silently break a hardcoded check, while a Necromancer is one wherever they log in.
ns.COA_CLASS_SPEC_TEMPLATES = {
    { class = "Necromancer", specs = {
        { name = "Death", role = "DAMAGER", icon = "x", weights = { Intellect = 1.0 } } } },
}

UnitClass = nil
local set, which = Valuate:GetTemplateSet()
eq(which, "classic", "no UnitClass at all falls back to the classic set")
eq(set, ns.CLASS_SPEC_TEMPLATES, "and returns it")

UnitClass = function() return "Warrior" end
local _, warriorSet = Valuate:GetTemplateSet()
eq(warriorSet, "classic", "a classic class gets the classic set")

UnitClass = function() return "Necromancer" end
local coaSet, coaWhich = Valuate:GetTemplateSet()
eq(coaWhich, "coa", "a CoA class gets the CoA set")
eq(coaSet, ns.COA_CLASS_SPEC_TEMPLATES, "and it is the CoA table")

UnitClass = function() return "Somethingelse" end
local _, unknownWhich = Valuate:GetTemplateSet()
eq(unknownWhich, "classic",
    "an unrecognised class falls back to classic rather than guessing CoA")

UnitClass = function() return nil end
local _, nilWhich = Valuate:GetTemplateSet()
eq(nilWhich, "classic", "a nil class name falls back too")

-- ---- what the last screen CLAIMS happened ------------------------------------------------------
--
-- CommitAutoScale is gated separately and does the right thing. This is about the sentence you
-- read afterwards, and every one of its three outcomes makes a promise about your OTHER scales.
--
-- The dangerous one is the plain-creation text, which says in so many words that it never
-- overwrites a scale you already have. Printed on the branch that just deleted one, that is a
-- false reassurance about the user's own data - and the wizard has a near-miss in exactly this
-- area already: an earlier version offered to overwrite any scale it had made, so asking for a
-- Tank build would replace your DPS one.
local created = ns.WizardOutcomeText(nil)
local updated = ns.WizardOutcomeText("updated")
local reused  = ns.WizardOutcomeText("reused")

ok(created:find("never overwrites", 1, true) ~= nil,
   "a plain creation promises nothing was overwritten")
ok(updated:find("never overwrites", 1, true) == nil,
   "an UPDATE never makes that promise - it just replaced one")
ok(updated:find("untouched", 1, true) ~= nil,
   "but it does say the others are untouched, which is the part that IS true")
ok(reused:find("nothing new was made", 1, true) ~= nil,
   "a reuse says nothing new was made")
ok(reused:lower():find("created", 1, true) == nil,
   "and does not claim to have created anything")

-- All three differ. A mapping that collapsed two outcomes onto one sentence would pass several
-- of the checks above while telling you the wrong thing about one of them.
ok(created ~= updated and updated ~= reused and created ~= reused,
   "the three outcomes are three different sentences")

-- AN OUTCOME THIS FUNCTION HAS NOT BEEN TAUGHT ABOUT.
--
-- nil means creation because that is exactly what CommitAutoScale returns for one. Anything
-- else is an outcome added later, and it must not inherit a guarantee written before it
-- existed - which is how a wizard comes to promise it never overwrites while overwriting.
local unknown = ns.WizardOutcomeText("migrated")
ok(unknown:find("never overwrites", 1, true) == nil,
   "an unrecognised outcome does NOT inherit the never-overwrites promise")
ok(unknown:find("untouched", 1, true) == nil,
   "nor the claim that your other scales are untouched")
ok(unknown:find("primary scale", 1, true) ~= nil,
   "it still says the part that is true of every outcome")

-- It reaches a screen, so it must always be a string.
for _, why in ipairs({ "updated", "reused", "migrated", "" }) do
    ok(type(ns.WizardOutcomeText(why)) == "string", "outcome " .. why .. " produces text")
end
ok(type(ns.WizardOutcomeText(nil)) == "string", "and so does nil")

return failures, checks
`,
  "wizarduitest",
  "the wizard screens"
);
