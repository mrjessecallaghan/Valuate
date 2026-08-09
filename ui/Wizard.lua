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
local FONT_H1, FONT_SMALL = ns.FONT_H1, ns.FONT_SMALL
local Anim = ns.Anim

-- The wizard's colour, matching AUTO_SCALE_COLOR in Valuate.lua. Read through HexToRGB
-- rather than duplicated as three floats, so there is exactly one place it is written down.
local WIZARD_HEX = "3FE0C8"

local WIDTH, HEIGHT = 380, 300

local WizardFrame = nil     -- the window
local screens = {}          -- name -> content frame
local currentScreen = nil
local currentPlan = nil     -- the plan being previewed; nil until step 2

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
}

local function BuildStepChoose(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)

    local title = CreateLabel(f, FONT_H1, COLORS.textTitle, "Make me a scale")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

    local blurb = CreateLabel(f, FONT_SMALL, COLORS.textDim,
        "A scale tells Valuate what to score gear on. This builds one from what\n" ..
        "you are already wearing, so you do not have to know the numbers.")
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -INNER_SPACING)

    local previous = blurb
    -- staggerFor returns the GAP between items, not a function of the index.
    local gap = Anim.staggerFor(#ROLE_CHOICES)
    for index, choice in ipairs(ROLE_CHOICES) do
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

    f.weights = CreateLabel(f, FONT_SMALL, COLORS.textBody, "")
    f.weights:SetPoint("TOPLEFT", f.caution, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    f.weights:SetWidth(WIDTH - PADDING * 2)
    f.weights:SetJustifyV("TOP")

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

    local lines, shown = {}, math.min(5, #ranked)
    for i = 1, shown do
        local abbrev = (ValuateStatAbbreviations or {})[ranked[i].stat] or ranked[i].stat
        table.insert(lines, string.format("%s  %.2f", abbrev, ranked[i].weight))
    end
    if #ranked > shown then
        table.insert(lines, string.format("and %d more", #ranked - shown))
    end
    return table.concat(lines, "\n")
end

-- ========================================
-- Screen 3: done
-- ========================================

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
        if WizardFrame then WizardFrame:Hide() end
        -- ShowUI, not ToggleUI: toggling would CLOSE the main window for anyone who had it
        -- open behind the wizard, which is the opposite of "fine-tune it".
        if Valuate.ShowUI then Valuate:ShowUI() end
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

    screens.choose = BuildStepChoose(body)
    screens.preview = BuildStepPreview(body)
    screens.done = BuildStepDone(body)

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
        templates = ns.CLASS_SPEC_TEMPLATES,
        totals = totals,
        role = role,
    })

    if not plan then
        -- Says what went wrong in the words PlanAutoScale chose, rather than a dead end.
        -- Every refusal in that function is written to be actionable.
        print("|cFF3FE0C8[Valuate]|r " .. tostring(why or "I could not build a scale."))
        return
    end

    currentPlan = plan
    local screen = screens.preview
    screen.name:SetText(plan.name)
    screen.basedOn:SetText(string.format("Closest to %s. %d%% match%s.",
        tostring(plan.basedOn), math.floor((plan.confidence or 0) * 100 + 0.5),
        plan.alternative and (", and " .. tostring(plan.alternative) .. " was almost as close") or ""))
    screen.caution:SetText(plan.caution or "")
    screen.weights:SetText(DescribeWeights(plan.weights))
    ShowScreen("preview")
end

-- Step 2 -> 3. The only place the wizard writes anything.
function ns.WizardCommit()
    if not currentPlan or not Valuate.CommitAutoScale then return end

    local scale, why = Valuate:CommitAutoScale(currentPlan)
    if not scale then
        print("|cFF3FE0C8[Valuate]|r " .. tostring(why or "I could not create that scale."))
        return
    end

    local screen = screens.done
    screen.name:SetText(currentPlan.name)
    screen.blurb:SetText(
        "It is now your primary scale, and your gear has been rescanned - item tooltips " ..
        "and Best Equipment already use it.\n\nYou can run this again any time; it never " ..
        "overwrites a scale you already have.")
    ShowScreen("done")

    if Valuate.PulseMinimapButton then Valuate:PulseMinimapButton() end
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
