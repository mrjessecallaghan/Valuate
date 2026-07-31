# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.15.2a] - 2026-07-31 — Surplus-gear junk marking hardened

### Safety
- **It now refuses to mark anything until it has trustworthy data.** The feature reasons
  "not in the best list, therefore surplus" — which is only true once the best list exists.
  Before the first scan, after a failed scan, or with no active scales, *nothing* is
  best-in-slot, so everything in your bags would have been marked at once. It now requires a
  completed scan, an active scale, and real best-in-slot entries before marking anything.
- **Gear in a saved equipment set is protected.** Building a set says you want that gear, and
  a PvP or fishing set generally is not best-in-slot.
- **Slots Valuate has no opinion about are left alone.** If there is no best-in-slot entry for
  an item's slot, its absence from the list means nothing.
- **New `/valuate junkmarks`** reports which guard is holding it back, so "nothing is being
  marked" is never ambiguous. It also points at `/valuate deletepreview`.

## [0.15.1a] - 2026-07-31 — Mark surplus gear as junk (optional)

### Added
- **AdiBags option: "Mark surplus gear as junk".** Equippable gear that is not best-in-slot
  and not a future upgrade gets routed into the Junk section, so surplus drops collect in one
  place instead of spreading through your bags.
- **It re-evaluates itself.** This is not a tag written once — if an item later becomes your
  best, it stops being marked on the next scan. No cleanup pass, no stale marks.

### Safety
- **Off by default, and capped at uncommon (green).** Valuate auto-delete uses the AdiBags
  junk filter as its deletable list, so anything marked here can be deleted automatically if
  you also run auto-delete. The option says so plainly.
- Never marks best-in-slot items, future upgrades, or profession tools. Anything it is unsure
  about (including items the client has not cached yet) is left alone.
- **Known limit, stated in the option:** Valuate only computes best-in-slot for *active*
  scales, so gear that is best for a spec whose scale you switched off is not protected.

## [0.15.0a] - 2026-07-31 — Upgrades get their own popup

### Added
- **A proper upgrade popup.** It was reusing the same dialog that asks *"delete these 12
  items?"* — so it could only ever be a block of text with two equal buttons, and it told you
  *"3 upgrade(s) are in your bags"* without saying which, or by how much.
- Now it's compact (300×84 instead of 400×130) and specific: the best upgrade's **icon** with
  its quality border, the **item name**, the **actual score gain**, and a headline in your
  spec's own colour. Hover the icon for the full item tooltip.
- Dismiss is a quiet corner **×** rather than a second full-width button — it's a
  notification, so declining shouldn't carry equal visual weight.
- Entrance animation (fade + a small spring overshoot) and a soft pulse on the icon glow.
  Both are skipped entirely if you have **Reduce Motion** on.

### Fixed
- The "nothing left to equip" path was hiding the *old* dialog, which would have left the new
  popup on screen offering to equip gear you were already wearing.

## [0.14.5a] - 2026-07-31 — "Always" auto-scan actually means always

### Changed
- **Equipping or unequipping anything re-scans much sooner** — about 1.2 seconds on "Always"
  instead of 3.5. Both directions were already covered; they were just slow. The settle
  window is shortened, not removed: an equip moves an item *between* a bag slot and an
  equipment slot, which is precisely what the in-transit guard protects against, so it keeps
  a real (if shorter) delay. Bulk equipment-set swaps still use the longest window, since
  that's when the most items are in flight at once.
- **Auto Scan set to "Always" now reacts to bag changes in about a second**, instead of
  several. Four separate delays were stacking up before a scan could run — the scheduled
  delay, a bag-quiet window, a minimum gap between scans, and the burst cap that stops a
  stream of bag updates deferring forever. All four used one conservative set of numbers, so
  "Always" behaved much like the other modes, and during sustained looting a scan could be
  six seconds behind your bags.
- Those numbers are now per-mode. "Always" is an explicit request to track your bags, so it
  gets tight ones; the other modes keep the cautious values, since they only fire on discrete
  events where latency doesn't matter.
