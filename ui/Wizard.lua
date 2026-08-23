-- ui/Wizard.lua
-- The guided scale wizard: three screens, one decision each, ending on a working scale.
--
-- The decision-making lives in Valuate.lua (PlanAutoScale / CommitAutoScale / the matching
-- and naming behind them) and is gated headlessly. This file is deliberately only the
-- screens, so the part that can be reasoned about does not depend on a frame existing.
--
-- Frame state stays FILE-LOCAL. Nothing outside this file touches the wizard's frames, so
-- they never needed the ns.X treatment that genuinely shared state got. The one global is
-- ValuateWizardFrame, which exists because UISpecialFrames closes frames BY NAME.

local _, ns = ...

local PADDING, ELEMENT_SPACING, INNER_SPACING = ns.PADDING, ns.ELEMENT_SPACING, ns.INNER_SPACING
local BUTTON_HEIGHT = ns.BUTTON_HEIGHT
local COLORS = ns.COLORS
local FONT_H1, FONT_SMALL, FONT_BODY = ns.FONT_H1, ns.FONT_SMALL, ns.FONT_BODY
local Anim = ns.Anim

-- The wizard's colour, matching AUTO_SCALE_COLOR in Valuate.lua. Read through HexToRGB
-- rather than duplicated as three floats, so there is exactly one place it is written down.
local WIZARD_HEX = "3FE0C8"

local WIDTH, HEIGHT = 380, 300

-- Five named stats plus the "and N more" line. Fixed, because the rows are pooled.
local PREVIEW_ROWS = 6

-- Which dot is lit. Named rather than positional so adding a screen cannot silently
-- renumber the others.
local STEP_INDEX = { choose = 1, preview = 2, done = 3 }
local STEP_COUNT = 3

local WizardFrame = nil     -- the window
local screens = {}          -- name -> content frame
local currentScreen = nil
local currentPlan = nil     -- the plan being previewed; nil until step 2
-- Survives the plan being cleared on commit, because the done screen still needs to know
-- WHICH scale to open when you ask to fine-tune it.
local lastCreatedName = nil

-- ========================================
-- Small builders
-- ========================================

local function WizardRGB()
    local r, g, b = ns.HexToRGB(WIZARD_HEX)
    return r or 0.25, g or 0.88, b or 0.78
end

