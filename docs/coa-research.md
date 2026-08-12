# Conquest of Azeroth — class/spec research

Working notes for adding CoA templates to `ui/Data.lua`. Written down rather than re-fetched,
because this is a long job and each session would otherwise start from nothing.

**Status: research in progress. No CoA templates have been added yet.**

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
| Primalist | (3 unknown by name) | tank, healer and DPS specs exist; "Restoration" is the healer |
| Sun Cleric | Seraphim, Blessings (+1 unknown) | Seraphim = tank, Blessings = healer |
| Reaper | (unknown) | soul-infusion mechanic |
| Venomancer | (unknown) | forms covering tank / DPS / healer / support |
| Stormbringer | (unknown) | "Static" resource management |
| Templar | (unknown) | holy martial arts; tank/DPS |
| Son of Arugal | (unknown) | — |

Roughly **47 of 69** spec names, and still **zero** stat priorities.

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

## What is still needed, in order

1. **The remaining spec names** — about 22 of 69 unknown (Primalist, Reaper, Venomancer,
   Stormbringer, Templar, Son of Arugal, and one Sun Cleric), plus the contradictions above.
2. **The role of each spec** — including which are Support.
3. **Primary / secondary / tertiary stats per spec.** This is the actual deliverable and the
   part no source consulted so far provides. Tier lists rank classes; they do not give stat
   weights.
4. **CoA's armour and weapon rules**, to rewrite `unusable` per spec rather than inheriting
   WotLK's.

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