- The in-transit guards are **unchanged** — they're what stop a scan reading a bag slot while
  an item is mid-move, and none of this relaxes them.

## [0.14.4a] - 2026-07-31 — Tab polish

### Added
- **The Scales list marks your current spec.** That scale drives your character-sheet score,
  the upgrade prompt's baseline, and which items get a green arrow — but the only way to
  find out which one it was involved a Settings dropdown named after the character window.
  Hovering any scale now explains what it does and how to change it.
- **Empty state for the Scales list**, instead of a blank panel, if you delete your last scale.
- **Bigger, glowing upgrade arrow** with a slow pulse, so it reads against bright item art.
  Respects Reduce Motion.

### Fixed
- **"Upgrades in bags" counted gear that was in your bank.** Banked upgrades are now reported
  separately, so the line stops claiming something untrue — and "no upgrades in bags" no
  longer appears when the upgrade is simply sitting in the bank.

### Changed
- **Settings columns rebalanced.** Column 1 had grown to 25 rows against 9 and 7, which is
  why options ran off the bottom. Bank, alert, quest and arrow options moved to a new
  **Alerts & Extras** section in column 3.

## [0.14.2a] - 2026-07-31 — Arrows follow your spec; character score stays on the gear tab

### Changed
- **Upgrade arrows now only appear for your current spec.** They previously flagged an
  upgrade for *any* active scale, which made them ambiguous — an arrow for a spec you
  weren't playing looked identical to one for the spec you were. Switching spec clears the
  cached answers, so an arrow can't linger from your previous one.

### Fixed
- **The character-sheet gear score no longer shows on the Pets, Reputation, Skills or
  Currency tabs.** It was parented to the whole character frame, so it stayed on screen over
  every tab that frame hosts. It now belongs to the equipment view itself, so it hides
  automatically — no tab list to keep in sync, and it stays correct for any other sub-panel
  this client adds later.

## [0.14.0a] - 2026-07-31 — Upgrade arrows

### Added
- **A green arrow pins to the top-right of any item icon that would be an upgrade for one
  of your active scales** — in your bags (AdiBags and the default bag frames), at vendors,
  and on the loot window. No more opening every tooltip to find out.
- Deliberately **not** shown on the character or wardrobe panels: an arrow on gear you're
  already wearing is noise, and the point is to flag what you could acquire.
- Toggle with **Upgrade Arrows** in Settings.

### Notes
- The answer is cached per item link and cleared on every scan, because equipping one thing
  changes whether everything else is an upgrade. Without the cache this would rebuild a
  tooltip and re-check every scale for each visible icon on every bag repaint.
- Non-gear is rejected before any tooltip is built, which is most of a bag's contents.

## [0.13.1a] - 2026-07-31 — Stat weight page polish, and edits that stick

### Fixed
- **Typed values were silently discarded unless you pressed Enter.** Clicking from one
  field to the next — the obvious way to fill in several stat weights — threw the edit
  away. The number stayed on screen, so it looked applied, but it never reached the scale
  and vanished on the next refresh. Found by auditing every edit box in the UI; it affected
  **stat weights** and **six Settings fields**: Keep Free Slots, Max Value, Min Value, Run
  Every, Decimal Places and Value Source. Enter and click-away now share one commit path.
- **The scale name box kept showing text you typed but never applied.** Renames still commit
  on Enter only — clicking away must not rename a scale by accident — but the field now
  restores the real name instead of displaying one the scale doesn't have.
- **Decimal Places** only refreshed tooltips on Enter; it now does so however you commit.

### Added
- **Stat rows with a weight set stand out.** With ~60 stats across five columns every row
  looked identical, so the handful you'd actually configured were impossible to spot.
- **A summary in the scale editor header** — how many stats are weighted, how many are
  banned, and what your current gear scores for that scale. A scale with no weights now says
  so outright ("this scale won't score any item") rather than leaving you to infer it from
  everything scoring zero.

## [0.13.0a] - 2026-07-30 — Automation that actually runs, and proof that it does

