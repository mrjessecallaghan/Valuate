# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.116.0a] - 2026-08-14 — FIXED: the template picker never offered CoA classes (or Death Knight)

### Fixed
**Reported from the game: "CoA templates are not available in selecting template."** Correct, and
worse than reported.

`ui/Pickers.lua` — the screen whose entire job is choosing a spec — had two independent faults:

1. It localised `ns.CLASS_SPEC_TEMPLATES` **at file load**, so it could only ever see the classic
   set. v0.79.0a switched the *wizard* to `GetTemplateSet()` and never switched this, and a
   constant captured at load cannot be fixed later by changing what `ns` holds.
2. Its class roster was **typed out by hand** — three columns of three:

   ```lua
   local column1Classes = {"Warrior", "Paladin", "Hunter"}
   local column2Classes = {"Rogue", "Priest", "Shaman"}
   local column3Classes = {"Mage", "Warlock", "Druid"}
   ```

   Nine names. So **Death Knight vanished the day it was added to the templates**, and has been
   missing from this screen ever since — a bug that shipped alongside the CoA one and nobody
   reported, because who checks whether a list is complete?

Between them: a picker offering **nine of thirty-one** classic options and **none of CoA's 21**.
All that data built, documented, wizard-matched, and unreachable from the one place you'd look.

The columns are now derived from the template set, so a class that exists in the data appears
by construction. Class matching also accepts the display name *or* the class token — the two
sites that matched a class here each assumed a different one, which is its own latent bug on a
server that may return either.

### Why nothing here caught it
Every gate passed the whole time. They checked the templates existed, that the wizard matched
them, that the data was internally consistent — and **none checked that the picker offers them**.
*"The screen draws"* and *"the screen draws the right things"* are different claims, and only the
first was ever tested.

### Two new gates, and they reproduce the bug
`tools/pickertest.js` (classic) and `tools/pickercoa.js` (CoA). Reverting the fix makes them fail
with exactly the user's report:

```
FAIL  every classic class appears in the picker (missing: Death Knight)
FAIL  every CoA class is offered (missing: Son of Arugal, Tinker, Barbarian, ... Stormbringer)
```

They're **two files** for the reason `wizardroles.js` is separate from `wizarduitest.js`: the
picker builds its frame once and reuses it, so one harness can be a classic character or a CoA
one, never both. Resetting the file-local frame mid-run would be testing something no player can
do — the first draft did exactly that and reported a failure that was an artefact of the test.

53 gates now.

## [0.115.0a] - 2026-08-14 — your best-in-slot, as a real WoW equipment set

### Added
- **`/valuate saveset <name>`** — equips your best gear for the active scale, waits for it to
  actually land, then saves it as a **WoW equipment set**.

Valuate knew what your best gear was; the equipment manager knew how to swap to a set with one
click, a keybind or a macro. Nothing connected them, so "wear my PvP gear" meant opening a panel
and clicking Equip All every time. Now:

```
/valuate pvpscale make      -> Arms (PvP)
/valuate saveset PvP        -> equips it, saves the set
/valuate pvpscale off       -> back to your PvE scale
/valuate saveset PvE        -> and again
```

Two sets, swappable from a keybind, built from scored gear rather than assembled by hand.

### The asynchronous trap this is built around
`SaveEquipmentSet` saves **what you are wearing** — there is no API to write a set from a list —
so this equips first and saves after. And equipping is asynchronous.

**Saving too early would write a set that is part best gear and part whatever hadn't swapped
yet.** Nothing looks wrong at the time. You'd find out a week later when you clicked the set and
got the mix back, with no way to tell what it was supposed to be.

So it polls until what you're wearing **matches what the scale wanted**, and if it never does,
it **refuses and says which slots didn't take** — a level requirement, a locked slot, an item
still in the bank. Refusing is the safe failure here; saving anyway is not.

Bank gear is excluded from that wait: Equip All can't reach it, so waiting for it would mean
waiting forever and never saving anything.

### It asks before overwriting
An existing set with that name is a thing someone built by hand, so it confirms first — through
`Valuate:ShowConfirmDialog`, never `StaticPopup`, which Blizzard recycles and whose taint broke
`CastSpellByName` in this addon once already.

Names are trimmed, so `"Raid "` and `"Raid"` don't become two different sets.

### Gates
`tools/equipsettest.js`, 25 checks — 51 gates, 108 mutations. Five new, including *"a set is
overwritten silently"* and *"your own enchanted copy reads as the wrong item, so the save never
fires"*.

The ambiguity guard fired twice more: once on my own new probe, and once because
`UnmatchedBestSlots` introduced a second `best.source ~= "bank"` and made the **existing**
`upgraderank` mutation point at the wrong function. That's the fifth time it has caught a
mutation whose meaning an unrelated edit changed.

## [0.114.0a] - 2026-08-14 — eight gate claims, violated on purpose

No addon changes. After three gates in a row turned out to check something *adjacent* to what
they claimed, the obvious question was: **how many of the others do?**

### Method
Take each gate's headline sentence, break exactly that, and see whether it notices. Not "does
the gate pass" — it always did — but *"can I violate the claim on the tin without failing it?"*

| gate | claim violated |
|---|---|
| `api` | a selftest-listed method no longer exists |
| `api` | an integration addon calls into Valuate for something that isn't there |
| `tocsync` | a `ui/` module drops out of the `.toc` and stops loading |
| `globals` | a nil global is read — this codebase's worst bug class |
| `contrast` | a text colour stops clearing WCAG AA |
| `speccoverage` | a class loses its templates, so the wizard can never match it |
| `options` | an automation ships defaulted **ON**, breaking the opt-in promise |
| `check` | `StaticPopup` is used again — the frame taint that broke `CastSpellByName` |

**All eight were caught on the first run.** That's the result worth having: the three weak gates
were the exception, not the rule, and the rest of the suite means what it says.

### They live in `mutations.js` now
Structurally these *are* mutations — break something, require a gate to fail — so they went into
the existing manifest rather than becoming a second tool that does the same job. 103 mutations
now, and "I checked this once" became "this is checked every run".

### Two things the mutation runner caught about my own probes
- The AdiBags anchor matched **twice**, so it was refused as ambiguous rather than silently
  breaking the wrong call site. That guard is now four-for-four.
- One probe reaches **across a repo boundary** into `Valuate-AdiBags`. Restoration is verified
  byte-for-byte, and the sibling addon is clean afterwards — checked, not assumed, because a
  half-restored file in a *different* git repo is exactly the mess a tool like this could leave.

## [0.113.1a] - 2026-08-14 — "documented in /valuate help" now means that

No addon changes. Third gate in a row whose check turned out to be weaker than its claim.

### Fixed
- **`commands.js` scanned every `print` in `Valuate.lua`** looking for `/valuate <name>`, then
  reported *"all 62 slash commands are documented in /valuate help"*.

Those aren't the same thing. A command that prints its own usage — `/valuate trivial <levels> ·
0 accepts everything`, printed by `/valuate trivial` itself — **documented itself**. Deleting a
real help line did not fail the gate.

`documented` is now read from the **help branch only**.

### Verified, both directions
Deleting the `/valuate trivial` help line now fails with *"Commands with no line in /valuate
help"*. The real source still passes, so this weakness was **latent** rather than already hiding
an omission — all 62 commands genuinely are in the help text. The mutation makes it permanent.

### The pattern, three for three
- **v0.111.0a** — the settings-snapshot exclusion list had no gate at all. Found `pvpScale`
  travelling to alts.
- **v0.113.0a** — the options gate accepted a *read* as proof an option was *reachable*. Found
  three options nobody could change.
- **v0.113.1a** — the commands gate accepted *any print* as proof a command was *in the help*.

Each check tested something **adjacent to** what it claimed, and each passed cleanly for months.
The tell is the same every time: the claim on the tin is narrow, the implementation is broad,
and broad always passes. Worth re-reading the remaining gates against their own headline
sentences rather than trusting the green.

## [0.113.0a] - 2026-08-14 — the to-do list speaks once, and three options become reachable

### Added
- **A one-line summary at login**, when there's something worth doing:
  `[Valuate] 3 things worth doing - /valuate todo`
- **`/valuate quiet`** — turns Valuate's chat messages and the loaded message off.
- **`/valuate trivial <levels>`** — how far below you a quest must be for auto-accept to skip it.
- `/valuate todonotify` toggles the login line.

`/valuate todo` answers the question, but only if you think to ask — and the point of the list is
that you *shouldn't* have to keep it in your head. It waits for the **second** login scan (the
first runs against a cold item cache, so a list built from it would be confidently short), says
one line, and never speaks again that session.

"Nothing to do" also counts as having spoken. Otherwise a clean character keeps re-checking and
the first thing to appear announces itself mid-dungeon — exactly the interruption this avoids.

### The options gate was passing things it shouldn't
`todoOnLogin` sailed through a gate whose whole job is *"every option is reachable"*, because
reachable meant **"the key is mentioned somewhere outside the defaults"** — which every option
satisfies by definition, since something has to read it. `if options.key == false` counted as a
way to change it.

Reachable now means **something assigns to it**: `options.key =`, a multiple assignment, or a
key declared as data (the Settings panel builds its battleground toggles from a table and
assigns through `GetOptions()[toggle.key]`, which no regex will ever see — the declaration *is*
the control).

### Which immediately found three options nobody could change
- **`chatMessages`** — the verbose-chat switch. Read since it was added, never settable. A
  chatty addon you can't quieten is one you uninstall.
- **`showStartupMessage`** — same.
- **`autoAcceptTrivialBelow`** — a tunable threshold with nothing to tune it.

All three now have commands. Two of them are, in effect, three-word bug reports that were
sitting in plain sight behind a check that looked green.

### Gates
`tools/todotest.js` 24 → 31 checks; 50 gates, 94 mutations. Four new, including *"'nothing to
do' re-checks forever, so the first new item announces itself mid-dungeon"*.

## [0.112.0a] - 2026-08-14 — `/valuate todo`: everything worth doing, in one list

### Added
- **`/valuate todo`** — one command for "what should I do about my gear?"

```
3 things worth doing
  1. Refresh Auto - Str/Crit/Hit/AP/Haste - your gear has moved on from it
      Everything below is scored by this scale, so it is worth doing first.
  2. Equip [Breastplate of Tenacity] in Chest  +48.2
  3. Fill 3 empty sockets
      Stats you have already earned and are not wearing.
  More detail: /valuate wizard  ·  /valuate upgrades  ·  /valuate sockets
```

The addon could already answer all of this — across `/valuate upgrades`, `sockets`, `enchants`
and the scale list's Refresh button. Which means it could only answer it **if you remembered
four places to look**, which is exactly backwards for a thing whose purpose is saving you the
effort.

### The order is the argument
A **stale scale comes first**, because everything under it is scored *by* that scale. Put
upgrades on top and the list confidently tells you to equip things chosen by weights you've
outgrown. Then upgrades (free, immediate), then sockets and enchants (need materials or a
vendor). The scale entry says *why* it's first rather than just being first.

**At most three upgrades.** Seventeen slots is the Best Equipment panel, not an answer to "what
should I do next".

**Empty means empty.** No heading over an empty space, no *"Fill 0 empty sockets"* — a to-do
list that always has something in it is one you stop opening.

### The gate caught a real bug before it shipped
I first wrote the counts as `local _, n = Valuate.FindEmptySockets and Valuate:FindEmptySockets()`.

Lua adjusts an `and` expression to a **single value**, so the second return — the count, which
is the entire point — was silently `nil`, and the socket and enchant items could never appear.
The command would have worked, printed a plausible list, and quietly never mentioned either
one. Both now use an explicit `if`, with the reason written next to them.

### Gates
`tools/todotest.js`, 24 checks — 50 gates, 90 mutations. Five mutations including *"upgrades are
listed above the stale scale that CHOSE them"* and *"the socket count is silently nil"*, which
is the bug above, now permanent.

## [0.111.0a] - 2026-08-14 — the battleground automations appear in Settings, and stop following you to alts

### Added
- **A "Battlegrounds & Dungeons" section in Settings**, with the five automations from
  v0.105–0.106: release on death, leave a finished battleground, take the invite, re-queue for
  PvP, re-queue for a dungeon.

They were **command-only**, which meant the newest and most consequential features in the addon
— the ones that move your character — were invisible to anyone who doesn't read `/valuate help`.
A feature nobody can find is a feature that doesn't exist.

Each tooltip ends with the same pointer: *"/valuate queuecheck says whether this client can
actually do it."* Every one depends on an API Ascension may not have, and saying so on the
control beats finding out when it silently never fires.

### Fixed
- **`pvpScale` was travelling in settings snapshots.** Shipped in v0.109.0a, unnoticed for two
  releases.

`characterWindowScale` is excluded from snapshots for a stated reason — *"names a scale that may
not exist on the target character"* — and `pvpScale` has exactly that problem. Copy your
Warrior's settings to your Necromancer and it would nominate **"Arms (PvP)"**, a scale that
character has never had, then switch to nothing every time it zoned into a battleground. That
looks precisely like the feature being broken.

`pvpScaleRestore` too: it's mid-battleground bookkeeping, and copying it makes an alt "restore"
to a scale it was never using.

### The exclusion list had no gate, which is why
`tools/snapshottest.js`, 21 checks. Five mutations, and the first one **is** the bug: deleting
`pvpScale` from the exclusion list. Two survived the first run, both fixture faults —

- Every table in the fixture was *also* excluded by name, so the "never copy tables" rule was
  never doing any work.
- The excluded keys had `nil` defaults, meaning they were absent from `DEFAULT_OPTIONS`
  entirely — so the loader's *"is this still a real option?"* guard refused them and the
  exclusion check never ran. Two guards, one of them dead.

### A lint rule I chose not to suppress
`settings-anchor-chain` flagged the new section's loop cursor as a shared anchor. It can't see
that the variable is reassigned each pass, so the report was wrong — but the escape hatch would
have blunted a rule that catches a real overlap bug. Instead the loop's cursor and the final
control are named separately, which is also just clearer: one is loop state, the other is one
specific frame. A future second anchor to that frame still gets caught.

### Gates
49 gates, 85 mutations. `settingstest.js` 108 → 123 checks — it drives the real Settings panel,
so the new controls are built and layout-checked by the gate that already existed.

## [0.110.1a] - 2026-08-14 — the gate suite runs in parallel: 198s → 22s

No addon changes. This is the tool a **pre-commit hook** runs, so its wall-clock is a tax on
every change I make.

### Fixed
- **48 gates ran one after another.** Each is a separate node process reading source and running
  fengari; none of them write anything (only `backup.js` and `mutate.js` do, and neither is a
  gate). So on a six-core machine, 47 of every 48 startups were pure queueing.

Measured on this box while it was under load: **198s → 22s**. On an idle one, 16s.

That number is why this was worth doing rather than tolerating. A check that takes three minutes
before every commit is one you start reasoning your way out of running — and a gate you skip is
worth exactly nothing.

### Output stays in list order
Finishing order is whatever the scheduler decides. Results are collected and printed in the
original order, because a pass list that shuffles itself between runs is unreadable — the same
"undefined order is not an order" rule the addon follows for `pairs()`.

### It now names its slowest gates
```
All 48 gates passed in 15.9s (5 at a time; slowest: check.js 4.1s, automatch.js 3.1s, tabtest.js 3.0s).
```
Without this, a gate that has quietly become pathological shows up only as *"the hook feels slow
lately"*. It also settled the question here: nothing was pathological, the slowest was 6.1s, and
the 198 seconds really was 48 startups queueing behind each other.

### Verified the failure path, not just the fast one
A runner that cannot report a failure is worse than no runner. Broke a gate on purpose: the
`===== enchants.js FAILED =====` banner appears, the failing gate's **full output** is preserved
rather than reduced to its last line, and the process exits **1**. The passing gates around it
still report normally.

## [0.110.0a] - 2026-08-14 — `/valuate pvpscale make` builds the scale the last release asked for

### Added
- **`/valuate pvpscale make`** — derives a PvP scale from the one you're using now, and
  nominates it.

v0.109.0a let you nominate a scale for battlegrounds, and shipped a question most people had no
answer to: **you had to already own a PvP scale.** A slot with nothing to put in it.

### The convention is stated, not hidden
Resilience and PvP Power get the same weight as the source scale's **highest-weighted stat** —
the claim being *"surviving is worth as much as your best offensive stat"*. That is a defensible
starting point and definitely **not a fact**. I don't know the right number and neither does any
table I could have copied, so the command prints the convention and the weight it used, and
expects you to tune it:

```
Made Raid (PvP) from Raid, and it will be active in battlegrounds.
  Added ResilienceRating and PVPPower at weight 1.00 - the same as Raid's highest stat.
  That is a convention, not a fact: tune it in the scale editor.
```

Same treatment as the six CoA specs marked *inferred* rather than filled in with plausible
weights.

### The mechanics are what had to be right
- **Copied, never shared.** Editing the derived scale must not silently edit its source.
- **Never overwrites.** Run it twice and you get `Raid (PvP 2)`, not a destroyed scale you'd
  already tuned. This command has no business deleting anything.
- **A weight you set yourself wins.** If the source already weights Resilience, that's a
  deliberate choice worth more than my convention, and it's left alone.
- **The source's real top weight**, not an assumed 1.0 — a scale topping out at 0.5 gets PvP
  stats at 0.5.
- **Refusals name themselves**: unknown scale, no weights, or all-zero weights, rather than
  producing a scale that scores nothing.

### The ambiguity check earned its keep again
`if top <= 0 then` exists twice in `Valuate.lua`, so the mutation was refused as ambiguous
rather than silently breaking the other one and reporting SURVIVED. That guard is three
releases old and has now caught two real cases.

### Gates
`tools/queuetest.js` 80 → 102 checks; 80 mutations, all caught.

## [0.109.0a] - 2026-08-14 — one scale in battlegrounds, yours everywhere else

### Added
- **`/valuate pvpscale <name>`** — nominate a scale for battlegrounds. It becomes active when
  you zone in, and the one you were using comes back when you leave.

Resilience, PvP Power and a chunk of stamina are worth a great deal in a battleground and close
to nothing in a dungeon, so *"what is my best chest"* has **two correct answers** depending on
where you're standing. Until now the addon gave you one of them everywhere — which, if you're
grinding battlegrounds, is the wrong one for most of your evening.

Everything downstream follows: upgrade arrows, best-in-slot, `/valuate upgrades`, junk marking.

### The restore is the risky half
Switching is easy. Getting you *back* is where this could quietly leave you scoring dungeon gear
against a PvP scale for days, so:

- **The restore target is persisted, not held in memory.** Reloading — or crashing — inside a
  battleground would otherwise strand you with no record of what you were using. Saved, it
  restores on the next zone out however you got there.
- **Re-entry never overwrites it.** The events driving this fire repeatedly, and a second switch
  would set the restore target to the PvP scale itself. That one is permanent damage from a
  one-line mistake, and it has a mutation.
- **"No scale before" is a real state** and comes back as no scale, rather than quietly
  promoting the PvP one to your default.
- **Deleted scales are refused, both directions**, and say so. Switching to a scale that isn't
  there would make every score read zero.
- **`/valuate pvpscale off` honours a pending restore first**, or switching it off inside a
  battleground would strand you on the PvP scale permanently.

Announced both ways. Silently changing which scale drives your arrows and your junk marking is
indistinguishable from the addon breaking.

### A gate caught me telling you to run a command I hadn't written
The "that scale no longer exists" message pointed at `/valuate pvpscale` before the command
existed. `commands.js` refused the build: *"These are printed to someone who is already stuck.
They will type exactly what they were told, get 'unknown command', and conclude something worse
is wrong."*

### Gates
`tools/queuetest.js` 58 → 80 checks; 75 mutations, all caught.

## [0.108.0a] - 2026-08-14 — the three automations that move your character get checks

### Added
Three `/valuate verify` entries, 35 → 38, for v0.105–0.106's queue work. These are the only
features here that **act in the world** rather than reporting on it, and they're the least
verified code in the addon.

- **`bgaccept`** — the pop is taken out of combat, and pointedly *not* taken in combat.
- **`bgleave`** — the 8-second pause is readable, and switching the option off *during* the
  countdown actually cancels it.
- **`autorelease`** — releases in the open world, refuses in a party instance.

Each one's decision logic is gate-tested. What no gate can reach is whether
`AcceptBattlefieldPort`, `LeaveBattlefield` and `IsInInstance` **exist and behave** the way I've
assumed on a modified client — and if they don't, the check fails for that reason, which is the
answer rather than a bug. `bgaccept` says so explicitly and points at `/valuate queuecheck` first.

### The one that matters most
`autorelease`'s refusal *is* its design. Releasing while a healer is casting on you throws the
resurrection away, and it's deliberately not configurable. But the guard depends on
`IsInInstance()` reporting party and raid instances the way I expect — and if Ascension doesn't,
the guard can't fire and this becomes an automation that quietly costs you battle rezzes. That's
worth one death in a dungeon to find out.

### On the gate that prompted this
Same as v0.102.0a: `verifytest` was five releases from failing, and I'd shipped three features
that move your character without adding a single check for any of them. Lag is 0 again.

## [0.107.0a] - 2026-08-14 — self-verify catches a toggle your client can't honour

### Added
- **`/valuate selfverify` gains a `canrun` check**: for every queue, release and leave
  automation you have **switched on**, does this client actually provide the APIs it needs?

`/valuate queuecheck` already answered this — but only if you thought to ask, and the moment
you'd think to ask is *after* it has already failed to do something. A toggle that's on but
can't fire looks exactly like one that simply hasn't had a reason to yet.

```
FAIL  Automations you switched on can actually run here
      Switched ON but cannot work on this client - Auto-queue PvP needs JoinBattlefield().
      The toggle will sit there looking armed and never fire.
