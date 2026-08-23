#!/usr/bin/env node
/*
 * @gate A repair is only claimed once it has been checked
 *
 * Runs the real Valuate:AutoRepair from Valuate.lua.
 *
 * This function spends money - sometimes the GUILD's - and had no gate at all.
 *
 * What it got wrong: it read pcall's `ok` as success. pcall tells you the CALL did not error.
 * It says nothing about whether the repair went through, and the two come apart in exactly the
 * case that matters. RepairAllItems(1) asks for guild funds, and a guild bank that is empty -
 * or a rank whose daily repair allowance is spent - refuses WITHOUT erroring.
 *
 * So it announced "Repaired using guild funds", marked the automation done, and returned. The
 * return also meant it never fell through to your own gold. You left town with red gear having
 * been told you were fine, by the feature whose entire job is preventing that.
 *
 * Three states, not two, and conflating any pair of them reintroduces the bug:
 *
 *     repaired      the cost went to zero
 *     not repaired  the cost is still owed - pay it yourself rather than walking away
 *     UNKNOWN       you left the merchant, so there is nothing to read
 *
 * The third is the one a careless fix drops. GetRepairAllCost answers about the merchant you
 * have open, so walking away leaves it with nothing to say - and reading that silence as
 * success puts the original bug back with extra steps.
 *
 * Durability comes from the SERVER, so none of this can be read on the same frame as the
 * request. Every claim is made from a deferred read, which this gate drives by hand.
 *
 * Usage:  node tools/repairtest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^ns\.REPAIR_VERIFY_DELAY = [\d.]+/m,
  /^function Valuate:AutoRepair\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error(
      "  SLICE  could not find " + re + " in Valuate.lua - this gate is testing nothing"
    );
    process.exit(1);
  }
  return m[0];
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
local function saidAny(lines, needle)
    for _, l in ipairs(lines) do
        if l:lower():find(needle:lower(), 1, true) then return true end
    end
    return false
end

ns = {}
Valuate = {}

-- ---- the world -------------------------------------------------------------------------------
COST, PURSE, AT_MERCHANT, GUILD_ALLOWED = 100, 5000, true, false
REPAIRED_BY, MARKS, SAID = nil, {}, {}

function CanMerchantRepair() return AT_MERCHANT end
function GetRepairAllCost() if not AT_MERCHANT then return 0 end return COST end
function GetCoinTextureString(c) return tostring(c) .. "c" end
function GetMoney() return PURSE end
function CanGuildBankRepair() return GUILD_ALLOWED end

-- The whole point: this is what a REAL repair does and a refused one does not.
GUILD_PAYS = true
function RepairAllItems(useGuild)
    if useGuild == 1 then
        REPAIRED_BY = "guild-attempt"
        if GUILD_PAYS then COST = 0 end   -- an empty bank or spent allowance just... does not
        return
    end
    REPAIRED_BY = "self"
    PURSE = PURSE - COST
    COST = 0
end

function Valuate:GetOptions() return OPTIONS end
function Valuate:MarkAutomation(name, outcome) MARKS[name] = outcome end
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    SAID[#SAID + 1] = table.concat(parts, " ")
end

-- Deferred work, captured rather than run, so the gate decides WHEN the verifying read
-- happens - which is the only way to model "the server has not answered yet".
PENDING = {}
function ValuateAfter(delay, fn) PENDING[#PENDING + 1] = { delay = delay, fn = fn } end
local function drain()
    local queue = PENDING
    PENDING = {}
    for _, p in ipairs(queue) do p.fn() end
end

` + sliced.join("\n") + `

local function reset(cost, guildAllowed, guildPays, purse)
    COST, GUILD_ALLOWED, GUILD_PAYS = cost, guildAllowed, guildPays
    PURSE, AT_MERCHANT = purse or 5000, true
    REPAIRED_BY, MARKS, SAID, PENDING = nil, {}, {}, {}
    OPTIONS = { autoRepairGuildFirst = guildAllowed }
end

-- ---- nothing is claimed before the check -----------------------------------------------------
-- The old code printed its success line synchronously. Anything said before the verifying read
-- is said without evidence, whichever way it turns out.
reset(100, false, true)
Valuate:AutoRepair()
eq(MARKS.autoRepair, nil, "nothing is marked done before the repair has been verified")
ok(not saidAny(SAID, "Repaired"), "and nothing is announced before it either")
ok(#PENDING > 0, "a verifying read is queued")
drain()
ok(saidAny(SAID, "Repaired"), "after the check, success IS announced")
ok(MARKS.autoRepair and MARKS.autoRepair:find("your own gold", 1, true) ~= nil,
   "and recorded, naming which purse paid")

-- ---- THE ONE THAT MATTERS: the guild is allowed but does not pay -------------------------------
-- CanGuildBankRepair says you are ALLOWED to use guild funds. It says nothing about whether any
-- are left. This is the shipped bug: announced, marked done, returned, never fell through.
reset(100, true, false)
Valuate:AutoRepair()
drain()
eq(REPAIRED_BY, "self",
   "guild funds that do not cover it fall through to your own gold rather than stopping")
ok(saidAny(SAID, "did not cover"), "and you are told the guild did not pay")
ok(not saidAny(SAID, "Repaired using guild funds"),
   "a repair the guild never paid for is NEVER announced as one")
drain()
ok(MARKS.autoRepair and MARKS.autoRepair:find("your own gold", 1, true) ~= nil,
   "the record names the purse that actually paid")

-- The pair. A guild that DOES pay must still be reported as the guild - a fix that always
-- says "your own gold" would pass every assertion above and be just as wrong.
reset(100, true, true)
Valuate:AutoRepair()
drain()
eq(PURSE, 5000, "when the guild pays, your own money is untouched")
ok(MARKS.autoRepair and MARKS.autoRepair:find("guild", 1, true) ~= nil,
   "and the guild is credited")

-- ---- UNKNOWN is not success -------------------------------------------------------------------
-- GetRepairAllCost answers about the merchant you have open. Walk away and it has nothing to
-- say, which is not the same as a repair having happened.
reset(100, false, true)
Valuate:AutoRepair()
AT_MERCHANT = false
drain()
ok(not saidAny(SAID, "Repaired using"),
   "leaving the merchant is not reported as a successful repair")
ok(MARKS.autoRepair and MARKS.autoRepair:find("confirm", 1, true) ~= nil,
   "it is recorded as unconfirmed, which is the honest answer")

-- ---- a repair that simply does not happen -------------------------------------------------------
reset(100, false, true)
GUILD_PAYS = true
local realRepair = RepairAllItems
RepairAllItems = function() REPAIRED_BY = "self" end  -- request sent, server never obliges
Valuate:AutoRepair()
drain()
ok(saidAny(SAID, "still damaged"), "a repair that did not take is reported as such")
ok(not saidAny(SAID, "Repaired using"), "and never as a success")
RepairAllItems = realRepair

-- ---- the cheap refusals still work ---------------------------------------------------------------
reset(100, false, true, 10)
Valuate:AutoRepair()
eq(REPAIRED_BY, nil, "too little money repairs nothing")
ok(MARKS.autoRepair and MARKS.autoRepair:find("afford", 1, true) ~= nil,
   "and says so, because did-nothing is what the report exists to explain")

reset(0, false, true)
eq(Valuate:AutoRepair(), false, "undamaged gear is not a repair")
eq(#PENDING, 0, "and queues no check")

reset(100, false, true)
AT_MERCHANT = false
eq(Valuate:AutoRepair(), false, "a merchant that cannot repair is refused up front")

return failures, checks
`,
  "repairtest",
  "automatic repair"
);