### Fixed
- **Auto-delete, scanning and upgrade alerts could all go long stretches without running.**
  Each was debounced by cancelling and re-arming its timer on every event — but `ITEM_PUSH`
  fires once per looted item and `BAG_UPDATE` fires constantly while looting, so every event
  pushed the deadline back another second and the work never happened *during the exact
  activity that requested it*. All three now stop deferring after a few seconds and let the
  pending run fire.
- **Work that hit a safety guard was thrown away instead of retried.** When a scan fired
  while bags were still settling, it was abandoned — the likely cause of "the scan didn't
  pick up the item in my bag". The upgrade check did the same on the in-transit guard, which
  is much of why the popup only appeared sometimes. Both now retry (bounded).

### Added
- **Junk cleanup also runs on a timer** — every 60s by default, independent of loot events.
  Set it in Settings (**Run Every (s)**) or with `/valuate junkinterval <secs>`; `0` restores
  event-only behaviour.
- **`/valuate report` now shows when each automation last ran and what it concluded** — gear
  scan, junk cleanup, junk selling, upgrade alert, bank snapshot. It records "ran and
  correctly did nothing" too, because a cleanup that skipped while bags were above target is
  a completely different diagnosis from one that never fired, and both used to look the same.
- **Skip Trivial Quests** — with auto-accept on, don't take quests 8+ levels below you. Also,
  auto-accept now picks the first *non-trivial* quest an NPC offers instead of always the
  first in the list, so a grey quest no longer blocks the real one behind it.
- **`/valuate profile`** — times the gear scan, per-item scoring, and tooltip parsing. There
  was no measurement before, so any claim about the addon being heavy or light was guesswork.

## [0.12.1a] - 2026-07-29 — Upgrade alert options

### Added
- **Upgrade alerts can be a chat message instead of a popup**, with an optional sound cue —
  for when you don't want a dialog taking focus mid-fight. One Settings control cycles
  **Popup → Popup + Sound → Chat → Chat + Sound**.
- **Alert For Other Specs** — the upgrade alert normally only considers your active scale.
  With this on, it also lists your other active scales that have upgrades waiting. On a
  classless server a drop often suits a spec you aren't currently running, and would
  otherwise get vendored without you noticing.
- **`/valuate equip`** — equips the best set for the active scale. Needed because the chat
  alert has no button to click.

### Fixed
- **The upgrade prompt could offer to equip gear sitting in your bank.** Introduced in
  0.12.0a: the upgrade count didn't check reachability, so once banked gear became a
  best-in-slot candidate the prompt could appear with an "Equip Best Set" button that then
  skipped the item. Banked upgrades are now counted separately and reported as such, and
  `/valuate notifycheck` no longer claims you're wearing the best when better gear is banked.

## [0.12.0a] - 2026-07-29 — Bank-aware best-in-slot, deterministic results

### Added
- **Your bank now counts towards best-in-slot.** Valuate snapshots your bank whenever you
  visit one, and that gear is considered when working out the best item for each slot.
  Banked items are marked with a bag icon in the Best Equipment panel, and **Equip All
  skips them and tells you how many it skipped** — it can't reach the bank, and an Equip
  All that quietly equips less than the panel shows would be worse than useless.
  Toggle with **Include Bank Items** in Settings.
- **`/valuate bank`** — shows the snapshot and, when it contributes nothing, says which of
  the three reasons applies: never visited, the option is off, or no equippable gear found.

### Fixed
- **Results no longer change between scans.** `table.sort` isn't stable, so six comparators
  that had no tiebreaker were leaving equal-ranked items in an order that ultimately came
  from `pairs()` — which is undefined. In practice that meant:
  - equal-scoring items could **swap places between scans**, flipping "Best for" tooltips,
    the generated equipment set, and which item AdiBags tagged;
  - the **reported "best" scale** for an upgrade could differ run to run;
  - **`/valuate deletepreview` could rank a different item than `deletenow` deleted**, since
    equal vendor values are very common among junk. Deletion is irreversible, so preview
    now predicts it exactly.

### Safety
- Auto-delete, auto-sell and the "keep N slots free" count remain **strictly bags-only** and
  can never see the bank. This is now enforced by the build: a new `no-bank-in-destructive-path`
  rule fails the build if bank data is ever referenced from those functions.
