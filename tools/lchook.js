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
if (!fs.existsSync(path.join(DIR, "Filter.lua")) || !fs.existsSync(path.join(DIR, "Plausible.lua"))) {
  console.log("SKIP  Valuate-LootCollector is not installed next to this addon; nothing to check.");
  process.exit(0);
}

const score = fs.readFileSync(path.join(DIR, "Score.lua"), "utf8");
/* Loaded in the order the .toc names them, because Filter.lua calls into Plausible.lua.
 * Reading only the two this gate used to know about is how it first failed: the sanity
 * filter went in, the .toc gained a file, and the fixture was still building a half-addon. */
const plausible = fs.readFileSync(path.join(DIR, "Plausible.lua"), "utf8");
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

-- The one predicate behind both the map pin layer and the arrow that points at the nearest
-- find. Counted, so the assertions can tell a hook that wraps it from one that replaces it.
local passCalls = 0
local PASS_ANSWER = true
function LCAddon:DiscoveryPassesFilters(d)
    passCalls = passCalls + 1
    return PASS_ANSWER
end

LibStub = function(major)
    if major == "AceAddon-3.0" then
        return { GetAddon = function() return LCAddon end }
    end
end

-- ---- the mocked Valuate ------------------------------------------------------------------
local WORLD = {}
local SCALE_NAME = "Dps"
local statCalls = 0

-- Positions 4 and 5 are item level and required level. They were nil here until the sanity
-- filter needed them, which is the shape of mock gap this whole toolchain keeps finding: the
-- code under test read a real return, the fixture answered nil, and nothing failed.
GetItemInfo = function(link)
    local e = WORLD[link]
    if not e or e.uncached then return nil end
    return "Item", nil, nil, e.ilvl, e.req, nil, nil, nil,
           e.equipLoc or "INVTYPE_CHEST"
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
assert(compile(${JSON.stringify(plausible)}, "@Valuate-LootCollector/Plausible.lua"))("Valuate-LootCollector", ns)
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

-- Status BEFORE anything is installed. This is the state a real user is in when the poll
-- never finds LootCollector's window, and it is the only moment the not-installed flags can
-- be observed - asserted afterwards, the hook is always in and the mutation that reports
-- everything as fine changes nothing.
local preInstall = ns.StatusReport()
local function preRow(label)
    for _, row in ipairs(preInstall) do if row.label == label then return row end end
end
eq(preRow("Hook installed").ok, false, "before the poll runs, the hook is reported as NOT installed")
eq(preRow("Hook installed").value, "no", "in words as well as colour")
eq(preRow("Button built").ok, false, "and the button as not yet built")

-- Driving the poll by hand is what half a second of play would do.
watcher.__scripts.OnUpdate(watcher, 1)
eq(ns.mode, "off", "the filter starts off, so installing the hook changes nothing by itself")

-- zone defaults to nil rather than to a real one: a row with no zone must fall through the
-- sanity filter untouched, so every assertion about the GEAR filter below is written against
-- rows the sanity filter cannot have an opinion about.
local function rowFor(link, mystic, vendor, zone)
    return { discovery = { il = link, z = zone, iz = 0 },
             isMystic = mystic or false, isVendor = vendor or false }
end

-- ---- OFF, and the two tabs this has no opinion about -------------------------------------
-- IDENTITY, not equality. Their result table is reused and wiped on every rebuild, so handing
-- back a copy would hand back a view of something about to be emptied.
--
-- The sanity filter is switched off for this block. It runs on every tab by design, so
-- leaving it on would mean these four assertions passed or failed on ITS behaviour while
-- claiming to be about the gear filter - and identity is exactly what a second filter
-- rebuilding the table takes away. It gets its own block below.
ns.sanity = false
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

-- ---- saying whether any of this is working ---------------------------------------------------
-- This addon is the least verifiable thing in the set: everything it does is invisible when it
-- works - rows that are not there - and equally invisible when it does not. A hook that never
-- installed, a button that never got built, a scale that was never picked, and a filter doing
-- nothing all look exactly like "there were no upgrades in that zone".
--
-- So the assertions are about the OK flags, not the words. A status line that reports a broken
-- thing in the same colour as a working one is a status line nobody reads twice.
local function statusBy(label)
    for _, row in ipairs(ns.StatusReport()) do
        if row.label == label then return row end
    end
end

-- Everything healthy: hook in, button built, scale picked.
ns.mode = "upgrades"
ROWS = { rowFor("up") }
Viewer.currentFilter = "eq"
Viewer:GetFilteredDiscoveries()

eq(statusBy("LootCollector").ok, true, "it reports finding LootCollector")
eq(statusBy("Hook installed").ok, true, "and that the hook went in")
eq(statusBy("Button built").ok, true, "and that the button exists")
eq(statusBy("Active scale").ok, true, "and that there is a scale to rank by")
ok(statusBy("Active scale").value:find("Dps", 1, true) ~= nil, "naming it")

-- NO SCALE. The single most likely reason for "it is not filtering anything", and the one the
-- panel itself cannot tell you because it never draws.
SCALE_NAME = nil
local noScale = statusBy("Active scale")
eq(noScale.ok, false, "with no active scale the row is flagged, not merely stated")
ok(noScale.value:find("NONE", 1, true) ~= nil, "and says so in words")
SCALE_NAME = "Dps"

