# Conquest of Azeroth — class/spec research

Working notes for adding CoA templates to `ui/Data.lua`. Written down rather than re-fetched,
because this is a long job and each session would otherwise start from nothing.

**Status: research in progress. Stat priorities ARE published, one wiki page per class; 5 of 21
classes extracted. No CoA templates written yet.**

---

## What CoA actually is

"COA" is **Conquest of Azeroth**, not "Chronicles of Ascension". It launched **3 July 2026** on
the **Vol'jin** realm.

This matters more than a name. CoA is **not** a reskin of WotLK's classes:

- **21 original classes**, built from scratch
- **69 specialisations** total (sources say "three or more" per class; one says 70)
- A **Support role**, in addition to tank / healer / DPS
- Custom talent trees, Dragonflight-style, per class

So the existing `CLASS_SPEC_TEMPLATES` — 10 classes, 31 specs, Warrior through Death Knight —
describe the **classless / standard** realms and have **no overlap with CoA at all**. Nothing
already in the table can be reused for it.

## Why the existing templates cannot simply be extended

Two structural assumptions in every current template are wrong for CoA:

1. **The role set.** `tools/speccoverage.js` currently requires every role to be one of
   `TANK`, `HEALER`, `DAMAGER`, because those are the three the wizard offers. CoA has a
   genuine fourth: **Support**. (Ironically v0.78.0a *removed* a stray `SUPPORT` from Paladin
   Retribution — correct for the WotLK table, and exactly the role CoA needs as a real one.)
   Adding CoA means the wizard's role question grows a fourth button, and
   `Valuate:MatchTemplateToStats` gains a role that currently matches nothing.

2. **The `unusable` weapon and armour sets.** Ascension's own CoA page describes
   *"mail tanking gear, intellect-based guns, strength-oriented throwing weapons"*. Every
   existing template encodes the WotLK assumption that guns are ranged-physical and casters
   cannot use them, that mail is not tank gear, and so on. Those `unusable` blocks would
   actively mislead on CoA — an intellect gun would be scored as unusable for a caster.

## The 21 classes

Necromancer, Pyromancer, Cultist, Starcaller, Sun Cleric, Tinker, Runemaster, Primalist,
Reaper, Venomancer, Chronomancer, Son of Arugal, Guardian, Stormbringer, Felsworn, Barbarian,
Witch Doctor, Witch Hunter, Knight of Xoroth, Templar, Ranger.

## Specs confirmed so far

**Provisional.** Only what a source actually stated — guesses are worse than blanks here. Roles
marked *(implied)* were inferred by the source's own wording, not stated outright, so they need
confirming before anything is built on them.

| Class | Specs | Role notes |
|---|---|---|
| Barbarian | Brutality, Head Hunting, Ancestry | — |
| Chronomancer | Displacement, Duality, Artificer | time manipulation; support/utility |
| Cultist | Heretic, God Blade, Dreadnought | flexes tank / DPS / healer by spec; Insanity mechanic |
| Felsworn | Infernal, Slayer, Tyrant | Tyrant = tank |
| Guardian | Vanguard, Gladiator, Inspiration | Vanguard = tank; shield-and-taunt |
| Knight of Xoroth | War, Hellfire, Defiance | — |
| Necromancer | Death, Animation, Rime | pet-based dark caster, DPS |
| Pyromancer | Flame Weaver, Incineration, Draconic | fire DPS; Draconic is the dragon-form spec |
| Ranger | Archer, Brigand, Farstrider | all DPS *(implied)* |
| Runemaster | Engravement, Glyph, Rift Blade | — |
| Starcaller | Warden, Sentinel, Moon Priest, Moon Guard | Moon Priest = healer. **Four** listed |
| Tinker | Demolition, Mechanics, Invention | — |
| Witch Doctor | Voodoo, Brewing, Shadowhunting | Brewing = healer |
| Witch Hunter | Boltslinger, Inquisitor, Darkness | — |
| Primalist | Mountain King, Life, Wildwalker, Geomancy | **confirmed below** - four specs |
| Sun Cleric | Seraphim, Blessings (+1 unknown) | Seraphim = tank, Blessings = healer |
| Reaper | (unknown) | soul-infusion mechanic |
| Venomancer | Fortitude, Stalking, Rot Weaver, Vizir | **confirmed below** - four specs |
| Stormbringer | (unknown) | "Static" resource management |
| Templar | (unknown) | holy martial arts; tank/DPS |
| Son of Arugal | (unknown) | — |

Roughly **47 of 69** spec names. Superseded in part by the per-class pages below, which give
spec names, roles AND stat priorities together and should be treated as the better source.

### Contradictions in the sources, left unresolved on purpose

The wiki that supplied most of the spec names is internally inconsistent, and these need
settling before the table is built rather than papered over:

