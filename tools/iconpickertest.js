#!/usr/bin/env node
/*
 * @gate The icon picker hands back the icon under the button you clicked
 *
 * Runs ui/Pickers.lua for real and drives the icon grid.
 *
 * The grid is virtual: a small pool of buttons is repositioned and re-textured as you
 * scroll 577 icons past it. Adding a search means the pool now draws from a list that
 * CHANGES, which is the stale-identity hazard this project has hit three times already -
 * and here it means clicking a sword and getting whatever icon used to be in that position.
 *
 * So the assertions are all of the form "what a button carries matches what it shows",
 * checked after scrolling and after filtering, rather than "the filter returned N results".
 *
 * Usage:  node tools/iconpickertest.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Dialog.lua",
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

Valuate.GetOptions = function() return { reduceMotion = false } end
GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:ClearLines() end
function GameTooltip:Show() end
function GameTooltip:Hide() end

local picked = nil
ns.ShowIconPicker(function(path) picked = path end)

local frame, box = nil, nil
for _, f in ipairs(__frames) do
    if f.__name == "ValuateIconPickerFrame" then frame = f end
    if f.__name == "ValuateIconSearchBox" then box = f end
end
ok(frame ~= nil, "the icon picker frame exists")
ok(box ~= nil, "the search box exists")

-- The scroll frame drives the grid; its OnShow does the initial layout.
local scrollFrame = nil
for _, f in ipairs(__frames) do
    if f.__type == "ScrollFrame" and f.__scripts and f.__scripts.OnShow then scrollFrame = f end
end
ok(scrollFrame ~= nil, "found the scrolling grid")
scrollFrame.__scripts.OnShow(scrollFrame)

-- The icon buttons are the ones carrying an iconPath after a layout.
local function shownButtons()
    local list = {}
    for _, f in ipairs(__frames) do
        if f.__type == "Button" and f.iconPath ~= nil and f:IsShown() then
            list[#list + 1] = f
        end
    end
    return list
end

local function search(text)
    box:SetText(text)
    box.__scripts.OnTextChanged(box)
end

ok(#shownButtons() > 0, "icons are laid out when the picker opens")

-- ---- what a button CARRIES is what it SHOWS -----------------------------------
-- The click handler passes self.iconPath; the texture is what you looked at. If those two
-- ever disagree you get an icon you did not choose, and nothing errors.
local function everyButtonAgrees(where)
    local bad = 0
    for _, b in ipairs(shownButtons()) do
        local expected = b.iconPath
        if expected == "" then
            -- The "no icon" entry deliberately draws a different texture.
            expected = "Interface\\\\Buttons\\\\UI-GroupLoot-Pass-Up"
        end
        if b.tex.__texture ~= expected then bad = bad + 1 end
    end
    eq(bad, 0, "every visible button shows the icon it carries (" .. where .. ")")
end

everyButtonAgrees("unfiltered")

-- ---- searching ------------------------------------------------------------------
search("sword")
local swordButtons = shownButtons()
ok(#swordButtons > 0, "searching for sword finds something")
local allMatch = true
for _, b in ipairs(swordButtons) do
    if not string.find(strlower(b.iconPath), "sword", 1, true) then allMatch = false end
end
ok(allMatch, "every icon shown after a search actually matches it")
everyButtonAgrees("filtered")

-- Clicking hands back what the button carries, and that is a matching icon.
local target = swordButtons[1]
picked = nil
target.__scripts.OnClick(target)
eq(picked, target.iconPath, "clicking returns the icon that button was carrying")
ok(string.find(strlower(tostring(picked)), "sword", 1, true) ~= nil,
   "...and it is one of the search results, not a leftover from before")

-- ---- reopening starts unfiltered -------------------------------------------------
-- A modal picker reopened with someone else's search still active would look like a picker
-- that had lost most of its icons.
ns.ShowIconPicker(function() end)
scrollFrame.__scripts.OnShow(scrollFrame)
eq(box:GetText(), "", "reopening clears the search box")
local afterReopen = #shownButtons()
search("sword")
local filtered = #shownButtons()
search("")
eq(#shownButtons(), afterReopen, "clearing the search restores the full grid")
ok(filtered < afterReopen or filtered == afterReopen,
   "a filtered grid is never larger than the unfiltered one")

-- ---- a search matching nothing ----------------------------------------------------
search("zzzznotanicon")
eq(#shownButtons(), 0, "a search matching nothing shows no icons")
-- ...and it must be recoverable, which is the half that would break silently.
search("")
eq(#shownButtons(), afterReopen, "and typing something else brings them all back")

-- ---- the scrollbar range follows the filter ----------------------------------------
-- Filtering shortens the list, so the scroll range has to shrink with it. Left at the
-- unfiltered length, a four-icon result can be scrolled past the end of itself into blank
-- space - and the grid looks empty while the search says it matched.
local scrollbar = nil
for _, f in ipairs(__frames) do
    if f.__type == "Slider" and f.__scripts and f.__scripts.OnValueChanged then scrollbar = f end
end
ok(scrollbar ~= nil, "found the scrollbar")

search("")
local _, fullMax = scrollbar:GetMinMaxValues()
search("sword")
local _, filteredMax = scrollbar:GetMinMaxValues()
ok(filteredMax < fullMax, "a filtered list has a shorter scroll range (" ..
   tostring(filteredMax) .. " vs " .. tostring(fullMax) .. ")")

-- And scrolling to the end of a filtered list still shows icons rather than empty space.
scrollbar.__scripts.OnValueChanged(scrollbar, filteredMax)
ok(#shownButtons() > 0, "scrolled to the end of a filtered list, icons are still on screen")
search("")

-- ---- scrolling keeps identity ------------------------------------------------------
-- The pool is repositioned and re-textured as you scroll. This is the original hazard,
-- independent of the search.
if scrollbar then
    local firstBefore = shownButtons()[1].iconPath
    scrollbar.__scripts.OnValueChanged(scrollbar, 200)
    everyButtonAgrees("scrolled")
    ok(shownButtons()[1].iconPath ~= firstBefore, "scrolling actually moved the grid")
end

return failures, checks
`,
  "iconpickertest",
  "the icon picker"
);