-- The memo is the honest measure of whether it has done any work at all: zero verdicts with the
-- filter on and a window open means evaluation is not reaching anything.
ns.ResetMemo()
eq(statusBy("Verdicts remembered").value, "0", "a fresh memo reports zero")
Viewer:GetFilteredDiscoveries()
ok(statusBy("Verdicts remembered").value ~= "0", "and it climbs once it has judged something")

-- Items it gave up on. Not a failure in itself - the client genuinely never answers for some -
-- but a large number explains a list that never narrows, which is otherwise unexplainable.
ns.ResetMemo()
WORLD["ghostly"] = { uncached = true }
ROWS = { rowFor("ghostly") }
for _ = 1, 5 do
    Viewer:GetFilteredDiscoveries()
    if ns.PendingCount() > 0 then driver.__scripts.OnUpdate(driver) end
end
ok(tonumber(statusBy("Gave up on").value) > 0,
   "an item the client never answers for is counted as given up on")

-- Every row has a label and a value, or the report prints blanks that read as broken state.
for _, row in ipairs(ns.StatusReport()) do
    ok(type(row.label) == "string" and row.label ~= "", "every status row has a label")
    ok(type(row.value) == "string" and row.value ~= "",
       "and a value: '" .. tostring(row.label) .. "'")
end


-- ---- the sanity filter, end to end -----------------------------------------------------------
--
-- Plausible.lua is proven on its own in tools/lcplausible.js. What is only provable HERE is the
-- wiring: that the verdict reaches the list, that the row actually leaves it, that the reason
-- survives the trip, and that it happens on the tabs the gear filter refuses to touch.
--
-- The zone ids are real ones out of LootCollector's ZoneList: 31 is Elwynn Forest, banded 1-10,
-- and 24 is Eastern Plaguelands, banded 53-60.
ns.sanity = true
ns.mode = "off"
Viewer.currentFilter = "eq"

WORLD["absurd"] = { equipLoc = "INVTYPE_HEAD", req = 60, ilvl = 200, stats = { Agility = 1 } }
WORLD["fine"]   = { equipLoc = "INVTYPE_HEAD", req = 8,  ilvl = 15,  stats = { Agility = 1 } }

