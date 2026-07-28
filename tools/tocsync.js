#!/usr/bin/env node
/*
 * Verifies the .toc's ui\*.lua list matches what's actually in ui/.
 *
 * This exists because of a real incident: a shell edit stripped the backslashes from
 * the .toc, producing "uiPickers.lua" and silently dropping ui\InfoPanels.lua from the
 * load order. Both files still parsed cleanly - they just never loaded. That failure is
 * invisible to a syntax check and only shows up in-game as a missing panel.
 *
 * Usage:  node tools/tocsync.js        (run from the addon root or tools/)
 * Exits non-zero on any mismatch.
 */
"use strict";

const fs = require("fs");
const path = require("path");

// Work from the addon root whether invoked there or from tools/.
const ADDON_ROOT = fs.existsSync("Valuate.toc")
  ? "."
  : path.resolve(__dirname, "..");

const tocPath = path.join(ADDON_ROOT, "Valuate.toc");
const uiDir = path.join(ADDON_ROOT, "ui");

if (!fs.existsSync(tocPath)) {
  console.error("Valuate.toc not found (run from the addon root or tools/).");
  process.exit(2);
}

const toc = fs.readFileSync(tocPath, "utf8");
const listed = [...toc.matchAll(new RegExp("^ui\\\\([A-Za-z]+\\.lua)", "gm"))].map(
  (m) => m[1]
);
const onDisk = fs.existsSync(uiDir)
  ? fs.readdirSync(uiDir).filter((f) => f.endsWith(".lua"))
  : [];

let ok = true;
for (const f of listed) {
  if (!fs.existsSync(path.join(uiDir, f))) {
    console.error("  MISSING FILE   .toc lists ui\\" + f + " but it is not on disk");
    ok = false;
  }
}
for (const f of onDisk) {
  if (!listed.includes(f)) {
    console.error(
      "  NEVER LOADED   ui/" + f + " exists but is absent from the .toc"
    );
    ok = false;
  }
}

// A malformed entry (backslash stripped) shows up as a ui-looking line we didn't match.
for (const line of toc.split(/\r?\n/)) {
  const t = line.trim();
  if (/^ui[A-Za-z]+\.lua$/.test(t)) {
    console.error("  MALFORMED      '" + t + "' - missing the ui\\ separator");
    ok = false;
  }
}

if (!ok) {
  console.error("\n.toc and ui/ are OUT OF SYNC.");
  process.exit(1);
}
console.log(
  "OK  .toc and ui/ in sync (" + listed.length + " modules): " + listed.join(" -> ")
);