```

### Silent unless it matters
**Nothing switched on → SKIP**, not a pass. A warning about features you aren't using is noise,
and noise is how a list stops being read — the same reasoning behind keeping the near-miss line
inside 10% and leaving ring enchants out of `/valuate enchants`.

An API missing for a feature you never enabled is **not your problem** and isn't reported.

### Why this one can only live here
Whether a toggle and a capability agree depends entirely on which functions *your* client
defines. No gate can see it: every headless test defines whatever mocks it needs. Five self-checks
now, and two of them — this and `agreement` — can find a **new** problem rather than confirm a
known assumption.

### Gates
`tools/selfverify.js` 39 → 48 checks; 71 mutations, all caught. Four new, including *"features
you never switched on are reported as broken"* and *"only the first API a feature needs is
checked"*.

## [0.106.0a] - 2026-08-14 — take the invite, and notice when you missed one

### Added
- **`/valuate autoacceptbg`** — takes the battleground port the moment a queue pops.
- **Re-queue after a missed pop.** If the invite lapses while you're away, `autoqueuepvp` puts
  you straight back in.

v0.105.0a's auto-queue was half a feature. The queue popped and you still had to be at the
keyboard to click **Enter Battle** — and if you missed it, the client drops you from the queue
silently. You find out ten minutes later that you've been standing in a city.

### Accepting is its own opt-in
`autoqueuepvp` does **not** turn it on. Being yanked out of a quest into Alterac Valley is
exactly the kind of surprise an addon should make you ask for, and wanting to keep questing
until *you* choose to go is a perfectly reasonable position. Switching it on says as much.

**Never in combat.** `AcceptBattlefieldPort` is refused mid-fight on some clients, and porting
out of a fight you're winning is its own kind of rude. The popup stays up, so nothing is lost —
you get it back when you're out, and `/valuate report` says that's why.

### The missed pop needs memory
From a standing start, *"still queued"* and *"dropped ten minutes ago"* look identical — both
are just a slot reading `none`. Only the **previous** status makes it detectable, so it's
remembered per queue slot. Two distinctions that had to be right:

- `confirm → none` is a **lapsed** pop, and re-queues.
- `confirm → active` is **you entering the battleground**, the opposite, and must not.

A slot seen for the first time never re-queues either — there's no previous status to compare
against, and firing on that would queue you the moment you log in.

### Gates
`tools/queuetest.js` 44 → 58 checks; 67 mutations, all caught. Five new ones, including *"ports
you into a battleground mid-fight"*, *"entering the battleground is mistaken for missing the
pop"*, and *"the previous status is never remembered, so a missed pop is undetectable"*.

Also repaired the README: v0.105.0a's note landed **inside** the automation table and orphaned
the last row.

## [0.105.0a] - 2026-08-14 — auto-queue, auto-release, auto-leave

### Added
Four automations for the loop that is mostly clicking: **queue → play → it ends → leave →
queue again.** All **off by default**, like every other automation here.

| command | what it does |
|---|---|
| `/valuate autorelease` | Releases your spirit on death |
| `/valuate autoleavebg` | Leaves a battleground once it has finished |
| `/valuate autoqueuepvp` | Re-queues for a random battleground after you leave one |
| `/valuate autoqueuedungeon` | Re-queues for a random dungeon after one finishes |
| `/valuate queuepvp` · `queuedungeon` | Queue right now, once |
| `/valuate queuecheck` | What's armed, and **which of these APIs your client actually has** |

### Three deliberate refusals
- **Auto-release will not fire while you're dead in a party or raid instance with other
  people.** Someone is very likely mid battle-rez, and releasing throws it away. Not
  configurable — "release even though my healer is casting on me" isn't a preference anyone
  holds on purpose. In the open world or a battleground it releases normally.
- **Leaving waits 8 seconds** and says so. The scoreboard is the only record of the match, and
  ripping it away instantly is worse than the clicking this replaces. The option is **re-read
  when the timer fires**, so switching it off during the countdown cancels the leave rather
  than carrying out a decision you've since reversed.
- **Re-queueing happens only after you've left.** Queueing from inside a match would either be
  refused or drop you into a second one.

### The unusual risk here
Everything else in this addon *reports*; these four *act*, and each calls an API Ascension may
have changed or removed. So every capability is **detected before use** and every refusal
**names the exact API it couldn't find** — `/valuate queuecheck` lists all eight without
touching anything. A toggle that's on but says `no` next to `JoinBattlefield` cannot work,
whatever the toggle says, and now you can see that in one command instead of inferring it from
silence.

The random battleground is found by its **isRandom flag**, not its name or position, so it
survives localisation and whatever Ascension calls it.

### Gates
`tools/queuetest.js`, 44 checks — 48 gates, 62 mutations. Seven mutations, and one **survived**:
I'd tested that a missing `JoinBattlefield` names itself but never that a missing
`GetBattlegroundInfo` does — one unnamed API is enough to reproduce the exact "nothing happened
and I can't tell why" this design exists to prevent.

**Untested in-game, and more consequential than usual** — these are the first features here that
can take an action in the world. Run `/valuate queuecheck` before trusting any of them.

## [0.104.0a] - 2026-08-14 — unenchanted gear, the other half of "stats you already earned"

### Added
- **`/valuate enchants`** — gear you're wearing with no enchant on it. The count also joins the
  socket line at the foot of `/valuate upgrades`.

v0.103.0a covered empty sockets; this is the same idea from the other side. Both are stats you
have already earned and aren't wearing, and both are invisible unless you go looking.

Cheaper than sockets, too: an item link is `|Hitem:ID:ENCHANT:...`, so this reads **field two**
and never touches a tooltip.

### Conservative on purpose
Only the nine slots that plainly take an enchant on any character: head, shoulder, back, chest,
wrist, hands, legs, feet, main hand. **Rings need Enchanting**, an off-hand only takes one if
it's a shield or holdable, and ranged wants a scope. Reporting those would nag most players about
something they can't act on — which is exactly how a useful list becomes one you stop reading,
the same reasoning that keeps the near-miss line inside 10%.

The footer names which slots were checked, rather than implying the list is exhaustive. Ascension
may differ again.

### "Can't read it" is not "unenchanted"
Only an explicit **zero** counts. A link that fails to parse returns nil, and nil is left alone —
the two look identical in a list and lead to completely different actions: one is a trip to an
enchanter, the other is a bug in the addon.

### Gates
`tools/enchants.js`, 16 checks — 47 gates, 55 mutations, all caught first time. The mutation that
matters most reads **field one** instead of field two: an item ID is never zero, so the command
would silently report "everything's enchanted" forever while checking nothing.

## [0.103.1a] - 2026-08-14 — mutations can no longer silently point at the wrong code

No addon behaviour changes. This fixes the tool that checks the other 46 gates are worth
anything.

### Fixed
- **`tools/mutate.js` now refuses an ambiguous anchor.** `String.replace` takes the *first*
  match, so a `from` string occurring twice silently mutates whichever copy comes first. Add a
  new function above the intended one and a mutation that has been passing for releases quietly
  starts breaking code its gate never runs — and reports **SURVIVED**, which reads as "your
  assertion is weak" when the truth is "this test moved house".

That is not hypothetical. It happened twice in v0.103.0a: to `return a.slotId < b.slotId` the
moment `FindEmptySockets` landed above `RankAvailableUpgrades`, and to
`for i = 2, tooltip:NumLines() do`, which `TooltipUniqueLimit` has owned all along. I fixed both
by hand and shipped, which fixed the instances and left the mechanism.

An anchor must now identify **exactly one** site. If it doesn't, the run stops and names the
count, demanding a `scope` instead of picking one and hoping.

### It found a scope that was never scoping
First run, immediately: the `NEARMISS` scope ended at a **shared comment** rather than the next
function, so it spanned **420 lines and three functions**. It had been scoping nothing since the
day I wrote it — its mutations were landing correctly only because `BuildNearMissLine` happened
to come first. Now ended at the next function header.

### Verified both directions
An anchor with 7 occurrences is refused with a non-zero exit; the same anchor with a scope
resolves to one site and runs normally. Exercised, not assumed — the same standard the baseline
guard got in v0.99.0a, and for the same reason: a checking tool that cannot fail is decoration.

51 mutations, 46 gates, all passing — and now for reasons I can believe.

## [0.103.0a] - 2026-08-14 — empty gem sockets: stats you already earned and aren't wearing

### Added
- **`/valuate sockets`** — every empty socket on gear you're wearing, most first.
- The count also appears at the foot of **`/valuate upgrades`**, because that's the moment
  you're already thinking about gear and an empty socket is a gain you *already own*.

An unfilled socket is invisible unless you go looking, and stays that way for whole levelling
stretches. Cheapest gain in the game, easiest to forget.

### Counted, never valued
Working out what a socket is *worth* means guessing which gem you'd put in it, and an invented
number would flow straight into item scores and back out as confident nonsense. So it reports
"this many, here" and says so. Same call as CoA's six missing stat priorities, which are marked
inferred rather than filled in with plausible weights.

### The whole feature is one distinction
An **empty** socket draws a line beginning with the socket's name; a **filled** one draws the
gem's own text. Matching is anchored at the start of the line — a search-anywhere match would
count sockets you'd already gemmed, the number would never reach zero, and you'd stop believing
it. Read from the client's own `EMPTY_SOCKET_*` globals with English fallbacks, the way
`TooltipUniqueLimit` already reads `ITEM_UNIQUE_EQUIPPABLE`.

### Two fixture faults, one of them retroactive
`tools/sockets.js`, 34 checks. Four mutations; **two survived** the first run and both were mine:

- The name-line mutation landed in **`TooltipUniqueLimit`**, which shares the line
  `for i = 2, tooltip:NumLines() do` and sits earlier in the file — so it broke a function this
  gate never runs. Now scoped.
- The tiebreak test used **Head and Legs**, which are already in slot order, so the tiebreak was
  never doing any work. `ns.EQUIP_SLOTS` reads like a character sheet, so **Back (15) is visited
  before Chest (5)** — that pair is the only thing that separates *sorted by slot* from *left in
  the order we found them*.

The second fault turned out to exist in **`upgraderank.js` too**: its tie test used Ring 1 and
Ring 2, equally in-order, and adding `FindEmptySockets` earlier in the file silently redirected
its unscoped mutation into the wrong function. Both fixed. A mutation that has been passing for
four releases was proving nothing.

51 mutations, 46 gates.

## [0.102.0a] - 2026-08-14 — the checklist catches up with what shipped

### Added
Three `/valuate verify` checks, 32 → 35. I had declined to add any for five releases on the
grounds that they would pad a list I'd just spent a release making honest. The `verifytest` gate
was eight releases from failing and, on re-reading, it was right and I was wrong: each of these
rests on something **only the client can answer**.

- **`altdetail`** — v0.98.0a's Alt-hover block. The verdicts inside it are gate-tested; whether
  it *draws* is not, and it rests on an assumption nothing headless can reach: that
  `IsAltKeyDown()` reports the truth while a tooltip is being built. If it doesn't, the block
  either never appears or never goes away — and a tooltip that keeps growing is worse than one
  that says nothing.
- **`nearmiss`** — v0.96.0a's near-miss line. The threshold and the exclusivity are gate-tested;
  what a real tooltip looks like carrying it is not. The failure to watch for is it appearing on
  **everything**.
- **`upgradelist`** — v0.99.0a's ranked list. The ranking, bank exclusion and tiebreak are
  gate-tested; whether an item link rebuilt from stored scan data still **renders as a link** is
  not. A stale or malformed one prints as raw text and cannot be clicked.

### Two of them arm themselves
`nearmiss` searches your bags for an item that should carry the line and prints it, so the check
hands you the item instead of asking you to go find one. `upgradelist` runs the command — through
the **real slash handler**, so it exercises the printer a user sees rather than a second copy
written for the check.

### On the gate that forced this
`verifytest` fails when the newest check falls more than ten minor releases behind the `.toc`,
with no escape hatch, on the reasoning that *shipping ten releases with nothing a human should
look at is itself worth being told*. I wrote that in v0.90.0a and then spent five releases
explaining why the growing gap was fine. It wasn't. The lag is 0 again.

## [0.101.0a] - 2026-08-14 — the check that would have caught v0.94.0a, in your client

### Added
- **`/valuate selfverify` gains an `agreement` check.** Two independent code paths score the
  same equipped item; they must land on the same number.

v0.94.0a was two pieces of code reading one item's stats from different sources and subtracting
the results. **All 43 gates passed on it.** They always will: a fixture hands both sides the same
numbers, so nothing headless can notice that production fetches them two different ways. Only the
client can.

```
GetEquippedItemScoreBySlotId   slot -> SetInventoryItem -> parse -> score
GetScaledStatsForItem          link -> find on your person -> shared reader -> parse -> score
```

Same item, same scale, two routes. If they diverge by more than 1%, every delta built on
them — upgrade arrows, the ranked list, the near-miss line, the Alt breakdown — is fiction, and
the check names the slot and both numbers so you can check it by hand rather than take its word.

### Two live reads, not live-versus-stored
Comparing against the stored scan would flag every level-up: scaled values legitimately move, the
scan hasn't rerun, and a check that cries wolf after every ding teaches you to ignore it. Both
sides are read *now*.

An item where the second route can only reach **base** stats is skipped rather than compared —
comparing base against scaled would report exactly the mismatch this check hunts, on an item
where it is expected and harmless. A false alarm here would be worse than no check, because it
would train you past a real one.

### Gates
`tools/selfverify.js` 28 → 39 checks; 47 mutations. All three new mutations caught, including
the false-alarm one.

Four self-checks now, and this is the first that can find a **new** bug rather than confirm a
known assumption — the other three ask whether the client matches what I assumed; this one asks
whether the addon agrees with itself.

## [0.100.0a] - 2026-08-14 — `/valuate selfverify`: the checks the addon can judge on its own

### Added
- **`/valuate selfverify`** — one command, three real answers from inside the client.

`/valuate verify` holds 32 behavioural checks and every one costs a human: read the steps, do
the thing, decide whether what you saw was right. Some of them never needed eyes — they needed
a **fact from the client** that no headless gate can reach, and the addon can compare that fact
against what it assumed all by itself.

| check | what it settles |
|---|---|
| **templates** | Does `UnitClass("player")` return a name that appears in a template set? This is the single assumption all **21 CoA classes and 70 builds** rest on. If it doesn't, `GetTemplateSet` silently falls back to the classic ten, nothing errors, and the wizard proposes an Arms Warrior build to a Necromancer. |
| **newstats** | Mastery, Versatility and Leech aren't stock 3.3.5 stats, so their tooltip **wording was guessed** back in v0.72.0a. This finds an item you actually own that mentions one, then checks the parser got a number out of it. Reading the same tooltip twice — once as text, once through the parser — is the only way to tell *"no such item"* from *"did not parse"*. |
| **caches** | Are v0.91–0.92's repaint savings real on your machine, or is the cache being dropped as fast as it fills? |

### A SKIP is not a PASS
Said out loud in the output, because the difference is the whole point. *"Nothing you own
carries Mastery"* must never read as *"Mastery parsing works"* — that assumption has gone
untested since it shipped, and reporting it green would be worse than reporting nothing.

A check that returns **nothing at all** counts as a **failure**, for the same reason: a
subsystem that cannot even be asked has not passed.

### Gates
`tools/selfverify.js`, 28 checks — 45 gates, 44 mutations now. Six mutations, and one
**survived**: every check in my fixture always returned a status, so the fallback for one that
returns nothing was never exercised, and making it default to `"pass"` changed nothing. The
fixture now includes a check that answers with silence.

Seventh fixture problem this session; third found by the committed tool. The pattern is stable
enough to state plainly: **my test worlds are consistently tidier than the game**, and mutation
testing is the only thing that has reliably said so.

### Still not v1.0.0
The roadmap gates 1.0.0 on in-game verification, and nothing here has run in the client. This
release makes that verification cheaper — it does not perform it.

## [0.99.0a] - 2026-08-14 — one command for "what should I put on right now"

### Added
- **`/valuate upgrades`** — your biggest gains, ranked, that you can act on immediately.

```
Biggest upgrades you can put on right now (Auto - Str/Crit/Hit/AP/Haste)
  1. +48.2  Chest  [Breastplate of Tenacity]
  2. +31.0  Neck   [Pendant of the Vanquished]  (slot is empty)
  3. +12.4  Ring 2 [Signet of the Kirin Tor]
  ...and 2 more. /valuate equip puts the whole set on.
```

The Best Equipment panel already answers this — across seventeen rows, with the arithmetic left
to you. When you have five minutes before an invite, the useful form is one ranked list.

**Two exclusions, both so every line is something you can do now.** Bank gear is out: Equip All
cannot reach it, so offering it as "your next upgrade" is advice that needs a trip across the
city first. Gear you are already wearing is out — including when the recorded and live scores
have drifted apart, which they do on a scaling realm, and which would otherwise produce
*"+2.0 — equip the chestpiece you already have on"*.

Ties break on slot id. Rings and trinkets tie constantly, `table.sort` is not stable, and without
a unique second key "your biggest upgrade" changes identity between runs while your gear does not.

### Removed a duplicate rather than adding a third
`ui/BestEquipment.lua` and `ui/CharacterWindow.lua` each carried a **byte-identical** 17-entry
slot table. This feature needed the same list, and a third copy is how two panels end up
disagreeing about whether Ranged is a slot. There is now one, `ns.EQUIP_SLOTS`, and both panels
read it.

### The mutation runner could report a green run while testing nothing
A stray backtick in the new gate's Lua block made it a **syntax error** — so it failed on every
mutation, and `mutate.js` reported all six as *caught*. A gate that is already broken confirms
everything.

It now establishes a baseline first: every gate involved must pass on untouched source, or the
run refuses to start and says which one is broken. Verified by breaking a gate on purpose.

### Gates
`tools/upgraderank.js`, 34 checks — 44 gates now. Six mutations, and one **survived**: my fixture
gave the already-worn item an identical score, so the `gain > 0` filter masked the identity check
entirely. Sixth fixture problem this session, and the second found by the committed tool.

## [0.98.0a] - 2026-08-14 — hold Alt over an item for the whole answer

### Added
- **Alt-hover breakdown on tooltips.** Hold **Alt** while hovering any item for the full
  best-in-slot picture, one line per scale — the same answer `/valuate why` gives, without
  shift-clicking the item into chat and typing a command around the link.

```
Best-in-slot, every scale
  Dps    412.0  -38.0 vs your best
  Tank   180.0  +22.0 - rescan to pick it up
  Healer nothing this scale wants
