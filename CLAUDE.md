# Working on Valuate

Operating manual for AI agents (and humans) editing this addon. Everything here was
learned by breaking something — please read before editing.

Valuate is a stat-weight gear scorer for **WoW Ascension 3.3.5a** (Interface 30300), a
classless server. Branch: `claude-fork`.

---

## 1. Verification: what to run, and what it proves

```bash
node tools/gates.js
```

Run this **before every commit** - or install the hook once and stop thinking about
it: `tools/install-hooks.cmd` (double-click, or run it from a terminal).

Gates **discover themselves**: a file in `tools/` is a gate if its header comment
contains an `@gate` line. There is deliberately no list to keep in step - a gate list
that loses an entry does not complain, it just stops running.

- `check.js` parses every Lua file with `luaparse` (Lua 5.1) and enforces the lint rules
  in §4. A Lua *syntax* error means the addon silently fails to load — this is the guard
  against shipping that.
- `tocsync.js` checks the `.toc`'s `ui\*.lua` list against what's on disk. A module that
  exists but isn't listed **never loads**, and a stripped backslash (`uiDialog.lua`)
  looks fine to a parser — both are invisible to `check.js` and were real bugs here.
- **None of these can tell you the UI looks right.** That is what `/valuate verify` is for,
  in-game: a short list of behaviours that fail SILENTLY, each saying what to do, what to
  expect, and what broke last time. Several arm themselves, because "find an upgrade while in
  combat, then leave combat" is not a test anyone runs by hand. **Add an entry there whenever
  you change behaviour a gate cannot see** - `tocsync.js` checks the ids are unique and the
  versions are real, but only a person can notice an entry is missing.
- **Twenty-five gates run Valuate code rather than reading it**: `animtest.js`, `widgettest.js`,
  `importtest.js`, `datatest.js`, `verifytest.js`, `deletetest.js`, `scalelisttest.js`,
  `bestequiptest.js`, `tooltiptest.js`, `arrowtest.js`, `sharetest.js`, `settingstest.js`,
  `tabtest.js`, `dialogtest.js`, `minimaptest.js`, `statsearchtest.js`, `charwindowtest.js`,
  `iconpickertest.js`, `surplustest.js`, `rolltest.js`, `questtest.js`, `futuretest.js`,
  `futurelinetest.js`, `passloottest.js`, `tsmratiotest.js`.
  This matters because
  every static gate passes on a clamp whose comparison is the wrong way round, a
  correct-looking branch in the wrong order, a division by a signed value that should have
  been a magnitude, or a cleanup step in one branch of a copied loop and missing from the
  other.
  `scalelisttest.js` goes furthest — it builds a real panel and drives its buttons.
  `settingstest.js` **builds the whole 2,232-line Settings panel** and drives its keybind
  button. Getting there needed the client's dropdown API and a few EditBox methods in the
  shared mock — those are things the CLIENT provides — and the addon's own `Valuate:`
  methods stubbed **in the gate**. Keep that line: pushing addon API into `luaharness.js`
  would make every other gate test against a more imaginary client than it does now.
  `tabtest.js` builds the main window and drives its tabs. Note that `Valuate:ShowUI()`
  wraps its build in a pcall of its own and reports failure by PRINTING, so it returns
  success on a broken window — assert on `__printed`, not on the pcall result.
  Start with `animtest.js` when extending runtime coverage: the engine's whole external
  surface is `CreateFrame` plus one option read, so its mock is small enough to trust.
  Mutation-tested — every check in it has been shown to fail when the behaviour it names
  is broken.
- **When the logic is worth running but its file is not loadable**, do what `verifytest.js`
  and `deletetest.js` do: match the functions out of `Valuate.lua` by source and execute
  those. The core file needs most of the WoW API to reach its end; a self-contained function
  needs none of it. A failed match exits non-zero and a truncated one will not compile, so
  this cannot degrade into a gate that silently tests nothing.
