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
  { gate: "verifytest", file: "Valuate.toc",
    label: "the checklist silently stops growing while the addon does not",
    from: "## Version: 0.119.1a", to: "## Version: 0.130.0a" },
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
  { gate: "selfverify", file: "Valuate.lua",
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
];
