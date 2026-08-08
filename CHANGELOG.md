# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.44.0a] - 2026-08-09 — An empty slot now says it is empty

### Fixed
- **Empty gear slots showed a grey `--` meaning "no comparison available".** The branch that
  should have said **New** was unreachable: a bare slot has no stats, so its score is nil, and
  `not equippedScore` caught it one branch earlier. Empty rings, necks and trinkets — exactly
  what a levelling character has — rendered as though Valuate had nothing to say about them.
- **It also contradicted the summary line directly above it**, which counts an empty slot's
  whole score as an upgrade. The total said "+120 in bags" and no row admitted to being any
  of it.
- **The tooltip went silent** for anything but a positive equipped score, so hovering an empty
  slot explained nothing — the case where you are most likely to be asking.
- A nil score has **two causes that are not the same answer**: nothing equipped, or something
  equipped whose stats this scale bans. Those are now distinguished; the second still reads
  `--`, because there genuinely is no number to compare.
- An equipped score of **zero or below** now shows a real delta instead of being lumped in
  with "no comparison". Both are numbers a scale can legitimately produce.
- `CLAUDE.md` pointed at `toolsinstall-hooks.cmd` — a stripped backslash, which is the exact
  bug the bullet two lines below it warns about.

### Added
- **"N empty slots you can fill"** in the Best Equipment summary. Deliberately not "empty
  slots": Off Hand is empty by design if you run a two-hander and plenty of builds never fill
  Ranged, so it counts only slots where you own something for them. A line that nags about
  correct slots is a line people learn to ignore.

### Development
- The row and its tooltip each carried their own copy of the three-way branch — which is how
  two answers to one question drift apart. Both now call one named `SlotCompareState`.
- **A thirteenth gate, `tools/bestequiptest.js`**, runs it. Mutation-tested: restoring the
  original branch order fails exactly the check that names the bug.
- Nothing caught this for eighteen releases because it is not a crash, a nil call or a missing
  symbol — it is a correct-looking branch in the wrong order, which no static gate can see.

## [0.43.0a] - 2026-08-09 — The scale list stops leaking

### Fixed
- **The scale list no longer leaks frames.** It rebuilt its rows on every change and orphaned
  the old ones; WoW never frees a frame, so creating, deleting, renaming or recolouring a scale
  cost you about **ten frames per scale, permanently**, for the rest of the session. Rows are
  now built once and repopulated — the same pooling the Best Equipment panel and the stat grid
  already use.
- The colour and icon pickers now check the row still shows the scale you opened them for
  before writing to it. Both are non-modal to the list.
- A row handed back to the pool mid-hover no longer keeps its highlight. Delete a scale while
  the cursor is over the row below it and `OnLeave` never fires.

### Added
- **A new scale fades in**; rows that merely shifted position do not. Deleting the second of
  five scales moves three rows up, and flashing all of them would say "three things happened"
  when one did — the same rule the upgrade arrows follow.
- `/valuate verify rows` — the half a gate cannot see.

### Development
- **This was deliberately not attempted for eleven releases.** The panel's own comment said so:
  the failure mode is a reused row whose handlers still refer to the scale that used to occupy
  it, and one of those handlers deletes a scale with no undo. The blocker was never difficulty,
  it was the absence of a way to prove it — so the note said to write it down rather than
  attempt it blind.
- **`tools/scalelisttest.js`** removes that blocker: 30 runtime checks that repopulate the pool
  with a different, shorter list and then fire the handlers. A row that captured its scale at
  build time passes a test that only populates once; it fails here. Mutation-tested — making a
  row keep its first scale forever fails the delete, the confirmation text, the visibility
  toggle and the editor lookup.
- Two rules keep it safe, both checked: **no handler captures a scale**, and **`release()`
  clears the row's identity**, since a parked row keeps its handlers forever.
- The shared WoW mock gained the frame methods a real panel needs. Deliberately explicit, not a
  catch-all `__index` returning no-ops — a mock that answers every call agrees with every
  mistake.

## [0.42.0a] - 2026-08-09 — The deletion promise is executed, not just read

### Development
- **The six deletion protections are now proven to fire**, in a new gate (`tools/deletetest.js`)
  that runs `IsProtectedFromDelete` for real: quest items, equipment-set members, weapon-set
  members, best-in-slot, future upgrades, and upgrades for any scale. 28 runtime checks.
- **Each protection is proven alone**, with the other five switched off. A test where several
  branches could account for the same answer passes with five of six broken — and reads as
  thorough coverage while doing it.
- **The gap this closes:** `delete-protections-complete` has checked since v0.40.0a that each
  category still has a branch returning its reason string. It cannot see a branch that is still
  present and no longer working — an inverted condition, a dropped option, a lookup that stopped
  returning what the branch tests for. The string is there, the build is green, and gear is
  deleted. Deletion is irreversible, so that was the worst remaining blind spot.
- Mutation-tested: inverting the quest-item `or`, dropping `includeInactive`, killing the
  equipment-set condition, and un-protecting future upgrades each fail exactly the checks that
  name them.