- **Slicing reaches the INTEGRATION addons too.** `surplustest.js` pulls `ComputeSurplusGear`
  out of `Valuate-AdiBags` — an AceAddon module that needs AdiBags itself to load, but whose
  decision function needs nothing but a fake `self`. Those files use CRLF and tabs unlike the
  core, so anchor slices on `?
end?
`. Skip rather than fail when the sibling addon is
  absent: a gate that fails for missing optional code teaches people to ignore it.
- **An uncaught mutation is not automatically a test gap.** Two guards that each cover the
  same case make either one individually removable with no observable change - an EQUIVALENT
  mutation. Confirm by removing both: if that fails, the pair is jointly load-bearing and the
  test is fine. `tsmratiotest.js` has a worked example. Do not weaken a test to chase one of
  these, and do not delete the redundant guard on the strength of it either.
- **Prove one branch at a time.** `deletetest.js` switches every protection off and enables
  exactly one per case, because a test where several branches could account for the same
  answer passes with five of six broken — and reads as thorough coverage while doing it.
- **Test a pool by REPOPULATING it.** `scalelisttest.js` always hands the pool a different and
  shorter list before it checks anything, because a row that captured its scale at build time
  passes every test that only populates once. That is the difference between covering the code
  and covering the failure.
- **Three places now describe a future upgrade** - the item tooltip line, the Best Equipment
  row when there is no equippable best, and that row's tooltip when there is. All three
  independently implement "never name a level when reqLevel is 0", and all three are
  currently right. Their OUTPUT genuinely differs (a column label, a paragraph, a one-liner),
  so a shared helper would be thinner than the duplication - but if a fourth appears, extract
  the predicate.
- **"We do not know" and "we know there is nothing" are different answers.** The PassLoot
  Upgrade rule returned yes for both: never-scanned AND nothing-tracked-for-this-slot. The
  first is missing data and must decline; the second is knowledge - you own nothing better,
  so the item genuinely is an upgrade - and must match. Applying the rule below to all three
  exits would have been the obvious move and the wrong one, which is why the gate mutates
  that case too.
- **When the action cannot be undone, uncertainty declines to act.** Three decisions now
  share that rule and it is the one to copy: surplus-gear marking says no unless every guard
  clears, quest reward selection picks NOTHING when nothing scored and there is a real choice
  to make, and deletion protects on any doubt. State it as an assertion, not a comment.
- **State an automated action as PROMISES, not as a branch.** Auto-roll decides in a group,
  on your behalf, where other people see the result. Pulled out as `DecideRollType`, its two
  real constraints become assertions over all eight inputs: never Need what we do not want,
  never Pass while Greed is available. A decision small enough to enumerate should be, and
  the promises should be checked on every case rather than the ones you thought of.
- **Sweep the input space for display logic.** `tooltiptest.js` states one property — the sign
  of the percentage matches the sign of the difference — and loops every baseline × difference
  × comparison mode. That found a second bug the hand-written cases missed, in the branch that
  prints `HUGE!` and no number. Formatting code has few enough inputs to enumerate; do.
- **"Exactly one thing changed" is not the same as "the right thing changed."** The Settings
  sweep clicks every checkbox and asserts one option moved and toggles back — and a box wired
  to its *neighbour's* option satisfies all of that perfectly. It was caught passing during a
  mutation run. `settingstest.js` now records which option each box **reads** to draw itself
  (via a recording proxy on `GetOptions`) and requires it to match the one it **writes**. Any
  sweep over near-identical controls needs that second half.
- **Seed a fixture from the real defaults, not a hand-written stub.** The first version of
  that sweep reported 23 failures, every one because an option started `nil` in the stub and
  ended `false` after a round trip. The addon guarantees every key exists at load, so a stub
  that doesn't was testing a state it never runs in. `settingstest.js` slices
  `DEFAULT_OPTIONS` out of `Valuate.lua`.
- **State installed on a BLIZZARD frame outlives you hardest.** `ColorPickerFrame.func` /
  `.cancelFunc` are shared with every other addon, and Valuate's stayed installed after its
  own use ended — so another addon's cancel could run our handler. Clearing on `OnHide` was
  the wrong fix (3.3.5 hides before calling `cancelFunc`); the right one is an **ownership
  check** — act only while our `func` is still installed. No cleanup, no ordering assumption.
  `ui/Pickers.lua` shows the other valid shape: it owns its own frame, so clearing the
  callback on `OnHide` is safe there.
