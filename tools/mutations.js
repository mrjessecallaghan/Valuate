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

// The .toc's version, READ rather than written down here.
//
// One mutation needs it as an anchor, and it is the single thing in this file that changes
// every release. Hardcoded, it goes stale the moment the version is bumped and the mutation
// reports UNAPPLIED - "this is testing nothing" - on exactly the releases nobody is looking
// at it. It did, for v0.176 and v0.177.
const TOC_VERSION =
  (require("fs")
    .readFileSync(require("path").join(__dirname, "..", "Valuate.toc"), "utf8")
    .match(/^##\s*Version:\s*(\S+)/m) || [])[1];

// Far enough ahead that no amount of checklist growth can bring it back to the boundary.
// Pinned at a literal, this mutation twice drifted into being equivalent as the checklist
// caught up - each time reporting SURVIVED for a rule that was working perfectly.
const FAR_FUTURE_VERSION = (function () {
  // No pattern here on purpose. This constant was once derived from the .toc and silently
  // stopped being derived: the shell ate both backslashes out of the expression that read the
  // version, leaving one that matches the LETTER d rather than a digit - so it matched no
  // version string that has ever existed. That fed an || fallback, so every run quietly
  // substituted a hardcoded number, which is the exact thing the comment above says this
  // function exists to prevent. A fallback is not an error, so nothing reported it.
  //
  // split() has no escapes to lose, and an unreadable version now THROWS instead of
  // substituting a number nobody chose. tools/toolsource.js watches for the rest of the class.
  const parts = String(TOC_VERSION || "").split(".");
  const minor = Number(parts[1]);
  if (parts.length < 2 || !Number.isFinite(minor)) {
    throw new Error(
      "mutations.js cannot read a minor version out of Valuate.toc (" + TOC_VERSION + "). " +
        "FAR_FUTURE_VERSION has to sit far past the checklist or its mutation proves nothing."
    );
  }
  return parts[0] + "." + (minor + 60) + ".0a";
})();
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
    from: "## Version: " + TOC_VERSION, to: "## Version: " + FAR_FUTURE_VERSION },
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
    // The print( prefix went away in v0.148.0a when the help lines moved into the grouped
    // table. The line itself was moved, not reworded, so the anchor is the literal alone.
    from: '                "  /valuate trivial <levels> - How far below you a quest must be to be skipped",',
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
  //
  // NO MUTATION HERE, deliberately, and this note is the reason.
  //
  // This used to break the idempotence guard - "already on it, do nothing" - to prove the
  // restore target could not be overwritten with the PvP scale, stranding you on it. When
  // v0.175.0a added dungeon and outdoor contexts it also added a second guard: the restore
  // slot is only written when it is empty, because a battleground-to-dungeon hop would
  // otherwise record the BATTLEGROUND scale as "what you were using".
  //
  // Those two guards now cover the same failure, so either one alone is removable with no
  // observable change - an EQUIVALENT mutation, not a test gap. Confirmed the way CLAUDE.md
  // says to: removing BOTH fails three assertions in queuetest.js, so the pair is jointly
  // load-bearing. Neither is deleted on the strength of the other, and no test was weakened
  // to manufacture a catch.
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
  // Scoped: v0.177.2a gave the SELL path the same line, so an unscoped anchor lands on
  // whichever comes first in the file rather than on the one this gate exercises.
  { gate: "deletetest", file: "Valuate.lua",
    scope: { start: "function Valuate:AutoUnjunkProtected", end: "\n-- opts is `true` for the chatty on-demand form" },
    label: "it un-junks everything, including genuine junk, refilling the pile you emptied",
    from: "                    local protected, why = IsProtectedFromDelete(bag, slot, link)", to: "                    local protected, why = true, \"x\"" },
  { gate: "deletetest", file: "Valuate.lua",
    label: "it sends a junk SECTION, so the rescue marks items as junk instead",
    from: 'AdiBags:SendMessage("AdiBags_OverrideFilter", nil, nil, itemId)', to: 'AdiBags:SendMessage("AdiBags_OverrideFilter", "Junk", nil, itemId)' },
  { gate: "deletetest", file: "Valuate.lua",
    label: "a switched-off automation edits another addon anyway",
    from: "    if not verbose and not options.autoUnjunkProtected then return 0 end", to: "" },

  // ---- grouped help (v0.148.0a) ---------------------------------------------
  // 74 commands as one flat list is seven screens of scrollback. The risk in grouping them
  // is a group that silently stops being reachable, which reads as the commands vanishing.
  { gate: "helptest", file: "Valuate.lua",
    label: "a help topic can never be selected, so a whole group becomes unreachable",
    from: 'if topic == "all" or topic == group.key then', to: "if false then" },
  { gate: "commands", file: "tools/commands.js",
    label: "the gate stops reading help lines, so undocumented commands pass unnoticed",
    from: "helped.add(m[1]);", to: ";" },
  { gate: "helptest", file: "Valuate.lua",
    label: "bare help dumps all 74 commands again, which is the wall this replaced",
    from: 'if topic == "all" or topic == group.key then', to: "if true then" },
  { gate: "helptest", file: "Valuate.lua",
    label: "an unknown topic silently shows the overview instead of saying so",
    from: "No help topic called ", to: "" },

  // ---- the what-is-new panel stays a summary (v0.149.0a) -------------------
  // Its own comment has said "a SUMMARY, not one entry per patch" since it was written, and
  // nothing enforced it: one day of releases took it to 68 bullets.
  { gate: "tocsync", file: "tools/tocsync.js",
    label: "the bullet count is never actually compared against the limit",
    from: "      const NEWS_BULLET_LIMIT = 60;", to: "      const NEWS_BULLET_LIMIT = 10;" },
  { gate: "tocsync", file: "tools/tocsync.js",
    label: "the count sweeps up every historical section, so it fires on prose nobody is changing",
    from: "newsBlock[1].match", to: "panel.match" },

  // ---- the login nudge for a guessed scale (v0.150.0a) ---------------------
  // Three surfaces already mark it, and all three need you to go and look. This is the one
  // that speaks when you are looking at none of them.
  { gate: "todotest", file: "Valuate.lua",
    label: "a scale built on guessed weights never says so at login",
    from: "    if primaryScale and primaryScale.Inferred then", to: "    if false then" },
  { gate: "todotest", file: "Valuate.lua",
    label: "every scale is flagged as a guess, so the flag stops meaning anything",
    from: "    if primaryScale and primaryScale.Inferred then", to: "    if true then" },

  // ---- the in-game manual keeps up (v0.151.0a) -----------------------------
  // The Automation section documented five automations while the addon had twenty. Same
  // drift as the About panel and the verify checklist: a hand-maintained list nobody checked.
  { gate: "tocsync", file: "tools/tocsync.js",
    label: "the manual-drift check never actually compares anything",
    from: "if (missing.length > autoCmds.length / 2) {", to: "if (missing.length > -1) {" },

  // ---- the guess reaches the glance (v0.152.0a) ----------------------------
  // Four surfaces already say it, and all four need you to go and look. This is the one
  // people actually glance at.
  { gate: "minimaptest", file: "MinimapButton.lua",
    label: "the glance never mentions that the scale is a guess",
    from: "            if scale.Inferred then", to: "            if false then" },
  { gate: "minimaptest", file: "MinimapButton.lua",
    label: "every scale is called a guess, so the mark stops meaning anything",
    from: "            if scale.Inferred then", to: "            if true then" },

  // ---- what is actually running (v0.153.0a) --------------------------------
  // Twenty automations, all off by default, spread across four sections. The line answering
  // "which are on" is only useful if it re-reads and if the label table stays complete.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "the running line is written once and then never updates, so it looks live and lies",
    from: "    ns.RefreshSettingsActiveLine = RefreshActiveLine", to: "" },
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "an empty list reads as blank rather than saying nothing is running",
    from: "        if #on == 0 then", to: "        if false then" },
  { gate: "options", file: "Valuate.lua",
    label: "an automation drops out of the running list and nothing notices",
    from: "    autoRollLoot            = { label = \"roll on loot\",                  beat = \"autoRoll\" },", to: "" },

  // ---- nothing acts while items are in transit (v0.154.0a) -----------------
  // The delete and sell paths have refused mid-swap since the transit bug. EquipBestSet did
  // not, because for most of its life it was a button somebody pressed - making it automatic
  // is what turned that into a real gap. Scoped anchors, because four functions now test the
  // same flag and a bare one would land on whichever came first.
  { gate: "deletetest", file: "Valuate.lua",
    scope: { start: "function Valuate:EquipBestSet(", end: "\n    local equipped" },
    label: "gear is equipped against slots that have already moved underneath it",
    from: "if equipmentSwapPending then", to: "if false then" },
  { gate: "deletetest", file: "Valuate.lua",
    scope: { start: "function Valuate:AutoUnjunkProtected(", end: "\n    local freed" },
    label: "the junk rescue writes overrides for item ids that have already moved",
    from: "if equipmentSwapPending then", to: "if false then" },

  // ---- and the two body-scoped rules can actually READ their subjects ------
  // Both of these count block keywords to find a function's body, and both were silently
  // inert for AutoDeleteJunk until a mutation asked. Prose in its comments read as Lua
  // structure, the body never closed, and the rule skipped it - which looks exactly like
  // finding nothing. These three mutations are the standing question 'can you still see
  // the delete path', asked of the rules rather than of me.

  // The delete path is the reason no-bank-in-destructive-path exists, and the function it
  // had never once examined. Bank slots hold the gear people care most about.
  { gate: "check", file: "Valuate.lua",
    label: "the bank snapshot reaches the delete path and no rule sees it",
    from: "    local force = opts.force == true  -- on-demand: ignore the enable toggle + free-slot gate",
    to: "    local force = opts.force == true or ValuateBankCache" },

  { gate: "check", file: "Valuate.lua",
    label: "the delete path loses its transit guard and no rule notices",
    from: "    if equipmentSwapPending or recentEquipmentChange then\n        if preview then print",
    to: "    if recentEquipmentChange then\n        if preview then print" },

  // SellNextBatch is exempted on purpose - it re-verifies each slot instead, which is the
  // stronger guarantee. Removing the exemption must turn the rule red, or that reasoning is
  // sitting on a rule which cannot see the function it is reasoning about. This is the only
  // acting path here that no runtime harness drives: a merchant is not mockable in a way
  // that would prove anything, so the lint rule is the whole of its coverage.
  { gate: "check", file: "Valuate.lua",
    label: "an unreachable-by-test acting path drops out of the rule entirely",
    from: "-- valuate-lint-ignore: acting-paths-wait-for-transit  re-verifies each slot instead, below",
    to: "-- (exemption removed)" },
  // ---- what each automation last did (v0.155.0a) ---------------------------
  // The heartbeat was recorded from the beginning and readable only through /valuate
  // report. Every step between an option being on and its outcome appearing is a table
  // lookup that returns nil rather than failing, so every one of them can break quietly.

  // The join itself: option key -> beat -> outcome. Point an automation at a beat nothing
  // records and the UI says 'no occasion yet' forever, which is what an idle automation
  // looks like - so the wrong answer is indistinguishable from the right one.
  { gate: "heartbeat", file: "Valuate.lua",
    label: "an automation is pointed at a beat nothing records, and reads as merely idle",
    from: 'beat = "autoRepair" },', to: 'beat = "autoRepairs" },' },

  // Two automations on one beat: switching on the second would report the first's outcome.
  { gate: "heartbeat", file: "Valuate.lua",
    label: "two automations share a beat, so one reports the other\u2019s outcome",
    from: 'beat = "junkSell" },', to: 'beat = "junkCleanup" },' },

  // The tiebreaker. pairs() feeds this, so equal labels would reshuffle between openings.
  { gate: "heartbeat", file: "Valuate.lua",
    scope: { start: "function Valuate:ActiveAutomationDetail(", end: "\n    return out" },
    label: "the running list reorders itself between openings of the panel",
    from: "table.sort(out, function(a, b)", to: "local _ = (function(a, b)" },

  // And the hover has to SHOW the outcome, not merely the fact that something ran. A
  // healthy automation's usual answer is 'did nothing, and here is why' - the why is the
  // entire reason this stopped being a chat command.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "the hover reports that an automation ran but not what it concluded",
    from: 'GameTooltip:AddLine("      " .. a.outcome, 0.55, 0.75, 0.55, true)',
    to: 'GameTooltip:AddLine("      ran", 0.55, 0.75, 0.55, true)' },

  // 'has not run yet' and 'ran, and did nothing' look identical if the first is blank.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "an automation that has had no occasion to run shows a blank instead of saying so",
    from: 'GameTooltip:AddDoubleLine(a.label, "no occasion yet",',
    to: 'GameTooltip:AddDoubleLine(a.label, "",' },
  // ---- every tab is built the same way (v0.156.0a) -------------------------
  // Four of the six tabs were hand-copied from CreateTab and none of the copies carried
  // the accent bar. SelectTab guards on the accent existing, so it skipped them without
  // a texture error or a missing frame - four tabs simply never showed you where you
  // were. Nothing could see it either, because the buttons were locals.

  // The bar itself.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "a tab is built without the accent that marks the one you are on",
    from: "        btn.accent = accent",
    to: "        if name ~= \"about\" then btn.accent = accent end" },

  // And that it follows the selection rather than merely existing. A bar shown on every
  // tab at once marks nothing.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "the accent stays lit on tabs you have left, so it marks all of them",
    from: "                if btn.accent then btn.accent:Hide() end",
    to: "                if false then btn.accent:Hide() end" },

  // The buttons have to stay reachable, or the checks above go back to being unwritable.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "the tab buttons stop being reachable, and nothing can check them again",
    from: "        buttons = tabs,", to: "        buttons = nil," },
  // ---- every button answers the mouse (v0.157.0a) --------------------------
  // Twelve buttons built by the shared helper had their hover fade REPLACED by a later
  // SetScript for a tooltip - the helper installs on the same slot, and last writer wins.
  // Nothing was missing and nothing errored; the buttons simply stopped lighting up, which
  // reads as disabled rather than broken.

  // The helper's own feedback. If the button it builds stops responding, everything
  // downstream of it does too.
  { gate: "tabtest", file: "ui/Widgets.lua",
    label: "the shared button helper stops giving any hover feedback",
    from: "    btn:HookScript(\"OnEnter\", function(self)\n        TweenBackdrop(self, COLORS.buttonHover",
    to: "    btn:HookScript(\"OnEnter\", function(self)\n        if false then TweenBackdrop(self, COLORS.buttonHover" },

  // And the reason those twelve went quiet: SetScript replaces, HookScript chains.
  { gate: "tabtest", file: "ui/Settings.lua",
    label: "a tooltip handler replaces a button\u2019s hover instead of chaining onto it",
    from: "restoreButton:HookScript(\"OnEnter\"", to: "restoreButton:SetScript(\"OnEnter\"" },

  // Scan Best Equipment: the odd one out among its own three siblings, each of which
  // carries this texture with a comment saying why.
  { gate: "tabtest", file: "ui/BestEquipment.lua",
    label: "the scan button loses the highlight its three siblings all have",
    from: "    local scanHL = scanButton:CreateTexture(nil, \"HIGHLIGHT\")",
    to: "    local scanHL = scanButton:CreateTexture(nil, \"ARTWORK\")" },

  // Tabs: hover on the ones you are not on, and NOT on the one you are.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "tabs stop answering the mouse entirely",
    from: "            if activeTab ~= name then\n                TweenBackdrop(self, COLORS.buttonHover",
    to: "            if false then\n                TweenBackdrop(self, COLORS.buttonHover" },

  { gate: "tabtest", file: "ValuateUI.lua",
    label: "hover dims the ACTIVE tab, the one thing telling you where you are",
    from: "            if activeTab ~= name then\n                TweenBackdrop(self, COLORS.buttonHover",
    to: "            if true then\n                TweenBackdrop(self, COLORS.buttonHover" },
  // ---- the To Do tab (v0.158.0a) --------------------------------------------
  // BuildTodoList has answered 'what should I do next' since it was written, and the
  // answer only ever reached a chat frame - the login line announced the list and then
  // asked you to type a command to read it. Every item already carried a command.
  //
  // todotest.js owns WHAT belongs on the list. These are about what only exists once it
  // is on screen, and every one of them is a failure you cannot see by looking.

  // Rows are pooled, so a shrinking list must hide the tail rather than leave last
  // visit's entries sitting under this visit's.
  { gate: "todopanel", file: "ui/TodoPanel.lua",
    label: "a shorter list leaves the previous visit\u2019s entries on screen beneath it",
    from: "        for i = #items + 1, #rowPool do\n            rowPool[i]:Hide()",
    to: "        for i = #items + 1, 0 do\n            rowPool[i]:Hide()" },

  // An empty list is an ANSWER. Silent emptiness reads as a panel that failed to load.
  { gate: "todopanel", file: "ui/TodoPanel.lua",
    label: "nothing to do shows a blank panel instead of saying there is nothing to do",
    from: "        if #items == 0 then\n            empty:Show()",
    to: "        if false then\n            empty:Show()" },

  // Reused rows must not carry the previous item's explanation under the new one's text.
  { gate: "todopanel", file: "ui/TodoPanel.lua",
    label: "an item with no detail inherits the detail of whatever used that row before",
    from: "                row.detail:SetText(\"\")\n                row.detail:Hide()",
    to: "                row.detail:SetText(\"\")" },

  // THE regression pooling makes possible: a row running the command it was BUILT with
  // rather than the one it is currently showing. It fires, it looks right, it is wrong.
  { gate: "todopanel", file: "ui/TodoPanel.lua",
    label: "a reused row runs the command it was first given, not the one it now shows",
    from: "            row.command = item.command",
    to: "            row.command = row.command or item.command" },

  // And the tab has to actually refresh. A to-do list that is stale is worse than none:
  // it has you chasing an upgrade you already equipped.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "the To Do tab shows whatever was true when the window was first opened",
    from: "                if ns.RefreshTodoPanel then ns.RefreshTodoPanel() end",
    to: "                if false then ns.RefreshTodoPanel() end" },
  // ---- the to-do list admits what it left out (v0.159.0a) ------------------
  // Trimming to three is right; stopping silently is not. A list that ends at three reads
  // as a complete one. /valuate upgrades caps at five and has always said so - this was the
  // one place in the addon that capped a list and kept quiet about it.
  { gate: "todotest", file: "Valuate.lua",
    label: "the to-do list stops at three upgrades and lets it look like all of them",
    from: "        local hidden = #upgrades - 3", to: "        local hidden = 0" },

  // The off-by-one on the other side: claiming more are waiting when none are is worse
  // than saying nothing, because it sends you looking for something that is not there.
  { gate: "todotest", file: "Valuate.lua",
    label: "it claims more upgrades are waiting when there are exactly three",
    from: "        if hidden > 0 and items[#items] then", to: "        if hidden >= 0 and items[#items] then" },
  // The row-sizing mutations that used to live here moved to widgettest when both panels
  // started sharing ns.FitRowHeight. Duplicating them per panel would have re-created the
  // thing the shared helper exists to prevent: two copies to keep in step.

  // ...and the list has to grow with them, or the rows below run off the panel.
  { gate: "todopanel", file: "ui/TodoPanel.lua",
    label: "the list keeps its old fixed-height sum and clips the rows below",
    from: "                total = total + rowPool[i]:GetHeight() + (i > 1 and ROW_GAP or 0)",
    to: "                total = total + ROW_HEIGHT + (i > 1 and ROW_GAP or 0)" },
  // ---- the To Do tab carries its count (v0.160.0a) -------------------------
  // The login line has always said how many things need doing. The tab said "To Do"
  // either way, so you had to open it to find out whether opening it was worth it.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "the tab hides the count, so you must open it to learn there is nothing in it",
    from: "        btn.label:SetText((n and n > 0) and (base .. \" (\" .. n .. \")\") or base)",
    to: "        btn.label:SetText(base)" },

  // Zero is not "(0)". A badge announcing that nothing needs attention is a badge
  // drawing attention to the absence of anything to attend to.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "an empty list still wears a badge, advertising that there is nothing to do",
    from: "(n and n > 0) and", to: "(n and n >= 0) and" },

  // And the label has to be re-measured, or a longer one is clipped by the old width.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "the tab keeps its old width, clipping the count it just added",
    from: "        btn:SetWidth(btn.label:GetStringWidth() + 40)", to: "" },
  // ---- the in-client UI checker (v0.161.0a) --------------------------------
  // A diagnostic that cannot fail is worse than none, because a clean run from it reads as
  // evidence. These break the arithmetic that decides whether something is outside its
  // parent; the gate feeds it fabricated coordinates, because the harness does no layout -
  // which is the entire reason the command exists.
  { gate: "uicheck", file: "ui/UICheck.lua",
    label: "text below its own row is no longer noticed - the v0.158.0a defect exactly",
    from: "        if c.bottom < p.bottom - SLACK then over[#over + 1] = \"below\" end",
    to: "        if false then over[#over + 1] = \"below\" end" },

  { gate: "uicheck", file: "ui/UICheck.lua",
    label: "the slack swallows real overflow instead of a rounded edge",
    from: "local SLACK = 1", to: "local SLACK = 400" },

  // The direction that keeps it honest. A checker that complains about correct layout
  // trains people to ignore it, and then it protects nothing at all.
  { gate: "uicheck", file: "ui/UICheck.lua",
    label: "a correctly laid-out window is reported as broken",
    from: "        if c.top > p.top + SLACK then over[#over + 1] = \"above\" end",
    to: "        if c.top >= p.top - 999 then over[#over + 1] = \"above\" end" },

  // Hidden pooled rows keep stale coordinates. Measuring them would bury the real report.
  { gate: "uicheck", file: "ui/UICheck.lua",
    label: "hidden rows are measured, so a pooled list reports dozens of phantom problems",
    scope: { start: "-- ---- 1. nothing is drawn outside", end: "-- ---- 2. nothing is off" },
    from: "if not (child.IsShown and child:IsShown()) then return end",
    to: "if child == nil then return end" },

  // And the tab count, which is how four of six tabs went unmarked until v0.156.0a.
  { gate: "uicheck", file: "ui/UICheck.lua",
    label: "every tab lit at once passes, though a bar on all of them marks none",
    from: "        elseif lit > 1 then", to: "        elseif false then" },
  // ---- not looked yet vs nothing to find (v0.162.0a) -----------------------
  // RankAvailableUpgrades returns nil when there is no scan data, and the builder read it
  // as "no upgrades" - so a character who had never scanned got an empty list, and the
  // panel said "your gear, gems and enchants are all up to date" about gear nothing had
  // ever looked at. CLAUDE.md states this rule off the back of the same bug in PassLoot.
  { gate: "todotest", file: "Valuate.lua",
    label: "never having looked is reported as having found nothing",
    from: "    elseif not (best and best[scaleName]) then", to: "    elseif false then" },

  // The other unknown: no scale to score against at all.
  { gate: "todotest", file: "Valuate.lua",
    scope: { start: "function Valuate:BuildTodoList(", end: "    local upgrades = scaleName" },
    label: "a character with no scale is told everything is fine",
    from: "    if not scaleName then", to: "    if false then" },

  // And it must CLEAR. A blocker that outlives the thing blocking it is noise, and noise
  // at the top of the list is how people stop reading the list.
  { gate: "todotest", file: "Valuate.lua",
    label: "the scan blocker never clears, so it sits at the top of every list forever",
    from: "    elseif not (best and best[scaleName]) then", to: "    elseif true then" },
  // ---- the scan-age line knows three states (v0.163.0a) --------------------
  // It printed "these are last session’s results" for the absence of a heartbeat, full
  // stop - so a character who had never scanned was told the empty grid in front of them
  // came from last time. Same shape as the to-do list telling an unscanned character its
  // gear was all up to date: a missing measurement read as a measurement of nothing.
  { gate: "tabtest", file: "ui/BestEquipment.lua",
    label: "a never-scanned character is told they are looking at last session’s results",
    from: "        if haveStored then", to: "        if true then" },

  // And the other direction: real saved results reported as nothing, which would have
  // people re-scanning gear the addon already knows about.
  { gate: "tabtest", file: "ui/BestEquipment.lua",
    label: "saved results from last session are reported as never having scanned",
    from: "        if haveStored then", to: "        if false then" },
  // ---- Ascension scales gear, so the template level is not a fact (v0.164.0a) ---
  // GetItemInfo’s minLevel is the item template’s number. On a server that scales gear
  // to your level it says nothing about this character, and the scan was filing wearable
  // gear under "upgrade at level 24" for a level already effectively passed. The tooltip
  // is rendered for THIS character with scaling applied, so redness is the whole signal.
  { gate: "scaledlevel", file: "Valuate.lua",
    label: "a met requirement drawn in white is read as a level still ahead of you",
    from: "        if TooltipLineIsRed(line) then", to: "        if line then" },

  // The other direction: a real requirement missed means gear recommended that cannot be
  // worn, which is worse - it is advice you cannot act on at all.
  { gate: "scaledlevel", file: "Valuate.lua",
    label: "a genuinely unmet level requirement is ignored",
    from: "            local level = text and text:match(pattern)",
    to: "            local level = nil" },

  // Line 1 is the item name in its quality colour, and legendary orange is close to red.
  { gate: "scaledlevel", file: "Valuate.lua",
    label: "the item name is scanned, so its text can invent a required level",
    scope: { start: "function ns.TooltipRequiredLevel(", end: "    return nil" },
    from: "for i = 2, tooltip:NumLines() do", to: "for i = 1, tooltip:NumLines() do" },
  // ---- enhancement slot classification (v0.165.0a) -------------------------
  // A live recipe gives one usable fact: its name. So the slot is read out of "Enchant
  // Boots - Greater Assault", first-match-wins - which makes ORDER the behaviour.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "weapon is matched before two-handed, so every 2H enchant becomes a 1H one",
    from: "    { pattern = \"2h weapon\",  slots = { 16 } },", to: "" },

  // The reverse: a plain weapon enchant fits either hand, and losing that makes the
  // off-hand look like it has no options at all.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "a plain weapon enchant is offered for the main hand only",
    from: "    { pattern = \"weapon\",     slots = { 16, 17 } },",
    to: "    { pattern = \"weapon\",     slots = { 16 } }," },

  // A ring enchant fits both fingers. One of them silently having no options is the kind
  // of gap nobody reports, because an empty row reads as "nothing available".
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "ring enchants are offered for one finger but not the other",
    from: "    { pattern = \"ring\",       slots = { 11, 12 } },",
    to: "    { pattern = \"ring\",       slots = { 11 } }," },

  // And the probe must REPORT a missing source rather than throw. The client is the
  // unknown quantity here; a probe that errors teaches nothing about it.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "a source the client lacks is reported as present anyway",
    from: "        if ok and present then", to: "        if true then" },
  // ---- the enhancement engine (v0.166.0a) ----------------------------------
  // A header row is a category label, not something you can make - and its name is a slot
  // word, so letting one through lists "Enchant Boots" as an enchant in its own right.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "category headers are collected as if they were enchants",
    from: "            if ok and name and craftType ~= \"header\" then",
    to: "            if ok and name then" },

  // 3.3.5 splits the apis: Enchanting behind Craft, everything else behind TradeSkill.
  // Reading one silently loses a whole profession and still looks like it works.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "only one of the two profession apis is read, losing the other entirely",
    from: "    if type(GetNumCrafts) == \"function\" and type(GetCraftInfo) == \"function\" then",
    to: "    if false then" },

  // What could not be read has to be REPORTED. Dropping it makes the panel look complete.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "an enhancement whose slot cannot be read is silently discarded",
    from: "            unreadable[#unreadable + 1] = { name = name, why = \"could not tell which slot\" }",
    to: "            local _ = name" },

  // An effect enchant that scores zero ranks below a +4 Spirit one for everybody.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "proc and movement enchants score zero, so they rank below trivial stat ones",
    from: "            score = score + effect[column]", to: "            score = score + 0" },

  // ...and the estimate has to be admitted. A number from someone’s judgement about
  // movement speed should not sit unlabelled beside one from your own stat weights.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "a judgement-derived score is presented as if it were measured",
    from: "            estimated = true", to: "            estimated = false" },

  // The role decides which column of effect values is read. This server is classless, so
  // the scale is the only statement of intent there is.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "every scale is treated as a damage scale, so tanks are valued as damage",
    from: "    if defensive > offensive * 0.6 then return \"tank\" end", to: "" },

  // Ranking order is the feature. Unsorted, the panel reshuffles between openings.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "the list comes back in whatever order the profession window happened to use",
    from: "        if a.score ~= b.score then return a.score > b.score end", to: "        if false then return false end" },
  // ---- the Enhance tab (v0.167.0a) -----------------------------------------
  // "I have not been shown any" and "you have already done every slot" are opposite
  // states that both produce an empty list. This project has said the same thing for both
  // three times now (see CLAUDE.md), so it is the assertion the panel exists to hold.
  // Read ONCE and used twice - the banner and the no-rows message - so one mutation proves
  // both. Two copies of the test would be two chances for half the panel to answer the
  // opposite question.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "never having looked reads as having already enhanced everything",
    from: "        local anyKnown = false", to: "        local anyKnown = true" },

  // The ordering argument. Hiding the runners-up undoes the whole point: a +8 armour
  // enchant beats an empty slot even when it is nowhere near the best available.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "only the winner is shown, so second-best-but-affordable disappears",
    from: "                for i = 2, math.min(#ranked, ALTERNATIVES + 1) do",
    to: "                for i = 2, 1 do" },

  // ---- a row per slot, and seven states (v0.177.0a) --------------------------
  // The panel used to draw a row only where it had something to offer, which meant four
  // completely different situations - already done, takes none, none collected, nothing worn -
  // all rendered identically: absent. Each of these mutations collapses one state into
  // another, which is the failure the redesign exists to prevent.

  // An enchant for gear you are not wearing is a shopping catalogue, not a to-do list.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "slots with nothing equipped in them are offered enhancements anyway",
    from: "    if not info.hasItem then return \"empty\" end",
    to: "    if false then return \"empty\" end" },

  // "Nothing goes here" and "I have not been shown any" are opposite claims. Reporting a
  // trinket as the latter sends you looking for something that cannot exist.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "a slot no enhancement fits reads as one I have simply never been shown",
    from: "    if not ns.ENHANCEABLE_SLOTS[info.slotId] then return \"none\" end",
    to: "    if false then return \"none\" end" },

  // Derived from the pattern table on purpose: a second hand-written list is a second thing
  // to forget, and forgetting it makes the panel offer a buckle to a slot it calls unenchantable.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "the enhanceable-slot set is empty, so every slot claims nothing goes on it",
    from: "    for _, slotId in ipairs(entry.slots) do ns.ENHANCEABLE_SLOTS[slotId] = true end",
    to: "" },

  // An enchanted slot is finished. Calling it a recommendation puts a job on a done thing.
  // Asked BEFORE the known-count check. Below it, an enchanted slot on a character whose
  // professions have never been opened reported "none shown to me yet" - which reads as a job,
  // on the one kind of slot that definitely is not one. A single-line anchor rather than a
  // two-line swap, because a multi-line one in this file has silently lost its newline three
  // times now and reported UNAPPLIED.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    scope: { start: "function ns.EnhanceSlotState(info)", end: "\n    if (info.shown or 0) <= 0" },
    label: "an enchanted slot reads as one I have never been shown options for",
    from: "    if info.hasEnchant then return \"enhanced\" end", to: "" },

  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "a slot that already has an enchant is recommended one anyway",
    from: "    if info.hasEnchant then return \"enhanced\" end",
    to: "    if false then return \"enhanced\" end" },

  // Filtered and blocked both leave an empty list, and only one is a fact about your gear.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "a slot the profession filter is hiding blames your item level instead",
    from: "    if (info.shown or 0) <= 0 then return \"filtered\" end",
    to: "    if false then return \"filtered\" end" },

  // Counted before the filter, or a crafted-only view reports an enchanter's slots as never
  // having been seen - sending you to open a window you already opened.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "the profession filter makes slots report they have never been shown any options",
    from: "                known = #all,", to: "                known = #ranked," },

  // The filter itself.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "the profession filter does nothing at all",
    from: "            if ns.EnhanceFilters.source ~= \"all\" then", to: "            if false then" },

  // Only two of the seven states are jobs.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "a slot waiting only on better gear does not count as anything to do",
    from: "    return state == \"recommend\" or state == \"blocked\"",
    to: "    return state == \"recommend\"" },

  // A badge that reads seventeen forever is a decoration.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "the tab badge counts rows drawn rather than jobs outstanding",
    from: "        if ns.SetTabCount then ns.SetTabCount(\"enhance\", actionable) end",
    to: "        if ns.SetTabCount then ns.SetTabCount(\"enhance\", shown) end" },

  // The 'only what I can act on' filter, which is the one control that hides slots.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "the 'only slots with something to do' tick hides nothing",
    from: "            if not (ns.EnhanceFilters.onlyActionable and not ns.EnhanceStateIsActionable(state)) then",
    to: "            if true then" },

  // Two patterns whose absence only became visible once every slot had a row: both were read
  // out of the profession window correctly and then filed under "couldn't read these".
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "a belt buckle is sent to the wrong slot",
    from: "    { pattern = \"buckle\",     slots = { 6 } },",
    to: "    { pattern = \"buckle\",     slots = { 7 } }," },
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "a scope is sent to the wrong slot",
    from: "    { pattern = \"scope\",      slots = { 18 } },",
    to: "    { pattern = \"scope\",      slots = { 17 } }," },

  // The scroll bar's own handler must REPLACE the template's, not chain onto it.
  //
  // UIPanelScrollBarTemplate's OnValueChanged calls SetVerticalScroll on the slider's parent,
  // which here is the panel. HookScript keeps it alive alongside ours, so the first SetValue
  // throws inside the panel builder - which is what v0.177.0a shipped, by a different route:
  // calling SetValue one line before SetScript.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "the scroll bar chains the template's handler instead of replacing it, and throws",
    from: "    scrollBar:SetScript(\"OnValueChanged\", function(_, value)",
    to: "    scrollBar:HookScript(\"OnValueChanged\", function(_, value)" },

  // Seventeen rows do not fit the window. They used to run off the bottom of it.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "the scroll range is always zero, so rows past the fold are unreachable",
    from: "        local range = math.max(0, lastContentHeight - scrollFrame:GetHeight())",
    to: "        local range = 0" },

  // "already enhanced" is the whole of what the item link supports. Dropping the words leaves
  // a slot that is done looking like one being recommended something.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "a finished slot does not say it is finished",
    from: "                        prefix = \"|cFF888888already enhanced|r  ·  \"",
    to: "                        prefix = \"\"" },

  // A judgement-derived number must not sit unlabelled beside a measured one.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "an estimated score is presented as though it were measured",
    from: "                    top.estimated and \"|cFFFFCC66~\" or \"|cFFFFFFFF\", top.score))",
    to: "                    \"|cFFFFFFFF\", top.score))" },

  // What could not be read is never dropped: it would make the list look complete.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "enhancements nobody could classify are silently discarded",
    from: "        if unreadable and #unreadable > 0 then", to: "        if false then" },
  // ---- vendor notes (v0.168.0a) ---------------------------------------------
  // Nothing on this machine knows where a recipe is sold, so these are written down while
  // you stand in front of one. "Record everything you ever see" is how a saved-variables
  // file becomes a problem nobody notices until it is one.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "the note list grows without bound, one entry per vendor item ever seen",
    from: "    if count <= ns.VENDOR_NOTE_CAP then return 0 end", to: "    if true then return 0 end" },

  // Evicting the NEWEST would throw away the note you just took, which is the one you are
  // most likely to be about to use.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "eviction discards the newest notes instead of the oldest",
    from: "        if a.at ~= b.at then return a.at < b.at end", to: "        if a.at ~= b.at then return a.at > b.at end" },

  // Narrow on purpose: everything-is-a-recipe blows the cap on one trip to a city.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "every vendor item is noted, so a city trip evicts everything that mattered",
    from: "    if not LooksLikeRecipe(name) then return 0 end", to: "    if false then return 0 end" },

  // A price that changed is the one worth keeping - reputation and server both move it.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "a recipe seen again at a new price keeps the stale one",
    from: "    notes[name] = {", to: "    notes[name] = notes[name] or {" },
  // ---- one row-fitting helper, shared (v0.169.0a) --------------------------
  // A fixed row height under wrapping text shipped TWICE - the To Do panel in v0.158.0a and
  // the Enhance panel in v0.167.0a, the second in a file created after the first was fixed.
  // Two implementations were two chances to forget, so there is one now, and these break it
  // in the ways both panels were broken.
  { gate: "widgettest", file: "ui/Widgets.lua",
    label: "rows go back to a fixed height, so wrapped text draws over the row below",
    from: "    row:SetHeight(math.max(floor, top + tallest + bottom))",
    to: "    row:SetHeight(floor)" },

  // A row can have independent stacks side by side and either can be the one that wraps.
  // Measuring only the first is exactly how the Enhance panel overflowed its own row.
  { gate: "widgettest", file: "ui/Widgets.lua",
    label: "only the first column is measured, so the other one overflows the row",
    from: "        if height > tallest then tallest = height end",
    to: "        if tallest == 0 then tallest = height end" },

  // An empty string must contribute nothing, not even its gap, or every row that omits one
  // carries a blank line of dead space.
  { gate: "widgettest", file: "ui/Widgets.lua",
    label: "an omitted line still reserves its space, padding every short row",
    from: "            if fs and text and text ~= \"\" and (not fs.IsShown or fs:IsShown()) then",
    to: "            if fs then" },

  // ---- one tooltip read per recipe, not per click (v0.170.0a) --------------
  // The Enhance tab rebuilds on every arrival including a re-click, deliberately. That meant
  // a full tooltip parse per recipe every time, and an enchanter with a filled book has a
  // few hundred. Correct, and needlessly expensive on a path a person clicks.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "every tab click re-reads a tooltip for every recipe you know",
    from: "    if hit then return hit.stats, hit.reqLevel end", to: "" },

  // The far worse failure: a cache that never clears. A recipe you just learned stays
  // invisible until you log out, which reads as the feature not seeing it at all.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "the cache never clears, so a newly learned enchant never appears",
    scope: { start: 'capture:SetScript("OnEvent"', end: "    local now =" },
    from: "        ns.ResetEnhanceCache()", to: "" },

  // A FAILED read must not be remembered - the usual cause is a tooltip that was not ready,
  // and caching that makes one bad moment permanent for the session.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "a failed read is cached, making one bad moment permanent",
    from: "    if name and stats then statsCache[name] = { stats = stats, reqLevel = reqLevel } end",
    to: "    if name then statsCache[name] = { stats = stats or {}, reqLevel = reqLevel } end" },

  // ---- one badge setter for every tab (v0.171.0a) --------------------------
  // A panel can refresh before its tab exists. An unknown name must be ignored rather than
  // fatal, or the whole window build dies on an ordering detail.
  { gate: "tabtest", file: "ValuateUI.lua",
    label: "badging a tab that does not exist takes the window down with it",
    from: "        if not btn or not btn.label then return end", to: "" },
  // ---- selfverify covers what shipped this session (v0.172.0a) -------------
  // Two diagnostics shipped and neither was in SELF_CHECKS, so "every check the addon can
  // judge on its own" was quietly incomplete. Same failure as the report toggles, the verify
  // checklist, the automation labels and the in-game manual before it.
  { gate: "selfverify", file: "Valuate.lua",
    label: "a client with no Craft api passes, though enchants can never appear",
    from: "    if not byKey.craft then", to: "    if false then" },

  // Zero open recipes is the NORMAL state with no window open. Calling it a failure would
  // teach people to ignore this check, which is worse than not having it.
  { gate: "selfverify", file: "Valuate.lua",
    label: "no profession window open is reported as a failure rather than untested",
    from: "    if open == 0 then", to: "    if false then" },

  // The UI check must not OPEN the window to inspect it: a diagnostic that changes what is
  // on your screen in order to measure it is measuring something you did not have.
  { gate: "uicheck", file: "ui/UICheck.lua",
    label: "the quiet check opens the window it was asked to inspect",
    from: "        if quiet then return nil, 0 end", to: "" },
  // ---- an enchant you cannot apply (v0.173.0a) -----------------------------
  // Enchants carry an item-level floor. Recommending a level-60 one for a level-20 chest is
  // advice that cannot be acted on, which is the specific thing this panel exists to prevent.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "an enchant that cannot go on your gear outranks one that can",
    from: "        if a.tooHigh ~= b.tooHigh then return b.tooHigh end", to: "" },

  // The other direction: demoting on a parse this code has never seen on Ascension would
  // bury usable options. A requirement it could not read counts as no requirement.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "an unreadable requirement is treated as unmet, burying usable enchants",
    from: "        local tooHigh = (wornLevel and entry.reqLevel and entry.reqLevel > wornLevel) or false",
    to: "        local tooHigh = (wornLevel and entry.reqLevel ~= wornLevel) or false" },

  // ...and a demoted one has to say WHY, or the strongest enchant sitting third looks
  // arbitrary and the panel looks broken.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "a demoted enchant reads as merely lower-scoring, with no reason given",
    from: "                    rest[#rest + 1] = alt.tooHigh", to: "                    rest[#rest + 1] = false" },
  // The requirement parser. Its wording is unverified against Ascension, so both directions
  // matter: missing a real floor offers unusable enchants, and inventing one hides good ones.
  { gate: "enhance", file: "ui/Enhance.lua",
    label: "the item-level floor is never read, so unusable enchants are recommended",
    from: "            local level = text:match(\"level (%d+) or higher item\")", to: "            local level = nil and text:match(\"x\")" },

  // Line 1 is the recipe name. A recipe whose title mentions a level would supply its own.
  { gate: "enhance", file: "ui/Enhance.lua",
    scope: { start: "local function RequiredItemLevel(", end: "    return nil" },
    label: "the recipe's own name supplies a requirement, if it happens to mention a level",
    from: "for i = 2, tip:NumLines() do", to: "for i = 1, tip:NumLines() do" },
  // ---- what the addon cost you (v0.174.0a) ---------------------------------
  // The TSM integration froze a client on a hot path nobody was measuring. This addon is
  // the one always loaded, runs twenty automations off thirty-three events, and had no
  // instrument at all.
  { gate: "eventcost", file: "Valuate.lua",
    label: "sorted by total, so a hundred harmless calls outrank the one that stutters",
    from: "        if a.worst ~= b.worst then return a.worst > b.worst end",
    to: "        if a.total ~= b.total then return a.total > b.total end" },

  // pairs() is not a ranking. A table that reshuffles is one you stop trusting.
  { gate: "eventcost", file: "Valuate.lua",
    label: "events costing the same reorder between runs",
    from: "        return a.event < b.event", to: "        return false" },

  // A blank section reads as "this addon costs nothing", which is a claim it has not earned.
  { gate: "eventcost", file: "Valuate.lua",
    label: "having measured nothing prints an empty heading instead of saying so",
    from: "    if #costs == 0 then", to: "    if false then" },

  // Silently stopping at six reads as a complete list.
  { gate: "eventcost", file: "Valuate.lua",
    label: "the events not shown are dropped without saying how many",
    from: "    if #costs > 6 then", to: "    if false then" },

  // A report that flags everything flags nothing.
  { gate: "eventcost", file: "Valuate.lua",
    label: "every event is coloured as a problem, including the cheap ones",
    from: "        local colour = c.worst > (ns.EVENT_STUTTER_MS or 100) and \"|cFFFF8800\" or \"|cFFFFFFFF\"",
    to: "        local colour = \"|cFFFF8800\"" },
  // ---- the scale follows where you are (v0.175.0a) -------------------------
  // A PvP scale switch already existed. This adds dungeons and an optional outdoor scale
  // to it, which turns one restore slot into a thing that can strand you.
  { gate: "queuetest", file: "Valuate.lua",
    label: "a dungeon uses the PvP scale, because both contexts read the same option",
    from: "        local name = opts.dungeonScale", to: "        local name = opts.pvpScale" },

  // Raids are dungeons and arenas are PvP. Dropping either grouping silently leaves that
  // content on whatever scale you happened to have.
  { gate: "queuetest", file: "Valuate.lua",
    label: "a raid is not treated as a dungeon, so raiding uses your outdoor scale",
    from: "    if inInstance and (instanceType == \"party\" or instanceType == \"raid\") then",
    to: "    if inInstance and instanceType == \"party\" then" },

  { gate: "queuetest", file: "Valuate.lua",
    label: "an arena is not treated as PvP",
    from: "    if inInstance and (instanceType == \"pvp\" or instanceType == \"arena\") then",
    to: "    if inInstance and instanceType == \"pvp\" then" },

  // THE case a second context introduces: battleground straight into a dungeon. Overwriting
  // the restore slot on the second hop makes the target the BATTLEGROUND scale, and coming
  // out you land on that and stay there.
  { gate: "queuetest", file: "Valuate.lua",
    label: "hopping between two contexts overwrites what you were actually using",
    from: "        if options.pvpScaleRestore == nil then", to: "        if true then" },

  // Switching to a deleted scale silently leaves every score wrong with no sign of why.
  { gate: "queuetest", file: "Valuate.lua",
    label: "a nomination deleted since you made it switches you to nothing",
    from: "        if not scales[wanted] then", to: "        if false then" },
  // ---- the context scale dropdowns (v0.176.0a) -----------------------------
  // One builder, three dropdowns. Three copies is the shape behind four separate defects
  // in this project already, and each of these has to do the same three things right.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "the scale list is read when the panel is BUILT, so a scale made later never appears",
    from: "            local scales = (Valuate.GetScales and Valuate:GetScales()) or {}",
    to: "            local scales = {}" },

  // pairs() is not an order. A menu that reshuffles is one you cannot find anything in twice.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "the scale menu reshuffles every time you open it",
    from: "            table.sort(names)", to: "" },

  // A scale with no weights cannot score anything, so offering it is offering a mistake.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "a scale with no weights is offered, and would score nothing if chosen",
    from: "                if scale and scale.Values and next(scale.Values) then names[#names + 1] = name end",
    to: "                if scale then names[#names + 1] = name end" },

  // A nomination pointing at a deleted scale must not read as "none" - a broken setting
  // hiding behind a plausible one is worse than one that looks broken.
  { gate: "settingstest", file: "ui/Settings.lua",
    label: "a nomination whose scale is gone reads as if nothing was ever chosen",
    from: "            if not scale then return value .. \" (missing)\" end",
    to: "            if not scale then return NONE end" },

  // ---- the profession snapshot (v0.181.0a) ---------------------------------
  // The missing half of the Enhance tab: the apis only answer while their window is open, so
  // until this the tab worked exactly once, in one order nobody would think to try.

  // A window that has opened but not populated reports zero rows for a tick. Storing that
  // replaces a good book with an empty one, and the feature looks like it forgot your
  // professions - worse than being a tick late.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "a half-open window wipes the book it had already remembered",
    from: "            if #entries > 0 or #unreadable > 0 then", to: "            if true then" },

  // Merging would leave an unlearned profession on offer forever with nothing to explain it.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "re-reading a book merges with the old one instead of replacing it",
    from: "                snap.books[bookName] = {",
    to: "                snap.books[bookName] = snap.books[bookName] or {" },

  // Reading only the api that answered first would silently drop the other one.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "only the first answering profession api is read, dropping the other",
    from: "    for _, source in ipairs(BOOK_SOURCES) do",
    to: "    for _, source in ipairs({ BOOK_SOURCES[1] }) do" },

  // A schema left in place is a half-read snapshot presented as a whole one.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "a snapshot written by another schema is read as though it were current",
    from: "       or ValuateEnhanceSnapshot.schema ~= ns.ENHANCE_SNAPSHOT_SCHEMA then",
    to: "       or false then" },

  // Oldest out first. Evicting the newest throws away the book you just opened.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "eviction discards the book you just read instead of the stalest one",
    from: "        if aa ~= bb then return aa < bb end", to: "        if aa ~= bb then return aa > bb end" },

  // The age is what turns a cache into a claim. Rounding three days down to "just now" is the
  // failure - the number exists to make you distrust old data.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "a book read days ago reads as fresh",
    from: "    if seconds < 60 then return \"just now\" end",
    to: "    if seconds < 86400 then return \"just now\" end" },

  // Sorted, because two professions can name the same enhancement and pairs() would pick a
  // different winner - and a different "could not read" order - between sessions.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    scope: { start: "function ns.CollectEnhancements()", end: "\nfunction ns.RankForSlot" },
    label: "book order is whatever pairs() felt like, so the list reshuffles between sessions",
    from: "    table.sort(names)", to: "" },

  // /valuate enhancecheck is the command people are told to run when the tab looks empty.
  // Reporting only the LIVE apis - all of which answer zero with no window open - sends them
  // to exactly the wrong conclusion while the snapshot behind the tab is full.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "the diagnostic reports only live windows, so a full snapshot reads as nothing",
    from: "    local remembered = ns.PrintEnhanceMemory()", to: "    local remembered = 0" },

  // "Nothing at all" is a hard statement that the feature cannot work on this client.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "it declares the client useless while holding a book it read from that client",
    from: "    if #available == 0 and remembered == 0 then", to: "    if #available == 0 then" },

  // ---- the to-do list and the Enhance tab agree (v0.183.0a) -----------------
  // Two panels in one window answered the same question differently: "Enchant 6 items" beside
  // "1 to enhance". Both were right about different questions, and the pair read as a bug.

  // A to-do you cannot act on is not a to-do. Counting bare slots as work is the old number.
  { gate: "todotest", file: "Valuate.lua",
    label: "slots with no known enhancement are listed as work you can do",
    from: "    if canEnhance > 0 then", to: "    if canEnhance + bareSlots > 0 then" },

  // ...and the other direction: dropping them entirely hides real unenchanted gear.
  { gate: "todotest", file: "Valuate.lua",
    label: "unenchanted slots vanish from the list entirely once nothing is known for them",
    from: "    elseif bareSlots > 0 then", to: "    elseif false then" },

  // The count comes from the Enhance tab's own logic, or the two drift apart again.
  { gate: "todotest", file: "Valuate.lua",
    label: "the to-do count stops coming from the Enhance tab and can disagree with it again",
    from: "    if ns.CountEnhanceTodo then canEnhance, bareSlots = ns.CountEnhanceTodo() end",
    to: "    canEnhance, bareSlots = 0, 0" },

  // No scale means no ranking, so there is no honest count to put on a list.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    scope: { start: "function ns.CountEnhanceTodo()", end: "\n    local bySlot = ns.CollectEnhancements()" },
    label: "a to-do count is produced with no scale to rank against",
    from: "    if not scaleName then return 0, 0 end", to: "" },

  // ---- advice that names your professions (v0.184.0a) ----------------------
  // "Open Enchanting or a crafting profession" is useless to a miner-skinner, and worse than
  // useless: it implies the feature would work if they went and did something.

  // A failed read is not "you have none". The skill list returns nothing when its headers are
  // collapsed, which is the exact quirk the Settings overrides exist for.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "an unreadable skill list is reported as having no professions at all",
    from: "        return {}, {}, true", to: "        return {}, {}, false" },

  // Only professions that make something wearable. Sending someone to open Cooking is the
  // failure this list exists to prevent.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "gathering and consumable professions are offered as places to find enhancements",
    from: "        if known[prof.name] then", to: "        if true then" },

  // Once a book is read, telling you to open it again is noise that outlives its usefulness.
  { gate: "enhancesnapshot", file: "ui/Enhance.lua",
    label: "it keeps telling you to open a book it has already read",
    from: "            if not snap.books[prof.name] then unread[#unread + 1] = prof end",
    to: "            unread[#unread + 1] = prof" },

  // ---- the account-wide scale library (v0.185.0a) --------------------------
  // Writes to a saved variable shared by every character on the account, and none of its
  // behaviour was gated - only the existence of its methods.

  // THE TRAP THE SOURCE NAMES. ImportScale returns a result CODE and every code is truthy:
  // SUCCESS is 1, ALREADY_EXISTS and TAG_ERROR are numbers too. Passing one straight through
  // makes a failure read as a success, and the caller then tells you your scale is on this
  // character when it is not.
  { gate: "librarytest", file: "ImportExport.lua",
    label: "a failed library load reports success, because every result code is truthy",
    from: "    if status == Valuate.ImportResult.SUCCESS then",
    to: "    if status then" },

  // A refusal that does not name the entry turns a typo into a mystery.
  { gate: "librarytest", file: "ImportExport.lua",
    label: "a missing library entry is refused without saying which one",
    from: "    if not tag then return false, \"no library entry called '\" .. tostring(entryName) .. \"'\" end",
    to: "    if not tag then return false, \"not found\" end" },

  // Deleting something that was not there is not a deletion.
  { gate: "librarytest", file: "ImportExport.lua",
    label: "deleting an entry that does not exist reports success",
    from: "    if lib[entryName] == nil then return false end", to: "" },

  // pairs() is not an order, and this list reaches a menu.
  { gate: "librarytest", file: "ImportExport.lua",
    label: "the library list reshuffles between openings",
    from: "    table.sort(names)", to: "" },

  // The entry is keyed on the DISPLAY name, which is what you would look for.
  { gate: "librarytest", file: "ImportExport.lua",
    label: "entries are filed under the internal key rather than the name you see",
    from: "    local entryName = scale.DisplayName or scaleName", to: "    local entryName = scaleName" },

  // The reason is passed THROUGH. "Couldn't serialise that scale" is unactionable when the
  // real problem is a brace in the name, which you can simply fix.
  { gate: "librarytest", file: "ImportExport.lua",
    label: "a serialisation failure is reported with a generic reason instead of the real one",
    from: "    if not tag or tag == \"\" then return false, why or \"couldn't serialise that scale\" end",
    to: "    if not tag or tag == \"\" then return false, \"couldn't serialise that scale\" end" },

  // ---- the bound on the only irreversible action (v0.186.0a) ---------------
  // deletetest.js proves WHICH items may never be touched. These prove how many are destroyed,
  // in what order, and that the preview predicts it. WoW has no undo and no buyback.

  // THE BOUND. Two slots short of the target deletes two items, not the whole junk pile.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "auto-delete empties the whole junk pile instead of stopping at the free-slot target",
    from: "        needed = keepFree - free", to: "        needed = #candidates" },

  { gate: "deletelimit", file: "Valuate.lua",
    label: "the loop ignores its own limit and deletes every candidate",
    from: "        if removed >= needed then break end", to: "" },

  // The gate that stops it running at all when the bags are fine.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "cleanup runs even when the bags are already at the target",
    from: "    if not preview and free >= keepFree then", to: "    if false then" },

  // "Delete now" means "run the normal cleanup immediately", not "empty my bags". This is the
  // one place a reasonable person might have made an exception.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "on-demand cleanup ignores the free-slot bound and deletes everything it can",
    from: "    local force = opts.force == true", to: "    local force = true" },

  // A preview that deletes is not a preview.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "preview mode actually deletes",
    from: "    local dryRun = preview or (options.autoDeleteDryRun == true)", to: "    local dryRun = false" },

  // table.sort is not stable and equal vendor prices are the norm among junk, so without a
  // total order the preview can rank a different item than the delete removes.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "equal-priced junk has no tie-break, so preview and delete can disagree",
    from: "        if a.bag ~= b.bag then return a.bag < b.bag end", to: "" },

  { gate: "deletelimit", file: "Valuate.lua",
    label: "the most valuable junk is deleted first instead of last",
    from: "        if a.value ~= b.value then return a.value < b.value end",
    to: "        if a.value ~= b.value then return a.value > b.value end" },

  // Bags shift between the scan and the delete: another addon, a stack merging.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "a slot whose contents changed since the scan is deleted anyway",
    from: "            if nowLink ~= c.link or nowLocked then", to: "            if false then" },

  // A locked slot is mid-move, mid-split, or waiting on the server.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "a locked slot is treated as ordinary junk",
    from: "                if isJunk and slotLocked then", to: "                if false then" },

  // The confirmation dialog exists to prevent exactly this kind of accident.
  { gate: "deletelimit", file: "Valuate.lua",
    label: "an item left on the cursor by a confirmation popup is counted as deleted",
    from: "                if CursorHasItem and CursorHasItem() then\n                    ClearCursor()",
    to: "                if false then\n                    ClearCursor()" },

  // ---- suggesting a quest reward is not taking it (v0.187.0a) --------------
  // A quest reward is irreversible in a way even deletion is not: the other choices are gone
  // the moment the quest completes, and there is no buyback for a road not taken.

  // THE ONE THAT MATTERS. Two features share this function - one draws a highlight, the other
  // completes the quest. Crossed, the addon completes quests it was only asked to advise on.
  { gate: "questaction", file: "Valuate.lua",
    label: "marking the best reward also takes it, with auto turn-in switched off",
    from: "    if options.autoQuestTurnIn then\n        if options.chatMessages then\n            if bestScore then",
    to: "    if true then\n        if options.chatMessages then\n            if bestScore then" },

  // The feature switch itself.
  { gate: "questaction", file: "Valuate.lua",
    label: "quest rewards are chosen even with the feature switched off",
    from: "    if not options.autoQuestReward then", to: "    if false then" },

  // No scale, no weights, no opinion - and a guess here spends a choice you cannot get back.
  { gate: "questaction", file: "Valuate.lua",
    scope: { start: "function Valuate:AutoSelectBestQuestReward", end: "\n    local scored, links" },
    label: "a reward is chosen with no active scale to score against",
    from: "    if not scale then", to: "    if false then" },

  // ChooseQuestReward returns nil when it should not guess.
  { gate: "questaction", file: "Valuate.lua",
    label: "the policy declining to choose is ignored and a reward is taken anyway",
    from: "    if not bestIndex then return end", to: "    bestIndex = bestIndex or 1" },

  // The reward that most improves your gear, not the biggest number in a vacuum: a strong
  // weapon you will never beat your current best with should lose to a modest trinket that
  // fills an empty slot.
  { gate: "questaction", file: "Valuate.lua",
    label: "the highest raw score wins over the reward that actually upgrades a slot",
    from: "                delta = score - Valuate:GetUpgradeBaseline(link, scale, scaleName),",
    to: "                delta = score," },

  // Index 0 is the guaranteed reward on a quest with nothing to choose.
  { gate: "questaction", file: "Valuate.lua",
    label: "a quest with no reward choice is completed even with turn-in switched off",
    from: "        if options.autoQuestTurnIn then\n            if options.chatMessages then",
    to: "        if true then\n            if options.chatMessages then" },

  // ---- rolling on loot (v0.188.0a) -----------------------------------------
  // The third thing this addon does on your behalf that cannot be taken back. A wrong Need
  // costs someone else the item and costs you the reputation.

  // THE ONE THAT MATTERS. Greed on a bad guess is a shrug; Need on one is a fight.
  { gate: "rollaction", file: "Valuate.lua",
    label: "Need is rolled on anything Need is offered on, wanted or not",
    from: "    if wants and canNeed then return 1, \"Need\" end",
    to: "    if canNeed then return 1, \"Need\" end" },

  // Need is frequently not offered for something you cannot use yet - a recipe above your
  // skill is exactly that - and Greed still wins it.
  { gate: "rollaction", file: "Valuate.lua",
    label: "an item you want but cannot Need on is passed instead of Greeded",
    from: "    if canGreed then return 2, \"Greed\" end", to: "" },

  // Rolls expire. One grace period, and no more: without the guard an item the client never
  // caches defers forever and the roll is lost by inaction.
  { gate: "rollaction", file: "Valuate.lua",
    label: "an uncached item defers forever and the roll expires unanswered",
    from: "    if link and not GetItemInfo(link) and not isRetry then",
    to: "    if link and not GetItemInfo(link) then" },

  // ...and the other direction: never waiting means rolling on stats that have not arrived.
  { gate: "rollaction", file: "Valuate.lua",
    label: "it rolls immediately on an item whose data has not arrived yet",
    from: "        ValuateAfter(0.5, function() Valuate:AutoRollOnLoot(rollID, true) end)", to: "" },

  // The feature switch.
  // Scoped: ConfirmAutoLootRoll guards on the same option and the same line, so an unscoped
  // anchor lands on whichever comes first rather than on the one this gate drives.
  { gate: "rollaction", file: "Valuate.lua",
    scope: { start: "function Valuate:AutoRollOnLoot", end: "-- Confirms the" },
    label: "loot is rolled on with the feature switched off",
    from: "    if not options.autoRollLoot or not rollID then return end", to: "    if not rollID then return end" },

  // Both classification options default ON, so an unset one must not switch them off.
  { gate: "rollaction", file: "Valuate.lua",
    label: "the recipe check is skipped unless its option is explicitly enabled",
    from: "    if link and options.autoRollRecipes ~= false then",
    to: "    if link and options.autoRollRecipes then" },

  { gate: "rollaction", file: "Valuate.lua",
    label: "the trade-good check is skipped unless its option is explicitly enabled",
    from: "    if link and not isRecipe and options.autoRollTradeGoods ~= false then",
    to: "    if link and not isRecipe and options.autoRollTradeGoods then" },

  // Both use the same private tooltip, and the second call repoints it - so asking twice is
  // not merely wasteful, it is a different answer about a different thing.
  { gate: "rollaction", file: "Valuate.lua",
    label: "a recipe is asked about again as a trade good, repointing the shared tooltip",
    from: "    if link and not isRecipe and options.autoRollTradeGoods ~= false then",
    to: "    if link and options.autoRollTradeGoods ~= false then" },

  // Switched ON and unable to work is the case worth recording.
  { gate: "rollaction", file: "Valuate.lua",
    label: "a client with no roll API looks idle rather than saying it cannot work",
    from: "        Valuate:MarkAutomation(\"autoRoll\", \"this client has no loot-roll API - cannot roll\")",
    to: "" },

  // A Greed on a learnable recipe reads as the feature failing unless it says Need was not on
  // offer.
  { gate: "rollaction", file: "Valuate.lua",
    label: "a Greed forced by Need being unavailable is reported as a plain Greed",
    from: "                reason = reason .. \", |cFFFF8800Need not offered|r\"\n            end\n        elseif isMaterial then",
    to: "            end\n        elseif isMaterial then" },

  // ---- the scaled item level (v0.189.0a) -----------------------------------
  // The bug this project already had once, reappearing in a feature written after the fix.
  // GetItemInfo index 4 is the item TEMPLATE's level; the tooltip is what the client renders
  // for THIS character, and on a scaling server those are different numbers.

  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "the enchant list reads the item template's level instead of the scaled one",
    from: "    local stats = Valuate:GetStatsForTooltipSetter(\"SetInventoryItem\", slotId)",
    to: "    local stats = { ItemLevel = select(4, GetItemInfo(GetInventoryItemLink(\"player\", slotId))) }" },

  // Nil means "no constraint I could read", and RankForSlot already treats that as permissive.
  // Zero would demote every enchant that carries a requirement at all.
  { gate: "enhancepanel", file: "ui/Enhance.lua",
    label: "an unreadable item level becomes zero, demoting every enchant with a requirement",
    from: "    return stats and stats.ItemLevel or nil", to: "    return (stats and stats.ItemLevel) or 0" },

  // ---- the option backfill (v0.190.0a) -------------------------------------
  // Every login fills in whatever this character has not saved. One failure mode, severe and
  // quiet: overwrite a key that is already there, and every choice you have made reverts.

  // THE ONE THAT MATTERS. Options defaulting to false are unharmed by any version of this
  // code; the dozen that default to TRUE are not. A truthiness test reads a deliberate false
  // as "missing" and switches the feature back on at every login.
  // Scoped: the same nil-check shape appears elsewhere, and an unscoped anchor lands on
  // whichever comes first in the file rather than on the backfill this gate drives.
  { gate: "optiondefaults", file: "Valuate.lua",
    scope: { start: "local function ApplyOptionDefaults", end: "function Valuate:GetOptions" },
    label: "a feature you switched off turns itself back on at the next login",
    from: "        if options[key] == nil then", to: "        if not options[key] then" },

  // ...and the other direction, or "never overwrite" would pass by doing nothing at all.
  { gate: "optiondefaults", file: "Valuate.lua",
    label: "nothing is ever filled in, so a new option never reaches an existing character",
    from: "    for key, value in pairs(DEFAULT_OPTIONS) do", to: "    for key, value in pairs({}) do" },

  // Handing out the default table itself lets one character write into DEFAULT_OPTIONS, and
  // through it into every other character on the account.
  { gate: "optiondefaults", file: "Valuate.lua",
    label: "table defaults are shared, so two characters edit the same one",
    from: "                options[key] = {}", to: "                options[key] = value" },

  // A fresh character must end up with a populated table, not an empty one that every later
  // reader then treats as "you turned everything off".
  { gate: "optiondefaults", file: "Valuate.lua",
    label: "a character with nothing saved gets an empty options table",
    from: "        ApplyOptionDefaults(ValuateOptions)", to: "" },

  // ---- what a locked weapon slot overrides (v0.191.0a) ---------------------
  // A lock pins a slot; weapon SETS are recomputed every scan, because a set is a comparison
  // between configurations and a pinned slot is not part of any comparison. Both facts are
  // true and they contradict each other on screen, which is the worst way to be right.

  { gate: "bestequiptest", file: "ui/BestEquipment.lua",
    label: "the weapon-set tooltip claims a main hand you have pinned to something else",
    from: "    local mh = be.locks[16] and (be[16] and be[16].itemName or \"a weapon\")",
    to: "    local mh = nil" },

  { gate: "bestequiptest", file: "ui/BestEquipment.lua",
    label: "a locked off hand goes unmentioned",
    from: "    local oh = be.locks[17] and (be[17] and be[17].itemName or \"something\")",
    to: "    local oh = nil" },

  // Both locked reads as two separate half-truths unless it says the set describes NEITHER.
  { gate: "bestequiptest", file: "ui/BestEquipment.lua",
    label: "both slots locked reports only the main hand, so the off hand looks described",
    from: "    if mh and oh then", to: "    if false then" },

  // A weapon set has nothing to say about your chest, and a note that fired for any lock at
  // all would appear on every tooltip for every scale the moment you pinned anything.
  { gate: "bestequiptest", file: "ui/BestEquipment.lua",
    label: "any locked slot at all produces a weapon-set note, including a locked chest",
    from: "    if type(be) ~= \"table\" or type(be.locks) ~= \"table\" then return nil end",
    to: "    if type(be) ~= \"table\" then return nil end\n    be.locks = be.locks or { [16] = true }" },

  // ---- upgrades waiting in your bank (v0.192.0a) ---------------------------
  // The bank is the one place this addon knows about that Equip All cannot reach, so a better
  // item can sit there indefinitely with nothing saying so.

  { gate: "todotest", file: "Valuate.lua",
    label: "upgrades sitting in your bank never appear on the to-do list",
    from: "    if bankUpgrades > 0 then", to: "    if false then" },

  // THE `and` TRAP, which the sockets block below already carries a warning about: an `and`
  // expression adjusts to a SINGLE value, so the third return - the only one wanted here -
  // becomes nil and the item can never appear. Written that way once already in this function.
  { gate: "todotest", file: "Valuate.lua",
    from: "        local _, _, inBank = Valuate:CountEquippableUpgrades(primaryName)",
    to: "        local inBank = Valuate.CountEquippableUpgrades and Valuate:CountEquippableUpgrades(primaryName)",
    label: "the bank count is read as a single return and is always nil" },

  // The bank contents are only upgrades RELATIVE to a scale, and this list already refuses to
  // rank anything without one.
  { gate: "todotest", file: "Valuate.lua",
    from: "    if Valuate.CountEquippableUpgrades and primaryName then",
    to: "    if Valuate.CountEquippableUpgrades then",
    label: "a bank upgrade count is claimed with no active scale to judge against" },

  // Ordered below what you can equip right now: a list that puts the trip across the city
  // first is a list you learn to skim.
  { gate: "todotest", file: "Valuate.lua",
    from: "            text = string.format(\"%d upgrade%s waiting in your bank\", bankUpgrades,",
    to: "            text = string.format(\"%d upgrade%s\", bankUpgrades,",
    label: "the bank item does not say where the upgrades are" },

  // ---- reading the vendor notes back (v0.193.0a) ---------------------------
  // The capture half always worked and the recall half never existed - a note only reached the
  // screen when its recipe happened to be the top recommendation on an Enhance row.

  // NOT MUTATED: the `name ~= "__schema"` half of the note filter. The marker is a NUMBER, so
  // the `type(note) == "table"` test beside it already excludes it, and removing the name
  // check changes nothing today. It stays in the source because it states the intent and
  // would become load-bearing the moment that marker grew into a table - the same call this
  // project already made for PriceKeepsRow, and the same reason.

  // Newest first: "where did I just see that" is the question this answers.
  { gate: "enhance", file: "ui/Enhance.lua",
    scope: { start: "function ns.SearchVendorNotes", end: "function ns.FormatVendorNote" },
    from: "        if a.at ~= b.at then return a.at > b.at end", to: "        if a.at ~= b.at then return a.at < b.at end",
    label: "the oldest note is listed first, so the one you just took is last" },

  // Ties break on name, or the order reshuffles between openings - and two notes from one
  // vendor share a timestamp far more often than not.
  { gate: "enhance", file: "ui/Enhance.lua",
    scope: { start: "function ns.SearchVendorNotes", end: "function ns.FormatVendorNote" },
    from: "        return a.name < b.name", to: "        return false",
    label: "notes sharing a timestamp come back in a different order each time" },

  // The cap is on what is SHOWN. A count capped alongside it would make a truncated list read
  // as "that is all of them".
  { gate: "enhance", file: "ui/Enhance.lua",
    from: "    local matched = #out", to: "    local matched = math.min(#out, limit or #out)",
    label: "the match count is capped with the display, hiding that anything was left out" },

  // Case-insensitive: you are typing from memory, not copying.
  { gate: "enhance", file: "ui/Enhance.lua",
    from: "            if not needle or name:lower():find(needle, 1, true) then",
    to: "            if not needle or name:find(needle, 1, true) then",
    label: "searching only matches the exact case you happened to type" },

  // Never having looked is not the same as there being none.
  { gate: "enhance", file: "ui/Enhance.lua",
    from: "    if total == 0 then", to: "    if false then",
    label: "an empty note store says nothing at all, rather than how notes get taken" },

  // ---- saying whether the filter works (v0.194.0a) -------------------------
  // Everything this addon does is invisible when it works and equally invisible when it does
  // not. A status line that flagged nothing would be one more thing that looks fine.

  // THE MOST LIKELY REASON IT IS "NOT FILTERING", and the one the panel cannot tell you
  // because with no scale it never draws at all.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    from: "    add(\"Active scale\", scaleName or \"NONE - nothing to rank by\", scaleName ~= nil)",
    to: "    add(\"Active scale\", scaleName or \"NONE - nothing to rank by\", true)",
    label: "having no active scale is reported as though it were fine" },

  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    from: "    add(\"Hook installed\", hooked and \"yes\" or \"no\", hooked == true)",
    to: "    add(\"Hook installed\", hooked and \"yes\" or \"no\", true)",
    label: "a hook that never installed is reported as though it were fine" },

  // The memo is the honest measure of whether it has judged anything at all.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    from: "    add(\"Verdicts remembered\", tostring(memoCount), true)",
    to: "    add(\"Verdicts remembered\", \"0\", true)",
    label: "the verdict count is always zero, so working and idle look identical" },

  // A large number here explains a list that never narrows, which is otherwise unexplainable.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    from: "    for _ in pairs(attempts) do stuck = stuck + 1 end", to: "",
    label: "items the client never answers for are not counted, so a stuck list has no cause" },

  // ---- which integrations are actually running (v0.195.0a) -----------------
  // Four addons extend this one and each fails silently. The pairing with the HOST is the whole
  // design: an integration is only interesting when the thing it extends is present.

  // THE STATE WORTH ACTING ON. Host here, integration not - your bags stop sorting and nothing
  // says why.
  { gate: "integrations", file: "Valuate.lua",
    from: "        elseif hostHere then state = \"MISSING\"",
    to: "        elseif hostHere then state = \"idle\"",
    label: "a missing integration is reported as idle, so a broken one looks deliberate" },

  // ...and the opposite, which is how a report becomes one you stop reading: warning about an
  // addon you never installed, for a host you never installed.
  { gate: "integrations", file: "Valuate.lua",
    from: "        else state = \"idle\" idle = idle + 1 end",
    to: "        else state = \"MISSING\" idle = idle + 1 end",
    label: "integrations for hosts you never installed are reported as missing" },

  // Idle ones are COUNTED, not listed. Naming four addons you have never heard of buries the
  // one line that mattered.
  { gate: "integrations", file: "Valuate.lua",
    from: "        if row.state ~= \"idle\" then", to: "        if true then",
    label: "every idle integration is listed by name, burying the one that matters" },

  // An orphan is odd and harmless. Colouring it as a failure sends someone to fix nothing.
  { gate: "integrations", file: "Valuate.lua",
    from: "                print(string.format(\"  |cFFAAAAAA%s is loaded but %s is not, so it is doing \" ..",
    to: "                print(string.format(\"  |cFFFF4040%s is NOT loaded but %s is not, so it is doing \" ..",
    label: "an integration with nothing to extend is coloured as a failure" },

  // ---- marking gear as surplus (v0.196.0a) ---------------------------------
  // ComputeSurplusGear had 16 assertions and ZERO mutations, so none of them had ever been
  // shown to fail on a broken guard. Its output marks an item as junk in AdiBags, and Valuate
  // reads AdiBags' junk classification when deciding what to sell and what to DELETE - so
  // every `return false` below is a protection standing between your gear and a bin.

  // No trustworthy best-in-slot data means no conclusions at all.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if not bestDataUsable then return false end", to: "",
    label: "gear is marked surplus before any usable best-in-slot data exists" },

  // You built that set deliberately, and nothing in it has to be best-in-slot for you to want it.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if equipmentSetItems[itemId] then return false end", to: "",
    label: "gear in one of your saved equipment sets is marked surplus" },

  // The memo, which had no test at all until v0.196.0a - only the decision inside it did.

  // Storing an uncached item's answer makes the "no" permanent for the session: the item
  // finishes loading and is never reconsidered, which is the feature silently doing nothing for
  // exactly the items that were slow to arrive.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if GetItemInfo(itemId) then", to: "	if true then",
    label: "an uncached item's answer is remembered, so it is never reconsidered" },

  // ...and the other direction: never memoising re-derives every answer on every bag repaint.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if cached ~= nil then return cached end", to: "",
    label: "the memo is never read, so every bag repaint re-derives every item" },

  // Off means off, and means not computing either - this runs per item per repaint.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if not self.db or not self.db.profile.markNonBestAsJunk then return false end", to: "",
    label: "gear is marked surplus with the option switched off" },

  // NOT MUTATED: `if not link then return false end` inside ComputeSurplusGear. GetItemInfo
  // returns everything or nothing, so link and equipLoc are nil together and the equipLoc guard
  // below already covers it - removing the link check changes no answer. It stays because it
  // states a different intent ("not cached yet, decide later") from the one below it ("not
  // gear"), and because the memo above depends on that distinction being real. Third time this
  // project has recorded an equivalent rather than pretending to test it; see PriceKeepsRow.

  // Valuate must actually hold a best for the slot. Without one, this item's absence from the
  // best list means nothing whatsoever.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if not SlotHasBest(equipLoc) then return false end", to: "",
    label: "an item is called surplus for a slot Valuate holds no best for" },

  // The quality ceiling is the user's stated limit on how far this may reach.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if not quality or quality > maxQuality then return false end",
    to: "	if not quality or quality > 99 then return false end",
    label: "the quality ceiling is ignored, so epics can be marked surplus" },

  // ...and an unknown quality is not a low one.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "	if not quality or quality > maxQuality then return false end",
    to: "	if quality and quality > maxQuality then return false end",
    label: "an item whose quality could not be read is treated as junk-eligible" },

  // Best-in-slot keeps it, which is the single most important line in the function.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "		if type(best) == \"table\" and next(best) then return false end", to: "",
    label: "your best-in-slot item is marked surplus" },

  // Not equippable yet, but will be. Marking it now bins it before you reach the level.
  { gate: "surplustest", file: "../Valuate-AdiBags/Valuate-AdiBags.lua",
    from: "		if type(future) == \"table\" and next(future) then return false end", to: "",
    label: "an item you cannot use yet but will is marked surplus" },

  // ---- the PassLoot upgrade verdict (v0.197.0a) ----------------------------
  // Never mutation-tested. A verdict of true means PassLoot performs whatever action you
  // configured on that item - Need, Greed, pass, announce - so a branch that answers the wrong
  // way acts on your behalf in a group.

  // THE HISTORICAL BUG, recorded in a comment beside the caller: this used to return TRUE, so a
  // character who had never scanned matched EVERYTHING.
  { gate: "passloottest", file: "../Valuate-PassLoot/Valuate.lua",
    from: "    return false, \"no scan data at all - run /valuate scan\"",
    to: "    return true, \"no scan data at all - run /valuate scan\"",
    label: "a character who has never scanned matches every item" },

  // Same shape one level down: scanned, but never for THIS scale.
  { gate: "passloottest", file: "../Valuate-PassLoot/Valuate.lua",
    from: "    return false, \"this scale has never been scanned - run /valuate scan\"",
    to: "    return true, \"this scale has never been scanned - run /valuate scan\"",
    label: "a scale that has never been scanned matches every item" },

  // Nothing tracked for the slot means anything beats it - an empty slot is the one case where
  // "no baseline" genuinely is an upgrade rather than an unknown.
  { gate: "passloottest", file: "../Valuate-PassLoot/Valuate.lua",
    from: "    return true, \"nothing tracked for this slot, so anything is an upgrade\"",
    to: "    return false, \"nothing tracked for this slot, so anything is an upgrade\"",
    label: "an empty slot never matches, so the first item for it is passed over" },

  // Strictly greater. An equal score is not an upgrade, and treating it as one churns your gear
  // for nothing every time a sidegrade drops.
  { gate: "passloottest", file: "../Valuate-PassLoot/Valuate.lua",
    from: "  if itemScore > bestScore then", to: "  if itemScore >= bestScore then",
    label: "an item scoring exactly what you already have counts as an upgrade" },

  // The reason travels with the verdict. A rule that fires or does not with no explanation is
  // one you cannot configure.
  { gate: "passloottest", file: "../Valuate-PassLoot/Valuate.lua",
    from: "  return false, string.format(\"%s does not beat the baseline %s\", tostring(itemScore), tostring(bestScore))",
    to: "  return false",
    label: "a refusal gives no reason, so a rule that never fires cannot be diagnosed" },

  // ---- grouping future upgrades (v0.198.0a) --------------------------------
  // Never mutation-tested. This is the report behind "is this worth carrying for another eight
  // levels", and the same future-upgrade data is a PROTECTION in two destructive paths - the
  // delete guard and the AdiBags surplus marking - so a wrong answer here reads as a tidy plan
  // while an item you will want at 60 goes in a bin.

  // Keyed on the LINK, so an item wanted by three scales is one line naming three rather than
  // three lines. Keyed on anything per-scale and the list triples in length.
  { gate: "futuretest", file: "Valuate.lua",
    from: "                    local entry = seen[f.itemLink]", to: "                    local entry = nil",
    label: "an item wanted by three scales is listed three times" },

  // The LOWEST requirement wins when two scales disagree: it is the same item, and the earlier
  // level is the true answer to when you can wear it.
  { gate: "futuretest", file: "Valuate.lua",
    from: "                    if (f.reqLevel or 0) < entry.level then entry.level = f.reqLevel or 0 end",
    to: "                    if (f.reqLevel or 0) > entry.level then entry.level = f.reqLevel or 0 end",
    label: "the highest requirement is reported, so the item looks further away than it is" },

  // Above your level is a promise the addon can keep; at or below it is something a level will
  // never fix - an unmet proficiency, most often - and belongs in the other list entirely.
  { gate: "futuretest", file: "Valuate.lua",
    from: "        if entry.level > playerLevel then", to: "        if entry.level >= playerLevel then",
    label: "an item you can already reach is filed as a future one, promising a level that will not help" },

  // ...and the same boundary the other way.
  { gate: "futuretest", file: "Valuate.lua",
    from: "        if entry.level > playerLevel then", to: "        if true then",
    label: "everything is filed as a future upgrade, including what a level cannot fix" },

  // pairs() is not an order and these names reach the screen beside an item.
  { gate: "futuretest", file: "Valuate.lua",
    scope: { start: "local function GroupFutureUpgrades", end: "function Valuate:PrintFutureUpgrades" },
    from: "        table.sort(names)", to: "",
    label: "the scale names beside an item reshuffle between runs" },

  // No data means no plan, rather than an empty plan presented as one.
  { gate: "futuretest", file: "Valuate.lua",
    from: "    if not bestEquipment or not activeScales then return {}, {} end", to: "",
    label: "a character with no scan data still gets a future-upgrade plan" },

  // ---- importing a scale (v0.198.0a) ---------------------------------------
  // Never mutation-tested. Importing writes into your scale table, and a scale is an hour of
  // tuning that nothing else on the character can reconstruct.

  // THE OVERWRITE GUARD. Without it, pasting a tag whose name you already use silently replaces
  // the scale you have been refining, with no prompt and nothing to undo it.
  { gate: "importtest", file: "ImportExport.lua",
    from: "    if alreadyExists and not overwrite then", to: "    if false then",
    label: "importing a scale silently replaces one of the same name" },

  // ...and the other direction: refusing WITH overwrite makes the confirm button do nothing,
  // which reads as the import being broken.
  { gate: "importtest", file: "ImportExport.lua",
    from: "    if alreadyExists and not overwrite then", to: "    if alreadyExists then",
    label: "confirming an overwrite still refuses, so the import appears broken" },

  // A tag this addon cannot read must not half-import. The parse is the gate, and it returns a
  // CODE - every one of which is truthy, which is the trap the library wrapper exists for.
  // Scoped: the same guard shape appears in the multi-tag path, and an unscoped anchor lands
  // on whichever comes first rather than on the single import this gate drives.
  { gate: "importtest", file: "ImportExport.lua",
    scope: { start: "function Valuate:ImportScale", end: "function Valuate:ParseMultipleScaleTags" },
    from: "    if not scaleName then", to: "    if false then",
    label: "an unreadable tag is imported anyway, writing nil into your scale table" },

  // A version error and a malformed tag are different problems with different fixes: one means
  // "this came from a newer Valuate", the other means "this text is not a tag".
  { gate: "importtest", file: "ImportExport.lua",
    from: "        if versionMessage then", to: "        if false then",
    label: "a tag from a newer version is reported as malformed, sending you to fix the wrong thing" },

  // ---- what the UI check covered (v0.199.0a) -------------------------------
  // The walk measures only VISIBLE things, so it judges the tab you are on and never the window.
  // "Clean, 412 things measured" read as the latter.

  // Scoped to the CLEAN branch: the failing branch carries the same line, deliberately, and an
  // unscoped anchor lands on whichever comes first.
  { gate: "uicheck", file: "ui/UICheck.lua",
    scope: { start: "if #problems == 0 then", end: "\n    else" },
    from: "        if unchecked > 0 then", to: "        if false then",
    label: "a clean result never mentions the tabs it did not open" },

  // Non-panel entries share the tabs table - selectTab and the button list - and counting them
  // as tabs inflates the warning into nonsense.
  { gate: "uicheck", file: "ui/UICheck.lua",
    from: "        if type(panel) == \"table\" and panel.IsShown and key:find(\"Panel\", 1, true) then",
    to: "        if type(panel) == \"table\" then",
    label: "the tab count includes things that are not tabs" },

  // Naming the tab is what turns a number into a verdict you can place.
  { gate: "uicheck", file: "ui/UICheck.lua",
    from: "            if panel:IsShown() then active = label end", to: "",
    label: "the report never says which tab it actually measured" },

  // ---- the self-test verdict (v0.200.0a) -----------------------------------
  // Three blocks inside RunSelfTest depend on the state of the character running it, each was
  // skipped silently, and the verdict still printed PASSED. "Self-test PASSED (42 checks)" is
  // the sentence somebody repeats back to you, and it was true and misleading at once.

  { gate: "selftestverdict", file: "Valuate.lua",
    from: "    local missing = #skipped > 0 and string.format(\", %d group(s) not run\", #skipped) or \"\"",
    to: "    local missing = \"\"",
    label: "the headline claims a clean pass while whole groups were never run" },

  // Naming them is what makes each one fixable: equip something, load AdiBags, pick a scale.
  { gate: "selftestverdict", file: "Valuate.lua",
    from: "        lines[#lines + 1] = \"not run: \" .. what", to: "",
    label: "the skipped groups are counted but never named, so none of them can be acted on" },

  // The count belongs on the FAILING line too. You fix what it named, run it again, and read
  // the next result as the whole picture.
  { gate: "selftestverdict", file: "Valuate.lua",
    from: "        lines[1] = string.format(\"Self-test: %d passed, %d FAILED%s.\", pass or 0, fail, missing)",
    to: "        lines[1] = string.format(\"Self-test: %d passed, %d FAILED.\", pass or 0, fail)",
    label: "a failing run hides that groups were skipped as well" },

  // A skip is not a failure. Wording it as one sends someone to fix what is not broken, and a
  // diagnostic that cries wolf stops being read.
  { gate: "selftestverdict", file: "Valuate.lua",
    from: "        lines[#lines + 1] = \"not run: \" .. what",
    to: "        lines[#lines + 1] = \"FAILED: \" .. what",
    label: "a group that could not run is reported as a failure" },

  // ---- the scroll range tracks the frame (v0.178.0a) ------------------------
  // How far there is to scroll depends on two numbers and only one of them changes when the
  // list does. The window animates to its tab height AFTER the refresh that computed the
  // range, and it is user-resizable besides.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "the scroll range is computed once and never tracks the frame it is measured against",
    from: "    scrollFrame:SetScript(\"OnSizeChanged\", ApplyScrollRange)", to: "" },

  // A bar that cannot move reads as a list that failed to load.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "an inert scroll bar sits there when the whole list already fits",
    from: "        if range > 0 then scrollBar:Show() else scrollBar:Hide() end", to: "" },

  // A thumb left past the end of a shorter list scrolls the content off the top.
  { gate: "enhancepanel", file: "ui/EnhancePanel.lua",
    label: "a bar scrolled to the bottom stays there when the list gets shorter",
    from: "        if scrollBar:GetValue() > range then scrollBar:SetValue(range) end", to: "" },

  // ---- a locked slot survives a scan (v0.177.3a) ---------------------------
  // Locking a slot and pressing Scan emptied it. Every assignment site guards on
  // `if not locks[slotId]` and every one of them was right; the reset that ran before them
  // kept only the padlock. The bug was not in the code that mentions locks.
  { gate: "locktest", file: "Valuate.lua",
    label: "a locked slot is emptied by the next scan, which is the opposite of a lock",
    from: "                if isLocked and previous[slotId] then", to: "                if false then" },

  // The other direction. "Preserve everything" also keeps the locked slot, and freezes
  // best-in-slot at whatever the first scan of the session found - a lock on every slot,
  // shown nowhere.
  { gate: "locktest", file: "Valuate.lua",
    label: "every slot is preserved, so a scan never updates anything again",
    from: "        local locks = previous and previous.locks",
    to: "        local locks = previous and setmetatable({}, { __index = function() return true end })" },

  // ---- fail closed on an unreadable item (v0.177.2a) -----------------------
  // The bug that sold an upgrade. An item whose stats could not be read lost the upgrade
  // protection AND the best-in-slot protection at once, because an item the scan cannot read
  // is not in the scan - five protections agreeing is not five protections when one failure
  // silences all of them.
  { gate: "deletetest", file: "Valuate.lua",
    label: "gear whose stats could not be read falls through every protection and is sold",
    from: "            local reason = ns.UnreadableGearReason and ns.UnreadableGearReason(link)",
    to: "            local reason = nil" },

  // The other direction, which is what makes the rule survivable: genuine junk still sells.
  // Protecting everything unreadable would switch the feature off in all but name, and a
  // feature that silently does nothing gets turned back on by someone who thinks it is broken.
  { gate: "deletetest", file: "Valuate.lua",
    label: "everything unreadable is protected, so auto-sell quietly stops selling junk",
    from: "    if equipLoc and equipLoc ~= \"\" and equipLoc ~= \"INVTYPE_BAG\" then",
    to: "    if true then" },

  // "Not cached yet" is the constant case, not the rare one: it is most of your bags for the
  // first seconds after a login, which is when you zone into a city and open a merchant.
  { gate: "deletetest", file: "Valuate.lua",
    label: "an item the client has not cached yet is treated as not-gear and sold",
    from: "    if not name then return \"the client has not cached it yet\" end", to: "" },

  // ---- Valuate-TSM, now inside the mutation run too (v0.180.0a) ------------
  // Its 162 assertions had never been mutation-tested: the suite lived outside the gate run,
  // so nothing here could name it as the gate that must fail.

  // The circuit breaker. It exists because a client froze hard enough to need killing, and a
  // breaker that does not break is worse than none - it is a reason not to look further.
  { gate: "siblingsuites", file: "../Valuate-TSM/Core.lua",
    label: "a tripped integration keeps running, so the freeze it caught comes back",
    from: "    return ns.tripped ~= nil or ns.Opts().disabled == true", to: "    return false" },

  // Tripping twice would spam the same message every frame on a path already known to be slow.
  { gate: "siblingsuites", file: "../Valuate-TSM/Core.lua",
    label: "it trips over and over on the same slow path instead of once",
    from: "    if ns.tripped then return end", to: "" },

  // The price ceiling. Your gold and a typed cap are both limits; the binding one is the
  // LOWER. Taking the higher offers things you cannot buy, which is the point of the filter.
  { gate: "siblingsuites", file: "../Valuate-TSM/Search.lua",
    label: "a cap above your gold wins, so it offers you what you cannot afford",
    from: "        if manual > 0 and manual < purse then return manual end",
    to: "        if manual > 0 and manual > purse then return manual end" },

  // Nil is not zero. Hiding every row because the client could not say how much gold you have
  // looks exactly like an empty auction house.
  { gate: "siblingsuites", file: "../Valuate-TSM/Search.lua",
    label: "a failed gold lookup hides every row, which reads as an empty auction house",
    from: "        if purse == nil then return nil end", to: "        if purse == nil then purse = 0 end" },

  // NOT MUTATED: `price <= 0` in PriceKeepsRow. Zero is truthy in Lua, so a zero buyout reaches
  // the comparison and is kept either way - the source says so, and adding the mutation here
  // only re-proved it. It stays in the source because it states the domain fact and because a
  // later change to the comparison would make it load-bearing with nothing to notice.

  // ---- the LootCollector hook (v0.2.0) -------------------------------------
  // The half that can hang a client. Both guards below are invisible in a small fixture and
  // neither is provable by reading, which is why the gate runs the real loop and counts.

  // A repaint that fires whether or not anything resolved rebuilds the list, re-queues what is
  // still unreadable, drains to nothing new, and asks for another repaint. Forever.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    label: "the driver repaints even when nothing resolved, which never terminates",
    from: "    if resolved > 0 then", to: "    if true then" },

  // Same shape one level down: an item the client has no data for goes back in the queue on
  // every pass, for as long as the window is open.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    label: "an item the client never answers for is retried forever",
    from: "    return memo[link] == nil and (attempts[link] or 0) < MAX_ATTEMPTS",
    to: "    return memo[link] == nil" },

  // The budget itself. Without it, thousands of tooltip builds run inside one repaint.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    label: "the pass has no time budget, so a large database is evaluated inside one repaint",
    from: "                elseif spent or (debugprofilestop() - start) > PASS_BUDGET_MS then",
    to: "                elseif false then" },

  // Their table is reused and wiped on every rebuild, so handing back a copy hands back a view
  // of something about to be emptied.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    label: "the filter rewrites rows even when it is switched off",
    from: "        if ns.mode == \"off\" or type(rows) ~= \"table\" then return rows end",
    to: "        if type(rows) ~= \"table\" then return rows end" },

  // A stat scale has no opinion about mystic scrolls or vendors, and emptying those tabs reads
  // as a broken addon rather than as a filter.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    label: "the Mystic Scrolls and vendor tabs get filtered by stat weights too",
    from: "        if selfRef.currentFilter ~= \"eq\" then return rows end", to: "" },

  // Checked BEFORE the memo is read, by both paths into it. Below the lookup it never ran for
  // anything already memoised, which is every item you had looked at.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    label: "switching spec keeps every verdict computed for the other one",
    from: "    if scaleName and scaleName ~= memoScale then", to: "    if false then" },

  // Their cache is keyed on their own filter state, which our button is not part of.
  // Scoped: SetMode invalidates too, and an unscoped anchor lands on whichever comes first
  // rather than on the driver path this gate drives.
  { gate: "lchook", file: "../Valuate-LootCollector/Filter.lua",
    scope: { start: "local function Repaint()", end: "local resolved = 0" },
    label: "the repaint reuses their cache, handing back the rows built before evaluation",
    from: "    if Viewer.InvalidateFilterCache then Viewer:InvalidateFilterCache() end", to: "" },

  // ---- the LootCollector filter (v0.1.0) -----------------------------------
  // This one hides rows from someone else's list, so every mutation here is asymmetric: the
  // failure is a worldforged upgrade that silently never appeared, and the only evidence of
  // it is an absence you cannot notice.

  // The whole design in one line. An item we could not evaluate stays on screen.
  { gate: "lctest", file: "../Valuate-LootCollector/Score.lua",
    label: "an item that could not be evaluated is hidden rather than shown",
    from: "    if verdict == ns.UNKNOWN or verdict == nil then return true end",
    to: "    if false then return true end" },

  // Mystic scrolls and vendors are not gear. Filtering them by stat weights empties tabs that
  // have nothing to do with this addon, which reads as a broken addon rather than a filter.
  { gate: "lctest", file: "../Valuate-LootCollector/Score.lua",
    label: "non-gear rows are filtered by stat weights, emptying the mystic and vendor tabs",
    from: "    if not isGear then return true end", to: "    if false then return true end" },

  // The two filter modes have to differ, or one of the three button states does nothing.
  { gate: "lctest", file: "../Valuate-LootCollector/Score.lua",
    label: "'My Stats' filters exactly like 'Upgrades', so one button state is dead",
    from: "    if mode == \"stats\" and verdict == \"stats\" then return true end", to: "" },

  // Unreadable stats are not a verdict. Treating them as one bakes "rubbish" into the memo for
  // an item whose only problem was that the client had not answered yet.
  { gate: "lctest", file: "../Valuate-LootCollector/Score.lua",
    label: "stats that could not be read are recorded as a judgement about the item",
    from: "    if score == nil then return ns.UNKNOWN end",
    to: "    if score == nil then return \"worthless\" end" },

  // Zero is a real answer - the scale has no weight on anything the item carries.
  { gate: "lctest", file: "../Valuate-LootCollector/Score.lua",
    label: "an item your scale scores at zero counts as something it values",
    from: "    if score <= 0 then return \"worthless\" end",
    to: "    if score < 0 then return \"worthless\" end" },

  // "Not cached yet" is not "not gear". Answering false here is permanent: the row is judged
  // furniture and never looked at again.
  { gate: "lctest", file: "../Valuate-LootCollector/Score.lua",
    label: "an uncached item is declared not-gear instead of not-yet-known",
    from: "    if not cached then return nil end", to: "    if not cached then return false end" },

  // One cycle function for the button and the slash command. Break it and a state is
  // unreachable from the button while the command can still set it.
  { gate: "lctest", file: "../Valuate-LootCollector/Score.lua",
    label: "the button cycle skips a mode, so one filter state cannot be reached by clicking",
    from: "    if mode == \"upgrades\" then return \"stats\" end",
    to: "    if mode == \"upgrades\" then return \"off\" end" },
