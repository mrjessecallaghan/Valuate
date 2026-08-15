#!/usr/bin/env node
/*
 * @gate ui/DungeonLoot.lua still matches the AtlasLoot tables it was harvested from
 *
 * Generates ui/DungeonLoot.lua from AtlasLoot's data files.
 *
 * WHY THIS EXISTS
 * ---------------
 * The dungeon-leave feature needs to know what each boss drops, and every item id is a claim
 * about a modified server that cannot be checked from outside the game. Writing them from
 * memory would produce confident nonsense - an addon that tells you to leave a dungeon your
 * boots were in. AtlasLoot has already done this work, its Ascension build carries this
 * server's custom items (the seven-digit ids), and it is sitting in the AddOns folder.
 *
 * So the ids are HARVESTED, never authored. Re-run this whenever AtlasLoot updates.
 *
 * BOSSES VS EVERYTHING ELSE
 * -------------------------
 * AtlasLoot names real encounters with `BabbleBoss["..."]` and names sections like
 * "Trash Mobs", "Quest Item" or "The Vault" with a plain string. That distinction only
 * exists in the SOURCE - at runtime both are just strings - and it is the reason this
 * generator reads the .lua files rather than the loaded tables.
 *
 * It matters because the feature counts bosses that are still alive. A "Trash Mobs" section
 * never dies, so counted as a boss it would sit in the remaining list forever and the prompt
 * would never fire. Recorded as `extra` instead, its loot still counts as a reason to stay
 * while never pretending to be something you can finish.
 *
 * CHECKS by default and only writes with --write. A gate that rewrote the source it is
 * checking would turn "this drifted" into "this silently fixed itself", and the drift is
 * the thing worth being told about: it means AtlasLoot was updated and the ids you are
 * being advised on are not the ids the game will drop.
 *
 * Usage:  node tools/genloot.js           (check only - fails if out of date)
 *         node tools/genloot.js --write   (regenerate ui/DungeonLoot.lua)
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDONS = path.resolve(__dirname, "..", "..");
const OUT = path.resolve(__dirname, "..", "ui", "DungeonLoot.lua");

const SOURCES = [
  "AtlasLoot_OriginalWoW/originalwow.lua",
  "AtlasLoot_WrathoftheLichKing/wrathofthelichking.lua",
];

// Only 5-man content. Raids are not this feature, and the sets/crafting tables are not
// dropped by anything.
const DUNGEON_TYPES = /^(ClassicDungeon|ClassicDungeonExt|WrathDungeon)$/;

function harvest() {
  const dungeons = [];
  let missing = 0;

  for (const rel of SOURCES) {
    const file = path.join(ADDONS, rel);
    if (!fs.existsSync(file)) {
      console.error(`  MISSING  ${rel} - AtlasLoot is not installed, so nothing can be harvested.`);
      missing++;
      continue;
    }
    const src = fs.readFileSync(file, "utf8");
    const heads = [...src.matchAll(/AtlasLoot_Data\["([^"]+)"\]\s*=\s*\{/g)];

    for (let i = 0; i < heads.length; i++) {
      const body = src.slice(heads[i].index, i + 1 < heads.length ? heads[i + 1].index : src.length);
      const type = (body.match(/\bType\s*=\s*"([^"]+)"/) || [])[1] || "";
      if (!DUNGEON_TYPES.test(type)) continue;

      const zone = (body.match(/\bName\s*=\s*BabbleZone\["([^"]+)"\]/) || [])[1];
      if (!zone) continue; // no zone name means nothing can match GetInstanceInfo

      // Section headers, in file order, each followed by its item ids up to the next header.
      const marks = [...body.matchAll(/\bName\s*=\s*(?:BabbleBoss\[)?"([^"]+)"\]?/g)];
      const sections = [];
      for (let j = 0; j < marks.length; j++) {
        const name = marks[j][1];
        if (name === zone) continue; // the zone's own Name line
        const from = marks[j].index;
        const to = j + 1 < marks.length ? marks[j + 1].index : body.length;
        const chunk = body.slice(from, to);

        const ids = [];
        const seen = new Set();
        for (const m of chunk.matchAll(/\bitemID\s*=\s*(\d+)/g)) {
          const id = Number(m[1]);
          if (id > 0 && !seen.has(id)) { seen.add(id); ids.push(id); }
        }
        if (!ids.length) continue;

        // The structural signal: BabbleBoss means a killable encounter.
        const isBoss = /BabbleBoss\[/.test(marks[j][0]);
        sections.push({ name, ids, isBoss });
      }

      if (!sections.some((s) => s.isBoss)) continue;
      dungeons.push({ zone, type, sections });
    }
  }

  if (missing === SOURCES.length) {
    // Not a failure. AtlasLoot is a source of data, not a dependency - someone checking out
    // this repo without it should not be told their tree is broken. The generated file is
    // committed, so the addon works either way; it simply cannot be re-verified here.
    console.log("SKIP  AtlasLoot is not installed, so ui/DungeonLoot.lua cannot be re-checked.");
    process.exit(0);
  }
  dungeons.sort((a, b) => a.zone.localeCompare(b.zone));
  return dungeons;
}

function render(dungeons) {
  const q = (s) => (s.includes('"') ? "'" + s + "'" : '"' + s + '"');
  const L = [];
  const bossCount = dungeons.reduce((n, d) => n + d.sections.filter((s) => s.isBoss).length, 0);
  const itemCount = dungeons.reduce(
    (n, d) => n + d.sections.reduce((m, s) => m + s.ids.length, 0), 0);

  L.push("-- ui/DungeonLoot.lua");
  L.push("-- Which bosses in this dungeon can still drop something you would wear.");
  L.push("--");
  L.push("-- GENERATED BY tools/genloot.js - DO NOT EDIT BY HAND.");
  L.push("-- Re-run it after AtlasLoot updates; hand edits are lost on the next run.");
  L.push("--");
  L.push("-- The ids are HARVESTED from AtlasLoot's Ascension build, never authored. Writing item");
  L.push("-- ids from memory would produce confident nonsense - an addon that tells you to leave a");
  L.push("-- dungeon your boots were in - and there is no way to check one from outside the game.");
  L.push("--");
  L.push("-- `bosses` are killable encounters (AtlasLoot marks them with BabbleBoss). `extra` is");
  L.push("-- everything else it lists - trash tables, quest items, vendor sections. Extras count as");
  L.push("-- a reason to STAY but are never expected to die, so they cannot sit in the remaining");
  L.push("-- list forever and stop the prompt from ever firing.");
  L.push("--");
  L.push("-- ============================================================================");
  L.push("-- THE RULE THIS DATA IS SHAPED AROUND");
  L.push("-- ============================================================================");
  L.push("--   A dungeon that is not listed produces NO ADVICE AT ALL. Not \"nothing here for you\" -");
  L.push("--   silence. The absence of data must never read as the presence of a negative answer.");
  L.push("--");
  L.push("--   A boss with an empty item list is treated as UNKNOWN, not as empty. Same reason.");
  L.push("--");
  L.push("-- Ascension is a modified server, and AtlasLoot can be wrong or behind. /valuate dungeon");
  L.push("-- says exactly what is known for where you are standing, so a wrong entry is visible");
  L.push("-- rather than silently steering you.");
  L.push("--");
  L.push(`-- ${dungeons.length} dungeons, ${bossCount} bosses, ${itemCount} items.`);
  L.push("");
  L.push("local _, ns = ...");
  L.push("");
  L.push("ns.DUNGEON_LOOT = {");

  for (const d of dungeons) {
    L.push(`    [${q(d.zone)}] = {`);
    L.push(`        bosses = {`);
    for (const s of d.sections.filter((x) => x.isBoss)) {
      L.push(`            { name = ${q(s.name)}, items = { ${s.ids.join(", ")} } },`);
    }
    L.push(`        },`);
    const extras = d.sections.filter((x) => !x.isBoss);
    if (extras.length) {
      L.push(`        extra = {`);
      for (const s of extras) {
        L.push(`            { name = ${q(s.name)}, items = { ${s.ids.join(", ")} } },`);
      }
      L.push(`        },`);
    }
    L.push(`    },`);
  }
  L.push("}");
  L.push("");
  L.push(fs.readFileSync(path.join(__dirname, "dungeonloot.tail.lua"), "utf8").replace(/\s+$/, ""));
  L.push("");
  return L.join("\n");
}

const dungeons = harvest();
const text = render(dungeons);

if (!process.argv.includes("--write")) {
  const current = fs.existsSync(OUT) ? fs.readFileSync(OUT, "utf8") : "";
  if (current.replace(/\r\n/g, "\n") !== text) {
    console.error(
      "ui/DungeonLoot.lua no longer matches AtlasLoot.\n\n" +
      "  Usually this means AtlasLoot was updated, so the item ids the addon advises on are\n" +
      "  not the ids the game will drop. Regenerate:  node tools/genloot.js --write\n" +
      "  If you edited the generated file by hand, move the change into\n" +
      "  tools/dungeonloot.tail.lua instead - hand edits are lost on every run."
    );
    process.exit(1);
  }
  const bosses = dungeons.reduce((n, d) => n + d.sections.filter((s) => s.isBoss).length, 0);
  console.log(
    `OK  ui/DungeonLoot.lua matches AtlasLoot - ${dungeons.length} dungeons, ${bosses} bosses.`
  );
} else {
  fs.writeFileSync(OUT, text);
  const bosses = dungeons.reduce((n, d) => n + d.sections.filter((s) => s.isBoss).length, 0);
  console.log(`Wrote ui/DungeonLoot.lua - ${dungeons.length} dungeons, ${bosses} bosses.`);
}
