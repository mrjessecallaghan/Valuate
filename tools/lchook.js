#!/usr/bin/env node
/*
 * @gate The LootCollector hook filters without freezing, and cannot spin
 *
 * Runs the REAL Score.lua and Filter.lua from Valuate-LootCollector against a mocked
 * LootCollector, a mocked Valuate and a clock the test drives.
 *
 * tools/lctest.js covers the decision - which rows survive. This covers the half that can hurt
 * you. LootCollector's database runs to thousands of discoveries and each verdict costs a
 * tooltip build, so the shipped design budgets every pass and finishes the rest between
 * frames. Two things in that arrangement can hang a client, and both are guards whose absence
 * is invisible until it happens:
 *
 *   * a repaint that fires whether or not anything resolved. A repaint rebuilds the list, the
 *     list re-queues whatever is still unreadable, that queue drains to nothing new, and it
 *     asks for another repaint. Some items never become readable, so "keep going until the
 *     queue is empty" never ends.
 *   * an unbounded retry. The same shape one level down: an item the client has no data for
 *     goes back in the queue on every pass, for as long as the window is open.
 *
 * Neither is provable by reading, and neither appears in a small fixture - which is why the
 * clock here is a counter the test advances rather than a real timer, and why the retry
 * assertion runs the loop and counts passes rather than checking a flag.
 *
 * The other half is that when the filter is OFF, or the tab is not the equipment tab, or there
 * is no scale, this addon hands back EXACTLY what LootCollector produced. Identity, not
 * equality: their result table is reused and wiped on every rebuild, so a copy would be a copy
 * of something about to be emptied.
 *
 * NOTE: the source is in a SIBLING addon. This skips rather than fails when it is absent -
 * see tools/tsmratiotest.js for the argument.
 *
 * Usage:  node tools/lchook.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const DIR = path.resolve(ADDON_ROOT, "..", "Valuate-LootCollector");
if (!fs.existsSync(path.join(DIR, "Filter.lua"))) {
  console.log("SKIP  Valuate-LootCollector is not installed next to this addon; nothing to check.");
  process.exit(0);
}

const score = fs.readFileSync(path.join(DIR, "Score.lua"), "utf8");
const filter = fs.readFileSync(path.join(DIR, "Filter.lua"), "utf8");

const run = load([]);

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

-- Slash commands register into these two globals; the client has them, the harness does not.
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(__printed, msg) end }

GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner() end
function GameTooltip:SetText() end
function GameTooltip:AddLine() end
function GameTooltip:Show() end
function GameTooltip:Hide() end

-- A clock the test drives. A real timer would make every budget assertion below a race, and
-- what is being tested is exactly what happens when time runs out mid-pass.
local CLOCK, TICK = 0, 0
debugprofilestop = function()
    CLOCK = CLOCK + TICK
    return CLOCK
end

-- ---- the mocked LootCollector -----------------------------------------------------------
local ROWS = {}
local refreshes, invalidations = 0, 0

local Viewer = {
    currentFilter = "eq",
    currentPage = 3,
    duplicatesFilterBtn = CreateFrame("Button", nil, CreateFrame("Frame")),
}
function Viewer:GetFilteredDiscoveries() return ROWS end
function Viewer:RefreshData() refreshes = refreshes + 1 end
function Viewer:InvalidateFilterCache() invalidations = invalidations + 1 end
Viewer.window = CreateFrame("Frame")

local LCAddon = {}
function LCAddon:GetModule(name) return name == "Viewer" and Viewer or nil end

LibStub = function(major)
    if major == "AceAddon-3.0" then
        return { GetAddon = function() return LCAddon end }
    end
end

-- ---- the mocked Valuate ------------------------------------------------------------------
local WORLD = {}
local SCALE_NAME = "Dps"
local statCalls = 0

GetItemInfo = function(link)
    local e = WORLD[link]
    if not e or e.uncached then return nil end
    return "Item", nil, nil, nil, nil, nil, nil, nil, e.equipLoc or "INVTYPE_CHEST"
end

Valuate = {
    GetPrimaryScale = function()
        if not SCALE_NAME then return nil, nil end
        return { Values = { Agility = 1 } }, SCALE_NAME
    end,
    GetStatsForTooltipSetter = function(_, _, link)
        statCalls = statCalls + 1
        local e = WORLD[link]
        return e and e.stats or nil
    end,
    CalculateItemScore = function(_, stats) return (stats and stats.Agility) or 0 end,
    IsUpgradeForAnyScale = function(_, link) return (WORLD[link] and WORLD[link].upgrade) or false end,
}

-- ---- load the addon, with the mocks already standing ---------------------------------------
-- Both files, one shared ns, exactly as the client loads them from the .toc.
local compile = loadstring or load
local ns = {}
assert(compile(${JSON.stringify(score)}, "@Valuate-LootCollector/Score.lua"))("Valuate-LootCollector", ns)
assert(compile(${JSON.stringify(filter)}, "@Valuate-LootCollector/Filter.lua"))("Valuate-LootCollector", ns)

-- Two frames carry an OnUpdate: the hidden background driver and the visible watcher that
-- polls for LootCollector's window. Told apart by that, since neither is named.
local watcher, driver
for _, f in ipairs(__frames) do
    if f.__scripts and f.__scripts.OnUpdate then
        if f.__shown == false then driver = driver or f else watcher = watcher or f end
    end
end
ok(watcher ~= nil, "the addon polls for LootCollector's window rather than assuming it exists")
ok(driver ~= nil, "and keeps a background driver frame, hidden until there is work")

-- Driving the poll by hand is what half a second of play would do.
watcher.__scripts.OnUpdate(watcher, 1)
eq(ns.mode, "off", "the filter starts off, so installing the hook changes nothing by itself")

local function rowFor(link, mystic, vendor)
    return { discovery = { il = link }, isMystic = mystic or false, isVendor = vendor or false }
end

-- ---- OFF, and the two tabs this has no opinion about -------------------------------------
-- IDENTITY, not equality. Their result table is reused and wiped on every rebuild, so handing
-- back a copy would hand back a view of something about to be emptied.
WORLD["junk"] = { stats = { Agility = 0 } }
ROWS = { rowFor("junk") }
eq(Viewer:GetFilteredDiscoveries(), ROWS, "with the filter off, their own table comes straight back")

ns.mode = "upgrades"
Viewer.currentFilter = "ms"
eq(Viewer:GetFilteredDiscoveries(), ROWS, "the Mystic Scrolls tab is not a list of gear, and is untouched")
Viewer.currentFilter = "bmv"
eq(Viewer:GetFilteredDiscoveries(), ROWS, "nor is the vendor tab")
Viewer.currentFilter = "eq"

SCALE_NAME = nil
eq(Viewer:GetFilteredDiscoveries(), ROWS, "and with no active scale there is nothing to rank by")
SCALE_NAME = "Dps"

-- ---- filtering, with the budget wide open --------------------------------------------------
TICK = 0
WORLD["up"] = { stats = { Agility = 50 }, upgrade = true }
WORLD["meh"] = { stats = { Agility = 5 } }
WORLD["nothing"] = { stats = { Agility = 0 } }
WORLD["uncached"] = { uncached = true }

ROWS = { rowFor("up"), rowFor("meh"), rowFor("nothing"), rowFor("uncached") }
local out = Viewer:GetFilteredDiscoveries()
eq(#out, 2, "upgrades mode keeps the upgrade and the item it could not read")
eq(out[1].discovery.il, "up", "the upgrade is kept")
eq(out[2].discovery.il, "uncached", "and so is the one nobody could evaluate - never hidden")

ns.mode = "stats"
out = Viewer:GetFilteredDiscoveries()
eq(#out, 3, "my-stats mode also keeps what the scale merely values")

ns.mode = "upgrades"
ROWS = { rowFor("nothing", true), rowFor("nothing", false, true) }
eq(#Viewer:GetFilteredDiscoveries(), 2, "mystic and vendor rows pass through even in the gear tab")

-- ---- the budget: a pass stops, and what it did not reach STAYS -----------------------------
-- The freeze this whole design exists to prevent. With the clock jumping past the budget on
-- the first reading, almost nothing is evaluated - and every row must survive that.
local many = {}
for i = 1, 200 do
    local link = "bulk" .. i
    WORLD[link] = { stats = { Agility = 0 } }   -- worthless: would be DROPPED if evaluated
    many[i] = rowFor(link)
end
ROWS = many

statCalls = 0
TICK = 1000    -- a single reading of the clock blows the whole budget
out = Viewer:GetFilteredDiscoveries()
eq(#out, 200, "when the budget is gone before the first row, every row is kept")
ok(statCalls < 200,
   "and most were never evaluated (" .. tostring(statCalls) .. " tooltip reads for 200 rows)")
ok(ns.PendingCount() > 0, "the ones it skipped are queued rather than forgotten")

-- ---- the driver, and the guards that stop it spinning --------------------------------------
ok(driver:IsShown(), "the driver is shown once there is a queue to work through")

TICK = 0
refreshes = 0
driver.__scripts.OnUpdate(driver)
eq(ns.PendingCount(), 0, "the driver drains its queue")
eq(refreshes, 1, "and repaints ONCE at the end, not once per item")
ok(invalidations > 0, "invalidating their cache first, or it hands back the pre-filter rows")

TICK = 0
out = Viewer:GetFilteredDiscoveries()
eq(#out, 0, "with everything evaluated, the worthless rows are finally dropped")

-- THE INFINITE LOOP. Items the client will never answer for: a pass queues them, the driver
-- resolves nothing, and it must NOT ask for a repaint - a repaint rebuilds the list, re-queues
-- them, and asks again, forever.
local ghosts = {}
for i = 1, 5 do
    local link = "ghost" .. i
    WORLD[link] = { uncached = true }
    ghosts[i] = rowFor(link)
end
ROWS = ghosts

TICK = 0
refreshes = 0
out = Viewer:GetFilteredDiscoveries()
eq(#out, 5, "unreadable rows are all kept")
ok(ns.PendingCount() > 0, "and queued for another try")

driver.__scripts.OnUpdate(driver)
eq(refreshes, 0, "a driver pass that resolved NOTHING does not ask for a repaint")
ok(not driver:IsShown(), "and stands down instead of running again")

-- THE UNBOUNDED RETRY. Same shape one level down: keep asking, and the queue refills on every
-- pass for as long as the window is open. Run the real loop and count.
-- Measured AFTER the filter pass and BEFORE the driver, which is the only place the bound
-- shows. Checking it after the driver ran proves nothing: the driver drains the queue every
-- time, bound or no bound, so "the queue is empty now" was true either way - and this
-- assertion passed with MAX_ATTEMPTS deleted entirely.
local rounds, queuedByPass = 0, 0
repeat
    rounds = rounds + 1
    Viewer:GetFilteredDiscoveries()
    queuedByPass = ns.PendingCount()
    if queuedByPass > 0 then driver.__scripts.OnUpdate(driver) end
until queuedByPass == 0 or rounds > 20
ok(rounds <= 20,
   "an item the client never answers for stops being retried (" .. tostring(rounds) .. " rounds)")
eq(queuedByPass, 0, "and a later pass queues nothing at all, rather than refilling forever")
eq(refreshes, 0, "none of those rounds asked for a repaint")

-- Still SHOWN, though. Giving up on evaluating something is not the same as hiding it.
out = Viewer:GetFilteredDiscoveries()
eq(#out, 5, "a row it gave up on is still in the list")

-- ---- the memo, and what makes it stale --------------------------------------------------------
ROWS = { rowFor("up") }
TICK = 0
Viewer:GetFilteredDiscoveries()
statCalls = 0
Viewer:GetFilteredDiscoveries()
eq(statCalls, 0, "a second look at the same item is answered from the memo")

ns.ResetMemo()
statCalls = 0
Viewer:GetFilteredDiscoveries()
ok(statCalls > 0, "and forgetting the memo makes it look again")

-- Switching scale re-answers everything: the whole comparison is relative to one set of
-- weights, so a verdict from the other spec is not a verdict at all.
Viewer:GetFilteredDiscoveries()
SCALE_NAME = "Tank"
statCalls = 0
Viewer:GetFilteredDiscoveries()
ok(statCalls > 0, "changing the active scale re-evaluates rather than reusing the old answers")
SCALE_NAME = "Dps"

-- ---- the button ------------------------------------------------------------------------------
local button
for _, f in ipairs(__frames) do
    if f.label and f.label.GetText and f.label:GetText()
       and tostring(f.label:GetText()):find("Valuate:", 1, true) then
        button = f
    end
end
ok(button ~= nil, "a button is added to their filter row")

ns.SetMode("off")
eq(button.label:GetText(), "Valuate: Off", "which names the current mode")
button.__scripts.OnClick()
eq(ns.mode, "upgrades", "clicking it advances the cycle")
eq(button.label:GetText(), "Valuate: Upgrades", "and the label follows")
eq(Viewer.currentPage, 1,
   "changing the filter returns you to page one, not page three of a shorter list")

return failures, checks
`,
  "lchook",
  "the LootCollector hook"
);
