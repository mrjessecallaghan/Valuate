# Working on Valuate

Operating manual for AI agents (and humans) editing this addon. Everything here was
learned by breaking something — please read before editing.

Valuate is a stat-weight gear scorer for **WoW Ascension 3.3.5a** (Interface 30300), a
classless server. Branch: `claude-fork`.

---

## 1. Verification: what to run, and what it proves

```bash
cd tools && node check.js
```

Run this **before every commit**. It parses every Lua file with `luaparse` (Lua 5.1) and
enforces the lint rules in §4. A Lua *syntax* error means the addon silently fails to
load — this is the guard against shipping that.

In-game, after a `/reload`:

```
/valuate selftest
```

Checks options completeness, that core methods exist, data structures are well-formed,
and that tooltip parsing still returns stats.

**What neither proves: behaviour.** There is no Lua runtime on the dev machine, so nothing
here executes addon logic. Every behavioural claim must be verified in-game by the user.
Say so honestly rather than implying a change is tested.

---

## 2. Hard constraints

- **Never touch the in-transit scan guards** (`equipmentSwapPending`, `recentEquipmentChange`
  in `Valuate.lua`). They prevent calling `SetBagItem` while items are moving between bags
  and equipped slots, which can make items vanish. This is an item-loss hazard, not a
  style choice.
- **Deletion and selling are irreversible.** `AutoDeleteJunk` and `AutoSellJunk` must always
  honour the hard protections in `IsProtectedFromDelete` (best-in-slot, weapon-set members,
  future upgrades, quest items, equipment-set members), re-verify the slot still holds the
  vetted item immediately before acting, and never remove more than the setting asks for.
- **Never auto-answer a destructive confirmation.** WoW's typed-`DELETE` dialog exists to
  prevent exactly the accident we'd be automating. Skip the item and log it instead.

---

## 3. Taint: the rules that bit us twice

WoW blocks addons from participating in protected code paths. Violations surface as
*"Valuate has been blocked from an action only available to the Blizzard UI"* or
*"AddOn 'Valuate' tainted the call of the secure function 'X()'"*.

- **Never use `StaticPopup`.** Blizzard *recycles* the `StaticPopup1..4` frames, so showing
  our dialog on one poisons it; when Blizzard later reuses that frame for a secure dialog
  (e.g. `USE_BIND`, "this will bind to you"), clicking it taints the secure call and the
  action is blocked. This happens even though we never call that function.
  **Use `Valuate:ShowConfirmDialog{...}`** (our own frame) instead.
- **Never write Blizzard UI table fields** (`QuestInfoFrame.itemChoice = x`) or **call
  Blizzard UI functions** (`QuestInfoItem_OnClick(...)`). Draw our own highlight and let
  the user click.
- **Never automate protected paths**: using items (`ConfirmBindOnUse`), casting, targeting.
- **Safe to call**: `EquipItemByName`, `RollOnLoot`, `ConfirmLootRoll`, `GetQuestReward`,
  `AcceptQuest`, `CompleteQuest`, `UseContainerItem` *at a merchant, on a sellable item*,
  `PickupContainerItem` / `DeleteCursorItem`.

---

## 4. Lint rules (enforced by `tools/check.js`, hard fail)

Each rule exists because of a real bug. To bypass one deliberately, append
`-- valuate-lint-ignore: <rule>` to that line and explain why.

| Rule | Bans | Why |
|---|---|---|
| `no-staticpopup` | `StaticPopup_Show/Hide`, `StaticPopupDialogs[` | taint (§3) |
| `no-blizzard-ui-writes` | writes to Blizzard frame fields, `*_OnClick(` calls | taint (§3) |
| `no-protected-calls` | `ConfirmBindOnUse` | blocks item use |
| `no-duplicate-junk-logic` | `CheckItem(`/`IsJunk(` outside the shared helper | §5 |
| `settings-anchor-chain` | two controls anchored to the same frame | §6 |

---

## 5. External contracts (do not re-guess these)

- **AdiBags junk classification** is `AdiBags:GetModule("Junk", true):CheckItem(itemId)`.
  Do **not** use the `addon:IsJunk` hook — it's AceHook-wrapped with a
  `mod:IsJunk(_, itemId)` signature and returns `false` for everything when called from
  outside, which silently classified 0 of 48 items as junk.
  All junk checks must go through **`IsItemJunk()`** in `Valuate.lua` — one implementation,
  used by both deleting and selling. Duplicating it is how that bug survived two fixes.
- **AdiBags filter priority**: `Valuate-AdiBags` registers at **97**. AdiBags gives each item
  to the highest-priority filter that claims it, and `AdiBags_AscensionStatWeights` (96),
  `FilterOverride`/`AdiBags_Ascension` (95) and `ItemSets` (90) would otherwise take our
  items first. If Valuate items stop being categorised, check priority before logic.
- **The integration modules are their own git repos**: `Valuate-AdiBags/`,
  `Valuate-PassLoot/`. They are *not* part of this repo — commit there separately.

---

## 6. Conventions

- **Settings layout:** each control anchors to the **previous control**, never to a shared
  sibling — two controls on one anchor render on top of each other. `CheckColumnAnchors`
  warns at runtime if this is violated.
- **UI layout is written blind.** No screenshots here; ask the user to verify anything
  positional, and prefer relative anchors over computed offsets.
- **Whitespace differs per file**: `Valuate.lua` / `ValuateUI.lua` use **spaces**; the
  AdiBags module uses **tabs** and has trailing whitespace. Anchor `Edit` calls on
  non-whitespace tokens or the match will fail.
- **Automation must be observable.** Every automated path needs a diagnostic that explains
  why it did *nothing* — `/valuate deletepreview`, `/valuate notifycheck`. Silent early
  returns are how the upgrade prompt went missing for days.
- **Options** live in `DEFAULT_OPTIONS` (`Valuate.lua`); add the key there or it won't
  persist. Every automation option should default **off**.
- **Commits:** isolated, one concern each, via `git commit -F <file>` (PowerShell mangles
  inline quotes). Explain *why*, not just what.

---

## 7. Map

| File | Contents |
|---|---|
| `Valuate.lua` | Core: options, scanning, scoring, weapon sets, all automation, slash commands |
| `ValuateUI.lua` | All UI: window, tabs, scale editor, Best Equipment, Settings, animation engine, dialog |
| `StatDefinitions.lua` | Stat list, tooltip parse patterns |
| `ImportExport.lua` | Scale import/export strings |
| `MinimapButton.lua` | Minimap button + upgrade pulse |
| `tools/check.js` | Syntax + lint gate |

See `ARCHITECTURE.md` for the data model and event flow.
