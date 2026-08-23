#!/usr/bin/env node
/*
 * @gate The To Do tab renders the real list, and reuses its rows without mixing them up
 *
 * Builds ui/TodoPanel.lua against a mocked WoW API and a mocked BuildTodoList.
 *
 * tools/todotest.js already owns the hard question - WHAT belongs on the list and in what
 * order - by running the real Valuate:BuildTodoList. This gate deliberately does not repeat
 * any of that. It asks the questions that only exist once the answer is on screen:
 *
 *   - is every item shown, and in the order it was given;
 *   - does an empty list SAY it is empty, rather than showing a blank panel that reads as
 *     one which failed to load;
 *   - are rows reused rather than recreated (WoW frames cannot be destroyed, so a rebuild
 *     per visit leaks one row per item for the whole session);
 *   - and, because they are reused, does each row still run ITS OWN command after the list
 *     underneath it has changed.
 *
 * That last one is the reason this file exists. A handler closing over an item from an
 * earlier refresh keeps working, keeps looking right, and quietly runs the wrong command.
 *
 * Usage:  node tools/todopanel.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/TodoPanel.lua",
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

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:AddLine() end
function GameTooltip:Hide() end
function GameTooltip:Show() end

-- What the slash handler was asked to do, so a click can be checked rather than assumed.
__ran = {}
SlashCmdList = { VALUATE = function(arg) table.insert(__ran, arg) end }

local ITEMS = {}
-- ONE definition, returning BOTH values from the start.
--
-- This began as a one-value mock, and when the second return was added a THIRD-release-later
-- block simply defined the function again further down. Two mocks for one function in one
-- file, with every assertion above the second one still running against the thin copy - the
-- same duplication that had already cost a bug in todotest.js and another in Valuate.lua.
local UNREAD = nil
Valuate.BuildTodoList = function() return ITEMS, UNREAD end

local host = CreateFrame("Frame")
host:SetWidth(600)
host:SetHeight(400)

-- ---- an empty list is an ANSWER ---------------------------------------------------------
-- BuildTodoList returns {} rather than a heading with nothing under it, on purpose: a
-- to-do list that always has entries is one you stop opening. The panel has to say so out
-- loud, or "nothing to do" and "this panel failed to load" look identical.
local panel = ns.CreateTodoPanel(host)
ok(panel ~= nil, "the panel builds")
ok(type(ns.RefreshTodoPanel) == "function", "and publishes a way to refresh it")

local function visibleRows()
    local n = 0
    for _, f in ipairs(__frames) do
        if f.__todoRow and f:IsShown() then n = n + 1 end
    end
    return n
end

local function emptyText()
    for _, f in ipairs(__frames) do
        for _, r in ipairs(f.__regions or {}) do
            if r.GetText and r:GetText() and r:GetText():find("Nothing outstanding", 1, true)
               and r:IsShown() then
                return r:GetText()
            end
        end
    end
    return nil
end

eq(ns.RefreshTodoPanel(), 0, "with nothing to do the list is empty")
ok(emptyText() ~= nil, "and the panel says so, rather than showing a blank")

-- ---- items render in the order they were given -------------------------------------------
ITEMS = {
    { kind = "scale", text = "Refresh Fury - your gear has moved on",
      detail = "Everything below is scored by this scale.", command = "/valuate wizard" },
    { kind = "upgrade", text = "Equip Bonecrusher in Main Hand", command = "/valuate upgrades" },
    { kind = "sockets", text = "Fill 2 empty sockets",
      detail = "Stats you have already earned.", command = "/valuate sockets" },
}
eq(ns.RefreshTodoPanel(), 3, "three things to do gives three rows")
ok(emptyText() == nil, "and the empty message is out of the way")

-- ---- a row with no detail does not leave the last one showing ----------------------------
-- The rows are reused. An item without a detail line landing on a row that had one would
-- keep the previous item's explanation underneath its own text.
local rows = {}
for _, f in ipairs(__frames) do
    if f.__todoRow then rows[#rows + 1] = f end
end
eq(#rows, 3, "exactly three rows were created")
ok(rows[2].detail and not rows[2].detail:IsShown(),
   "an item with no detail hides the detail line rather than inheriting one")
ok(rows[1].detail:IsShown(), "and an item with one shows it")

-- ---- rows grow to fit what is in them -----------------------------------------------------
-- These details are sentences, not labels. The one BuildTodoList writes for a guessed scale
-- runs to two hundred characters and wraps to three lines at this width, and a fixed-height
-- row put the second and third of them outside their own backdrop, over whatever came next.
ITEMS = {
    { kind = "upgrade", text = "Short", command = "/valuate upgrades" },
    { kind = "guess", text = "The weights in Fury are a guess",
      detail = "No stat priority was ever published for that spec, so they were read off its " ..
               "description. Everything below is ranked by them. Edit them as you learn what " ..
               "actually works for you.",
      command = "/valuate scales" },
}
ns.RefreshTodoPanel()
local sized = {}
for _, f in ipairs(__frames) do
    if f.__todoRow and f:IsShown() then sized[#sized + 1] = f end
end
eq(#sized, 2, "two items, two rows")
ok(sized[2]:GetHeight() > sized[1]:GetHeight(),
   "the row with a wrapping paragraph is taller than the one with a single line (" ..
   tostring(sized[1]:GetHeight()) .. " vs " .. tostring(sized[2]:GetHeight()) .. ")")


-- The list frame has to account for it too, or the rows below run off the panel.
local listFrame
for _, f in ipairs(__frames) do
    if f.__todoRow then listFrame = listFrame or f:GetParent() end
end
ok(listFrame and listFrame:GetHeight() >= sized[1]:GetHeight() + sized[2]:GetHeight(),
   "the list is at least as tall as the rows it holds")


-- ---- clicking a row runs THAT row's command ----------------------------------------------
ITEMS = {
    { kind = "scale", text = "Refresh Fury - your gear has moved on",
      detail = "Everything below is scored by this scale.", command = "/valuate wizard" },
    { kind = "upgrade", text = "Equip Bonecrusher in Main Hand", command = "/valuate upgrades" },
    { kind = "sockets", text = "Fill 2 empty sockets",
      detail = "Stats you have already earned.", command = "/valuate sockets" },
}
ns.RefreshTodoPanel()
__ran = {}
rows[1].go.__scripts.OnClick(rows[1].go)
eq(#__ran, 1, "clicking a row runs one command")
eq(__ran[1], "wizard", "and it is that row's own, with the slash prefix stripped")

__ran = {}
rows[3].go.__scripts.OnClick(rows[3].go)
eq(__ran[1], "sockets", "each row runs its own")

-- ---- THE regression the pooling makes possible -------------------------------------------
-- Same frames, different items. A handler that closed over the item from the previous
-- refresh still fires, still looks right, and runs the wrong command entirely.
ITEMS = {
    { kind = "enchants", text = "Enchant 4 items", command = "/valuate enchants" },
}
eq(ns.RefreshTodoPanel(), 1, "the list shrinks to one")
eq(visibleRows(), 1, "and the rows that are no longer needed are hidden, not left on screen")

__ran = {}
rows[1].go.__scripts.OnClick(rows[1].go)
eq(__ran[1], "enchants",
   "the reused row runs the NEW item's command, not the one it was built with")

-- ---- reuse, not recreation ----------------------------------------------------------------
local before = #__frames
ITEMS = {
    { kind = "upgrade", text = "a", command = "/valuate upgrades" },
    { kind = "upgrade", text = "b", command = "/valuate upgrades" },
    { kind = "upgrade", text = "c", command = "/valuate upgrades" },
}
ns.RefreshTodoPanel()
ns.RefreshTodoPanel()
ns.RefreshTodoPanel()
eq(#__frames, before, "refreshing an already-built list creates no new frames")

-- ...and creates no new HANDLERS either, which is the subtler half.
--
-- Anything installed inside the refresh is installed again on every visit to the tab.
-- SetScript merely replaces, so it looks fine; HookScript CHAINS, and the row quietly
-- collects one more tooltip handler per refresh for the rest of the session. Nothing about
-- it is visible - every copy draws the same tooltip - which is exactly why it needs asking.
local tipCalls = 0
local realAdd = GameTooltip.AddLine
GameTooltip.AddLine = function(self, ...) tipCalls = tipCalls + 1 return realAdd(self, ...) end
local probe
for _, f in ipairs(__frames) do
    if f.__todoRow and f:IsShown() then probe = probe or f end
end
if probe then
    probe.go.__scripts.OnEnter(probe.go)
    local once = tipCalls
    for _ = 1, 5 do ns.RefreshTodoPanel() end
    tipCalls = 0
    probe.go.__scripts.OnEnter(probe.go)
    eq(tipCalls, once, "hovering after five refreshes draws the tooltip once, not six times")
end
GameTooltip.AddLine = realAdd

-- ---- an unfamiliar kind is still readable --------------------------------------------------
-- The accent is keyed on the kind BuildTodoList sets. A kind added there and not here must
-- fall back to neutral rather than erroring: an entry nobody colour-coded yet is still an
-- entry you need to be able to read.
ITEMS = { { kind = "somethingNew", text = "a new sort of thing", command = "/valuate report" } }
local fine = pcall(ns.RefreshTodoPanel)
ok(fine, "a kind this panel has never heard of does not break the list")
eq(visibleRows(), 1, "and is still shown")

-- ---- what the list did NOT read, drawn on the panel -----------------------------------------------
--
-- This seam was unexercised. The mock returned ONE value, so unread was always nil, the
-- confident sentence was always the one chosen, and the coverage note added in v0.203.0a had
-- never been rendered by any gate at all.
--
-- The formatters are gated in tools/todounread.js and BuildTodoList's second return is gated in
-- tools/todotest.js. Neither proves the panel joins them up - which is the same shape as the
-- v0.210.0a bug: every part tested, and the path between them not.
--
-- Note the mock now returns TWO values. Lua adjusts an and expression to one, and the panel's
-- own call site carries a comment about exactly that; a fixture that returns one value can
-- never catch it.

-- Every visible string on the panel.
local function panelText()
    local out = {}
    for _, f in ipairs(__frames) do
        if f.IsShown and f:IsShown() and f.GetRegions then
            for _, r in ipairs({ f:GetRegions() }) do
                if r and r.GetText and r:GetText() and r.IsShown and r:IsShown() then
                    out[#out + 1] = r:GetText()
                end
            end
        end
    end
    return table.concat(out, " | ")
end

-- An empty list with nothing unread: the confident sentence, unchanged.
ITEMS, UNREAD = {}, nil
ns.RefreshTodoPanel()
local said = panelText()
ok(said:find("all up to date", 1, true) ~= nil,
   "nothing to do and nothing unread still says your gear is up to date")

-- THE ONE THAT MATTERS. An empty list is read as "you are done", and a source that failed on
-- this refresh means the panel cannot honestly say that.
ITEMS, UNREAD = {}, { "empty sockets (an item is still being swapped)" }
ns.RefreshTodoPanel()
said = panelText()
eq(said:find("all up to date", 1, true), nil,
   "with a source unread, the blanket claim is GONE from the panel - not merely softened")
ok(said:find("sockets", 1, true) ~= nil, "and what was missed is named on screen")

-- Said on a NON-empty refresh too. A list of jobs is just as much a claim about partial
-- coverage as a clean bill is, and the more dangerous of the two to over-read.
ITEMS = { { kind = "scan", text = "Scan your gear", command = "/valuate scan" } }
UNREAD = { "2 worn slots still loading" }
ns.RefreshTodoPanel()
said = panelText()
ok(said:find("Not read this refresh", 1, true) ~= nil,
   "a list with rows on it STILL says what went unread")
ok(said:find("still loading", 1, true) ~= nil, "naming the source")

-- And it withdraws. A note that never clears is one you stop reading.
UNREAD = nil
ns.RefreshTodoPanel()
said = panelText()
eq(said:find("Not read this refresh", 1, true), nil,
   "a clean refresh withdraws the note rather than leaving it up")
ITEMS = {}

return failures, checks
`,
  "todopanel",
  "the To Do tab"
);