- Also pinned: the upgrade check is asked about **inactive scales too** (drop that and gear that
  is an upgrade for a scale you haven't switched on becomes deletable, silently); a throwing
  container API doesn't propagate out of the scan; and with no client APIs at all the function
  answers rather than errors.

### Fixed
- **The docs said five gates execute real Lua while six did** — caught automatically by the rule
  added last release, on its first opportunity.
- `CLAUDE.md` and `check.js` both stated that a gate cannot tell whether a protection is
  *correct*, only whether it still exists. True when written; this release is the counter-example.

## [0.41.0a] - 2026-08-09 — The checklist becomes a walkthrough

### Added
- **`/valuate verify next`** hands you the next outstanding check — details, reason it exists, and
  it arms itself where it can. Then `/valuate verify done <name>` ticks it and names the next one,
  so the sixteen checks are a loop you work through rather than a list you read.
- **A stale tick comes round again by itself.** Ticks have recorded the version they were made at
  since v0.37.0a, but only the list ever showed it; the walkthrough now treats "verified at v0.30.0a,
  changed in v0.33.0a" as outstanding and says why when it offers it back to you.

### Changed
- Ticking the last outstanding check says so, rather than leaving you to count.

### Fixed
- **A check named after a command verb could never be opened.** `RunVerify` tests `next` / `done` /
  `undo` / `reset` before it searches the list, so an id colliding with one would silently run the
  verb instead. Now a gate rule, with the verbs read out of `RunVerify` rather than listed — a
  hand-maintained copy is the exact drift this checker exists to catch.
- **The docs said four gates execute real Lua while five did.** That count is how a reader decides
  which parts of this addon are behaviour-tested rather than merely known to parse, so it is worth
  being right. Now counted from the gates that pull in the harness and checked against both
  `README.md` and `ARCHITECTURE.md` — the eighth hand-maintained list here to drift, and the fifth
  to drift by *adding* something, which is the direction nobody re-reads for.
- **`CLAUDE.md` said `animtest.js` was the only gate running Valuate code.** Three runtime gates
  ago that stopped being true.

### Development
- **A tenth gate, `tools/verifytest.js`** — 16 runtime checks on the pending/staleness logic.
  Every way it can be wrong is quiet: a stale tick counted as finished, a version compared as text,
  an unknown version treated as old. Mutation-tested.
- It **slices three functions out of `Valuate.lua`** and runs those, rather than loading the file —
  the core file needs most of the WoW API to reach its end, and these need none of it. That makes
  core logic testable for the first time; previously only `ui/` modules were reachable. A failed
  slice exits non-zero and a truncated one will not compile, so it cannot degrade into a gate that
  silently tests nothing.

### Notes
- `done` deliberately **names** the next check without arming it. Arming has side effects — it
  starts a pulse, it fires a combat-exit — and firing one the moment you ticked something else
  means it goes off while you aren't watching, which wastes the check rather than running it.
- 16 runtime checks against the real sliced source of the pending/staleness logic, including that
  `0.9.0a` is older than `0.10.0a` (true as versions, false as text) and that an unknown recorded
  version is treated as unknown rather than old.

## [0.40.2a] - 2026-08-09 — The invariant no gate could reach

### Added
- **`/valuate selftest` now asserts the key best-in-slot invariant**: `[slotId]` only ever holds an
  item equippable *right now*, with anything gated behind level or proficiency living in `.future`.
  `ARCHITECTURE.md` stated this as fact and nothing verified it.
- **Three features rest on it and break together if it slips** — the upgrade prompt treats a slot
  mismatch as a genuinely wearable upgrade, Equip All tries to equip whatever is there, and the
  level-up announcement reports what has just left `.future`. None of them errors when it goes
  wrong; you're simply offered gear you can't wear.

### Notes
- This one **cannot** be a static gate — it needs your character's level and the live item cache.
  That's the honest boundary: the last several releases converted hand-verifications into build
  gates, and this is the first claim where the selftest is the only place it can live.
- An uncached item is **skipped rather than failed**. `GetItemInfo` returns nil until the client
  has seen an item, and reporting a violation the client can't answer would be a false alarm — the
  fastest way to teach someone to ignore a diagnostic.
- Scan logic proven through the harness, including the uncached and unknown-player-level cases.

## [0.40.1a] - 2026-08-09 — And the re-check before acting is enforced too

### Added
- **Lint rule `destructive-paths-reverify`** (14th rule), completing the other half of the deletion
  safety promise: *"both re-verify a slot still holds the vetted item immediately before acting."*
- Both paths queue candidates and act later — deletion in a loop, selling in batches across ticks.
  Bags shift in between. Without the re-check a bag/slot pair is just coordinates, and coordinates
  point at whatever is there **now**. The rule requires the link re-read, the comparison against the
  vetted `c.link`, and the locked check, in the window immediately before the destructive call.

### Notes — two false results caught while building it
- **First version searched the whole function** and passed while the act-time locked check was
  deleted, because `AutoDeleteJunk` also calls `GetContainerItemInfo` in its *scan* loop. The rule
  looked right and was answering a weaker question — exactly the failure it exists to catch.
- **Second version matched a comment.** Both functions name their destructive call in a comment
  near the top, so `indexOf` found that instead of the call, took a window containing no guards,
  and reported all three missing on perfectly good code. Comments are now blanked before the search.
- That one was caught only because the mutation run restores the original and re-checks the
  **baseline** afterwards. Trusting the mutations alone would have shipped a rule that failed on
  correct code — and the first thing anyone does with a gate that cries wolf is weaken it.

## [0.40.0a] - 2026-08-09 — The deletion promise is enforced, not just written down

### Added
- **Lint rule `delete-protections-complete`** (13th rule). The README and the Auto Delete tooltip
  both promise deletion never touches best-in-slot, weapon-set members, future upgrades, anything
  that's an upgrade for any scale, quest items, or items in a WoW equipment set. The gate checks
  `IsProtectedFromDelete` still returns a reason for each of the six.
- Verified two releases ago by hand and found sound — but deletion is the only irreversible thing
  this addon does, and a guarantee that was checked once has a shelf life. Removing or renaming
  any of the six branches now fails the build. Tested by doing exactly that to three of them.

### Notes
- It checks the **reason strings**, not the logic. A gate can't tell whether a protection is
  *correct*; it can tell when one has been deleted or quietly renamed, which is the failure that
  would otherwise ship in silence. Those strings are user-visible anyway — the tooltip verdict
  prints them verbatim as `Junk, but kept: <reason>`.
- **Caught a false positive in my own rule before it shipped**: the guard was
  `basename(file) === "Valuate.lua"`, and `Valuate-PassLoot` ships its own `Valuate.lua` — so the
  gate flagged an integration addon for not containing a function it has no business having. Now
  matched by full path. A check that fires on the wrong file is worse than no check, because the
  first fix anyone reaches for is to weaken it.
- Documented as CLAUDE.md §12, including the non-obvious part: weapon-set members are protected by
  the *best-in-slot* branch, because `GetBestForInfo` consults `weaponKeep` first.

## [0.39.3a] - 2026-08-09 — "Opt-in and off by default" is now enforced

### Verified — no bug
- The README promises **"every automation feature is opt-in and off by default."** Checked against
  `DEFAULT_OPTIONS`: every feature in that table — quest rewards, loot rolls, the upgrade prompt,
  auto-delete, auto-sell, repair, quest accept and turn-in — defaults to `false`. **The claim
  holds.**
- Two options *do* default to `true` — `autoRollRecipes` and `autoRollTradeGoods` — but both are
  modifiers gated behind `autoRollLoot`, which is `false`. `AutoRollOnLoot` returns immediately
  unless that parent is on, so neither can act by itself.

### Added
- **`tools/options.js` now enforces it.** A boolean option whose name begins `auto` or `notify`
  must default to `false`. This is the promise a new install rests on — you add the addon and it
  does not start deleting, selling, rolling or accepting on your behalf until you say so — and it
  only takes one default flipped during a debugging session to make the README a lie about an
  irreversible feature.
- Modifiers can be exempted, but each **must name the parent that gates it**, and the gate checks
  that parent actually guards something. Claiming a parent that doesn't exist fails, so the
  exemption list can't quietly become a dumping ground.

### Notes
- Third consecutive pass to find no bug. That is worth stating plainly rather than padding — but
  a hand-verification that isn't recorded anywhere decays to nothing, so the durable move was to
  convert it into a gate rather than a paragraph.

## [0.39.2a] - 2026-08-09 — The deletion promise, verified

### Verified — no bug
- The README and the in-game tooltip both promise deletion **never touches**: best-in-slot,
  **weapon-set members**, future upgrades, anything that's an upgrade for any scale, quest items,
  or items in a WoW equipment set. Five of those six have an explicit branch in
  `IsProtectedFromDelete`; **weapon-set members do not**, which is what prompted the check.
- **The promise holds.** `GetBestForInfo` consults `weaponKeep` *first*, so an off-set weapon —
  your two-hander while 1H+Shield is active — comes back with a category and is protected by the
  best-in-slot branch. That the protection lives there rather than in a branch of its own is now
  written at the site, since it isn't obvious from the six-item list.

### Changed
- **The protection *reason* now distinguishes the two.** Both were reported as `best-in-slot`, and
  "kept: best-in-slot" on a weapon you aren't currently using reads like a mistake. It now says
  `weapon-set member (twohander)`. The tooltip cleanup verdict shows this string verbatim, so the
  imprecision was user-facing.

### Notes
- Same technique as last release: **a comment that names a set is a testable claim.** This is the
  highest-stakes one in the project — it describes the only irreversible thing the addon does — so
  it was worth checking even though it turned out to be sound.

## [0.39.1a] - 2026-08-09 — Deleting or renaming a scale refreshes the tooltips

### Fixed
- **Deleting a scale, or renaming one, didn't invalidate tooltip state.** `Valuate:ResetTooltips`
  carries a comment saying it is called *"whenever scoring inputs change — a stat weight edited, a
  stat banned, a scale toggled"*, and it also drops the upgrade-arrow cache. Removing a scale
  entirely is plainly such a change, and **none of the three sites called it**: shift-delete,
  confirmed delete, and rename.
- Effect was small — a tooltip already built for an item could keep that scale's cached border
  colour until you hovered something else, and a rename left the "Best for" line keyed on the old
  name. Small, but the claim in the comment was simply not true.

### Notes
- Found by testing the comment rather than trusting it: it names the inputs it covers, so the
  check is just "is that list complete?" Three of the five paths were fine, two were covered
  *transitively* (`LoadScaleFromLibrary` goes through `ImportScale`, which does reset), and
  deletion was the gap.
- **Two things confirmed correct on the way**, worth recording so they aren't re-examined: editing
  a stat weight already drops the arrow cache explicitly — the signature is equipped-gear plus
  primary-scale name, which a weight edit doesn't move, and the code says so. And
  `DeleteScaleFromLibrary` correctly does *not* reset, because the library is account-wide storage
  and removing an entry changes no scoring on this character.

## [0.39.0a] - 2026-08-09 — A tooltip can no longer score the wrong item

### Fixed
- **A malformed item link could be replaced by an unrelated item's link, and the tooltip would
  then parse, score and colour that one instead.** When `GetItem()` returns a link too malformed
  to yield an item ID, the code substitutes the link from the last remembered bag or inventory
  slot. But those were only ever cleared *by each other* — `SetMerchantItem`, `SetLootItem`,
  `SetHyperlink` and the quest setters clear neither — so a bag slot remembered from an earlier
  hover survived onto a completely different item.
- Both are now cleared in `OnTooltipSet`, which every `Set*` hook calls **first**; the two setters
  that know their source then populate it. After it runs, the pair describes the item now being
  shown, or nothing at all.

### Notes
- This is **pre-existing** code, not mine — but it's the same class as the cleanup-verdict bug
  fixed last release, found by asking where else that same stale state was trusted. Worth doing
  in the same pass while the shape was fresh.
- The declarations moved **above** `OnTooltipSet` so it can clear them. A local declared below its
  reader is a nil global, silently — the single most productive bug in this file's history, and
  the reason that move needed care rather than a one-line edit.
- The per-setter clears are now redundant. They're kept as belt-and-braces, but their comments no
  longer imply they're the mechanism — a comment that overstates its own line is how the next
  person misplaces the real guard.

## [0.38.9a] - 2026-08-09 — The cleanup verdict stops reading the wrong bag slot

### Fixed
- **A merchant or loot item could be reported as "Junk, but kept: quest item" because of something
  in your backpack.** The tooltip's cleanup verdict passed `LastBagSlot` to the protection check.
  That value is set by `SetBagItem` and cleared by `SetInventoryItem` — but **not** by
  `SetMerchantItem`, `SetLootItem`, `SetHyperlink` or the quest setters, which only refresh the
  item. So hovering a bag item and then a vendor item left it pointing at the bag slot, and the
  quest-item and equipment-set protections were evaluated against **your bag** rather than the item
  on screen.
- It now re-verifies that the remembered slot actually holds the item being shown, and hands over
  nothing if it doesn't — falling back to the honest "working from the link alone" path the verdict
  already had.

### Notes
- This is the same re-verification the delete and sell paths perform before acting: **confirm the
  slot still holds what you think it does.** The pattern existed; this code didn't reach for it.
- Worse than the `partial` case it now falls back to. Unknown provenance produces a hedged answer;
  *wrong* provenance produces a confident one — on the exact feature whose job is telling you what
  cleanup would do.
- Sixth self-audit pass, sixth defect.

## [0.38.8a] - 2026-08-09 — The progress count stops reading its own output

### Fixed
- **`/valuate verify` counted progress by pattern-matching its own display string.** It searched
  the formatted label for `[x]` and `STALE` to decide how many checks were done. That works right
  up until the marker or the wording changes — at which point the tally silently becomes
  *"0 of 16 checked"* and looks entirely authoritative.
- State and presentation are now separate: `VerifiedState` returns the facts, `VerifiedLabel`
  draws them, and the count reads the former. Reformatting the list can no longer change the
  tally.

### Notes
- **Deriving data from presentation is the same silent-wrongness this checklist exists to catch**,
  which made it a poor thing to have inside the checklist. Fifth self-audit pass, fifth defect, all
  in code from the last dozen releases.
- Proven through the harness, including the two cases most likely to be got wrong: a check ticked
  *before* its behaviour changed counts as done **and** stale, and a tick with an unknown version
  (`"?"`) counts as done but is never called stale — there is nothing to compare it against.
- The superseded function was deleted rather than left beside its replacement.

## [0.38.7a] - 2026-08-09 — The staleness warning stops going stale

### Fixed
- **The "Scanned N ago" label never updated while you sat with the tab open.** It exists to tell
  you the data might be old — and it would itself freeze at *"Scanned moments ago"* for as long as
  the panel stayed up. Leave it twenty minutes and it still claimed the scan had just happened. A
  staleness warning going stale is worse than none, because it's the thing you were relying on to
  notice. It now refreshes every twenty seconds.
- This is the first use of `ns.ValuateAfter` from `ui/`. Before v0.37.0a this file would have had
  to roll its own `OnUpdate` frame — which is exactly what publishing that primitive was for.

### Notes
- Also corrected my own comment on the way in: it claimed the tick "only runs while the panel is
  visible", when in fact only the *update* is skipped while hidden. Stopping and restarting the
  timer would need an `OnShow` hook for one no-op comparison every twenty seconds — not a trade
  worth making, but worth describing accurately rather than flattering.
- Fourth self-audit pass. Confirmed two things were **not** bugs before finding this one:
  `GetScales()` self-initialises so first login can't fault on `next(nil)`, and the pooled stat
  grid handles its scale being deleted underneath it because every handler reads
  `ns.EditingScaleName` when it fires.

## [0.38.6a] - 2026-08-09 — The settings search says how many it found

### Added
- **A match count in the Settings search box.** The filter *dims* rather than hides — which is
  what keeps the anchor chain intact — but that means a match further down the panel is
  dimmed-in-place and invisible until you scroll to it. Without a count there was no way to tell
  **"nothing matches"** from **"the matches are below the fold"**, and those call for opposite
  reactions: one means refine the search, the other means keep scrolling.
- Reads `no matches` in red, or `N match`/`N matches`.

### Notes
- Only groups carrying **text** count. A spacer or a bare texture follows the filter visually but
  isn't a setting anyone was looking for, and counting them would inflate every number.
- Found by auditing my own recent work rather than the older code — third pass, third real gap. A
  feature can be correct and still be unusable if it won't tell you what it did.

## [0.38.5a] - 2026-08-09 — Levelling mid-swap no longer loses the announcement

### Fixed
- **The level-up notice could vanish silently.** `ScanBestEquipment` *refuses* while an equipment
  swap is in flight and returns `false`; the level-up code ignored that return. Ding while gear is
  moving and the scan was declined, the future list was unchanged, and the announcement
  disappeared — at exactly the moment it was wanted. It now retries, up to three times at three
  seconds apart.

### Notes
- The self-audit that found this started from a different worry: that calling `ScanBestEquipment`
  directly might bypass the in-transit guards, which are a standing "never touch" in this project.
  **It doesn't** — the function guards itself rather than relying on `ScheduleScan`, so the direct
  call was always safe. The bug was the opposite of the one I went looking for: not that the guard
  would fail to fire, but that I never noticed when it did.
- Bounded on purpose. If gear is still moving nine seconds later, the next ordinary scan folds the
  items in anyway, and a timer that outlives the moment is worse than a missed message.
- Retry shape proven through the harness, including permanent refusal — it stops after the
  allowance and falls through silently rather than looping.

## [0.38.4a] - 2026-08-09 — The new notices honour "chat messages" like everything else

### Fixed
- **The level-up and bank notices ignored the `chatMessages` option.** Both were added in the last
  few releases and neither was wired to the existing verbosity control — so someone who had
  deliberately turned chat down still got a message on **every level** (sixty-odd times while
  levelling) and on **every bank visit**. That is precisely the noise problem I warned about when
  adding the bank notice, introduced two releases later by the same hand.

### Notes
- **The first-run message deliberately stays ungated**, and that is now written down at the site so
  it isn't "tidied up" later. It fires once in a character's entire life and is the difference
  between the addon working for you and sitting there scoring everything the same. Silencing
  routine chatter is not a request to be left guessing on your first login.
- Same distinction the deletion announcements already make: **safety and orientation are not
  verbosity.** Convenience that repeats is.
- Also worth recording: the audit command I used to check this reported a false negative, because
  its search range began *below* the guard it was looking for. Reading the actual code is what
  settled it — a grep that answers the wrong question confidently is its own small version of the
  bug being fixed here.

## [0.38.3a] - 2026-08-09 — A scale that can't work now says so

### Added
- **`/valuate check` now names any active scale with no stat weights.** Such a scale scores
  everything 0 and looks completely normal doing it — a column of zeros in Best Equipment, `0.0`
  in every tooltip, and nothing explaining why.
- `GetActiveScales` only requires a `Values` **table**, and an empty one is truthy — so this is
  exactly what the **Blank** button produces until you fill it in. It completes the first-run
  story: a new user clicks Blank, gets a scale that silently does nothing, and had no way to find
  out.
- The existing check only fired when **no** scale found anything, so one good scale alongside one
  empty scale went entirely unreported.

### Notes
- Proven through the harness, and the case that mattered was the near-miss: **a negative weight is
  still a weight.** Someone weighting Spirit at −1 to steer away from it has a perfectly good
  scale, and testing `v ~= 0` rather than `v > 0` is the difference between flagging it and
  leaving it alone.
- All-zero weights *do* count as empty, since they score identically to no weights at all.

## [0.38.2a] - 2026-08-09 — Best Equipment admits when its data is stale

### Added
- **The Best Equipment tab now says how old its results are.** `ValuateBestEquipment` is saved per
  character, so it survives logout — open that tab before anything triggers a scan and you are
  looking at **last session's** best-in-slot, presented exactly like fresh results. Loot, vendor or
  level in between and it can be substantially wrong, with nothing saying so.
- Before the first scan of a session it reads *"Not scanned this session — these are last
  session's results"*; afterwards, *"Scanned N ago"*.

### Notes
- The distinction comes free, and by accident of implementation: the automation heartbeat is keyed
  on `GetTime()`, which resets at login. So "no heartbeat" means precisely "no scan since you
  logged in" — exactly the case worth flagging, with no new state to store.
- Updated on **every redraw**, not just when the Scan button is pressed. Background scans update
  the rows without going near that button, and an age label that only tracked manual scans would
  be its own kind of lie.

## [0.38.1a] - 2026-08-09 — The bank tells you while you're standing in it

### Added
- **Opening a bank now says whether anything in it beats what you're wearing.** The count already
  existed — `CountEquippableUpgrades` has always returned a bank figure, and the minimap tooltip
  shows it — but only if you went looking. An open bank is the one moment it's directly
  actionable: the item is an arm's reach away and you're about to walk off without it.

### Notes
- **Scoped to the open event only.** That handler also serves `PLAYERBANKSLOTS_CHANGED`, which
  fires on every item moved in or out — so without the guard, shuffling five things through the
  bank would have printed five times. Caught before shipping by checking what else routes through
  that branch rather than assuming it was bank-open.
- Silent when nothing in the bank is an upgrade, which is the common case. A notification that
  fires when there's nothing to do stops being read.

## [0.38.0a] - 2026-08-09 — Levelling tells you what it unlocked

### Added
- **Gaining a level now names the gear it just made wearable.** The addon already tracked items
  you own that would be upgrades if you were high enough — `future[slotId]`, each with its
  `reqLevel` — and nothing ever looked at that data at the moment it exists for. `PLAYER_LEVEL_UP`
  was not even registered.
- Levelling triggers no rescan under most `autoScan` settings, because your bags did not change.
  So a piece carried since level 18 could sit there long after it became wearable, with the addon
  quietly knowing.

### Notes
- It reports only what **actually left** the future list, not everything whose `reqLevel` you now
  meet. An item can sit there for reasons a level does not fix — an unmet proficiency, say — and
  *"your level is high enough"* is a different claim from *"you can wear this"*. So it notes the
  candidates, rescans, and reports the difference.
- The rescan is deferred two seconds: `PLAYER_LEVEL_UP` fires before `UnitLevel` reports the new
  value on some 3.3.5 clients, and the level arrives in the first vararg — which this handler names
  `addonName`, because `ADDON_LOADED` got there first. It falls back to `UnitLevel` rather than
  trusting a parameter name.
- Output capped at five items, and the list is sorted — it is built from `pairs()` and is
  user-visible, which is the rule `pairs-list-needs-sort` exists to enforce.

## [0.37.2a] - 2026-08-09 — An alt is told its scales already exist

### Changed
- **A new character is now told its scales are one command away.** `ValuateScaleLibrary` and
  `ValuateSettingsSnapshot` are **account-wide**, while scales and options are per-character —
  the library exists precisely so an alt does not start from nothing. But nothing said so at the
  one moment it matters, so anyone who had set this up on their main arrived on an alt, saw a
  Starter scale, and had no idea their real work was already saved.
- The first-run message now lists what is in the library and points at `/valuate library`, plus
  `/valuate settings load` when a snapshot exists. With an empty library you get the template
  advice exactly as before.
- The list is **capped at five names** with "and N more". This prints at login; someone with
  fifteen saved scales wants a hint, not a wall of text.

### Notes
- Same shape as the previous release, one level out: a correct feature existed and the moment it
  was built for never reached for it. Finding these has meant looking at *user moments* rather
  than at code — first install, then first alt.
- The capping logic including both boundaries (exactly five, and six) is proven through the
  fengari harness rather than eyeballed.

## [0.37.1a] - 2026-07-31 — A first install that explains itself

### Changed
- **The first-run scale now says what it is.** A new install got a scale called “Default” whose own
  source comment described it as “for testing”: every primary stat weighted 1.0, so it scores a
  plate DPS piece and a cloth caster piece almost identically. Nothing said so. A new user saw
  numbers that looked authoritative and had no way to know they were placeholders.
- It is now called **Starter**, and a one-time message explains that its weights are crude and
  points at the 45 built-in class/spec templates. Nothing can guess better on their behalf —
  Ascension is **classless**, so there is no spec to infer — which is exactly why saying so is the
  whole job.
- **The template button now has the words and the width.** It was a 20%-wide “+” beside an
  80%-wide “New Blank Scale” — emphasis exactly backwards for the person who needs it most. A
  newcomer cannot usefully fill in a blank scale; not knowing their stat weights is the problem
  the addon exists to solve. Now **From Template** is the wide one and **Blank** sits beside it.

### Notes
- Caught while writing the message: it originally said to click “New from Template”, and no such
  button exists — the visible label was “+”. Telling a brand-new user to click something that
  isn’t there is precisely the wrong first impression, and it is why the button got relabelled
  rather than the message getting vaguer.
- Nothing referenced the old scale name, so the rename is safe.
- `/valuate verify firstrun` covers it, and is honest that it is the hardest check to run: it
  needs a character that has never had Valuate, or `ValuateScales` cleared.

## [0.37.0a] - 2026-07-31 — Rules you can actually follow

### Fixed
- **CLAUDE.md §9 told you delays belong on `ValuateAfter` — and the `ui/` layer could not reach
  it.** It was a file-local in `Valuate.lua`, never published, so nothing in `ui/` could call it.
  `ui/CharacterWindow.lua` consequently rolled its own timer three separate times, each needing a
  lint annotation to explain why it was raw. **A rule that cannot be obeyed is not a rule; it is a
  trap for whoever reads it next.** Now published as `ns.ValuateAfter` and `Valuate.After`.
- **`Anim.setHeight` was documented as "the ONLY writer of a shared height" and was not.**
  `ns.ScaleEditorFrame` had three direct `SetHeight` calls. No bug today — none of them animate,
  so there was no tween to fight — but the claim was false, and it is the claim that makes it safe
  for anyone to animate that frame later. All three now go through it.

### Notes
- The existing `CharacterWindow` timers are **left alone**. They are throttles and debounces
  rather than one-shot delays, they are annotated, and they work; rewriting live UI blind to
  satisfy tidiness is the wrong trade. What changed is that the next one written there has a
  choice.
- Both `ValuateAfter` branches return a handle with `:Cancel()`, so callers can treat the return
  uniformly regardless of which `C_Timer` flavour the client shipped.
- Verified afterwards: **no direct `__anim_` access anywhere outside the engine**, so every
  animation cancel already goes through `Anim.cancelProp`. That primitive needed no work.

## [0.36.3a] - 2026-07-31 — `/valuate errors` stops under-reporting

### Fixed
- **`/valuate errors` could answer "nothing went wrong" while two subsystems had been broken
  since login.** Its whole job is to be the one place to look, and two failure paths bypassed it:
  - the **periodic junk cleanup**, which had its own once-only flag and its own chat message. If
    auto-delete errored, cleanup silently stopped for the session and the command said nothing.
  - the **animation engine**, whose cancelled-callback report also went only to chat, where it
    scrolls away.
- Both now route through `Valuate:ReportRuntimeError`, so they appear alongside event and tooltip
  failures. The junk ticker keeps its extra "run /valuate deletepreview" hint, which is advice the
  generic reporter has no business knowing.

### Notes
- `ui/Animations.lua` guards rather than assumes: it loads before much of the core, so it falls
  back to a plain print if the reporter is not there yet. An engine that errors *while reporting
  an error* is not an improvement.
- The harness now defines `ReportRuntimeError` on the mock for that one test, so both paths stay
  covered — the routing where it exists, the fallback everywhere else. Swallowing the routed call
  fails the gate.
- Same shape as the last two releases: a correct primitive existed (`ReportRuntimeError`, added
  in v0.31.2a) and older code kept its own copy. **A diagnostic that under-reports is worse than
  none, because it is trusted.**

## [0.36.2a] - 2026-07-31 — Every animation is now owned, and the gate says so

### Fixed
- **The stat-editor commit flash could paint a row belonging to a different scale.** It was the
  last bare `Anim.tween` in the addon. Pooling the stat grid (v0.33.0a) made it reachable:
  switching scales now reuses the same edit box, so a flash started under the previous scale
  carried on painting after the row had been repopulated. It settled correctly — `onDone` hands
  the final look back to `ApplyWeightedLook`, which reads current state — but the transient
  belonged to a scale you were no longer looking at.

### Added
- **Lint rule `anim-tween-needs-owner`** (12th rule). A bare `Anim.tween` cannot be replaced, so
  re-triggering stacks and the older run can finish *last* and win. Twice that left a stale value
  on screen — the Best Equipment count-ups last release, this flash now — and **both were in code
  written after `Anim.owned` was added to prevent exactly that.**
- `ui/Animations.lua` is exempt by definition; everywhere else, `Anim.owned` works on any table,
  so there is no excuse involving Blizzard frames. A genuinely one-shot animation is still fine,
  it just has to say so — there are currently **zero** such sites, so the rule costs nothing today.

### Notes
- Verified by reverting both fixes: each fails the gate. This is the companion to
  `raw-onupdate-needs-reason` and exists for the same reason — having a correct primitive is not
  the same as reaching for it.

## [0.36.1a] - 2026-07-31 — Scores stop landing on the previous scan

### Fixed
- **A Best Equipment score could come to rest showing the PREVIOUS scan's number.** The per-row
  count-ups were bare `Anim.tween` calls, not owned ones. Each captured the score it started
  with and wrote to a **pooled** label, so re-revealing the tab — switching away and back, or a
  scan landing while it was open — left the earlier run going. It kept writing the old value and
  finished on it. The staggered delays made it worse: an old tween can outlive a new one, so it
  was not even reliably the newest value that won.
- **`Anim.revealIn` is now owned too.** Every cascade in the addon uses it and they are
  re-triggered constantly. Harmless for alpha alone — both runs end at 1 — but it was the same
  one-property-two-owners fault, and the engine exists to prevent exactly that.

### Notes
- This is the fault `Anim.owned` was added for in v0.23.1a, in code I wrote afterwards. Having a
  correct primitive is not the same as reaching for it; the pattern only holds where it is
  actually applied.
- Pinned in the harness: re-revealing must replace the running tween, and the replacement must
  still land at 1. Reverting `revealIn` to an unowned tween fails the gate. 131 runtime checks.
- `/valuate verify scoreroll` covers the visible symptom.

## [0.36.0a] - 2026-07-31 — `/valuate verify` keeps your place

### Added
- **The verification checklist now tracks what you have already checked**, across sessions:
  ```
  /valuate verify              [x] and [ ] per check, with a count
  /valuate verify done <id>    mark one as passed
  /valuate verify undo <id>    unmark it
  /valuate verify reset        start over
  ```
- Ten checks is more than anyone holds in their head, and losing your place halfway is the
  difference between doing the pass and abandoning it. This is the work I keep calling the
  bottleneck, so making it tractable beats adding more surface that would need verifying too.
- Each tick records **which version it was checked at**, and a check whose behaviour changed
  since then shows as **STALE** rather than done. A tick that quietly goes out of date is
  exactly the failure this checklist exists to catch — it would be a poor thing to build into
  the checklist itself.
- Detail view now ends with the exact command to mark it off, so the loop closes without
  needing to remember the syntax.

### Notes
- Version comparison is **numeric**, component by component. As strings, `"0.9.0a" < "0.10.0a"`
  is false while as versions it is true. Nothing in this project can hit that today — every
  version in play has a two-digit minor — but a comparison that is wrong only for inputs which
  "cannot happen" is a trap left for later, and it cost six lines to do properly. Proven with
  six cases through the existing fengari harness.

## [0.35.1a] - 2026-07-31 — Enforcing the constraint TSM integration rests on

### Added
- **Lint rule `no-tsm-headcols-write`** (11th rule). `Valuate-TSM` is built around one
  constraint: `#rt.headCols` must stay 8. TSM does index arithmetic off that length in three
  places — the price-per-unit right-click toggle and the on-show price relabel in
  `AuctionResultsTable.lua`, and the "% Market Value" relabel in Shopping's `Util.lua`.
  Appending even one column silently retargets all three onto **Valuate's** columns: TSM keeps
  working, on the wrong data, in someone else's addon, with no error anywhere.
- The constraint was written down in `Valuate-TSM/Core.lua` and **enforced by nothing** — the
  same shape as most of the bugs found this session. Documented as CLAUDE.md §11.

### Notes
- Reads are fine and everywhere (`#rt.headCols`, `rt.headCols[i]:SetWidth(…)`); only assignment
  is banned. Verified both ways: appending and assigning each fail the gate, while the existing
  legitimate reads do not trip it.
- **No bug found.** `Valuate-TSM` respects its own constraint correctly — headers live in
  `rt.valuateHeadCols`, cells in `row.valuateCols`, and both values are derived on demand. This
  release is the guard, not a fix.

## [0.35.0a] - 2026-07-31 — The in-game docs catch up, and get gated

### Fixed
- **The in-game Changelog tab was seventeen releases behind.** It ended at v0.17.2a while the
  addon was at v0.34.2a — which is worse than shipping no changelog: a user opening that tab
  concludes nothing has happened since. It now carries a summary of everything since, and
  **`tocsync.js` checks it**: the version marked `(Current)` there must match the `.toc`.
  Every other version-bearing surface was already checked; the only one a *user* sees was not.
- **The Instructions tab never mentioned two features that exist to be discovered** — the
  Settings search box, and the tooltip cleanup verdict. A feature nobody knows about is close to
  a feature that does not exist. Both are now described where someone would look.

### Notes
- The new check is deliberately "the newest entry names the current version", not "every release
  has an entry". The panel is a curated summary; the release-by-release detail belongs in
  `CHANGELOG.md`. That costs one line per release and makes another seventeen-release gap
  impossible.
- `globals.js` caught a nil global in my own edit to that panel (`sectionSpacing` is not in scope
  in the changelog builder — it is `versionSpacing`). That would have errored when the tab was
  opened, and nothing else would have noticed.

## [0.34.2a] - 2026-07-31 — The integrations are checked too

### Added
- **`tools/api.js` now verifies every `Valuate:X()` that the integration addons call.**
  `Valuate-AdiBags`, `Valuate-PassLoot` and `Valuate-TSM` load separately from Valuate, so a
  method renamed here breaks them **at loot time or on a bag repaint** — not at load, where you
  would notice. Nothing checked this. 29 calls across the three now resolve, and renaming one
  fails the gate with the exact method and file.
- Guarded calls (`if Valuate.X then`) are checked as well. A defensive guard means the caller
  degrades instead of erroring; it does not mean the name may be wrong.

### Notes
- Found by auditing `Valuate-PassLoot`, the one component untouched all session while Valuate's
  API moved underneath it. **All ten of its calls were already correct** — no bug. The gate is
  the deliverable, not a fix.
- `ui/ScaleList.lua` was re-examined for the captured-scale problem that was real in the weapon-set
  handlers. It is **not** present: its handlers capture only the scale *name* and re-read the table
  by that name when they fire. Another negative result worth recording so it is not re-checked.

## [0.34.1a] - 2026-07-31 — ARCHITECTURE.md catches up

### Changed
- **`ARCHITECTURE.md` documented none of this session's subsystems.** It was last touched before
  the animation engine gained its ownership model, before the runtime harness existed, and before
  two panels were converted to frame pools. That is the document a fresh session reads instead of
  re-deriving the codebase, so a stale one is worse than none — the same drift found in the README
  four releases ago, in the document where it costs most.
- Three sections added: **Animation** (the shared driver, why ownership is by named property, the
  motion tokens, the easing invariant), **Frame pooling** (what WoW does not free, which panels
  pool and which does not), and **Verification** (what static gates prove, what the runtime gates
  prove, and what only a person in the game can answer).
- The verification section also records **the recurring bug shape** this session kept finding:
  not typos, but code that was correct when written and quietly stopped being correct — or a
  principle the codebase already states, applied everywhere except one place. Six concrete
  instances are listed. Auditing for that shape found more than looking for mistakes did.

## [0.34.0a] - 2026-07-31 — The tooltip tells you what cleanup would do

### Added
- **Item tooltips now say whether Valuate would sell or delete the item**, and what is
  protecting it if not:
  - `Junk, but kept: best-in-slot` (or *quest item*, *in an equipment set*, *future upgrade*, …)
  - `Junk — nothing is protecting this`
- The cleanup features have always been able to answer this — but only if you remembered to type
  `/valuate why`, which is the wrong moment. You want it while looking at the item, *before*
  switching automation on. "Make sure the auto junk is robust" was never really a request for
  more guards; it was a request to be able to see what it would do.
- **It configures itself: no new option.** The line only appears while auto-sell or auto-delete is
  armed, so people who don't use cleanup never see it, and nobody needs a 48th setting to turn it
  off. It also only ever appears on items that *are* junk.
- When the tooltip doesn't know the item's bag and slot, it says "would be removed from your bags"
  rather than "nothing is protecting this" — the quest-item and equipment-set protections can't be
  evaluated without them, and claiming a quest item was unprotected would be a poor way to find out.

### Notes
- `Valuate:GetJunkVerdict` is a method rather than a file-local because the tooltip code sits ~3,600
  lines *above* `IsProtectedFromDelete`, and a local declared down there would be a nil global up
  here. That trap has produced two real bugs in this file already.
- The line has its own added-flag, reset everywhere the score lines' flag is. The tooltip refresh
  runs every frame, so without one the line would be appended sixty times a second — which is
  exactly what `/valuate verify junkline` tells you to watch for.

## [0.33.1a] - 2026-07-31 — Auto-delete won't touch a slot mid-move

### Fixed
- **Auto-delete could act on a bag slot that was mid-operation.** A `locked` slot is one the
  client is still resolving — being moved, split, or awaiting the server. `AutoSellJunk` has
  always skipped those, at both scan time and at the moment of sale. Auto-delete, the
  **irreversible** path, checked at neither. It now does both.
- The existing link re-verify does not cover this: a slot can be locked while still reporting
  the same item link, so "the contents didn't change" was true and the delete proceeded anyway.
- Locked slots are counted as protected rather than deletable, so `/valuate deletepreview` can
  never claim an item is deletable that the same pass would refuse to touch.

### Notes — what this audit did *not* find
- The re-verify guard the README promises for **both** delete and sell is genuinely there in
  both. My first check looked in `AutoSellJunk` and found nothing; the guard lives in
  `SellNextBatch`, where the actual selling happens. No bug — worth stating plainly rather than
  leaving the impression there was one.
- `ui/ScaleList.lua` still rebuilds rather than pools, and I have deliberately **left it that
  way**. It is the same pattern the stat grid just got, but the risk profile is different: the
  leak is now ~5 frames per user action rather than 250 per click, while `scaleData` is captured
  by ten handlers including **delete**, so a rebinding mistake deletes the wrong scale. Small
  gain, irreversible failure, no way to test it — the trade doesn't hold.

## [0.33.0a] - 2026-07-31 — The stat grid is a pool at last

### Fixed
- **Clicking a scale no longer orphans ~250 UI frames.** The stat editor discarded every row
  and rebuilt the grid on each call — ~60 stat rows plus their columns and containers — and
  `SetParent(nil)` does not free a frame in WoW; nothing does. Clicking through ten scales cost
  on the order of 2,500 frames, permanently, and frame count is a global UI cost rather than
  just this addon's problem. The grid is now built once and repopulated.
- `ui/BestEquipment.lua` was rewritten around a pool for exactly this reason back in v0.9.5a.
  This function never got the same treatment; now it has.

### Notes — why this was safe to do, having not been before
- The layout is **scale-invariant**: it is generated from `ValuateStatCategories` and
  `ValuateEquipmentCategories`, which are static data. Only the values differ.
- A row captures nothing about its scale except two values — every handler on it already reads
  `ns.EditingScaleName` when it fires. So reuse only has to re-run `row.populate`, which is the
  same code a freshly built row runs. A reused row cannot reach a state a new one could not.
- `UpdateBannedState` is symmetric, so a stat banned by the previous scale is cleanly un-banned
  rather than left greyed out. Order matters there and is documented at the call: the value is
  set *before* it, because it finishes by reading the box.
- The weapon-set widgets were the one exception — they captured their scale table — which is why
  **v0.32.1a had to land first**. That was a real bug in its own right.
- **The old rebuild remains as a fallback.** Reuse is attempted only when the cached grid still
  belongs to the current editor frame; otherwise the function falls through and rebuilds exactly
  as before. The worst case of a stale cache is the old behaviour, not a broken editor.
- `/valuate verify statgrid` covers it. The symptom to watch for is a row showing the *previous*
  scale's value — which matters more than it sounds, because you might then "correct" a value
  that was never wrong.

## [0.32.1a] - 2026-07-31 — Weapon-set toggles write to the scale you're editing

### Fixed
- **A weapon-set toggle could silently do nothing.** The Weapon Sets checkboxes and the active-set
  button captured the scale table they were built with. Importing a scale tag, or loading one from
  the library, **replaces that table wholesale** (`scales[name] = newData`) — so after either, the
  captured reference pointed at an orphan. Clicking a weapon-set checkbox moved the checkbox and
  wrote the setting to a table nothing reads. No error, no visible sign, setting lost.
- All four handlers now read the current scale via `ns.EditingScaleName` at click time, and bail if
  there isn't one.

### Notes
- `CommitValue`, four functions up in the same file, already did exactly this and carries a comment
  giving this reason. Same file, same problem, the principle applied to one and not the other — the
  fourth time that pattern has produced a real bug in as many releases.
- This is also the prerequisite for pooling the stat grid: handlers that read the current scale can
  be reused across scales, which ones capturing a table cannot. The pooling itself is still
  outstanding (~250 frames orphaned per scale you click) and remains documented at the function.

## [0.32.0a] - 2026-07-31 — Dragging the colour wheel stops leaking frames

### Fixed
- **Adjusting a scale's colour orphaned thousands of UI frames.** WoW calls the colour
  picker's callback on *every* colour change — continuously while you drag the wheel — and
  that callback rebuilt the entire scale list each time. `UpdateScaleList` discards its
  buttons with `SetParent(nil)`, which does **not** free a frame in WoW; nothing does. With
  five scales, a few seconds of dragging permanently orphaned a couple of thousand frames.
  The rebuild was also **redundant**: the swatch is the only thing in a row that shows the
  colour, and the callback already updated it directly. The rebuild is gone.
- The cancel path now restores the swatch directly too, for the same reason.
- `ui/Pickers.lua`'s template-button tooltip was the last hover handler calling
  `GameTooltip:SetOwner` directly instead of going through `ShowTooltipSafe`, so it could
  appear while a frame was being dragged. Every other one in the addon already went through it.

### Notes — known leaks, written down rather than half-fixed
- `UpdateScaleList` and `UpdateStatWeightsList` both **rebuild rather than pool**. Each call
  orphans about five frames per scale, and roughly 250 frames respectively, permanently.
  `ui/BestEquipment.lua` hit exactly this and was rewritten around a pool; these two never got
  the same treatment.
- Removing the colour-picker caller takes the scale-list leak from *alarming* to *slow* — what
  remains is one call per user action rather than dozens per second.
- The stat-editor one (~250 frames per scale you click) is untouched. Fixing it means splitting
  a ~250-line layout builder into build-once and populate, on live UI I cannot run. That is
  recorded in a comment at the function rather than attempted blind — a botched conversion
  breaks the stat editor outright.

## [0.31.2a] - 2026-07-31 — The tooltip can't spam you any more

### Fixed
- **An error while scoring a hovered item would have repeated ~60 times a second.** The tooltip
  refresh runs every frame for as long as a tooltip is on screen, and it was the one hot handler
  with no error containment — so a single bad item wouldn't produce *an* error, it would produce
  a wall of them, every frame, until you moved the mouse. That is the difference between the
  addon being broken and the game being unusable.
- It now reports **once** and carries on. Deliberately not disabled after an error: one malformed
  item would otherwise switch tooltip scoring off for the rest of the session, silently, which is
  worse than a single line in chat. The error is listed by `/valuate errors` alongside event
  errors.

### Notes
- This wasn't a new idea — the event handler, the AdiBags filter and the minimap-button tooltip
  all already contain their errors, each with a comment giving this exact reason. The
  highest-frequency handler of the four was the one that never got it. The reasoning was
  already written down three times; it just hadn't been applied here.
- `Valuate:ReportRuntimeError` is a **method** rather than a file-local on purpose: its callers
  live thousands of lines above the error machinery, and a local declared down there would be a
  nil global up here — the trap this project has now hit twice.

## [0.31.1a] - 2026-07-31 — `/valuate export` stops guessing

### Fixed
- **`/valuate export <name>` could silently export the wrong scale.** It took the *first*
  case-insensitive match from a `pairs()` loop, which has no order — so with two scales whose
  names differ only in case, or where one scale's internal key equals another's display name,
  you got an arbitrary one of them with no indication. Handing someone the wrong scale is a
  failure you find out about later, if at all. It now collects every match: an exact
  internal-name hit wins outright (keys are unique), and anything still ambiguous is **reported
  with the exact names to choose from** rather than guessed at.
- **"Available scales" printed in a different order each time.** Two separate listings each
  looped `pairs()` and printed as they went. Minor on its own — but that list is what you read
  to find the exact name to type back in, and a list that reorders itself is a poor thing to
  search. Both now go through one sorted helper, which also shows the internal key when it
  differs from the display name, since that is exactly when the display name may be ambiguous.

### Notes
- Found by auditing the four `pairs()` loops that `break` early — "take the first match" from an
  unordered iteration. The other three are existence checks where order cannot change a boolean,
  so they were left alone; a lint rule for this shape would be three-quarters false positives,
  which is worse than none.
- `pairs-list-needs-sort` (added last release) does **not** catch this shape — it sees lists that
  are built and returned, not loops that break on a first match. Worth knowing where the rule's
  edge is rather than assuming it covers the whole class.

## [0.31.0a] - 2026-07-31 — Which scale is your primary, deterministically

### Fixed
- **Your scales could change order between reloads, and so could which one Valuate treats as
  primary.** `Valuate:GetActiveScales` built its list with `pairs()`, whose order is undefined,
  and never sorted it. Twelve callers treat that list as if it had an order — the **Best
  Equipment tab lays its columns out in it**, and `GetPrimaryScale` took element `[1]` as its
  fallback, which decides which scale drives the **upgrade arrows**, the **character-sheet
  score** and the **auto-roll baseline**. It's now sorted by display name (matching the scale
  list beside it) with the scale key as a tiebreaker.
