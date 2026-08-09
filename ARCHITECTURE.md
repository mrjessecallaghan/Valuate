# Valuate Architecture

The data model and control flow, so you don't have to reverse-engineer them.
See `CLAUDE.md` for the rules and constraints when editing.

---

## Load order (`Valuate.toc`)

```
libs/…              LibStub, CallbackHandler, AceDB
Valuate.lua         core (defines the Valuate table)
StatDefinitions.lua
ImportExport.lua

ui/Shared.lua       design tokens + shared mutable state   ─┐
ui/Data.lua         icon list, class/spec templates         │
ui/Animations.lua   tween engine                            │ each may use
ui/Widgets.lua      buttons, validation, tooltip helper     │ anything ABOVE
ui/Dialog.lua       confirm dialog (needs Widgets, Anim)    │ it, never below
ui/Pickers.lua      icon + template pickers                 │
ui/ScaleList.lua    left panel                              │
ui/ScaleEditor.lua  stat grid, import/export dialogs        │
ui/BestEquipment.lua                                        │
ui/Settings.lua                                             │
ui/InfoPanels.lua   Instructions / About / Changelog       ─┘

ValuateUI.lua       window, tabs, character display, ShowUI/Refresh* API
MinimapButton.lua
```

**The `ui/` order is a dependency chain, not alphabetical.** Each module re-localises
what it needs from the shared namespace (`local _, ns = ...`), so anything it uses must
already be published by a file listed above it. `Dialog.lua` needing
`ns.CreateStyledButton` from `Widgets.lua` is why Widgets precedes it.

Two cross-file mechanisms:
- **`ns` (the addon private table)** carries UI-internal things between `ui/` modules
  and `ValuateUI.lua`.
- **The `Valuate` table** carries the public API. Core loads *first*, so it guards UI
  calls with `if Valuate.X then` — e.g. `Valuate.lua` shows the upgrade prompt through
  `Valuate:ShowConfirmDialog`, which `ui/Dialog.lua` only defines later.

A module missing from the `.toc` never loads and reports no error — run
`node tools/tocsync.js`.

---

## Saved variables

| Global | Scope | Contents |
|---|---|---|
| `ValuateScales` | per character | the user's scales |
| `ValuateOptions` | per character | every option; defaults in `DEFAULT_OPTIONS` |
| `ValuateBestEquipment` | per character | last scan's results |

Add new options to **`DEFAULT_OPTIONS`** (`Valuate.lua`) or they won't persist —
`ApplyOptionDefaults` backfills missing keys on load so updates don't wipe settings.

### A scale

```lua
ValuateScales["Enhancement"] = {
  DisplayName = "Enhancement",
  Color       = "FF8040",     -- hex, no |cff
  Icon        = "Interface\\Icons\\…",
  Visible     = true,          -- false = inactive (excluded from GetActiveScales)
  Values      = { Strength = 1.2, … },   -- stat weights; the actual scoring input
  Unusable    = { TwoHandDps = true },   -- "banned" stats: any item with one scores nil
  WeaponSets  = { TwoHand = true, … },   -- nil means ALL configs enabled
  ActiveWeaponSet = "auto",    -- "auto" | config key
}
```

### Best-equipment results

```lua
ValuateBestEquipment["Enhancement"] = {
  [1..18]  = { itemLink, score, itemName, itemTexture, itemQuality },  -- per inv slot
  locks    = { [slotId] = true },   -- user-locked; scans never overwrite these
  future   = { [slotId] = { …, reqLevel } },  -- can't equip YET but would be an upgrade
  weaponSets = { TwoHand = { mh = rec, oh = rec, total = n }, … },
  weaponKeep = { [itemId] = "twohander"|"onehander"|"shield"|"offhand" },
  activeWeaponSet = "TwoHand",
}
```

Key invariant: **`[slotId]` only ever holds an item equippable right now.** Anything
gated behind level/proficiency lives in `.future`. That's why the upgrade prompt can
trust a slot mismatch to mean a genuinely wearable upgrade.

**`/valuate selftest` asserts this**, because no static gate can — it needs your level and
the live item cache. Three features break together if it slips (the upgrade prompt, Equip
All, and the level-up announcement), and none of them errors when it does; you are simply
offered gear you cannot wear.

