#!/usr/bin/env node
/*
 * @gate Every font token names a font the client is guaranteed to have
 *
 * This gate used to assert the opposite of what it asserts now, and the story is the point.
 *
 * v0.74.0a replaced the six font tokens with custom font objects to get a real type scale
 * (16/14/13/12/12/10), because FONT_H1 and FONT_BODY were the same font and headings were
 * therefore the same size as their body text. It shipped with a fallback meant to catch a
 * client that would not take the font. The fallback could not fire:
 *
 *     local applied = pcall(font.SetFont, font, FONT_PATH, size)
 *     if not applied or (font.GetFont and not font:GetFont()) then return fallbackTemplate end
 *
 * pcall returns success THEN the call's own result and only the first was captured, so a
 * SetFont returning false without erroring read as success. And a 3.3.5 Font object has no
 * GetFont method, so `font.GetFont` is nil and the entire second clause is falsy. DefineFont
 * returned the name of a font object with NO FONT SET, and the first SetText against it threw
 * "Font not set" while the window was being built. The UI would not open, and relogging did
 * not help because the same code ran again.
 *
 * The mock made it worse rather than catching it: luaharness answers SetFont with a stored
 * table and CreateFont with a frame, so every assertion about sizes passed against a fiction.
 * 25 green checks and a broken client.
 *
 * So this gate no longer tries to prove a scale is applied - a headless harness cannot know
 * whether THIS client accepts a font. It proves the only thing that is checkable here and
 * that actually matters: every token names a stock font template, which the client ships.
 *
 * Reintroducing a real type scale is fine. It has to be verified in the game first, and the
 * check has to be a functional probe (draw text with it and see), not a guard written against
 * an API surface nobody confirmed.
 *
 * Usage:  node tools/typescale.js
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");
const shared = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Shared.lua"), "utf8");

/*
 * The stock font objects a 3.3.5 client defines. Deliberately a short, conservative list:
 * anything outside it has to be proven to exist in the game rather than assumed, which is
 * the mistake this file now exists to prevent.
 */
const STOCK_FONTS = new Set([
  "GameFontNormal",
  "GameFontNormalSmall",
  "GameFontNormalLarge",
  "GameFontNormalHuge",
  "GameFontHighlight",
  "GameFontHighlightSmall",
  "GameFontHighlightLarge",
  "GameFontDisable",
  "GameFontDisableSmall",
  "NumberFontNormal",
  "NumberFontNormalSmall",
  "NumberFontNormalLarge",
  "ChatFontNormal",
  "QuestFontNormalSmall",
  "SystemFont_Shadow_Med1",
  "SystemFont_Shadow_Small",
]);

const TOKENS = ["FONT_TITLE", "FONT_H1", "FONT_H2", "FONT_H3", "FONT_BODY", "FONT_SMALL"];

const assigned = {};
for (const token of TOKENS) {
  const m = shared.match(new RegExp(`^ns\\.${token}\\s*=\\s*"([^"]+)"`, "m"));
  if (m) assigned[token] = m[1];
}

const missing = TOKENS.filter((t) => !assigned[t]);
if (missing.length) {
  console.error(
    "These font tokens are not a plain string naming a stock font: " + missing.join(", ") +
      "\n\nA computed font (CreateFont, SetFont) cannot be verified from here, and shipping " +
      "one unverified is what broke the UI in v0.74.0a - the token resolved to a font object " +
      'with no font set and the window would not open ("Font not set").'
  );
  process.exit(1);
}

const unknown = TOKENS.filter((t) => !STOCK_FONTS.has(assigned[t]));
if (unknown.length) {
  console.error("Font tokens naming a font this client may not have:");
  for (const t of unknown) console.error(`  ${t} = "${assigned[t]}"`);
  console.error(
    "\nIf it really is a stock 3.3.5 font, add it to STOCK_FONTS. If it is one you defined, " +
      "it must be proven to draw text in the game before shipping - see the header."
  );
  process.exit(1);
}

console.log(
  `OK  all ${TOKENS.length} font tokens name stock fonts the client ships ` +
    `(${new Set(Object.values(assigned)).size} distinct).`
);