- **`GetPrimaryScale` no longer builds a list to read one element from it.** It ran for every
  item icon on every bag repaint — from the top of `IsItemLinkUpgrade`, *before* that function's
  cache was consulted, so the cache never saved this part. A hundred icons meant a hundred table
  allocations and sorts per repaint, purely to answer a question whose answer changes only when
  you toggle a scale. It now scans for the minimum directly and allocates nothing.

### Added
- **Lint rule `pairs-list-needs-sort`** (10th rule, and the first that works on the AST rather
  than a single line). It flags a function that appends to a list inside a `pairs()` loop and
  returns it unsorted. `sort-needs-tiebreaker` covered the half that already calls `table.sort`;
  this covers the half that never sorts at all. Between them: seven instances of this one bug
  class. It fires on nothing in the codebase today, and on `GetActiveScales` the moment its sort
  is removed.
- A self-test assertion that `GetPrimaryScale()` agrees with `GetActiveScales()[1]`. The two now
  implement the same ordering separately, which is precisely how orderings drift — and the
  symptom would be quiet: arrows following one scale while the columns lead with another.

### Changed
- `check.js` reported `RULES.length + 3` rules — a magic number needing to be remembered every
  time a structural rule was added, and silently under-reporting when it wasn't. The four
  non-array rules are now named in one list, so the count is derived and the list doubles as
  their only index.

