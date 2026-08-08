#!/usr/bin/env node
/*
 * @gate The character-sheet score keeps updating after a blank
 *
 * Runs ui/CharacterWindow.lua for real and drives its refresh.
 *
 * UpdateCharacterWindowDisplay guards against re-entry with a flag set on entry and cleared
 * on exit, and it is tested on the function's FIRST line. Two branches blank the display -
 * "no scales at all" and "the selected scale is not in the table" - and they were written as
 * near-identical copies where only the first cleared the flag.
 *
 * So the second one did not produce a wrong number. It stopped the character-sheet score
 * updating at all, for the rest of the session, with no error and nothing on screen to say
 * why. A /reload was the only way out and nobody would know to try one.
 *
 * The check that matters is therefore not "does it blank correctly" but "does it still work
 * AFTERWARDS". Every case here blanks the display and then asks for a real update, because
 * a test that only inspects the blank state passes with the guard stuck.
 *
 * Usage:  node tools/charwindowtest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const core = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const defaults = core.match(/local DEFAULT_OPTIONS\s*=\s*\{[\s\S]*?\n\}/);
if (!defaults) {
  console.error("  SLICE  could not find `local DEFAULT_OPTIONS` in Valuate.lua");
  process.exit(1);
}

const run = load([
  "StatDefinitions.lua",
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/CharacterWindow.lua",
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

` + defaults[0] + `
local OPTIONS = DEFAULT_OPTIONS

-- The scales table and the ACTIVE list are separate sources, which is the whole point: the
-- second blanking branch is reached when the active list names a scale the table no longer
-- has. Keeping them independent here lets the test create exactly that.
local SCALES = { Melee = { DisplayName = "Melee", Color = "FF8040", Values = { Strength = 2 } } }
local ACTIVE = { "Melee" }

Valuate.GetOptions = function() return OPTIONS end
Valuate.GetScales = function() return SCALES end
Valuate.GetActiveScales = function() return ACTIVE end
Valuate.GetEquippedItemScoreBySlotId = function() return 5 end
Valuate.CalculateTotalEquippedScore = function() return 85 end
Valuate.ResetTooltips = function() end
Valuate.GetPrivateTooltip = function() return nil end

function GetInventoryItemLink() return nil end
function GetInventoryItemTexture() return nil end
function GetItemQualityColor() return 1, 1, 1 end
function GetItemInfo() return "Thing" end
GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:AddDoubleLine() end
function GameTooltip:ClearLines() end
function GameTooltip:Show() end
function GameTooltip:Hide() end
function GameTooltip:SetText() end

-- A stand-in character sheet. The addon looks for AscensionCharacterFrame first and falls
-- back to PaperDollFrame; either is fine, this gate is not about which.
PaperDollFrame = CreateFrame("Frame")
PaperDollFrame:Show()

Valuate:InitializeCharacterWindowUI()

-- The score FontString is the one the display writes. Found by driving a real update and
-- seeing which text changes, rather than by index into the frame list.
OPTIONS.characterWindowScale = "Melee"
Valuate:RefreshCharacterWindowDisplay()

local scoreText = nil
for _, f in ipairs(__frames) do
    if f.__type == "FontString" and f.__text and string.find(tostring(f.__text), "%d") then
        scoreText = f
    end
end
ok(scoreText ~= nil, "the character window shows a score")

local function currentScore() return scoreText and scoreText.__text end
local function refresh() Valuate:RefreshCharacterWindowDisplay() end

local live = currentScore()
ok(live ~= nil and live ~= "--", "a real score is on screen to begin with (" .. tostring(live) .. ")")

-- ---- branch 1: no scales at all -----------------------------------------------
-- This one always cleared the guard, so it is the control: whatever happens after branch 2
-- should also happen here.
SCALES = {}
ACTIVE = {}
refresh()
eq(currentScore(), "--", "with no scales the score blanks")

SCALES = { Melee = { DisplayName = "Melee", Color = "FF8040", Values = { Strength = 2 } } }
ACTIVE = { "Melee" }
OPTIONS.characterWindowScale = "Melee"
refresh()
ok(currentScore() ~= "--", "and it comes back when a scale exists again")

-- ---- branch 2: THE regression --------------------------------------------------
-- The active list names a scale the table does not have. The display blanks - correctly -
-- and then has to keep working. It did not: the guard stayed set and the first line of the
-- update function returned early from then on.
SCALES = {}
ACTIVE = { "Ghost" }
OPTIONS.characterWindowScale = nil
refresh()
eq(currentScore(), "--", "a scale that is active but missing blanks the score")

SCALES = { Melee = { DisplayName = "Melee", Color = "FF8040", Values = { Strength = 2 } } }
ACTIVE = { "Melee" }
OPTIONS.characterWindowScale = "Melee"
refresh()
ok(currentScore() ~= "--",
   "the score updates again afterwards - the re-entrancy guard was released")

-- Twice, because a guard released by luck rather than by design would show up on the second
-- pass through the same path.
SCALES = {}
ACTIVE = { "Ghost" }
OPTIONS.characterWindowScale = nil
refresh()
SCALES = { Melee = { DisplayName = "Melee", Color = "FF8040", Values = { Strength = 2 } } }
ACTIVE = { "Melee" }
OPTIONS.characterWindowScale = "Melee"
refresh()
ok(currentScore() ~= "--", "...and again after a second trip through that branch")

-- ---- the two branches agree -----------------------------------------------------
-- They are the same outcome written twice, which is how they came to differ. Whatever one
-- leaves behind, the other must too.
SCALES = {}
ACTIVE = {}
refresh()
local afterBranch1 = currentScore()
SCALES = {}
ACTIVE = { "Ghost" }
refresh()
eq(currentScore(), afterBranch1, "both blanking branches leave the same thing on screen")

SCALES = { Melee = { DisplayName = "Melee", Color = "FF8040", Values = { Strength = 2 } } }
ACTIVE = { "Melee" }
OPTIONS.characterWindowScale = "Melee"
refresh()
ok(currentScore() ~= "--", "and recovery works from either of them")

return failures, checks
`,
  "charwindowtest",
  "the character-sheet score"
);
