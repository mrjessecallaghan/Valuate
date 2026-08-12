# Valuate

Stat-weight gear scorer for **World of Warcraft: Ascension** (WotLK 3.3.5a, classless).

Score every item against your own stat weights, see what's best in each slot, and — if you
want it — let Valuate handle the tedium: picking quest rewards, rolling on loot, keeping
bag space clear, and selling junk.

> **This is a fork.** Branch `claude-fork`, currently **v0.78.0a**, substantially diverged
> from upstream v0.8.1a. Most of the newer automation is **untested in-game** unless noted —
> see *Status* below. Every automation feature is **opt-in and off by default**.

## Installation

1. Copy the `Valuate` folder into `World of Warcraft/Interface/AddOns/`
2. `/reload`, or restart the client
3. Enable it at the character-select screen

Optional integrations: `Valuate-AdiBags` (tags best-in-slot items in your bags) and
`Valuate-PassLoot` (Valuate-aware loot rules).

## Core features

- **Guided scale wizard** — the fastest way in, and the one to start with. `/valuate wizard`
  (or **Make me a scale** at the top of the scale list) reads the gear you're already
  wearing, works out which of 31 hand-tuned builds you most resemble, and creates an
  optimized scale from it — named after its own top five stats, like
  `Auto - Str/Crit/Hit/AP/Haste`. Three screens, one click each. It shows you exactly what
  it would make *before* making anything, tells you how confident it is (and says so plainly
  when your gear is mixed), never overwrites a scale you already have, and finishes with the
  new scale selected and your gear rescanned. Generated scales share one **teal** colour, so
  you can always tell them from the ones you built yourself. Because Ascension is classless,
  it never asks "what class are you" — it works that out from what you wear.
- **Custom stat-weight scales** — unlimited, per character, with per-stat "ban" flags for
  stats you never want.
- **Tooltip scores** — live item score, comparison against what you're wearing, and a
  "★ Best for" marker naming the scales an item wins for.
- **Best Equipment panel** — best-in-slot per scale, upgrade deltas, an equipped-vs-best
  summary, and one-click **Equip All**. Slots you're wearing *nothing* in are called out
  as **New** and counted, but only when you actually own something to fill them — an empty
  Off Hand is correct if you run a two-hander.
- **Weapon sets** — a classless character can validly run several setups, so Valuate tracks
  **Two-Hander**, **1H + Shield**, **1H + Off-Hand** and **Dual Wield** *independently*,
  each with its own score. Enable the ones you use per scale and pick which is active;
  gear belonging to any enabled set is never treated as vendor fodder.
- **Upgrade arrows** — a green arrow on any item icon that beats what you're wearing, in your
  bags, at vendors and on the loot window, plus a **still blue** one on gear you cannot use
  yet but will. Only the actionable marker moves. Follows your *current spec*, so an arrow always
  means the same thing. Never on the character or wardrobe panels.
- **Bank-aware best-in-slot** — gear in your bank counts, snapshotted when you visit one.
  Banked items are marked, because Equip All can't reach them.
- **Character-sheet score** with a per-slot breakdown tooltip.
- **Import/export** scales as text tags (carries weapon-set config).
- **Shared across your characters** — scales and settings are per character, so a **scale
  library** and a **settings snapshot** let you set up once and load anywhere.
- **Ascension-aware** — PvE/PvP Power, scaled stats, and tooltip wording differences.

## Automation (all opt-in, all off by default)

| Feature | What it does | Commands |
|---|---|---|
| **Quest rewards** | Pre-selects the reward that's the biggest *upgrade*, not just the highest score. Optional full auto turn-in and auto-accept. | `/valuate quest`, `turnin`, `accept` |
| **Loot rolls** | Need on an upgrade for any of your scales, Greed otherwise. Also **unlearned recipes** for professions you have — including ones above your current skill, since you'll train into them — and **crafting materials** your professions use. | `/valuate roll`, `why <item>` |
| **Upgrade prompt** | When an equippable upgrade lands in your bags, offers one-click Equip Best Set. | `/valuate notify`, `notifycheck` |
| **Cleanup verdict on tooltips** | While auto-sell or auto-delete is on, item tooltips say whether Valuate would remove the item, or what is protecting it. No setting - it appears only when cleanup is armed. | (automatic) |
| **Junk auto-delete** | Keeps N bag slots free by removing the least valuable junk. **Irreversible.** | `/valuate autodelete`, `deletepreview`, `deletenow`, `keepfree <n>` |
| **Merchant** | Sells junk and repairs on arrival. Safer than deleting — gold, plus Buyback. | `/valuate sell`, `sellnow`, `repair` |
| **Wardrobe collecting** | Collects appearances you don't have yet from items in your bags. **May bind the items** — that is not verifiable from an addon, so look before you enable it. | `/valuate wardrobe`, `wardrobenow`, `autowardrobe` |
| **Surplus gear as junk** *(AdiBags)* | Routes gear that is neither best-in-slot nor a future upgrade into the Junk section. **Off by default** — junk feeds auto-delete. Re-evaluated live, so an item that later becomes your best un-marks itself. | `/valuate junkmarks` |