## [0.30.0a] - 2026-07-31 — The gates run themselves

### Added
- **`tools/gates.js`** — one command runs every gate (about 1.3s). Nothing else lists them:
  a file in `tools/` **is** a gate if its header comment carries an `@gate` line, so gates
  declare themselves and adding one has no second step to forget.
- **A `pre-commit` hook**, installable by double-clicking `tools/install-hooks.cmd`. Nine
  gates that run only when someone remembers to run them are nine gates that will eventually
  not run — and "I ran the gates" is exactly the kind of quiet assumption that every real bug
  this project has found was made of. `git commit --no-verify` bypasses it; needing that twice
  means the gate is wrong.
- The hook **refuses** if `node` isn't on PATH rather than passing. A missing toolchain that
  silently lets every commit through looks identical to success, which is the worse failure.

### Changed
- The gate list had reached four copies (`package.json`, `CLAUDE.md`, `README.md`, and whatever
  got typed at the shell). Seven hand-maintained lists here have drifted, and a gate list is the
  worst one to lose an entry from: the missing gate doesn't complain, it just stops running while
  everything keeps reporting OK. There is now one source, and it's discovery rather than a list.
- `gates.js` **refuses to report success** if discovery finds fewer than five gates, for the same
  reason — a broken discovery would otherwise wave every commit through with a green "0 passed".

