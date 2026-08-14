#!/usr/bin/env node
/*
 * @gate Queueing, releasing and leaving act only when asked, and say why when they don't
 *
 * Runs the real bodies against a mocked client.
 *
 * Unlike most of this addon, these four DO something rather than report something, and each
 * one calls an API Ascension may have changed. Two failure shapes matter:
 *
 *   ACTING WHEN IT SHOULDN'T. Releasing while your raid is mid battle-rez throws the rez
 *   away. Leaving a battleground after the user switched auto-leave off during the countdown
 *   is acting on a decision they have since reversed. Queueing while still inside a match
 *   drops you into another one.
 *
 *   DOING NOTHING, SILENTLY. "The API is missing on this client" and "you are already
 *   queued" and "it's switched off" are three completely different problems that all look
 *   identical from the outside. Every refusal has to name itself.
 *
 * Usage:  node tools/queuetest.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

const PIECES = [
  /^local BG_LEAVE_DELAY = \d+/m,
  /^local function ApiPresent\([\s\S]*?\r?\nend/m,
  /^local function InBattleground\([\s\S]*?\r?\nend/m,
  /^function Valuate:AutoReleaseSpirit\([\s\S]*?\r?\nend/m,
  /^function Valuate:QueueForBattleground\([\s\S]*?\r?\nend/m,
  /^function Valuate:QueueForDungeon\([\s\S]*?\r?\nend/m,
  /^local bgLeaveScheduled = false/m,
  /^function Valuate:HandleBattlefieldEnd\([\s\S]*?\r?\nend/m,
  /^local bfStatusWas = \{\}/m,
  /^function Valuate:HandleBattlefieldQueues\([\s\S]*?\r?\nend/m,
  /^function Valuate:ApplyContextScale\([\s\S]*?\r?\nend/m,
];
const sliced = PIECES.map((re) => {
  const m = lua.match(re);
  if (!m) {
    console.error("  SLICE  could not find " + re + " in Valuate.lua - this gate tests nothing");
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
local function saysAbout(reason, word, what)
    checks = checks + 1
    if type(reason) ~= "string" or not reason:find(word, 1, true) then
        table.insert(failures, what .. " (reason was: " .. tostring(reason) .. ")")
    end
end

Valuate = {}
local OPTIONS = {}
function Valuate:GetOptions() return OPTIONS end
local MARKS = {}
function Valuate:MarkAutomation(key, detail) MARKS[key] = detail end

-- ---- the mocked client -------------------------------------------------------
local INSIDE, KIND = false, nil
function IsInInstance() return INSIDE, KIND end
local PARTY, RAID = 0, 0
function GetNumPartyMembers() return PARTY end
function GetNumRaidMembers() return RAID end

local released = 0
function RepopMe() released = released + 1 end

local WINNER = nil
function GetBattlefieldWinner() return WINNER end
local left = 0
function LeaveBattlefield() left = left + 1 end

-- name, canEnter, isHoliday, isRandom  -> the list the client hands back.
local BG_LIST = {}
function GetBattlegroundInfo(i)
    local e = BG_LIST[i]
    if not e then return nil end
    return e.name, e.canEnter, false, false, false, e.isRandom
end
local joined = nil
function JoinBattlefield(index) joined = index end

local DUNGEON_CHOICE = 1234
function GetRandomDungeonBestChoice() return DUNGEON_CHOICE end
local setDungeon, joinedLFG = nil, 0
function SetLFGDungeon(id) setDungeon = id end
function JoinLFG() joinedLFG = joinedLFG + 1 end

-- Queue slots. Status is the client's own vocabulary: none / queued / confirm / active.
local BF_STATUS = {}
function GetMaxBattlefieldID() return 2 end
function GetBattlefieldStatus(i)
    local s = BF_STATUS[i]
    return s and s.status or "none", s and s.map or nil
end
local accepted = {}
function AcceptBattlefieldPort(i, join) table.insert(accepted, { i = i, join = join }) end
local IN_COMBAT = false
function InCombatLockdown() return IN_COMBAT end

-- Delays are captured, not run. Firing them by hand is the only way to test what happens
-- BETWEEN scheduling and firing - which is where the interesting decisions live.
local PENDING = {}
function ValuateAfter(delay, fn) table.insert(PENDING, { delay = delay, fn = fn }) end
local function firePending()
    local queue = PENDING
    PENDING = {}
    for _, p in ipairs(queue) do p.fn() end
end

` + sliced.join("\n") + `

-- ---- auto-release ------------------------------------------------------------
OPTIONS.autoRelease = false
local okRel, why = Valuate:AutoReleaseSpirit()
eq(okRel, false, "switched off, it does not release")
saysAbout(why, "off", "and says it is off rather than failing silently")
eq(released, 0, "nothing was released")

OPTIONS.autoRelease = true
INSIDE, KIND = false, nil
eq(Valuate:AutoReleaseSpirit(), true, "on, out in the world, it releases")
eq(released, 1, "exactly once")

-- THE guard: dead in a party instance with other people, someone may be resurrecting you.
INSIDE, KIND, PARTY = true, "party", 4
local okRel2, why2 = Valuate:AutoReleaseSpirit()
eq(okRel2, false, "in a group inside an instance it does NOT release")
saysAbout(why2, "resurrect", "and says why - a battle rez is about to be thrown away")
eq(released, 1, "still only the one release")

INSIDE, KIND, PARTY = true, "raid", 0
RAID = 24
eq(Valuate:AutoReleaseSpirit(), false, "the same guard covers raids")
RAID = 0

-- Alone in an instance there is nobody to rez you, so releasing is right.
INSIDE, KIND, PARTY = true, "party", 0
eq(Valuate:AutoReleaseSpirit(), true, "alone in an instance it releases")

-- A battleground has no battle rez to lose, and releasing is what you were going to do.
INSIDE, KIND, PARTY = true, "pvp", 9
eq(Valuate:AutoReleaseSpirit(), true, "in a battleground with a group it still releases")

-- A client with no RepopMe cannot be made to release, and must say so by name.
local realRepop = RepopMe
RepopMe = nil
INSIDE, KIND, PARTY = false, nil, 0
local okRel3, why3 = Valuate:AutoReleaseSpirit()
eq(okRel3, false, "a client without RepopMe refuses")
saysAbout(why3, "RepopMe", "and names the API it could not find")
RepopMe = realRepop

-- ---- queueing for a battleground --------------------------------------------
INSIDE, KIND = false, nil
BG_LIST = {}
local okQ, whyQ = Valuate:QueueForBattleground()
eq(okQ, false, "no battlegrounds listed means no queue")
saysAbout(whyQ, "random battleground", "and says what was missing")

-- The RANDOM entry is chosen by its flag, not its position or its name - so it survives
-- localisation and whatever Ascension calls it.
BG_LIST = {
    { name = "Warsong Gulch", canEnter = true, isRandom = false },
    { name = "Random Battleground", canEnter = true, isRandom = true },
}
eq(Valuate:QueueForBattleground(), true, "the random battleground is queued")
eq(joined, 2, "and it is the entry flagged isRandom, not the first in the list")

-- An entry you cannot enter (wrong level) is not queued for.
joined = nil
BG_LIST = { { name = "Random Battleground", canEnter = false, isRandom = true } }
eq(Valuate:QueueForBattleground(), false, "a random battleground you cannot enter is skipped")
eq(joined, nil, "and nothing was joined")

-- Already inside a match: queueing again would drop you into a second one.
BG_LIST = { { name = "Random Battleground", canEnter = true, isRandom = true } }
INSIDE, KIND = true, "pvp"
local okQ2, whyQ2 = Valuate:QueueForBattleground()
eq(okQ2, false, "it will not queue while you are still in a battleground")
saysAbout(whyQ2, "Already in", "and says so")
INSIDE, KIND = false, nil

-- EVERY missing API must name itself, not just the last one checked. "Nothing happened"
-- with no cause is the failure mode these messages exist to prevent, and one unnamed API is
-- enough to reproduce it.
local realJoin = JoinBattlefield
JoinBattlefield = nil
saysAbout(select(2, Valuate:QueueForBattleground()), "JoinBattlefield",
   "a client without JoinBattlefield names it")
JoinBattlefield = realJoin

local realInfo = GetBattlegroundInfo
GetBattlegroundInfo = nil
saysAbout(select(2, Valuate:QueueForBattleground()), "GetBattlegroundInfo",
   "a client without GetBattlegroundInfo names that one too")
GetBattlegroundInfo = realInfo

-- ---- queueing for a dungeon --------------------------------------------------
eq(Valuate:QueueForDungeon(), true, "a dungeon queue goes through")
eq(setDungeon, 1234, "the client's own recommended dungeon is used")
eq(joinedLFG, 1, "and it queued once")

DUNGEON_CHOICE = nil
local okD, whyD = Valuate:QueueForDungeon()
eq(okD, false, "no dungeon offered means no queue")
saysAbout(whyD, "no random dungeon", "and says the client offered none")
DUNGEON_CHOICE = 1234

local realJoinLFG = JoinLFG
JoinLFG = nil
saysAbout(select(2, Valuate:QueueForDungeon()), "JoinLFG", "a client without JoinLFG names it")
JoinLFG = realJoinLFG

-- ---- leaving a finished battleground ----------------------------------------
OPTIONS.autoLeaveBattleground = true
INSIDE, KIND, WINNER = false, nil, nil
Valuate:HandleBattlefieldEnd()
eq(#PENDING, 0, "outside a battleground it does nothing")

INSIDE, KIND = true, "pvp"
Valuate:HandleBattlefieldEnd()
eq(#PENDING, 0, "inside one that is still running it does nothing")

WINNER = 1
Valuate:HandleBattlefieldEnd()
eq(#PENDING, 1, "a finished match schedules the leave")
eq(PENDING[1].delay, BG_LEAVE_DELAY, "after the stated delay, not instantly - the scoreboard is the only record")

-- UPDATE_BATTLEFIELD_STATUS fires repeatedly. Scheduling once per fire would leave, then
-- try to leave again, and re-queue several times over.
Valuate:HandleBattlefieldEnd()
Valuate:HandleBattlefieldEnd()
Valuate:HandleBattlefieldEnd()
eq(#PENDING, 1, "repeated events do not schedule it again")

-- Switched off DURING the countdown: acting now would carry out a decision the user has
-- since reversed.
OPTIONS.autoLeaveBattleground = false
firePending()
eq(left, 0, "switching it off during the countdown cancels the leave")
saysAbout(MARKS.bgLeave, "cancelled", "and the report says it was cancelled, not that it left")

-- The real path: still on when the timer fires.
OPTIONS.autoLeaveBattleground = true
OPTIONS.autoQueuePvP = false
WINNER = 1
Valuate:HandleBattlefieldEnd()
firePending()
eq(left, 1, "left the battleground")
eq(#PENDING, 0, "and with PvP auto-queue off, nothing else was scheduled")

-- With auto-queue on, the re-queue is scheduled only AFTER leaving - queueing from inside
-- would either be refused or drop you into another match.
OPTIONS.autoQueuePvP = true
joined, WINNER = nil, 1
Valuate:HandleBattlefieldEnd()
firePending()
eq(left, 2, "left again")
eq(joined, nil, "and had NOT queued at the moment it left")
ok(#PENDING == 1, "the re-queue is scheduled for after")
INSIDE, KIND = false, nil   -- out of the battleground now
firePending()
eq(joined, 1, "then it queues")

-- Switched off entirely: the match ending is recorded, but nothing happens.
OPTIONS.autoLeaveBattleground = false
INSIDE, KIND, WINNER = true, "pvp", 1
MARKS.bgLeave = nil
Valuate:HandleBattlefieldEnd()
eq(#PENDING, 0, "with auto-leave off nothing is scheduled")
saysAbout(MARKS.bgLeave, "off", "but /valuate report still learns the match ended")

-- ---- taking the port, and noticing you missed it -----------------------------
OPTIONS.autoAcceptBattleground = false
OPTIONS.autoQueuePvP = false
BF_STATUS = { [1] = { status = "confirm", map = "Warsong Gulch" } }
Valuate:HandleBattlefieldQueues()
eq(#accepted, 0, "with auto-accept off, a queue pop is left alone")

OPTIONS.autoAcceptBattleground = true
BF_STATUS = { [1] = { status = "confirm", map = "Warsong Gulch" } }
Valuate:HandleBattlefieldQueues()
eq(#accepted, 1, "with it on, the invite is taken")
eq(accepted[1].join, 1, "and taken as ACCEPT, not decline")

-- Never mid-fight: the client refuses the port on some builds, and being yanked out of a
-- fight you are winning is its own kind of rude. The popup stays up either way.
accepted = {}
IN_COMBAT = true
BF_STATUS = { [1] = { status = "confirm", map = "Warsong Gulch" } }
Valuate:HandleBattlefieldQueues()
eq(#accepted, 0, "it does not port you out of combat")
saysAbout(MARKS.bgAccept, "combat", "and the report says why, so it does not look broken")
IN_COMBAT = false

-- A queue merely WAITING must not be accepted - only a pop.
accepted = {}
BF_STATUS = { [1] = { status = "queued", map = "Warsong Gulch" } }
Valuate:HandleBattlefieldQueues()
eq(#accepted, 0, "a queue that has not popped yet is not 'accepted'")

-- ---- the missed pop ----------------------------------------------------------
-- From a standing start, "still queued" and "dropped ten minutes ago" look identical. Only
-- the PREVIOUS status makes this detectable, which is why it is remembered per slot.
OPTIONS.autoAcceptBattleground = false
OPTIONS.autoQueuePvP = true
BG_LIST = { { name = "Random Battleground", canEnter = true, isRandom = true } }
INSIDE, KIND = false, nil

BF_STATUS = { [1] = { status = "confirm", map = "Alterac Valley" } }
Valuate:HandleBattlefieldQueues()          -- remembers "confirm"
joined = nil
BF_STATUS = { [1] = { status = "none" } }
Valuate:HandleBattlefieldQueues()          -- the pop came and went
eq(joined, 1, "a pop that lapsed re-queues you")
saysAbout(MARKS.queuePvP, "missed", "and the report says it was a missed pop")

-- Going confirm -> active is ENTERING the battleground, the opposite of missing it.
joined = nil
BF_STATUS = { [1] = { status = "confirm", map = "Alterac Valley" } }
Valuate:HandleBattlefieldQueues()
BF_STATUS = { [1] = { status = "active", map = "Alterac Valley" } }
Valuate:HandleBattlefieldQueues()
eq(joined, nil, "entering the battleground is not treated as missing the pop")

-- And a slot that was simply never queued must not fire on the first look, when there is
-- no previous status to compare against.
joined = nil
bfStatusWas = {}
BF_STATUS = { [1] = { status = "none" } }
Valuate:HandleBattlefieldQueues()
eq(joined, nil, "an idle slot on first sight does not re-queue")

-- With auto-queue off, the miss is recorded but nothing happens.
OPTIONS.autoQueuePvP = false
joined, MARKS.queuePvP = nil, nil
BF_STATUS = { [1] = { status = "confirm", map = "Alterac Valley" } }
Valuate:HandleBattlefieldQueues()
BF_STATUS = { [1] = { status = "none" } }
Valuate:HandleBattlefieldQueues()
eq(joined, nil, "with auto-queue off a missed pop does not re-queue")
saysAbout(MARKS.queuePvP, "off", "but the report still learns it happened")

-- Slots are tracked independently: two queues, and only the one that lapsed re-queues.
OPTIONS.autoQueuePvP = true
bfStatusWas = {}
BF_STATUS = { [1] = { status = "confirm", map = "AV" }, [2] = { status = "queued", map = "WSG" } }
Valuate:HandleBattlefieldQueues()
joined = nil
BF_STATUS = { [1] = { status = "none" }, [2] = { status = "queued", map = "WSG" } }
Valuate:HandleBattlefieldQueues()
eq(joined, 1, "the lapsed slot re-queues while the other keeps waiting")

-- A client with no queue APIs at all must not crash the event handler.
local realMax = GetMaxBattlefieldID
GetMaxBattlefieldID = nil
local safe = pcall(function() Valuate:HandleBattlefieldQueues() end)
eq(safe, true, "a client without GetMaxBattlefieldID is handled, not crashed into")
GetMaxBattlefieldID = realMax

-- ---- the PvP scale swap ------------------------------------------------------
-- Resilience is worth a great deal in a battleground and nothing in a dungeon, so "what is
-- my best chest" has two right answers. The swap itself is easy; the RESTORE is where this
-- can quietly leave you scoring your dungeon gear against a PvP scale for days.
local SCALES = { Arena = {}, Raid = {} }
function Valuate:GetScales() return SCALES end
function Valuate:ResetTooltips() end

OPTIONS.pvpScale = nil
OPTIONS.characterWindowScale = "Raid"
INSIDE, KIND = true, "pvp"
eq(Valuate:ApplyContextScale(), false, "with no PvP scale nominated it does nothing")
eq(OPTIONS.characterWindowScale, "Raid", "and leaves your scale alone")

OPTIONS.pvpScale = "Arena"
eq(Valuate:ApplyContextScale(), true, "zoning into a battleground switches to the PvP scale")
eq(OPTIONS.characterWindowScale, "Arena", "which is now active")
eq(OPTIONS.pvpScaleRestore, "Raid", "and what you were using is remembered")

-- Idempotent: the events that drive this fire repeatedly, and a second switch would
-- overwrite the restore target with the PvP scale itself - stranding you on it forever.
eq(Valuate:ApplyContextScale(), false, "switching again while already switched does nothing")
eq(OPTIONS.pvpScaleRestore, "Raid", "and the restore target is NOT overwritten with the PvP scale")

INSIDE, KIND = false, nil
eq(Valuate:ApplyContextScale(), true, "leaving restores")
eq(OPTIONS.characterWindowScale, "Raid", "the scale you were using")
eq(OPTIONS.pvpScaleRestore, nil, "and the marker is cleared")

eq(Valuate:ApplyContextScale(), false, "with nothing to restore, leaving again does nothing")
eq(OPTIONS.characterWindowScale, "Raid", "and does not disturb your scale")

-- The restore target is PERSISTED, so a reload inside a battleground still restores. This
-- simulates exactly that: the marker survives, memory does not.
OPTIONS.characterWindowScale, OPTIONS.pvpScaleRestore = "Arena", "Raid"
INSIDE, KIND = false, nil
eq(Valuate:ApplyContextScale(), true, "a reload inside a battleground still restores on the way out")
eq(OPTIONS.characterWindowScale, "Raid", "back to the right one")

-- Having no explicit scale before is a real state, and must come back as no scale rather
-- than being quietly promoted to whichever one PvP used.
OPTIONS.characterWindowScale = nil
INSIDE, KIND = true, "pvp"
Valuate:ApplyContextScale()
eq(OPTIONS.pvpScaleRestore, "", "no previous scale is remembered as empty, not as nil")
INSIDE, KIND = false, nil
Valuate:ApplyContextScale()
eq(OPTIONS.characterWindowScale, nil, "and you go back to having no specific scale")

-- Nominated scale deleted: say so, change nothing. Switching to a scale that is not there
-- would leave every score reading zero.
OPTIONS.pvpScale = "Deleted"
OPTIONS.characterWindowScale = "Raid"
INSIDE, KIND = true, "pvp"
eq(Valuate:ApplyContextScale(), false, "a nominated scale that no longer exists is refused")
eq(OPTIONS.characterWindowScale, "Raid", "and your current scale is untouched")
eq(OPTIONS.pvpScaleRestore, nil, "with no restore marker left behind to confuse the way out")

-- The scale you were using got deleted while you were in the battleground.
OPTIONS.pvpScale = "Arena"
OPTIONS.characterWindowScale, OPTIONS.pvpScaleRestore = "Arena", "Gone"
INSIDE, KIND = false, nil
eq(Valuate:ApplyContextScale(), false, "restoring to a deleted scale is refused")
eq(OPTIONS.characterWindowScale, "Arena", "leaving the PvP one active rather than nothing")
eq(OPTIONS.pvpScaleRestore, nil, "and the marker is cleared so it does not retry forever")

return failures, checks
`,
  "queuetest",
  "queueing, releasing and leaving"
);