```

The summary lines answer *should I care*. This answers *why*, which is a question you ask about
one item in fifty — so it costs a keypress rather than permanent tooltip space.

**Alt, not Shift.** Shift is the client's own compare-tooltip modifier and is how you link an
item into chat; taking it over would break two things people already use.

`/valuate detail` toggles it off.

### One honest limitation
3.3.5 does not redraw a tooltip when a modifier changes. The options were an `OnUpdate` polling
for a keypress on every frame — for a line most hovers do not want — or nothing. It is nothing:
**hold Alt before you hover**, or move off and back. The command says so when you enable it.

### A bad assertion, found by the tool from the last release
`node tools/mutate.js` reported a survivor immediately: deleting the "this is your best" line
entirely changed nothing.

Two faults, one hiding the other. The fixture pointed both scales at the *incumbent* item, so no
line in the whole block ever took the `best` branch. And the assertion meant to check it searched
for the word **"best"** — which also appears in `"-38.0 vs your best"`, the line for a scale the
item **lost**. It passed on output meaning the exact opposite of what it claimed to verify.

Now matched on the colour marker rather than the word, against a fixture where the item genuinely
is one scale's best. Fifth fixture problem this session, and the first one found by a committed
tool rather than a script I happened to write that day — which is the entire argument for
committing it.

### Gates
`tools/whybis.js` 48 → 58 checks; `tools/mutations.js` 29 → 32. All 43 gates, all 32 mutations.

## [0.97.0a] - 2026-08-14 — the thing that actually finds the bugs is now a tool

### Added
- **`node tools/mutate.js`** — breaks the code on purpose in 29 specific ways and requires the
  matching gate to fail for each. `node tools/mutate.js whybis` for one gate's worth.

A passing gate tells you the code does something. It does not tell you the gate would **notice**
if the code stopped — and an assertion that notices nothing reads exactly like one that works.

This session shipped twelve releases, and mutation testing found more real problems than every
static gate combined. It was also a throwaway script in a temp folder, rewritten from scratch
each time and deleted after. The record of *which assertions are load-bearing* existed only in
one conversation.

### What the 29 encode
Each names the user-facing consequence rather than the line it edits — *"a good second ring is
called beaten while you wear junk in the other hand"*, *"an item you should go and equip is
reported as beaten"*, *"a hidden scale keeps marking gear as best, and surplus feeds
auto-delete"*.

**Four exist because a survivor exposed the fixture, not the code:** a bag of nothing but chest
pieces, a bag of nothing but gear, a tooltip parse that was never empty, and a best-score that
was always exactly 100 — against which `gap / bestScore` and `gap / 100` are the same
arithmetic, so the percentage was never tested at all. Those are the four most valuable entries
in the file, because each marks a place my test world was tidier than the game.

### It has to be trustworthy before it is useful
It edits real source files, so: originals held in memory, restored after every mutation,
verified **byte-for-byte** at the end, and restored on interrupt. A failed restore is reported
loudly and exits non-zero. Deliberately **not** part of `gates.js` — a tool that rewrites your
working tree should be something you choose to run.

An **UNAPPLIED** result is a failure too, not a skip: a mutation whose anchor has moved is
testing nothing, and silently passing it is exactly how a manifest rots into decoration.

### Both failure modes verified
Not assumed — exercised. An inert mutation (a comment word) is correctly reported as
**SURVIVED**; a stale anchor as **UNAPPLIED**; both exit non-zero; the manifest restores clean.

The first attempt at that self-check was itself wrong: I used a whitespace change as the "inert"
case, and it broke a gate's slice regex, so the gate failed for the right-looking wrong reason
and the tool appeared to work. A no-op has to actually be a no-op.

## [0.96.0a] - 2026-08-14 — the tooltip tells you when something is *close*

### Added
- **A near-miss line on item tooltips.** *"Just short for Tank — 4% behind your best."*

`★ Best for` is binary, and the decision you actually make at a vendor is not. An item that
misses by 2% is worth keeping; one that misses by 60% is fodder — and the tooltip said exactly
the same thing about both: nothing. This is the line that separates them, and it's the whole
question you're asking when you hover something you already know isn't your best.

**One line, closest scale only, only inside 10%.** A line per scale is bloat; a line on every
item is noise that trains you to stop reading — which is worse than silence, because it sits
directly under the line that matters most. It appears only when *Best for* and the future-upgrade
line both had nothing to say: an item that's already your best, or is waiting on a level, is not
"just short" of anything.

Percentages, not points. A raw gap of 20 means nothing without knowing the scale's magnitude,
and that magnitude changes every time you re-weight anything. A sub-1% gap reads **"under 1%"**
rather than rounding to *"0% behind"*, which would look like a tie and invite you to keep
something that lost.

### Why this one is sound
It scores from the stats already parsed off the **displayed** tooltip — Ascension's scaled
values, the same source the best-equipment scores were built from. That is the entire reason the
comparison means anything; see v0.95.0a's `base-stats-need-scaled-comparison` for what it looks
like when it isn't.

### Gates
`tools/whybis.js` 33 → 48 checks. Five mutations, each caught: threshold ignored, furthest scale
reported instead of closest, "would win" items treated as near misses, a sub-1% gap rounded to a
tie, and the gap reported as raw points.

That last one **survived the first run**. Every baseline in the fixture was exactly 100, and
against 100 `gap / bestScore` and `gap / 100` are the same arithmetic — a percentage has to be a
percentage *of* something, and the test could not tell. Fourth time this session that mutation
testing has caught the fixture, not the code: all-chest bags, all-gear bags, never-empty parses,
and now one convenient number.

## [0.95.0a] - 2026-08-14 — a lint rule for the bug that got past 43 gates, and it found two more

### Added
- **`base-stats-need-scaled-comparison`**, lint rule 18. `GetStatsForItemLink` reads an item's
  **base** stats via `SetHyperlink`; every score the scan stores comes from
  `SetBagItem`/`SetInventoryItem`, which read Ascension's **scaled** stats. Subtracting one from
  the other produces a confident number that is fiction on a scaling realm.

v0.94.1a fixed one instance of that. Nothing about the code looked wrong — which is exactly why
all 43 gates passed on it — so the only durable answer is a rule.

### It found two more the moment it ran
Both in the integration addons, both in paths that make decisions, neither turned up by any
amount of reading:

- **`Valuate-PassLoot`** — the loot-roll decision. Already tries the loot tooltip first and only
  falls back to the link, recording which it used. Correct, and now says so on the line.
- **`Valuate-TSM`** — the Upgrade column. An auction listing is **not on your person**, so no
  scaled read exists; base stats are the only stats there are. That one is not fixable, so it is
  now written down: **the Upgrade column is a shopping heuristic on a scaling realm, not a
  measurement**, because it compares a base score against a scanned best-in-slot.

All four call sites now carry an annotation saying why base values are correct there. That is
the point of the escape hatch — it turns an invisible assumption into a written one.

### Removed a duplicate I had just written
`GetScaledStatsForItem` hand-rolled its own tooltip read: `ClearLines`, `pcall` the setter,
parse, reject an empty result. `Valuate:GetStatsForTooltipSetter` already did all four, and is
what the upgrade arrows, the quest-reward chooser and the roll decision go through — its
`pcall` and its empty-parse rejection are *why* those paths are right.

So the fix for a "two copies of one calculation" bug was itself a second copy. It now goes
through the shared reader, which also means `tools/whybis.js` protects that function for every
caller: the mutation that makes it accept an empty parse is now caught, and it wasn't before.

### Gates
`tools/whybis.js` 33 checks, unchanged in count and now exercising the real shared reader
instead of a stand-in. Five mutations, each caught — including the new one against
`GetStatsForTooltipSetter` itself.

## [0.94.1a] - 2026-08-14 — the best-in-slot gap was comparing base stats against scaled ones

### Fixed
- **v0.94.0a, shipped an hour earlier, reported a fictional number on scaling realms.**
  `ExplainBestInSlot` scored the item you asked about from `GetStatsForItemLink`, which uses
  `SetHyperlink` and therefore reads **base** stats — then subtracted that from best-equipment
  scores built with `SetBagItem`/`SetInventoryItem`, which read Ascension's **scaled** stats.
  Two different numbers for one item, subtracted from each other and printed to three
  significant figures.

The gap was wrong. Worse, the **"would win"** verdict could fire for an item that would not —
the one verdict I'd singled out as needing to be right, because it tells you to go and equip
something.

Every gate passed. They were all testing the verdict logic, which was correct; nothing checked
where the two numbers came from. A fixture that hands both sides the same stats table cannot
notice that production reads them two different ways.

### The fix
`Valuate:GetScaledStatsForItem` finds the item on your person and reads it the way the scan
did — equipped slot first, since that is the copy the best-equipment table was built from, then
your bags. Failing that it falls back to the link and **says so**:

```
Read from the link, not from the item - these are BASE stats.
Put it in your bags for numbers that match what was scanned.
```

That line matters more than the fix. A chat link for something you do not own is a case where
base stats are genuinely all there is, so the honest move is to label them, not to hide them
behind a confident-looking number.

It **reads** the in-transit guard, never relaxes it — `SetBagItem` during an equipment swap is
exactly what that guard exists to prevent — and falls back to base while a swap is pending.

### Gates
`tools/whybis.js` 23 → 33 checks. Five mutations, each caught: the scaled read removed
entirely, base stats labelled as scaled, equipped slots never searched, the in-transit guard
ignored, and an empty parse accepted as a real read.

That last one **survived the first run**. My mock returned either real stats or `nil` — but a
tooltip that has not populated parses to an **empty table**, and accepting that as a scaled read
would score a perfectly good item at zero and report *"scores nothing"* about it. Third time
this session a mutation has found the fixture modelling something the client does not do.

## [0.94.0a] - 2026-08-14 — "why isn't this my best-in-slot?" finally has an answer

### Added
- **`/valuate why <item>` now explains best-in-slot**, per scale, with the score, what beat
  it, and by how much.

It already explained rolls, arrows and junk — every automated *decision*. The addon's own core
output, "this is your best chest", had no diagnostic at all. *"Every automated path has a
diagnostic that explains why it did nothing"* was true of everything except the headline
feature, and "why isn't this my best?" is the most common question a gear addon gets.

```
-- best-in-slot --
BEST for Dps (412.0).
Beaten for Tank: 180.0 vs 244.0, short by 64.0.
    beaten by [Breastplate of Tenacity]
Scores nothing for Healer - none of its stats are weighted, so it can never win.
```

### Four verdicts that used to look identical
All of these were silence before, and they call for completely different actions:

| verdict | what it means |
|---|---|
| **best** | it is your best for that scale |
| **beaten** | something scores higher — named, with the gap |
| **would win** | it outscores what you have, but the scan hasn't run since it arrived |
| **scores nothing** | the scale weights none of its stats, so it can never win |

**"Would win" is the one that had to be right.** Reporting it as *beaten* would be a confident
lie about an item you should go and equip — so it is its own verdict, and it tells you to run
`/valuate scan`.

Deliberately **not** mixed with equippability. "You can't wear this yet" is a different answer
from "this loses on points", and the arrow line above already covers the first.

### Rings
An item with two possible slots is compared against the **weaker** of them, because that is the
one it would displace. Comparing against the stronger would report a good second ring as beaten
while you wear junk in the other hand. Same rule `GetUpgradeBaseline` already uses — two answers
from one rule, not two rules that can drift apart.

Matching is by **item ID, not link**: the recorded link carries whatever enchants and gems the
item had when scanned, so comparing strings would call your own gear an impostor.

### Gates
`tools/whybis.js`, 23 checks. Five mutations, each caught: "would win" collapsed into "beaten",
matching by link, "scores nothing" dropped, comparing against the stronger of two slots, and
explaining scales you have hidden.

The two-slot case only became testable because writing the mutations exposed that the fixture
was all chest pieces — the ring rule was unexercised, so the mutation that broke it passed.

## [0.93.0a] - 2026-08-14 — proving the last two releases actually did anything, in your client

### Added
- **`/valuate profile` now reports whether the caches are hitting.** Two lines at the bottom:
  the active-scale list and item slot lookups, each as a hit rate since login.

v0.91.0a and v0.92.0a cut a bag repaint from 240 sorts and 240 `GetItemInfo` calls to none.
Every word of that was proved by a gate **counting calls in a test harness** — which is evidence
about the source, not about your client. And a cache that silently never hits looks exactly like
one that works: same answers, same code path, no error, just the old cost quietly back. The
timings already in `/valuate profile` cannot tell those apart, because both are "some number of
milliseconds".

Two increments per lookup buys the answer. Open your bags a few times and run the command: above
90% means the last two releases are real on your machine. *Not used yet* means nothing has asked
yet, which is different from missing.

New verify check **`cachehit`** (32 now), which arms itself by running the profile.

### An optimisation deliberately NOT made
I went looking for a third hot path and checked two candidates before touching either:

- **`GetStatsForItemLink`** does a full `SetHyperlink` and tooltip parse per call — the most
  expensive thing a 3.3.5 addon can do. It has exactly **one caller**, a diagnostic. Caching it
  would have been pure ceremony.
- **The gear scan's stat parsing** already dedupes by item ID within a scan, and it reads
  `SetBagItem`/`SetInventoryItem` deliberately, because those carry Ascension's *scaled* values.
  Those depend on your level, so caching them across scans would be wrong, not just unnecessary.

Both are already right. Recording that here so the next pass does not re-derive it — "I checked
and there is nothing to do" is a result worth keeping.

## [0.92.0a] - 2026-08-14 — a repaint you have already done now costs nothing

### Optimised
Same path as v0.91.0a, the other half of it. The AdiBags filter asks two questions per item —
is this best-in-slot, is it a future upgrade — and **both called `GetItemInfo` for the same
item** to learn the same immutable fact: where it is worn. 240 calls for a 120-item bag, and
`GetItemInfo` is the expensive one in the client, missing entirely for an item the server has
not sent yet.

An item's equip location is intrinsic. No enchant, gem, reforge or scaling moves a chest piece
to the finger slot, so the answer is memoised by item ID and **never invalidated**. Keyed by ID
rather than link, because two links for one item differ by enchants and would fragment the
cache for nothing.

```
                    before          after (cold)     after (warm)