### Fixed
- **README documentation drift.** It still claimed the gates "check *structure*, never behaviour:
  there is no Lua runtime here" — false since the fengari harness four gates ago, and the Status
  section repeated it. Both now say what's actually true: four subsystems are genuinely
  behaviour-tested, everything else is statically verified only.

## [0.29.0a] - 2026-07-31 — Find the setting you're looking for

### Added
- **A search box at the top of Settings.** Forty-seven options across three columns: knowing an
  option exists and finding it are different problems, and only the first was solved. Type
  `junk` and the junk-related rows stay bright while everything else recedes.
- **It dims rather than hides**, deliberately. Every control here anchors to the one above it,
  so hiding one would collapse the rest of the column — the exact failure the
  `settings-anchor-chain` lint rule exists to catch. Alpha touches no anchors, so nothing can
  move.
- Escape clears the filter before it gives up focus, so a stray press can't leave the page
  dimmed with no visible reason.

### Notes
- **The search index is derived from the built UI, never hand-maintained.** A list of
  "option → search words" would be the eighth such list in this project, and the other seven
  have all drifted. This one reads the labels actually on screen, so an option added tomorrow
  is searchable with no extra step.
- The wrinkle: a label isn't reliably part of the control it names — about half are regions of
  their checkbox, and the half beside dropdowns and sliders are regions of the *column*, so no
  amount of walking children finds them. What *is* reliable is that a label and the thing it
  labels sit on the same **line**, which is a property of the layout rather than of how it was
  written. Elements are grouped by vertical position and share their combined text.
- The index refuses to cache an implausible result. `GetTop()` is nil for a frame that has never
  been laid out, and a too-early build would cache empty for the whole session with searching
  silently doing nothing; the next keystroke simply tries again.
- **Not covered by any gate** — this is pure UI. `/valuate verify search` walks through it.

## [0.28.1a] - 2026-07-31 — Guarding the templates

### Added
- **`tools/datatest.js`** — cross-checks `ui/Data.lua`'s ~45 class/spec templates against
  `StatDefinitions.lua`. Between them those files hold roughly a thousand hand-typed stat keys,
  and a typo in any one is completely silent: the template produces a weight under a key nothing
  ever matches, so that stat simply doesn't count. The template looks fine, the scale looks
  fine, and the scores are quietly wrong. 3,640 checks.