ROWS = { rowFor("absurd", false, false, 31), rowFor("fine", false, false, 31) }
local out = Viewer:GetFilteredDiscoveries()
eq(#out, 1, "a level 60 requirement in Elwynn Forest is taken out of the list")
eq(out[1].discovery.il, "fine", "and the level-appropriate find in the same zone stays")
eq(#ns.hidden, 1, "what it removed is recorded rather than merely dropped")
eq(ns.hidden[1].link, "absurd", "by link")
ok(ns.hidden[1].why and ns.hidden[1].why:find("60", 1, true) ~= nil,
   "with the reason, so the judgement can be argued with rather than only trusted")

-- The SAME item in a zone that holds level 60 content is not implausible at all. This is the
-- assertion that separates a level filter from a quality filter.
ROWS = { rowFor("absurd", false, false, 24) }
eq(#Viewer:GetFilteredDiscoveries(), 1, "the identical item in Eastern Plaguelands is left alone")
eq(#ns.hidden, 0, "and nothing is reported as hidden")

-- ---- it runs where the gear filter will not ---------------------------------------------------
-- A scroll listed in a zone it could not have come from is just as wrong as a helmet, and the
-- gear filter refuses those tabs on purpose. This is the point of gating the two separately.
for _, tab in ipairs({ "ms", "bmv" }) do
    Viewer.currentFilter = tab
    ROWS = { rowFor("absurd", tab == "ms", tab == "bmv", 31) }
    eq(#Viewer:GetFilteredDiscoveries(), 0,
       "the sanity filter applies on the " .. tab .. " tab, where the gear filter never runs")
end
Viewer.currentFilter = "eq"

-- ---- and it needs nothing the gear filter needs ------------------------------------------------
SCALE_NAME = nil
ROWS = { rowFor("absurd", false, false, 31) }
eq(#Viewer:GetFilteredDiscoveries(), 0,
   "with no active scale it still works - it is not asking about your gear")
SCALE_NAME = "Dps"

-- ---- every way of having no grounds leaves the row alone ----------------------------------------
--
-- Each of these is a different reason, and the shared answer is never "hide it". They are
-- written out one at a time because collapsing them is how a filter starts treating "I could
-- not tell" as "no".
ROWS = { rowFor("absurd", false, false, nil) }
eq(#Viewer:GetFilteredDiscoveries(), 1, "a row with no zone on it is not judged")

ROWS = { rowFor("absurd", false, false, 99999) }
eq(#Viewer:GetFilteredDiscoveries(), 1, "nor is one in a zone the level table has never been taught")

WORLD["stranger"] = { equipLoc = "INVTYPE_HEAD", req = 60, ilvl = 200, uncached = true }
ROWS = { rowFor("stranger", false, false, 31) }
eq(#Viewer:GetFilteredDiscoveries(), 1, "nor an item the client has not cached yet")

-- iz is 0 for a map LootCollector recognises and the map id itself for one it does not. An
-- unrecognised map is one the level table cannot have a range for either.
ROWS = { { discovery = { il = "absurd", z = 31, iz = 31 }, isMystic = false, isVendor = false } }
eq(#Viewer:GetFilteredDiscoveries(), 1, "nor a discovery on a map LootCollector itself does not know")

-- ---- switched off, it is completely inert ---------------------------------------------------------
ns.sanity = false
ROWS = { rowFor("absurd", false, false, 31) }
eq(Viewer:GetFilteredDiscoveries(), ROWS,
   "switched off with the gear filter off too, their own table comes straight back untouched")
ns.sanity = true

-- ---- the two together -----------------------------------------------------------------------------
-- An implausible row must not come back as a hole. ns.Keep says yes to anything that is not
-- gear, and a removed row is not gear, so the order of those two tests is load-bearing.
ns.mode = "upgrades"
WORLD["realupgrade"] = { equipLoc = "INVTYPE_HEAD", req = 8, ilvl = 15,
                         stats = { Agility = 50 }, upgrade = true }
ROWS = { rowFor("absurd", false, false, 31), rowFor("realupgrade", false, false, 31) }
out = Viewer:GetFilteredDiscoveries()
eq(#out, 1, "with both filters on, the implausible row is gone and the upgrade is not")
eq(out[1].discovery.il, "realupgrade", "-- and it is the upgrade that survived")
for i = 1, #out do ok(out[i] ~= nil, "no hole is left where a hidden row was") end
ns.mode = "off"


-- ---- the map pins and the tracking arrow -------------------------------------------------------
--
-- LootCollector::DiscoveryPassesFilters is the single predicate behind the map pin layer and
-- the arrow that points at the nearest find. It is the surface that actually costs something:
-- a row in a list is a row, but a phantom pin is a walk across a zone to stand on empty ground.
ns.sanity = true
ns.mode = "off"

local function pin(link, zone, iz) return { il = link, z = zone, iz = iz or 0 } end

ok(LCAddon.DiscoveryPassesFilters ~= nil, "the map predicate is hooked at all")

PASS_ANSWER = true
passCalls = 0
eq(LCAddon:DiscoveryPassesFilters(pin("fine", 31)), true,
   "a level-appropriate find keeps its pin on the map")
eq(passCalls, 1, "and the original was called, not replaced")

eq(LCAddon:DiscoveryPassesFilters(pin("absurd", 31)), false,
   "a level 60 requirement in Elwynn Forest loses its pin, so nobody walks to it")
eq(LCAddon:DiscoveryPassesFilters(pin("absurd", 24)), true,
   "the identical item in Eastern Plaguelands keeps its pin")

-- THEIRS IS FINAL WHEN IT SAYS NO. Their own window has hide-stale, hide-looted and the rest;
-- a filter that could turn a hidden discovery back ON would be overriding those settings.
PASS_ANSWER = false
passCalls = 0
eq(LCAddon:DiscoveryPassesFilters(pin("fine", 31)), false,
   "what their own filters hid stays hidden - this never adds a pin back")
eq(passCalls, 1, "and it asked them first rather than deciding by itself")
PASS_ANSWER = true

-- The same four ways of having no grounds, on this path too.
eq(LCAddon:DiscoveryPassesFilters(pin("absurd", nil)), true, "no zone, no opinion")
eq(LCAddon:DiscoveryPassesFilters(pin("absurd", 99999)), true, "an untaught zone, no opinion")
eq(LCAddon:DiscoveryPassesFilters(pin("stranger", 31)), true, "an uncached item, no opinion")
eq(LCAddon:DiscoveryPassesFilters(pin("absurd", 31, 31)), true,
   "and a map LootCollector itself does not recognise")
eq(LCAddon:DiscoveryPassesFilters(nil), true, "no discovery at all is survivable")

-- Switched off, it is inert here as well.
ns.sanity = false
eq(LCAddon:DiscoveryPassesFilters(pin("absurd", 31)), true,
   "with the sanity filter off, every pin their filters allow is drawn")
ns.sanity = true

-- ONLY the sanity filter belongs on this path. Whether an item beats your gear is a good
-- reason to leave it in a list and a bad reason to remove it from the map: the map is how you
-- find out where things are, and emptying it of everything you happen to out-gear would make
-- the addon look broken.
ns.mode = "upgrades"
eq(LCAddon:DiscoveryPassesFilters(pin("nothing", 31)), true,
   "an item worth nothing to your scale still keeps its pin - the map is not the upgrade list")
ns.mode = "off"

-- Nothing is recorded from this path. It runs per pin per repaint, so appending there would
-- grow the record without bound; the list pass rebuilds it and is what /vlc hidden reports on.
ns.hidden = {}
for _ = 1, 20 do LCAddon:DiscoveryPassesFilters(pin("absurd", 31)) end
eq(#ns.hidden, 0, "twenty map repaints add nothing to the hidden record")

return failures, checks
`,
  "lchook",
  "the LootCollector hook"
);