GetActiveScales       240             180              180
table.sorts           240               1                0
scales-table walks    240               1                0
GetItemInfo           240             120                0
```

### The one thing that must never be cached is a miss
`GetItemInfo` returns nothing for an item the client has not received yet. Storing that as
"goes nowhere" would leave the item unequippable in Valuate's eyes until a `/reload` — and the
items most likely to be uncached are the ones that just dropped. `false` means *asked, and it
genuinely goes nowhere*; that is a different answer from *do not know yet*, and only one of them
is worth remembering.

### A benchmark that modelled a bag nobody has
Three mutations, and the third **survived**: deleting the "goes nowhere" branch changed nothing,
because every item in the benchmark was a chest piece. A real bag is mostly *not* gear — potions,
reagents, quest items — which makes that branch the common case, not an edge case. Half the
simulated bag is now non-equippable, which is both more realistic and enough to catch it.

The measurement moved when the model got honest: cold `GetActiveScales` fell from 240 to 180,
because a non-gear item leaves `GetFutureUpgradeScales` before it asks. That number was never
wrong — the bag was.

## [0.91.0a] - 2026-08-14 — a bag repaint stops re-sorting a list that cannot have changed

### Measured, then fixed
The roadmap has flagged the AdiBags filter as the likeliest hot spot since before there was a
way to check. There is one now: **`tools/hotpath.js`** drives the path AdiBags drives — one
filter call per item per repaint, each asking `IsBestInSlot` and `GetFutureUpgradeScales` — and
found a 120-item bag with 6 scales doing this per repaint:

```
240 GetActiveScales calls, 240 table.sorts, 240 full walks of the scales table
```

`GetActiveScales` allocated a table, walked every scale and **sorted** the result, on every
call. The list is derived from the scales table alone, so it cannot change while a repaint is
in flight: **239 of those 240 sorts could not affect any answer.** Now cached:

```
240 GetActiveScales calls, 1 sort, 1 walk
```

### Invalidation is the risky half, so it hangs off something that already exists
The cache is dropped in `ResetTooltips`, which is already the "scoring inputs changed" signal
and already drops the upgrade-arrow cache for exactly this reason. Hanging it there rather than
on thirty individual mutation sites means a new one inherits it.

A one-second **TTL** backs that up. It is the safety net, not the mechanism: if some future path
edits scales without going through `ResetTooltips`, a stale list would mark gear as surplus that
is not — and surplus feeds auto-delete. One second is imperceptible for a visibility toggle and
still collapses an entire repaint burst into a single build.

### Counts, not milliseconds
Wall-clock under a Lua-in-JS harness says nothing about Lua 5.1 in the client. "How many times
did we sort a list that cannot have changed" transfers exactly. The budgets are ceilings the
current code sits under, so a change that makes a repaint measurably worse has to say so out
loud rather than shipping quietly.

`GetItemInfo` stays at 2 per item and is deliberately *not* optimised below that — it is the
shape of the filter itself asking two questions, not waste.

### Gates
`tools/hotpath.js`, 14 checks, and the harness now prints a benchmark's measurement alongside
its OK line — a number that only appears when a budget breaks is a number you never see.

Four mutations, each caught: cache never invalidated (which would keep marking gear as best for
a scale you had hidden), cache never stored, TTL never lapsing, backwards-clock guard removed.
The backwards-clock one **survived the first run** — the assertion did not exist until it said
so, which is the whole reason for mutating.

## [0.90.0a] - 2026-08-14 — the in-game checklist covers what actually shipped

### Fixed
- **`/valuate verify` had stopped growing at v0.64.0a while the addon went on to v0.89.0a.**
  Twenty-five releases — the CoA template set, Mastery/Versatility/Leech, wardrobe collecting,
  the AdiBags scan button, this week's wizard work — every one of them resting on an assumption
  about the client that no headless gate can test, and none of them on the list. A checklist
  that quietly falls behind is worse than a short one: it reports "nothing pending" and sounds
  like assurance.

### Five new checks, 21 → 31
The one that matters most is **`coaclass`**, because the entire 21-class, 70-spec feature hangs
on a single untested assumption: that `UnitClass("player")` returns the CoA class name, spelled
the way the templates spell it. If it returns a stock token instead, `GetTemplateSet` falls
through to the classic ten and every CoA build is silently unreachable — nothing errors, the
wizard just proposes an Arms Warrior build to a Necromancer. The check arms itself: it prints
what the client said and which set matched, so the answer takes one command.

- **`newstats`** — Mastery, Versatility and Leech tooltip wording was **guessed**. The parser
  accepts `+12 Mastery Rating` and a bare `+12 Mastery` because I could not see which Ascension
  uses. If it uses neither, every item carrying them scores as though it carried nothing.
- **`scalerefresh`** — v0.89.0a's Refresh button and the update path behind it.
- **`wardrobebind`** — whether `CollectItemAppearance` binds the item. An addon cannot see this
  until after the fact, which is why the README warns rather than guessing.
- **`adibagscan`** — another addon's header-widget contract, and a guessed ordering value.

### And a gate so it cannot happen again
`tools/verifytest.js` now reads the real list and fails when its newest entry falls more than ten
minor releases behind the `.toc`. **No escape hatch on purpose** — shipping ten releases with
nothing a human should look at is itself the thing worth being told. It also rejects duplicate
check ids, which would share one tick: verifying either would mark both done, which is precisely
the failure the checklist exists to prevent.

Three mutations confirm it: eleven releases behind, two checks sharing an id, and the list
renamed out from under the gate.

## [0.89.0a] - 2026-08-14 — the scale list tells you when your Auto scale has gone stale

### Added
- **The wizard button now says what it would actually *do*.** v0.88.0a taught the wizard to
  update the scale it made, and immediately created a discovery problem: the only way to find
  out a scale had drifted was to re-run the wizard on a hunch. When an update is available the
  button at the top of the scale list reads **Refresh my scale** instead of *Make me a scale*,
  and its tooltip names the scale: *"Your gear has moved on from Auto - Str/Crit/Hit, which I
  made for you earlier."*

A stale scale is not a preference, it is quietly wrong — it ranks your gear against weights you
outgrew. But it is not urgent either, so this gets **no chat nudge and no popup**. It waits in
the one place you already look at your scales, and it names what it means rather than asserting
"your scale is out of date", which is an accusation you cannot check.

### Not an automation, and not an option
`Valuate:GetAutoScaleDrift` is the read-only half of `PlanAutoScale`. It writes nothing, creates
nothing and takes no action — it answers a question the UI asks so it can pick its own label.
There is nothing here to opt into because nothing here happens to you.

It passes **no role**, deliberately: "whatever your gear most resembles" is the only honest
question to ask unprompted. And because it inherits v0.88.0a's `AutoSource` matching, standing in
caster gear never reports your **tank** scale as stale — that is a different build, not a drifted
one.

### Cost
Two guards keep this off the repaint path: a **pre-check** that skips the template match entirely
for anyone with no wizard-made scale, and a **20-second TTL** on the answer. Both are gate-tested
by proving the opposite fails.

### Gates
`tools/autowizard.js` (84 checks, was 72) covers the detector; `tools/scalelisttest.js` (45, was
37) covers the button. Eight mutations, each caught by the assertion meant for it: pre-check
dead, TTL dead, backwards-clock guard removed, drift never reported, label never swaps, label
never reverts, name not carried to the tooltip, refresh never called.

Writing the button test surfaced a second thing worth recording: wrapping `ns.CreateStyledButton`
from the harness captures **nothing**, because `ui/ScaleList.lua` localises it at load and is
already holding its own reference. The test finds the button in the frame registry instead.

## [0.88.0a] - 2026-08-14 — the wizard can update the scale it made, not just make another

### Added
- **Re-running the wizard now offers to *update* the scale it built for you before**, instead of
  only ever creating a new one. Gear drifts — you level, you re-gem, you pick up a tier piece —
  and the weights the wizard derived at 62 are not the weights it would derive at 80. Until now
  the only way to correct a stale `Auto -` scale was to delete it and start over, which meant the
  addon's own output was the one thing it could not maintain.

The preview screen's button reads **Update it** where it used to read *Create it*, with a line
naming exactly what would be replaced: *"This replaces Auto - Str/Crit/Hit/AP/Haste, which I made
earlier and your gear has moved on from."* Replacing edits is only acceptable *because* the
preview names what it is replacing, beside the weights it would write. Silent would be wrong.

### The design flaw a test caught before it shipped
The first cut matched any scale carrying the wizard's teal colour. That is wrong, and the gate
said so within a minute: if you have a DPS `Auto` scale and ask for a **Tank** build, those are
two different builds, not one drifted build. Offering to overwrite the first with the second
would destroy a scale you deliberately made.

Scales now record the spec they were derived from (`AutoSource`), and an update is only offered
when the new weights come from **that same spec**. A different spec always creates. Three
mutations confirm it: ignoring the source, never offering the update, and never recording the
source each fail a different assertion.

### Unchanged
Hand-built scales are still never touched — no colour, no source, no match. Asking for a build
you already have exactly still says *Use it* and writes nothing at all.

## [0.87.0a] - 2026-08-09 — you can actually ask the wizard for a Support build

### Fixed
- **The wizard had no Support choice.** CoA has six support specs, `SUPPORT` became a real
  role in v0.80.0a, and the templates were all in place — but the first screen still offered
  only *Build it for me*, Tank, Healer and Damage. There was no way to ask for the thing the
  data supported. A gap I left open myself.

### It appears only where it can work
The classic ten classes have no support specs, so on those realms the button could only ever
answer *"nothing resembles what you are wearing"*. It is filtered out there — a control that
cannot succeed is its own kind of bug, and the wizard already refuses to draw dead controls
elsewhere.

Filtering happens **before** the cascade is measured, so the stagger spaces the buttons that
exist rather than leaving a gap where a hidden one would have been.

### Gates
Two, because one run cannot cover both cases — the wizard builds its screens once per session,
so a single harness can only be a classic character *or* a CoA one:

- `tools/wizarduitest.js` builds against the classic set and requires the button to be
  **absent**, and the choice count to be four rather than five.
- **`tools/wizardroles.js`** is a fresh session that is CoA from the start, and requires the
  button to be **present** alongside the other three.

Mutation-tested both directions — always-drawn and never-drawn — and each was caught by
exactly the gate meant to catch it, which is the evidence that the two are complementary
rather than one being redundant.

## [0.86.0a] - 2026-08-09 — CoA support exists in the documentation now, too

Same gap as v0.71.0a found for the wizard: a major feature present in the code and absent
from every document describing the addon. Eight releases of Conquest of Azeroth work, and
neither README nor ARCHITECTURE mentioned it once.

### Added
- **README** — CoA is in the tagline and has its own feature entry: 21 classes, 70 specs, the
  wizard picking the right set by class, and the honest caveats (six inferred specs, and the
  entries that look wrong at a glance but are not).
- **README** — Mastery, Versatility and Leech are listed as scored stats. They were added in
  v0.79.0a and never mentioned to anyone.
- **ARCHITECTURE** — a table of the two template sets, why they are separate, how
  `Valuate:GetTemplateSet()` chooses, the conversion ladder, and two warnings for whoever
  edits this next: do **not** generate CoA weights from role, and the missing `unusable`
  lists are a decision rather than an omission.

### Research notes closed
`docs/coa-research.md` is marked complete, with what remains open stated plainly: six specs
whose weights are inferred, no `unusable` lists by choice, and the fact that none of it has
run in the game.

## [0.85.0a] - 2026-08-09 — the wizard was throwing away every template's banned stats

### Fixed
- **Wizard-made scales had an empty `Unusable` table, always.** `CommitAutoScale` hardcoded
  `Unusable = {}` and `PlanAutoScale` never read `spec.unusable`, so the templates' banned
  stats were discarded on the way through. Retribution bans nine weapon types; a scale built
  from it happily scored daggers, staves and wands, and Best Equipment would offer them.

Found while deciding what to do about CoA's `unusable` blocks — the question "what happens to
these?" turned out to have the answer "nothing, ever". It affects the **classic** realm too,
where all 31 templates define them carefully.

The banned stats are **copied**, not referenced, for the same reason the weights are: the
wizard shows the plan again on its final screen, and a shared table would let a later edit to
either change the other. Mutation-tested both ways.

### And a decision about CoA's own `unusable` blocks: there aren't any, deliberately
CoA's armour and weapon rules are barely documented. Confirmed: Bloodmage wears leather, Witch
Hunter's Black Knight tanks in mail, Guardian uses shields, Templar fights with fists. That is
four data points across 21 classes, and CoA also has **smart drops tailored to your active
spec**, which is the game already solving much of this.

Inventing bans from that would be worse than having none. An empty list means nothing is
wrongly excluded; a wrong list actively hides gear you can use, and hides it *silently*. So
the CoA templates ship with no `unusable`, and the reason is recorded next to them rather than
left as an apparent oversight for someone to "complete".

## [0.84.0a] - 2026-08-09 — all 21 CoA classes, 70 specs

The last class is in. **Son of Arugal** — which turns out to be the same class as
**"Bloodmage"**, resolving the third and final source contradiction, where "Blood Mage" looked
like a 22nd class.

### The one class with no published stat priority
Its page 404s on the wiki carrying the other twenty, and no source found gives one. What *is*
published is each spec's description and the class's leather armour, so the weights are
**inferred from those** — Ferocity shreds in worgen form, Blood spends health on siphons,
Packleader fights with summons, Fleshweaver heals through ritual.

That is weaker than transcription, and it is labelled as such. Every affected spec carries
`inferred = true`, and `tools/speccoverage.js` now reports the count in its summary:
*"6 with INFERRED weights - no published priority"*. Guardian *Inspiration* is marked the same
way. The alternative was leaving the class out entirely — which would mean the wizard silently
never proposes it, and a silent gap is the exact failure that gate exists to catch.

### Count
70 specs against the "69" most sources quote. One source said 70, so this sits at the top of
the published range rather than contradicting it. Cultist's fourth spec (*Corruption*) is the
likeliest reason the lower figure circulates: the class-list articles omit it, and only the
per-class page has it.

### A process note
The insert script reported success while changing nothing — its anchor used `\n` against a CRLF
file, and it printed a hardcoded message instead of checking. It now verifies the replacement
altered the text and re-reads the file to confirm. Third time this session a "success" message
has been unearned, and the fix is always the same: assert rather than announce.

## [0.83.0a] - 2026-08-09 — the wizard uses the CoA templates now

The CoA table existed but nothing read it. This connects it.

### Added
- **`Valuate:GetTemplateSet()`** — returns the template set matching this character, and a
  word naming which it picked. The wizard now asks it instead of always taking the classic
  table, so a Necromancer is matched against CoA builds and a Warrior against classic ones.

### Detected from the CLASS, not the realm name
Conquest of Azeroth launched on Vol'jin, and a hardcoded check for that string would quietly
stop working the day a second CoA realm opens. A Necromancer is a Necromancer wherever they
log in, and no classic character is ever one.

It falls back to the classic set whenever the answer is not *clearly* CoA — an unrecognised
class, a missing `UnitClass`, a nil class name, or the classless realms. That is the safe
direction: the classic set has been the only set for this addon's entire life, so falling
back to it is exactly the behaviour everyone already has.

### Gates
- Five runtime checks in `tools/wizarduitest.js` covering every branch — no `UnitClass`, a
  classic class, a CoA class, an unrecognised class, and a nil class name.
- Mutation-tested both ways that matter: a selector that always returns classic (CoA players
  would silently get Warrior builds) and one that always returns CoA (everyone else would).
- `GetTemplateSet` is in the `/valuate selftest` list. It lives in `ui/Data.lua`, so checking
  it also proves that module loaded — the same reason `ShowScaleWizard` is listed.

## [0.82.0a] - 2026-08-09 — CoA templates: 20 of 21 classes, 66 of 69 specs

Nine more classes transcribed — Tinker, Barbarian, Felsworn, Witch Doctor, Chronomancer,
Templar, Knight of Xoroth, Reaper, Witch Hunter. Every class whose page could be read now has
templates.

Only **Son of Arugal** is missing; its wiki page 404s at the URL pattern that served the other
twenty, so it needs finding another way.

### Three entries carry a warning comment, because they look like mistakes and are not
- **Chronomancer *Artificer* leads with Spirit.** A minor regen afterthought in 3.3.5 and a
  primary stat here.
- **Witch Hunter *Black Knight* is an Agility-scaling tank in mail.** Neither half is possible
  under 3.3.5 rules, and it independently confirms the "mail tanking gear" line on Ascension's
  own CoA page.
- **Felsworn splits its primaries** — Intellect for Infernal, Agility for Slayer and Tyrant —
  which is why the one-class-stat tendency is documented as a tendency and never used to
  generate anything.

Each has a comment sitting beside its weights, because the next person to read "a tank whose
primary stat is Intellect" will otherwise assume a typo and helpfully break it.

### Still to do
CoA-aware `unusable` blocks (the WotLK weapon and armour assumptions are actively wrong here),
realm detection so the wizard picks the right table, and Son of Arugal.

## [0.81.0a] - 2026-08-09 — CoA templates: 11 of 21 classes

Six more classes transcribed: Venomancer, Necromancer, Pyromancer, Guardian, Cultist,
Starcaller. **38 of 69 specs** now have templates.

### Three judgement calls, each marked in the source where it was made
- **Necromancer and Pyromancer publish one priority for all three specs.** That is the
  source's own choice, so all three share it rather than having differences invented for
  them.
- **Venomancer *Stalking* is published as "Leech, melee uptime, survivability."** Only the
  first is a gear stat. Uptime is read as haste and survivability as stamina — a judgement,
  not a transcription, and commented as such.
- **Guardian *Inspiration* has no published priority at all.** Its weights are inferred from
  the class's other two specs and flagged in the file so they can be corrected rather than
  mistaken for something a source said.

### What the data keeps confirming
Starcaller leads with **Intellect in all four specs — tank and melee included**. That inverts
3.3.5, where the role picks the primary stat, and it is why this table cannot be derived from
role or from any rule of thumb. The comment sits next to the Warden weights so the next person
to read them does not "fix" the apparent mistake.

## [0.80.0a] - 2026-08-09 — the first Conquest of Azeroth templates

Research becomes data. Five CoA classes, 17 specs, transcribed from the per-class pages.

### Added
- **`COA_CLASS_SPEC_TEMPLATES`** in `ui/Data.lua` — Primalist, Sun Cleric, Ranger, Runemaster
  and Stormbringer. Deliberately a **separate table**: a classless player must never be offered
  "Stormbringer Lightning", and a CoA player must never be offered "Arms Warrior". Neither
  class exists on the other one's realm.
- **`SUPPORT` as a real role** — six CoA specs have it. Allowed in the CoA table only; the
  classic table still forbids it, because Paladin Retribution carried a stray `SUPPORT` until
  v0.78.0a and was unreachable by role because of it.

### The conversion, stated once and applied uniformly
The source publishes **ordered lists**; Valuate scores with **numbers**. One ladder everywhere:

| Rank | Weight |     | Rank | Weight |
|---|---|---|---|---|
| 1st | 1.00 |  | 4th | 0.40 |
| 2nd | 0.75 |  | unlisted but plausible | 0.05 |
| 3rd | 0.55 |  | | |

Uniform is reproducible and honest about its own precision. Hand-tuning each spec would invent
detail the source does not contain.

**Dual primaries get 1.0 each.** Several specs publish two ("Strength/Agility", "Intellect or
Agility"). Weighting both scores a character carrying either one correctly and only
over-values the rare one carrying both — whereas picking one is simply wrong for half the
people playing that spec, and splitting into two templates hands the wizard two
near-identical candidates that are permanently each other's runner-up.

### Gates
- `tools/speccoverage.js` now checks both tables separately, with per-table role sets, and
  enforces that **every CoA spec's top weight is exactly 1.0** — a converted primary that
  came out at 0.9 means the ladder was applied wrongly. Mutation-tested three ways.
- No completeness expectation for CoA yet: 5/21 is a milestone, not a failure, and the gate
  reports progress rather than pretending the table is finished.
- The gate reported **"CoA: 0/21"** on its first run while five classes sat in the file. Its
  slice was anchored on `ns.SCALE_ICON_LIST`, which also appears in a comment on line 6, so
  `indexOf` matched the comment and produced an empty range. Anchored on the assignment now —
  and worth recording, because a coverage gate that silently measures nothing is worse than
  no gate.

## [0.79.0a] - 2026-08-09 — Mastery, Versatility and Leech are scoreable now

### Added
- **Three stats Valuate could not see.** `MasteryRating`, `VersatilityRating` and
  `LeechRating` now exist in the stat list, the abbreviation table, the display names and the
  tooltip parser. An item carrying them used to score as though it carried nothing.

They are not in stock 3.3.5 — Blizzard added Mastery in Cataclysm and Versatility/Leech in
Warlords — which is why they were missing. Ascension back-ported them, and two independent
sources say so:

- **Conquest of Azeroth publishes them as real priorities.** Stormbringer wants Mastery high
  in two of its three specs and Versatility in the third; Pyromancer and Barbarian both list
  Versatility.
- **`AscensionStatWeights`**, an addon installed alongside this one, already weights all
  three.

### Why this before the CoA templates
It is the prerequisite. A CoA scale that wants Mastery could not be written at all — the stat
did not exist to reference, and `tools/autoname.js` requires every stat to have an
abbreviation. This clears that.

The parser takes both phrasings: `+N Mastery Rating` and the bare `+N Mastery`, since modern
WoW drops the word and it is not knowable from here which Ascension uses. An unmatched tooltip
line is not an error — it is a stat silently scored as zero — so covering both is cheap
insurance against exactly the kind of silent wrongness this addon keeps finding.

### Risk
Deliberately additive data only: four tables, no new code paths, nothing at file scope. That
matters given v0.74.0a broke the client with a core change — `tools/loadtime.js` now refuses
file-scope calls, and this change does not go near one. `datatest.js` picked the new stats up
automatically and went from 3997 to 4003 checks.

## [0.78.0a] - 2026-08-09 — Death Knight existed everywhere except in Valuate

Starting a pass over the class/spec templates. Two defects before any research, both invisible
by reading the file, because both are *things that are not there*.

### Fixed
- **Death Knight had no templates at all.** Nine classes, 28 specs. Blood, Frost and Unholy
  simply did not exist — so a plate-and-Strength tank asking the wizard for a tank scale got
  Protection Warrior or Protection Paladin, because Blood was not in the running. The wizard
  hands out the closest *other* build and looks like it worked; nothing anywhere says a better
  match was missing. All three are in, with WotLK 3.3.5 stat priorities.
- **Paladin Retribution had `role = "SUPPORT"`.** The wizard offers Tank, Healer and Damage, so
  Retribution could not be matched by role **at all** — not a wrong answer, an unreachable one.
  It is `DAMAGER` now.

31 specs across 10 classes.

### Gates
- **`tools/speccoverage.js`** — every class and spec in the 3.3.5 list has a template, every
  role is one the wizard can actually ask for, and every spec has weights, an icon and a
  colour. Mutation-tested against all three real shapes: a missing class, a missing spec, and
  a role outside the set.
- The templates are the wizard's entire source of intelligence, and this table is 1700 lines.
  A gap in it is silent by construction, which is exactly what a gate is for.

### Still to do
The stat weights are WotLK baselines — the same basis as the 28 that were already here. Where
**Ascension CoA** diverges from stock 3.3.5, they will need correcting against a real source,
which is the rest of this job.

## [0.77.0a] - 2026-08-09 — a gate for the one failure that reached the client

Every bug this session was caught by a gate except one, and that one broke the addon for a
real person. This is the gate for its shape.

### Gates
- **`tools/loadtime.js`** — at **file scope**, only APIs guaranteed to exist on every 3.3.5
  client may be called. Everything else has to move inside a function that runs after load.

File-scope code is uniquely unforgiving. It runs on every login, before any of the addon's own
error handling exists; there is no setting or command to avoid it; and relogging just runs it
again — which is exactly what you saw when v0.74.0a would not open. A headless mock cannot
tell you whether *this* client has the function you are calling, and in that case it confidently
told me it did.

The allowlist is deliberately tiny — `CreateFrame`, `IsAddOnLoaded`, `GetAddOnMetadata`, the
`Valuate` table itself, and Lua's own library. Each entry is a promise that the call exists
everywhere this addon runs. **`CreateFont` is not on it**, even though it is a genuine 3.3.5
API, because what failed was not its existence but the `SetFont` that follows it.

Built on the AST rather than line matching, and it does not descend into function bodies — a
call inside one runs later, when a failure costs one feature instead of the whole addon.
Method calls on locals are excluded too: `animDriver:SetScript(...)` is calling a frame that
`CreateFrame` just returned on the line above. That left 58 real file-scope calls across 20
files, all legitimate.

**It catches the actual bug.** Reintroducing the v0.74.0a font code as a mutation fails the
gate at `ui/Shared.lua:224 CreateFont(...)`, as do a custom-server API and a retail-only one
called at load.

### Also
- Corrected a comment in `tools/luaharness.js` that claimed the `CreateFont` mock existed to
  exercise a real code path in `ui/Shared.lua`. That path was reverted in v0.75.0a, so the
  comment described something that no longer happened — the same species of stale claim these
  gates exist to catch.

## [0.76.0a] - 2026-08-09 — collect wardrobe appearances you don't have yet

### Added
- **`/valuate wardrobe`** — lists every item in your bags whose appearance you have not
  collected. Read-only; this is the one to run first.
- **`/valuate wardrobenow`** — collects them.
- **`/valuate autowardrobe`** — does it automatically as items arrive. Off by default,
  throttled, and it runs *below* the in-transit guard so nothing is collected while items are
  still moving between bags and slots.

### What I could not verify, and why it shapes the design
The API is Ascension's, not Blizzard's — `C_Appearance.GetItemAppearanceID`,
`C_AppearanceCollection.IsAppearanceCollected` and `CollectItemAppearance`. I read it out of
PastLoot rather than guessing, but **I have never run it**, and an hour before writing this a
font object built against an unconfirmed API surface stopped the whole UI from opening.

**Collecting may BIND the item.** PastLoot only ever calls it on things it is about to delete
or vendor, which is consistent with binding and proves nothing either way. Nothing available to
an addon can settle it. So: off by default, and a preview exists precisely so you can look at
the list and decide before switching anything on.

Everything uncertain therefore means **do nothing**:
- No wardrobe API → a reason, never an error.
- `IsAppearanceCollected` returns nil or errors → the item is left alone. *"I could not find
  out"* and *"you do not have it"* are different answers, and only one justifies acting.
- Two items sharing an appearance → collected once, since the collected-state cannot catch up
  within a single pass.

### Gates
- `tools/wardrobetest.js`, 31 checks, mutation-tested six ways.
- Two bugs found by writing it. The re-verify-before-acting guard was **theatre** — the
  function built its own list moments before acting, so nothing could change in between;
  it now accepts a list you previewed earlier, which makes the check real. And the throttle
  used `0` as its "never ran" sentinel, which collides with a legitimate `GetTime()` of 0, so
  the first pass was skipped; it has its own flag now.
- One mutation initially **survived**: treating a falsy collected-state as "uncollected". My
  error-case mock made `pcall` hand back the error *string*, which is truthy, so the mutation
  passed through it untouched. The case that actually mattered — the API answering with **nil**
  — had no test until that survival pointed at it.

## [0.75.0a] - 2026-08-09 — HOTFIX: v0.74.0a stopped the UI opening

**If you are on v0.74.0a, update.** The window would not open and relogging did not help.

```
Error opening UI: ValuateUI.lua:170: <unnamed>:SetText(): Font not set
```

### Fixed
- **Reverted the custom font objects.** The type scale added in v0.74.0a shipped with a
  fallback that *could not fire*:

  ```lua
  local applied = pcall(font.SetFont, font, FONT_PATH, size)
  if not applied or (font.GetFont and not font:GetFont()) then return fallbackTemplate end
  ```

  Two holes, either one fatal. `pcall` returns success *then* the call's own result, and only
  the first was captured — so a `SetFont` that returned false without erroring read as
  success. And a 3.3.5 `Font` object has **no `GetFont` method**, so `font.GetFont` is nil and
  the whole second clause is falsy. `DefineFont` returned the name of a font object with no
  font set, and the first `SetText` against it threw while the window was being built.

The colour work from v0.74.0a is **unaffected and stays** — the contrast fixes and the
hierarchy repair are numbers in a table, with nothing to fail at runtime. What is lost is the
type scale: `FONT_H1` is `FONT_BODY` again, so headings are once more the same size as their
body text. That is a cosmetic problem and a window that will not open is not; the two are not
worth trading.

### What the gate was doing while this shipped
Reporting 25 green checks against a fiction. The harness answers `SetFont` with a stored table
and `CreateFont` with a frame, so every assertion about font sizes passed — *the mock agreed
with the mistake*. This is the third time this session a mock has been wrong in the addon's
favour, and the first time it reached the client.

`tools/typescale.js` has been rewritten to assert the only thing that is honestly checkable
without the game: every font token names a **stock** font template the client is guaranteed to
ship. It no longer claims to verify a type scale, because a headless harness cannot know
whether *this* client accepts a font.

Reintroducing the scale is still worth doing — but it needs a functional probe (draw text with
the font and see whether it throws), verified in the game, not a guard written against an API
surface nobody confirmed.

## [0.74.0a] - 2026-08-09 — UI overhaul, stage 1: the design tokens

First of two staged releases. This one changes **only** `ui/Shared.lua`, because 79% of colour
use and 95% of font use already go through tokens — so the refresh cascades to all 15 modules
without touching them. Stage 2 is layout and navigation.

Two defects, both found by measuring rather than by looking, and together they explain why the
panels read as flat and hard to scan:

### Fixed
- **The text hierarchy was inverted.** `textHeader` measured **10.90:1** against a `textBody`
  of **14.18:1** — every section heading was *quieter* than the paragraph beneath it. Both
  colours look fine in isolation, which is why no amount of care caught it. The scale now
  descends properly: title 18.28 → header 15.92 → body 12.19 → dim 7.55.
- **`textDim` failed WCAG AA.** 3.73:1 on buttons, 4.41:1 on inputs — and that is the token
  hints and secondary labels use, which is exactly the text someone is squinting at when they
  are already unsure what a control does. Now 5.85:1 at worst.
- **Six font tokens, three fonts.** `FONT_H1` *was* `FONT_BODY`, and `FONT_H2`, `FONT_H3` and
  `FONT_SMALL` were all one font. A section heading was literally the same size as its body
  text. There is a real scale now — 16 / 14 / 13 / 12 / 12 / 10 — built from font objects, so
  all 264 call sites are unchanged: the tokens are still strings naming a font.
- **The hover state was shouting.** `buttonHover` was a 2.8× luminance jump off `buttonBg`,
  loud for a dark theme, and it put dim text on a hovered scale row at 3.26:1. Softened to a
  ~1.7× lift — still a clear affordance.

### Safety
`DefineFont` copies the stock font object before changing size, so colour, shadow and
justification are inherited and only the size moves. If the client refuses the font it returns
the stock template instead — a bad path would otherwise mean *invisible* text across every
panel at once, which is far worse than the flat scale being fixed.

### Gates
- `tools/contrast.js` — every text token must clear AA on every background it is drawn on, and
  the hierarchy must descend. Mutation-tested four ways, including restoring the original
  inversion.
- `tools/typescale.js` — the six tokens must resolve to *real* font objects with distinct
  descending sizes. The check that they are **not** the stock names is the one doing the work:
  a silent fallback would restore the old flat scale while every other gate still passed.
- Both gates found things while being written. Contrast flagged dim-on-hover, which turned out
  to be real — `ScaleList` dims inactive row names, and rows tween to `buttonHover` on hover.
  And two of my own type-scale mutations initially survived, because the fallback check matched
  any of three `return fallbackTemplate` branches rather than the one that mattered.

## [0.73.0a] - 2026-08-09 — the health check sends you to the wizard now, not to the stat editor

### Changed
- **`/valuate check` pointed people at manual work they cannot do.** Finding an active scale
  with no weights, it said *"open it and set some"* — which assumes you know what your weights
  should be, and not knowing is precisely why the scale is empty. Both that remedy and the
  "no active scale" one now offer `/valuate wizard`.

### Gates
- Every `/valuate <command>` the addon **prints to you** must be a real command. These are
  remedies handed to someone already stuck: they type exactly what they were told, get
  "unknown command", and conclude something worse is wrong.

### How badly I got that gate wrong first
Recorded because the failures are more instructive than the result, and both directions
happened in one sitting:

1. **Scanning the whole source** reported four problems, all wrong, in three different ways —
   a comment mentioning a removed command, the in-game changelog *correctly* recording
   *"Removed /valuate cache and /valuate clearcache commands"* (text it would be a lie to
   change), and the help line `/valuate or /val`, where "or" is English.
2. **Narrowing to `print(...)` calls** made it pass cleanly — and it was then protecting
   nothing at all. The health-check remedies are accumulated into a `problems` table and
   printed later, so the one surface the gate existed for was outside its scope. Only
   mutation testing found that; a green tick would otherwise have looked like success.
3. A greedy `[a-z]+` backtracked to report a command called **`o`** after the lookahead
   rejected `or`.

Now: comments stripped, historical changelog text exempt, `\b` before the lookahead, and
three mutations confirming it catches a renamed remedy, a removed one, and a stale tooltip
hint.

## [0.72.0a] - 2026-08-09 — `/valuate selftest` could not see the wizard at all

### Fixed
- **The self-test's method list contained none of the wizard's API.** Eleven releases, ten
  public methods, and `/valuate selftest` would have reported all-clear while the entire
  subsystem was missing — including the case that matters most, `ui/Wizard.lua` failing to
  load, which leaves the rest of the addon working and only the wizard gone. That is the
  subsystem a new user meets *first*. All ten are now checked, including
  `Valuate:ShowScaleWizard()` and `Valuate:ApplyMinimapButtonOptions()`, which live in other
  files precisely so a module that failed to load is caught.
- **`Valuate:RegisterBestEquipmentListener()` was never self-tested either.** Found by the new
  gate on its first run, and pre-existing rather than mine: `ARCHITECTURE.md` tells
  integrations to register through it, so if it vanished AdiBags would simply stop refreshing
  and nothing would say why.

### Gates
- `tools/api.js` now requires **every method the docs present as public API** to be in the
  self-test list. Deliberately not "every method" — the list is 61 of 131, and a subset is
  correct — but documenting one is the moment you tell people they can rely on it, and
  self-test is what proves at load that it is still there.
- The rule keys on the `Valuate:Name()` form, so the wizard's `ARCHITECTURE.md` table was
  rewritten to name each method in full instead of as a bare backticked word. That was found
  by mutation: dropping the wizard entries from the self-test list did **not** fail, because
  the docs had not named them in a form the gate could see. Documented coverage went from 4
  methods to 13.

## [0.71.0a] - 2026-08-09 — the wizard exists in the documentation now, too

Eleven releases of wizard, and it appeared in exactly one place outside its own source: the
module table in `CLAUDE.md`. Not the README's feature list, not the command reference, not
`ARCHITECTURE.md`. A feature nobody can read about is most of the way to a feature nobody
finds.

### Added
- **README** — the wizard now leads the feature list, where a new reader actually looks, and
  `/valuate wizard` is in the command block.
- **ARCHITECTURE.md** — a section on the three-layer split (matching → plan → commit → screens)
  with the table of which layer writes, and the consequences worth knowing before changing any
  of it: why matching ignores item-level stats, why similarity is cosine, why ties break on
  the class/spec key, why weights are floored, why the plan is copied on commit, and why a
  duplicate is reused rather than overwritten.

### Gates
- `tools/commands.js` now checks that **every command the README names actually exists**. Same
  failure as the scale list's empty state, which pointed at two renamed buttons for several
  releases: documentation naming a thing that is not there is worse than no documentation,
  because it sends someone confident in the wrong direction and they blame themselves rather
  than the file.
- The first run of that check reported a bug **in itself** — `\s+` in the pattern spanned the
  command block's column alignment, so `/valuate` → `open the UI` read as a command called
  `open`. Fixed to a single space before shipping. A checker that fires on correct content is
  the exact failure that made `CheckColumnAnchors` useless in the client, and it would have
  been careless to add another one in the same session that fixed it.

## [0.70.0a] - 2026-08-09 — "Fine-tune it" now lands on the scale it just made

### Fixed
- **The last step dropped you at the main window and left you to find the new scale
  yourself.** That is the same *"now go and do it yourself"* the wizard exists to remove, and
  it lands worse here than anywhere else: the row you are hunting for is one of several that
  all begin `Auto - `. It now opens the window **and selects that scale**, so you arrive in
  the editor on the thing you asked to fine-tune.

The selection goes through the scale list's own click handler rather than assigning state
directly. Selecting a scale also loads it into the editor and repaints the list; `ScaleList`
owns that sequence, and duplicating it here would be a second copy of one rule — which is the
mistake this project has paid for repeatedly.

### Gates
- 46 checks. Mutation-tested two ways: not selecting, and never remembering which scale was
  created. The name is held separately from the plan, because the plan is cleared on commit
  and the done screen still needs to know which scale to open.

## [0.69.0a] - 2026-08-09 — the wizard moves like the rest of the addon

The screens worked but were plain next to everything around them, and the preview's weights
were a single block of text.

### Changed
- **The weight rows cascade in**, one per stat, instead of arriving as one block. A cascade
  is how this addon says *"here is a list, read it in order"* everywhere else, and the
  weights are the substance of that screen.
- **Three step dots**, the current one lit in the wizard's teal. A wizard with no sense of
  position is just a sequence of dialogs; this is the cheapest thing that says *"two more
  clicks"*, which is what someone hesitating over an unfamiliar window wants to know.

### The risk that came with it
Per-stat rows mean a **pool** — WoW never frees a frame, and this screen is shown every time
the wizard runs, so rebuilding the rows would leak for the session. Pools have one classic
failure: a row still showing the *previous* run's stat when a shorter list is displayed.
Here that would mean the preview claiming weights the scale does not have, on the screen
whose entire job is telling you the truth about what it will make.

So the gate drives a full build and then a two-weight one, and requires rows 3–6 to be both
cleared **and** hidden. Mutation-testing it produced exactly the bug being guarded against:
rows reading `Exp 0.90`, `Crit 0.80`, `2HDps 0.75` left over from the previous build, under a
scale with two weights.

### Gates
- `tools/wizarduitest.js`, 45 checks, three new mutations: leftover rows, rows emptied but not
  hidden, and step dots never created.

## [0.68.0a] - 2026-08-09 — running it twice no longer gives you two scales you cannot tell apart

Same gear, same answer — so a second run built a scale identical to the one you already had
and handed it a `(2)` suffix to distinguish two indistinguishable things. That is scale
*accumulation*, not scale management.

### Added
- **The wizard now recognises a scale it already made.** The preview says *"You already have
  this exact scale. I will just switch to it."*, the button changes from **Create it** to
  **Use it**, and committing selects the existing scale instead of creating a twin. The final
  screen says what actually happened rather than claiming to have made something.
- `Valuate:FindMatchingAutoScale(weights, scales)` — matches on weights, both directions, so
  a scale with three extra stats is not called identical to one with three fewer.

### Kept deliberately
- **It does not overwrite the scale it finds.** Only the weights are known to match; you may
  have renamed or recoloured it, and those are yours.
- **A different build still creates.** Owning one generated scale must not block the wizard
  from ever building another.
- **The uniqueness suffix stays**, for the one case it is still needed: the name records only
  the top five stats, so a hand-edited scale can share a name while its weights differ. Reuse
  would be wrong there, and without the suffix the next run would silently overwrite your
  edits.

### Gates
- 67 checks, mutation-tested ten ways.
- That last case is worth recording. Adding duplicate detection **made an existing mutation
  stop failing** — the uniqueness suffix no longer mattered for identical gear, because the
  duplicate path now handles it. A mutation that stops being caught is a behaviour that
  stopped being tested, so the surviving case (same name, different weights, hand-edited)
  now has its own test.

## [0.67.0a] - 2026-08-09 — the wizard stops sounding sure when it isn't

Two honesty bugs on the confirm screen. It is the screen where the wizard asks you to trust
it, so overclaiming there costs more than anywhere else in the addon.

### Fixed
- **"X was close" was said about the runner-up whether or not it was close.** The preview
  named the second-best template unconditionally, including when it had scored far lower.
  `MatchTemplateToStats` now returns the runner-up's **score** as well, and the runner-up is
  only mentioned when it landed within `0.03` of the winner. A hedge you have not earned is
  as misleading as certainty you have not earned.

### Added
- **A weak match now says so.** Below `0.55` confidence the preview adds: *"Your gear is
  mixed, so this is a rough guess. Picking a role below usually does better."* Mixed gear,
  levelling greens and half-finished sets all land there — and those are exactly the people
  who cannot tell a good answer from a bad one, so the wizard has to be the one to admit it.
  It still lets you create the scale; a dead end helps nobody.
- The caution line is **empty when the match was good**. One that is always on screen is one
  nobody reads.

### Gates
- Both rules are tested with constructed cases — identical twins for "genuinely close", a
  lopsided pair for "not close at all" — and mutation-tested three ways: naming the runner-up
  unconditionally, never raising the caution, and always raising it.
- The confident-match assertion is written as the **rule** (`caution is absent exactly when
  confidence is high`) rather than a hardcoded expectation, so it stays meaningful if the
  templates or the threshold move.
- Worth recording: adding two constants to `Valuate.lua` broke two gates immediately, because
  the slice lists that splice this code into the harness did not know about them and they
  compiled to nil globals. That is the upvalue-ordering trap again, and this time the gates
  caught it in seconds rather than the client catching it in a red error.

## [0.66.0a] - 2026-08-09 — the "no scales yet" screen was pointing at buttons that no longer existed

### Fixed
- **The empty state told you to click two things that are not there.** With no scales, the
  list said *"Use **New Blank Scale** below, or **+** to start from a template"*. Both were
  renamed releases ago — to *Blank* and *From Template* — and nobody re-read the one screen
  whose entire job is telling a stuck user what to click. It now points at **Make me a
  scale** and says what that will do.

This is the same drift as the eleven undocumented commands and the discarded heartbeat, but
it lands on the worst possible person: someone with nothing on screen, looking for the
instruction that tells them what to do next, and being sent to a button that does not exist.

### Gates
- `tools/scalelisttest.js` now requires every button the empty state highlights to be a
  button actually on the panel. It extracts the colour-highlighted spans from the text and
  matches them against the real labels, so this cannot rot again — verified by putting the
  old text back, which fails on both `New Blank Scale` and `+`.

## [0.65.0a] - 2026-08-09 — you can find the wizard without knowing it exists

A feature reachable only by a slash command is a feature for people who already read the
changelog. **"Make me a scale"** is now the top row of the Scale List, full width, in the
wizard's teal.

It goes above *Blank* and *From Template* deliberately, extending the argument already
written into that panel. Blank was demoted once because a new user cannot usefully fill in an
empty scale — they do not yet know what their weights should be, which is the entire problem
the addon solves. *From Template* has the same flaw one step further out: choosing between 45
presets still assumes you know which one you are. The wizard is the only entry point on that
panel that answers **that** question for you, so it gets the top row.

### Added
- The **Make me a scale** button on the Scale List, with a tooltip that says what it will do
  and promises it shows you first and never overwrites.
- `/valuate verify wizard` — opens the wizard and tells you how many scales you have, so the
  "closing at the preview leaves nothing behind" promise can be checked in the client rather
  than only in a mock.

### Note
`HookScript`, not `SetScript`, for the new button's hover — the same trap that cost the
wizard's own buttons their hover animation one release ago. `CreateStyledButton` owns
`OnEnter`/`OnLeave`, and replacing them kills the fade on that button alone, which is the
kind of thing nobody notices until the interface just feels slightly wrong.

## [0.64.0a] - 2026-08-09 — the wizard has screens: `/valuate wizard`

The guided scale builder is now usable. Three screens, one decision each.

1. **Make me a scale** — one big *Build it for me*, with Tank / Healer / Damage underneath as
   overrides rather than a quiz you must pass first.
2. **This is what I would make** — the name, what it was closest to, the match percentage,
   the five stats that named it with their weights, and the runner-up when it was close.
   Nothing here is recomputed; it all comes off the plan object, so the preview cannot
   disagree with what gets created.
3. **Done** — it is already your primary scale and your gear is already rescanned. *Close*,
   or *Fine-tune it* to open the editor.

### Added
- `/valuate wizard`, and `ui/Wizard.lua`.

### Gates
- `tools/wizarduitest.js` builds the real screens and clicks through them — 29 checks.
- **Writing that gate caught five bugs in this file**, every one of which passes a parse
  check and a globals check, because each is a real function called with the wrong contract:
  - `Anim.staggerFor` returns the **gap** between items, not a function of the index. Calling
    a number would have errored while laying out the very first screen.
  - `ns.ShowTooltipSafe(frame, anchorType)` *claims* the tooltip; it does not take title and
    body text. The hints would have silently vanished.
  - `Valuate:ToggleUI()` takes no arguments and **toggles** — so *Fine-tune it* would have
    closed the main window for anyone who already had it open.
  - A styled button keeps its text on `btn.label`; the button itself has no `SetTextColor`,
    so the primary action's tint never applied.
  - `CreateStyledButton` installs its own `OnEnter`/`OnLeave` to run the hover fade, and
    `SetScript` was **replacing** them — silently killing the hover animation on exactly the
    buttons that screen is made of. `HookScript` now.
- **The mock did not register named frames as globals**, though the client does — that is how
  `UISpecialFrames` closes a frame by name. Any code doing `_G["ValuateSomething"]` found nil
  and the gate agreed with it. Fixed in `tools/luaharness.js`.
- `settings-anchor-chain` now tracks anchors **per function** rather than per file. Three
  builders each with a `local title` are three different frames, and flagging them is the
  same crying-wolf failure that made `CheckColumnAnchors` useless in the client. Verified it
  still catches a genuine same-function collision.

## [0.63.0a] - 2026-08-09 — the wizard runs end to end, and its own colour

Third piece. The whole path now exists headlessly: read your gear → match a template →
normalise → name it → create it → leave you on a scale that is actually in use. Only the
screens are left.

### Added
- **`Valuate:PlanAutoScale(opts)`** — works everything out and **changes nothing**. Returns
  the name, the weights, the colour, the icon, what it was based on, how confident the match
  was, and the runner-up.
- **`Valuate:CommitAutoScale(plan, scales)`** — the only half that writes.
- **The wizard's own colour: `#3FE0C8`.** Every generated scale takes it rather than the
  matched spec's colour, so you can tell at a glance which scales you made by hand and which
  the wizard made. The icon still comes from the matched spec — the icon says *what it is*,
  the colour says *where it came from*.

