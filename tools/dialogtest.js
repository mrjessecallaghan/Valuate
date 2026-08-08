#!/usr/bin/env node
/*
 * @gate The confirm dialog runs the callback it is currently showing
 *
 * Runs ui/Dialog.lua for real.
 *
 * ValuateConfirmDialog is a SINGLETON. One frame is created once and reused for every
 * question the addon asks, including "delete this scale?" - so the accept button is rebound
 * on each use, and the hazard is the same one that kept the scale list unpooled for eleven
 * releases: a reused control still wired to the previous request. Here the consequence is a
 * click on "Delete" running the callback from a dialog you already dismissed.
 *
 * A test that shows one dialog and clicks it passes whether or not the rebinding works.
 * Every case below shows a SECOND dialog first, then clicks, and checks which callback ran
 * - and equally that the other one did not, because "the right thing happened" and "only
 * the right thing happened" are different claims.
 *
 * The dialog exists because StaticPopup1..4 are recycled by Blizzard and showing one of
 * ours poisons the frame for later secure use (see CLAUDE.md §3). That is why this is our
 * own frame and why it has to be reused carefully rather than not reused.
 *
 * Usage:  node tools/dialogtest.js
 */
"use strict";

const { load } = require("./luaharness.js");

const run = load([
  "ui/Shared.lua",
  "ui/Data.lua",
  "ui/Animations.lua",
  "ui/Widgets.lua",
  "ui/Dialog.lua",
]);

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

local ns = __ns

-- ---- find the dialog ----------------------------------------------------------
-- Shown once so the frame exists, then located by NAME - it is the one frame in this file
-- that has one, and the name is what the Escape registration keys off too.
Valuate:ShowConfirmDialog({ text = "warm up" })

local dialog = nil
for _, f in ipairs(__frames) do
    if f.__name == "ValuateConfirmDialog" then dialog = f end
end
ok(dialog ~= nil, "the confirm dialog is created with its expected name")

local function accept() dialog.accept.__scripts.OnClick(dialog.accept) end
local function cancel() dialog.cancel.__scripts.OnClick(dialog.cancel) end

-- ---- one frame, reused --------------------------------------------------------
local before = #__frames
Valuate:ShowConfirmDialog({ text = "again" })
Valuate:ShowConfirmDialog({ text = "and again" })
eq(#__frames, before, "showing it again reuses the frame rather than building another")

-- ---- text and button labels follow the current request ------------------------
Valuate:ShowConfirmDialog({ text = "Delete the scale \\"Melee\\"?", acceptText = "Delete", cancelText = "Keep" })
eq(dialog.text:GetText(), "Delete the scale \\"Melee\\"?", "the message is the current one")
eq(dialog.accept.label:GetText(), "Delete", "the accept label is the current one")
eq(dialog.cancel.label:GetText(), "Keep", "the cancel label is the current one")

-- A request that does not name its buttons must not inherit the last one's labels.
-- "Delete" left sitting on a dialog asking something else is how a person clicks it.
Valuate:ShowConfirmDialog({ text = "Something else?" })
eq(dialog.accept.label:GetText(), "Okay", "an unnamed accept button falls back, it does not inherit \\"Delete\\"")
eq(dialog.cancel.label:GetText(), "Cancel", "...and neither does cancel")

-- ---- THE hazard: the callback belongs to the CURRENT dialog -------------------
local ranA, ranB = 0, 0
Valuate:ShowConfirmDialog({ text = "first", onAccept = function() ranA = ranA + 1 end })
Valuate:ShowConfirmDialog({ text = "second", onAccept = function() ranB = ranB + 1 end })
accept()
eq(ranB, 1, "accept runs the callback of the dialog on screen")
eq(ranA, 0, "...and NOT the one it replaced")

-- The same, the other way round, so a test that only ever moves in one direction cannot
-- pass by accident.
ranA, ranB = 0, 0
Valuate:ShowConfirmDialog({ text = "second", onAccept = function() ranB = ranB + 1 end })
Valuate:ShowConfirmDialog({ text = "first", onAccept = function() ranA = ranA + 1 end })
accept()
eq(ranA, 1, "and again with the order reversed")
eq(ranB, 0, "...still only the current one")

-- ---- cancel does not act ------------------------------------------------------
local acted, cancelled = 0, 0
Valuate:ShowConfirmDialog({
    text = "Delete 12 items?",
    onAccept = function() acted = acted + 1 end,
})
cancel()
eq(acted, 0, "cancel never runs onAccept")
eq(dialog:IsShown(), false, "cancel closes the dialog")

-- ---- accept closes before it acts ---------------------------------------------
-- The callback can open another dialog (a chained confirmation), so the frame must be
-- released first or the second Show would be undone by the first Hide.
local shownDuringCallback = nil
Valuate:ShowConfirmDialog({
    text = "chain",
    onAccept = function() shownDuringCallback = dialog:IsShown() end,
})
accept()
eq(shownDuringCallback, false, "the dialog is hidden BEFORE the callback runs")

-- A callback that opens another dialog leaves it on screen.
Valuate:ShowConfirmDialog({
    text = "outer",
    onAccept = function()
        Valuate:ShowConfirmDialog({ text = "inner", onAccept = function() acted = acted + 1 end })
    end,
})
accept()
eq(dialog:IsShown(), true, "a chained dialog opened from a callback stays up")
eq(dialog.text:GetText(), "inner", "...and it is the inner one")
accept()
eq(acted, 1, "the chained dialog's own callback runs")

-- ---- a dialog with no callbacks at all ----------------------------------------
Valuate:ShowConfirmDialog({ text = "just telling you" })
local safe = pcall(accept)
ok(safe, "accepting a dialog with no onAccept does not error")
eq(dialog:IsShown(), false, "...and still closes it")

-- ---- HideConfirmDialog --------------------------------------------------------
-- Escape is wired to hide the frame, and hiding must never act. That is the assumption
-- the Escape registration rests on, and check.js has a rule keeping callers honest to it.
acted = 0
Valuate:ShowConfirmDialog({ text = "pending", onAccept = function() acted = acted + 1 end })
Valuate:HideConfirmDialog()
eq(dialog:IsShown(), false, "HideConfirmDialog closes it")
eq(acted, 0, "closing without answering acts on nothing")

return failures, checks
`,
  "dialogtest",
  "the confirm dialog"
);
