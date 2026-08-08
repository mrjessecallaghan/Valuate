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

` + m[0] + `

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
safe, res = pcall(IsProtectedFromDelete, 1, 1, LINK)
eq(safe, true, "missing APIs do not error")
eq(res, false, "with no APIs at all, nothing claims protection")

return failures, checks
`,
  "deletetest",
  "the deletion protections"
);