- **A re-entrancy guard must be released on EVERY exit.** `UpdateCharacterWindowDisplay`
  had two near-identical branches that blank the display and only one released the flag —
  which is tested on the function's first line, so the failure is not a wrong number but
  the display never updating again, silently, until a `/reload`. Make the blank-and-release
  one function rather than a pair, and have the gate ask for a real update AFTER the blank:
  a test that only inspects the blank state passes with the guard stuck.
- **An armed state must not outlive the thing that armed it.** Twice now: the Settings
  keybind capture had two exits and both needed the panel in front of you, and the minimap
  drag was cleared only by OnDragStop. Both left the control armed when the frame was
  hidden, and hidden frames get no input — so the trap springs when you come back. Give
  every arming path an `OnHide`, and assert the general form (*after any way this ends, it
  is not armed*) so a third exit added later has a check waiting.
- **Three copies of a widget will drift on the detail nobody tests.** The Settings, stat and
  icon search boxes each grew their own Escape handling — clear-then-unfocus, clear-and-
  unfocus, and clear-if-any-always-unfocus. `ns.CreateSearchBox` owns the chrome, hint and
  keys; callers supply only the filtering, which is the part that genuinely differs. Two of
  the three were written in this session, two releases apart.
- **Find a control by NAME, not by the handler it happens to carry.** `statsearchtest.js`
  first looked for "the EditBox with an OnTextChanged handler" and got a stat weight box —
  all sixty have one, for input validation. Name the frame (as the confirm dialog and the
  upgrade popup already do) and find it by that.
- **Run an accessibility branch through the same assertions as the normal one.** Reduce
  Motion had its own copy of the arrow-driver loop, which returned early and never pruned,
  so the leak existed only with the option ON — the branch nobody watching the screen would
  catch. `arrowtest.js` runs both modes through an identical block on purpose. Better still,
  decide the values and share one loop, so the cleanup cannot belong to one branch.
- `globals.js` does **scope analysis** and reports identifiers read as globals that
  aren't a known API. This is the guard against the worst bug class here: a reference
  that resolves to a nil global instead of the local you meant — Lua raises no error, the
  code just silently misbehaves. It has already caught a missing `HEADER_HEIGHT`
  (arithmetic on nil → the Settings panel would have failed to build), missing
  `ValuateTween`/`EaseOutQuad` in BestEquipment, and a function reading a local declared
  *below* it. **When you move code between files, this is the check that matters.**
  If it flags a legitimate WoW API, add the name to `KNOWN` in `globals.js`.

### The integration addons have no remote

`Valuate-AdiBags`, `Valuate-PassLoot` and `Valuate-TSM` are real git repositories with real
history and **no remote** - everything committed to them exists on one disk. Run:

```bash
node tools/backup.js
```

It DISCOVERS which sibling `Valuate-*` addons lack a remote and writes a verified git bundle
for each (`git clone <name>.bundle` restores the full history). Not a gate: gates only read.

The manual version of this drifted - bundles written by hand on 29 July, not again until
9 August, by which point AdiBags was eight commits ahead of its backup and a PassLoot bug fix
was unbacked entirely. **And the hand-kept list was wrong**: `Valuate-TSM` had never been
backed up at all, because I only ever remembered the two I had been told about. Discovery
found it on the first run.

This is a stopgap. Two private GitHub repos would end the problem; a bundle only helps if the
disk it is on survives.

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
| `no-dialog-oncancel-with-escape` | `onCancel` outside `ui/Dialog.lua` | Escape hides without running it |
| `no-retail-only-api` | 15 methods/namespaces added after Interface 30300 | the call raises, so the rest of the function never runs |
| `no-raw-motion-duration` | literal durations and pulse periods outside the engine | motion that varies without meaning (§ARCHITECTURE) |
| `no-relocalised-shared-state` | `local X = ns.X` for MUTABLE shared state | silently desyncs files |
| `no-duplicate-junk-logic` | `CheckItem(`/`IsJunk(` outside the shared helper | §5 |
| `no-tsm-headcols-write` | assigning to `rt.headCols` in the TSM integration | §11 |
| `anim-tween-needs-owner` | a bare `Anim.tween` outside the engine | §9 |
| `delete-protections-complete` | removing a protection the deletion promise names | §12 |
| `destructive-paths-reverify` | acting on a slot without re-checking it first | §12 |
| `settings-anchor-chain` | two controls anchored to the same frame | §6 |