- Nothing else could see this. `luaparse` is happy — it's a valid table. `globals.js` is happy —
  they're table *keys*, not identifiers. Only comparing the two files catches it.
- Also checked: every stat has a display name (the editor falls back to the raw key, which reads
  as a bug rather than a missing label), no template scores everything zero, spec colours are
  real hex, and the icon picker's "no icon" entry is present exactly once and first.

### Notes
- **The gate found no bugs — the data was already correct.** Its first three "findings" were all
  wrong assumptions of mine: that weights can't reference equipment rows (they can and should —
  `IsLibram = 0.3` is how a paladin values a libram, and parsing genuinely produces that key),
  that the empty icon entry was malformed (it's the deliberate "clear selection" option), and
  that duplicate icons were sloppy (the same icon sits under two headings on purpose, so it's
  findable either way). Each was corrected in the test, not the data.
- Duplicate icons are deliberately **not** checked. A gate that fails on a considered choice is
  worse than no gate — a lesson this project already learned from `settings-anchor-chain`.
- Six mutations — a one-letter stat typo, a ban typo, a weight given as a string, a malformed
  colour, a missing display name, and a misplaced no-icon entry — all fail the gate.

## [0.28.0a] - 2026-07-31 — Exports you can actually import

### Fixed
- **Exporting a scale whose name contained `{`, `}` or `|` produced a tag this addon then
  refused — or worse, silently corrupted.** The rule lived only in the *parser*, so the
  exporter never consulted it. With `}` or `|` you got a rejection blaming the tag's format,
  with nothing pointing at the name. With `{` there was no error at all: `My{Scale` exported
  and re-imported as a scale called **`My`**, because the parser's pattern stops at the first
  brace. The rule now lives in one place (`Valuate:IsValidScaleTagName`) that both sides use,
  and export refuses up front with a message naming the scale to rename.
- **Export-all silently dropped scales it couldn't serialise.** It now reports each one. Nine
  tags when you have ten is the same silent loss, and bulk export is exactly when nobody counts.
- Every export failure path now says *which* problem it hit instead of "Failed to generate
  export string for scale."

### Added
- **`tools/importtest.js`** — a third runtime gate, covering `ImportExport.lua`. That file makes
  zero WoW API calls and parses text pasted in from elsewhere, so two properties matter and
  neither is visible to a parser: export→import must be lossless, and anything the exporter can
  produce the importer must accept. 78 checks, including malformed input that must never raise,
  version compatibility in both directions, and the full weapon-set round trip.

### Notes
- The harness confirmed one thing that *looks* like a bug and isn't: a disabled weapon set
  round-trips as `nil` rather than `false`. `IsWeaponSetEnabled` reads a missing key inside an
  existing table as disabled, so the two are equivalent — the check now asserts the semantics
  rather than the representation, and the all-disabled case (where the table must still exist,
  or every set silently switches back on) is pinned separately.

## [0.27.1a] - 2026-07-31 — A bad colour no longer takes down a panel

### Fixed
- **`HexToRGB` errored on any six-character string that wasn't valid hex.** It checked the
  *length* of a colour but not its *validity*, and `tonumber("ZZ", 16)` is nil — so the
  division that followed raised, inside whichever panel happened to be building at the time,
  taking the whole panel down rather than showing one wrong swatch. Scale colours come from
  saved variables and imported scale tags, neither of which the addon controls, so a
  hand-edited file or a malformed tag was enough. Invalid colours now fall back to white.

### Added
- **`tools/widgettest.js`** — a second runtime gate, covering `ui/Widgets.lua`: the stat-weight
  input validation and colour handling. That is the addon's pure logic, it is all edge cases,
  and every failure mode is quiet — a weight that silently becomes a different number, or a
  colour that resolves to white and looks like a theme choice. 61 checks; the `HexToRGB` bug
  above is what the first run found.
- **`tools/luaharness.js`** — the fengari bootstrap and WoW mock, extracted from `animtest.js`
  once there was a second file worth executing. Deliberately one mock: two drifting copies of
  "what the client does" would be worse than none, since each gate would then be testing
  against a different imaginary WoW.

### Notes
- The harness also pinned two behaviours that are correct but easy to misread: `RGBToHex`
  **floors** rather than rounds (0.5 → `7F`, not `80`), and `ValidateWholeNumberInput` returns
  exactly one value rather than leaking `gsub`'s replacement count as a second return.

## [0.27.0a] - 2026-07-31 — Arrows arrive

### Changed
- **Upgrade arrows now pop out to full size when they appear** instead of simply being there.
  The arrow's whole job is to be noticed, and something arriving catches the eye in a way
  something already present does not. Both in your bags (AdiBags) and at merchants and loot
  windows.
- **Only when the arrow is genuinely new.** The arrow update runs for every button on every
  bag repaint, so the risk here is the exact opposite of the feature — a naive version makes
  every arrow jitter constantly while you move items around. Each arrow remembers which item
  it is for, so the entrance also correctly re-plays when a slot's upgrade is replaced by a
  *different* upgrade, which a plain shown/hidden flag would miss.
- **The entrance animates size, not alpha** — deliberately. The pulse driver writes alpha to
  every visible arrow on every frame, so an alpha-based entrance would be overwritten a frame
  later. That is the same collision that took two releases to find elsewhere; here the two
  animations share a driver and never touch the same property.
- Interrupting an arrow mid-entrance (closing the bag, equipping the item) restores it to full
  size, so it can never come back at 40%.

### Added
- `/valuate verify arrow` for the above — the first entry added under the rule introduced last
  release, that behaviour a gate cannot see gets a check.
- The harness now pins an assumption `ui/UpgradeArrows.lua` makes about the engine: that owned
  tweens work on a **plain table**, not just a frame. That is what lets the arrows own their
  tweens on their own record instead of writing a field onto a Blizzard item button.

## [0.26.0a] - 2026-07-31 — `/valuate verify`

### Added
- **`/valuate verify`** — the behavioural checks no gate can answer. Six static gates parse
  and scope-check every file and a headless harness runs the animation engine, but none of
  them can tell you whether a button looks pressed. Several releases have now shipped fixes
  whose only proof was that the reasoning was careful; this is the list of what that leaves.
- **Checks arm themselves where they can.** `/valuate verify combat` sets the deferred-upgrade
  flag and runs the leave-combat path directly, because "find an upgrade while in combat, then
  leave combat" is not a test anyone performs by hand. `/valuate verify minimap` starts a pulse
  so you can interrupt it with a drag.
- **A check that cannot possibly fire says so first.** Arming the combat check with no upgrade
  in your bags reports exactly that, rather than showing nothing and letting it read as a
  failure. Same for Reduce Motion being on when the check is about motion.
- Every entry names the version that introduced it, the steps, what to expect, and **what broke
  last time** — the failure mode is the part worth knowing, since all of these fail silently.

### Changed
- `tools/tocsync.js` now checks the verify list itself: ids must be unique (`/valuate verify
  <id>` takes the first match, so a duplicate would silently shadow the other entry) and every
  `since` must name a real CHANGELOG release. Seven hand-maintained lists in this project have
  drifted; a checklist that cites a version nobody shipped is worse than no checklist.
- `RunVerify` and `CountEquippableUpgrades` added to the self-test's method list.

## [0.25.0a] - 2026-07-31 — See what the scan changed

### Added
- **Slots whose best item changed since you last looked now light up briefly** in the Best
  Equipment tab. A scan used to rewrite the panel in silence — with seventeen slots per scale
  across several columns, finding the one that moved meant remembering what was there before.
- The comparison is against **the last state you actually saw**, not the last redraw. A scan
  that happens while you are on the Settings tab is not consumed silently; switching to Best
  Equipment still shows you what it did.
- Nothing flashes on first sight of a scale, and nothing flashes on a refresh that changed
  nothing — the two cases where a highlight would say nothing at all.
- Under Reduce Motion the row simply never lights up. A notification has no meaningful
  "instant" form, so there is nothing to collapse it to.

### Notes
- The change is keyed on the item **link** rather than the item id, so a differently-enchanted
  version of the same base item correctly counts as a different best-in-slot.
- This is cosmetic and its logic is not covered by the runtime harness — `ui/BestEquipment.lua`
  has far too large an API surface to mock honestly. Worth a look in-game: run a scan that you
  know changes one slot, and check that exactly that row lights up.

## [0.24.0a] - 2026-07-31 — The window resizes instead of snapping

### Changed
- **The main window now animates its height** instead of jumping. Switching tabs, selecting a
  scale, and Best Equipment growing to fit its rows all ease into the new size. This is the
  most visible thing the animation engine does, and it was the last place that still snapped.
- **`Anim.setHeight(frame, height, animate)` is now the only writer of a shared frame's
  height.** It had seven writers across three files — fine while they all snapped, and a
  hazard the moment one animates: a plain `SetHeight` landing during a running height tween
  is overwritten on the very next frame, and the window springs back to a size nobody asked
  for. That is the same defect the `OnUpdate` slot kept producing, so the consolidation came
  first and the animation second.
- The Best Equipment tab's reset-to-minimum deliberately still snaps — animating it would run
  the window toward the minimum and then reverse as the content fit lands.

### Added
- **The easing library's endpoint invariant is now pinned.** Everything downstream depends on
  an easing returning *exactly* 1 at t=1 — that is what makes a tween land on its target — and
  nothing tested it. An easing added later that overshot or fell short would have broken
  several unrelated things at once, silently. Checking it also documented a real asymmetry:
  t=1 must be exact, while t=0 only needs to be near, because `outBack` legitimately returns
  2.2e-16 there and the driver never evaluates t=0 anyway.
- Harness now at 126 runtime checks.

## [0.23.2a] - 2026-07-31 — The one OnUpdate slot

### Fixed
- **Buttons showed no pressed state on a quick click.** `OnMouseDown` cancelled the running
  hover fade with `SetScript("OnUpdate", nil)` — correct before tweens moved onto the shared
  driver, and a silent no-op ever since, because clearing a script slot that was never set
  raises nothing. The hover tween simply overwrote the pressed colour on the next frame.
- **The character-sheet fallback gave up after one attempt.** Its comment says "also try
  periodically in case event doesn't fire", but it cleared its own `OnUpdate` unconditionally
  after the first try — so if the character UI was still loading one second in (exactly the
  case it exists for), the score never appeared. It now retries once a second until it
  succeeds, stopping after 15 attempts so a client with no character UI isn't polled forever.

### Added
- **`Anim.cancelProp(frame, propKey)`** — "stop animating this and give me the property
  back", the counterpart to `Anim.owned`. There was previously no way to express it, which
  is why the dead `SetScript` line survived. Three new harness checks, all mutation-verified.
- **Lint rule `raw-onupdate-needs-reason`** (9th rule). A frame has one `OnUpdate` slot, and
  two bugs this session came from sharing it. The rule doesn't try to guess which uses are
  wrong — it flags every raw `OnUpdate` and makes the legitimate ones (dedicated driver and
  throttle frames) state their reason inline. All 15 existing sites now name their sole
  owner. Documented as CLAUDE.md §9.

## [0.23.1a] - 2026-07-31 — Two silent bugs, both found by tightening a gate

### Fixed
- **The deferred in-combat upgrade prompt never fired.** `bagUpgradePending` was declared
  `local` 3,500 lines below the event handler that reads it, so that handler saw a nil global
  instead. Finding an upgrade mid-fight set the flag; leaving combat checked a different
  variable and did nothing. Every in-combat upgrade prompt has been dropped, silently, since
  the feature was written. Declaration moved up beside the other event-handler flags.
- **The minimap pulse and the drag handler both owned the button's single `OnUpdate` slot.**
  Whichever wrote second discarded the other's cleanup: dragging during a pulse left the
  starburst glow visible and the button stuck at up to 1.14x scale until some later pulse
  happened to finish, and a pulse arriving mid-drag stopped the button following the cursor.
  The pulse now runs on the shared animation engine, leaving the drag handler as the only
  writer of that slot.

### Added
- **`Anim.owned(frame, propKey, opts)`** — public form of the engine's owned tween, where
  re-triggering replaces rather than stacks. This is the thing a bare
  `frame:SetScript("OnUpdate", ...)` cannot give you, and it is why the collision above was
  possible at all. Four new harness checks cover it, all mutation-verified.

### Changed
- **`tools/globals.js` pass 1 is now scope-aware.** It treated any `x = ...` as a global
  assignment and whitelisted that name in *every* file — so `ns = ns or {}` in `Valuate.lua`
  (an assignment to a *local*) quietly disabled undefined-global detection for `ns`
  everywhere. `MinimapButton.lua` was shipping without capturing `ns` at all and the gate
  said nothing. Tightening it caught that immediately, and surfaced the `bagUpgradePending`
  bug above, which had been masked the same way.
- `UpgradeArrows` and `UpgradePopup` use the published `ns.ReduceMotion()` accessor rather
  than each re-reading the option.

## [0.23.0a] - 2026-07-31 — A gate that actually runs the code

### Added
- **`tools/animtest.js`** — the first gate that *executes* Valuate rather than reading it.
  It loads `ui/Animations.lua` under fengari against a mocked WoW API and asserts 99 things
  about the running engine. The other five gates all pass on a clamp whose comparison is the
  wrong way round; this one does not.
- Every check in it is **mutation-tested**: the engine was deliberately broken eight ways and
  each break confirmed to fail a named check. Three mutations survived the first draft, and
  the harness was strengthened until none did.

### Changed
- **Cascades now derive their per-item gap** from `Anim.staggerFor(count)`. Five staggered
  reveals had each grown their own hand-tuned number (0.07 / 0.06 / 0.05 / 0.03 / 0.025) —
  all sitting on one curve, because each was really encoding "keep the whole cascade to about
  a third of a second for THIS many items". Written as a formula, a new cascade gets the right
  gap without anyone eyeballing it.
- `Anim.revealIn` replaces four near-identical copies of the same fade-in block. One of the
  four was missing the completion guard the other three had.
- The main window now opens through `Anim.popIn`, like every dialog it opens, instead of
  hand-spelling that animation with its own pair of durations.
- Remaining ad-hoc durations adopted the motion tokens. `MOTION.count` added for number
  roll-ups, which are a readout rather than a state change and want their own timing.

### Fixed
- Corrected a comment that justified the engine's "land exactly on the target" guards with a
  failure mode this driver cannot produce — it clamps progress to 1, and every built-in easing
  returns exactly 1 there. The guards are still worth keeping, but as insurance against a
  *custom* easing that never reaches 1, which the harness now covers. The old reasoning would
  have survived any amount of review; running the code is what disproved it.

## [0.22.5a] - 2026-07-31 — Motion becomes a vocabulary

### Changed
- **Animation timings are now design tokens**, like the colours. Eight different durations had
  accumulated across about a dozen animations, each reasonable alone — but motion that varies
  without meaning reads as slightly off rather than deliberate, the same way mismatched spacing
  does. There are now four, chosen by intent: `instant`, `fast`, `base`, `slow`.
- Button hover in/out were 0.12 and 0.18; both are now `fast`. Asymmetric hover can be
  deliberate, but nothing documented it as such and every other control was symmetric.

## [0.22.4a] - 2026-07-31 — One command to check it works

### Added
- **`/valuate check`** — the answer to "is this actually doing anything?". It runs the
  self-test, then triages the states that *look* broken but are not errors: no active scale,
  no scan has run, a scan that produced nothing, or something that errored earlier.
- The README and in-game help now point at it first.
- `tools/tocsync.js` also checks the README's stated version against the `.toc`, since that
  line had already gone ten releases stale once.

## [0.22.3a] - 2026-07-31 — Close the last frame leak

### Fixed
- **The timer fallback allocated a frame per call.** It only runs on clients without `C_Timer`
  — not this one — but Valuate schedules timers constantly, so it would have leaked steadily
  there. Frames are now pooled and returned on completion *and* on cancellation, which matters
  because scan scheduling cancels far more timers than it lets finish.

## [0.22.2a] - 2026-07-31 — Stop leaking a frame every time you open your character sheet

### Fixed
- **Opening the character sheet allocated a new frame each time.** WoW never frees frames, so
  they accumulated for the whole session — a few hundred over an evening of gear checks. The
  three delayed refreshes now share one reusable timer, which also debounces them.

## [0.22.1a] - 2026-07-31 — Contain the per-frame paths too

### Fixed
- **A failing animation callback would have errored on every frame, forever.** The tween is
  only removed by code that ran *after* the callback, so an error meant it never finished and
  never left the queue. The offending animation is now cancelled and reported once; everything
  else carries on.
- **The automatic junk-cleanup timer is now error-contained.** That is the timer that deletes
  things, so an error part-way through was the last place that should fail quietly.

## [0.22.0a] - 2026-07-31 — Errors stop being silent

### Added
- **Event handlers are now error-contained and report themselves.** Most players run with
  script errors **off** — the default — so a bug in one event branch would silently disable
  part of the addon with nothing to point at. That is the worst failure mode for an addon this
  size, and the one this project has repeatedly paid for.
- Each event reports **once**, so a failure in a constantly-firing branch like `BAG_UPDATE`
  cannot spam your chat.
- **`/valuate errors`** lists anything that has gone wrong this session, and `/valuate selftest`
  now fails if there is anything to list.

## [0.21.2a] - 2026-07-31 — Catch phantom methods in the selftest

### Added
- **`tools/api.js`** fails the build if `/valuate selftest` names a method that does not exist.
  Those names are plain strings, so a typo or an entry left behind by a rename would surface
  in game as `method GetScaelLibrary` — reading like a broken build rather than a bad list.
- Deliberately **not** "every method must be listed": that list is curated to cover the
  load-bearing API, and demanding completeness would produce noise instead of signal.

## [0.21.1a] - 2026-07-31 — Settings snapshot gets buttons

### Added
- **Save For Alts / Load Saved** buttons under Advanced, so the settings snapshot is not
  command-only. Loading asks for confirmation and states that your scales are untouched.
- `/valuate selftest` now also checks the snapshot, restore-defaults and PassLoot-conflict
  methods exist.

## [0.21.0a] - 2026-07-31 — Copy your settings to your other characters

### Added
- **`/valuate settings save` and `/valuate settings load`.** The scale library solved "set it up
  again on every alt" for scales; 48 options had the same problem and nothing solved it. Save a
  snapshot on a configured character, apply it anywhere.
- **Three things are deliberately never copied**, because they describe the character rather
  than your preferences: the window position, this character's professions, and the
  character-window scale (which names a scale the target may not have).

## [0.20.4a] - 2026-07-31 — Ask why about any item

### Added
- **`/valuate why [itemlink]`** explains everything Valuate thinks of an item: whether it would
  roll Need and why, whether it gets a **green arrow** and why not, and whether it is classed as
  junk (so auto-sell and auto-delete could act on it).
- **Upgrade arrows were the one automated decision with no diagnostic.** Since they became
  spec-only and cached, "no arrow" has several possible causes that look identical — arrows off,
  no active scale, or simply not an upgrade for the spec you are currently on.
- `/valuate rollcheck` still works; `why` is just the honest name now that it covers more than
  rolls.

## [0.20.3a] - 2026-07-31 — The minimap button tells you something

### Added
- **The minimap tooltip now shows status**: your current spec and its colour, what your gear
  scores, and how many upgrades are waiting — including any sitting in your bank. It previously
  only said "Click to open" and "Drag to move".
- All of it is guarded, so if anything cannot be worked out the tooltip says "Status
  unavailable" rather than erroring on every pass of your mouse.

## [0.20.2a] - 2026-07-31 — Warn when PassLoot is rolling too

### Added
- **Valuate now tells you when PassLoot is also rolling on your loot.** The Valuate-PassLoot
  module registers a *rule* that PassLoot acts on — it does not roll itself — so with Valuate's
  own auto-roll enabled as well, two addons act on the same roll and can disagree. Which one
  lands is a race.
- Shown in both `/valuate roll` and `/valuate report`, next to what is armed. It is deliberately
  **not** arbitrated: there is no way to know which you meant, and silently overriding the other
  addon would be worse than saying so.

## [0.20.1a] - 2026-07-31 — The report knows about everything again

### Fixed
- **`/valuate report` was omitting features that were switched on.** Its list of armed
  automation was hardcoded and predated the upgrade arrows, bank scanning, recipe and material
  rolling, alert options and the cleanup timer — so the one command meant to answer "what will
  this do?" was quietly incomplete.
- Sub-options now read under their parent — `roll on loot (+recipes, +materials)` — rather than
  as a flat wall of toggles.
- It also reports **AdiBags surplus-gear marking** when that is on. It lives in the AdiBags
  module's own settings but feeds Valuate's auto-delete, so running both should not be
  something you discover the hard way.

## [0.20.0a] - 2026-07-31 — Restore default settings

### Added
- **A "Restore Default Settings" button**, under Advanced. There are now 48 options, and the
  only way back to a known state was deleting saved variables — which also takes your scales.
- **It only touches options.** Your scales, the scale library, best-equipment data and the bank
  snapshot are left alone, and the confirmation says so.
- Also available as `Valuate:RestoreDefaultOptions()`, which reports how many settings changed.

## [0.19.7a] - 2026-07-31 — The rest of the per-icon work stops repeating

### Fixed
- **Surplus-gear junk marking recomputed everything per bag icon, per repaint** — an item
  lookup plus three scale-walking checks, with no cache. It is now remembered per item and
  cleared alongside the data it derives from.
- **Junk classification re-resolved AdiBags on every call**, two library lookups deep, for an
  answer that cannot change once found. Now resolved once.
- Together with the arrow fix in 0.19.6a, the three things AdiBags asks Valuate about for every
  visible icon are all cached and invalidated on change rather than on a timer.

## [0.19.6a] - 2026-07-31 — Upgrade arrows stop recomputing constantly

### Fixed
- **The upgrade-arrow cache was thrown away on every scan.** That was harmless when scans were
  rare, but Auto Scan on "Always" now runs about once a second while looting — so every visible
  bag icon was rebuilding a tooltip and re-checking scales on every repaint, for a baseline
  that had not actually moved.
- It now clears only when the answers could have changed: your equipped gear, your current
  spec, or your stat weights. A scan that finds nothing new invalidates nothing.

## [0.19.5a] - 2026-07-31 — Instructions catch up with the addon

### Fixed
- **The Instructions tab was telling you something untrue.** It still said stat weights "won't
  save automatically" and to press Enter — that stopped being true in 0.13.1a, when clicking
  away started committing too.

### Added
- Two new Instructions sections: **Finding Upgrades** (arrows, the popup, bank items, future
  upgrades) and **Automation** (auto-roll, delete/sell, quests, and the commands that explain
  why something did nothing).
- The **Scale Library** is documented under Per-Character Profiles, where the problem it solves
  is described.

## [0.19.4a] - 2026-07-31 — Selftest covers the recent work

### Added
- **`/valuate selftest` now checks the newer features**: the scale library holds tags rather
  than scale tables, profession overrides are keyed by name, and every Valuate window that has
  been created is registered for Escape.
- The Escape check only asserts on windows that **actually exist yet** — they are all created
  lazily, so asserting on all of them would fail on a fresh login for windows you simply have
  not opened.

## [0.19.3a] - 2026-07-31 — Profile what actually runs per bag icon

### Added
- **`/valuate profile` now measures the per-bag-item paths** — the upgrade-arrow check (cached
  and cold) and junk classification. These are the costs that scale with bag size: AdiBags
  calls into both for every visible icon on every repaint, so a millisecond there is multiplied
  by a bagful. The profiler previously only measured the scan, scoring and tooltip parsing.
- The **cold** arrow figure matters separately: a scan clears the cache, so the next repaint
  pays full price for every item at once.
- Library rows cascade in when the window opens, matching the reveals elsewhere.

## [0.19.2a] - 2026-07-31 — Scale library gets a window

### Added
- **A "Scale Library" button** under the scale list, opening a proper window: every saved scale
  listed with **Load** and **Delete**, plus **Save Current Scale**. The slash commands still
  work, but a feature this useful should not live only in chat.
- Deleting asks for confirmation, and says plainly that scales already on your characters are
  unaffected.

## [0.19.1a] - 2026-07-31 — Scale library shared across characters

### Added
- **A scale library shared by all your characters.** Scales are saved per character, so every
  new one started empty and the only way to move a scale was to export a tag, keep it
  somewhere, and paste it back. Save once, load anywhere:
  - `/valuate library` — list what is stored
  - `/valuate library save <scale>` — put this character's scale in the library
  - `/valuate library load <name>` — copy it onto this character
  - `/valuate library delete <name>`
- It stores the same **scale tags** the export box produces, so the library can never drift
  from what pasting a tag does, and there is no second format to keep in step.

## [0.19.0a] - 2026-07-31 — Equip just the item the popup is showing you

### Added
- **Click the upgrade popup's icon to equip only that item.** The Equip button takes the whole
  set, which is the wrong granularity when you only want the one thing the popup is telling you
  about — and it was the only option until now.
- The icon lifts slightly on hover so it reads as clickable, and the tooltip says what a click
  does.
- Blocked in combat with a message, the same guard Equip All uses, rather than a click that
  silently does nothing.

## [0.18.5a] - 2026-07-31 — One entrance for every window; the score rolls

### Changed
- **Every popup now arrives the same way.** The icon, template and class-spec pickers were
  appearing instantly; the upgrade popup and confirm dialog each had their own timings. All
  five now share one entrance — fade plus a small spring — so the addon feels like one thing.
- The confirm dialog uses a **shallower** overshoot on purpose: it often asks about something
  destructive, and a bouncy arrival is the wrong tone for "delete these 12 items?".
- **The character-sheet score now rolls to its new value** instead of silently becoming a
  different number. Equipping something makes the change visible, which is the interesting part.

## [0.18.4a] - 2026-07-31 — Escape closes Valuate windows

### Added
- **Escape now closes the Valuate window**, the same way it closes Blizzard's panels — along
  with the icon, template and class-spec pickers, the upgrade popup, and the confirm dialog.
  Import/Export already did this; now everything is consistent.
- Registration goes through one guarded helper, so a frame cannot be added twice to the list
  Blizzard walks on every Escape press.

## [0.18.3a] - 2026-07-31 — Scale editor feedback and reveal

### Added
- **Committing a stat weight now flashes the input.** Until recently, clicking away from a
  field silently discarded the edit and the box looked identical either way — so "saved" now
  has a visible tell, which matters more here than anywhere else in the UI.
- **The stat grid fades in when you switch scales**, so ~60 rows arrive as a change rather than
  one wall of numbers instantly replacing another.

## [0.18.2a] - 2026-07-31 — Settings reveal, scale list transitions

### Changed
- **The Settings tab now reveals in a stagger**, column by column, the same flourish the Best
  Equipment tab uses — so the two read as one product rather than one animated tab and one
  static one.
- **The scale list fades instead of snapping.** Hover, selection, and the previously-selected
  row all transition, so picking a scale reads as a handoff between two rows rather than two
  separate pops.
- Both honour **Reduce Motion**, which the animation helpers apply themselves.

## [0.18.1a] - 2026-07-31 — Settings page organised

### Changed
- **Column 1 was one header over ~24 controls** — a single wall of checkboxes. It is now six
  labelled sections: Display & Formatting, Scanning, Quests, Loot Rolling, Upgrade Alerts, and
  Vendor & Cleanup.
- **Every section header gained an accent rule**, so the ten sections across all three columns
  read as distinct groups rather than a continuous list.

## [0.18.0a] - 2026-07-31 — Profession overrides

### Added
- **Settings > Professions** — a multi-select list of which professions auto-roll should treat
  as yours. Tick as many as you like.
- Professions read from your skill list show **(detected)** and are always included; you cannot
  untick them, because an override can only add.
- This exists because the skill list returns **nothing** while its headers are collapsed —
  which silently stops every recipe and material from rolling Need, with no other symptom.
  Ticking them by hand makes the feature work regardless.
- `/valuate roll` and `/valuate rollcheck` now mark which professions were detected and which
  you added manually, so a wrong answer points at the right place to fix it.
- Gathering professions are not listed: they have no recipes, and produce materials rather
  than consuming them.

## [0.17.4a] - 2026-07-31 — Don't Need a recipe you already carry

### Changed
- **A recipe you already have a copy of no longer rolls Need.** A second copy teaches you
  nothing, so it should not be taken off someone who could use it. Bank included — a spare in
  the bank is still a spare.
- **A skill requirement you cannot meet yet is still not a blocker** — that was already the
  case and remains so. You train into it, so the recipe is worth winning now.

### Added
- `/valuate rollcheck` now names the exact reason a recipe would not Need: no professions
  detected, wrong profession for this character, already known, or already carried.

## [0.17.3a] - 2026-07-31 — Explain auto-roll decisions

### Added
- **`/valuate rollcheck [itemlink]`** walks the whole decision for an item and says exactly
  where it stops. A recipe that Greeds when you expected Need has four possible causes that
  look identical from outside: the profession list could not be read, the recipe is for a
  profession another character has rather than this one, it is already known, or the client
  never offered Need.
- **The roll message now says when Need was wanted but unavailable.** The client commonly
  disables Need for an item you cannot use yet — exactly the case for a recipe above your
  skill — so a Greed on a learnable recipe no longer looks like the feature failing.

## [0.17.2a] - 2026-07-31 — Junk stops pretending to be new

### Added
- **Junk no longer triggers the new-item highlight.** AdiBags' own "ignore junk" setting only
  covers grey *quality*, so anything junk for another reason — marked surplus, added to the
  Junk list by hand, or flagged by Scrap — still glowed as new and sat in the New section.
- It uses the **same junk classification** as auto-delete and auto-sell, via a new public
  `Valuate:IsItemJunk`, so all three always agree rather than each deciding separately.
- Toggle: **Junk isn't new**, in the AdiBags Valuate filter options. On by default — the hook
  can only ever suppress a highlight.

## [0.17.1a] - 2026-07-31 — Auto-Need profession materials

### Added
- **Auto-roll now Needs crafting materials your professions use** — cloth for Tailoring, herbs
  for Alchemy, metal for Blacksmithing, and so on. Trade goods do not say what they are for,
  so this is driven by a subtype-to-profession mapping.
- **Gathering professions are ignored.** Mining produces ore, so a miner is not short of it —
  listing them would make every miner Need every piece of metal that drops.
- Unmapped subtypes (the generic "Other"/"Materials" buckets) are left alone rather than
  guessed at.
- Toggle: **Need Profession Materials**, under Auto Roll Loot.

### Worth knowing
- Materials drop **far** more often than recipes, so this makes you roll Need on a lot of
  ordinary loot. Some groups consider that poor etiquette. The option says so, and it is one
  click to turn off.

## [0.17.0a] - 2026-07-31 — Auto-Need learnable recipes

### Added
- **Auto-roll now Needs recipes for professions you actually have.** A recipe requiring more
  skill than you currently have still rolls Need — you will train into it, so the usual
  "can you use this right now" test is deliberately not applied.
- Recipes you **already know**, and recipes for professions you **don't have**, are left alone.
- If Need isn't offered (the client often disables it for something you can't use yet), it
  falls back to Greed rather than passing.
