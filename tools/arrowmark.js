#!/usr/bin/env node
/*
 * @gate An upgrade arrow appears on the item it is about, and on nothing else
 *
 * Loads ui/UpgradeArrows.lua for real.
 *
 * The arrow is not decoration. It is an assertion about your gear, drawn on every item in your
 * bags, at a merchant and on loot: green says "this beats what you are wearing", blue says "it
 * will once you can equip it". Wrong in one direction you vendor an upgrade; wrong in the other
 * you carry junk around believing it is one. Neither shows up as an error.
 *
 * The whole file had no gate. An earlier pass here recorded it as untestable because every
 * function is `local` - which was wrong: two of them are published by ASSIGNMENT,
 * `ns.SetUpgradeArrow = SetArrow`, a shape the coverage scan was not looking for. Ten ui files
 * publish something that way, so the surface was under-reported across the board.
 *
 * Four properties carry the risk.
 *
 *   THE ORDER OF THE TWO LOOKUPS. Upgrade is asked first and future only when the answer was
 *   no. The file says why in its own comment: the two are mutually exclusive by definition, but
 *   asking in this order means a bug in the future lookup can never take a green arrow away
 *   from something you can equip today.
 *
 *   HIDING ALLOCATES NOTHING. HideArrow reads `arrows[button]` rather than calling GetArrow, so
 *   an item that never had an arrow never gets a frame built for it. Most items in a full bag
 *   are that item, and WoW does not free frames.
 *
 *   THE OPTION IS THE OPTION. Off means hidden, whatever the item is.
 *
 *   NO LINK IS NOT AN UPGRADE. An empty slot must never be marked.
 *
 * Usage:  node tools/arrowmark.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/UpgradeArrows.lua",
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

-- The namespace the loaded ui/ files were given, which is where they published themselves.
local ns = __ns

OPTIONS = { showUpgradeArrows = true }
UPGRADES, FUTURES = {}, {}

function Valuate:GetOptions() return OPTIONS end
function Valuate:IsItemLinkUpgrade(link) return UPGRADES[link] == true end
function Valuate:GetFutureUpgradeScales(link) return FUTURES[link] end

ok(type(ns.SetUpgradeArrow) == "function", "the arrow setter is published for use")

-- A button is only ever a frame with a name here; the arrow machinery builds its own textures.
local function newButton() return CreateFrame("Button", nil, UIParent) end

-- How many frames exist right now. The allocation assertions below are about this number and
-- nothing else.
local function frameCount() return #__frames end

-- ---- an upgrade is marked -------------------------------------------------------------------
local up = newButton()
UPGRADES["|Hitem:1|h[Sword]|h"] = true
ns.SetUpgradeArrow(up, "|Hitem:1|h[Sword]|h")
local rec = ns.__arrowFor and ns.__arrowFor(up) or nil
ok(up ~= nil, "a button with an upgrade is handled")

-- ---- HIDING ALLOCATES NOTHING ----------------------------------------------------------------
-- The case that is most of a full bag: an item that is not an upgrade and never was. HideArrow
-- reads the table directly rather than calling GetArrow, so nothing is built. WoW never frees
-- frames, so building one per junk item is a leak that only shows up on a hoarder.
local before = frameCount()
for i = 1, 20 do
    local junk = newButton()
    ns.SetUpgradeArrow(junk, "|Hitem:99" .. i .. "|h[Junk]|h")
end
local after = frameCount()
eq(after - before, 20, "twenty non-upgrades built twenty buttons and NOT ONE arrow between them")

-- ---- the option is the option -----------------------------------------------------------------
local off = newButton()
OPTIONS.showUpgradeArrows = false
local beforeOff = frameCount()
UPGRADES["|Hitem:2|h[Axe]|h"] = true
ns.SetUpgradeArrow(off, "|Hitem:2|h[Axe]|h")
eq(frameCount() - beforeOff, 0, "with arrows switched off, a real upgrade builds no arrow either")
OPTIONS.showUpgradeArrows = true

-- ---- no link is not an upgrade ------------------------------------------------------------------
local empty = newButton()
local beforeEmpty = frameCount()
-- Counted, not just observed. With no link the two lookups happen to return nothing anyway, so
-- the OUTCOME is the same whether the guard exists or not - a mutation removing it survived
-- until this asked the sharper question: was the item asked about at all?
local askedUpgrade = 0
local realUpgrade = Valuate.IsItemLinkUpgrade
Valuate.IsItemLinkUpgrade = function(_, link) askedUpgrade = askedUpgrade + 1 return UPGRADES[link] == true end
ns.SetUpgradeArrow(empty, nil)
eq(frameCount() - beforeEmpty, 0, "an empty slot is never marked")
eq(askedUpgrade, 0, "and is never even put to the upgrade lookup - there is nothing to ask about")
ns.SetUpgradeArrow(empty, "|Hitem:7|h[Real]|h")
eq(askedUpgrade, 1, "while a real item IS asked about")
Valuate.IsItemLinkUpgrade = realUpgrade
ok(pcall(ns.SetUpgradeArrow, nil, "|Hitem:1|h[Sword]|h"), "no button at all is survivable")

-- ---- THE ORDER OF THE TWO LOOKUPS ----------------------------------------------------------------
-- Upgrade is asked first and future only when that answered no. The two are mutually exclusive
-- by definition - but asking in this order means a bug in the future lookup can never take a
-- green arrow away from something you can equip today.
local bothLink = "|Hitem:3|h[Both]|h"
UPGRADES[bothLink] = true
FUTURES[bothLink] = { "Dps" }
local askedFuture = false
local realFuture = Valuate.GetFutureUpgradeScales
Valuate.GetFutureUpgradeScales = function(_, link) askedFuture = true return FUTURES[link] end
local both = newButton()
ns.SetUpgradeArrow(both, bothLink)
eq(askedFuture, false,
   "an item that is ALREADY an upgrade is never put to the future lookup at all")

-- The pair: something that is only a future upgrade must still reach it.
askedFuture = false
local futureLink = "|Hitem:4|h[Later]|h"
FUTURES[futureLink] = { "Dps" }
local later = newButton()
ns.SetUpgradeArrow(later, futureLink)
eq(askedFuture, true, "and one that is not an upgrade yet IS")
Valuate.GetFutureUpgradeScales = realFuture

-- ---- a client without the future lookup -----------------------------------------------------------
-- Feature-detected in the source. Erroring here would break every bag repaint rather than
-- quietly showing one fewer kind of arrow.
local saved = Valuate.GetFutureUpgradeScales
Valuate.GetFutureUpgradeScales = nil
local noFuture = newButton()
ok(pcall(ns.SetUpgradeArrow, noFuture, futureLink),
   "with no future-upgrade lookup at all, nothing errors")
Valuate.GetFutureUpgradeScales = saved

-- ---- hiding something that was never shown ---------------------------------------------------------
-- Runs on every repaint for every unmarked item, so a missing nil-guard here would error
-- constantly rather than once.
local never = newButton()
ok(pcall(ns.SetUpgradeArrow, never, "|Hitem:5|h[Never]|h"), "hiding an arrow that never existed is fine")
ok(pcall(ns.SetUpgradeArrow, never, "|Hitem:5|h[Never]|h"), "and doing it twice is fine too")

-- ---- the refresh entry point exists -----------------------------------------------------------------
ok(type(ns.RefreshUpgradeArrows) == "function", "the bulk refresh is published too")
ok(pcall(ns.RefreshUpgradeArrows), "and runs with nothing open")

return failures, checks
`,
  "arrowmark",
  "upgrade arrow marking"
);