### Why plan and commit are separate
A wizard that creates as it goes leaves half-made scales behind when you close it halfway,
and this one is aimed squarely at people who **will** close it halfway. Planning touching
nothing is a property worth a gate rather than a comment, so it has one: after planning, the
scales table, the options table and the rescan counter must all be untouched.

Two smaller decisions in the same spirit:
- The committed scale's weights are **copied, not referenced**. The wizard shows the plan
  again on its last screen, and a shared table would mean a later edit to either silently
  changed the other.
- It ends by making the new scale **primary** and rescanning. Dropping you back at a list
  with a new row to go and select yourself is the point where a wizard stops being one.

### Gates
- `tools/autowizard.js`, 47 runtime checks against the real templates, mutation-tested seven
  ways — including planning that writes, committing that references instead of copying, and
  a second run that overwrites the first.
- The wizard colour is checked against every class and spec colour in `CLASS_SPEC_TEMPLATES`.
  The template list grows, and a collision would quietly defeat the entire point of having
  one colour — so it is checked rather than eyeballed.

## [0.62.0a] - 2026-08-09 — the wizard works out what you are, instead of asking

Second piece of the guided scale wizard, still headless so it can be tested before anything
is drawn. Ascension is classless, so "what class are you" is the wrong question and a
28-entry spec list is the wrong menu. But those 28 templates are hand-tuned weight sets, and
the gear you already wear says which one you resemble — so the wizard can **propose** an
answer and let you confirm it, which is the difference between a wizard and a form.