- `/valuate roll` now lists the professions it detected. An empty list is the one silent
  failure here — no professions found means no recipe will ever roll Need.
- Toggle: **Need Unlearned Recipes**, under Auto Roll Loot.

## [0.16.1a] - 2026-07-31 — Scans on login

### Added
- **Best-in-slot now refreshes when you log in.** The saved data survives across sessions but
  can be stale — gear arrives by mail, or the last session ended mid-scan — and until
  something happened to trigger a scan, the panel and the upgrade arrows showed whatever was
  true when you logged out.
- It runs **twice**, at 6s and 15s. Right after entering the world the client's item cache is
  cold, so items it has not loaded yet get skipped — a single early scan can quietly produce a
  *worse* result than not scanning. The second pass catches whatever was still loading.
- Runs in every Auto Scan mode except **Off**, which means no automatic scans at all.

## [0.16.0a] - 2026-07-31 — Unique-Equipped respected; tabards no longer scored

### Fixed
- **A Unique-Equipped ring was recommended for both ring slots.** The scan limited an item by
  how many copies you *own*, but uniqueness limits how many you may *wear*. Both the Best
  Equipment panel and the upgrade popup were suggesting gear the game will not let you equip.
- Uniqueness is not exposed by the item API on this client, so it is read from the tooltip.
  Three forms exist, and the one in play here — `Unique-Equipped: Protector's Band (1)` — is
  the one other addons miss, because they match the plain `Unique-Equipped` string exactly.
- The limit is now applied in three places: best-in-slot assignment, the dual-wield off-hand
  pick (owning two copies of a unique one-hander still only lets you wield one), and the
  future-upgrade list.
- **Tabards and shirts are no longer scored.** They can never carry stats, so the number was
  meaningless. This is independent of the profession-tools option.

## [0.15.3a] - 2026-07-31 — Item names were secretly item links

### Fixed
- **Item names were being stored as full item links.** `GetItemInfo` returns *name, link, …*
  and the scan kept the second value, so every saved "name" was a link. That is why the
  upgrade popup showed a bracketed blue `[Sentinel's Medallion]` and ran out of room — links
  are much longer than names, and they carry their own colour, so any colour the display
  applied was silently ignored.
- Fixing it at the source also corrects three other places that were wrapping a link in a
  colour code that could never take effect: the Best Equipment future-item row, its weapon-set
  tooltip, and the character-window line.
- **The upgrade popup got wider (300 → 356)** and the item now has its own line, so a long
  name no longer competes with the score and spec for space. If one still would not fit it is
  trimmed with an ellipsis instead of being cut off mid-word.

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