---

## Weapon sets

Four configs (`WEAPON_SET_DEFS`): `TwoHand`, `OneHandShield`, `OneHandOffhand`,
`DualWield` (short labels `2H`, `1H+Sh`, `1H+OH`, `DW` — used in equipment-set names).

Each is scored independently, so a 2H and a 1H no longer fight over the main-hand slot.
One is **active** and resolves into slots 16/17, which is what tooltips, AdiBags and
right-click-equip see. `activeWeaponSet` = the scale's `ActiveWeaponSet`, or when `"auto"`,
the set matching your equipped weapons, else the highest total.

`weaponKeep` is the union across **all enabled** configs — so switching your active set
never makes Valuate tell you to vendor the other setup's gear.

`Valuate:IsWeaponSetEnabled(scale, key)` treats a missing `WeaponSets` table as
all-enabled (backwards compatibility).

---

## Scoring pipeline

```
tooltip → ParseStatsFromTooltip → stats{} → CalculateItemScore(stats, scale) → number
```

- `ParseStatsFromTooltip` matches `ValuateStatPatterns` (`StatDefinitions.lua`) against
  each tooltip line. Lines are **normalised first** (`NormalizeStatText`): Ascension writes
  "Improves hit rating" where Blizzard writes "improves **your** hit rating", so both the
  line and the patterns are folded to one canonical form. Patterns are normalised once and
  cached; lines without a digit skip the ~100-pattern loop entirely.
- `Valuate:GetStatsForTooltipSetter(setter, …)` populates the private tooltip via any
  `Set*` method (`SetBagItem`, `SetLootRollItem`, `SetQuestItem`, …) and parses it.

### The shared upgrade API — use this, don't reinvent it

| Function | Purpose |
|---|---|
| `GetUpgradeBaseline(link, scale, name)` | score this item must beat; weapon-set-aware (the *weakest* position it could take) |
| `GetItemUpgradeInfo(link, stats, opts)` | per-scale `{score, baseline, delta}`; `opts.includeInactive` widens to all scales |
| `IsUpgradeForAnyScale(link, stats, opts)` | → `isUpgrade, bestDelta, scaleName` |
| `GetBestForInfo(link)` | which scales it's best for + weapon category |
| `GetFutureUpgradeScales(link)` | scales where it's a not-yet-usable upgrade |

Quest rewards, auto-roll and the delete/sell protections all consume these — one
definition of "upgrade" across the addon.

---

## Animation (`ui/Animations.lua`)

One shared ticker drives every tween in the addon. Not a style preference — a frame has
exactly **one** `OnUpdate` slot, so two features animating the same frame silently
overwrite each other, and the loser's cleanup never runs.

```
Anim.tween{duration, ease, delay, onUpdate, onDone}   -- raw
Anim.owned(frame, propKey, opts)                      -- re-triggering REPLACES
Anim.cancelProp(frame, propKey)                       -- stop, hand the property back
Anim.setHeight(frame, h, animate)                     -- the ONLY writer of a shared height
Anim.revealIn(frame, delay)  /  Anim.staggerFor(n)    -- cascades
Anim.popIn(frame, fromScale, duration)                -- standard entrance
```

- **Ownership is by named property**, not by frame. So a frame can have an alpha tween and
  a size tween at once, while a second alpha tween cleanly replaces the first.
- **Durations come from `ns.MOTION`** (`ui/Shared.lua`) — `instant`/`fast`/`base`/`slow`/
  `count`, plus `cascade`/`stagger`/`staggerMin`. Chosen by *intent*. Motion that varies
  without meaning reads as sloppy the way mismatched spacing does.
- **Cascade gaps are derived**, not picked: `Anim.staggerFor(count)` divides a total window
  by the item count. Five reveals had each grown their own hand-tuned gap.
- **Reduce Motion is handled inside the engine** — every tween jumps to its final state, so
  callers never branch on it. The one exception is a *notification* (the minimap pulse), where
  the honest instant form is "don't play it".
- Every easing returns **exactly 1 at t=1**. Several things depend on it, and it is pinned by
  `tools/animtest.js` rather than assumed.
