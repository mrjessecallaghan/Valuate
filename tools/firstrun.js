#!/usr/bin/env node
/*
 * @gate An empty screen says which empty it is, and points at something that exists
 *
 * Builds the real Best Equipment panel and reads what it puts on screen when there is
 * nothing to show.
 *
 * Best Equipment had ONE message for two different situations:
 *
 *   "No active scales. Activate scales in the Scales tab to see best equipment."
 *
 * That is correct when you have scales and none are switched on. It is wrong for someone who
 * has never made one - which is everybody, once - because it sends them looking for a switch
 * that is not there. The most common reason this panel is empty is the one case its only
 * message did not describe.
 *
 * An empty screen is the first screen a new user reaches, and the only thing it has to do is
 * name the next action correctly. Getting that wrong is not a cosmetic failure: the panel
 * looks broken, and the fix it suggests cannot be carried out.
 *
 * This gate is about the DISTINCTION, not the wording. It checks that the two states produce
 * different text and that each points at something the user can actually do from where they
 * are standing - so a future rewrite is free to change the phrasing and not free to collapse
 * them back into one.
 *
 * Usage:  node tools/firstrun.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/BestEquipment.lua",
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

local SCALES, ACTIVE = {}, {}
Valuate.GetScales = function() return SCALES end
Valuate.GetActiveScales = function() return ACTIVE end
Valuate.GetBestEquipment = function() return {} end
Valuate.GetOptions = function() return { decimalPlaces = 1 } end
-- Only the empty states are this gate's subject; the populated path is bestequiptest.js.
Valuate.GetPrimaryScale = function() return nil, nil end
Valuate.CalculateTotalEquippedScore = function() return 0 end
Valuate.GetEquippedItemScoreBySlotId = function() return 0 end
Valuate.ScanBestEquipment = function() end

-- The panel skips its whole rebuild while the window is hidden, so it has to look open.
local uiFrame = CreateFrame("Frame")
uiFrame.__shown = true
ns.ValuateUIFrame = uiFrame

local parent = CreateFrame("Frame")
parent.__shown = true
local built, err = pcall(ns.CreateBestEquipmentPanel, parent)
ok(built, "the Best Equipment panel builds" .. (built and "" or (": " .. tostring(err))))

-- Everything the panel has drawn, so the assertions are about what a user can READ rather
-- than about which font string happens to hold it.
local function onScreen()
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

local function refresh()
    if Valuate.RefreshBestEquipmentDisplay then Valuate:RefreshBestEquipmentDisplay() end
end

-- ---- nobody has made a scale yet ------------------------------------------------
-- The first-run case. Whatever this says, it must not be the "go and activate one" message.
SCALES, ACTIVE = {}, {}
refresh()
local firstRun = onScreen()
ok(firstRun ~= "", "with no scales at all, the panel says something rather than sitting blank")
ok(firstRun:find("Make me a scale", 1, true) ~= nil,
   "and names the button that actually exists - the one that BUILDS a scale")

-- ---- scales exist, none switched on ---------------------------------------------
SCALES = { ["Tank"] = { DisplayName = "Tank", Values = { Stamina = 1 } } }
ACTIVE = {}
refresh()
local noneActive = onScreen()
ok(noneActive ~= "", "with scales but none active, the panel says something")
ok(noneActive:find("active", 1, true) ~= nil,
   "and this is the case where 'active' is the right word, because there is something to activate")

-- ---- the distinction is the point -----------------------------------------------
-- One message for both is how this shipped, and it was wrong in the more common half.
ok(firstRun ~= noneActive,
   "the two empty states say DIFFERENT things - collapsing them is the bug this gate exists for")

-- Specifically: the first-run screen must not send someone hunting for a switch that is not
-- there. This is the exact failure, spelled out, so a rewrite cannot reintroduce it quietly.
eq(firstRun:find("Activate scales in the Scales tab", 1, true), nil,
   "the first-run screen does not tell you to activate a scale you have never made")

-- ---- and it goes away when there is something to show ---------------------------
ACTIVE = { { name = "Tank", scale = SCALES["Tank"] } }
refresh()
local withScales = onScreen()
eq(withScales:find("Make me a scale", 1, true), nil,
   "once a scale is active the first-run prompt is gone, not left sitting under the rows")
eq(withScales:find("none are switched on", 1, true), nil,
   "and so is the not-activated one")

return failures, checks
`,
  "firstrun",
  "the empty Best Equipment screen names the right next action"
);