> **Known false positive:** the rule matches the anchor's *identifier text*, so two
> layout helpers whose anchor **parameter** shares a name (`anchorTo`, `header`) look
> to it like two controls pinned to one frame. Give each helper a distinct parameter
> name (`afterFrame`, `existingHeader`) rather than suppressing the rule — it is
> still catching the real case everywhere else.

**A lint rule is code nobody lints.** `no-retail-only-api` therefore runs a set of sample
lines through its own patterns before it reads a single file, and exits non-zero if any is
classified wrongly. Both failure directions are silent otherwise: a pattern that matches
nothing passes every file forever, and one that matches too much fails correct code —
`destructive-paths-reverify` did exactly that, and was caught only because a mutation run
happened to re-check the baseline. The **negative** samples carry most of the weight;
`SetTexture(1, 1, 1, 1)` is the correct 3.3.5a call and must never be flagged. Do the same
for any rule whose pattern is not obviously exact.
| `sort-needs-tiebreaker` | a `table.sort` comparator with no fallback key | §7 |
| `pairs-list-needs-sort` | a list built in a `pairs()` loop and returned unsorted | §7 |
| `no-bank-in-destructive-path` | bank-cache reads inside delete/sell/free-slot code | §8 |
| `raw-onupdate-needs-reason` | any `SetScript("OnUpdate"` without a written justification | §9 |

### §7 — Sorting must define a TOTAL order

`table.sort` is **not stable**, and `pairs()` order is **undefined**. A comparator that
answers a tie with `false` therefore leaves equal elements in an arbitrary order that can
change between runs — which has produced flipping "Best for" tooltips, a varying reported
"best" scale, and a `deletepreview` that disagreed with what `deletenow` deleted.

Always fall through to a unique key:

```lua
table.sort(items, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.itemId < b.itemId   -- unique tiebreaker
end)
```

### §8 — The bank is read-only, and only for scoring

`Valuate:ScanBankContents` snapshots bank containers (`-1`, and bank bags `5-11`)
whenever the player visits a bank, into `ValuateBankCache`. Stats are parsed **at
snapshot time** — `SetBagItem` gives real scaled stats only while the container is
live; a later `SetHyperlink` silently returns base stats instead.

That snapshot may be read **only** by scoring and ownership code
(`ScanBestEquipment`, `PlayerOwnsItem`, the panel, `/valuate bank`). It must never
reach `AutoDeleteJunk`, `AutoSellJunk`, or `CountFreeBagSlots`:

- deletion is irreversible, and the bank is where people keep gear they care about;
- "keep N slots free" is a promise about **bags** — counting bank slots towards it
  would silently stop the cleanup that promise depends on.

Items sourced from the bank carry `source = "bank"`, and `EquipBestSet` skips them
and says so, because they cannot be reached by `EquipItemByName`.

### §9 — Debounced work must be capped, and gated work must retry

All three schedulers (`ScheduleScan`, `ScheduleJunkCleanup`,
`ScheduleUpgradeNotifyCheck`) had the same pair of defects. Both are silent, so
neither shows up as an error — only as "it just doesn't happen very often".

**1. Uncapped debounce starves itself.** Cancel-and-re-arm on every event means a
continuous event stream pushes the deadline back forever. `ITEM_PUSH` fires once per
looted item and `BAG_UPDATE` fires constantly while looting — so the work never ran
during exactly the activity that requested it. Every scheduler now records when the
burst started and stops re-arming after `MAX_*_DEFER` seconds, letting the armed
timer fire.

**2. A blocked callback must reschedule, not return.** When the timer fired into the
in-transit guard or the bag-quiet window, the work was **dropped**, not deferred.
Those guards mean "not safe *yet*", so returning loses the request entirely. They now
retry on a short delay, **bounded** (≤5 attempts) — `ValuateAfter`'s no-`C_Timer`
fallback allocates a frame per call and WoW never frees frames, so an unbounded retry
would leak.