// ---- the gates themselves (v0.201.0a) ------------------------------------
  // Nothing checked the eighty JavaScript files doing the checking, and one of them had been
  // quietly broken for weeks. Each of these breaks tools/toolsource.js in one of the three
  // ways it exists to notice.
  //
  // Deliberately aimed at files toolsource does NOT load. It requires mutations.js and
  // nothing else, so a mutation that made a gate throw on require would exit non-zero
  // without the scanner ever running - "caught" for a reason that proves nothing.
  { gate: "toolsource", file: "tools/genloot.js",
    label: "a pattern loses its backslashes and matches letters instead of digits, silently",
    from: "const ADDONS = path.resolve(__dirname, \"..\", \"..\");",
    to: "const stripped = /^(d+)./;\nconst ADDONS = path.resolve(__dirname, \"..\", \"..\");" },

  // gates.js discovers by reading the first 2000 bytes for an @gate line. Lose it and the
  // gate is dropped from every run with no error and no mention - the total ticks down by
  // one where nobody is counting.
  { gate: "toolsource", file: "tools/hotpath.js",
    label: "a gate stops being discovered, so it never runs again and nothing says so",
    from: " * @gate A bag repaint stays cheap",
    to: " * A bag repaint stays cheap" },

  // A mutation aimed at a gate that does not exist can only ever report "caught": the runner
  // fails to spawn the file, and a non-zero exit is exactly what "caught" means.
  { gate: "toolsource", file: "tools/mutations.js",
    label: "a mutation names a gate that does not exist, so it can only ever look caught",
    from: "gate: \"contrast\"", to: "gate: \"nosuchgate\"" },
];