### Added
- **`Valuate:MatchTemplateToStats(templates, totals, role)`** — compares what you wear
  against what each spec values, by the angle between them rather than the size. A level 20
  and a level 80 in the same *kind* of gear match the same template; raw totals would put
  them nowhere near each other. Returns the runner-up too, so a close call can be shown as a
  close call instead of presented as certainty.
- **`Valuate:NormalizeWeights(weights, floor)`** — rescales so the leading stat is exactly
  `1.0`, rounds to two places, and drops everything under `0.05`.

### Why those two details are not cosmetic
- **Stamina, Armor and Health are excluded from the comparison.** They scale with item level
  rather than with what you are building, and left in they dominate everything: every build
  converges on one template while looking like it is working. The gate buries a caster in
  999999 Stamina and Armor and requires the match not to move.
- **Templates carry weights as low as 0.005** as scoring tiebreakers. Invisible when scoring,
  but they reach the stat editor — and forty near-zero rows is what makes a generated scale
  feel like a mess rather than a build. Normalising takes one real template from 23 rows to
  11.

### Gates
- `tools/automatch.js`, 97 runtime checks against the **real** `CLASS_SPEC_TEMPLATES` rather
  than a fixture — the templates are the entire reason the result is any good, so a fixture
  would let the maths pass while the actual data produced nonsense. Mutation-tested six ways.
- Two mutations initially **survived**, meaning those assertions were decoration: the real
  templates never produce an exact score tie, and their weights all divide evenly, so neither
  the tiebreak nor the rounding was being exercised. Both now have a constructed case. The
  tiebreak matters because without it the winner falls out of the order templates happen to
  sit in — reordering `ui/Data.lua` would silently change what the wizard proposes to
  everyone.

## [0.61.0a] - 2026-08-09 — a generated scale names itself

First piece of the guided scale wizard. Deliberately the piece with a fixed specification and
no UI attached, so it can be tested properly before anything is drawn: a scale the wizard
builds is named from what it actually weights — **`Auto - Str/Crit/Hit/AP/Haste`**.

### Added
- **`Valuate:BuildAutoScaleName(weights)`** — the top five stats by weight, abbreviated,
  highest first. Five is what fits a scale-list row without truncating. Stats the scale does
  not chase are left out: a zero or negative weight does not describe a scale, so a build that
  weights only Strength is `Auto - Str`, not padded to five.
- **`Valuate:BuildUniqueAutoScaleName(weights, existing)`** — scales are keyed by name, so
  running the wizard twice with the same answers would silently overwrite the first result.
  It suffixes instead — `Auto - Str/Crit (2)` — and skips names already taken rather than
  stopping at the first gap. The wizard must never dead-end on something you did not ask about.
- **`ValuateStatAbbreviations`** — a short form for all 51 stats, using what a player already
  writes in chat rather than invented shorthand. The point is that you read the name without
  decoding it.

### Gates
- `tools/autoname.js`, 17 runtime checks, mutation-tested five ways.
- **Ties break on the stat name**, and that is load-bearing rather than tidiness. Equal
  weights are ordinary — a caster template can weight four stats at 1.0 — and `pairs()` order
  is undefined. Removing the tiebreaker in a mutation genuinely produced a different name from
  identical input (`Auto - Int/Hit/Haste/Crit` against `Auto - Crit/Haste/Hit/Int`), which is
  the same class of bug as the active-set tie in `27397e7`.
- Every stat in `ValuateStatCategories` must have an abbreviation, and every abbreviation must
  name a real stat. Two lists of 51, edited at different times — the ninth hand-maintained list
  in this project, gated on the same argument as the other eight. Without it a new stat falls
  back to its full name and you get `Auto - Strength/CritRating/HitRating`.

## [0.60.3a] - 2026-08-09 — the layout checker was crying wolf, and the mock was agreeing with it

Reported from the client: opening Settings printed a red **"two controls share an anchor and
will OVERLAP"** several times over. That message is the addon's own safeguard, and it was
wrong every single time — 13 warnings on a layout with nothing wrong with it.

### Fixed
- **`CheckColumnAnchors` ignored the offset, so it called every section header a bug.** It
  keyed a control's slot on `(relativeTo, relativePoint)` alone. But sharing an anchor is
  normal and deliberate here: each header draws a 2px accent rule at `-2` *and* puts the
  first control a full gap below, both anchored to the header. Those are stacked, not
  overlapping. The key now includes the offset, which is what "the same slot" actually
  means — all 13 false alarms go, and a genuine overlap still fails.
- **The warning didn't say which controls.** In a column of forty it left you to find them
  by eye. It now names both, stripped of colour codes: *"Decimal Places:" and "Show Scale
  Value:" in column 1 sit at the same spot*.

A red error that fires on correct layout is worse than no error: it trains you to scroll
past the one message that matters.

### Gates
- **The mock had no frame hierarchy at all** — no `GetChildren`, no `GetRegions`, no
  `GetPoint`, and `CreateTexture` returned a loose frame belonging to nobody. So
  `CheckColumnAnchors` hit its `if not colFrame.GetChildren then return 0` guard and
  reported a clean bill of health while the client printed 13 warnings. `tools/luaharness.js`
  now models it: frames register with their parent, font strings and textures register as
  *regions*, and `GetPoint`/`GetNumPoints` read back what `SetPoint` recorded.
- Regions are **not** children — the client's `GetChildren` returns frames and `GetRegions`
  returns regions, with nothing in both. Getting that wrong first made every region collide
  with *itself*, which read as 40 more layout bugs that did not exist.
- `tools/settingstest.js` now asserts the panel builds with zero collisions, mutation-tested
  two ways: two checkboxes anchored to the same sibling at the same offset (1 collision), and
  the accent rule moved into the first control's slot (6).

## [0.60.2a] - 2026-08-09 — a setting the snapshot saved, counted, and then threw away

Checking another documented promise, this time "a settings snapshot lets you set up once and
load anywhere". The snapshot itself is well built — it iterates every option and uses an
*exclusion* list, so options added later are carried automatically rather than needing to be
remembered. The hole was on the other side.

### Fixed
- **Your minimap button's position was saved into the settings snapshot, counted in the
  total it reported, and then silently dropped when you loaded it.** `LoadSettingsSnapshot`
  only applies keys that exist in `DEFAULT_OPTIONS`, and `minimapButtonAngle` was never
  declared there — it was created the first time you dragged the button. So you positioned
  the button, saved a snapshot, loaded it on an alt, and got the default position while
  every other setting transferred. The count had told you it was included.
- **Nothing applied the minimap options once they changed.** Position and visibility are
  read when the button is *created*, and `ShowMinimapButton`/`HideMinimapButton` **write**
  the option rather than applying it — they're the user's action, not the appliers. So
  loading a snapshot or restoring defaults moved the setting while the button stayed put,
  and the two only agreed again after a `/reload`. New `Valuate:ApplyMinimapButtonOptions()`
  makes the button match the options; both paths now call it.
- **`showUpgradeArrows` was declared twice in `DEFAULT_OPTIONS`.** Both copies said `true`,
  so nothing was broken — but Lua keeps the last one, which means editing the first line
  would have been a no-op that reads as a fix.

### Added
- `/valuate verify buttonoptions` — moves the button to the opposite side of the minimap and
  back, so the no-reload behaviour can be confirmed in the client.

### Gates
- `tools/options.js` gained three checks, each mutation-tested: a key declared twice; a key
  written into the saved options table but never declared (the bug above, caught exactly);
  and a `SNAPSHOT_EXCLUDED` entry naming an option that no longer exists — an exclusion that
  protects nothing while hiding that the real key is unprotected.
- One deliberate exemption, with a reason: `characterWindowScale` has no honest default,
  because it names a scale and "unset" is a real state its readers test for. Declaring it as
  `""` would not express that — an empty string is truthy in Lua, so every `if scale then`
  check would start passing.
- `tools/minimaptest.js` drives the new applier: a changed angle moves the button, and a
  snapshot that hides or shows it takes effect immediately. 21 checks.

## [0.60.1a] - 2026-08-09 — `/valuate report` was collecting an outcome and discarding it

### Fixed
- **Auto-accept quests recorded its outcome every time, and nothing ever displayed it.**
  `questAccept` had a heartbeat from the day the feature shipped and was never added to the
  report's list. That's the worst version of this problem: not missing data, but data
  collected and thrown away — nobody notices, because the recording side looks correct.

### Added
- **Heartbeats for the three automations that had none**: auto-roll, auto-repair, and quest
  reward selection. The report claims to say *when each automation last ran and what it
  concluded*; for those three it could not say anything at all.
- Each records the **outcome**, not just the time — `"Need on [Item]"`, `"could not afford
  3g 40s"`, `"took [Item]"`. Auto-repair records the case where it *couldn't* pay, because
  "ran and correctly did nothing" is a different answer from "never ran", and a chat line
  scrolls away.
- Quest reward selection records **which** reward it took. That action is irreversible, so
  "something was taken" is not a useful thing to be told afterwards.

### Development
- `tools/commands.js` now also checks that **every recorded heartbeat is displayed**, and
  that the report doesn't list automations which never record one — those would read *"not
  yet this session"* forever, which is a lie by omission.
- Mutation-tested both directions; removing the `questAccept` line reproduces the original
  bug exactly.
- That's the **ninth** hand-maintained list here to drift, and the second found by checking a
  README claim rather than reading code. *"Every automated path has a diagnostic that explains
  why it did nothing"* is now true for all nine.

## [0.60.0a] - 2026-08-09 — `/valuate help` was hiding every command that deletes things

### Fixed
- **The in-game help listed 19 of 30 commands**, and the missing eleven were not an even
  spread. They were the automation toggles and **every command that deletes or sells** —
  `autodelete`, `deletenow`, `sell`, `sellnow`, `repair`, `roll`, `accept`, `notify` — plus
  **`deletepreview`**, which is the command the addon itself tells you to run before enabling
  deletion.
- Someone reading `/valuate help` in the game could not discover that any of it existed. The
  README documented them, which is not where you look when you're standing at a vendor.
- They're now listed in two labelled groups — *Automation (all off by default)* and *Bags and
  merchants* — with `deletepreview` highlighted, because it's the one that answers "what
  would this actually do to my bags" before anything is switched on.
- `valuesource` was undocumented too, and I didn't know it existed until the gate said so.

### Added
- **A thirty-first gate, `tools/commands.js`.** `options.js` has long checked that every
  *option* is reachable; commands had no equivalent, and the same rot set in. This is the
  eighth hand-maintained list here to drift, and the argument is unchanged: the list is
  edited far less often than the thing it describes, so the drift is structural rather than
  careless.
- Commands are **discovered from the dispatcher**, not listed — a hardcoded list would be the
  exact problem the gate exists to catch. Three deliberately-hidden commands each carry a
  reason, and a stale exemption is itself a failure.

### One thing worth admitting
- My first version of the gate reported `deletepreview` as undocumented **because I'd
  coloured it orange** — the pattern didn't allow a colour code before `/valuate`. A gate that
  punishes the emphasis you put on the safety command gets the emphasis removed rather than
  the gate fixed. Fixed the pattern.

## [0.59.0a] - 2026-08-09 — Everything that breathes now breathes at one rate

### Fixed
- **Four things in this addon pulse, and they ran at 1.3, 1.3, 1.6 and 1.3 seconds** — the
  upgrade-arrow glow, the minimap attention pulse, the upgrade popup's icon glow, and the
  AdiBags marker. Three agreed by coincidence; one differed with nothing written down to say
  why. They now share **`MOTION.pulse`**.
- Several things pulsing at slightly different rates is the *"motion that varies without
  meaning"* the MOTION table exists to stop. It reads as an interface assembled rather than
  designed — the sort of thing you feel without being able to name.
- `MOTION.pulse` is also published as **`Valuate.PulsePeriod`**, because `Valuate-AdiBags` is
  a separate addon that can't see `ns` and was carrying a copy of the number. A copy is how
  the popup ended up at 1.6, and a rhythm that's only *coincidentally* shared isn't shared.

### Added
- **A seventeenth lint rule, `no-raw-motion-duration`.** `ARCHITECTURE.md` claimed durations
  come from `ns.MOTION`; nothing checked it, and it wasn't quite true.

### Two things the rule caught that I hadn't
- **A fourth pulse site.** My manual audit found three because I only looked inside the
  `Valuate` folder. The rule scans the sibling addons too and found the AdiBags one
  immediately — the same lesson as `backup.js` finding an addon that had never been backed up.
- **My own refactor made the code less checkable.** The popup's period was
  `2 * math.pi / 1.6`, which the rule caught; rewriting it as `local period = …` moved it out
  of the rule's sight, and a mutation run showed the "fixed" code could take its divergent
  rhythm straight back. **Naming a magic number doesn't stop it being one.** The rule now
  covers that shape, and carries self-check samples like `no-retail-only-api` — the negatives
  especially, since a named constant with a comment is the sanctioned escape hatch and
  flagging those would push people toward inlining numbers to keep the build quiet.

## [0.58.1a] - 2026-08-09 — Backing up the three addons that exist on one disk

### Added
- **`node tools/backup.js`** — discovers which sibling `Valuate-*` addons have **no git
  remote** and writes a verified git bundle for each. `git clone <name>.bundle` restores the
  full history. Not a gate: gates only read, and this acts.

### Why now
- Last release put a **behavioural bug fix** into `Valuate-PassLoot`, which has no remote. It
  sat in exactly one place. That's a fix one accident from gone, and it's the second time this
  session I've flagged the risk without reducing it.
- The existing bundles were written **by hand on 29 July and not again until today**. By then
  `Valuate-AdiBags` was **eight commits ahead** of its backup and PassLoot one. A thing you
  have to remember to do is a thing that stops being done — the same argument behind every
  self-discovering list in this toolchain.

### The part that justifies discovery over a list
- **`Valuate-TSM` had never been backed up at all.** 2,208 lines, five commits, no remote, no
  bundle. The hand-kept approach missed it entirely because I only ever thought about the two
  I'd been told about. The tool found it on its first run.
- All three bundles now verify as complete, restorable histories — checked rather than
  assumed, because a bundle that doesn't verify isn't a backup.

### Still outstanding
- This is a **stopgap**. Two private GitHub repos would end the problem; a bundle only helps
  if the disk it's on survives. Creating them needs a person — `gh` isn't installed here, and
  it isn't something a script should do on someone's behalf.

## [0.58.0a] - 2026-08-09 — Equip All tells you what it's about to change

### Added
- **The Equip All tooltip now lists the slots it would change**, with a count — up to eight,
  then "…and N more". If there's nothing to do it says so, rather than leaving you to press
  it and find out.
- A button that changes several slots at once shouldn't need to be pressed to discover how
  many. *"6 slots"* tells you the size of the change; the **names** tell you whether it's the
  change you meant.

### Deliberately not a confirmation dialog
- Equipping is **reversible** — the gear you took off is still in your bags — so gating it
  behind a confirm would be friction on a button you might press every few levels. The useful
  thing here isn't an extra click, it's knowing what's about to happen while you're already
  looking at it. Compare deletion, which *is* gated, because it can't be undone.

### Implementation
- The list is collected in the row loop that already reads every slot's best and what's worn.
  Recomputing on hover would cost what a scan costs, on a mouse move.
- **Compared by item ID, not by link.** Two links for the same item differ by enchant and
  suffix, so a link comparison would report every slot as changing — a lie in the safe
  direction, which is still a lie, and the kind that reads as the feature not working.
- The predicate mirrors `EquipBestSet`'s skips exactly: locked slots, bank items it can't
  reach, anything already worn. I checked the two against each other rather than assuming —
  same 17 slots, same three rules, same ID comparison. `/valuate verify equipcount` exists
  because they are two pieces of code stating one rule, and only a person can watch the
  predicted count meet the real one.

## [0.57.1a] - 2026-08-09 — The last uncovered integration, and an honest null result

### Development
- **A thirtieth gate, `tools/tsmratiotest.js`**, covering `UpgradePercent` and `ComputeRatio`
  in `Valuate-TSM` — the maths behind the *upgrade* and *upgrade per gold* columns in TSM's
  shopping results. That's the last integration with no runtime coverage.
- **No bug found.** This code was written carefully and handles every trap I went looking
  for: a zero baseline returns `math.huge` (an empty slot is an *infinite* improvement, and
  must never be filtered out for being a small one), a zero or negative buyout is refused
  rather than divided by, and `math.huge` can't reach the ratio because `PrimaryValue`
  returns the delta, not the percentage. Worth saying plainly in a session where most of
  these audits found something.
- The gate exists because these are **divisions in display code** — the shape that produced
  three real bugs here already — and because a wrong answer sorts a shopping list, which
  means it decides what you buy.

### A mutation result worth recording
- Two of the four mutations **weren't caught**, and the interesting part is why. Removing
  *either* zero-price guard changes nothing observable, because the other one still catches
  the case. They're **equivalent mutations, not test gaps** — I confirmed it by removing
  **both**, which fails three checks.
- So the guards are individually redundant and jointly load-bearing. That's defensible
  belt-and-braces, not dead code, and it's now the sort of claim that has evidence behind it
  rather than a shrug.

## [0.57.0a] - 2026-08-09 — The PassLoot Upgrade rule stops firing on data it doesn't have

### Fixed
- **`Valuate-PassLoot`'s Upgrade rule matched everything on a character that had never been
  scanned.** Two of its exits returned *"yes, this is an upgrade"* when Valuate simply had no
  data — no best-equipment table at all, or none for the scale the rule names.
- A PassLoot rule matching means PassLoot performs whatever action you configured for it, and
  the usual configuration is **"if Upgrade then Need"**. So a false match is a Need roll on
  something that isn't an upgrade — the exact failure the core addon's auto-roll is built to
  make impossible (v0.53.1a: *"never Need on something we do not want"*). The integration was
  contradicting the addon it integrates with, in front of other people.
- Failing open is the wrong direction when the failure is social and the fix is one
  `/valuate scan`. Both now decline, and say which in the debug log.

### What did NOT change, and why
- **"Scanned, but nothing tracked for this slot" still matches.** That one isn't missing
  data — it's knowledge: you own nothing better for that slot, so the item genuinely *is* an
  upgrade. Conflating "we don't know" with "we know there's nothing" is what made returning
  yes for all three look reasonable.
- That distinction is a mutation in the gate, not just a comment: making that case decline
  fails two checks. Applying *"uncertainty declines to act"* to all three exits would have
  been the obvious move and the wrong one.

### Development
- **A twenty-ninth gate, `tools/passloottest.js`** — 16 checks on `module:UpgradeVerdict`,
  extracted from the middle of `GetMatch` so the four exits could be stated at all.
- Mutation-tested four ways: each never-scanned case returning yes again, the
  nothing-tracked case declining, and an equal score counting as an upgrade.
- Also pinned: an **equal** score is not an upgrade (a sidegrade costs the same socially as a
  worse item, and you already have one), and the comparison works across zero, since a scale
  can carry negative weights.
- Like `surplustest.js`, the source is in a sibling addon with **no git remote** — this gate
  skips rather than fails when it's absent, and is currently the only thing guarding it.

## [0.56.1a] - 2026-08-09 — What's waiting behind the item you already have

### Added
- **A Best Equipment row's tooltip now names the future item for that slot**, with the level
  it needs.
- The panel already drew future items — but **only when there was no equippable best at
  all**. While levelling that's the rare case: you have *something* in every slot, so
  anything waiting sat invisible behind it, in the one panel you'd plan gear from. A row can
  only draw one item; its tooltip can mention both.
- It doesn't invent a level either. When something other than a level is in the way, the line
  says *"waiting for this slot"* and leaves the number out — the same rule the item tooltip's
  future line follows.

### Notes
- **I was wrong about this before I looked.** I assumed the panel ignored future items
  entirely; it handles them carefully — dimmed icon, `Lv 42` in the comparison column, a
  tooltip covering the unlearned-proficiency case. The gap was narrower and more specific
  than the one I set out to fix, and only visible after reading the code.