- A new `sort-needs-tiebreaker` rule fails the build on any comparator without a tiebreaker,
  so the non-determinism class above can't come back.
- `/valuate selftest` now checks the bank snapshot is well-formed and that every item the
  panel badges as banked actually exists in the snapshot.

## [0.11.1a] - 2026-07-29 — Weapon-set correctness, `/valuate report`

### Added
- **`/valuate report`** — one digest of where your gear stands: per scale, your equipped
  total vs the best achievable, how many upgrades are waiting in bags and what they're
  worth; the current spec's weapon sets with totals and which is active; free bag slots
  against the auto-delete target; and **which automation is actually switched on**. That
  last line is deliberate — most "nothing happened" confusion comes from a feature being
  off, or acting only under conditions you can't see.
- **`/valuate selftest` now verifies every UI module actually loaded**, naming any that
  failed. The UI is split across twelve files; previously a module that errored while
  loading only showed up later as a broken tab.

### Fixed
- **The active weapon set could change by itself.** Auto-selection iterated an unordered
  table, and ties are common — before you own a shield or off-hand, `1H+Shield`,
  `1H+Off-Hand` and `Dual Wield` all form from the same lone one-hander and score
  identically. The winner was arbitrary and could differ between scans, so your Main/Off
  Hand display and the upgrade prompt's baseline could flip with no gear change. Selection
  is now deterministic, and ties break toward the set with more positions actually filled.
- **Future upgrades ignored weapons for other setups.** A not-yet-usable weapon was judged
  against whatever occupied the main-hand slot — the *active* set's weapon. While running a
  two-hander, a one-hander that would greatly improve your `1H+Shield` set was never
  recorded as a future upgrade, never appeared in "Soon", and wasn't kept by AdiBags. It's
  now measured against the weakest position it could take across your enabled sets.
- **Three latent nil-reference bugs in the split UI**, found by new scope-analysis
  tooling: a missing constant that would have errored while the Settings panel built, two
  missing animation functions behind the Equip All flash, and a long-dead `nil` field.
- Tooltips no longer appear while dragging the window (that check had silently never
  worked — it referenced a variable declared below it).

### Changed
- README and the in-game About panel rewritten; both still described the v0.7.0 feature
  set. The UI split is complete: `ValuateUI.lua` went 8,967 → 618 lines across twelve
  modules.
- Developer tooling now also does **scope analysis** (catching references that silently
  resolve to `nil`), verifies the namespace contract, and checks the docs for drift.

## [0.11.0a] - 2026-07-19 — Merchant automation, upgrade prompts, and a rebuilt UI

**Still untested in-game at release** except where noted — no Lua runtime is available on
the dev machine, so changes are review- and lint-verified only.

### Added
- **Bag-upgrade prompt.** When an equippable upgrade for your current spec is sitting in
  your bags, Valuate offers a one-click "Equip Best Set". Triggers on **any** item
  entering your bags — loot, quest rewards, mail, trade, crafting, vendor purchases — and
  defers politely until you're out of combat. Two modes: re-prompt every loot, or only
  when the available upgrades actually change. `/valuate notify`, `/valuate notifycheck`.
- **Auto-sell junk and auto-repair at merchants.** Selling uses the *same* junk rules and
  the same hard protections as auto-delete, and is strictly safer — you get the gold, and
  the vendor's Buyback tab can undo a mistake. Optional guild-funds-first repair.
  `/valuate sell`, `/valuate sellnow`, `/valuate repair`.
- **`/valuate deletenow`** — run junk cleanup on demand instead of waiting for a loot
  event. Respects your Keep Free Slots target; it is not a "delete everything" button.
- **Animation system.** One shared ticker driving window open/close, tab crossfades, a
  staggered Best Equipment reveal with score count-ups, hover transitions, an Equip All
  flash, and a minimap pulse when an upgrade lands. **Reduce Motion** collapses all of it
  to instant.
