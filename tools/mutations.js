/*
 * Every assertion we believe is load-bearing, written as a way to break it.
 *
 * A gate that passes tells you the code does something. It does not tell you the gate would
 * NOTICE if the code stopped. This file is the difference: each entry breaks the source in a
 * specific, plausible way and names the gate that must fail as a result.
 *
 * Run with:  node tools/mutate.js  [gate-name]
 *
 * A SURVIVED result is the finding. It means an assertion is decorative - it reads like a
 * test and protects nothing. Every one of these was written after a real gap:
 *
 *   - four in one session were the FIXTURE, not the code: bags of nothing but chest pieces,
 *     bags of nothing but gear, a tooltip parse that was never empty, and a best-score that
 *     was always exactly 100 (against which "gap / bestScore" and "gap / 100" are the same
 *     arithmetic, so the percentage was untested).
 *   - one was a design flaw caught before it shipped: the wizard offering to overwrite any
 *     scale it had made, so asking for a Tank build would replace your DPS one.
 *
 * Fields:
 *   gate    the tool that must FAIL when this is applied
 *   file    path relative to the addon root
 *   label   what breaking it would mean for a user, not what line changed
 *   from/to exact substring replacement, first occurrence within `scope`
 *   scope   optional { start, end } markers, so a mutation lands in one function
 *           rather than the first coincidental match in an 9,000-line file
 */
"use strict";

const SCALED = {
  start: "function Valuate:GetScaledStatsForItem",
  end: "\n-- Why is this item not my best-in-slot?",
};
const SHARED_READER = {
  start: "function Valuate:GetStatsForTooltipSetter",
  end: "\n-- Sums the stats across everything you are wearing.",
};
const EXPLAIN = {
  start: "function Valuate:ExplainBestInSlot",
  end: "\n-- How much this item would improve each scale",
};
const DETAIL = {
  start: "function Valuate:BuildDetailLines",
  end: "\n-- How much this item would improve each scale",
};
const COUNT_SOCKETS = {
  start: "local function CountEmptySockets",
  end: "\n-- Returns { { slotId, slotName",
};
const FIND_SOCKETS = {
  start: "function Valuate:FindEmptySockets",
  end: "\n-- What is my biggest upgrade right now?",
};
const UNMATCHED_SLOTS = {
  start: "function Valuate:UnmatchedBestSlots",
  end: "\n-- Everything that can be decided BEFORE touching your gear.",
};
const ANNOUNCE_TODO = {
  start: "function Valuate:AnnounceTodo",
  end: "\n-- Everything worth doing about your gear, in one list.",
};
const TODO = {
  start: "function Valuate:BuildTodoList",
  end: "\n-- Making the PvP scale, rather than leaving you an empty slot to fill.",
};
const BUILD_PVP = {
  start: "function Valuate:BuildPvPScaleFrom",
  end: "\n-- Your PvP answer and your PvE answer are not the same answer.",
};
const RANK_UPGRADES = {
  start: "function Valuate:RankAvailableUpgrades",
  end: "\n-- The full best-in-slot breakdown",
};
// Ends at the NEXT function, not at a shared comment. Using "-- How much this item would
// improve each scale" here made this "scope" span 420 lines and three functions, so it
// scoped nothing - the ambiguity check found it the first time it ran.
const NEARMISS = {
  start: "function Valuate:BuildNearMissLine",
  end: "\nfunction Valuate:RankAvailableUpgrades",
};

// The dungeon-leave feature spans two files: the counting lives in ui/DungeonLoot.lua and
// the decision to interrupt you lives in Valuate.lua. Scoped separately, because "does it
// count right" and "does it know when to shut up" fail in different ways.
const WHERE = {
  start: "function Valuate:FindUpgradeSources(",
  end: "\nfunction Valuate:GetDungeonUpgradeStatus",
};
const D_COUNT = { start: "function ns.CountRemainingUpgrades(", end: "\nend" };
const D_KNOWN = { start: "function ns.BossLootKnown(", end: "\nend" };
const D_GET = { start: "function ns.GetDungeonLoot(", end: "\nend" };
const D_CONSIDER = { start: "function Valuate:ConsiderDungeonLeave(", end: "\nend" };
const D_ITEM = { start: "local function DungeonItemIsUpgrade(", end: "\nend" };
const D_CURRENT = { start: "function Valuate:GetCurrentDungeon(", end: "\nend" };
const D_TRACK = { start: "function Valuate:UpdateDungeonTracking(", end: "\nend" };
const D_NOTE = { start: "function Valuate:NoteDungeonUnitDeath(", end: "\nend" };
const D_RESET = { start: "function Valuate:ResetDungeonProgress(", end: "\nend" };

// The spec tooltip. Ends at the next function rather than at "\nend", which would stop at
// the first nested block close inside it.
const SPEC_TIP = {
  start: "local function BuildSpecTooltip(",
  end: "\n-- ========================================",
};

// The two doors from a template into a saved scale, plus the screen that has to keep saying
// what the picker only said once.
const PLAN_AUTO = { start: "function Valuate:PlanAutoScale(", end: "\nfunction Valuate:CommitAutoScale" };
const BE_EMPTY = { start: "        if #activeScales == 0 then", end: "\n        if noScalesTextFrame then" };
const POPUP_EQUIP = {
  start: 'f.equipButton:SetScript("OnClick"',
  end: "\n    -- Shared entrance",
};
const ABOUT = { start: "local function CreateAboutPanel(", end: "\n-- ========================================" };
const SC_CACHES = { start: "local function SelfCheckCaches(", end: "\nlocal SCORE_AGREEMENT_TOLERANCE" };
const HIT_STATE = { start: "function Valuate:GetHitState(", end: "\n-- How much of THIS item" };
const CMP_BREAKDOWN = { start: "function Valuate:CalculateStatBreakdownWithComparison(", end: "\n    -- Sort by hover contribution" };
const BREAKDOWN = { start: "function Valuate:CalculateStatBreakdown(", end: "\n    -- Sort by contribution" };
const HIT_LINE = { start: "function Valuate:BuildHitCapLine(", end: "\nfunction Valuate:BuildDetailLines" };
const HIT_FACTOR = { start: "local function HitValueFactor(", end: "\n-- Diminishing VALUE" };
const DIM_FACTOR = { start: "local function DiminishingFactor(", end: "\nfunction Valuate:CalculateItemScore" };
const CASTER_TEST = { start: "local function ScaleIsCaster(", end: "\n-- What the client says" };
const WIZ_PLAN = { start: "function ns.WizardPlan(", end: "\n    currentPlan = plan" };
const WIZ_FAILED = { start: "local function BuildStepFailed(", end: "\nlocal function BuildStepDone" };
const SC_ITEMS = { start: "local function SelfCheckDungeonItems(", end: "\n-- Does the dungeon you are standing in" };
const SC_KEYS = { start: "local function SelfCheckDungeonKeys(", end: "\nlocal SELF_CHECKS" };
const COMMIT_AUTO = { start: "function Valuate:CommitAutoScale(", end: "\n-- Everything that can" };
const FROM_TEMPLATE = { start: "function ValuateUI_CreateScaleFromTemplate(", end: "\nfunction ValuateUI_NewScale" };
const EDITOR_SUMMARY = { start: "local function UpdateEditorSummary(", end: "\n    ns.UpdateScaleEditorSummary" };


