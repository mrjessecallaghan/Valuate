#!/usr/bin/env node
/*
 * @gate The deletion protections actually fire
 *
 * Runs the REAL source of IsProtectedFromDelete against a mocked WoW API.
 *
 * Deletion is the only irreversible thing this addon does, and the promise around it -
 * never a quest item, an equipment-set member, a weapon-set member, a best-in-slot, a
 * future upgrade, or an upgrade for any scale - is the most load-bearing sentence in the
 * project.
 *
 * `delete-protections-complete` in check.js already guards the promise STRUCTURALLY: each
 * category has a branch returning its own reason string, and those strings are printed
 * verbatim in the tooltip verdict, so a deleted or renamed branch fails the build. What it
 * cannot see is whether a branch still fires. A condition inverted, an `and` that should be
 * an `or`, a lookup that stopped returning what the branch tests for - the string is still
 * there, the gate is still green, and gear is deleted.
 *
 * That gap existed because Valuate.lua could not be executed. It can now be sliced (see
 * verifytest.js), so this closes it: every category is proven to protect, and each is
 * proven ALONE, with every other protection switched off. A test where several could be
 * responsible for the same answer would pass with five of the six branches broken.
 *
 * Usage:  node tools/deletetest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");
const extra = ["MarkDisplaced", "WasDisplacedByUs", "AutoUnjunkProtected"].map(function (name) {
  const hit = lua.match(
    new RegExp("^function Valuate:" + name + "\\([\\s\\S]*?\\r?\\nend", "m")
  );
  if (!hit) {
    console.error("  SLICE  could not find Valuate:" + name + " - this gate tests nothing");
    process.exit(1);
  }
  return hit[0];
}).join("\n");
const m = lua.match(/^local function IsProtectedFromDelete\(([\s\S]*?)\nend\n/m);
if (!m) {
  console.error(
    "  SLICE  could not find `local function IsProtectedFromDelete` in Valuate.lua - " +
      "it was renamed, moved or reshaped, so this gate is testing nothing"
  );
  process.exit(1);
}

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

-- Every protection OFF. Each test switches on exactly one, so a passing case names the
-- branch responsible - with five of six broken this file still fails, which is the whole
-- point of proving them one at a time.
local lastUpgradeOpts
local function clear()
    lastUpgradeOpts = nil
    GetContainerItemQuestInfo = function() return false, nil end
    GetContainerItemEquipmentSetInfo = function() return false end
    Valuate = {
        GetBestForInfo = function() return nil end,
        GetFutureUpgradeScales = function() return nil end,
        GetStatsForTooltipSetter = function() return { str = 10 } end,
        IsUpgradeForAnyScale = function(self, link, stats, opts)
            lastUpgradeOpts = opts
            return false
        end,
    }
end

` + extra + "\n" + m[0] + `

local LINK = "|cff0070dd|Hitem:1234::::::::80:::::|h[Test Item]|h|r"

-- Nothing protects it: deletable. If this ever returns true the whole file proves
-- nothing, because every case below would pass for the wrong reason.
clear()
local prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, false, "an unprotected junk item is deletable")

-- No link at all. Protected, because an item we cannot identify is one we cannot vet.
clear()
prot, reason = IsProtectedFromDelete(1, 1, nil)
eq(prot, true, "a missing link is protected")
eq(reason, "no link", "a missing link says why")

-- 1. Quest item, reported as a quest item.
clear()
GetContainerItemQuestInfo = function() return true, nil end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "a quest item is protected")
eq(reason, "quest item", "quest item reason")

-- ...and reported ONLY as a quest ID, with the boolean false. Real 3.3.5 returns one or
-- the other depending on the item, so the branch tests both; an \`and\` here would leave
-- every quest-starting item deletable.
clear()
GetContainerItemQuestInfo = function() return false, 4242 end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "an item with only a quest ID is protected")
eq(reason, "quest item", "quest-ID-only reason")

-- 2. Belongs to a WoW equipment set.
clear()
GetContainerItemEquipmentSetInfo = function() return true end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "an equipment-set member is protected")
eq(reason, "in an equipment set", "equipment set reason")

-- 3. Best-in-slot: GetBestForInfo returns entries, none carrying a weapon category.
clear()
Valuate.GetBestForInfo = function() return { { scale = "Melee" } } end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "a best-in-slot item is protected")
eq(reason, "best-in-slot", "best-in-slot reason")

-- 4. Weapon-set member: an entry carrying a category, named in the reason.
clear()
Valuate.GetBestForInfo = function() return { { scale = "Melee", category = "Two-Hander" } } end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "a weapon-set member is protected")
eq(reason, "weapon-set member (Two-Hander)", "weapon-set reason names the set")

-- A categorised entry AFTER an uncategorised one still wins. The loop must scan the whole
-- list; returning on the first entry would call an off-set weapon "best-in-slot", which
-- reads like a mistake on a weapon you are not currently using - and the tooltip verdict
-- shows this string verbatim.
clear()
Valuate.GetBestForInfo = function()
    return { { scale = "Melee" }, { scale = "Tank", category = "1H + Shield" } }
end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(reason, "weapon-set member (1H + Shield)", "a later categorised entry still wins")

-- An EMPTY table is still "best for something" as far as this branch goes. Worth pinning:
-- \`if info then\` is truthy for {}, so the answer is protection rather than a fall-through.
clear()
Valuate.GetBestForInfo = function() return {} end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "an empty best-for list still protects")
eq(reason, "best-in-slot", "empty best-for list reads as best-in-slot")

-- 5. Future upgrade - gear you cannot use yet but will.
clear()
Valuate.GetFutureUpgradeScales = function() return { "Melee" } end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "a future upgrade is protected")
eq(reason, "future upgrade", "future upgrade reason")

-- 6. An upgrade for any scale, even one never scanned into the results.
clear()
Valuate.IsUpgradeForAnyScale = function(self, link, stats, opts) lastUpgradeOpts = opts return true end
prot, reason = IsProtectedFromDelete(1, 1, LINK)
eq(prot, true, "an upgrade is protected")
eq(reason, "an upgrade", "upgrade reason")

-- ...and it must ask about INACTIVE scales too. Drop that option and gear that is an
-- upgrade for a scale you have not switched on becomes deletable - silently, with every
-- reason string still present and every static gate still green.
ok(lastUpgradeOpts ~= nil, "IsUpgradeForAnyScale was actually consulted")
eq(lastUpgradeOpts and lastUpgradeOpts.includeInactive, true,
   "the upgrade check includes inactive scales")

-- No stats: the branch must not call the upgrade check at all, since scoring nil stats is
-- meaningless. It falls through to deletable, which is correct only because everything
-- else already said no.
clear()
Valuate.GetStatsForTooltipSetter = function() return nil end
Valuate.IsUpgradeForAnyScale = function(self, link, stats, opts) lastUpgradeOpts = opts return true end
prot = IsProtectedFromDelete(1, 1, LINK)
eq(prot, false, "no stats means the upgrade branch is skipped")
eq(lastUpgradeOpts, nil, "the upgrade check is not consulted without stats")

-- A THROWING client API must not take the addon down. Both container calls are pcall'd
-- because they error on some slots in 3.3.5; an error escaping here would abort the whole
-- delete scan mid-pass.
clear()
GetContainerItemQuestInfo = function() error("boom") end
GetContainerItemEquipmentSetInfo = function() error("boom") end
Valuate.GetBestForInfo = function() return { { scale = "Melee" } } end
local safe, res = pcall(IsProtectedFromDelete, 1, 1, LINK)
eq(safe, true, "a throwing container API does not propagate")
eq(res, true, "later protections still apply after a throwing API")

-- Missing APIs entirely (an older client, or a method not yet defined at load). Each
-- branch is guarded by an existence check, so this must answer rather than error.
clear()
GetContainerItemQuestInfo = nil
GetContainerItemEquipmentSetInfo = nil
Valuate = {}
` + extra + `
safe, res = pcall(IsProtectedFromDelete, 1, 1, LINK)
eq(safe, true, "missing APIs do not error")
eq(res, false, "with no APIs at all, nothing claims protection")

-- ---- gear one of our own automations just took off you ---------------------------------
-- The automations were written one at a time and never introduced to each other. Auto-equip
-- puts the piece it replaced into your bags; auto-delete runs on the bag update that follows.
-- The displaced item is protected by NONE of the other rules here - it is no longer
-- best-in-slot, because the thing that replaced it is, and no longer an upgrade, because you
-- are wearing something better. It is simply deletable.
--
-- At level ten that item can be grey, which is exactly what auto-delete looks for. Nobody
-- asked for "delete the gear I was wearing four seconds ago", and deletion has no undo.
Valuate.displaced = { grace = 300, at = {} }
local NOW = 1000
function GetTime() return NOW end

local DISPLACED_LINK = "|Hitem:4242|h[Old Chest]|h"
function GetItemIdFromLink(link) return tonumber(link and link:match("|Hitem:(%d+)")) end

-- Not marked: nothing here protects it, which is the whole problem.
local prot2, reason2 = IsProtectedFromDelete(1, 1, DISPLACED_LINK)
eq(prot2, false, "an ordinary replaced item is not protected by any other rule")

-- Marked by our own equip.
Valuate:MarkDisplaced(4242)
prot2, reason2 = IsProtectedFromDelete(1, 1, DISPLACED_LINK)
eq(prot2, true, "gear auto-equip just replaced is protected from deletion")
ok(reason2 and reason2:find("auto-equip", 1, true) ~= nil,
   "and the reason names WHY, so the tooltip verdict can explain a keep nobody asked for")

-- A grace period, not an amnesty. The protection covers the window where one automation is
-- still reacting to another; it is not there to make old gear immortal.
NOW = 1000 + 301
prot2 = IsProtectedFromDelete(1, 1, DISPLACED_LINK)
eq(prot2, false, "once the window passes it is deletable again - this is a grace period, not " ..
   "a permanent exemption")

-- A clock that goes backwards (a /reload resets GetTime) must expire it rather than protect
-- it forever, which is the same trap the active-scale cache had.
NOW = 10
Valuate.displaced.at[4242] = 1000
prot2 = IsProtectedFromDelete(1, 1, DISPLACED_LINK)
eq(prot2, false, "a clock that ran backwards expires the mark rather than pinning it")

-- And a different item is unaffected.
NOW = 1000
Valuate:MarkDisplaced(4242)
eq(IsProtectedFromDelete(1, 1, "|Hitem:9999|h[Other]|h"), false,
   "marking one item does not protect everything in your bags")

-- ---- rescuing gear from the junk pile ---------------------------------------------------
-- AdiBags decides junk by QUALITY; this addon decides by what your scale is worth. They
-- disagree hardest at low level, where a white or even grey item really can be your
-- best-in-slot - so gear you are WEARING lands in the Junk section, and everything that
-- trusts that section, including this addon's own selling, treats it as disposable.
--
-- The dangerous half is the direction. This writes to another addon's override table, and an
-- automation that could mark things AS junk would be making a judgement about worth that
-- nobody asked it to make.
local sent, filtersChanged = {}, 0
local JUNKY = {}
local FAKE_ADIBAGS = {
    SendMessage = function(_, msg, section, _unused, itemId)
        if msg == "AdiBags_FiltersChanged" then filtersChanged = filtersChanged + 1 return end
        sent[#sent + 1] = { msg = msg, section = section, itemId = itemId }
    end,
}
ResolveAdiBagsJunk = function() return FAKE_ADIBAGS, nil end
IsItemJunk = function(_, _, itemId) return JUNKY[itemId] == true end
GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
local BAGLINKS = {}
GetContainerItemLink = function(bag, slot) return BAGLINKS[slot] end
GetItemInfo = function() return "Item", nil, 0 end
Valuate.MarkAutomation = function() end
Valuate.GetOptions = function() return { autoUnjunkProtected = true, chatMessages = false } end

BAGLINKS[1] = "|Hitem:4242|h[Protected]|h"
BAGLINKS[2] = "|Hitem:5555|h[Genuine Junk]|h"
JUNKY[4242], JUNKY[5555] = true, true

-- Only 4242 is protected: it is best-for something. Fields set individually rather than
-- through clear(), which rebuilds the whole table and would take the sliced method with it.
GetContainerItemQuestInfo = function() return false, nil end
GetContainerItemEquipmentSetInfo = function() return false end
Valuate.GetFutureUpgradeScales = function() return nil end
Valuate.GetStatsForTooltipSetter = function() return { str = 10 } end
Valuate.IsUpgradeForAnyScale = function() return false end
Valuate.GetBestForInfo = function(_, link)
    if link and link:find("4242", 1, true) then return { { scale = "Melee" } } end
    return nil
end
Valuate.GetOptions = function() return { autoUnjunkProtected = true, chatMessages = false } end
Valuate.MarkAutomation = function() end

local freed = Valuate:AutoUnjunkProtected()
eq(freed, 1, "exactly the protected item is rescued")
eq(#sent, 1, "and exactly one override is sent")
eq(sent[1] and sent[1].itemId, 4242, "for the item your scale actually wants")
eq(sent[1] and sent[1].section, nil,
   "with a NIL section, which is how the junk filter is told to exclude it")
ok(filtersChanged >= 1, "and the filters are refreshed once, not per item")

-- The direction that matters. Nothing here may ever mark something AS junk: deciding an item
-- is worthless is a judgement this addon has no business making for you.
for _, m in ipairs(sent) do
    ok(m.section == nil,
       "no message carries a junk section - this rescues only, it never marks")
end

-- Switched off means untouched, including another addon's state.
sent, filtersChanged = {}, 0
Valuate.GetOptions = function() return { autoUnjunkProtected = false } end
eq(Valuate:AutoUnjunkProtected(), 0, "with the option off it does nothing")
eq(#sent, 0, "and writes nothing to AdiBags")

-- Nothing protected: nothing sent. A rescue that fires on genuine junk would be worse than
-- none, because it would quietly refill the pile you were trying to empty.
sent = {}
Valuate.GetOptions = function() return { autoUnjunkProtected = true, chatMessages = false } end
Valuate.GetBestForInfo = function() return nil end
Valuate.GetFutureUpgradeScales = function() return nil end
Valuate.IsUpgradeForAnyScale = function() return false end
Valuate.displaced.at = {}
eq(Valuate:AutoUnjunkProtected(), 0, "genuine junk is left exactly where it is")
eq(#sent, 0, "and nothing is written")

return failures, checks
`,
  "deletetest",
  "the deletion protections"
);