- **This line is not gated**, and that's worth saying in a release where most things are. It
  lives inside a closure that needs the whole panel built and an `OnEnter` fired; the risk is
  a print statement reading data three other places already read correctly.
  `/valuate verify futureslot` covers it.
- Recorded in `CLAUDE.md`: **three places now describe a future upgrade**, each independently
  implementing "never name a level when `reqLevel` is 0", all three currently right. Their
  output genuinely differs — a column label, a paragraph, a one-liner — so a shared helper
  would be thinner than the duplication. If a fourth appears, extract the predicate.

## [0.56.0a] - 2026-08-09 — A still blue marker for gear you can't use yet

### Added
- **Future upgrades now get a marker on the bag icon**, alongside the green upgrade arrow.
  Last release's tooltip line only helps if you hover; in a full bag you still couldn't see
  which items were worth keeping without checking each one.
- **Green pulses, blue doesn't.** Movement is the loudest thing a bag icon can do, and it
  belongs to the marker you can act on. A future marker pulsing alongside would be asking for
  attention it can't reward — you'd look, find the item unequippable, and learn to ignore
  both.
- Same textures, recoloured, one marker per button. An item is either equippable-and-better
  or not-yet-equippable, never both — so that isn't a simplification, it's the shape of the
  data.
- **Levelling into an item turns its marker green in place**, and that gets the usual pop-in:
  it's the moment the item changed meaning.

### Implementation
- The upgrade check runs **first**, so a bug in the future lookup can never take a green
  arrow away from something you can actually equip.
- The still-marker branch lives **inside the one driver loop** rather than as an early return
  of its own. That's not style: the Reduce Motion path was once a second loop that returned
  early and forgot to prune, and it leaked for a whole session (v0.45.1a).

### Development
- 11 more checks in `arrowtest.js` (28 total), including that the pulse and the stillness are
  measured **over the same frames** — otherwise the test can pass by having looked at the two
  markers at different moments.
- Mutation-tested three ways: future markers pulsing, the future check running first and
  stealing green from a wearable upgrade, and both modes sharing a colour.
- One test bug of my own, fixed: the pruning check used a global count while two earlier
  buttons were still on screen, so it was asserting about them. It now asks about the two
  buttons it actually hid.

## [0.55.1a] - 2026-08-09 — Making the in-game pass smaller instead of longer

### Changed
- **`/valuate verify` now says which checks a build gate already proves the logic for**, and
  **`verify next` hands out the ungated ones first.** Eight of the twenty-one are backed by a
  gate that executes their logic on every commit; for those, the in-game step is "does it
  look right", a much smaller ask. The other thirteen are the only evidence those behaviours
  will ever have.
- Twenty-one checks is a long sitting and it may stop half way. If it does, the half that got
  done should be the half nothing else covers — so the walkthrough front-loads those. Order
  within each group is preserved, so it stays predictable.
- The summary now states the split honestly rather than one total.

### Fixed
- **`README.md` said the verify list was "short on purpose".** It was, once. It is 21 checks
  now, five of them added this session, and calling that short is the same kind of drifted
  claim the gates exist to catch — with the added problem that a list described as short and
  observed to be long is one you stop believing.
- The Status section had grown into a 23-item run-on sentence. Regrouped into what the gates
  actually cover: **things that can destroy or spend something**, **panels driven the way a
  user drives them**, and **pure logic whose wrong answer still looks plausible**.

### Development
- A `gate = "tools/…"` field on a check is a claim that it is safe to treat as smaller — so
  `tocsync.js` now fails if the named file does not exist. A wrong claim there is worse than
  none, because it makes a check look skippable.
- 8 more checks in `verifytest.js` (24 total) on the new ordering, including that a **stale
  gated** check does not jump the queue. Mutation-tested: reverting to plain list order fails
  the two checks that name it.

## [0.55.0a] - 2026-08-09 — The tooltip finally says why it's been keeping that item

### Added
- **A future-upgrade line on item tooltips**: *"Upgrade at level 42 for: Melee, Tanking"*.
- **The addon has been acting on this for a long time without saying so.**
  `IsProtectedFromDelete` keeps future upgrades, so auto-delete has been sparing these items
  since the feature existed — and `GetFutureUpgradeScales` was called from *exactly one
  place*, that protection. The knowledge existed, it changed behaviour, and it never reached
  you. The moment it matters is at a vendor with a full bag, hovering the thing and deciding.
- Reports the **level**, not just the scales, because "keep this" and "keep this for eleven
  more levels" are different decisions. Where two scales disagree, the **lowest** requirement
  wins — it's one item, and the earliest level is the true answer.
- **It never invents a level.** When the item is held back by something a level won't fix —
  an untrained proficiency, most often — the line drops the promise and says *"upgrade once
  you can use it"* rather than printing *"at level 0"*. A tooltip naming a level you passed
  twenty levels ago reads as a bug and teaches you to distrust the rest of it.
- Best-in-slot and future-upgrade lines can never both appear: equippability is
  item-intrinsic, so an item is one or the other.

### Development
- **A twenty-eighth gate, `tools/futurelinetest.js`** — 17 checks on what the line *claims*.
  Mutation-tested three ways: printing "at level 0", taking the highest requirement instead
  of the lowest, and reading whatever future record came first instead of matching on the
  item.
- `/valuate verify futureline` covers the half no gate can see — and specifically the failure
  worth looking for: the line **not** appearing on an item `/valuate future` does list, which
  would mean the tooltip and the delete protection disagree about the same item.

## [0.54.0a] - 2026-08-09 — See what's waiting, and at what level

### Added
- **`/valuate future`** — everything in your bags and bank that will become an upgrade,
  grouped by the level that unlocks it, with how far away each one is. The data has existed
  since future upgrades did; nothing ever let you *look* at it. The level-up announcement
  tells you what just became wearable, which is right at that moment and no help when you're
  deciding whether a piece is worth carrying for another eight levels.
- An item that's a future upgrade for three scales is **one line naming three**, not three
  lines. Where two scales disagree about the requirement, the **lowest** wins — it's the same
  item, and the earlier level is the true answer to "when can I wear this".
- **Items whose level you already meet are listed separately**, under *"high enough level,
  but still not wearable"*. An item can sit in the future list for reasons a level doesn't
  fix — an unmet weapon proficiency, most often — and reporting those as "you'll get this at
  20" would be a promise the addon can't keep. `AnnounceUnlockedUpgrades` already draws that
  distinction by rescanning rather than trusting `reqLevel`; this draws it by saying so.

### Development
- **A twenty-seventh gate, `tools/futuretest.js`** — 26 checks on `GroupFutureUpgrades`,
  which is pure: scan results, active scales and a level in; two sorted lists out.
- Mutation-tested four ways: no split between waiting-on-level and blocked, the *highest*
  requirement winning a disagreement, de-duplicating by slot instead of item link, and an
  item exactly at your level counting as future.
- Three `sort-needs-tiebreaker` suppressions, each with the reason on the line: both tables
  are keyed by the value being sorted on, so no two entries can tie and the comparators are
  already total. That's what the escape hatch is for.
- One test guard added after a mutation run: with the split broken, `blocked[1].link` died
  with an index error instead of naming the problem. **A gate that crashes is worth less than
  one that says what went wrong** — third time this session that's needed fixing.

## [0.53.2a] - 2026-08-09 — The quest reward choice, which cannot be taken back

### Development
- **`ChooseQuestReward` pulled out of `AutoSelectBestQuestReward` and gated.** A quest reward
  is **irreversible** — the moment one is taken the others are gone — and with auto turn-in
  on, this runs without asking. That puts it with the deletion protections, not with the
  display code, and it was the last automated decision still embedded in a loop that also
  talks to the client and paints a highlight.
- The safety rule is the same shape as the surplus-gear one: **nothing scored and more than
  one choice means pick nothing.** All rewards being bags or consumables is not a reason to
  guess; the quest window is still open and the player can decide. One choice is not a
  choice, so pre-selecting it costs nothing.
- Also pinned: **an upgrade beats a bigger raw score.** A strong weapon you'll never beat
  your current best with should lose to a modest trinket that fills an empty slot — that's
  the whole reason this isn't "highest number wins". And a delta of exactly zero is *not* an
  upgrade.
- **Ties go to the lowest index**, asserted over repeated runs. An irreversible choice must
  not depend on the order a table happened to be built in.
- 17 checks. Mutation-tested four ways: guessing when nothing scored, ignoring upgrades in
  favour of raw score, ties resolving to the last index, and treating a zero delta as an
  upgrade.

### Notes
- **No behaviour changed.** As with the auto-roll last release, the decision was already
  right — it just had nothing keeping it that way, and couldn't be stated without reading
  twenty lines of loop.
- That's now **every automated action in the addon** — delete, sell, surplus-marking, roll,
  quest reward — with its policy named and its safety rule asserted.

## [0.53.1a] - 2026-08-09 — The auto-roll decision, stated as two promises

### Development
- **`DecideRollType` pulled out of `AutoRollOnLoot` as a named function**, and gated. This
  decision is taken automatically, in a group, on your behalf, and **other people see the
  result** — but it was a branch sitting between a tooltip parse and a live `RollOnLoot`
  call, where it couldn't be stated or tested.
- Two properties carry the weight, and they're now assertions rather than reading:
  - **Never Need on something we don't want.** Needing on gear you can't use is what people
    get removed from groups for, and nobody asked you before it happened.
  - **Never Pass when Greed is available.** Passing costs you the item and gains nobody
    anything; if the addon acts by itself, the floor is "no worse than Greed".
- Three booleans is **eight cases, so they're enumerated rather than sampled** — the lesson
  from the tooltip percentage, where hand-picked cases missed the branch that mattered. Both
  properties are asserted over every one of the eight, so a fourth flag added later can't
  slip past them.
- 38 checks. Mutation-tested three ways: Needing whenever Need is offered (the social
  disaster), Passing instead of Greeding on something we don't want, and the printed label
  disagreeing with the roll actually sent — a chat line that lies about what it just did on
  your behalf.
- Also pinned: `nil` is not `true`. Those flags come straight from `GetLootRollItemInfo`, and
  a nil `canNeed` has to read as "not offered" rather than sneaking through a truthiness
  check.

### Notes
- **No behaviour changed.** The decision was already correct; it just had nothing keeping it
  that way, and it was the last automated action in the addon in that position.

## [0.53.0a] - 2026-08-09 — The one uncovered decision that could delete gear

### Development
- **A twenty-fourth gate, `tools/surplustest.js`**, covering `ComputeSurplusGear` in
  `Valuate-AdiBags` — the last untested decision in the project that can end in gear being
  **deleted**. "Mark surplus gear as junk" routes anything that is neither best-in-slot nor a
  future upgrade into AdiBags' Junk section, and that section is what auto-delete and
  auto-sell consume. A wrong *yes* here isn't a mislabelled bag icon; it's an item destroyed.
- The asymmetry is the design, so the checks are about the asymmetry: **every uncertainty
  must answer no.** No trustworthy best-in-slot data yet, item not in the client's cache,
  Valuate has no opinion about the slot, part of a saved equipment set, above the quality
  ceiling, excluded from evaluation, unknown quality — nine separate ways of not being sure,
  each turned on one at a time against a baseline that does answer yes.
- Also pinned: an **empty** best-for list must *not* protect. Those helpers return a table,
  `if best then` is true for `{}` in Lua, and a naive check would protect every item ever
  asked about — the feature would silently do nothing. Opposite mistake to the dangerous one,
  equally invisible.
- Mutation-tested four ways: dropping the best-data guard, the truthy-empty-table trap,
  making the quality ceiling exclusive, and un-protecting equipment-set members.

### Notes
- **The source lives in a sibling addon, not in this repository.** That's unusual for a gate
  here and worth knowing before trusting a green run. On a machine with only Valuate checked
  out this **skips** rather than fails — a gate that failed for being unable to find optional
  code would train people to ignore it.
- `Valuate-AdiBags` still has no git remote, so this gate is currently the only thing
  guarding any of it.
- The slice had to be made CRLF-tolerant: the integration addons ship with Windows line
  endings and tab indentation, unlike the core, so the `\nend\n` anchor every other sliced
  gate uses found nothing.

## [0.52.1a] - 2026-08-09 — One search box, three users, one Escape

### Fixed
- **Escape behaved differently in each of the three search boxes.** Settings cleared the text
  on the first press and released focus on a second; the Scale Editor's stat search did both
  at once; the icon search cleared if there was anything and always released. Three
  behaviours for one key, in one addon — and two of them were written by me, two releases
  apart.
- They now share **`ns.CreateSearchBox`**, which keeps the two-stage version. Not because it
  was first: while an EditBox has focus it **swallows Escape**, so a box that releases focus
  in the same press as it clears leaves you no way to clear a search and *then* close the
  window with a second press.
- The hint now hides on **focus**, not just on text. A placeholder sitting under a blinking
  caret reads as text you have to delete.

### Implementation
- What's shared is the chrome, the hint and the keys. What isn't is the filtering — Settings
  walks a derived index, the stat grid dims rows, the icon picker rebuilds a list — so the
  caller supplies that through `onQuery`. Those parts *should* differ; the keys shouldn't.
- Removed a second writer in passing: the icon picker's reopen path was setting the hint
  itself, which `SetText` already handles through `OnTextChanged`.

### Development
- 14 more checks in `widgettest.js` (86 total). Mutation-tested three ways — and **two of the
  mutations are the exact variants that existed before this release**, each now failing.
- **The mock's `SetText` now fires `OnTextChanged` on an EditBox, as the client does.** Real
  code leans on this: the icon picker clears its search on reopen with a bare `SetText("")`
  and relies on the resulting event to restore the full grid. A mock that swallowed it would
  make working code look broken here — or worse, invite someone to "fix" the code to match
  the mock.

## [0.52.0a] - 2026-08-09 — Search the icon picker

### Added
- **A search box in the icon picker.** There are **577 icons** in an eight-wide scrolling
  grid; finding one meant scrolling past all of them. Type `sword`, `frost`, `potion` — the
  grid filters as you go. Same problem the Scale Editor's stat grid had at a tenth of the
  size.
- The **"no icon"** entry is kept out of the filter rather than dropped, so clearing a
  scale's icon is still possible while a search is active.
- A search matching nothing **says so** instead of leaving an empty grid that reads like the
  picker failed to load.
- **Reopening starts unfiltered** — the opposite choice to the stat search, which persists.
  That one lives in a panel you keep open while comparing scales; this is a modal picker you
  open to answer one question, and reopening it with someone else's search still active
  would look like a picker that had lost most of its icons.

### Implementation
- The grid draws from a `shownIcons` list rather than `SCALE_ICON_LIST` directly, so
  filtering is a matter of replacing it and recomputing. **Row count, content height and
  scrollbar range move together** in one function: left at the unfiltered length, a
  four-icon result can be scrolled past the end of itself into blank space, and the grid
  looks empty while the search says it matched.

### Development
- **A twenty-third gate, `tools/iconpickertest.js`** — 20 checks. The grid is *virtual*: a
  small button pool is repositioned and re-textured as you scroll. Adding a search means
  that pool now draws from a list that **changes** — the stale-identity hazard this project
  has hit three times, and here it means clicking a sword and getting whatever used to be in
  that position.
- So the assertions are all *"what a button carries matches what it shows"*, checked after
  scrolling **and** after filtering, rather than "the filter returned N results".
- Mutation-tested three ways: a button carrying the unfiltered icon, the scroll range left
  unshrunk, and a reopen keeping the previous search.
- **My first mutation run missed one of those.** The scroll-range mutation passed because the
  test never scrolled *after* filtering. Second time this session a mutation run has found a
  gap in my test rather than in the code, which is the argument for running them at all.

## [0.51.1a] - 2026-08-09 — A latent trap in the character-sheet score, removed

### Fixed
- **One branch of `UpdateCharacterWindowDisplay` returned without releasing its re-entrancy
  guard.** That flag is tested on the function's *first line*, so leaving it set wouldn't
  produce a wrong number — it would stop the character-sheet score updating **at all**, for
  the rest of the session, with no error and nothing on screen to say why. A `/reload` is the
  only way out and nobody would know to try one.
- Two branches blank the display — "no scales at all" and "the selected scale is not in the
  table" — written as near-identical copies. Only the first cleared the flag. They are now
  one function, so a third caller can't reintroduce half of it.

### Reachability — worth being plain about
- **That branch is unreachable today.** `GetActiveScales` builds its list from the keys of
  `GetScales()`, so the name it hands back is always present in the table a moment later. I
  went looking for a path a user could hit and there isn't one.
- It's still worth removing: the consequence is severe and completely silent, it activates
  the moment `GetActiveScales` gains any other source, and the duplicated pair it came from
  had already diverged once. This is a trap being defused, not a bug being reported.

### Development
- **A twenty-second gate, `tools/charwindowtest.js`** — 9 checks, and every one blanks the
  display and then asks for a *real update*, because a test that only inspects the blank
  state passes with the guard stuck. It also runs the same sequence twice, since a guard
  released by luck rather than design shows up on the second pass.
- Mutation-tested: restoring the missing release fails three checks, all of them
  "the score never comes back".
- `HookScript` joins the mock, modelled properly as **adding** to a handler rather than
  replacing it — that's the whole reason addons use it on Blizzard frames, and a replacing
  mock would let a gate pass while the real client ran two handlers.

## [0.51.0a] - 2026-08-09 — Find a stat without reading all sixty

### Added
- **A search box in the Scale Editor header.** The stat grid is around sixty rows across five
  columns; finding the one you want meant reading all of them. Settings solved this for a
  smaller list a while back — the editor is where it actually hurts.
- Matches the **label or the internal name**, so someone who knows the data can type
  `TwoHandDps` without guessing what it's called on screen. Case-insensitive, Escape clears
  it, and a count (`4/76`) sits beside the box — or **"no match"**, so an entirely dim grid
  doesn't read as a rendering fault.
- **Dims rather than hides**, like the Settings search and for a stronger reason: this is a
  fixed five-column grid built from static category tables, so hiding rows would leave holes
  or force a relayout of all sixty on every keystroke.
- **The filter survives switching scales.** The rows are pooled and repopulating never
  touches alpha, so the dim persists by itself — clearing the query while the grid stayed
  dim would leave the box and the grid disagreeing.

### Implementation
- Dimming writes the **row's alpha**, deliberately not its text colour. `ApplyWeightedLook`
  already owns the label colour and the input border — it's what marks a stat that carries a
  weight — and a second writer on one property is the fault this codebase keeps finding.
  Alpha is uncontested, so the two compose: a weighted stat that matches your search still
  reads as weighted.
- **Instant, with no tween.** This runs on every keystroke; an animated filter would still be
  catching up with what you typed three characters ago.

### Development
- **A twenty-first gate, `tools/statsearchtest.js`** — builds the real grid (76 rows) and
  drives the box. Mutation-tested three ways: dimming everything, dimming the containers too
  (which fades whole columns and reads as a rendering fault), and writing the label colour
  instead of alpha.
- The gate asserts the *second* claim explicitly — **that nothing but the stat rows is
  touched** — because containers, column frames and section headers share a table with the
  rows.
- The search box is **named** (`ValuateStatSearchBox`). The first version of the gate looked
  for "the EditBox with an `OnTextChanged` handler" and found a stat weight box: all sixty
  have one, for input validation. It spent its assertions typing into the last row of the
  grid.

## [0.50.3a] - 2026-08-09 — Our colour-picker callback stops answering other addons' cancels

### Fixed
- **`ColorPickerFrame` is Blizzard's and shared with every addon.** Valuate installed `func`
  and `cancelFunc` on it and nothing ever removed them, so they outlived our use of the
  picker. Most addons set `func` before showing it, which displaces ours — but plenty set
  only `func` and leave `cancelFunc` alone. Then someone else's picker is cancelled, **our**
  `cancelFunc` runs, and writes a Valuate scale's colour back to whatever `previousValues`
  we left behind.
- The obvious fix — clear the fields on hide — is the wrong one. 3.3.5's cancel button
  **hides the frame first and calls `cancelFunc` after** (which is why it passes
  `previousValues` explicitly), so clearing on `OnHide` would delete the callback moments
  before it was due to run and break cancel entirely.
- The guard is ownership instead: a callback acts only while our `func` is still the
  installed one. That needs no cleanup and doesn't care what order Blizzard hides and
  cancels in — which matters, because the ordering isn't something I can check from here.

