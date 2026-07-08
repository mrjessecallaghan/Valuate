# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.9.1a] - 2026-07-08 — Improvement pass

Performance, consistency and quality-of-life pass across the fork.

### Performance
- **Tooltip border color is cached per item** instead of recomputed every frame.
  The `GameTooltip` OnUpdate hook was calling the border-color logic (~60×/sec)
  while any item tooltip was shown, and that logic parses the equipped item's
  tooltip — the addon's biggest CPU cost. Now computed once per hovered item.
- **Best Equipment / character-window refreshes are skipped while hidden.** The
  Best Equipment panel was rebuilt (3×17 rows of frames) on *every* scan even with
  the window closed; the character-window score (which parses ~17 tooltips) was
  recomputed on nearly every option change even with the character sheet closed.
  Both now no-op when not visible and refresh on show.
- **Best Equipment rebuild parses each equipped item once**, not once per
  (scale × slot) — e.g. 51 tooltip parses → 17 for three scales.

### Consistency & logic
- **Auto quest reward now skips rewards you can't use yet** (level / unlearned
  proficiency), matching the Best Equipment "equippable now" logic.
- **Equipped-item scores now use scaled stats** (`SetInventoryItem`) everywhere, so
  tooltip "vs equipped" numbers match the Best Equipment panel and character window.
- Option defaults consolidated into a single source of truth (no more drift between
  the two default lists).

### Quality of life
- New `/valuate scan` (manual best-equipment scan) and `/valuate quest` (toggle auto
  quest reward); `/valuate help` refreshed.
- **PassLoot_Valuate no longer spams chat**: ~14 debug `print()` calls on every loot
  evaluation are now gated behind PassLoot's debug toggle.

### Cleanup
- Removed the dead `Valuate:DisplayScoresOnTooltip` function (~115 lines, unused) and
  a dead `lastBagUpdateTime` variable.

### Known follow-up
- Full frame-reuse (pooling) for the Best Equipment panel is deferred pending in-game
  testing; the per-scan rebuild cost was already addressed above.

## [0.9.0a] - 2026-07-07 — Claude fork

This release begins the **Claude fork** of Valuate: an in-place polish pass that
keeps the addon name, saved scales, and the AdiBags/PassLoot integrations fully
working. The pristine pre-fork addon is preserved in the repo's `master` branch
and in an `_Valuate_Original_Archive_*` folder + zip outside the load path.

### Added
- **Best Equipment now respects what you can actually equip.** The best-in-slot
  scan previously picked the highest-scoring item regardless of whether the
  character could wear it. It now only chooses items that are *currently
  equippable* — required level met and no red requirement lines on the tooltip
  (which also catches unlearned weapon/armor proficiencies on Ascension's
  classless system). Items that would be an upgrade but aren't usable yet (e.g.
  above your level) are no longer treated as best-in-slot and are never
  auto-equipped or marked "Best for" on tooltips. Instead they're kept as a
  **future upgrade**: when a slot has no equippable best, the Best Equipment
  panel shows the future item dimmed with its required level, for reference only.
- **Auto Choose Best Quest Reward** (opt-in, off by default). When a quest offers
  a choice of rewards, Valuate scores each choosable reward with your active scale
  (the character-window scale, or the first active scale) using the item's *scaled*
  stats, honoring the scale's banned stats, and pre-selects the highest-scoring one.
  It only highlights the reward — you still click "Complete Quest" yourself — and it
  leaves non-gear rewards (bags, consumables) for you to decide. Toggle it in
  Settings → "Auto Choose Best Quest Reward".

### Fixed
- **Shopping-tooltip border coloring never ran.** In `UpdateShoppingTooltip`,
  `shoppingItemLink` was scoped to an inner `if` block but read again afterward
  for border coloring, so it was always `nil` there and equipped-item comparison
  tooltips never got their green/red border. Hoisted to function scope.
- **Auto-scan timer cancellation was inert.** Scans were scheduled with
  `C_Timer.After` (which returns no handle) and cancelled with `C_Timer.Cancel`
  (not present on stock 3.3.5a `C_Timer`), so pending scans could never actually
  be cancelled and overlapping scans could queue. Replaced with a `ValuateAfter`
  helper that returns a real cancelable handle via `C_Timer.NewTimer` when
  available, and gracefully degrades to `C_Timer.After` or a pure `OnUpdate`
  timer on clients that ship neither.
- **`BAG_UPDATE` "always" auto-scan mode was silently disabled.** The handler
  compared `GetTime()` against a cooldown value it had set one line earlier, so
  the guard was always true and the "always" scan path never fired. Removed the
  dead check; debouncing is still handled by `ScheduleScan` and the scan
  callback's own bag-quiet gate. The genuine item-in-transit guards are untouched.

### Changed
- Removed a redundant second `local options` declaration in `Valuate:Initialize()`.
- Bumped version to `0.9.0a` and marked the addon as the Claude fork in the `.toc`.

## [0.7.0] - 2026-01-06

### Added
- **Per-Character Profile System**: Settings and scales are now saved per-character instead of account-wide
  - Each character maintains their own independent set of stat weight scales
  - All settings (UI position, minimap button, decimal places, etc.) are now character-specific
  - Characters no longer share configurations - complete isolation per character
- Added accessor functions for clean per-character data access:
  - `Valuate:GetCharacterKey()` - Returns unique character identifier
  - `Valuate:GetOptions()` - Returns character-specific options
  - `Valuate:GetScales()` - Returns character-specific scales
- Automatic migration system for transitioning from account-wide to per-character storage

### Changed
- Migrated from `SavedVariables` to `SavedVariablesPerCharacter` for data storage
- Updated all 214+ references throughout codebase to use new accessor functions
- Settings now persist per-character across logins and reloads

### Breaking Changes
- **IMPORTANT**: Existing configurations will not automatically transfer to all characters
  - Upon updating to 0.7.0, each character starts with a fresh configuration
  - Use the import/export feature to share scales between your characters if desired
  - Old account-wide saved variables file can be manually deleted after upgrade

### Migration Notes
- To clean up old data, delete: `WTF-Account\[account]\SavedVariables\Valuate.lua` (account-wide file)
- New per-character files are stored at: `WTF-Account\[account]\[realm]\[character]\SavedVariables\Valuate.lua`

## [0.6.2] - 2025-12-XX

### Removed
- Removed vestigial cache system (was never actually used - tooltip path bypassed it)
- Removed `/valuate cache` and `/valuate clearcache` commands
- Removed cache size setting from UI

### Notes
- Cache was architecturally unused: the main tooltip path (GetStatsFromDisplayedTooltip) 
  never touched the cache. Only GetStatsForItemLink used it, which was only called 
  from the /valuate test command. Removed to clean up dead code.

## [0.2.0]

### Added
- Stat parsing system with regex patterns
- Tooltip integration for displaying item scores
- Scale system for stat weights
- Configuration UI

### Changed
- Improved slash command help menu

## [0.1.0] - [Initial Release]

### Added
- Initial addon structure
- Basic loading and initialization
- Slash command handler (/valuate, /val)
- Version info command
- Documentation structure (README, CHANGELOG, DEVELOPER, ASCENSION_DEV)