- **Selectable active spec** per Best Equipment column, with a visual indicator.
- **Import/export now carries weapon-set configuration** (scale tag v2). Older tags still
  import; a v2 tag is refused by older Valuate with a clear message rather than silently
  importing junk.

### Fixed
- **Bind-on-use items were being blocked** (e.g. Ascension's vanity sync), reporting
  *"Valuate tainted the call of the secure function ConfirmBindOnUse()"*. Valuate was
  never the caller: showing our own prompts through Blizzard's shared StaticPopup frames
  poisoned one, and the taint surfaced when the game later reused that frame for a secure
  dialog. Valuate now uses its own dialog frame and contains **no** StaticPopup usage at
  all. A second, latent case in the quest-reward code (which would have blocked "Complete
  Quest") was fixed the same way.
- **Junk was not being detected at all** — the delete preview reported 0 junk from a full
  bag. Valuate was calling AdiBags' hooked `IsJunk`, which returns false when called from
  outside; it now asks the Junk module directly and honours your include/exclude lists.
  Grey vendor trash and items you mark as junk are both recognised.
- **A better weapon set could become invisible.** "Auto" picked whichever set matched the
  weapons you were *wearing*, so equipping a 1H hid a stronger 2H in your bags — from the
  Best Equipment panel *and* from the upgrade prompt. "Auto" now means highest-scoring;
  what you're wearing is only a tie-break. Equip All no longer pins the active set either.
- **The upgrade prompt often never appeared.** A combat check wrapped the whole path, so
  looting mid-fight skipped it entirely *and* skipped the deferral, losing the prompt.
- **Auto-delete ignored non-loot sources** (quest rewards, mail, crafting) and refused to
  run in combat, which is exactly when bags fill during AoE farming.
- **Overlapping text in Settings**, plus a build-time guard so two controls can never
  again be anchored to the same position unnoticed.
- **Tooltips appeared while dragging** the window — a check that had silently never worked.
- Auto-sell can no longer *use* an item instead of selling it (unsellable/locked items are
  skipped), and both selling and deleting now re-verify a slot still holds the vetted item
  immediately before acting.

### Changed
- **The UI was split into 11 focused modules** under `ui/` — `ValuateUI.lua` went from
  8,967 lines to ~1,376. No behaviour change intended; it makes the code navigable and
  edits precise.
- **Developer tooling**: a syntax + lint gate (`tools/check.js`) enforcing six rules, each
  derived from a bug that actually shipped here; a `.toc` sync check; and `/valuate
  selftest`, which now also sanity-checks the AdiBags integration rather than merely
  checking that nothing errored. `CLAUDE.md` and `ARCHITECTURE.md` document the
  constraints and data model.
- Performance: the per-frame tooltip hook and the stat parser both short-circuit far
  earlier on the common path.

## [0.10.0a] - 2026-07-19 — Weapon sets, loot & bag automation

Large release. Valuate now tracks gear as **weapon configurations** rather than one
winner per slot, and automates most of the gear lifecycle: acquiring it (loot rolls,
quest rewards), keeping it (AdiBags tags, delete protections), wearing it (Equip All,
equipment sets) and making room for it (junk auto-delete).

**Everything below is untested in-game at release** — no Lua runtime is available on the
dev machine, so all changes are review-verified only. Verify before relying on them, and
be especially careful with the destructive junk auto-delete.

### Added
- **Weapon Sets.** Each scale can track four weapon configurations independently —
  **Two-Hander**, **1H + Shield**, **1H + Off-Hand** and **Dual Wield** — instead of a
  single best item per slot. Previously a 2H and a 1H fought over the main-hand slot and
  only the higher score survived, so the other setup was invisible. Each config is
  toggleable per scale in the scale editor, and one is the **active set** that drives
  main/off-hand best-in-slot for tooltips, AdiBags and right-click-equip. Gear belonging
  to any *enabled* config is still kept, so switching your active set never makes Valuate
  tell you to vendor the other setup's pieces.
- **Best Equipment weapon-sets panel.** Each scale column lists its enabled configs with
  a combined score; click one to make it active. Columns also show **Equipped X / Best Y**
  and **Upgrades in bags: +Z**.
- **Equip All** button — equips a scale's entire best-in-slot set in one click (skipping
  locked slots and anything already worn, refusing in combat), pins that weapon set as
  active, and flashes the row so it's clear which configuration you're now wearing.
- **Save Set** button — snapshots the gear you're currently wearing into a WoW equipment
  set named after the scale and its active weapon set, e.g. `Retribution (2H)`.
- **Auto Roll On Loot** (Settings, off by default). On a group loot roll, rolls **Need**
  when the item is an upgrade for any of your scales — including inactive ones, and
  including gear you can't equip yet but would beat your best — and **Greed** otherwise.
  It never rolls Need on something that isn't an upgrade. `/valuate roll`.
- **Auto Accept Quests** (Settings, off by default). Accepts quests from NPCs, including
  escort/shared confirmations and quests listed in gossip or multi-quest greeting windows.
  `/valuate accept`.
- **Junk auto-delete** (Settings, off by default — **deletion is permanent**). After
  looting, deletes the least valuable junk until a configurable number of bag slots is
  free. Candidates come from AdiBags' own Junk classification (honouring its
  include/exclude lists), or grey quality without AdiBags. Tunable quality ceiling, value
  floor/ceiling, and free-slot target. **Hard protections that cannot be disabled:** never
  deletes best-in-slot, weapon-set members, future upgrades, anything that's an upgrade for
  any scale, quest items, or items in a WoW equipment set. Every deletion is logged.
  `/valuate autodelete`, `/valuate deletepreview`, `/valuate keepfree <n>`.