- `Anim.owned` works on any **table**, not just frames — `ui/UpgradeArrows.lua` owns its tweens
  on its own records so it never writes a field onto a Blizzard button.

A raw `frame:SetScript("OnUpdate", …)` is a lint failure unless annotated (CLAUDE.md §9).
What legitimately remains is dedicated driver and throttle frames.

So is a **bare `Anim.tween` outside the engine**. An animation nothing can replace outlives
the data it started with — twice that left a stale value on screen, both times in code
written *after* `Anim.owned` existed to prevent it. Every animation in the addon is owned.

## Frame pooling

**WoW never frees a `CreateFrame` widget.** `SetParent(nil)` does not free it; nothing does.
A refresh function that rebuilds its rows therefore leaks, permanently, every time it runs.

| Panel | State |
|---|---|
| `ui/BestEquipment.lua` | pooled — structure built once, content and closures rebound |
| `ui/ScaleEditor.lua` (stat grid) | pooled — grid built once, `row.populate(scale)` per scale |
| `ui/ScaleEditor.lua` (library list) | pooled by index |
| `ui/ScaleList.lua` | pooled — `BuildScaleRow(i)` once, `row.populate(name, scale)` per update |

The stat grid is poolable because its layout comes from static category tables and a row
captures nothing about its scale: every handler reads `ns.EditingScaleName` when it fires.
That is the pattern — **read the current state at call time, don't capture it** — and it is
also what makes the editor survive an import replacing the scale table underneath it.

The scale list was left rebuilding for several releases *on purpose*, because it is the one
panel where getting this wrong is destructive: a row carries a delete button, so a captured
name means deleting the scale that used to sit in that position. It was pooled once
`tools/scalelisttest.js` could repopulate the pool with a different, shorter list and prove
the handlers follow. Two rules make it safe, and both are checked there:

- **No handler captures a scale.** Each reads `self.scaleName` / the row's, at call time.
  The colour and icon pickers are the exception and capture deliberately at *click* time,
  then check the row still shows that scale before writing to it.
- **`release()` clears `scaleName`.** A parked row keeps its handlers forever — nothing can
  detach them — so the identity is what gets cleared, which turns every one into a no-op.

Cost of having left it: about **ten frames per scale per update**, permanently, for anyone
who edited their scales during a session.

---

## Events → behaviour

| Event | Does |
|---|---|
| `PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE`, `LOOT_OPENED` | schedule a rescan (`ScheduleScan`, honours `autoScan`) |
| `EQUIPMENT_SWAP_PENDING/FINISHED` | set/clear the **in-transit guards** — never bypass |
| `LOOT_CLOSED`, `ITEM_PUSH` | `ScheduleJunkCleanup` + `ScheduleUpgradeNotifyCheck` (both debounced) |
| `MERCHANT_SHOW` | auto-repair, then auto-sell junk |
| `QUEST_DETAIL/GREETING/ACCEPT_CONFIRM`, `GOSSIP_SHOW` | auto-accept quests |
| `QUEST_COMPLETE/PROGRESS` | pick best reward / auto turn-in |
| `START_LOOT_ROLL`, `CONFIRM_LOOT_ROLL` | auto Need/Greed |
| `EQUIP_BIND_CONFIRM` | confirm **only** for Valuate-initiated equips (`MarkEquipIntent`) |
| `PLAYER_REGEN_ENABLED` | flush prompts deferred during combat |

`ITEM_PUSH` (not `BAG_UPDATE`) is the "an item entered my bags" trigger: `BAG_UPDATE` also
fires on removals and moves, which would re-nag the prompt constantly.

---

## Integration flow

```
ScanBestEquipment()
  → RefreshBestEquipmentDisplay()          (UI)
  → NotifyBestEquipmentChanged()           (listeners)
       → Valuate-AdiBags: mark dirty + AdiBags_FiltersChanged   (re-filter the bag)
       → core: CheckBagUpgradeNotify("scan")                    (hide/refresh prompt)
```

Register with `Valuate:RegisterBestEquipmentListener(fn)`. Without this, AdiBags keeps
showing the *previous* scan's categorisation.

---

## Automation and its diagnostics

Every automated path has a command that explains why it did nothing — add one for any new
automation (see `CLAUDE.md` §6).

