# Valuate Architecture

The data model and control flow, so you don't have to reverse-engineer them.
See `CLAUDE.md` for the rules and constraints when editing.

---

## Load order (`Valuate.toc`)

```
libs/…            LibStub, CallbackHandler, AceDB
Valuate.lua       core (defines the Valuate table)
StatDefinitions.lua
ImportExport.lua
ValuateUI.lua     all UI (depends on core)
MinimapButton.lua
```

Later files may call into earlier ones, not vice-versa — core guards UI calls with
`if Valuate.X then`. This matters: `Valuate.lua` shows the upgrade prompt via
`Valuate:ShowConfirmDialog`, which `ValuateUI.lua` defines later, hence the guard.

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