- **Pluggable value source** for junk ranking — defaults to vendor sell price, but can use
  a TradeSkillMaster price source (`DBMarket`, `DBMinBuyout`, or a custom price string) and
  always falls back to vendor when unavailable. The preview reports when it falls back, so
  a missing source can't silently change what gets deleted.
- **Future upgrades are kept by AdiBags.** Items you can't equip yet (e.g. a higher level
  is required) that would be an upgrade once usable now go to their own `Soon:`/`Future
  Items` section, with an option to merge them into the main Best Items section.
- **Bind confirmation handling.** Equipping a bind-on-equip item raised a confirmation
  nothing answered, so Equip All silently skipped BoE upgrades. Valuate now confirms binds
  for equips **it** initiated; a prompt you raise by manually equipping something still
  behaves exactly as before. Optional `Auto Confirm Bind On Loot` for your own looting.

### Changed
- **Auto quest reward now picks the biggest upgrade, not the highest score.** Each reward
  is measured against the weakest position it could take across your enabled weapon sets,
  so a marginal 2H upgrade loses to a large 1H-set upgrade, and an empty slot counts as a
  full upgrade. Falls back to the highest raw score when nothing is an upgrade.
- **"Best for" tooltips are qualified by weapon category** — "★ Best two-hander for:
  Retribution" rather than a bare "Best for", so you can tell *which* setup an item wins.
- **UI overhaul.** Cohesive dark slate/azure palette, Best Equipment columns framed as
  cards with a scale-coloured header accent, a clear active-tab accent, and micro-animations
  (eased hover fades, tab accent sweep, set-activation flash).
- **Saving an equipment set is no longer coupled to Equip All** — it's a separate **Save
  Set** button, so equipping never overwrites a saved set for you.
- Internal: one shared upgrade API (`GetItemUpgradeInfo` / `IsUpgradeForAnyScale` /
  `GetUpgradeBaseline`) now backs quest rewards, auto-roll and delete protection, replacing
  logic that was duplicated across four call sites.

### Fixed
- **Stats written without the possessive were silently dropped.** Ascension writes
  "Equip: Improves hit rating by 2" where the patterns expected "...improves **your** hit
  rating"; the line never matched, so the stat was ignored in all scoring. This affected
  every rating with "your" in its pattern, not just hit. Tooltip lines and patterns are now
  folded to one canonical form (and Improves/Increases treated as interchangeable), fixing
  it in both directions. Integer captures also widened to accept decimals.
