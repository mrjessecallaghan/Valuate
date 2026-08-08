#!/usr/bin/env node
/*
 * @gate The stat search dims what does not match, and only that
 *
 * Builds the real Scale Editor grid and drives its search box.
 *
 * The grid is around sixty stat rows across five columns, and it is POOLED - the same
 * frames are repopulated when you switch scales. That makes the filter two claims rather
 * than one: it dims the right rows, and it leaves everything else alone. The second is
 * where this could go wrong quietly, because the rows share their table with the containers,
 * column frames and section headers that lay the grid out - dimming one of those would fade a
 * whole column and look like a rendering fault rather than a filter.
 *
 * It is also why the filter writes ALPHA rather than text colour. ApplyWeightedLook already
 * owns the label colour and the input border, marking the stats that carry a weight, and a
 * second writer on one property is the fault this codebase keeps finding. The two must
 * compose: a weighted stat that matches your search still has to read as weighted.
 *
 * Usage:  node tools/statsearchtest.js
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
  "ui/Dialog.lua",
  "ui/Pickers.lua",
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

` + defaults[0] + `
local OPTIONS = DEFAULT_OPTIONS

local SCALES = {
    Melee = { DisplayName = "Melee", Color = "FFFFFF", Visible = true,
              Values = { Strength = 2.5 } },
    Caster = { DisplayName = "Caster", Color = "FFFFFF", Visible = true,
               Values = { Intellect = 3 } },
}
Valuate.GetOptions = function() return OPTIONS end
Valuate.GetScales = function() return SCALES end
Valuate.GetPrimaryScale = function() return SCALES.Melee, "Melee" end
Valuate.GetActiveScales = function() return { "Melee" } end
Valuate.ResetTooltips = function() end
Valuate.ScanBestEquipment = function() end
Valuate.IsWeaponSetEnabled = function() return true end
Valuate.GetWeaponSetDefinitions = function()
    return {
        { key = "TwoHand", label = "Two-Hander", short = "2H" },
        { key = "OneHandShield", label = "1H + Shield", short = "1H+Sh" },
    }
end
Valuate.RefreshBestEquipmentDisplay = function() end
Valuate.ShowConfirmDialog = function() end
GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end
ColorPickerFrame = CreateFrame("Frame")
function ColorPickerFrame:GetColorRGB() return 0, 0, 0 end
function ColorPickerFrame:SetColorRGB() end

local parent = CreateFrame("Frame")
local built, err = pcall(ns.CreateScaleEditor, parent)
if not built then return { "the scale editor failed to build: " .. tostring(err) }, 1 end

ns.EditingScaleName = "Melee"
ns.CurrentSelectedScale = "Melee"
local populated, perr = pcall(ValuateUI_UpdateScaleEditor, "Melee", SCALES.Melee)
if not populated then return { "populating the editor failed: " .. tostring(perr) }, 1 end

-- By NAME. The obvious finder - "the EditBox with an OnTextChanged handler" - picks a stat
-- weight box instead: every one of them has that handler for input validation, and there
-- are sixty. The first version of this gate did exactly that and spent its assertions
-- typing into the last stat row in the grid.
local box = nil
for _, f in ipairs(__frames) do
    if f.__name == "ValuateStatSearchBox" then box = f end
end
ok(box ~= nil, "found the stat search box")

-- Every row in the grid, and separately the things that are NOT rows.
local rows, nonRows = {}, {}
for _, f in ipairs(__frames) do
    if f.populate and f.statName then
        rows[#rows + 1] = f
    elseif f.__type == "Frame" and f.__height and f.__height > 0 then
        nonRows[#nonRows + 1] = f
    end
end
ok(#rows > 30, "the grid built a realistic number of stat rows (got " .. #rows .. ")")

local function search(text)
    box:SetText(text)
    box.__scripts.OnTextChanged(box)
end

local function alphaOf(name)
    for _, r in ipairs(rows) do
        if r.statName == name then return r:GetAlpha() end
    end
    return nil
end

local function dimCount()
    local n = 0
    for _, r in ipairs(rows) do if r:GetAlpha() < 1 then n = n + 1 end end
    return n
end

-- ---- nothing typed means nothing dimmed ---------------------------------------
eq(dimCount(), 0, "with an empty box every stat is at full alpha")

-- ---- a real search ------------------------------------------------------------
search("strength")
eq(alphaOf("Strength"), 1, "the stat you searched for stays bright")
ok(dimCount() > 0, "and the ones that do not match are dimmed")
ok(dimCount() < #rows, "...but not all of them")

-- Case does not matter, in either direction.
search("STRENGTH")
eq(alphaOf("Strength"), 1, "the search is case-insensitive")

-- ---- the internal name works too ----------------------------------------------
-- Someone who knows the data should not have to guess the label.
local rawName = nil
for _, r in ipairs(rows) do
    if r.statName ~= (ValuateStatNames[r.statName] or r.statName) then rawName = r.statName break end
end
if rawName then
    search(strlower(rawName))
    eq(alphaOf(rawName), 1, "searching the internal name finds the stat (" .. rawName .. ")")
end

-- ---- clearing restores everything ---------------------------------------------
search("")
eq(dimCount(), 0, "clearing the box brings every stat back")

-- ---- a query matching nothing --------------------------------------------------
search("zzzznotastat")
eq(dimCount(), #rows, "a query matching nothing dims every stat")
search("")

-- ---- the filter touches ONLY the stat rows -------------------------------------
-- Containers, column frames and section headers live in the same table as the rows. Dimming
-- one would fade a whole column and read as a rendering fault rather than a filter.
local nonRowAlphas = {}
for i, f in ipairs(nonRows) do nonRowAlphas[i] = f:GetAlpha() end
search("agility")
local changed = 0
for i, f in ipairs(nonRows) do
    if f:GetAlpha() ~= nonRowAlphas[i] then changed = changed + 1 end
end
eq(changed, 0, "no container, column or header had its alpha touched")
search("")

-- ---- the dim survives switching scales -----------------------------------------
-- The rows are pooled and populate never touches alpha, so a filter has to still be in
-- force after a repopulate - otherwise the box says one thing and the grid shows another.
search("stamina")
local dimmedBefore = dimCount()
ns.EditingScaleName = "Caster"
ValuateUI_UpdateScaleEditor("Caster", SCALES.Caster)
eq(dimCount(), dimmedBefore, "switching scales keeps the filter in force")
eq(alphaOf("Stamina"), 1, "...with the searched stat still bright")
search("")

-- ---- and it composes with the weighted look ------------------------------------
-- ApplyWeightedLook owns the label colour; the filter owns alpha. A weighted stat that
-- matches must still read as weighted, which is only true if they are different properties.
ns.EditingScaleName = "Melee"
ValuateUI_UpdateScaleEditor("Melee", SCALES.Melee)
local strengthRow = nil
for _, r in ipairs(rows) do if r.statName == "Strength" then strengthRow = r end end
ok(strengthRow ~= nil, "found the Strength row")
local weightedColour = strengthRow.label.__textColor
search("strength")
eq(strengthRow.label.__textColor, weightedColour, "searching does not repaint the label colour")
eq(strengthRow:GetAlpha(), 1, "...and the matching row is fully opaque")
search("")

return failures, checks
`,
  "statsearchtest",
  "the stat search"
);
