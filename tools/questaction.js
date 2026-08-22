#!/usr/bin/env node
/*
 * @gate Marking the best quest reward never takes it
 *
 * Runs the REAL Valuate:AutoSelectBestQuestReward, with the REAL ChooseQuestReward policy
 * inside it, against a mocked quest frame.
 *
 * tools/questtest.js proves the POLICY - which reward should win, and when to decline to guess.
 * Nothing proved the ACTION built on it, which is the same split that left auto-delete's bound
 * untested: the decision was covered and the thing that acts on the decision was not.
 *
 * A quest reward is irreversible in a way even deletion is not - the other choices are gone the
 * moment the quest completes, and there is no vendor buyback for a road not taken. So the
 * property this file exists for is the boring one:
 *
 *     WITH AUTO TURN-IN OFF, THIS MUST ONLY DRAW A HIGHLIGHT.
 *
 * Two features share one function. The first suggests, by anchoring a texture to the reward
 * button; the second takes the reward through GetQuestReward. If those ever cross, the addon
 * completes quests the user only asked it to advise on - and the user finds out afterwards.
 *
 * The marker is drawn WITHOUT touching Blizzard's UI on purpose: writing QuestInfoFrame's
 * fields or calling QuestInfoItem_OnClick from addon code taints the quest frame, and the
 * client then blocks "Complete Quest" outright. That constraint is asserted too, because the
 * obvious "improvement" is to just click the button for them.
 *
 * Usage:  node tools/questaction.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const { load, ADDON_ROOT } = require("./luaharness.js");

const lua = fs.readFileSync(path.join(ADDON_ROOT, "Valuate.lua"), "utf8");

function slice(header, what) {
  const hit = lua.match(new RegExp("^" + header + "\\([\\s\\S]*?\\r?\\nend\\r?\\n", "m"));
  if (!hit) {
    console.error("  SLICE  could not find " + what + " in Valuate.lua - this gate tests nothing");
    process.exit(1);
  }
  return hit[0];
}

const policy = slice("local function ChooseQuestReward", "ChooseQuestReward");
const action = slice("function Valuate:AutoSelectBestQuestReward", "AutoSelectBestQuestReward");

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

-- ---- the quest frame ---------------------------------------------------------------------------
-- CHOICES is index -> { score, baseline }. The score is what your scale makes of the reward; the
-- baseline is what you already have in that slot, which is what turns a score into an upgrade.
CHOICES = {}
REWARD_TAKEN = nil          -- the index passed to GetQuestReward, or nil if it was never called
GetNumQuestChoices = function() local n = 0 for _ in pairs(CHOICES) do n = n + 1 end return n end
GetQuestItemLink = function(_, index) return "|Hitem:" .. (100 + index) .. ":0|h[Reward " .. index .. "]|h" end
GetQuestReward = function(index) REWARD_TAKEN = index end

-- Stubbed: the scoring has its own gate, and re-deriving it here would be a second opinion
-- rather than a new one. What is untested is what gets DONE with the answer.
function ScoreQuestChoice(index, scale) return CHOICES[index] and CHOICES[index].score or nil end
Valuate.GetUpgradeBaseline = function(_, link, _, _)
    local index = tonumber(link:match("Reward (%d+)"))
    return (index and CHOICES[index] and CHOICES[index].baseline) or 0
end

SCALE = { DisplayName = "Dps" }
Valuate.GetPrimaryScale = function() return SCALE, SCALE and "Dps" or nil end
Valuate.MarkAutomation = function() end

-- The reward buttons Blizzard would have created, and a UIParent that can make a texture.
for i = 1, 4 do _G["QuestInfoItem" .. i] = CreateFrame("Button") end
UIParent = CreateFrame("Frame")

OPTIONS = {}
Valuate.GetOptions = function() return OPTIONS end

local function questWith(...)
    CHOICES, REWARD_TAKEN = {}, nil
    Valuate.questRewardMarker = nil
    __printed = {}
    for i, c in ipairs({ ... }) do CHOICES[i] = c end
end
local function choice(score, baseline) return { score = score, baseline = baseline or 0 } end

local function markedIndex()
    local marker = Valuate.questRewardMarker
    if not marker or not marker:IsShown() then return nil end
    -- Which button it is anchored to.
    for _, pt in ipairs(marker.__points or {}) do
        for i = 1, 4 do
            if pt[2] == _G["QuestInfoItem" .. i] then return i end
        end
    end
    return nil
end

` + policy + `
` + action + `

-- ---- SUGGESTING IS NOT TAKING ------------------------------------------------------------------
-- The property this file exists for. Two features share one function: one draws a highlight,
-- the other completes the quest. If they ever cross, the addon takes rewards the user only
-- asked it to advise on, and there is no undo for a quest reward.
OPTIONS = { autoQuestReward = true, autoQuestTurnIn = false }
questWith(choice(10), choice(90), choice(30))
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, nil, "with auto turn-in OFF the quest is never completed")
eq(markedIndex(), 2, "but the best reward is highlighted for you to click")

-- ...and with it on, the same choice is actually taken.
OPTIONS.autoQuestTurnIn = true
questWith(choice(10), choice(90), choice(30))
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, 2, "with auto turn-in ON the same reward is taken")

-- ---- IT NEVER CLICKS BLIZZARD'S BUTTON -----------------------------------------------------------
-- Writing QuestInfoFrame's fields or calling QuestInfoItem_OnClick from addon code taints the
-- quest frame, and the client then blocks "Complete Quest" outright - so the addon draws its own
-- texture and lets you click. The obvious "improvement" is to click it for them, which breaks
-- the quest frame for the rest of the session.
CLICKED = false
QuestInfoItem_OnClick = function() CLICKED = true end
OPTIONS.autoQuestTurnIn = false
questWith(choice(10), choice(90))
Valuate:AutoSelectBestQuestReward()
eq(CLICKED, false, "the reward button is never clicked from addon code")

-- ---- THE FEATURE SWITCH -----------------------------------------------------------------------------
OPTIONS = { autoQuestReward = false, autoQuestTurnIn = true }
questWith(choice(10), choice(90))
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, nil, "switched off, it takes nothing even with turn-in enabled")
eq(markedIndex(), nil, "and marks nothing")

-- ---- NO SCALE MEANS NO OPINION ------------------------------------------------------------------------
-- Every score here is your stat weights applied to a reward. With no scale there are no weights,
-- and guessing would spend a choice you cannot get back.
OPTIONS = { autoQuestReward = true, autoQuestTurnIn = true, chatMessages = true }
SCALE = nil
questWith(choice(10), choice(90))
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, nil, "with no active scale it takes nothing rather than guessing")
ok(table.concat(__printed, "\\n"):find("no active scale", 1, true) ~= nil,
   "and says why, rather than looking broken")
SCALE = { DisplayName = "Dps" }

-- ---- WHEN THE POLICY DECLINES, NOTHING HAPPENS ---------------------------------------------------------
-- ChooseQuestReward returns nil in exactly one situation: more than one choice, and NOT ONE of
-- them could be scored. Taking one anyway would be the addon making an arbitrary irreversible
-- choice on no information at all.
--
-- The first version of this test used a TIE, on the assumption that equal scores are refused.
-- They are not - the policy takes the first of them, deliberately and deterministically - so
-- that assertion was testing a rule the addon does not have.
OPTIONS = { autoQuestReward = true, autoQuestTurnIn = true, chatMessages = true }
CHOICES, REWARD_TAKEN = {}, nil
Valuate.questRewardMarker = nil
CHOICES[1] = { score = nil, baseline = 0 }
CHOICES[2] = { score = nil, baseline = 0 }
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, nil, "two rewards, neither readable: it takes nothing rather than guessing")
eq(markedIndex(), nil, "and marks nothing, so the gap is visible rather than papered over")

-- A tie IS broken, and always the same way. Equal-scoring rewards are common - two pieces of
-- the same armour type for the same slot - and a coin flip that lands differently between
-- reloads would be worse than a rule, because you could not learn it.
questWith(choice(50), choice(50))
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, 1, "equal scores go to the first, rather than being refused")
questWith(choice(50), choice(50))
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, 1, "and the same way every time")

-- ONE choice is not a choice. Even unreadable, it is the only thing on offer, so taking it
-- costs nothing that could have been kept.
CHOICES, REWARD_TAKEN = {}, nil
Valuate.questRewardMarker = nil
CHOICES[1] = { score = nil, baseline = 0 }
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, 1, "a single unreadable reward is still taken, because there is no alternative")

-- ---- THE UPGRADE, NOT THE BIGGEST NUMBER -----------------------------------------------------------------
-- A strong weapon you will never beat your current best with should lose to a modest trinket
-- that fills an empty slot. That is why the delta against GetUpgradeBaseline exists at all - and
-- it is only visible when the two answers DIFFER, so this fixture makes them differ.
OPTIONS = { autoQuestReward = true, autoQuestTurnIn = true }
questWith(choice(100, 95), choice(60, 0))
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, 2, "the reward that most improves your gear wins over the highest raw score")

-- ---- NO CHOICE TO MAKE ---------------------------------------------------------------------------------------
-- Index 0 is the guaranteed reward. With turn-in on, the quest still completes; with it off,
-- nothing happens at all, because there was nothing to advise on.
OPTIONS = { autoQuestReward = true, autoQuestTurnIn = true }
questWith()
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, 0, "a quest with no reward choice still completes, taking the guaranteed reward")

OPTIONS.autoQuestTurnIn = false
questWith()
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, nil, "with turn-in off, a quest with no choice is left alone entirely")

-- ---- A REWARD THAT WILL NOT SCORE -------------------------------------------------------------------------------
-- ScoreQuestChoice returns nil for something it cannot read. That choice must be absent from the
-- ranking rather than counted as zero, which would make an unreadable reward lose to anything -
-- including a genuinely worthless one.
OPTIONS = { autoQuestReward = true, autoQuestTurnIn = true }
CHOICES, REWARD_TAKEN = {}, nil
Valuate.questRewardMarker = nil
CHOICES[1] = { score = nil, baseline = 0 }   -- unreadable
CHOICES[2] = choice(40)
Valuate:AutoSelectBestQuestReward()
eq(REWARD_TAKEN, 2, "an unreadable reward is skipped and the readable one is chosen")

return failures, checks
`,
  "questaction",
  "the quest reward action"
);