When adding a scheduler: cap the debounce, and make every early-return in the
callback either reschedule or be genuinely final.

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
| `StatDefinitions.lua` | Stat list, tooltip parse patterns |
| `ImportExport.lua` | Scale import/export strings (tag v2 carries weapon sets) |
| `ValuateUI.lua` | Main window, tab system, character-window display, `Valuate:ShowUI`/`Refresh*` API |
| `ui/*.lua` | The UI panels — see below |
| `MinimapButton.lua` | Minimap button + upgrade pulse |
| `tools/check.js` | Syntax + lint gate |
| `tools/globals.js` | Scope analysis: undefined globals + the `ns.*` contract |
| `tools/tocsync.js` | `.toc` ↔ `ui/` ↔ this file stay in step |
| `tools/options.js` | Options are reachable; every automation defaults to off |
| `tools/commands.js` | Every slash command is in `/valuate help`; every heartbeat is in `/valuate report` |
| `tools/api.js` | Selftest-listed methods exist; integration addons call real ones |
| `tools/animtest.js` | Runs the animation engine for real against a mocked WoW API |
| `tools/widgettest.js` | Runs input validation, colour handling and the shared search box |
| `tools/importtest.js` | Runs scale-tag parsing and the export/import round trip |
| `tools/datatest.js` | Cross-checks the spec templates against the stat definitions |
| `tools/verifytest.js` | Runs the `/valuate verify` walkthrough's pending/staleness logic |
| `tools/deletetest.js` | Runs each of the six deletion protections and proves it fires |
| `tools/scalelisttest.js` | Runs the pooled scale list; proves rows act on the scale shown |
| `tools/bestequiptest.js` | Runs the slot comparison states (empty / unusable / delta) |
| `tools/tooltiptest.js` | Runs the tooltip comparison text; sign, colour and magnitude agree |
| `tools/arrowtest.js` | Ticks the upgrade-arrow driver; proves it prunes in both motion modes |
| `tools/sharetest.js` | Runs the stat-share ranking; shares, sign handling, stable order |
| `tools/settingstest.js` | Builds the Settings panel; keybind capture always releases the keyboard |
| `tools/tabtest.js` | Builds the main window; arrivals only play on arrival |
| `tools/dialogtest.js` | The reused confirm dialog runs the callback it is currently showing |
| `tools/minimaptest.js` | The minimap drag cannot outlive the drag; the pulse stays off OnUpdate |
| `tools/statsearchtest.js` | The stat search dims non-matching rows and touches nothing else |
| `tools/charwindowtest.js` | The character-sheet score still updates after it blanks |
| `tools/iconpickertest.js` | The virtual icon grid hands back the icon you clicked |
| `tools/surplustest.js` | Surplus-gear marking (feeds auto-delete) says no unless certain |
| `tools/rolltest.js` | Auto-roll never Needs what it does not want, never Passes for free |
| `tools/questtest.js` | Quest reward choice prefers upgrades and declines to guess |
| `tools/futuretest.js` | Future upgrades group by the level that actually unlocks them |
| `tools/futurelinetest.js` | The future-upgrade tooltip line never invents a level |
| `tools/passloottest.js` | The PassLoot Upgrade rule does not fire on absent scan data |
| `tools/tsmratiotest.js` | The TSM upgrade columns divide safely (empty slots, zero prices) |
| `tools/luaharness.js` | The shared fengari bootstrap + WoW mock (not a gate itself) |

### `ui/` modules (load order matters — see the `.toc`)

