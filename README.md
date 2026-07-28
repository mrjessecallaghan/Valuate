# Valuate

Stat-weight gear scorer for **World of Warcraft: Ascension** (WotLK 3.3.5a, classless).

Score every item against your own stat weights, see what's best in each slot, and — if you
want it — let Valuate handle the tedium: picking quest rewards, rolling on loot, keeping
bag space clear, and selling junk.

> **This is a fork.** Branch `claude-fork`, currently **v0.11.0a**, substantially diverged
> from upstream v0.8.1a. Most of the newer automation is **untested in-game** unless noted —
> see *Status* below. Every automation feature is **opt-in and off by default**.

## Installation

1. Copy the `Valuate` folder into `World of Warcraft/Interface/AddOns/`
2. `/reload`, or restart the client
3. Enable it at the character-select screen

Optional integrations: `Valuate-AdiBags` (tags best-in-slot items in your bags) and
`Valuate-PassLoot` (Valuate-aware loot rules).

## Core features

- **Custom stat-weight scales** — unlimited, per character, with per-stat "ban" flags for
  stats you never want.
- **Tooltip scores** — live item score, comparison against what you're wearing, and a
  "★ Best for" marker naming the scales an item wins for.
- **Best Equipment panel** — best-in-slot per scale, upgrade deltas, an equipped-vs-best
  summary, and one-click **Equip All**.
- **Weapon sets** — a classless character can validly run several setups, so Valuate tracks
  **Two-Hander**, **1H + Shield**, **1H + Off-Hand** and **Dual Wield** *independently*,
  each with its own score. Enable the ones you use per scale and pick which is active;
  gear belonging to any enabled set is never treated as vendor fodder.
- **Character-sheet score** with a per-slot breakdown tooltip.
- **Import/export** scales as text tags (carries weapon-set config).
- **Ascension-aware** — PvE/PvP Power, scaled stats, and tooltip wording differences.

## Automation (all opt-in, all off by default)

| Feature | What it does | Commands |
|---|---|---|
| **Quest rewards** | Pre-selects the reward that's the biggest *upgrade*, not just the highest score. Optional full auto turn-in and auto-accept. | `/valuate quest`, `turnin`, `accept` |
| **Loot rolls** | Need on an upgrade for any of your scales, Greed otherwise. Never Needs a non-upgrade. | `/valuate roll` |
| **Upgrade prompt** | When an equippable upgrade lands in your bags, offers one-click Equip Best Set. | `/valuate notify`, `notifycheck` |
| **Junk auto-delete** | Keeps N bag slots free by removing the least valuable junk. **Irreversible.** | `/valuate autodelete`, `deletepreview`, `deletenow`, `keepfree <n>` |
| **Merchant** | Sells junk and repairs on arrival. Safer than deleting — gold, plus Buyback. | `/valuate sell`, `sellnow`, `repair` |

**Safety.** Deleting and selling never touch best-in-slot items, weapon-set members, future
upgrades, quest items, or anything in a WoW equipment set — and both re-verify a slot still
holds the vetted item immediately before acting. Junk is whatever **AdiBags' Junk filter**
says it is (honouring your include/exclude lists), so you stay in control of the definition.
Use **`/valuate deletepreview`** to see exactly what would go before enabling deletion.

Every automated path has a diagnostic that explains why it did *nothing* — that's what the
`*check`/`preview` commands are for.

## Useful commands

```
/valuate            open the UI
/valuate scan       rescan bags and equipped gear
/valuate selftest   self-check: options, APIs, data structures, AdiBags integration
/valuate version    version info
```

## Status

Developed without a local Lua runtime, so changes are **statically verified, not
behaviour-tested**. Assume anything you haven't personally exercised is unverified, and
be deliberate about the destructive features (deletion is permanent — WoW has no undo).

## Development

```bash
cd tools && npm install     # once: installs luaparse
node check.js               # syntax + 6 lint rules
node tocsync.js             # .toc / ui/ / CLAUDE.md in sync
node globals.js             # scope analysis + namespace contract
```

Those gates exist because each encodes a bug that actually shipped here — addon taint,
duplicated junk logic, overlapping settings controls, a module silently missing from the
`.toc`, a moved local becoming a nil global. See **`CLAUDE.md`** for the constraints when
editing (taint rules, external contracts, conventions) and **`ARCHITECTURE.md`** for the
data model and load order.

## Credits

Built on the original Valuate for WoW Ascension. This fork's changes are documented in
`CHANGELOG.md`.

## License

[To be determined]