module.exports = [
  // ---- the repaint caches (v0.91.0a, v0.92.0a) -----------------------------
  { gate: "hotpath", file: "Valuate.lua",
    label: "a hidden scale keeps marking gear as best - and surplus feeds auto-delete",
    from: "\n    activeScalesCache, activeScalesAt = nil, -1", to: "\n    local _ = 1" },
  { gate: "hotpath", file: "Valuate.lua",
    label: "the active-scale cache never stores, so every repaint sorts again",
    from: "activeScalesCache, activeScalesAt = active, now", to: "local _ = active" },
  { gate: "hotpath", file: "Valuate.lua",
    label: "a missed invalidation would stick forever - the TTL safety net is gone",
    from: "now - activeScalesAt <= ACTIVE_SCALES_TTL", to: "true" },
  { gate: "hotpath", file: "Valuate.lua",
    label: "a /reload runs the clock backwards and pins a stale scale list",
    from: " and now >= activeScalesAt", to: "" },
  { gate: "hotpath", file: "Valuate.lua",
    label: "an item the server has not sent yet is remembered as unequippable until /reload",
    from: "if itemEquipLoc == nil then", to: "if false then" },
  { gate: "hotpath", file: "Valuate.lua",
    label: "equip locations are never cached, so a repaint asks the client twice per item",
    from: "targetSlotsCache[itemId] = slots or false", to: "local _ = slots" },
  { gate: "hotpath", file: "Valuate.lua",
    label: "'this goes nowhere' is not remembered, so every potion is re-asked forever",
    from: "= slots or false", to: "= slots or nil" },
  { gate: "hotpath", file: "Valuate.lua",
    label: "/valuate profile reports a confident and wrong cache hit rate",
    from: "cacheStats.slotHit = cacheStats.slotHit + 1", to: "local _ = 1" },

  // ---- the scale list's wizard button (v0.89.0a) ---------------------------
  { gate: "scalelisttest", file: "ui/ScaleList.lua",
    label: "a stale Auto scale is never surfaced, so the update path is unreachable",
    from: 'wizardButton.label:SetText(drifted and "Refresh my scale" or "Make me a scale")',
    to: 'wizardButton.label:SetText("Make me a scale")' },
  { gate: "scalelisttest", file: "ui/ScaleList.lua",
    label: "the button says 'Refresh' forever, on a click that would create",
    from: 'wizardButton.label:SetText(drifted and "Refresh my scale" or "Make me a scale")',
    to: 'if drifted then wizardButton.label:SetText("Refresh my scale") end' },
  { gate: "scalelisttest", file: "ui/ScaleList.lua",
    label: "the tooltip cannot name which scale went stale",
    from: "wizardButton.drifted = drifted", to: "wizardButton.drifted = nil" },
  { gate: "scalelisttest", file: "ui/ScaleList.lua",
    label: "drift is never re-read, so the button is right once and wrong after",
    from: "    RefreshWizardButton()", to: "    --RefreshWizardButton()" },

  // ---- the in-game checklist (v0.90.0a) ------------------------------------
  // Jumps far past LAG_ALLOWED rather than one release over it. A mutation tuned to sit
  // exactly on the boundary goes stale every time the checklist gains an entry - this one
  // survived for that reason, claiming to protect a rule it had drifted off the edge of.
  { gate: "verifytest", file: "Valuate.toc",
    label: "the checklist silently stops growing while the addon does not",
    from: "## Version: 0.147.0a", to: "## Version: 0.199.0a" },
  { gate: "verifytest", file: "Valuate.lua",
    label: "two checks share one tick, so verifying either marks both done",
    from: 'id = "newstats", since = "0.72.0a"', to: 'id = "coaclass", since = "0.72.0a"' },

  // ---- base vs scaled stats (v0.94.1a, v0.95.0a) ---------------------------
  { gate: "whybis", file: "Valuate.lua", scope: SCALED,
    label: "back to the v0.94.0a bug: base stats subtracted from scaled ones",
    from: "if itemId and not equipmentSwapPending and Valuate.GetStatsForTooltipSetter then",
    to: "if false then" },
  { gate: "whybis", file: "Valuate.lua", scope: SCALED,
    label: "base numbers presented as if they were comparable",
    from: "return Valuate:GetStatsForItemLink(itemLink), false",
    to: "return Valuate:GetStatsForItemLink(itemLink), true" },
  { gate: "whybis", file: "Valuate.lua", scope: SCALED,
    label: "gear you are wearing is read from its link instead of its slot",
    from: "for slotId = 1, 18 do", to: "for slotId = 1, 0 do" },
  { gate: "whybis", file: "Valuate.lua", scope: SCALED,
    label: "the in-transit guard is relaxed - SetBagItem fires mid equipment swap",
    from: " and not equipmentSwapPending", to: "" },
  { gate: "whybis", file: "Valuate.lua", scope: SHARED_READER,
    label: "a tooltip that has not populated scores a good item at zero (all callers)",
    from: "if not stats or not next(stats) then return nil end",
    to: "if not stats then return nil end" },

  // ---- the best-in-slot verdicts (v0.94.0a) --------------------------------
  { gate: "whybis", file: "Valuate.lua", scope: EXPLAIN,
    label: "an item you should go and equip is reported as beaten",
    from: 'entry.verdict = "unscanned"', to: 'entry.verdict = "beaten"' },
  { gate: "whybis", file: "Valuate.lua", scope: EXPLAIN,
    label: "your own enchanted gear is called an impostor",
    from: "bestLink and GetItemIdFromLink(bestLink) == itemId", to: "bestLink == itemLink" },
  { gate: "whybis", file: "Valuate.lua", scope: EXPLAIN,
    label: "an unscoreable item looks like a close loss instead of an impossible one",
    from: "if entry.score <= 0 then", to: "if false then" },
  { gate: "whybis", file: "Valuate.lua", scope: EXPLAIN,
    label: "a good second ring is called beaten while you wear junk in the other hand",
    from: "if not bestScore or s < bestScore then", to: "if not bestScore or s > bestScore then" },
  { gate: "whybis", file: "Valuate.lua", scope: EXPLAIN,
    label: "scales you have hidden are explained anyway",
    from: "ipairs(Valuate:GetActiveScales())", to: "pairs(Valuate:GetScales())" },

  // ---- self-verify (v0.100.0a) ---------------------------------------------
  { gate: "selfverify", file: "Valuate.lua",
    label: "'nothing owned carries Mastery' reads as 'Mastery parsing works'",
    from: 'return "skip", "Nothing you are wearing or carrying mentions',
    to: 'return "pass", "Nothing you are wearing or carrying mentions' },
  { gate: "selfverify", file: "Valuate.lua",
    label: "a tooltip word the parser missed is reported as a pass",
    from: "if got and got > 0 then", to: "if true then" },
  { gate: "selfverify", file: "Valuate.lua",
    label: "a class in NO template set passes, so CoA silently falls back to classic",
    from: '    return "fail", string.format(\n        "UnitClass says', to: '    return "pass", string.format(\n        "UnitClass says' },
  { gate: "selfverify", file: "Valuate.lua",
    label: "caches judged on one lookup, so a lucky first hit reads as 100%",
    from: "if total < SELF_VERIFY_MIN_HITS then", to: "if false then" },
  // Scoped when SelfCheckDungeonItems reused the same threshold. An anchor that was
  // unique when written does not stay unique, which is what the ambiguity guard is for.
  { gate: "selfverify", file: "Valuate.lua", scope: SC_CACHES,
    label: "a cold cache passes, hiding that the optimisation is not real on this client",
    from: "if pct >= 80 then", to: "if pct >= 0 then" },
  { gate: "selfverify", file: "Valuate.lua",
    label: "a check that returns nothing is recorded as a pass rather than a failure",
    from: 'status = status or "fail",', to: 'status = status or "pass",' },

  // ---- queue / release / leave (v0.105.0a) ---------------------------------
  { gate: "queuetest", file: "Valuate.lua",
    label: "releases while your raid is mid battle-rez, throwing the rez away",
    from: "if party > 0 or raid > 0 then", to: "if false then" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "leaves the battleground after you switched auto-leave off mid-countdown",
    from: "if not Valuate:GetOptions().autoLeaveBattleground then", to: "if false then" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "every repeated status event schedules another leave and another re-queue",
    from: "if bgLeaveScheduled then return end", to: "if false then return end" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "leaves the instant the match ends, ripping away the only record of it",
    from: "ValuateAfter(BG_LEAVE_DELAY, function()", to: "ValuateAfter(0, function()" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "queues for a battleground you cannot enter, or the wrong one entirely",
    from: "if isRandom and canEnter then", to: "if name then" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "queues again while still inside the match, landing you in a second one",
    from: "    if InBattleground() then\n        return false, \"Already in a battleground.\"",
    to: "    if false then\n        return false, \"Already in a battleground.\"" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "a missing client API is not named, so 'nothing happened' has no cause",
    from: 'return false, "No GetBattlegroundInfo() on this client - the battleground list cannot be read."',
    to: 'return false, "no"' },

  // ---- the defensive floor (v0.118.0a) -------------------------------------
  { gate: "defensive", file: "Valuate.lua",
    label: "52 CoA specs go back to scoring survivability at zero",
    from: "        if (out[stat] or 0) < floor then", to: "        if false then" },
  { gate: "defensive", file: "Valuate.lua",
    label: "the floor OVERRULES a weight the author deliberately set higher",
    from: "if (out[stat] or 0) < floor then", to: "if true then" },
  { gate: "defensive", file: "Valuate.lua",
    label: "the floor is absolute, so it is invisible on one spec and overwhelming on another",
    from: "local floor = top * fraction", to: "local floor = fraction" },
  { gate: "defensive", file: "Valuate.lua",
    label: "the shared template table is mutated, compounding on every later read",
    from: "    local out = {}\n    local top = 0", to: "    local out = weights\n    local top = 0" },
  { gate: "defensive", file: "Valuate.lua",
    label: "a tank is floored against its own top stat, gaining Armor it never asked for",
    from: '    if role == "TANK" then return out end', to: "" },

  // ---- equipping on level-up (v0.117.0a) -----------------------------------
  { gate: "equipsettest", file: "Valuate.lua",
    label: "gear is swapped mid-pull the instant you ding",
    from: 'return false, "In combat - will equip when you are out."', to: "local _ = 1" },
  { gate: "equipsettest", file: "Valuate.lua",
    label: "a deferred equip never happens, so levelling in combat silently does nothing",
    from: 'levelUpEquipPending = (reason == "In combat - will equip when you are out.")',
    to: "levelUpEquipPending = false" },
  { gate: "equipsettest", file: "Valuate.lua",
    label: "every fight you finish re-equips your gear, forever",
    from: "if fromCombatEnd and not levelUpEquipPending then return false", to: "if false then return false" },
  { gate: "equipsettest", file: "Valuate.lua",
    label: "a permanent refusal stays pending and fires after an unrelated fight",
    from: "        levelUpEquipPending = (reason ==", to: "        levelUpEquipPending = true or (reason ==" },

  // ---- best-in-slot as an equipment set (v0.115.0a) ------------------------
  { gate: "equipsettest", file: "Valuate.lua",
    label: "a set is overwritten silently, destroying one someone built by hand",
    from: "if existing == setName then exists = true break end", to: "" },
  { gate: "equipsettest", file: "Valuate.lua", scope: UNMATCHED_SLOTS,
    label: "bank gear blocks the save forever, so no set is ever written",
    from: 'best.source ~= "bank"', to: "true" },
  { gate: "equipsettest", file: "Valuate.lua",
    label: "your own enchanted copy reads as the wrong item, so the save never fires",
    from: "if wornId ~= GetItemIdFromLink(best.itemLink) then", to: "if worn ~= best.itemLink then" },
  { gate: "equipsettest", file: "Valuate.lua",
    label: "gear is swapped while you are in combat",
    from: 'return nil, "Not in combat - gear cannot be changed."', to: 'local _ = 1' },
  { gate: "equipsettest", file: "Valuate.lua",
    label: "'Raid ' and 'Raid' become two different equipment sets",
    from: "    setName = strtrim(setName)", to: "" },

  /* ---- each gate's HEADLINE CLAIM, violated on purpose (v0.114.0a) ---------
   *
   * Three gates in a row turned out to check something ADJACENT to what they claimed - a
   * read counted as "reachable", any print counted as "documented", and the snapshot
   * exclusion list had no gate at all. Each passed cleanly for months.
   *
   * So the remaining high-stakes claims were tested the only way that works: violate the
   * sentence on the tin and see whether the gate notices. All eight below were caught on
   * the first run, which is the result worth having - the three weak ones were the
   * exception. They live here so that stays true rather than being a thing I checked once.
   */
  { gate: "api", file: "Valuate.lua",
    label: "a method the selftest promises to check no longer exists",
    from: "function Valuate:GetCacheStats() return cacheStats end",
    to: "function Valuate:GetCacheStatsRENAMED() return cacheStats end" },
  { gate: "api", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    label: "an integration addon calls into Valuate for something that is not there",
    // The filter's call specifically; the file has another at line 380.
    from: "self:FirstEnabledScale(Valuate:IsBestInSlot(slotData.link))",
    to: "self:FirstEnabledScale(Valuate:IsBestInSlotNOPE(slotData.link))" },
  { gate: "tocsync", file: "Valuate.toc",
    label: "a ui module drops out of the .toc and simply stops loading",
    from: "ui\\Wizard.lua\n", to: "" },
  { gate: "globals", file: "ui/Wizard.lua",
    label: "a nil global is read - the silent failure this codebase's worst bugs were",
    from: "local _, ns = ...",
    to: "local _, ns = ...\nlocal __probe = SomeGlobalThatDoesNotExistAnywhere" },
  { gate: "contrast", file: "ui/Shared.lua",
    label: "a text colour stops clearing WCAG AA against the panel it is drawn on",
    from: "textDim = { 0.60, 0.64, 0.72, 1 },", to: "textDim = { 0.18, 0.19, 0.22, 1 }," },
  { gate: "speccoverage", file: "ui/Data.lua",
    label: "a class loses its templates, so the wizard can never match it",
    from: 'class = "Warrior"', to: 'class = "WarriorTYPO"' },
  { gate: "options", file: "Valuate.lua",
    label: "an automation ships defaulted ON, breaking the opt-in promise",
    from: "autoQueuePvP = false,", to: "autoQueuePvP = true," },
  { gate: "check", file: "ui/Wizard.lua",
    label: "StaticPopup is used again - the frame taint that broke CastSpellByName",
    from: "local _, ns = ...",
    to: 'local _, ns = ...\nlocal __t = StaticPopup_Show("X")' },

  // ---- /valuate help really is the source of truth (v0.114.0a) -------------
  // Removing a real help line must fail. Before v0.114.0a it did not: "documented" was
  // checked against every print in the file, so a command printing its own usage counted
  // as documenting itself. `trivial` is the case that exposed it.
  { gate: "commands", file: "Valuate.lua",
    label: "a command drops out of /valuate help and nothing notices",
    from: '        print("  /valuate trivial <levels> - How far below you a quest must be to be skipped")',
    to: "" },

  // ---- the login summary (v0.113.0a) ---------------------------------------
  { gate: "todotest", file: "Valuate.lua", scope: ANNOUNCE_TODO,
    label: "the login summary repeats every time anything triggers it",
    from: "if todoAnnounced then return false", to: "if false then return false" },
  { gate: "todotest", file: "Valuate.lua", scope: ANNOUNCE_TODO,
    label: "'nothing to do' re-checks forever, so the first new item announces itself mid-dungeon",
    from: "    todoAnnounced = true\n\n    local items", to: "\n    local items" },
  { gate: "todotest", file: "Valuate.lua", scope: ANNOUNCE_TODO,
    label: "an empty list still prints a summary of nothing",
    from: "if #items == 0 then return false", to: "if false then return false" },
  { gate: "todotest", file: "Valuate.lua", scope: ANNOUNCE_TODO,
    label: "switching the summary off does not switch it off",
    from: "if Valuate:GetOptions().todoOnLogin == false then", to: "if false then" },

  // ---- the gear to-do list (v0.112.0a) -------------------------------------
  { gate: "todotest", file: "Valuate.lua",
    label: "upgrades are listed above the stale scale that CHOSE them",
    from: '            kind = "scale",', to: '            kind = "zscale",' },
  { gate: "todotest", file: "Valuate.lua",
    label: "all seventeen slots are listed, so it stops being an answer",
    from: "for i = 1, math.min(3, #upgrades) do", to: "for i = 1, #upgrades do" },
  { gate: "todotest", file: "Valuate.lua", scope: TODO,
    label: "'Fill 0 empty sockets' - the list is never empty and stops being read",
    from: "    if sockets > 0 then", to: "    if sockets >= 0 then" },
  { gate: "todotest", file: "Valuate.lua",
    label: "the socket count is silently nil, so that item can never appear",
    from: "        local _, n = Valuate:FindEmptySockets()\n        sockets = n or 0",
    to: "        local n = Valuate:FindEmptySockets()\n        sockets = n or 0" },
  { gate: "todotest", file: "Valuate.lua",
    label: "an empty slot is not called out, so a huge gain looks like a remarkable item",
    from: 'detail = u.emptySlot and "That slot is empty." or nil,', to: "detail = nil," },

  // ---- the settings snapshot (v0.111.0a) -----------------------------------
  // The first of these IS the bug that shipped in v0.109.0a and sat unnoticed for two
  // releases: pvpScale travelling to an alt that has no such scale.
  { gate: "snapshottest", file: "Valuate.lua",
    label: "your Warrior's PvP scale name is copied onto a character that has no such scale",
    from: "    pvpScale = true,", to: "" },
  { gate: "snapshottest", file: "Valuate.lua",
    label: "mid-battleground bookkeeping is copied to an alt, which then 'restores' to nothing",
    from: "    pvpScaleRestore = true,", to: "" },
  { gate: "snapshottest", file: "Valuate.lua",
    label: "the active scale name travels, pointing every alt at a scale it does not have",
    from: "    characterWindowScale = true,", to: "" },
  { gate: "snapshottest", file: "Valuate.lua",
    label: "tables are copied by reference, aliasing two characters' settings to one object",
    from: 'if not SNAPSHOT_EXCLUDED[key] and type(value) ~= "table" then',
    to: "if not SNAPSHOT_EXCLUDED[key] then" },
  { gate: "snapshottest", file: "Valuate.lua",
    label: "an old snapshot can reintroduce an option that no longer exists",
    from: "if DEFAULT_OPTIONS[key] ~= nil and not SNAPSHOT_EXCLUDED[key] then",
    to: "if DEFAULT_OPTIONS[key] ~= nil then" },

  // ---- deriving the PvP scale (v0.110.0a) ----------------------------------
  { gate: "queuetest", file: "Valuate.lua",
    label: "running it twice overwrites the PvP scale you already tuned",
    from: "while scales[name] do", to: "while false do" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "the derived scale SHARES the source's weights - editing one edits both",
    from: "for stat, weight in pairs(base.Values) do scale.Values[stat] = weight end",
    to: "scale.Values = base.Values" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "a deliberate Resilience weight is overwritten by the convention",
    from: "if not scale.Values[stat] then", to: "if true then" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "PvP stats are assumed to be worth 1.0 rather than the source's real top weight",
    from: "scale.Values[stat] = top", to: "scale.Values[stat] = 1.0" },
  { gate: "queuetest", file: "Valuate.lua", scope: BUILD_PVP,
    label: "a source with no positive weights produces a scale that scores nothing",
    from: "if top <= 0 then", to: "if false then" },

  // ---- the PvP scale swap (v0.109.0a) --------------------------------------
  { gate: "queuetest", file: "Valuate.lua",
    label: "re-entry overwrites the restore target, stranding you on the PvP scale forever",
    from: "        if options.characterWindowScale == wanted then\n            return false, \"Already using it.\"",
    to: "        if false then\n            return false, \"Already using it.\"" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "switches to a scale that was deleted, so every score reads zero",
    from: "if not scales[wanted] then", to: "if false then" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "the restore marker is never cleared, so it fights you on every zone change",
    from: "options.pvpScaleRestore = nil\n\n    if restore == \"\" then",
    to: "\n    if restore == \"\" then" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "'no scale before' is forgotten, promoting the PvP scale to your default",
    from: "options.pvpScaleRestore = options.characterWindowScale or \"\"",
    to: "options.pvpScaleRestore = options.characterWindowScale" },

  // ---- toggle vs capability (v0.107.0a) ------------------------------------
  { gate: "selfverify", file: "Valuate.lua",
    label: "an armed automation the client cannot perform is reported as fine",
    from: "if #broken == 0 then", to: "if true then" },
  { gate: "selfverify", file: "Valuate.lua",
    label: "features you never switched on are reported as broken - noise you learn to ignore",
    from: "if options[need.opt] then", to: "if true then" },
  { gate: "selfverify", file: "Valuate.lua",
    label: "only the first API a feature needs is checked",
    from: "for _, api in ipairs(need.apis) do", to: "for _, api in ipairs({ need.apis[1] }) do" },
  { gate: "selfverify", file: "Valuate.lua",
    label: "nothing switched on reads as a pass rather than 'nothing to check'",
    from: 'return "skip", "None of the queue, release or leave automations are switched on."',
    to: 'return "pass", "None of the queue, release or leave automations are switched on."' },

  // ---- taking the port / missed pops (v0.106.0a) ---------------------------
  { gate: "queuetest", file: "Valuate.lua",
    label: "ports you into a battleground mid-fight",
    from: "elseif type(InCombatLockdown) == \"function\" and InCombatLockdown() then",
    to: "elseif false then" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "accepts a queue that has not popped, or declines instead of accepting",
    from: "pcall(AcceptBattlefieldPort, i, 1)", to: "pcall(AcceptBattlefieldPort, i, nil)" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "entering the battleground is mistaken for missing the pop, re-queueing you",
    from: 'elseif was == "confirm" and status == "none" then',
    to: 'elseif was == "confirm" then' },
  { gate: "queuetest", file: "Valuate.lua",
    label: "the previous status is never remembered, so a missed pop is undetectable",
    from: "bfStatusWas[i] = status", to: "bfStatusWas[i] = nil" },
  { gate: "queuetest", file: "Valuate.lua",
    label: "auto-accept fires even when switched off",
    from: 'if status == "confirm" and options.autoAcceptBattleground then',
    to: 'if status == "confirm" then' },

  // ---- missing enchants (v0.104.0a) ----------------------------------------
  { gate: "enchants", file: "Valuate.lua",
    label: "the item ID is read instead of the enchant, so nothing is EVER reported",
    from: 'itemLink:match("|?H?item:%d+:(%d+)")', to: 'itemLink:match("item:(%d+)")' },
  { gate: "enchants", file: "Valuate.lua",
    label: "an unreadable link is called unenchanted - a trip to the enchanter for nothing",
    from: "if link and LinkEnchantId(link) == 0 then", to: "if link and not LinkEnchantId(link) or (link and LinkEnchantId(link) == 0) then" },
  { gate: "enchants", file: "Valuate.lua",
    label: "every slot is checked, so rings and trinkets nag about enchants you cannot apply",
    from: "if ENCHANTABLE_SLOTS[def.slotId] then", to: "if true then" },
  { gate: "enchants", file: "Valuate.lua",
    label: "waist creeps into the enchantable set",
    from: "    [10] = true, [7] = true, [8] = true, [16] = true,",
    to: "    [10] = true, [7] = true, [8] = true, [16] = true, [6] = true," },

  // ---- empty sockets (v0.103.0a) -------------------------------------------
  { gate: "sockets", file: "Valuate.lua",
    label: "sockets you have already gemmed are counted, so the number never reaches zero",
    from: "if text:find(s, 1, true) == 1 then", to: "if text:find(s, 1, true) then" },
  // Scoped: "for i = 2, tooltip:NumLines()" also appears in TooltipUniqueLimit, and an
  // unscoped mutation lands there instead - breaking a function this gate never runs, which
  // is how a mutation "survives" while testing nothing.
  { gate: "sockets", file: "Valuate.lua", scope: COUNT_SOCKETS,
    label: "the item's NAME line is read, so an item called after a socket counts itself",
    from: "for i = 2, tooltip:NumLines() do", to: "for i = 1, tooltip:NumLines() do" },
  { gate: "sockets", file: "Valuate.lua", scope: FIND_SOCKETS,
    label: "items reorder between runs, so the socket list is never the same twice",
    from: "return a.slotId < b.slotId", to: "return false" },
  { gate: "sockets", file: "Valuate.lua",
    label: "the in-transit guard is relaxed - tooltips read mid equipment swap",
    from: "    if equipmentSwapPending then return nil, 0 end", to: "    if false then return nil, 0 end" },

  // ---- the cross-path agreement check (v0.101.0a) --------------------------
  { gate: "selfverify", file: "Valuate.lua",
    label: "two paths disagreeing about your gear is reported as agreement",
    from: "if worst <= SCORE_AGREEMENT_TOLERANCE then", to: "if true then" },
  { gate: "selfverify", file: "Valuate.lua",
    label: "a base-stat fallback is compared against a scaled read - a false alarm every time",
    from: "if isScaled and stats and viaSlot > 0 then", to: "if stats and viaSlot > 0 then" },
  { gate: "selfverify", file: "Valuate.lua",
    label: "nothing equipped reads as 'the paths agree' rather than 'nothing to compare'",
    from: "if compared == 0 then", to: "if false then" },

  // ---- the ranked upgrade list (v0.99.0a) ----------------------------------
  // Scoped since v0.115.0a: UnmatchedBestSlots excludes bank gear with the same line, and
  // an unscoped anchor would land there instead - breaking a function this gate never runs.
  { gate: "upgraderank", file: "Valuate.lua", scope: RANK_UPGRADES,
    label: "bank gear is offered as your next upgrade - advice you cannot act on",
    from: 'best.source ~= "bank"', to: "true" },
  // Scoped, because FindEmptySockets uses the same tiebreak line and sits EARLIER in the
  // file - an unscoped mutation lands there and breaks a function this gate never runs.
  { gate: "upgraderank", file: "Valuate.lua", scope: RANK_UPGRADES,
    label: "tied slots reorder between runs, so 'your biggest upgrade' changes identity",
    from: "return a.slotId < b.slotId", to: "return false" },
  { gate: "upgraderank", file: "Valuate.lua",
    label: "the list is not ranked at all - smallest gain can come first",
    from: "if a.gain ~= b.gain then return a.gain > b.gain end",
    to: "if a.gain ~= b.gain then return a.gain < b.gain end" },
  { gate: "upgraderank", file: "Valuate.lua",
    label: "gear already on your body is listed as an upgrade to itself",
    from: "if equippedId ~= GetItemIdFromLink(best.itemLink) then", to: "if true then" },
  { gate: "upgraderank", file: "Valuate.lua",
    label: "a downgrade is presented as an upgrade",
    from: "if gain > 0 then", to: "if gain >= 0 or true then" },
  { gate: "upgraderank", file: "Valuate.lua",
    label: "an empty slot is never flagged, so a huge gain looks like a great item",
    from: "emptySlot = equippedLink == nil,", to: "emptySlot = false," },

  // ---- the Alt-hover breakdown (v0.98.0a) ----------------------------------
  { gate: "whybis", file: "Valuate.lua", scope: DETAIL,
    label: "gear you should go and equip reads as a loss instead of a gain",
    from: '"%s  %.1f  |cFF00FF00+%.1f|r - rescan to pick it up"',
    to: '"%s  %.1f  |cFFFF8800-%.1f|r vs your best"' },
  { gate: "whybis", file: "Valuate.lua", scope: DETAIL,
    label: "an item the scale wants nothing of looks like a narrow loss",
    from: '"%s  |cFFAAAAAAnothing this scale wants|r"', to: '"%s  |cFFAAAAAAno weights set|r"' },
  { gate: "whybis", file: "Valuate.lua", scope: DETAIL,
    label: "scales are silently dropped from the breakdown",
    from: "lines[#lines + 1] = string.format(\"%s  |cFF00FF00best|r  %.1f\", named, e.score)",
    to: "local _ = named" },

  // ---- the near-miss tooltip line (v0.96.0a) -------------------------------
  { gate: "whybis", file: "Valuate.lua", scope: NEARMISS,
    label: "a near-miss line on every item - noise that trains you to stop reading",
    from: "if pct <= NEAR_MISS_RATIO and", to: "if true and" },
  { gate: "whybis", file: "Valuate.lua", scope: NEARMISS,
    label: "the least relevant scale is named instead of the closest",
    from: "not closestPct or pct < closestPct", to: "not closestPct or pct > closestPct" },
  { gate: "whybis", file: "Valuate.lua", scope: NEARMISS,
    label: "an item that would WIN is described as just short of winning",
    from: 'e.verdict == "beaten"', to: 'e.verdict ~= "x"' },
  { gate: "whybis", file: "Valuate.lua", scope: NEARMISS,
    label: "'0% behind' reads as a tie and invites you to keep something that lost",
    from: 'shown < 1 and "under 1%" or ', to: 'false and "under 1%" or ' },
  { gate: "whybis", file: "Valuate.lua", scope: NEARMISS,
    label: "the gap is a percentage of nothing - correct only when your best scores 100",
    from: "local pct = e.gap / e.bestScore", to: "local pct = e.gap / 100" },

  // ---- the dungeon leave suggestion (v0.120.0a) ----------------------------
  // This feature tells you to leave a dungeon. Its claim is "nothing left in here is an
  // upgrade"; its RIGHT to make that claim is "nothing left in here is unknown". Both
  // halves get broken here, because on a loot table this incomplete, the willingness to
  // stay quiet is the whole feature.
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_KNOWN,
    label: "a boss nobody filled in reads as a boss that drops nothing for you",
    from: "and type(boss.items) == \"table\" and #boss.items > 0", to: "" },
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_COUNT,
    label: "an unmapped boss stops counting as unknown, so a half-written table gives advice",
    from: "unknown = unknown + 1   -- no list at all", to: "unknown = unknown + 0   --" },
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_COUNT,
    label: "an item the client could not resolve is treated as a definite 'no'",
    from: "if answer == nil then unresolved = true end",
    to: "if answer == false then unresolved = true end" },
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_COUNT,
    label: "one unreadable item hides a real upgrade sitting further down the same list",
    from: "if answer == true then return true end", to: "if answer == true then return nil end" },

  // ---- trash and other things that cannot be killed (v0.121.0a) ------------
  // AtlasLoot lists "Trash Mobs" and vendor sections alongside real bosses. Counted as
  // bosses they would never die, the dungeon would never read as finished, and the prompt
  // would never fire at all - the feature would look switched off rather than broken.
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_COUNT,
    label: "trash is counted as a boss you still have to kill, so the dungeon never ends",
    from: "for _, section in ipairs(dungeon.extra or {}) do",
    to: "for _, section in ipairs(dungeon.bosses) do" },
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_COUNT,
    label: "trash loot stops counting as a reason to stay",
    from: "    for _, section in ipairs(dungeon.extra or {}) do", to: "    for _, section in ipairs({}) do" },

  // ---- gear versus everything else (v0.121.0a) -----------------------------
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_ITEM,
    label: "a recipe or a bag reads as 'cannot tell', so a boss that drops one blocks the prompt forever",
    from: 'if equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" or equipLoc == "INVTYPE_BAG" then',
    to: "if false then" },
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_COUNT,
    label: "a boss you already killed is still counted as standing between you and the door",
    from: "if not killed[boss.name] then", to: "if true then" },
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua", scope: D_GET,
    label: "an unlisted dungeon returns an answer instead of silence",
    from: "return ns.DUNGEON_LOOT[instanceName]",
    to: "return ns.DUNGEON_LOOT[instanceName] or { bosses = {} }" },

  { gate: "dungeonloot", file: "Valuate.lua", scope: D_CONSIDER,
    label: "it offers to leave while bosses it knows nothing about are still alive",
    from: "if status.unknown > 0 then", to: "if false then" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_CONSIDER,
    label: "it offers to leave with an upgrade still ahead of you - the Mr Smite case",
    from: "if status.upgrades > 0 then return end", to: "if false then return end" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_CONSIDER,
    label: "the prompt fires again on every later kill instead of once",
    from: "if dungeonLeaveOffered then return end", to: "if false then return end" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_CONSIDER,
    label: "a switched-off automation runs anyway",
    from: "if not options.notifyDungeonNoUpgrades then return end", to: "if false then return end" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_ITEM,
    label: "an item missing from the client cache is scored as 'not an upgrade'",
    from: "if not link then return nil end", to: "if not link then return false end" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_ITEM,
    label: "an item whose tooltip parsed to nothing is scored as 'not an upgrade'",
    from: "then return nil end -- parsed nothing", to: "then return false end --" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_CURRENT,
    label: "raids and the open world are treated as 5-man dungeons",
    from: "if instanceType ~= \"party\" then return nil end", to: "if false then return nil end" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_TRACK,
    label: "the loudest event in the game stays registered everywhere, forever",
    from: "local want = Valuate:GetOptions().notifyDungeonNoUpgrades and Valuate:GetCurrentDungeon() ~= nil",
    to: "local want = true" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_NOTE,
    label: "the prompt fires on the kill, before the corpse has been looted",
    from: "ValuateAfter(6, function() Valuate:ConsiderDungeonLeave() end)",
    to: "Valuate:ConsiderDungeonLeave()" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_RESET,
    label: "a second run of the same dungeon inherits the first run's kills",
    from: "    dungeonKilled = {}", to: "    if true then return end" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: D_CONSIDER,
    label: "it offers to leave a dungeon that is already finished, which is just noise",
    from: "if status.remaining <= 0 then return end", to: "if false then return end" },

  // ---- the harvested loot table (v0.121.0a) --------------------------------
  // The table is generated from AtlasLoot, so the failure that matters is not a wrong id -
  // it is a generator that quietly harvests NOTHING and leaves a syntactically perfect file
  // that makes the whole feature a no-op while every other assertion still passes.
  { gate: "dungeonloot", file: "ui/DungeonLoot.lua",
    label: "the harvested table collapses to a handful of dungeons",
    from: 'ns.DUNGEON_LOOT = {', to: 'ns.DUNGEON_LOOT = {} ns.UNUSED_LOOT = {' },

  // ---- the spec tooltip (v0.122.0a) ----------------------------------------
  // The tooltip is the last thing between a user and committing to a template. Every
  // mutation here is a way for it to look fine while telling you less than it knows.
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "a spec whose weights were GUESSED is offered as confidently as a researched one",
    from: "if template.inferred then", to: "if false then" },
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "every spec is stamped with the guess warning, so the warning means nothing",
    from: "if template.inferred then", to: "if true then" },
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "the stat list reshuffles between two hovers of the same button",
    from: "        table.sort(ranked, function(a, b)", to: "        local _ = function(a, b)" },
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "the priority is listed lightest-first, so the top line is the least important stat",
    from: "if a.weight ~= b.weight then return a.weight > b.weight end",
    to: "if a.weight ~= b.weight then return a.weight < b.weight end" },
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "the list stops at five and looks complete, hiding everything else the spec wants",
    from: 'GameTooltip:AddLine("  and " .. rest .. " more", 0.5, 0.5, 0.5)',
    to: "local _ = rest" },
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "the weights are named but never shown, so there is nothing to check",
    from: '"  " .. (names[e.stat] or e.stat), string.format("%.2f", e.weight),',
    to: '"  " .. (names[e.stat] or e.stat), "",' },
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "the description is dropped and the tooltip repeats the button again",
    from: "GameTooltip:AddLine(template.description, 0.9, 0.9, 0.9, true)",
    to: "local _ = template.description" },
  { gate: "spectip", file: "ui/Pickers.lua", scope: SPEC_TIP,
    label: "the numbers appear with no heading saying what they are",
    from: 'GameTooltip:AddLine("Values most:", 0.6, 0.6, 0.6)', to: "local _ = 1" },

  // ---- the guess has to outlive the click (v0.123.0a) ----------------------
  // v0.122.0a made the picker admit six specs have weights nobody published. That warning
  // lasted ONE HOVER: both creation paths dropped the flag, so the scale it made was
  // indistinguishable from a researched one for as long as you used it. Each mutation here
  // puts it back to that.
  { gate: "inferred", file: "ui/ScaleEditor.lua", scope: FROM_TEMPLATE,
    label: "From Template forgets the weights were a guess the instant you click",
    from: "Inferred = template.inferred or nil,", to: "Inferred = nil," },
  { gate: "inferred", file: "ui/ScaleEditor.lua", scope: FROM_TEMPLATE,
    label: "every scale built from a template claims to be a guess",
    from: "Inferred = template.inferred or nil,", to: "Inferred = true," },
  { gate: "inferred", file: "Valuate.lua", scope: PLAN_AUTO,
    label: "the wizard loses the flag between matching a spec and describing the plan",
    from: "inferred = spec.inferred or nil,", to: "inferred = nil," },
  { gate: "inferred", file: "Valuate.lua", scope: COMMIT_AUTO,
    label: "the plan carries the flag and the committed scale drops it anyway",
    from: "Inferred = plan.inferred or nil,", to: "Inferred = nil," },
  { gate: "inferred", file: "ui/ScaleEditor.lua", scope: EDITOR_SUMMARY,
    label: "the flag is stored and never shown - the code looks like it works",
    from: "if scale.Inferred then", to: "if false then" },
  { gate: "inferred", file: "ui/ScaleEditor.lua", scope: EDITOR_SUMMARY,
    label: "every scale is warned about, so the warning stops meaning anything",
    from: "if scale.Inferred then", to: "if true then" },

  // ---- the settings column balance (v0.125.0a) -----------------------------
  // The measurement is the whole rule. A panel that reports nothing, or reports the same
  // number three times, satisfies a balance check trivially and forever.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "the panel stops reporting how full its columns are, so balance can never be checked again",
    from: "parent.columnContentHeights = { columnHeights[1], columnHeights[2], columnHeights[3] }",
    to: "parent.columnContentHeights = nil" },
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "every column reports the tallest height, so the check passes on any layout",
    from: "parent.columnContentHeights = { columnHeights[1], columnHeights[2], columnHeights[3] }",
    to: "parent.columnContentHeights = { tallest, tallest, tallest }" },
  // Aimed at the THRESHOLD, not the layout. A fixed pixel amount judged against a ratio
  // goes stale every time the columns get better balanced - this was resized once already
  // and drifted under the line again at 91%. Breaking the check itself tests the same claim
  // and cannot expire.
  { gate: "settingstest", file: "tools/settingstest.js",
    label: "the column balance assertion is never reached",
    from: "ok(ratio >= 0.60, string.format(", to: "ok(ratio >= 0.99, string.format(" },

  // ---- the empty Best Equipment screen (v0.126.0a) -------------------------
  // The first screen a new user reaches. Its only job is to name the next action, and it
  // named one that did not exist - "activate a scale" to someone who had never made one.
  { gate: "firstrun", file: "ui/BestEquipment.lua", scope: BE_EMPTY,
    label: "both empty states collapse back into one message, wrong for the more common half",
    from: "if haveAny then", to: "if true then" },
  { gate: "firstrun", file: "ui/BestEquipment.lua", scope: BE_EMPTY,
    label: "someone with scales switched off is told to go and make one they already have",
    from: "if haveAny then", to: "if false then" },
  { gate: "firstrun", file: "ui/BestEquipment.lua", scope: BE_EMPTY,
    label: "having any scale at all stops being detected, so first-run wording never appears",
    from: "for _ in pairs(scales) do haveAny = true break end", to: "haveAny = true" },
  { gate: "firstrun", file: "ui/BestEquipment.lua", scope: BE_EMPTY,
    label: "the empty screen is blank - the panel just looks broken",
    from: "noScalesTextFrame:Show()", to: "noScalesTextFrame:Hide()" },

  // ---- the About panel measuring itself (v0.127.0a) ------------------------
  // The fixed 400px was not an approximation, it was the reason the feature list went a year
  // stale: the panel warned that adding to the list would clip it, so nobody added.
  { gate: "aboutfits", file: "ui/InfoPanels.lua", scope: ABOUT,
    label: "the panel goes back to a constant height, so any content 'fits' forever",
    from: "local measured = math.abs(currentY) + 20", to: "local measured = 400" },
  { gate: "aboutfits", file: "ui/InfoPanels.lua", scope: ABOUT,
    label: "the feature list drops back to the version that was a year behind the addon",
    from: '"• Make me a scale - builds one from the gear you are already wearing\\n" ..', to: "" },

  // The harness's own measurement. A GetStringHeight that ignores its text turns every
  // layout assertion in the project into a count of how many font strings exist.
  { gate: "aboutfits", file: "tools/luaharness.js",
    label: "string height stops depending on the string, and layout gates measure nothing",
    from: "return lines * 12", to: "return 12" },

  // ---- the self-checks for the harvested loot table (v0.128.0a) ------------
  // These are the only things that will ever settle whether 2,918 ids taken out of AtlasLoot
  // are real on this server. A wrong verdict here is worse than no verdict: it is a green
  // line about data nobody has tested.
  { gate: "selfverify", file: "Valuate.lua", scope: SC_ITEMS,
    label: "a completely cold cache reports PASS, so untested ids look verified",
    from: 'if resolved == 0 then', to: "if false then" },
  { gate: "selfverify", file: "Valuate.lua", scope: SC_ITEMS,
    label: "any resolution rate at all counts as success, so a broken table passes",
    from: "if pct >= 80 then", to: "if pct >= 0 then" },
  { gate: "selfverify", file: "Valuate.lua", scope: SC_ITEMS,
    label: "the ambiguous middle is reported as a definite failure instead of 'run it again'",
    from: '    return "skip", string.format(\n        "Only %d%% of %d sampled ids resolved',
    to: '    return "fail", string.format(\n        "Only %d%% of %d sampled ids resolved' },
  { gate: "selfverify", file: "Valuate.lua", scope: SC_ITEMS,
    label: "a generator that harvested nothing reads as fine",
    from: 'if #ids == 0 then', to: "if false then" },

  { gate: "selfverify", file: "Valuate.lua", scope: SC_KEYS,
    label: "a dungeon whose name does not match reports PASS - the silent failure stays silent",
    from: '    return "fail", string.format(\n        "\\"%s\\" is not in the loot table',
    to: '    return "pass", string.format(\n        "\\"%s\\" is not in the loot table' },
  { gate: "selfverify", file: "Valuate.lua", scope: SC_KEYS,
    label: "standing in the open world is judged as a real result rather than skipped",
    from: 'if instanceType ~= "party" then', to: "if false then" },

  // ---- the wizard's failure screen (v0.129.0a) -----------------------------
  // The most likely way to reach it is a brand-new character wearing nothing, on the first
  // screen of an addon they installed a minute ago. It used to print to chat and leave the
  // window where it was: a button that appears to do nothing, with the explanation behind
  // the window that just failed to respond.
  { gate: "wizarduitest", file: "ui/Wizard.lua", scope: WIZ_PLAN,
    label: "the reason goes back to chat and the wizard just sits there",
    from: "if screens.failed then", to: "if false then" },
  { gate: "wizarduitest", file: "ui/Wizard.lua", scope: WIZ_PLAN,
    label: "the failure screen appears but says nothing about what went wrong",
    from: "screens.failed.reason:SetText(message)", to: "local _ = message" },
  { gate: "wizarduitest", file: "ui/Wizard.lua", scope: WIZ_FAILED,
    label: "the screen no longer says nothing was created, leaving 'what did it do to me' open",
    from: '"Nothing was created or changed. Fix the above and try again, or build a scale by " ..',
    to: '"" .. ' },
  { gate: "wizarduitest", file: "ui/Wizard.lua", scope: WIZ_FAILED,
    label: "a dead end - Close only, with the fix one screen away and no way back to it",
    from: 'local retry = ns.CreateStyledButton(f, "Try again", 150, BUTTON_HEIGHT + 4)',
    to: 'local retry = ns.CreateStyledButton(f, "Close", 150, BUTTON_HEIGHT + 4)' },

  // ---- the hit cap (v0.130.0a) ---------------------------------------------
  // Two failure directions, opposite in kind. Not capping over-values a dead stat; capping on
  // a GUESS mis-ranks every hit item in a direction nobody can see. The second is worse.
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_FACTOR,
    label: "hit past the cap is valued in full again - the bug the feature exists for",
    from: "if headroom <= 0 then return 0 end", to: "if headroom <= 0 then return 1 end" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_FACTOR,
    label: "an item that overshoots the cap is counted whole instead of up to the cap",
    from: "return headroom / itemPercent", to: "return 1" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_FACTOR,
    label: "it acts on an UNCALIBRATED conversion - capping on a number nobody derived",
    from: "if not state or not state.calibrated or not itemRating or itemRating <= 0 then return 1 end",
    to: "if not state or not itemRating or itemRating <= 0 then return 1 end" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_FACTOR,
    label: "a switched-off scoring model changes your scores anyway",
    from: "if not Valuate:GetOptions().hitCapAware then return 1 end", to: "" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_STATE,
    label: "the conversion is assumed rather than derived, so it claims calibration it lacks",
    from: "if rating > 0 and percent > 0 then", to: "if true then" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_STATE,
    label: "headroom can go negative, so being over the cap reads as room to spare",
    from: "headroom = math.max(0, cap - percent),", to: "headroom = cap - percent," },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_STATE,
    label: "everyone gets the melee cap, so casters are told to stack an extra 1%",
    from: 'local key = ScaleIsCaster(scale) and "spell" or "melee"', to: 'local key = "melee"' },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_STATE,
    label: "the target level is ignored, so a raid cap is applied while levelling",
    from: "local gap = tonumber(options.hitCapTargetGap) or 0", to: "local gap = 0" },
  { gate: "hitcap", file: "Valuate.lua", scope: CASTER_TEST,
    label: "caster and melee builds are told apart backwards",
    from: "return caster > physical", to: "return physical > caster" },

  // ---- diminishing value: a preference, and it has to behave like one ------
  { gate: "hitcap", file: "Valuate.lua", scope: DIM_FACTOR,
    label: "a preference that reorders your gear turns itself on",
    from: "if not options.diminishingReturns then return 1 end", to: "" },
  { gate: "hitcap", file: "Valuate.lua", scope: DIM_FACTOR,
    label: "the curve falls twice as fast as the setting says it will",
    from: "return 1 / (1 + (have / half))", to: "return 1 / (1 + (have / half) * 2)" },
  { gate: "hitcap", file: "Valuate.lua", scope: DIM_FACTOR,
    label: "the taper reaches zero, making heavily-stacked items unrankable against each other",
    from: "return 1 / (1 + (have / half))", to: "return math.max(0, 1 - (have / half))" },
  { gate: "hitcap", file: "Valuate.lua",
    label: "primary stats are tapered too, though they do not work that way",
    from: "local DIMINISHING_RATINGS = {",
    to: "local DIMINISHING_RATINGS = setmetatable({}, { __index = function() return { melee = 11, spell = 11 } end })\nlocal _UNUSED = {" },

  // ---- saying why the number moved (v0.131.0a) -----------------------------
  // A silent scoring adjustment is worse than none: you cannot tell a working addon from a
  // broken one. Each of these puts the silence back in a different place.
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_LINE,
    label: "a capped item says nothing, so a good item looks bad for no visible reason",
    from: "if state.headroom <= 0 then", to: "if false then" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_LINE,
    label: "an uncalibrated character is told nothing, which reads as having headroom",
    from: "if not state.calibrated then", to: "if false then" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_LINE,
    label: "the wasted portion is reported in percent, not the rating printed on the item",
    from: "local usefulRating = math.floor(state.headroom * state.perPercent + 0.5)",
    to: "local usefulRating = math.floor(state.headroom + 0.5)" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_LINE,
    label: "builds that ignore hit are lectured about a cap costing them nothing",
    from: "if not scale or not scale.Values or not scale.Values.HitRating", to: "if false and (nil" },

  // ---- what the after-the-fact sweep found (v0.132.0a) ---------------------
  // Shipping the hit cap left two holes, and neither showed up while writing it.
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_FACTOR,
    label: "the piece keeping you capped scores nothing, so you are told to replace it",
    from: "if worn then headroom = headroom + itemPercent end", to: "" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_FACTOR,
    label: "every item is treated as already worn, so nothing is ever capped",
    from: "if worn then headroom = headroom + itemPercent end",
    to: "headroom = headroom + itemPercent" },
  { gate: "hitcap", file: "Valuate.lua", scope: HIT_FACTOR,
    label: "headroom is read from the clamped field, hiding how far past the cap you are",
    from: "local headroom = state.cap - state.percent", to: "local headroom = state.headroom" },
  { gate: "hitcap", file: "Valuate.lua", scope: BREAKDOWN,
    label: "the breakdown disagrees with the score it exists to explain",
    from: "            if bdAdjusting then", to: "            if false then" },
  { gate: "hitcap", file: "Valuate.lua", scope: BREAKDOWN,
    label: "an adjusted line is not marked, so a smaller number has no visible reason",
    from: "                if factor < 1 then capped = true end", to: "" },
  { gate: "hitcap", file: "Valuate.lua", scope: BREAKDOWN,
    label: "every line is marked adjusted, so the marker stops meaning anything",
    from: "                if factor < 1 then capped = true end", to: "                capped = true" },

  // ---- the comparison tooltip (v0.133.0a) ----------------------------------
  // The most-read tooltip in the addon, and the only place where both questions - what would
  // this ADD, and what would I LOSE - are asked at once.
  { gate: "hitcap", file: "Valuate.lua", scope: CMP_BREAKDOWN,
    label: "the comparison ignores the cap entirely, disagreeing with the score beneath it",
    from: 'if statName == "HitRating" and Valuate:GetOptions().hitCapAware then', to: "if false then" },
  { gate: "hitcap", file: "Valuate.lua", scope: CMP_BREAKDOWN,
    label: "your equipped hit is valued as if you were not wearing it, so your own gear reads as worthless",
    from: "local equippedFactor = HitValueFactor(equippedValue, scale, true)",
    to: "local equippedFactor = HitValueFactor(equippedValue, scale, false)" },
  { gate: "hitcap", file: "Valuate.lua", scope: CMP_BREAKDOWN,
    label: "the candidate is valued as if already worn, so capped hit looks like an upgrade",
    from: "local hoverFactor = HitValueFactor(hoverValue, scale, false)",
    to: "local hoverFactor = HitValueFactor(hoverValue, scale, true)" },
  { gate: "hitcap", file: "Valuate.lua", scope: CMP_BREAKDOWN,
    label: "the adjusted row is not flagged, so the numbers move with nothing to explain them",
    from: "if hoverFactor < 1 or equippedFactor < 1 then cmpAdjusted = true end", to: "" },

  // ---- the worn sweep (v0.134.0a) ------------------------------------------
  // NOT mutation-tested, deliberately, and the reason is worth writing down.
  //
  // Two of the seven call sites the worn fix touched are guarded STRUCTURALLY by the
  // equipped-scores-are-worn lint rule rather than behaviourally by a gate. Mutations for
  // them were written and both SURVIVED - not because the assertions are weak, but because
  // no gate can see those lines: selfverify mocks the very function whose argument changed,
  // and ScanBestEquipment is five hundred lines of tooltip scraping that cannot be sliced.
  //
  // Contorting either fixture until the mutation died would have produced a test that
  // passes rather than a test that checks. The lint rule is the real guard; recording that
  // honestly beats a green line that means nothing.

  // ---- the upgrade popup (v0.138.0a) ---------------------------------------
  // 285 lines that interrupt you and then change your gear, with no gate on any of it until
  // now. Its two equip paths disagreed about ORDER, and the more prominent one was worse.
  { gate: "popuptest", file: "ui/UpgradePopup.lua", scope: POPUP_EQUIP,
    label: "a click that cannot work in combat still takes the upgrade off your screen",
    from: "if InCombatLockdown() then", to: "if false then" },
  { gate: "popuptest", file: "ui/UpgradePopup.lua", scope: POPUP_EQUIP,
    label: "the popup refuses out of combat too, so Equip never works at all",
    from: "if InCombatLockdown() then", to: "if true then" },
  { gate: "popuptest", file: "ui/UpgradePopup.lua", scope: POPUP_EQUIP,
    label: "it equips but never closes, so a done deal keeps asking",
    // Single-line anchor: this file is CRLF, so a `\n` in a multi-line anchor matches
    // nothing and the guard reports UNAPPLIED rather than letting it pass silently.
    from: "        Valuate:HideUpgradePopup()", to: "        local _ = 1" },

  // ---- compiling every file, not just the parsed ones (v0.139.0a) ---------
  // The gate exists because luaparse is more permissive than the game. If it ever stops
  // covering everything, or stops failing on a real compile error, it is worse than absent:
  // it is a green line saying the client can load files nobody compiled.
  { gate: "compileall", file: "tools/compileall.js",
    label: "the self-check is inert, so a broken compile check would report all clear",
    from: '["local x = 1 + 1 return x", true, "ordinary valid Lua"],',
    to: '["local x = 1 + 1 return x", false, "ordinary valid Lua"],' },
  { gate: "compileall", file: "tools/compileall.js",
    label: "the scan silently covers nothing, so every file passes by not being looked at",
    from: "    } else if (entry.name.endsWith(\".lua\")) {", to: "    } else if (false) {" },

  // ---- a weak match explains itself (v0.140.0a) ----------------------------
  // caution was a boolean and the wizard does SetText(plan.caution or ""), so an unsure match
  // called SetText(true) - on exactly the low-level characters that needed the explanation.
  { gate: "autowizard", file: "Valuate.lua", scope: PLAN_AUTO,
    label: "caution goes back to a boolean, so the wizard hands SetText(true) to the client",
    from: "caution = (score < MATCH_UNSURE) and string.format(", to: "caution = (score < MATCH_UNSURE) and true and (" },
  { gate: "autowizard", file: "Valuate.lua", scope: PLAN_AUTO,
    label: "every match cautions, and a warning on everything is a warning on nothing",
    from: "caution = (score < MATCH_UNSURE) and string.format(", to: "caution = true and string.format(" },
  { gate: "autowizard", file: "Valuate.lua", scope: PLAN_AUTO,
    label: "a weak match says nothing at all, which is where this started",
    from: "caution = (score < MATCH_UNSURE) and string.format(", to: "caution = false and string.format(" },

  // ---- an ungated check announces itself (v0.141.0a) -----------------------
  // The checks carrying the most weight were distinguishable from the ones carrying least
  // only by an absence - which is the failure the checklist exists to catch, built into the
  // checklist.
  { gate: "verifytest", file: "Valuate.lua",
    label: "an ungated check says nothing, so the ones that matter most look ordinary",
    from: '        print("   |cFFFF8833Nothing else proves this.|r', to: '        local _ = ("' },
  { gate: "verifytest", file: "Valuate.lua",
    scope: {
      start: "local function PrintVerifyCheck(",
      end: "\n-- Marks a check done",
    },
    label: "every check claims a gate, including the ones that have none",
    from: "    if c.gate then", to: "    if true then" },

  // ---- the guess mark in the scale list (v0.142.0a) ------------------------
  // The list is where you choose BETWEEN scales, and a guessed one looked like every other
  // row. The mark and its explanation shipped together on purpose: v0.133.0a shipped a
  // symbol with no key and had to come back two releases later to explain it.
  { gate: "scalelisttest", file: "ui/ScaleList.lua",
    label: "a guessed scale is unmarked in the list, so you cannot tell while choosing",
    from: "if scale.Inferred then guessMark:Show() else guessMark:Hide() end",
    to: "guessMark:Hide()" },
  { gate: "scalelisttest", file: "ui/ScaleList.lua",
    label: "every scale is marked as a guess, so the mark marks nothing",
    from: "if scale.Inferred then guessMark:Show() else guessMark:Hide() end",
    to: "guessMark:Show()" },
  { gate: "scalelisttest", file: "ui/ScaleList.lua",
    label: "the guess reuses the gold star that already means current spec",
    from: 'guessMark:SetText("|cFFFF8833?|r")', to: 'guessMark:SetText("|cFFFFD100*|r")' },

  // ---- where to go for an upgrade (v0.143.0a) ------------------------------
  // 2,918 item ids sat unused while the only way to learn whether a dungeon held anything
  // for you was to be standing in it. Every rule here is the same one: do not present a
  // guess as a finding.
  { gate: "dungeonloot", file: "Valuate.lua", scope: WHERE,
    label: "it recommends gear you cannot wear yet, putting a level 10 in a raid",
    from: "and (tonumber(minLevel) or 0) <= myLevel then", to: "then" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: WHERE,
    label: "an item the client cannot read is silently dropped instead of counted",
    from: "unknown = unknown + 1   -- never fetched", to: "unknown = unknown + 0   --" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: WHERE,
    label: "the biggest upgrade is no longer the answer given first",
    from: "if a.best ~= b.best then return a.best > b.best end",
    to: "if a.best ~= b.best then return a.best < b.best end" },
  { gate: "dungeonloot", file: "Valuate.lua", scope: WHERE,
    label: "non-gear counts as an upgrade, so a recipe sends you to a dungeon",
    from: 'elseif equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG"',
    to: "elseif true" },

  // ---- naming the slot, not counting it (v0.144.0a) ------------------------
  { gate: "dungeonloot", file: "Valuate.lua", scope: WHERE,
    label: "the slots are computed and thrown away, so a dungeon says nothing about WHY to go",
    from: "if not slots[slotName] then slots[slotName] = true end", to: "local _ = slotName" },

  // ---- auto-equip upgrades (v0.145.0a) --------------------------------------
  // The most consequential automation here: it changes your gear with no press, and can bind
  // a BoE you just looted. Every mutation is a guard removed.
  { gate: "options", file: "Valuate.lua",
    label: "the automation that changes your gear without asking defaults to ON",
    from: "    autoEquipUpgrades = false,", to: "    autoEquipUpgrades = true," },

  // ---- automations that never met each other (v0.146.0a) -------------------
  // Auto-equip creates an item in your bags; auto-delete runs on the bag update that
  // follows; every other protection has just stopped applying to it by design. Deletion has
  // no undo, so each guard here gets broken on purpose.
  { gate: "deletetest", file: "Valuate.lua",
    label: "gear auto-equip just took off you is deletable - deletion has no undo",
    from: '        return true, "just replaced by auto-equip"', to: '        return false, "x"' },
  { gate: "deletetest", file: "Valuate.lua",
    label: "the grace period never expires, so old gear becomes immortal",
    from: "if now - at > Valuate.displaced.grace or now < at then", to: "if false then" },
  { gate: "deletetest", file: "Valuate.lua",
    label: "a clock that ran backwards pins the protection forever",
    from: "or now < at then", to: "then" },
  { gate: "deletetest", file: "Valuate.lua",
    label: "marking one item protects everything in your bags",
    from: "    if not at then return false end", to: "    if not at then return true end" },

  // ---- rescuing gear from the junk pile (v0.147.0a) ------------------------
  // Writes to ANOTHER ADDON'S state, and the direction is the dangerous part: marking
  // something as junk is a judgement about worth that this addon has no business making.
  { gate: "deletetest", file: "Valuate.lua",
    label: "it un-junks everything, including genuine junk, refilling the pile you emptied",
    from: "                    local protected, why = IsProtectedFromDelete(bag, slot, link)", to: "                    local protected, why = true, \"x\"" },
  { gate: "deletetest", file: "Valuate.lua",
    label: "it sends a junk SECTION, so the rescue marks items as junk instead",
    from: 'AdiBags:SendMessage("AdiBags_OverrideFilter", nil, nil, itemId)', to: 'AdiBags:SendMessage("AdiBags_OverrideFilter", "Junk", nil, itemId)' },
  { gate: "deletetest", file: "Valuate.lua",
    label: "a switched-off automation edits another addon anyway",
    from: "    if not verbose and not options.autoUnjunkProtected then return 0 end", to: "" },
];