| File | Contents |
|---|---|
| `Shared.lua` | Design tokens (spacing, `COLORS`, backdrops, fonts) **and shared mutable state** |
| `Data.lua` | Icon list, class/spec templates |
|  `DungeonLoot.lua` | Per-boss dungeon loot, and the rule that missing data means silence. **Generated** by `tools/genloot.js` from AtlasLoot - edit the functions in `tools/dungeonloot.tail.lua`, never here |
| `Animations.lua` | Shared-ticker tween engine, easing, Reduce Motion |
| `Widgets.lua` | Validation, colour conversion, `CreateStyledButton`, `ShowTooltipSafe` |
| `Dialog.lua` | `Valuate:ShowConfirmDialog` — the StaticPopup replacement (§3) |
| `Pickers.lua` | Icon picker, template pickers, role-icon helpers |
| `ScaleList.lua` | Left-hand scale list, `UpdateScaleList` |
| `ScaleEditor.lua` | Stat-weight grid, weapon-set group, import/export dialogs |
| `BestEquipment.lua` | Best Equipment tab (**keeps the frame pool** — see below) |
| `Settings.lua` | Settings tab + `CheckColumnAnchors` |
| `TodoPanel.lua` | The To Do tab — renders `Valuate:BuildTodoList`, one clickable row per item |
| `InfoPanels.lua` | Instructions / About / Changelog |
| `CharacterWindow.lua` | Score on Blizzard's character sheet + breakdown tooltip |
| `UpgradeArrows.lua` | Green upgrade arrow on merchant / loot / bag item icons |
| `UpgradePopup.lua` | The "you found an upgrade" popup (separate from the confirm dialog) |
| `Wizard.lua` | The guided scale wizard: three screens over `PlanAutoScale` / `CommitAutoScale` |

**Adding a module:** create `ui/Name.lua` starting with `local _, ns = ...`, re-localise what it
needs from `ns`, publish its entry points (`ns.CreateFoo = CreateFoo`), and add
`ui\Name.lua` to the `.toc` **before** `ValuateUI.lua`. A file missing from the `.toc`
simply never loads — silently. Run `node tools/tocsync.js` to catch that.

### The one rule that makes the split work

- **Immutable** (constants, colours, plain functions): re-localise —
  `local COLORS = ns.COLORS`. Cheap, and call sites are unchanged.
- **Shared mutable state**: always `ns.X` at *every* read and write.
  Currently: `ValuateUIFrame`, `EditingScaleName`, `CurrentSelectedScale`,
  `ScaleEditorFrame`, `ScaleListButtons`, `ValuateUI_OnTemplateOverwrite`,
  `IsDraggingFrame`. Re-localising one of these silently breaks it — the local copy is
  assigned, other files keep reading the old value, and nothing errors.