- **The Dual Wield set only ever found a main hand.** The off-hand pick was gated on a
  dual-wield check that has no dependable API on 3.3.5 and fell back to class defaults —
  meaningless on a classless server. Enabling the Dual Wield set now implies you dual-wield,
  and knowing the Dual Wield passive counts as proof.
- **One-hand weapons leaked past a 1H ban.** Weapon-type bans had equip-location backstops
  for 2H/off-hand/ranged but not one-hand, so 1H items whose DPS parsed differently were
  still marked best-in-slot.
- **AdiBags kept showing stale results.** Valuate now notifies integration modules when
  best-equipment data changes, so the bag re-filters after a scan instead of holding the
  previous scan's categorisation.
- **AdiBags filter was being starved.** `ValuateBestItems` registered at priority 90, below
  `AdiBags_AscensionStatWeights` (96) and others, which claimed the gear first — so best
  items landed in ordinary categories. Now registered at 97.
- **`/valuate deletepreview` printed nothing** unless bags were nearly full. Preview now
  always runs, and reports why items were excluded (quality, value range, or protection).

## [0.9.5a] - 2026-07-08 — Best Equipment frame pooling

### Changed
- **The Best Equipment panel now reuses a persistent pool of column/row frames**
  instead of creating a fresh set (~3 scales × 17 rows × ~11 widgets) on every
  rebuild. WoW never garbage-collects `CreateFrame` widgets, so the old approach
  leaked frames each time the panel refreshed. Structure is built once per column
  (`BuildBestEquipColumn`) and only content + per-slot closures are updated.
  All mutable visual state (icon desaturation/alpha, quality border, texts,
  scripts) is reset each update so a reused row can't inherit a previous look.
  **Untested in-game at release — verify before relying on it (see below).**

## [0.9.4a] - 2026-07-08 — Auto quest turn-in

### Added
- **Auto Turn In Quests** (Settings toggle, off by default; requires "Auto Choose
  Best Quest Reward"). Extends the reward auto-select: at a quest's reward screen
  Valuate completes the quest and takes the best-scoring reward, and it advances
  the "do you have the items?" progress screen for you. Safety: if a reward choice
  can't be scored (e.g. all bags/consumables), the quest is NOT auto-completed so
  you can decide. New `/valuate turnin` command; also on the QUEST_PROGRESS and
  QUEST_COMPLETE events.

## [0.9.3a] - 2026-07-08 — Best Equipment layout & off-hand fixes

### Fixed
- **Item names no longer cut off** in the Best Equipment panel. The score and
  comparison columns were a fixed 130px combined for tiny values ("0.0", "2.5",
  "Lv 12"); tightened them (and the slot-name label) to give the item-name
  column much more room.
- **One-hand weapons are no longer recommended for the off-hand** on characters
  that can't dual-wield. The scan mapped every `INVTYPE_WEAPON` to both the main-
  and off-hand slots unconditionally. A new `Valuate:CanDualWield()` (native API
  → currently-equipped off-hand weapon → class default) now gates the off-hand
  slot; shields, held-in-off-hand items, and off-hand-only weapons are unaffected.
  If detection is wrong for your character, equipping any off-hand weapon once is
  read as "can dual-wield."

## [0.9.2a] - 2026-07-08 — Ignore profession tools

### Added
- **Ignore Profession Tools** (Settings toggle, on by default). Valuate no longer
  scores, displays scores for, tracks as best-in-slot, or filters loot on
  profession tools — fishing poles, mining picks, skinning knives, blacksmith
  hammers, engineering tools, and similar. These are the "Fishing Poles" and
  "Miscellaneous" weapon subtypes; caster held-in-off-hand tomes/orbs (Armor
  subtype "Miscellaneous") are deliberately **not** affected. A central gate,
  `Valuate:IsItemExcludedFromEvaluation`, is applied on the item tooltip, the
  best-equipment scan (and equipped-item comparison baselines), the "Best for"
  indicator, quest-reward auto-select, and the Valuate-PassLoot loot filter.
  Note: item subtypes are localized; the exclusion list uses enUS names.

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