**Safety.** Deleting and selling never touch best-in-slot items, weapon-set members, future
upgrades, quest items, or anything in a WoW equipment set — and both re-verify a slot still
holds the vetted item immediately before acting. Junk is whatever **AdiBags' Junk filter**
says it is (honouring your include/exclude lists), so you stay in control of the definition.
Use **`/valuate deletepreview`** to see exactly what would go before enabling deletion.

Every automated path has a diagnostic that explains why it did *nothing* — that's what the
`*check`/`preview` commands are for.

## Useful commands

```
/valuate                  open the UI
/valuate wizard           build an optimized scale from the gear you're wearing
/valuate wardrobe         list bag appearances you have not collected yet
/valuate scan             rescan bags and equipped gear
/valuate check            is it actually working? start here
/valuate report           what's armed, when each automation last ran, and what it concluded
/valuate why <item>       explain this item: roll decision, upgrade arrow, junk status
/valuate library          scales shared across all your characters
/valuate settings save    copy this character's settings to your others (then `load`)
/valuate selftest         self-check: options, APIs, data structures, integrations
/valuate profile          time the scan, scoring, and the per-bag-icon work
/valuate weights          which of your stat weights are actually doing anything
/valuate future           gear waiting on a level, grouped by the level it needs
/valuate version          version info
```

`Escape` closes any Valuate window.

**When something seems not to happen**, `/valuate report` is the fastest answer — it shows
what's switched on and when each automation last ran, *including* "ran and correctly did
nothing", which is a different answer from "never ran".

## Status

Developed without the game running. **30 subsystems execute real Lua** headlessly against a
mocked WoW API and are genuinely behaviour-tested. They fall into three groups:

- **Things that can destroy or spend something** — the deletion protections, surplus-gear
  marking, the auto-roll decision, the quest reward choice, the PassLoot Upgrade rule, the TSM upgrade columns.
- **Panels driven the way a user drives them** — the scale list, Settings, the main
  window's tabs, the confirm dialog, the minimap button, the icon picker, both search
  boxes, the character-sheet score.
- **Pure logic whose wrong answer still looks plausible** — the animation engine, input and
  colour handling, scale-tag parsing, the spec templates, tooltip comparison text, the slot
  comparison states, stat shares, future-upgrade grouping and its tooltip line, the verify
  walkthrough, the upgrade-arrow driver.

**Everything else is statically verified only**: it loads, it resolves, its wiring is
consistent.

So assume anything you haven't personally exercised is unverified, and be deliberate about
the destructive features (deletion is permanent — WoW has no undo). `/valuate verify` lists
the specific things worth checking by hand.

## Development

```bash
cd tools && npm install     # once: installs luaparse + fengari
node gates.js               # run every gate (about 1.5s)
node gates.js --list        # ...or just see what would run
node backup.js              # bundle the sibling addons that have no git remote
```

Then, in-game, for anything the gates structurally cannot see:

```
/valuate check              # is it loaded, configured and actually doing something?
/valuate verify             # behavioural checks a human has to look at
/valuate verify next        # hand me the next one, set up and ready
```

Every gate encodes a bug that actually shipped here — addon taint, duplicated junk logic,
overlapping settings controls, a module silently missing from the `.toc`, a moved local
becoming a nil global, an unstable sort producing different "best" items between scans,
bank data reaching a delete path, an option with no way to switch it on, a destructive
command missing from the in-game help.

30 of them **execute real Lua** under fengari against a mocked WoW API (listed under *Status*
above). Those are where every substantive bug has been found, because the static gates can
only see structure — they cannot see a correct-looking branch in the wrong order. The rest
check wiring: that a file loads, a symbol resolves, a list stays in step.

Neither kind can tell you the UI looks right. That is what **`/valuate verify`** is for
in-game. It holds **21 checks** — it was short once and has grown with the addon, so it now
says which of them a build gate already proves the *logic* for. Those are "does it look
right", a smaller ask; the rest are the only evidence those behaviours will ever have, and
**`/valuate verify next` hands you those first** so a half-finished sitting covers the half
nothing else does.
**`/valuate verify next`** walks you through it one at a time, arming each check that can
arm itself. Ticks record the version they were made at, so a check comes round again by
itself once the behaviour underneath it changes.

See **`CLAUDE.md`** for the constraints when editing (taint rules, external contracts,
conventions) and **`ARCHITECTURE.md`** for the data model and load order.

## Credits

Built on the original Valuate for WoW Ascension. This fork's changes are documented in
`CHANGELOG.md`.

## License

[To be determined]