### Honest uncertainty
- **I haven't observed this happening.** It requires another addon to open the colour picker
  setting `func` but not `cancelFunc`, and for you to cancel. That's a common enough shape to
  be worth guarding, but this is a defensive fix, not a reproduced bug — the same footing as
  the `SetColorTexture` sweep.

### Development
- 4 more checks in `scalelisttest.js` (34 total), including that **our own** cancel still
  restores the colour we opened with — a guard that broke the normal path would be worse than
  the hazard. Mutation-tested: removing it lets a foreign cancel clobber the scale.
- **This came from applying the rule written down last release** rather than waiting to trip
  over a third instance. The sweep also checked `ui/Pickers.lua`, which **already** clears its
  callback on `OnHide` — so the icon picker was right all along and the colour picker was the
  only site left.

## [0.50.2a] - 2026-08-09 — The minimap button stops following the cursor after you let go

### Fixed
- **Hiding the minimap button mid-drag left it following the cursor.** The cursor-follow is
  installed on `OnDragStart` and was cleared only by `OnDragStop` — which needs the button to
  still be there. Hide it while dragging (Settings has a toggle, so does `/valuate minimap`)
  and the handler stayed installed. Hidden frames get no `OnUpdate`, so nothing happened
  until you showed it again, at which point it resumed following the cursor with no mouse
  button held.
- **Releasing the button while still hovering it handed back the un-hovered colour**, so the
  button looked un-hovered with the mouse sitting on it until you moved away and back. The
  resting colour now depends on where the cursor actually is, and matches what `OnEnter`
  gives you rather than being a third value.
- Both exits now go through one `EndDrag`, so they cannot drift apart.

### Development
- **A twentieth gate, `tools/minimaptest.js`** — 15 checks on a file that had none. It states
  the general form (*after any way a drag can end, the button is not following the cursor*)
  so a third exit added later has an assertion waiting for it.
- **It also checks the pulse stayed off the frame's `OnUpdate`.** The pulse and the drag once
  shared that single slot and the drag discarded the pulse's cleanup, leaving a starburst
  stuck on at 1.14× scale. The pulse moved to the animation engine's named-property
  ownership; moving it back would silently restore that bug, so now it can't.
- Mutation-tested three ways, all caught: removing the `OnHide` disarm, always restoring
  white, and putting the pulse back on `OnUpdate`.
- `math.atan2` joins `math.pow` and `unpack` in the harness shims — removed in 5.3, present
  in the 5.1 client, so restoring it is matching the target runtime rather than papering
  over anything.

### Notes
- **This is the second time an armed state has outlived its trigger** (the Settings keybind
  capture was the first, three releases ago). Written up in `CLAUDE.md` as a rule rather than
  fixed twice and forgotten: give every arming path an `OnHide`, and assert the general form.

## [0.50.1a] - 2026-08-09 — The confirm dialog is pinned to the question it's asking

### Development
- **A nineteenth gate, `tools/dialogtest.js`.** `ValuateConfirmDialog` is a **singleton** —
  one frame reused for every question the addon asks, including *"delete this scale?"* — so
  its accept button is rebound each time. That's the hazard that kept the scale list unpooled
  for eleven releases, in miniature: a reused control still wired to the previous request.
  Here it would mean clicking **Delete** running the callback from a dialog you already
  dismissed.
- 21 checks. Every case shows a **second** dialog before clicking, because a test that shows
  one and clicks it passes whether or not the rebinding works. Each also asserts the *other*
  callback did **not** run — "the right thing happened" and "only the right thing happened"
  are different claims.
- Mutation-tested three ways, all caught: binding accept once at creation (the stale
  callback), acting before hiding (which also closes a chained dialog opened from the
  callback), and not resetting button labels when a request omits them — that last one leaves
  **"Delete" sitting on a dialog asking something else**, which is how a person clicks it.
- Also pinned: the dialog hides *before* the callback runs, so a callback may open another
  one; cancel never runs `onAccept`; and `HideConfirmDialog` acts on nothing.

### Added
- **A sixteenth lint rule, `no-dialog-oncancel-with-escape`.** `ui/Dialog.lua` registers the
  dialog for Escape-to-close and notes that this is safe *"because no caller passes
  onCancel"*. That is true — I checked — but it's a coupling, not an observation: Escape hides
  the frame without running anything, so the day a caller needs cleanup on cancel, Escape
  starts skipping it silently, on the dialog that asks about deletion. Using `onCancel` now
  requires removing the Escape registration first, which is what the comment already said.

## [0.50.0a] - 2026-08-09 — Clicking the tab you're already on stops jolting the window

### Fixed
- **Re-clicking the active tab replayed its arrival.** `SelectTab` did identical work whether
  you were switching tabs or clicking the one you were already on. On Best Equipment that
  meant snapping the window to `MIN_WINDOW_HEIGHT` and growing it back to fit — so a click
  that changed nothing **collapsed the window and re-expanded it**, the most visible thing a
  no-op could do.
- The staggered column reveals replayed too, and the crossfade blinked the panel you were
  already reading.
- An entrance is for arriving. Playing it when nothing arrived is what makes a UI feel loose.
- A re-click still shows the panel, restyles the buttons and refreshes content, so it remains
  a reasonable way to ask for a refresh — it just doesn't perform the arrival.
- The pinned-opaque path now cancels any crossfade still running first, or the old tween
  overwrites the alpha on its next frame.

### Development
- **An eighteenth gate, `tools/tabtest.js`**, builds the real main window and drives its
  tabs. 15 checks, stated as *arrivals happen on arrival*: reveal and height-reset fire on a
  genuine switch, not on a re-click, and **do** fire again when you leave and come back — the
  guard has to key on the tab changing, not on "have we been here before".
- Mutation-tested: forcing `isSwitch = true` (the old behaviour) fails exactly the four
  re-click checks.
- **`Valuate:ShowUI()` wraps its build in a pcall of its own and reports failure by
  printing**, so it returns success even when the window didn't build. The gate asserts on
  the captured output rather than the pcall result — otherwise it would sail past a
  completely broken window. Noted in `CLAUDE.md`.
- Two fixture traps worth recording: the panels **assign** `RevealBestEquipmentColumns` and
  `RevealSettingsColumns` during the build, so counters installed beforehand are overwritten
  and every assertion silently counts zero. The first run did exactly that.

## [0.49.2a] - 2026-08-09 — Every settings checkbox is checked against the option it owns

### Development
- **The Settings gate now clicks all 27 option checkboxes** and asserts three things per box:
  exactly one option changes, clicking again puts it back, and — the important one — the
  option it *writes* is the option it was *drawn from*.
- **That third check exists because the first two aren't enough.** A settings panel is dozens
  of near-identical controls built by copy-paste, and the failure that shape produces is a box
  wired to its neighbour's key: the box ticks, something saves, and the feature you meant to
  switch on stays off while an unrelated one changes. Exactly one option still moves and it
  still toggles back. It was caught **passing** during a mutation run, which is how the check
  came to exist.
- The panel supplies the missing half itself: every box initialises with
  `SetChecked(GetOptions().someKey == true)`, so a recording proxy on `GetOptions` says which
  key each box read. Mutation-tested three ways — wired to a neighbour (*"drawn from
  autoSellJunk, wrote autoRepair"*), writing two options, and writing `true` one-way.
- **Result: no wiring bugs.** 27 checkboxes verified, 107 checks, no false positives on
  correct code — which is only worth saying because the sweep is proven to catch all three.

### Fixed (in the fixture, not the addon)
- The first run of this sweep reported **23 failures, all of them mine**: the stub options
  table started most keys `nil`, so a round trip ending in `false` read as "didn't toggle
  back". The addon guarantees every key exists at load. The fixture now slices the real
  `DEFAULT_OPTIONS` out of `Valuate.lua`, so it tests a state the addon actually runs in and
  a newly added option can't quietly fall out of coverage.

## [0.49.1a] - 2026-08-09 — The Settings panel gets runtime coverage

### Development
- **A seventeenth gate, `tools/settingstest.js`, builds the whole 2,232-line Settings panel
  and drives its keybind button.** That file had no runtime coverage at all and was the
  largest blind spot left; last release's two keybind bugs were found by reading it, which
  is not a method that scales.
- **Both of those bugs are now caught mechanically.** Mutation-tested: restoring the
  right-click-clear-without-releasing fails with *"a key pressed afterwards is not silently
  bound (got VALUATE_TOGGLE_UI, wanted nil)"* — the shipped bug, stated as an assertion.
  Restoring the missing `OnHide` disarm fails the two checks that name it.
- 23 checks, all ending on **"did the keyboard get handed back"**, because that is the
  property that matters rather than which key ended up bound.
- The button is found by looking for the only frame in the panel with an `OnKeyDown`
  handler, so inserting a control above it cannot silently redirect the gate.

### Notes
- The line I said I'd keep, kept: the client's **dropdown API and a few EditBox methods**
  went into the shared mock, because those are what a client provides. The addon's own
  `Valuate:` methods are stubbed **in the gate**. Pushing addon API into `luaharness.js`
  would make all twelve runtime gates test against a more imaginary client than they do now.
- This is the piece of work I deliberately stopped half-way through last release rather than
  ship a fixture that read as coverage without being it.

## [0.49.0a] - 2026-08-09 — The keybind button lets go of your keyboard

### Fixed
- **Right-clicking the Toggle UI keybind button to clear it never ended the capture.**
  Right-click clears regardless of state, so doing it while the button said *"Press Key..."*
  left `isCapturingKeybind` true and the keyboard still enabled: the next key you pressed was
  silently bound, the button stayed capture-blue, and its hover styling stayed suppressed
  because both `OnEnter` and `OnLeave` skip themselves mid-capture.
- **Nothing ended the capture when the window closed either.** It had exactly two exits —
  Escape, or pressing a key — and both need the panel in front of you. Click away and it
  stayed armed; reopen Settings and it was still waiting, and still bound the next thing you
  typed. Hidden frames get no input, so the trap only sprang when you came back, which is
  when you'd forgotten about it.
- On 3.3.5 that's worse than a stuck colour: there's no `SetPropagateKeyboardInput` until
  4.0, so a frame holding `EnableKeyboard(true)` **consumes** what you type. An armed button
  on a visible panel eats keystrokes.
- Both paths now go through `StopKeybindCapture`, and the button disarms on `OnHide`.

### Notes
- Found by reading `ui/Settings.lua`, which at **2,232 lines has no runtime coverage at
  all** — the largest untested surface left. It does load under the harness and builds about
  a third of the way before it needs `Valuate:` API surface mocked, which is a test fixture
  rather than a harness gap. Recorded in `CLAUDE.md` so the next attempt doesn't restart
  from nothing.
- `/valuate verify keybind` covers it: no gate can watch a button hold the keyboard.

## [0.48.0a] - 2026-08-09 — The answer moves to where the decision is

### Added
- **Hovering a stat's weight box in the Scale Editor now says what that weight is doing** —
  its share of your equipped score, how much of the stat you're wearing, and the weight
  itself. `/valuate weights` answers this for the whole scale, but with ~60 rows across five
  columns the question is asked *per row*, and going to the chat frame to find out breaks the
  thing you were doing.
- Three distinct answers, because they mean different things: a percentage, **"you are
  carrying none of this stat"**, and "no weight set". The middle one is deliberately not
  phrased as an error — a weight for a stat you'll pick up twenty levels from now is a plan,
  and a tooltip that calls it a mistake teaches you to stop reading tooltips.
- Hover only, no layout change. A share column on every row would need width this grid
  doesn't have, and would put a number beside fifty-odd stats that contribute nothing.

### Implementation
- The tooltip goes through **the same `RankStatShares`** `/valuate weights` uses. Two copies
  of one calculation is how the Best Equipment row and its tooltip ended up disagreeing about
  empty slots, and how the percentage ended up dividing by a signed baseline in one place and
  a magnitude in the other.
- **Totals are cached for 5s; the ranking is not.** Reading 17 slots through the private
  tooltip costs what a scan costs and can't run per row — but your weights change *as you
  type*, and a share that didn't move when you changed the number would be worse than no
  share at all.
- A TTL rather than event invalidation on purpose: hooking `PLAYER_EQUIPMENT_CHANGED` would
  mean editing the handler carrying the in-transit scan guards, which is the one place in
  this addon not worth touching for a tooltip.

### Development
- 9 more checks in `sharetest.js` (44 total), all on the cache. Mutation-tested three ways:
  dropping the clock-went-backwards guard, never expiring, and not caching at all.
- That guard matters because a `/reload` resets `GetTime`. Without it, `now - then` goes
  negative, which reads as "not expired", and the cache pins whatever it last held — after a
  long session, for the rest of the session.

## [0.47.0a] - 2026-08-09 — Which of your stat weights actually matter

### Added
- **`/valuate weights [scale]`** — ranks the scale's stats by how much they contribute to the
  gear you are wearing right now, with a bar, a percentage share, and the `value × weight`
  behind it. Defaults to your current spec; name a scale to check another.
- **It names the weights doing nothing.** A scale with fifteen weights looks carefully tuned,
  and if twelve are on stats your gear does not carry, tuning them is theatre. Until now the
  only way to find out was to change a number and watch whether anything moved. Those are
  listed separately, as *not wrong, just not doing anything yet* — a weight for a stat you
  will pick up later is a plan, not a mistake.
- Shares are computed against the sum of **absolute** contributions, so a negative weight is
  reported as the work it is doing without pushing everything else past 100%. Ranking is by
  magnitude too: a large penalty is a big deal and sorts like one.

### Development
- **A sixteenth gate, `tools/sharetest.js`** — 35 checks on the ranking. Every way it can be
  wrong produces a plausible-looking table, which is exactly why it is executed rather than
  read. Mutation-tested four ways: dividing by the signed total (produces a **300%** share),
  sorting by signed contribution (buries the penalty last), dropping the name tiebreaker
  (order reshuffles between identical runs), and discarding the idle list.
- **New check: `top-level-local-budget`.** Lua allows 200 locals per function scope and a
  file's top level *is* a scope. `luaparse` does not enforce it, so a file that crosses the
  line passes every gate here and then fails to compile in the client — which for an addon
  means it silently does not load. `Valuate.lua` sits at 104; the check warns at 180.

## [0.46.1a] - 2026-08-09 — The whole API-version class is guarded, and the rule checks itself

### Development
- **Swept the codebase for other post-30300 APIs and found none.** `SetShown` appears only in
  a comment saying not to use it, and `C_Timer` already has explicit flavour detection in
  `Valuate.lua`. `SetColorTexture` really was the outlier — worth saying, because "I found one,
  there must be more" is a guess and this is the check that settles it.
- **`no-retail-only-texture-api` is now `no-retail-only-api`**, covering 15 methods and
  namespaces with the version each arrived: `SetShown` (5.0), `SetAtlas`/`SetMaskTexture`
  (6.0), `SetIgnoreParentAlpha`/`SetIgnoreParentScale`/`UnitEffectiveLevel` (7.0),
  `C_Container` (10.0), `C_Item`/`C_EquipmentSet`/`securecallfunction` (8.0),
  `SetResizeBounds` (9.0), and others. Every one is absent today; the list exists so that
  stays true.
- `C_Timer` is **deliberately not** on the list — it is feature-detected on purpose, and
  "add it, it's a `C_` namespace" is an obvious-looking change that would break a working
  detection. The self-check below pins that.

### The rule checks itself
- **A lint rule is code nobody lints.** This one now runs 10 sample lines through its own
  patterns before reading a single file, and exits non-zero if any is classified wrongly.
- Both failure directions are otherwise silent: a pattern that matches nothing passes every
  file forever, and one that matches too much fails correct code — which
  `destructive-paths-reverify` did earlier in this fork, caught only because a mutation run
  happened to re-check the baseline.
- The **negative** samples carry most of the weight. `colorPreview:SetTexture(1, 1, 1, 1)` is
  the correct 3.3.5a call and must never be flagged.
- Mutation-tested in both directions: a typo'd pattern fails on the positive sample, and a
  pattern widened to `Set\\w*Texture` fails naming the exact correct call it would have
  broken.

## [0.46.0a] - 2026-08-09 — Every flat colour goes through one call that works on this client

### Fixed
- **22 places filled a texture with `SetColorTexture`, which arrived in Legion (7.0).** This
  addon targets **Interface 30300**, where the solid-colour setter is `SetTexture(r, g, b, a)`
  — numbers instead of a path. Exactly one place, in `ui/ScaleList.lua`, used the 3.3.5 form,
  which is what a habit looks like rather than a decision.
- Affected every accent bar, separator, row highlight, header background, scrollbar track and
  the Best Equipment change-flash — across `BestEquipment`, `Dialog`, `ScaleEditor`,
  `Settings`, `UpgradePopup` and `ValuateUI`. On a client without the method each one raises,
  and in Lua that means **the rest of that function never runs**, so the damage is not a
  missing line but a half-built panel.
- All of them now go through **`ns.SetSolidColor`**, which asks the texture which method it
  has. Correct on either client, one lookup, only while building UI.

### Honest uncertainty
- **I cannot tell from here whether this was actually broken.** Ascension ships a customised
  3.3.5a client and may well have backported the call. If it did, this release changes
  nothing you can see; if it did not, a good part of the UI was erroring at build time. That
  is precisely why it is worth not guessing — and why `/valuate verify solidcolour` exists.

### Development
- **A fifteenth lint rule, `no-retail-only-texture-api`**, so the modern name cannot come
  back. `ui/Shared.lua` is exempt, by resolved path rather than basename — the same trap that
  once made another rule flag `Valuate-PassLoot`'s own `Valuate.lua`.
- `widgettest.js` gained 11 checks driving the helper against **both** client shapes: a
  texture that has `SetColorTexture` must use it, one that does not must fall back, a missing
  alpha must stay missing, and a nil texture must be ignored rather than raise. A fallback
  nothing runs is a fallback nobody knows is broken.
- Mutation-tested: removing the detection makes the gate fail with
  `attempt to call a nil value (method 'SetColorTexture')` — the exact error a 3.3.5a client
  would have produced.

## [0.45.1a] - 2026-08-09 — Reduce Motion stops leaking work

### Fixed
- **With Reduce Motion on, the upgrade-arrow driver never released an arrow.** One driver
  animates every arrow on screen by walking a set; bags and merchant windows close without
  telling it, so it prunes as it goes and arrows re-register when they are next drawn. The
  Reduce Motion branch was a second copy of that loop which returned early and skipped the
  pruning — so with the accessibility option on, the set only grew, and the driver wrote alpha
  to textures inside closed bags on every frame for the rest of the session.
- That is the branch least likely to be noticed by whoever is watching the screen, which is a
  poor place to keep the copy that forgot to clean up.
- Both modes now **decide the alphas and share one loop**, so the cleanup cannot belong to
  only one of them.

### Development
- **A fifteenth gate, `tools/arrowtest.js`** — 17 checks that tick the real driver and run
  *both* motion modes through an identical block of assertions. Mutation-tested: restoring the
  early return fails four checks under Reduce Motion and none under normal motion, which is
  exactly the shape of the original bug.
- The mock gained `RegisterEvent` and friends. They **record**, never dispatch — a mock that
  fired events would be deciding when the client does, which is the behaviour a gate is trying
  to observe.

## [0.45.0a] - 2026-08-09 — The tooltip stops contradicting itself

### Fixed
- **A negative equipped score flipped the sign of the percentage.** Going from -10 to -5 is an
  improvement; the tooltip reported **-50%**, and since the `+` and the green were already
  chosen from the raw difference, it printed **`+-50.0%` in green**. Negative scores are not
  hypothetical — the weight box deliberately keeps a leading minus so a scale can penalise a
  stat.
- The addon already knew the answer. `CalculateStatBreakdownWithComparison` has always divided
  by `math.abs` for the per-stat lines. It was the same computation, in the same tooltip,
  disagreeing with itself.
- **A catastrophic downgrade read as good news.** Past ±1000% the text is `HUGE!` with no
  number — but the sign came from a variable left empty for losses, on the convention that the
  number carries its own minus. There is no number in that branch, so a huge loss rendered
  `(HUGE!)`, distinguishable from a huge gain's `(+HUGE!)` only by an absent character. It now
  says `-HUGE!`.

### Development
- **A fourteenth gate, `tools/tooltiptest.js`** — 303 runtime checks on the most-read string
  the addon produces. Mutation-tested: both fixes fail exactly the checks that name them.
- The second bug was found by the gate, not by reading. It states one property — **the sign of
  the percentage matches the sign of the difference** — and sweeps every baseline × difference
  × comparison mode rather than listing cases by hand. Formatting code has few enough inputs
  to enumerate.

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

