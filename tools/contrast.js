#!/usr/bin/env node
/*
 * @gate Text is legible on every background, and the hierarchy descends
 *
 * A dark theme is easy to get subtly wrong and very hard to argue about, because "is that
 * readable?" is a matter of opinion right up until you measure it. This measures it.
 *
 * Two rules, both objective:
 *
 *   1. Every text token clears WCAG AA (4.5:1) against every background it can sit on.
 *      textDim was at 3.73 against buttonBg - and textDim is the token hints and secondary
 *      labels use, which is exactly the text someone is squinting at when they are already
 *      unsure what a control does.
 *
 *   2. The hierarchy descends: title > header > body > dim. It did NOT. textHeader measured
 *      10.9 against a textBody of 14.2, so every section heading was quieter than the
 *      paragraph beneath it. That is the sort of thing you feel as "this panel is hard to
 *      scan" without ever being able to name it, and no amount of care catches it by eye -
 *      both colours look fine in isolation.
 *
 * Contrast is computed the standard way: sRGB -> relative luminance -> (L1+0.05)/(L2+0.05).
 *
 * Usage:  node tools/contrast.js
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ADDON_ROOT = fs.existsSync("Valuate.toc") ? "." : path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ADDON_ROOT, "ui", "Shared.lua"), "utf8");

const block = src.match(/ns\.COLORS = \{[\s\S]*?\n\}/);
if (!block) {
  console.error("ERROR  could not find ns.COLORS in ui/Shared.lua");
  process.exit(2);
}

const colors = {};
for (const m of block[0].matchAll(/^\s*(\w+)\s*=\s*\{\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/gm)) {
  colors[m[1]] = [parseFloat(m[2]), parseFloat(m[3]), parseFloat(m[4])];
}

const lin = (c) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
const lum = ([r, g, b]) => 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
const ratio = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};

// Backgrounds text is actually drawn on. buttonHover is included because a label sits on a
// button while it is hovered, which is precisely when someone is reading it.
const BACKGROUNDS = ["windowBg", "panelBg", "inputBg", "buttonBg", "buttonHover"];
const TEXT = ["textTitle", "textHeader", "textBody", "textDim", "textAccent"];
const AA = 4.5;

const missingToken = [...TEXT, ...BACKGROUNDS].filter((k) => !colors[k]);
if (missingToken.length) {
  console.error(
    "ERROR  palette is missing " + missingToken.join(", ") + " - the token names changed, " +
      "so this gate would pass by checking nothing"
  );
  process.exit(2);
}

const failures = [];
for (const t of TEXT) {
  for (const b of BACKGROUNDS) {
    const r = ratio(colors[t], colors[b]);
    if (r < AA) {
      failures.push(`  ${t} on ${b}: ${r.toFixed(2)} (needs ${AA})`);
    }
  }
}

if (failures.length) {
  console.error("Text that is not legible enough on a background it is drawn on:");
  for (const f of failures) console.error(f);
  console.error(
    "\nLighten the text token or darken the background. This is measured, not a matter of " +
      "taste - below 4.5 is hard to read for people who are not you, on monitors that are " +
      "not yours."
  );
  process.exit(1);
}

/*
 * The visual hierarchy has to match the semantic one. A heading that is quieter than its
 * body text inverts the reading order of the whole panel.
 */
const ORDER = ["textTitle", "textHeader", "textBody", "textDim"];
const against = colors.windowBg;
const inversions = [];
for (let i = 0; i < ORDER.length - 1; i++) {
  const a = ratio(colors[ORDER[i]], against);
  const b = ratio(colors[ORDER[i + 1]], against);
  if (a <= b) {
    inversions.push(
      `  ${ORDER[i]} (${a.toFixed(2)}) is not brighter than ${ORDER[i + 1]} (${b.toFixed(2)})`
    );
  }
}

if (inversions.length) {
  console.error("The text hierarchy is inverted - these read in the wrong order of importance:");
  for (const i of inversions) console.error(i);
  console.error(
    "\ntitle > header > body > dim, by measured contrast. Anything else makes a panel hard " +
      "to scan in a way nobody can point at."
  );
  process.exit(1);
}

const lowest = Math.min(
  ...TEXT.flatMap((t) => BACKGROUNDS.map((b) => ratio(colors[t], colors[b])))
);
console.log(
  `OK  all ${TEXT.length} text tokens clear WCAG AA on all ${BACKGROUNDS.length} backgrounds ` +
    `(worst pair ${lowest.toFixed(2)}:1); hierarchy descends title > header > body > dim.`
);