local function CreateLabel(parent, font, colour, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetText(text or "")
    fs:SetTextColor(unpack(colour))
    fs:SetJustifyH("LEFT")
    return fs
end

-- ========================================
-- Screen switching
-- ========================================

-- One screen visible at a time, and the new one pops in. Every screen is built once and
-- reused: WoW never frees frames, so rebuilding them per visit would leak for the session.
local function ShowScreen(name)
    for screenName, frame in pairs(screens) do
        if screenName == name then
            frame:Show()
            -- popIn honours Reduce Motion itself, so this does not branch on it.
            Anim.popIn(frame, 0.96, ns.MOTION and ns.MOTION.fast or 0.15)
        else
            frame:Hide()
        end
    end
    currentScreen = name

    -- Three dots, the current one lit. A wizard with no sense of position is just a
    -- sequence of dialogs; this is the cheapest thing that says "two more clicks", which
    -- is exactly what someone hesitating over an unfamiliar window wants to know.
    if WizardFrame and WizardFrame.stepDots then
        local current = STEP_INDEX[name] or 0
        for index, dot in ipairs(WizardFrame.stepDots) do
            if index == current then
                ns.SetSolidColor(dot, WizardRGB())
            else
                ns.SetSolidColor(dot, unpack(COLORS.textDim))
            end
        end
    end
end

-- ========================================
-- Screen 1: what are you building
-- ========================================
--
-- The primary action is "Build it for me" and it is the biggest thing on the screen. The
-- role buttons underneath are an override, not a question you must answer first - a wizard
-- that opens with a quiz is the thing this is trying not to be.

local ROLE_CHOICES = {
    { role = nil,       label = "Build it for me",  hint = "Reads your gear and picks the closest build. Start here." },
    { role = "TANK",    label = "Tank",             hint = "Weight survivability and threat instead." },
    { role = "HEALER",  label = "Healer",           hint = "Weight healing throughput and mana instead." },
    { role = "DAMAGER", label = "Damage",           hint = "Weight damage output instead." },
    -- Conquest of Azeroth only. Shown when the active template set actually HAS support
    -- specs, and left out otherwise: the classic ten classes have none, so on those realms
    -- this button could only ever answer "nothing resembles what you are wearing".
    --
    -- A control that cannot succeed is its own kind of bug, which is why this is filtered
    -- rather than always drawn.
    { role = "SUPPORT", label = "Support",          hint = "Weight group buffs and utility instead.",
      needsRole = "SUPPORT" },
}

-- True when the set this character will actually be matched against contains the role.
local function TemplateSetHasRole(role)
    local set = (Valuate.GetTemplateSet and Valuate:GetTemplateSet()) or ns.CLASS_SPEC_TEMPLATES
    for _, class in ipairs(set or {}) do
        for _, spec in ipairs(class.specs or {}) do
            if spec.role == role then return true end
        end
    end
    return false
end

local function BuildStepChoose(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)

    local title = CreateLabel(f, FONT_H1, COLORS.textTitle, "Make me a scale")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local blurb = CreateLabel(f, FONT_SMALL, COLORS.textDim,
        "A scale tells Valuate what to score gear on. This builds one from what\n" ..
        "you are already wearing, so you do not have to know the numbers.")
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -INNER_SPACING)

    -- Only the choices this character can actually be answered with. Filtered BEFORE the
    -- cascade is measured, so the stagger spaces the buttons that exist rather than leaving
    -- a gap where a hidden one would have been.
    local choices = {}
    for _, choice in ipairs(ROLE_CHOICES) do
        if not choice.needsRole or TemplateSetHasRole(choice.needsRole) then
            choices[#choices + 1] = choice
        end
    end

    local previous = blurb
    -- staggerFor returns the GAP between items, not a function of the index.
    local gap = Anim.staggerFor(#choices)
    for index, choice in ipairs(choices) do
        local isPrimary = (index == 1)
        local btn = ns.CreateStyledButton(f, choice.label, WIDTH - PADDING * 2,
            isPrimary and (BUTTON_HEIGHT + 8) or BUTTON_HEIGHT)
        btn:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0,
            isPrimary and -(ELEMENT_SPACING * 2) or -INNER_SPACING)

        if isPrimary then
            -- The recommended path looks like the recommended path. The text lives on
            -- btn.label; a styled button has no SetTextColor of its own.
            btn.label:SetTextColor(WizardRGB())
        end

        btn:SetScript("OnClick", function()
            ns.WizardPlan(choice.role)
        end)
        -- HookScript, not SetScript. CreateStyledButton installs its own OnEnter/OnLeave to
        -- run the hover fade, and replacing them would silently kill the hover animation on
        -- exactly the buttons this screen is made of.
        btn:HookScript("OnEnter", function(self)
            -- ShowTooltipSafe only claims the tooltip (and declines while a frame is being
            -- dragged); the content is still ours to set.
            if ns.ShowTooltipSafe(self) then
                GameTooltip:SetText(choice.label)
                GameTooltip:AddLine(choice.hint, unpack(COLORS.textBody))
                GameTooltip:Show()
            end
        end)
        btn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

        Anim.revealIn(btn, gap * (index - 1))
        previous = btn
    end

    return f
end

-- ========================================
-- Screen 2: here is what I would make
-- ========================================
--
-- Everything shown here comes off the plan object. Nothing is recomputed, so the preview
-- cannot disagree with what gets created - which is the failure people never forgive in a
-- confirm screen.

local function BuildStepPreview(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)

    local title = CreateLabel(f, FONT_H1, COLORS.textTitle, "This is what I would make")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    f.name = CreateLabel(f, FONT_H1, { WizardRGB() }, "")
    f.name:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    f.basedOn = CreateLabel(f, FONT_SMALL, COLORS.textDim, "")
    f.basedOn:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -INNER_SPACING)

    -- Sits between the match line and the weights, and is EMPTY when the match was good -
    -- an always-present caution is one nobody reads.
    f.caution = CreateLabel(f, FONT_SMALL, COLORS.textAccent, "")
    f.caution:SetPoint("TOPLEFT", f.basedOn, "BOTTOMLEFT", 0, -INNER_SPACING)
    f.caution:SetWidth(WIDTH - PADDING * 2)

    -- One row per stat rather than a single block of text, so they can cascade in - the
    -- weights are the substance of the screen and a cascade is how this addon says
    -- "here is a list, read it in order" everywhere else.
    --
    -- Built ONCE and repopulated. WoW never frees a frame, so rebuilding these per preview
    -- would leak for the session, and this screen is shown every time the wizard runs.
    f.rows = {}
    for i = 1, PREVIEW_ROWS do
        local row = CreateLabel(f, FONT_SMALL, COLORS.textBody, "")
        if i == 1 then
            row:SetPoint("TOPLEFT", f.caution, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
        else
            row:SetPoint("TOPLEFT", f.rows[i - 1], "BOTTOMLEFT", 0, -2)
        end
        row:SetWidth(WIDTH - PADDING * 2)
        f.rows[i] = row
    end

    local create = ns.CreateStyledButton(f, "Create it", 150, BUTTON_HEIGHT + 4)
    create:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    create:SetScript("OnClick", function() ns.WizardCommit() end)
    f.create = create

    local back = ns.CreateStyledButton(f, "Back", 90, BUTTON_HEIGHT)
    back:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    back:SetScript("OnClick", function() ShowScreen("choose") end)

    return f
end

-- The five stats that name the scale, listed with their weights - the same five, in the
-- same order, so the name is legible rather than mysterious.
local function DescribeWeights(weights)
    local ranked = {}
    for stat, weight in pairs(weights or {}) do
        table.insert(ranked, { stat = stat, weight = weight })
    end
    -- Same total order the name uses: weight first, then stat name. Two different orders
    -- for the same data would make the preview contradict the title above it.
    table.sort(ranked, function(a, b)
        if a.weight ~= b.weight then return a.weight > b.weight end
        return a.stat < b.stat
    end)

    local lines, shown = {}, math.min(PREVIEW_ROWS - 1, #ranked)
    for i = 1, shown do
        local abbrev = (ValuateStatAbbreviations or {})[ranked[i].stat] or ranked[i].stat
        table.insert(lines, string.format("%s  %.2f", abbrev, ranked[i].weight))
    end
    if #ranked > shown then
        table.insert(lines, string.format("and %d more", #ranked - shown))
    end
    -- A LIST, not a joined block: the caller gives each line its own row so they can
    -- cascade. Returning text with newlines is what made that impossible before.
    return lines
end

-- ========================================
-- Screen 3: done
-- ========================================

-- When it cannot build one.
--
-- This used to print the reason to chat and return, leaving the wizard sitting on the screen
-- you were already on. Every refusal PlanAutoScale writes is deliberately actionable - "put
-- something on first" - and all of that care was being delivered behind the window that had
-- just failed to respond, to someone whose attention is on the button they pressed.
--
-- The likeliest way to reach it is also the worst place to be lost: a brand-new character
-- wearing nothing, on the first screen of the addon they just installed.
local function BuildStepFailed(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)

    local title = CreateLabel(f, FONT_H1, COLORS.textTitle, "I could not build one")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    -- The reason in PlanAutoScale's own words. Rewording it here would mean two places to
    -- keep true, and the version behind the window is the one that gets updated.
    f.reason = CreateLabel(f, FONT_BODY, COLORS.textBody, "")
    f.reason:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    f.reason:SetWidth(WIDTH - PADDING * 2)

    local hint = CreateLabel(f, FONT_SMALL, COLORS.textDim,
        "Nothing was created or changed. Fix the above and try again, or build a scale by " ..
        "hand from a class template.")
    hint:SetPoint("TOPLEFT", f.reason, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    hint:SetWidth(WIDTH - PADDING * 2)

    -- Back to the start rather than only Close: the usual fix - equip something, pick a
    -- different role - is one screen away, and closing the window to reopen it is a step
    -- nobody should have to work out for themselves.
    local retry = ns.CreateStyledButton(f, "Try again", 150, BUTTON_HEIGHT + 4)
    retry:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    retry:SetScript("OnClick", function() ShowScreen("choose") end)

    local close = ns.CreateStyledButton(f, "Close", 120, BUTTON_HEIGHT)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    close:SetScript("OnClick", function() if WizardFrame then WizardFrame:Hide() end end)

    return f
end

local function BuildStepDone(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)

    local title = CreateLabel(f, FONT_H1, COLORS.textTitle, "Done")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    f.name = CreateLabel(f, FONT_H1, { WizardRGB() }, "")
    f.name:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    f.blurb = CreateLabel(f, FONT_SMALL, COLORS.textBody, "")
    f.blurb:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -INNER_SPACING)
    f.blurb:SetWidth(WIDTH - PADDING * 2)

    local close = ns.CreateStyledButton(f, "Close", 150, BUTTON_HEIGHT + 4)
    close:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    close:SetScript("OnClick", function() if WizardFrame then WizardFrame:Hide() end end)

    local tweak = ns.CreateStyledButton(f, "Fine-tune it", 120, BUTTON_HEIGHT)
    tweak:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    tweak:SetScript("OnClick", function()
        local name = lastCreatedName
        if WizardFrame then WizardFrame:Hide() end
        -- ShowUI, not ToggleUI: toggling would CLOSE the main window for anyone who had it
        -- open behind the wizard, which is the opposite of "fine-tune it".
        if Valuate.ShowUI then Valuate:ShowUI() end

        -- ...and SELECT the scale it just made. Opening the window and leaving you to find
        -- the new row is the same "now go and do it yourself" the wizard exists to remove,
        -- and it is worse here than anywhere: the row you are looking for is one of several
        -- that all start "Auto - ".
        --
        -- Clicked rather than assigned, because selecting a scale also loads it into the
        -- editor and repaints the list; ScaleList owns that sequence and duplicating it
        -- here would be a second copy of one rule, which this project keeps paying for.
        local button = ns.ScaleListButtons and ns.ScaleListButtons[name]
        local onClick = button and button.GetScript and button:GetScript("OnClick")
        if onClick then onClick(button) end
    end)

    return f
end

-- ========================================
-- The window
-- ========================================

local function CreateWizardFrame()
    local f = CreateFrame("Frame", "ValuateWizardFrame", UIParent)
    f:SetWidth(WIDTH)
    f:SetHeight(HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetBackdrop(ns.BACKDROP_WINDOW)
    f:SetBackdropColor(unpack(COLORS.bgWindow or COLORS.borderDark))
    f:SetBackdropBorderColor(WizardRGB())
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:Hide()

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", PADDING, -PADDING)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PADDING, PADDING)

    -- The step dots live on the WINDOW, not on a screen: they are the one thing that has to
    -- outlive whichever screen is showing.
    f.stepDots = {}
    for i = 1, STEP_COUNT do
        local dot = f:CreateTexture(nil, "OVERLAY")
        dot:SetWidth(6)
        dot:SetHeight(6)
        dot:SetPoint("BOTTOM", f, "BOTTOM", (i - (STEP_COUNT + 1) / 2) * 12, 6)
        ns.SetSolidColor(dot, unpack(COLORS.textDim))
        f.stepDots[i] = dot
    end

    screens.choose = BuildStepChoose(body)
    screens.preview = BuildStepPreview(body)
    screens.done = BuildStepDone(body)
    screens.failed = BuildStepFailed(body)

    -- Escape closes it. Registered by NAME, which is why the frame has one.
    ns.RegisterEscapeClose("ValuateWizardFrame")

    return f
end

-- ========================================
-- Flow
-- ========================================

-- Step 1 -> 2. Plans only; nothing is created until the user says so on the next screen.
function ns.WizardPlan(role)
    if not Valuate.PlanAutoScale then return end

    local totals = Valuate.GetCachedEquippedStatTotals and Valuate:GetCachedEquippedStatTotals()
    local plan, why = Valuate:PlanAutoScale({
        -- The set matching this character's class: Conquest of Azeroth's 21 classes, or the
        -- classic ten. Proposing "Stormbringer Lightning" to a Warrior would be nonsense, and
        -- so would proposing "Arms Warrior" to a Necromancer.
        templates = (Valuate.GetTemplateSet and Valuate:GetTemplateSet()) or ns.CLASS_SPEC_TEMPLATES,
        totals = totals,
        role = role,
    })

    if not plan then
        -- Shown IN the wizard, in the words PlanAutoScale chose. It used to print and return,
        -- which left the window sitting on the screen you were already on while the
        -- explanation went to the chat frame behind it - a button that appears to do nothing.
        local message = tostring(why or "I could not build a scale.")
        if screens.failed then
            screens.failed.reason:SetText(message)
            ShowScreen("failed")
        else
            -- Only if the screen failed to build. Losing the reason entirely would be worse
            -- than printing it somewhere imperfect.
            print("|cFF3FE0C8[Valuate]|r " .. message)
        end
        return
    end

    currentPlan = plan
    local screen = screens.preview
    screen.name:SetText(plan.name)
    screen.basedOn:SetText(string.format("Closest to %s. %d%% match%s.",
        tostring(plan.basedOn), math.floor((plan.confidence or 0) * 100 + 0.5),
        plan.alternative and (", and " .. tostring(plan.alternative) .. " was almost as close") or ""))
    -- Already have it: say so plainly and change what the button offers to do. Creating a
    -- second identical scale and suffixing it "(2)" leaves you with two rows you cannot
    -- tell apart, which is a worse outcome than the one you came for.
    if plan.duplicateOf then
        screen.caution:SetText("You already have this exact scale. I will just switch to it.")
        screen.create.label:SetText("Use it")
    elseif plan.updates then
        -- Replacing a scale the wizard made before, rather than adding a near-duplicate to a
        -- list that is already hard to tell apart. Names it, because "Update" without saying
        -- what is being updated is the sort of button people do not press.
        screen.caution:SetText(string.format(
            "This replaces %s, which I made earlier and your gear has moved on from.",
            tostring(plan.updates)))
        screen.create.label:SetText("Update it")
    else
        screen.caution:SetText(plan.caution or "")
        screen.create.label:SetText("Create it")
    end

    -- Rows cascade in rather than appearing as a block. Unused rows are emptied AND hidden,
    -- because a pooled row still showing last run's stat is the classic pool bug.
    local lines = DescribeWeights(plan.weights)
    local gap = Anim.staggerFor(#lines)
    for i, row in ipairs(screen.rows) do
        if lines[i] then
            row:SetText(lines[i])
            row:Show()
            Anim.revealIn(row, gap * (i - 1))
        else
            row:SetText("")
            row:Hide()
        end
    end

    ShowScreen("preview")
end

-- Step 2 -> 3. The only place the wizard writes anything.
-- What the last screen says happened, chosen from what CommitAutoScale actually did.
--
-- Three outcomes, and every one of them makes a promise about YOUR OTHER SCALES:
--
--   "reused"    you already had this exact scale, so nothing new was made
--   "updated"   one wizard-made scale was replaced, and the rest are untouched
--   nil         a plain creation - nothing was overwritten at all
--
-- Getting this mapping wrong corrupts nothing: CommitAutoScale has already done whatever it
-- did, and it is gated separately. What it does is tell you the wrong thing about your own
-- data - and the third sentence is an explicit promise that nothing was overwritten. Printing
-- that on the branch which just deleted a scale is the failure this project cares most about:
-- not the action, the claim made about it.
--
-- An unrecognised `why` gets the CAUTIOUS wording, never the promise. nil means creation
-- because that is precisely what CommitAutoScale returns for one; anything else is an outcome
-- added later, and a new outcome must not silently inherit a guarantee written before it
-- existed. That is how the wizard came to offer to overwrite any scale it had made.
--
-- Returns the blurb text.
function ns.WizardOutcomeText(why)
    if why == "updated" then
        return "Updated to match the gear you are wearing now, and made your primary scale. " ..
               "Your other scales are untouched."
    end
    if why == "reused" then
        -- Says what actually happened. Reporting "created" here would be a small lie that
        -- sends you looking for a new row that does not exist.
        return "You already had this one, so nothing new was made - it is just your primary " ..
               "scale now, and your gear has been rescanned."
    end
    if why == nil then
        return "It is now your primary scale, and your gear has been rescanned - item tooltips " ..
               "and Best Equipment already use it.\n\nYou can run this again any time; it never " ..
               "overwrites a scale you already have."
    end
    -- Something this function has not been taught about. Say the part that is true of every
    -- outcome and claim nothing beyond it.
    return "It is now your primary scale, and your gear has been rescanned."
end

function ns.WizardCommit()
    if not currentPlan or not Valuate.CommitAutoScale then return end

    local scale, why = Valuate:CommitAutoScale(currentPlan)
    if not scale then
        print("|cFF3FE0C8[Valuate]|r " .. tostring(why or "I could not create that scale."))
        return
    end

    local screen = screens.done
    screen.name:SetText(currentPlan.name)
    screen.blurb:SetText(ns.WizardOutcomeText(why))

    ShowScreen("done")

    if Valuate.PulseMinimapButton then Valuate:PulseMinimapButton() end
    lastCreatedName = currentPlan.name
    currentPlan = nil
end

function Valuate:ShowScaleWizard()
    if not WizardFrame then WizardFrame = CreateWizardFrame() end
    currentPlan = nil
    ShowScreen("choose")
    WizardFrame:Show()
    Anim.popIn(WizardFrame, 0.94)
end

ns.ShowScaleWizard = function() Valuate:ShowScaleWizard() end