- **"Black Knight"** appears both as a class of its own *and* as a fourth Witch Hunter spec.
- **"Valkyrie"** is listed as a class whose spec is "Sun Cleric", while Sun Cleric is also one
  of the 21 classes.
- **"Blood Mage"** appears as a class, but is not in the 21-class list from the other sources.
- **Starcaller shows four specs** where every other class shows three.

The 21-class list itself is consistent across three independent sources, so where they disagree
that list wins. The extra names are most likely sub-specs, renamed content, or wiki drift.

## Stat priorities: found, and a method that works

Earlier passes concluded no source published CoA stat priorities. That was wrong — I had been
searching for class *lists*, not for stat priorities. There is one wiki page per class carrying
explicit, ordered priorities:

```
https://www.conquestofazerothwiki.wiki/classes/conquest-of-azeroth-<class>
```

So the remaining work is mechanical rather than blocked: 21 pages, one per class.

### Data collected so far

| Class | Spec | Role | Stat priority (as published) |
|---|---|---|---|
| Primalist | Mountain King | TANK | Armor > Stamina > Defense Rating > Strength |
| Primalist | Life | HEALER | Spell Power > Intellect > Critical Strike > Haste |
| Primalist | Wildwalker | DAMAGER (melee) | Strength > Attack Power > Hit Rating > Critical Strike |
| Primalist | Geomancy | DAMAGER (caster) | Spell Power > Haste > Intellect > Spell Critical |
| Venomancer | Fortitude | TANK | Armor, health, intellect, agility |
| Venomancer | Stalking | DAMAGER (melee) | Leech, melee uptime, survivability |
| Venomancer | Rot Weaver | DAMAGER (caster) | Haste, crit, spell power |
| Venomancer | Vizir | HEALER | Haste, mana, healing throughput |
| Necromancer | Death | DAMAGER (ranged) | Intellect + Spell Power, then Haste, Critical Strike |
| Necromancer | Animation | DAMAGER (ranged) | *(same — the page gives one priority for all three)* |
| Necromancer | Rime | DAMAGER (ranged) | *(same)* |
| Pyromancer | Flame Weaver | **HEALER** | Crit (S) > Intellect (A) > Haste (B) > Versatility (C) |
| Pyromancer | Incineration | DAMAGER (ranged) | *(same tier list)* |
| Pyromancer | Draconic | DAMAGER (melee-range) | *(same tier list)* |
| Guardian | Vanguard | TANK | Strength/Stamina > Defense Rating > Parry/Dodge > Block Value |
| Guardian | Gladiator | DAMAGER (physical) | Strength/Agility > Crit > Haste/Armor Pen > Hit Rating |
| Guardian | Inspiration | **SUPPORT** | not published; spec is "Banners & Songs" group buffs |

**5 of 21 classes** extracted (18 specs).

### What these four pages changed

- **Support is real and now has a name.** Guardian *Inspiration* is the first confirmed
  SUPPORT spec. The fourth wizard role is not hypothetical.
- **An earlier source was wrong about Pyromancer.** It was described as fire DPS across the
  board; its own page makes **Flame Weaver a healer**. Class-list articles are not reliable
  for roles — only the per-class pages are.
- **Some classes publish one priority for every spec.** Necromancer and Pyromancer both do.
  That is the source's choice, not missing data, and the templates should reflect it rather
  than inventing per-spec differences that nobody published.
- **Not every spec has a priority at all.** Guardian *Inspiration* has none. A support spec
  built on group buffs may genuinely not have one, and a blank is the honest record.

### CoA uses stats Valuate cannot score

Pyromancer's priority ends in **Versatility**. Valuate's 51-stat list has no Versatility, no
Mastery and no Leech — and `AscensionStatWeights` weights all three, plus `MYSTIC_ENCHANT`,
`MYTHIC` and `FERVOR`.

So a faithful CoA template cannot currently be written: the stats it needs to reference do not
exist in `ValuateStatCategories`, and `tools/autoname.js` requires every stat to have an
abbreviation. **Adding those stats is a prerequisite**, not a nicety — and it is a change to
the scoring core, not just the template table.

### Two things this immediately confirms

- **Four specs is normal.** Both classes documented so far have four, not three. 21 x 3 = 63
  against 69 total, so roughly six classes carry a fourth. The table must not assume three.
- **CoA really does break WotLK's stat assumptions.** Venomancer *Fortitude* is a **tank that
  wants intellect**, and Primalist *Mountain King* puts **Armor above Stamina**. Neither makes
  sense under 3.3.5 rules, which is exactly why the existing templates cannot be adapted.

### The conversion problem, stated before it is solved

These are **ordered lists**, not numeric weights, and Valuate scores with numbers. Turning
"A > B > C > D" into weights needs a stated rule rather than taste. Proposed, to be applied
uniformly and recorded in the template comments:

| Rank | Weight |
|---|---|
| 1st (primary) | 1.0 |
| 2nd | 0.75 |
| 3rd | 0.55 |
| 4th | 0.40 |
| unlisted but plausible | 0.05–0.1 |

A uniform rule is defensible and reproducible; hand-tuning each spec would be inventing
precision the source does not contain. Where a page states a *reason* for an ordering — the
Pyromancer's crit engine, for instance — that is worth reflecting with a wider gap than the
default.

Some published entries are not stat names at all: Venomancer Stalking's "melee uptime,
survivability" and Vizir's "healing throughput" describe intent, not gear stats. Those need a
judgement call per spec, and it must be recorded as one.

## What is still needed, in order

1. **The remaining spec names** — about 22 of 69 unknown (Primalist, Reaper, Venomancer,
   Stormbringer, Templar, Son of Arugal, and one Sun Cleric), plus the contradictions above.
2. **The role of each spec** — including which are Support.
3. **Primary / secondary / tertiary stats per spec.** This is the actual deliverable and the
   part no source consulted so far provides. Tier lists rank classes; they do not give stat
   weights.
4. **CoA's armour and weapon rules**, to rewrite `unusable` per spec rather than inheriting
   WotLK's.

## The best source found so far is already on this machine — and it is not CoA

`Interface/AddOns/AscensionStatWeights/AscensionStatWeights.lua` is an installed addon whose
whole purpose is Ascension stat weights. Its `SPEC_WEIGHTS` table carries **real, numeric,
Ascension-tuned weights** for all 30 class specs plus four classless archetypes
(`Classless:Physical DPS`, `Spell DPS`, `Healer`, `Tank`).

It is a far better authority than the WotLK knowledge Valuate's templates were built from, and
its `BASE_WEIGHTS` names Ascension stats that Valuate's own stat list does not model at all:
`PVP_POWER`, `MYSTIC_ENCHANT` (7.5 — the highest weight in the file), `MYTHIC`, `FERVOR`,
`VERSATILITY`, `MASTERY`, `LEECH`, `AVOIDANCE`, `SPEED`.

**But it contains no CoA classes.** Its `TALENT_SPECS` is Warrior through Druid, the standard
ten. So it solves the *classless/standard* realm and says nothing about Conquest of Azeroth.

### A contradiction it exposes in what Valuate now ships

Valuate's `Death Knight:Blood` template (added v0.78.0a) is a **tank** build — Stamina 1.0,
Defense 0.9, Dodge/Parry. AscensionStatWeights weights `Death Knight:Blood` as **damage**:

```lua
["Death Knight:Blood"] = { STR = 2.05, ATTACK_POWER = 1.0, ARMOR_PEN = 1.05,
                           EXPERTISE = 1.15, CRIT = 0.92, HASTE = 0.7 },
```

No Defense, no Dodge, no Parry. Either Ascension's Blood is not the tank spec WotLK's was, or
that addon treats all three DK specs as DPS. **Unresolved** — and worth resolving, because
Valuate would currently propose a Blood tank scale to someone whose gear says otherwise. It was
written from my own WotLK knowledge, which is exactly the class of assumption this file exists
to stop.

## No CoA content exists in this client

A scan of the whole `Interface/` tree for CoA class names (Pyromancer, Chronomancer, Necromancer,
Felsworn, Runemaster) returns only **AtlasLoot mob names** — no class data, no spec data. Nothing
CoA-related is installed here.

That is worth knowing before more time goes into local archaeology: whatever this installation
is, it is not a Conquest of Azeroth client, so CoA's own data files are not available to read.

### Where that is likely to come from

- The in-game **CoA talent/build calculator** (`ascension.gg/en/v2/coa-builder/voljin`) — has
  the authoritative class and spec list, but the page is too large for a plain fetch and needs
  driving in a browser.
- **In-game tooltips** on the Vol'jin realm — the ground truth for what a spec scales with,
  and something only the user can read.
- Community build guides per class, once spec names are known to search for.

## Honest assessment

Stat priorities are the hard 80% of this and none of the sources consulted give them. Inventing
plausible-looking weights would produce a wizard that confidently proposes wrong builds — the
failure mode this addon's gates exist to prevent, and worse than having no CoA templates at all,
because a missing class is at least silent rather than misleading.

The structural work (a fourth role, CoA-aware `unusable`, a separate template set keyed by
realm) can proceed without the numbers and is worth doing first.

## Sources

- <https://ascension.gg/en/features/new-wow-classes-coa>
- <https://noobtoboss.com/ascension-wow-conquest-of-azeroth/>
- <https://conquestofazeroth.space/classes/conquest-of-azeroth-class-list>
- <https://conquest-of-azeroth.wiki/classes/>
- <https://project-ascension.fandom.com/wiki/Conquest_of_Azeroth>
- <https://www.conquestofazerothwiki.wiki/classes> (most spec names; internally inconsistent — see above)