- **Panel-local state stays local.** Most state is (each panel's frames, widget pools).
  Only promote a variable when a second file genuinely needs it.

Also preserved by design: `BestEquipment.lua` reuses a **frame pool** (structure built
once, content updated per refresh). WoW never frees `CreateFrame` widgets, so rebuilding
rows each refresh leaks them — don't "simplify" that away.

See `ARCHITECTURE.md` for the data model and event flow.

### §10 — A list built from `pairs()` has no order until you give it one

`pairs()` order is **undefined**. A function that builds a list inside a `pairs()` loop and
returns it is returning an arbitrary order, and every caller that indexes `[1]`, renders it in
sequence, or takes a "first" inherits that. It looks perfectly stable until a reload.

`Valuate:GetActiveScales` did exactly this. Its order decided the **Best Equipment column
layout**, and `GetPrimaryScale` took element `[1]` as its fallback — so which scale drove the
**upgrade arrows**, the **character-sheet score** and the **auto-roll baseline** was whichever
one Lua happened to hand over first.

`sort-needs-tiebreaker` (§7) covers the half that already calls `table.sort`.
`pairs-list-needs-sort` covers the half that never sorts at all. Between them, seven instances
of this one bug class.

Sort before returning, with a unique tiebreaker — and if a caller reads only one element,
consider finding it directly instead: `GetPrimaryScale` now scans for its minimum rather than
building and sorting a list to read `[1]`, which is both deterministic and free of the
per-item-per-repaint allocation it used to cost.

### §9 — A raw `OnUpdate` must be a decision, not a habit

A frame has exactly **one** `OnUpdate` slot. Two features that both use it on the same
frame silently overwrite each other, and the loser's cleanup never runs. Two bugs in one
session came from this:

- `MinimapButton`'s upgrade pulse and its drag handler both wrote the button's slot.
  Dragging during a pulse left the starburst glow on screen and the button stuck at up to
  1.14× scale, permanently.
- `ui/Widgets.lua` cancelled a hover fade with `SetScript("OnUpdate", nil)`. That worked
  before tweens moved onto the shared driver and became a **no-op** afterwards — clearing
  a slot that was never set raises nothing. Buttons stopped showing a pressed state.

Neither is visible to a parser and both read as completely ordinary. So the gate does not
try to be clever about which ones are wrong: **every** raw `OnUpdate` is flagged, and the
legitimate ones carry their reason inline.

| Instead of | Use |
|---|---|
| `frame:SetScript("OnUpdate", ...)` to animate | `Anim.owned(frame, propKey, opts)` — owns a *named property*, so unrelated animations on one frame coexist and related ones replace cleanly |
| `frame:SetScript("OnUpdate", nil)` to cancel | `Anim.cancelProp(frame, propKey)` |
| `frame:SetScript("OnUpdate", ...)` to wait | `ValuateAfter(delay, fn)` — reachable from `ui/` as `ns.ValuateAfter`, and as `Valuate.After` |

What legitimately remains is **dedicated driver and throttle frames** — one frame that
exists only to tick, with no other owner. Annotate those:

```lua
-- valuate-lint-ignore: raw-onupdate-needs-reason  dedicated throttle frame; nothing else animates it
throttleFrame:SetScript("OnUpdate", function(self, elapsed)
```

If you cannot write a reason that names the frame's sole owner, it is the bug.

### §11 — `Valuate-TSM` must never append to `rt.headCols`

TSM does index arithmetic off **`#rt.headCols`** in three places — the price-per-unit
right-click toggle and the on-show price relabel in `AuctionResultsTable.lua`, and the
"% Market Value" relabel in `Shopping/modules/Util.lua`.

Append one column and all three silently retarget onto **our** columns. TSM keeps working;
it just operates on the wrong data, in someone else's addon, with no error anywhere.

So the integration is built around keeping `#rt.headCols` at 8:

| Ours | Never |
|---|---|
| headers in `rt.valuateHeadCols` | `rt.headCols` |
| cells in `row.valuateCols` | the row tables (TSM's `RowSort` would index nil through them) |

Both numbers are derived on demand instead — every row already carries `link`, `itemString`
and `auctionRecord`.

Reads are fine and everywhere (`#rt.headCols`, `rt.headCols[i]:SetWidth(…)`). Only
**assignment** is banned, which is what `no-tsm-headcols-write` checks.

This constraint was written down in `Valuate-TSM/Core.lua` and enforced by nothing for as
long as it existed — the same shape as most of the bugs found in this project.

### §12 — The deletion promise is enforced, not just written down

The README and the Auto Delete tooltip both say deletion **never touches**:

> best-in-slot, weapon-set members, future upgrades, anything that's an upgrade for any
> scale, quest items, or items in a WoW equipment set.

Deletion is the only irreversible thing this addon does, so that sentence is the most
load-bearing one in the project. `delete-protections-complete` checks that
`IsProtectedFromDelete` still returns a reason for each of the six.

It checks the **reason strings**, not the logic — it catches a branch deleted or quietly
renamed, which is the failure that would otherwise ship in silence. Those strings are
user-visible anyway: the tooltip cleanup verdict prints them verbatim as
`Junk, but kept: <reason>`.

`deletetest.js` covers the other half: it **executes** `IsProtectedFromDelete` and proves
each of the six actually fires, one at a time with the rest switched off. A branch that is
still present and no longer working — an inverted condition, a dropped option — is invisible
to the string check, and a deleted branch is invisible to the runtime one. Keep both.

Note that **weapon-set members are protected by the best-in-slot branch** —
`GetBestForInfo` consults `weaponKeep` first, so an off-set weapon comes back with a
category. That's why the branch reports `weapon-set member (twohander)` rather than
`best-in-slot`: both are protected, but "kept: best-in-slot" on a weapon you aren't
using reads like a mistake.

If you genuinely need to change what's protected, change the README and the tooltip in
the same commit. The gate exists to make that a decision rather than an accident.
