#!/usr/bin/env node
/*
 * @gate The upgrade popup never dismisses itself on a click that cannot work
 *
 * Builds the real popup and drives its buttons.
 *
 * 285 lines that interrupt you and then change your gear, and until now no gate ran a line of
 * it - it was only ever LOADED, by tabtest.js, so that the window would build. That is the
 * same blind spot ui/Settings.lua sat in before settingstest.js was written and immediately
 * turned up a keyboard capture that never let go.
 *
 * What it found here: the popup has two ways to equip, and they did not behave alike.
 *
 *   THE ICON equips just that item. It checked InCombatLockdown first, said so, and left the
 *   popup up so you could click again afterwards.
 *
 *   THE EQUIP BUTTON takes the whole set. It hid the popup and THEN called through to
 *   EquipBestSet, which refuses in combat and prints the same line. So the message was never
 *   missing - the popup was. A click that could not possibly succeed took the upgrade off
 *   your screen and left you to remember what it was.
 *
 * The more prominent control had the worse behaviour, which is the shape worth pinning: it is
 * not a missing check, it is two paths to one outcome that disagree about the order.
 *
 * Usage:  node tools/popuptest.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/UpgradePopup.lua",
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
Valuate.GetOptions = function() return {} end

local IN_COMBAT = false
function InCombatLockdown() return IN_COMBAT end

local equippedByName = {}
function EquipItemByName(link, slot) equippedByName[#equippedByName + 1] = { link, slot } end
local intents = 0
Valuate.MarkEquipIntent = function() intents = intents + 1 end

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end
function GameTooltip:Show() end
function GameTooltip:Hide() end
function GameTooltip:SetHyperlink() end

local onEquipCalls = 0
local function showPopup(count)
    return Valuate:ShowUpgradePopup({
        count = count or 1,
        itemLink = "|Hitem:123|h[Test Item]|h",
        itemName = "Test Item",
        itemIcon = "icon",
        itemSlotId = 5,
        delta = 12.5,
        onEquip = function() onEquipCalls = onEquipCalls + 1 end,
    })
end

local hidden = 0
local realHide = Valuate.HideUpgradePopup
Valuate.HideUpgradePopup = function(self)
    hidden = hidden + 1
    if realHide then return realHide(self) end
end

-- ---- it builds and equips out of combat ------------------------------------------
local f = showPopup(1)
ok(f ~= nil, "the popup builds")
ok(f.equipButton ~= nil, "and has an Equip button")

IN_COMBAT = false
hidden, onEquipCalls = 0, 0
f.equipButton:GetScript("OnClick")(f.equipButton)
eq(onEquipCalls, 1, "out of combat, Equip does the thing")
eq(hidden, 1, "and closes the popup, because it worked")

-- ---- and refuses IN combat without throwing your upgrade away --------------------
-- The bug. EquipBestSet would have refused anyway; what it could not do is put the popup
-- back, because it had already been hidden.
IN_COMBAT = true
hidden, onEquipCalls = 0, 0
f.equipButton:GetScript("OnClick")(f.equipButton)
eq(onEquipCalls, 0, "in combat, Equip does not try")
eq(hidden, 0, "and the popup STAYS UP - a click that cannot work must not cost you the upgrade")

-- Still usable once combat ends, which is the point of not having dismissed it.
IN_COMBAT = false
f.equipButton:GetScript("OnClick")(f.equipButton)
eq(onEquipCalls, 1, "and the same button works the moment combat ends")

-- ---- the icon path, which was right all along ------------------------------------
-- Kept under test so the two cannot drift apart again in the other direction.
local iconButton
for _, frame in ipairs(__frames) do
    local handler = frame.GetScript and frame:GetScript("OnClick")
    if handler and frame ~= f.equipButton and frame.__type == "Button" then
        iconButton = iconButton or frame
    end
end
ok(iconButton ~= nil, "the icon is clickable too")

IN_COMBAT = true
local before = #equippedByName
for _, frame in ipairs(__frames) do
    local handler = frame.GetScript and frame:GetScript("OnClick")
    if handler and frame.__type == "Button" then pcall(handler, frame) end
end
eq(#equippedByName, before, "no click on this popup equips anything while in combat")

return failures, checks
`,
  "popuptest",
  "the upgrade popup's two equip paths agree"
);
