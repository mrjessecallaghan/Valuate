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
const NEARMISS = {
  start: "function Valuate:BuildNearMissLine",
  end: "\n-- How much this item would improve each scale",
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
    from: "## Version: 0.98.0a", to: "## Version: 0.130.0a" },
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