| Feature | Option | Diagnostic |
|---|---|---|
| Junk auto-delete | `autoDeleteJunk` | `/valuate deletepreview`, `/valuate deletenow` |
| Upgrade prompt | `notifyBagUpgrade` | `/valuate notifycheck` |
| Auto-sell / repair | `autoSellJunk`, `autoRepair` | `/valuate sellnow` |
| Auto-roll | `autoRollLoot` | chat line per roll |
| Whole addon | — | `/valuate selftest` |

Junk classification is **only** `IsItemJunk()` (delegates to AdiBags' Junk module).
Deletion/selling additionally require `IsProtectedFromDelete()` to pass.

---

## Verification: what proves what

Three layers, and it matters which is which — a green run does not mean "this works".

**Static gates** — `check.js` (syntax + 10 lint rules), `globals.js` (scope analysis and the
`ns.*` contract), `options.js`, `api.js`, `tocsync.js`. These prove a file *loads* and its
wiring is consistent. They cannot see behaviour.

`api.js` also checks **across addons**: every `Valuate:X()` called by `Valuate-AdiBags`,
`Valuate-PassLoot` or `Valuate-TSM` must exist. Those integrations load separately, so a method
renamed here breaks them at loot time or on a bag repaint — not at load, where you would notice.

**Runtime gates** — `animtest.js`, `widgettest.js`, `importtest.js`, `datatest.js`,
`verifytest.js`, `deletetest.js`, `scalelisttest.js`, `bestequiptest.js`, `tooltiptest.js`, `arrowtest.js`, `sharetest.js`, `settingstest.js`, `tabtest.js`, `dialogtest.js`, `minimaptest.js`, `statsearchtest.js`, `charwindowtest.js`, `iconpickertest.js`, `surplustest.js`, `rolltest.js`, `questtest.js`. These 21 *execute real Lua* under fengari against a mocked WoW API
(`luaharness.js` — deliberately one mock, since two would drift into testing different
imaginary clients). Every substantive bug found in this codebase has come from these, because
the static gates can only read.

Four of them load whole `ui/` files. `verifytest.js` and `deletetest.js` instead **slice
functions out of `Valuate.lua`** by source match, because the core file needs most of the WoW
API to reach its end while those functions need none of it. Slicing runs the shipped source
rather than a copy; a failed slice exits non-zero and a truncated one will not compile as Lua,
so neither can pass quietly. Reach for it when core logic is worth executing but its file is
not loadable.

`deletetest.js` is the one to copy. It proves each of the six deletion protections **alone**,
with every other protection switched off — a test where several branches could account for the
same answer passes with five of six broken. Mutation-tested: inverting the quest-item `or`,
dropping `includeInactive`, or killing the equipment-set condition each fail exactly the checks
that name them.

Run everything with **`node tools/gates.js`** (~1.3s), or install the pre-commit hook once via
`tools/install-hooks.cmd`. Gates **discover themselves** — a file in `tools/` is a gate if its
header carries an `@gate` line — so there is no list to fall out of step.

**In-game** — `/valuate check` (is it loaded, configured, doing something?) and
`/valuate verify` (behaviours no gate can answer). The verify list is deliberately short: only
things that fail *silently*, and several arm themselves, because "find an upgrade while in
combat, then leave combat" is not a test anyone runs by hand.

New behaviour that a gate cannot see should gain a `/valuate verify` entry. `tocsync.js` checks
the ids are unique and the versions real, but only a person can notice one is missing.

### The recurring bug shape

Almost nothing here has been a typo. The bugs have been **code that was correct when written and
quietly stopped being correct when something underneath it moved**, or a principle this codebase
already states, applied everywhere except one place:

- error containment in three hot handlers, but not the fourth (the tooltip)
- `pairs()` sorted in six places, but not `GetActiveScales`
- `SetScript("OnUpdate", nil)` to cancel, after tweens moved to the shared driver
- frame pooling in `BestEquipment`, but not the stat grid
- reading state at call time in `CommitValue`, but not in the weapon-set handlers
- a locked-slot check when selling, but not when deleting

Auditing for *that shape* has been far more productive than looking for mistakes.
