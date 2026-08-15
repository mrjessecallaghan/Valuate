#!/usr/bin/env node
/*
 * @gate A scaled item's requirement is read from the tooltip, not from the item template
 *
 * Runs the REAL ns.TooltipRequiredLevel against a mocked WoW tooltip.
 *
 * ASCENSION SCALES GEAR TO YOUR LEVEL. GetItemInfo's minLevel is the item template's number
 * and says nothing about this character: a piece whose template reads "Requires Level 24" is
 * commonly wearable long before 24, because it scaled down to meet you.
 *
 * The scan read that static number and did `playerLevel >= reqLevel`, so wearable gear was
 * filed under "upgrade at level 24" - a level the character had effectively already passed,
 * for an item they could put on immediately.
 *
 * The tooltip does not have that problem. It is rendered by the client, for this character,
 * with scaling applied. An unmet requirement is drawn RED; a met one is not. The addon was
 * already reading redness for proficiencies - TooltipLineIsRed's comment argues for exactly
 * this, "respects Ascension's learned proficiencies rather than a static class table" - and
 * the level check simply never got the same treatment.
 *
 * The colour is the whole signal, so these cases are all about colour.
 *
 * Usage:  node tools/scaledlevel.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

// TooltipLineIsRed FIRST: TooltipRequiredLevel calls it, and a slice that splices them the
// other way round leaves it nil at definition time and every line reads as not-red - which
// would make this gate pass by finding nothing, forever.
const parts = ["TooltipLineIsRed", "ns.TooltipRequiredLevel"].map(function (name) {
  const pattern = name.startsWith("ns.")
    ? "^function " + name.replace(".", "\\.") + "\\([\\s\\S]*?\\r?\\nend"
    : "^local function " + name + "\\([\\s\\S]*?\\r?\\nend";
  const hit = lua.match(new RegExp(pattern, "m"));
  if (!hit) {
    console.error("  SLICE  could not find " + name + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return hit[0];
});

const run = load([]);

run(
  `
local failures, checks = {}, 0
local function ok(cond, what) checks = checks + 1 if not cond then table.insert(failures, what) end end
local function eq(got, want, what)
    checks = checks + 1
    if got ~= want then
        table.insert(failures, what .. " (got " .. tostring(got) .. ", wanted " .. tostring(want) .. ")")
    end
end

local ns = {}
ITEM_MIN_LEVEL = "Requires Level %d"

-- A tooltip is a numbered set of font strings, each with a colour. That is all the client
-- gives, and all this reads.
local LINES = {}
local function line(text, r, g, b)
    return { text = text, r = r, g = g, b = b }
end
local RED = { 1.0, 0.13, 0.13 }
local WHITE = { 1.0, 1.0, 1.0 }

ValuateTip = { NumLines = function() return #LINES end }
function getglobal(name)
    local i = tonumber(name:match("TextLeft(%d+)$") or "")
    if not i then return nil end
    local l = LINES[i]
    if not l then return nil end
    return {
        GetText = function() return l.text end,
        GetTextColor = function() return l.r, l.g, l.b end,
    }
end
_G = { ValuateTip = ValuateTip }

${parts.join("\n")}

local function setTip(...)
    LINES = {}
    for _, l in ipairs({ ... }) do LINES[#LINES + 1] = l end
end

-- ---- the case that was wrong ------------------------------------------------------------
-- Scaled to meet you. The template still says 24 somewhere, but the client is not drawing a
-- red requirement, because there is no requirement left to meet.
setTip(
    line("Scaled Chestplate", unpack(WHITE)),
    line("Requires Level 24", unpack(WHITE)),
    line("+12 Strength", unpack(WHITE))
)
eq(ns.TooltipRequiredLevel("ValuateTip"), nil,
   "a requirement the client draws in WHITE is already met - there is no level to wait for")

-- ---- and the case that is genuinely ahead of you ------------------------------------------
setTip(
    line("Big Sword", unpack(WHITE)),
    line("Requires Level 60", unpack(RED)),
    line("+40 Strength", unpack(WHITE))
)
eq(ns.TooltipRequiredLevel("ValuateTip"), 60,
   "a RED requirement is real, and its level is read from the line itself")

-- ---- held back by something a level will not fix ------------------------------------------
-- A proficiency. There IS a red line, but no level in it, so there is no number to promise -
-- and the caller says "upgrade once you can use it" rather than inventing "at level 0".
setTip(
    line("Plate Helm", unpack(WHITE)),
    line("Plate", unpack(RED))
)
eq(ns.TooltipRequiredLevel("ValuateTip"), nil,
   "a red line with no level in it yields no level, rather than zero")

-- ---- the name line is never mistaken for a requirement ------------------------------------
-- Line 1 is the item name in its quality colour. Orange legendary is close enough to red to
-- matter if the loop ever started at 1.
setTip(
    line("Requires Level 99 Blade", 1.0, 0.13, 0.13),
    line("+5 Agility", unpack(WHITE))
)
eq(ns.TooltipRequiredLevel("ValuateTip"), nil,
   "the item NAME is skipped, however red it is and whatever it happens to say")

-- ---- both kinds of red, level first --------------------------------------------------------
setTip(
    line("Epic Mail", unpack(WHITE)),
    line("Mail", unpack(RED)),
    line("Requires Level 45", unpack(RED))
)
eq(ns.TooltipRequiredLevel("ValuateTip"), 45,
   "a level found later still wins over an earlier red line that has none")

-- ---- nothing red at all ---------------------------------------------------------------------
setTip(line("Plain Ring", unpack(WHITE)), line("+3 Stamina", unpack(WHITE)))
eq(ns.TooltipRequiredLevel("ValuateTip"), nil, "an unrestricted item has no required level")

-- ---- the colour thresholds --------------------------------------------------------------------
-- Red is r > 0.8, g < 0.35, b < 0.35. Orange item-quality text sits inside the red channel but
-- not the green one, and reading it as a requirement would invent levels out of item names.
setTip(line("x", unpack(WHITE)), line("Requires Level 30", 1.0, 0.5, 0.0))
eq(ns.TooltipRequiredLevel("ValuateTip"), nil, "orange is not red, so it is not a requirement")

setTip(line("x", unpack(WHITE)), line("Requires Level 30", 0.5, 0.1, 0.1))
eq(ns.TooltipRequiredLevel("ValuateTip"), nil, "dark maroon is not red either")

return failures, checks
`,
  "scaledlevel",
  "the scaled requirement reader"
);
