-- ValuateUI.lua
-- UI Window for Valuate stat weight calculator

-- Ensure Valuate namespace exists (defensive check)
if not Valuate then
    Valuate = {}
end

-- ========================================
-- UI Constants (defined in ui/Shared.lua)
-- ========================================
-- Separate .lua files cannot see each other's locals, so the design tokens live on the
-- addon private table and are re-localised here. Every existing reference below keeps
-- working unchanged, and local lookups stay as fast as before.
local _, ns = ...

local PADDING, ELEMENT_SPACING, INNER_SPACING, COLUMN_GAP =
    ns.PADDING, ns.ELEMENT_SPACING, ns.INNER_SPACING, ns.COLUMN_GAP
local BUTTON_HEIGHT, ENTRY_HEIGHT, SCROLLBAR_WIDTH =
    ns.BUTTON_HEIGHT, ns.ENTRY_HEIGHT, ns.SCROLLBAR_WIDTH
local NUM_COLUMNS, COLUMN_WIDTH, ROW_HEIGHT, ROW_SPACING, HEADER_HEIGHT, HEADER_SPACING =
    ns.NUM_COLUMNS, ns.COLUMN_WIDTH, ns.ROW_HEIGHT, ns.ROW_SPACING, ns.HEADER_HEIGHT, ns.HEADER_SPACING
local SCALE_LIST_WIDTH, EDITOR_CONTENT_WIDTH, WINDOW_WIDTH =
    ns.SCALE_LIST_WIDTH, ns.EDITOR_CONTENT_WIDTH, ns.WINDOW_WIDTH
local MIN_WINDOW_HEIGHT, MAX_WINDOW_HEIGHT = ns.MIN_WINDOW_HEIGHT, ns.MAX_WINDOW_HEIGHT

local COLORS = ns.COLORS
local BORDER_TOOLTIP, BORDER_EDGE_SIZE = ns.BORDER_TOOLTIP, ns.BORDER_EDGE_SIZE
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_INPUT, BACKDROP_BUTTON =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_INPUT, ns.BACKDROP_BUTTON

-- Static reference data (defined in ui/Data.lua)
local SCALE_ICON_LIST, CLASS_SPEC_TEMPLATES = ns.SCALE_ICON_LIST, ns.CLASS_SPEC_TEMPLATES

-- Pickers (defined in ui/Pickers.lua)
local ShowIconPicker = ns.ShowIconPicker

-- Scale list panel (defined in ui/ScaleList.lua)
local UpdateScaleList, CreateScaleList = ns.UpdateScaleList, ns.CreateScaleList

-- Best Equipment panel (defined in ui/BestEquipment.lua)
local CreateBestEquipmentPanel = ns.CreateBestEquipmentPanel

-- Settings panel (defined in ui/Settings.lua)
local CreateSettingsPanel = ns.CreateSettingsPanel

-- Read-only content tabs (defined in ui/InfoPanels.lua)
local CreateInstructionsPanel, CreateAboutPanel, CreateChangelogPanel =
    ns.CreateInstructionsPanel, ns.CreateAboutPanel, ns.CreateChangelogPanel

-- Widgets and helpers (defined in ui/Widgets.lua)
local ValidateStatValueInput, ValidateWholeNumberInput =
    ns.ValidateStatValueInput, ns.ValidateWholeNumberInput
local ApplyStatValueValidation, ApplyWholeNumberValidation =
    ns.ApplyStatValueValidation, ns.ApplyWholeNumberValidation
local ShowTooltipSafe, CreateStyledButton = ns.ShowTooltipSafe, ns.CreateStyledButton
local HexToRGB, RGBToHex = ns.HexToRGB, ns.RGBToHex
-- NOTE: IsDraggingFrame is shared MUTABLE state and is therefore always accessed as
-- ns.IsDraggingFrame - a re-localised copy would never see updates from other files.

-- ========================================
-- Input Validation Functions
-- ========================================

-- Font Standards (all use white/highlight fonts for modern look)
-- Font styles (defined in ui/Shared.lua, re-localised here)
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL


-- Main UI Frame


-- Forward declaration for overwrite callback


-- ValuateOptions and ValuateScales are per-character SavedVariablesPerCharacter
-- accessed via Valuate:GetOptions() and Valuate:GetScales()


-- ========================================
-- Role Icon Configuration
-- ========================================



-- Creates a styled button with consistent look
-- ========================================
-- Animation engine (defined in ui/Animations.lua)
-- ========================================
-- Re-localised from the shared namespace. The engine keeps its own state (the active
-- tween list and the ticker frame) internal to that file - nothing here mutates it,
-- so plain re-localisation is safe.
local Anim, Easing = ns.Anim, ns.Easing
local ReduceMotion, EaseOutQuad = ns.ReduceMotion, ns.EaseOutQuad
local ColorLerp, ValuateTween, TweenBackdrop = ns.ColorLerp, ns.ValuateTween, ns.TweenBackdrop



-- ========================================
-- Main Window Creation
-- ========================================

local function CreateMainWindow()
    if ns.ValuateUIFrame then
        return ns.ValuateUIFrame
    end
    
    -- Main frame
    local frame = CreateFrame("Frame", "ValuateUIFrame", UIParent)
    frame:SetWidth(WINDOW_WIDTH)
    frame:SetHeight(MIN_WINDOW_HEIGHT)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("DIALOG")  -- Above most UI elements
    
    -- Backdrop (standardized clean border)
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    
    -- Position (restored from saved settings)
    local options = Valuate:GetOptions()
    if options and options.uiPosition and options.uiPosition.point and options.uiPosition.x and options.uiPosition.y then
        frame:SetPoint(options.uiPosition.point, UIParent, options.uiPosition.relativePoint or options.uiPosition.point, options.uiPosition.x, options.uiPosition.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Save position on move
    frame:SetScript("OnDragStart", function(self)
        ns.IsDraggingFrame = true
        GameTooltip:Hide()  -- Hide any visible tooltips
        self:StartMoving()
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.IsDraggingFrame = false
        local options = Valuate:GetOptions()
        if options then
            if not options.uiPosition then
                options.uiPosition = {}
            end
            local point, _, relativePoint, x, y = self:GetPoint()
            options.uiPosition.point = point
            options.uiPosition.relativePoint = relativePoint
            options.uiPosition.x = x
            options.uiPosition.y = y
        end
    end)
    
    -- Title bar (clean, minimal)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -8)
    titleBar:SetHeight(24)
    
    -- Title text (centered)
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", FONT_TITLE)
    titleText:SetPoint("CENTER", frame, "TOP", 0, -20)
    titleText:SetText("Valuate")
    titleText:SetTextColor(unpack(COLORS.textTitle))
    
    -- Version text (smaller, next to title)
    local versionText = titleBar:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    versionText:SetPoint("LEFT", titleText, "RIGHT", 6, 0)
    versionText:SetText("v" .. (Valuate.version or "?"))
    versionText:SetTextColor(unpack(COLORS.textDim))
    
    -- Close button (custom styled)
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeButton:SetBackdrop(BACKDROP_BUTTON)
    closeButton:SetBackdropColor(0.2, 0.2, 0.2, 1)
    closeButton:SetBackdropBorderColor(unpack(COLORS.border))
    
    local closeLabel = closeButton:CreateFontString(nil, "OVERLAY", FONT_BODY)
    closeLabel:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeLabel:SetText("×")
    closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.2, 0.2, 1)
        closeLabel:SetTextColor(1, 1, 1, 1)
    end)
    closeButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    closeButton:SetScript("OnClick", function()
        Valuate:HideUI()
    end)
    
    -- Content area (below title bar)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", PADDING, -PADDING)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
    frame.contentFrame = contentFrame
    
    -- Store reference
    ns.ValuateUIFrame = frame
    frame:Hide()
    
    return frame
end

-- ========================================
-- Tab System
-- ========================================

local function CreateTabSystem(mainFrame, contentFrame)
    local activeTab = "scales"
    local tabs = {}
    local tabPanels = {}
    
    local function SelectTab(tabName)
        activeTab = tabName
        
        -- Hide all panels
        for _, panel in pairs(tabPanels) do
            panel:Hide()
        end
        
        -- Show selected panel with a quick crossfade, so switching tabs reads as a
        -- transition rather than an instant swap. The Best Equipment tab is exempt: it
        -- does its own staggered per-column reveal (below), which would otherwise
        -- compound with a whole-panel fade (child alpha x parent alpha).
        if tabPanels[tabName] then
            local panel = tabPanels[tabName]
            panel:Show()
            if tabName == "bestEquipment" then
                panel:SetAlpha(1)
            else
                panel:SetAlpha(0)
                Anim.fade(panel, 1, 0.18, "outQuad")
            end
        end
        
        -- Adjust window height based on tab
        if ns.ValuateUIFrame then
            if tabName == "scales" then
                -- Scales tab: Restore dynamic height if a scale is already selected
                local scales = Valuate:GetScales()
                if ns.EditingScaleName and scales[ns.EditingScaleName] then
                    -- Trigger resize by refreshing the scale editor
                    ValuateUI_UpdateScaleEditor(ns.EditingScaleName, scales[ns.EditingScaleName])
                end
            elseif tabName == "bestEquipment" then
                -- Best Equipment tab sizes itself to fit rows + weapon-sets + summary
                -- (the panel is already shown above, so the refresh will resize).
                ns.ValuateUIFrame:SetHeight(MIN_WINDOW_HEIGHT)
                if Valuate.RefreshBestEquipmentDisplay then
                    Valuate:RefreshBestEquipmentDisplay()
                end
                -- Staggered per-column reveal (only on tab-open, so it's a flourish).
                if Valuate.RevealBestEquipmentColumns then
                    Valuate:RevealBestEquipmentColumns()
                end
            else
                -- Instructions, About, Changelog, and Settings tabs: Use minimum height with proper spacing
                ns.ValuateUIFrame:SetHeight(MIN_WINDOW_HEIGHT)
            end
        end
        
        -- Update tab buttons - selected vs unselected appearance
        for name, btn in pairs(tabs) do
            if name == tabName then
                -- Selected tab: brighter fill, azure accent bar, bright label
                btn:SetBackdropColor(unpack(COLORS.buttonHover))
                btn:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
                btn.label:SetTextColor(unpack(COLORS.textTitle))
                if btn.accent then
                    -- Sweep the accent in rather than popping it, so switching tabs
                    -- reads as a transition instead of a redraw. Textures have no
                    -- OnUpdate, so the owning button drives the tween.
                    local accent = btn.accent
                    accent:SetAlpha(0)
                    accent:Show()
                    ValuateTween(btn, 0.22, function(t)
                        accent:SetAlpha(EaseOutQuad(t))
                    end)
                end
            else
                -- Unselected tab: darker, recessed look
                btn:SetBackdropColor(unpack(COLORS.buttonPressed))
                btn:SetBackdropBorderColor(unpack(COLORS.borderDark))
                btn.label:SetTextColor(unpack(COLORS.textDim))
                if btn.accent then btn.accent:Hide() end
            end
        end
    end
    
    -- Create tab buttons dynamically - sitting on bottom border of window
    local function CreateTab(name, text, panel, anchorSide)
        local btn = CreateFrame("Button", nil, mainFrame)  -- Parent to mainFrame for proper anchoring
        btn:SetHeight(22)
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        btn:SetScript("OnClick", function()
            SelectTab(name)
        end)
        
        local label = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        label:SetText(text)
        label:SetTextColor(unpack(COLORS.textBody))
        btn.label = label

        -- Azure accent bar along the top edge, shown only for the active tab.
        local accent = btn:CreateTexture(nil, "OVERLAY")
        accent:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -1)
        accent:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -1)
        accent:SetHeight(2)
        accent:SetColorTexture(unpack(COLORS.textAccent))
        accent:Hide()
        btn.accent = accent
        
        -- Size button based on text
        btn:SetWidth(label:GetStringWidth() + 40)
        
        -- Position tab on specified side of window bottom
        if anchorSide == "right" then
            btn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -20, -21)
        else
            btn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, -21)
        end
        
        tabs[name] = btn
        tabPanels[name] = panel
        
        return btn
    end
    
    -- Create panel containers - fill the entire content area
    local scalesPanel = CreateFrame("Frame", nil, contentFrame)
    scalesPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    scalesPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    
    -- Create container hierarchy for scales panel (consistent with best equipment UI)
    -- Main content container (fills scalesPanel)
    local scalesContentContainer = CreateFrame("Frame", nil, scalesPanel)
    scalesContentContainer:SetPoint("TOPLEFT", scalesPanel, "TOPLEFT", 0, 0)
    scalesContentContainer:SetPoint("BOTTOMRIGHT", scalesPanel, "BOTTOMRIGHT", 0, 0)
    
    -- Left side: Scale list container
    local scaleListContainer = CreateFrame("Frame", nil, scalesContentContainer)
    scaleListContainer:SetPoint("TOPLEFT", scalesContentContainer, "TOPLEFT", 0, 0)
    scaleListContainer:SetPoint("BOTTOMLEFT", scalesContentContainer, "BOTTOMLEFT", 0, 0)
    scaleListContainer:SetWidth(200)
    
    -- Right side: Scale editor container
    local scaleEditorContainer = CreateFrame("Frame", nil, scalesContentContainer)
    scaleEditorContainer:SetPoint("TOPLEFT", scaleListContainer, "TOPRIGHT", PADDING, 0)
    scaleEditorContainer:SetPoint("BOTTOMRIGHT", scalesContentContainer, "BOTTOMRIGHT", 0, 0)
    
    -- Store container references for external access
    scalesPanel.contentContainer = scalesContentContainer
    scalesPanel.scaleListContainer = scaleListContainer
    scalesPanel.scaleEditorContainer = scaleEditorContainer
    
    local instructionsPanel = CreateFrame("Frame", nil, contentFrame)
    instructionsPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    instructionsPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    instructionsPanel:Hide()
    
    local settingsPanel = CreateFrame("Frame", nil, contentFrame)
    settingsPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    settingsPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    settingsPanel:Hide()
    
    local aboutPanel = CreateFrame("Frame", nil, contentFrame)
    aboutPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    aboutPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    aboutPanel:Hide()
    
    local changelogPanel = CreateFrame("Frame", nil, contentFrame)
    changelogPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    changelogPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    changelogPanel:Hide()
    
    local bestEquipmentPanel = CreateFrame("Frame", nil, contentFrame)
    bestEquipmentPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    bestEquipmentPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    bestEquipmentPanel:Hide()
    
    -- Create tabs (Scales on left, Instructions/About/Changelog/Settings on right)
    CreateTab("scales", "Scales", scalesPanel, "left")
    
    -- Create Settings tab first (anchored to right)
    local settingsTab = CreateTab("settings", "Settings", settingsPanel, "right")
    
    -- Create Changelog tab to the left of Settings
    local changelogBtn = CreateFrame("Button", nil, mainFrame)
    changelogBtn:SetHeight(22)
    changelogBtn:SetBackdrop(BACKDROP_BUTTON)
    changelogBtn:SetBackdropColor(unpack(COLORS.buttonBg))
    changelogBtn:SetBackdropBorderColor(unpack(COLORS.border))
    changelogBtn:SetScript("OnClick", function()
        SelectTab("changelog")
    end)
    
    local changelogLabel = changelogBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    changelogLabel:SetPoint("CENTER", changelogBtn, "CENTER", 0, 0)
    changelogLabel:SetText("Changelog")
    changelogLabel:SetTextColor(unpack(COLORS.textBody))
    changelogBtn.label = changelogLabel
    changelogBtn:SetWidth(changelogLabel:GetStringWidth() + 40)
    changelogBtn:SetPoint("RIGHT", settingsTab, "LEFT", -4, 0)
    
    tabs["changelog"] = changelogBtn
    tabPanels["changelog"] = changelogPanel
    
    -- Create About tab to the left of Changelog
    local aboutBtn = CreateFrame("Button", nil, mainFrame)
    aboutBtn:SetHeight(22)
    aboutBtn:SetBackdrop(BACKDROP_BUTTON)
    aboutBtn:SetBackdropColor(unpack(COLORS.buttonBg))
    aboutBtn:SetBackdropBorderColor(unpack(COLORS.border))
    aboutBtn:SetScript("OnClick", function()
        SelectTab("about")
    end)
    
    local aboutLabel = aboutBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    aboutLabel:SetPoint("CENTER", aboutBtn, "CENTER", 0, 0)
    aboutLabel:SetText("About")
    aboutLabel:SetTextColor(unpack(COLORS.textBody))
    aboutBtn.label = aboutLabel
    aboutBtn:SetWidth(aboutLabel:GetStringWidth() + 40)
    aboutBtn:SetPoint("RIGHT", changelogBtn, "LEFT", -4, 0)
    
    tabs["about"] = aboutBtn
    tabPanels["about"] = aboutPanel
    
    -- Create Instructions tab to the left of About
    local instructionsBtn = CreateFrame("Button", nil, mainFrame)
    instructionsBtn:SetHeight(22)
    instructionsBtn:SetBackdrop(BACKDROP_BUTTON)
    instructionsBtn:SetBackdropColor(unpack(COLORS.buttonBg))
    instructionsBtn:SetBackdropBorderColor(unpack(COLORS.border))
    instructionsBtn:SetScript("OnClick", function()
        SelectTab("instructions")
    end)
    
    local instructionsLabel = instructionsBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    instructionsLabel:SetPoint("CENTER", instructionsBtn, "CENTER", 0, 0)
    instructionsLabel:SetText("Instructions")
    instructionsLabel:SetTextColor(unpack(COLORS.textBody))
    instructionsBtn.label = instructionsLabel
    instructionsBtn:SetWidth(instructionsLabel:GetStringWidth() + 40)
    instructionsBtn:SetPoint("RIGHT", aboutBtn, "LEFT", -4, 0)
    
    tabs["instructions"] = instructionsBtn
    tabPanels["instructions"] = instructionsPanel
    
    -- Create Best Equipment tab to the left of Instructions
    local bestEquipmentBtn = CreateFrame("Button", nil, mainFrame)
    bestEquipmentBtn:SetHeight(22)
    bestEquipmentBtn:SetBackdrop(BACKDROP_BUTTON)
    bestEquipmentBtn:SetBackdropColor(unpack(COLORS.buttonBg))
    bestEquipmentBtn:SetBackdropBorderColor(unpack(COLORS.border))
    bestEquipmentBtn:SetScript("OnClick", function()
        SelectTab("bestEquipment")
    end)
    
    local bestEquipmentLabel = bestEquipmentBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    bestEquipmentLabel:SetPoint("CENTER", bestEquipmentBtn, "CENTER", 0, 0)
    bestEquipmentLabel:SetText("Best Equipment")
    bestEquipmentLabel:SetTextColor(unpack(COLORS.textBody))
    bestEquipmentBtn.label = bestEquipmentLabel
    bestEquipmentBtn:SetWidth(bestEquipmentLabel:GetStringWidth() + 40)
    bestEquipmentBtn:SetPoint("RIGHT", instructionsBtn, "LEFT", -4, 0)
    
    tabs["bestEquipment"] = bestEquipmentBtn
    tabPanels["bestEquipment"] = bestEquipmentPanel
    
    -- Select default tab
    SelectTab("scales")
    
    return {
        frame = tabFrame,
        scalesPanel = scalesPanel,
        instructionsPanel = instructionsPanel,
        aboutPanel = aboutPanel,
        changelogPanel = changelogPanel,
        settingsPanel = settingsPanel,
        bestEquipmentPanel = bestEquipmentPanel,
        selectTab = SelectTab
    }
end

-- ========================================
-- Scale Editor (Right Panel)
-- ========================================

local StatWeightRows = {}

-- Helper to create a stat row
local function CreateStatRow(parent, statName, scale, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(COLUMN_WIDTH)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    
    -- Stat label (adjusted width for 5-column layout)
    local label = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(82)  -- Increased for longer stat names like "Shadow Resist:"
    label:SetJustifyH("RIGHT")
    label:SetText((ValuateStatNames[statName] or statName) .. ":")
    
    -- Value input (compact, with validation)
    local editBox = CreateFrame("EditBox", nil, row)
    editBox:SetHeight(14)
    editBox:SetWidth(48)  -- Slightly reduced to accommodate wider label
    editBox:SetPoint("LEFT", label, "RIGHT", 2, 0)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")  -- Using smaller font for compact display
    editBox:SetJustifyH("CENTER")
    editBox:SetBackdrop(BACKDROP_INPUT)
    editBox:SetBackdropColor(unpack(COLORS.inputBg))
    editBox:SetBackdropBorderColor(unpack(COLORS.border))
    editBox:SetTextInsets(2, 2, 0, 0)
    editBox.statName = statName
    
    -- Apply input validation (max 5 digits, one decimal, minus at start only)
    ApplyStatValueValidation(editBox)
    
    -- Focus handling
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText()) or 0
        if ns.EditingScaleName and Valuate:GetScales()[ns.EditingScaleName] then
            local scale = Valuate:GetScales()[ns.EditingScaleName]
            if not scale.Values then scale.Values = {} end
            if value ~= 0 then
                scale.Values[self.statName] = value
            else
                scale.Values[self.statName] = nil
            end
            
            -- Reset all tooltips to reflect the change immediately
            if Valuate.ResetTooltips then
                Valuate:ResetTooltips()
            end
        end
        self:ClearFocus()
    end)
    
    -- Unusable checkbox (ban stat) - smaller for compact layout
    local unusableCheckbox = CreateFrame("CheckButton", nil, row)
    unusableCheckbox:SetSize(12, 12)
    unusableCheckbox:SetPoint("LEFT", editBox, "RIGHT", 2, 0)
    unusableCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    unusableCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    unusableCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    unusableCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    unusableCheckbox.statName = statName
    
    -- Helper function to update banned visual state
    local function UpdateBannedState(isBanned)
        if isBanned then
            label:SetTextColor(unpack(COLORS.textDim))
            editBox:SetText("")
            editBox:EnableMouse(false)
            editBox:EnableKeyboard(false)
            editBox:SetBackdropColor(unpack(COLORS.disabled))
            editBox:SetBackdropBorderColor(unpack(COLORS.borderDark))
        else
            label:SetTextColor(unpack(COLORS.textBody))
            editBox:EnableMouse(true)
            editBox:EnableKeyboard(true)
            editBox:SetBackdropColor(unpack(COLORS.inputBg))
            editBox:SetBackdropBorderColor(unpack(COLORS.border))
        end
    end
    
    -- Check if this stat is marked as unusable
    local isUnusable = (scale and scale.Unusable and scale.Unusable[statName])
    unusableCheckbox:SetChecked(isUnusable == true)
    
    -- Set initial visual state
    if isUnusable then
        UpdateBannedState(true)
    else
        local value = (scale and scale.Values and scale.Values[statName])
        if value and value ~= 0 then
            editBox:SetText(tostring(value))
        else
            editBox:SetText("")
        end
    end
    
    -- OnClick handler for ban checkbox
    unusableCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        if ns.EditingScaleName and Valuate:GetScales()[ns.EditingScaleName] then
            local currentScale = Valuate:GetScales()[ns.EditingScaleName]
            if not currentScale.Unusable then
                currentScale.Unusable = {}
            end
            
            if checked then
                currentScale.Unusable[statName] = true
                if currentScale.Values then
                    currentScale.Values[statName] = nil
                end
            else
                currentScale.Unusable[statName] = nil
            end
            
            -- Reset all tooltips to reflect the change immediately
            if Valuate.ResetTooltips then
                Valuate:ResetTooltips()
            end
        end
        
        UpdateBannedState(checked)
    end)
    
    -- Tooltip for unusable checkbox
    unusableCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Ban Stat", 1, 1, 1)
        GameTooltip:AddLine("Items with this stat won't show a score for this scale.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    unusableCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    row.label = label
    row.editBox = editBox
    row.unusableCheckbox = unusableCheckbox
    row.updateBannedState = UpdateBannedState
    
    return row
end

local function UpdateStatWeightsList(scaleName, scale)
    if not ns.ScaleEditorFrame then return end
    
    -- Clear existing rows
    for _, row in pairs(StatWeightRows) do
        if row.Hide then row:Hide() end
        if row.SetParent then row:SetParent(nil) end
    end
    StatWeightRows = {}
    
    -- Use categories from StatDefinitions.lua
    if not ValuateStatCategories then
        print("|cFFFF0000Valuate|r: Stat categories not defined!")
        return
    end
    
    -- ========================================
    -- Item Stats Container (top section with 5 columns)
    -- ========================================
    local itemStatsContainer = CreateFrame("Frame", nil, ns.ScaleEditorFrame)
    itemStatsContainer:SetPoint("TOPLEFT", ns.ScaleEditorFrame, "TOPLEFT", 0, 0)
    itemStatsContainer:SetWidth(NUM_COLUMNS * COLUMN_WIDTH + (NUM_COLUMNS - 1) * COLUMN_GAP)
    tinsert(StatWeightRows, itemStatsContainer)
    
    -- Create column frames within Item Stats container
    local columnFrames = {}
    local columnHeights = {}
    for i = 1, NUM_COLUMNS do
        columnHeights[i] = 0
    end
    
    for i = 1, NUM_COLUMNS do
        local colFrame = CreateFrame("Frame", nil, itemStatsContainer)
        colFrame:SetWidth(COLUMN_WIDTH)
        colFrame:SetPoint("TOPLEFT", itemStatsContainer, "TOPLEFT", (i - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0)
        columnFrames[i] = colFrame
        tinsert(StatWeightRows, colFrame)
    end
    
    -- Populate each column with its categories
    for _, category in ipairs(ValuateStatCategories) do
        local col = category.column
        if col and col >= 1 and col <= NUM_COLUMNS and columnFrames[col] then
            local colFrame = columnFrames[col]
            local yOffset = -columnHeights[col]
            
            -- Create category header
            local headerFrame = CreateFrame("Frame", nil, colFrame)
            headerFrame:SetHeight(HEADER_HEIGHT)
            headerFrame:SetWidth(COLUMN_WIDTH)
            
            if columnHeights[col] > 0 then
                yOffset = yOffset - HEADER_SPACING
            end
            headerFrame:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, yOffset)
            
            local headerLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H3)
            headerLabel:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
            headerLabel:SetText(category.header)
            headerLabel:SetTextColor(unpack(COLORS.textAccent))
            
            tinsert(StatWeightRows, headerFrame)
            
            if columnHeights[col] > 0 then
                columnHeights[col] = columnHeights[col] + HEADER_SPACING
            end
            columnHeights[col] = columnHeights[col] + HEADER_HEIGHT
            
            -- Create stat rows for this category
            for _, statName in ipairs(category.stats) do
                if ValuateStatNames[statName] then
                    local rowYOffset = -columnHeights[col] - ROW_SPACING
                    local row = CreateStatRow(colFrame, statName, scale, rowYOffset)
                    
                    StatWeightRows[statName] = row
                    tinsert(StatWeightRows, row)
                    columnHeights[col] = columnHeights[col] + ROW_HEIGHT + ROW_SPACING
                end
            end
        end
    end
    
    -- Find tallest column for Item Stats section
    local itemStatsMaxHeight = 0
    for i = 1, NUM_COLUMNS do
        if columnHeights[i] > itemStatsMaxHeight then
            itemStatsMaxHeight = columnHeights[i]
        end
    end
    
    -- Set column frame heights for Item Stats
    for i = 1, NUM_COLUMNS do
        columnFrames[i]:SetHeight(itemStatsMaxHeight)
    end
    
    -- Set Item Stats container height
    itemStatsContainer:SetHeight(itemStatsMaxHeight)
    
    -- ========================================
    -- Equipment Types Container (below Item Stats with 5 columns)
    -- ========================================
    local equipmentStartY = itemStatsMaxHeight + ELEMENT_SPACING * 2
    
    if ValuateEquipmentCategories then
        -- Equipment Types container
        local equipmentTypesContainer = CreateFrame("Frame", nil, ns.ScaleEditorFrame)
        equipmentTypesContainer:SetPoint("TOPLEFT", itemStatsContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING * 2)
        equipmentTypesContainer:SetWidth(NUM_COLUMNS * COLUMN_WIDTH + (NUM_COLUMNS - 1) * COLUMN_GAP)
        tinsert(StatWeightRows, equipmentTypesContainer)
        
        -- Equipment section header
        local equipHeader = CreateFrame("Frame", nil, equipmentTypesContainer)
        equipHeader:SetHeight(HEADER_HEIGHT + 4)
        equipHeader:SetWidth(NUM_COLUMNS * COLUMN_WIDTH + (NUM_COLUMNS - 1) * COLUMN_GAP)
        equipHeader:SetPoint("TOPLEFT", equipmentTypesContainer, "TOPLEFT", 0, 0)
        
        -- Separator line
        local separator = equipHeader:CreateTexture(nil, "BACKGROUND")
        separator:SetHeight(1)
        separator:SetPoint("TOPLEFT", equipHeader, "TOPLEFT", 0, 0)
        separator:SetPoint("TOPRIGHT", equipHeader, "TOPRIGHT", 0, 0)
        separator:SetColorTexture(unpack(COLORS.border))
        
        local equipLabel = equipHeader:CreateFontString(nil, "OVERLAY", FONT_H2)
        equipLabel:SetPoint("LEFT", equipHeader, "LEFT", 0, -6)
        equipLabel:SetText("Equipment Types")
        equipLabel:SetTextColor(unpack(COLORS.textHeader))
        
        tinsert(StatWeightRows, equipHeader)
        
        local equipStartY = HEADER_HEIGHT + ELEMENT_SPACING
        
        -- Create equipment column frames
        local equipColumnFrames = {}
        local equipColumnHeights = {}
        for i = 1, NUM_COLUMNS do
            equipColumnHeights[i] = 0
        end
        
        for i = 1, NUM_COLUMNS do
            local colFrame = CreateFrame("Frame", nil, equipmentTypesContainer)
            colFrame:SetWidth(COLUMN_WIDTH)
            colFrame:SetPoint("TOPLEFT", equipmentTypesContainer, "TOPLEFT", (i - 1) * (COLUMN_WIDTH + COLUMN_GAP), -equipStartY)
            equipColumnFrames[i] = colFrame
            tinsert(StatWeightRows, colFrame)
        end
        
        -- Populate equipment categories (now all in one row with 5 columns)
        for _, category in ipairs(ValuateEquipmentCategories) do
            local col = category.column
            if col and col >= 1 and col <= NUM_COLUMNS and equipColumnFrames[col] then
                local colFrame = equipColumnFrames[col]
                local yOffset = -equipColumnHeights[col]
                
                -- Create category header
                local headerFrame = CreateFrame("Frame", nil, colFrame)
                headerFrame:SetHeight(HEADER_HEIGHT)
                headerFrame:SetWidth(COLUMN_WIDTH)
                headerFrame:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, yOffset)
                
                local headerLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H3)
                headerLabel:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
                headerLabel:SetText(category.header)
                headerLabel:SetTextColor(unpack(COLORS.textAccent))
                
                tinsert(StatWeightRows, headerFrame)
                equipColumnHeights[col] = equipColumnHeights[col] + HEADER_HEIGHT
                
                -- Create stat rows for equipment types
                for _, statName in ipairs(category.stats) do
                    if ValuateStatNames[statName] then
                        local rowYOffset = -equipColumnHeights[col] - ROW_SPACING
                        local row = CreateStatRow(colFrame, statName, scale, rowYOffset)
                        
                        StatWeightRows[statName] = row
                        tinsert(StatWeightRows, row)
                        equipColumnHeights[col] = equipColumnHeights[col] + ROW_HEIGHT + ROW_SPACING
                    end
                end
            end
        end
        
        -- Find tallest equipment column
        local equipMaxHeight = 0
        for i = 1, NUM_COLUMNS do
            if equipColumnHeights[i] > equipMaxHeight then
                equipMaxHeight = equipColumnHeights[i]
            end
        end
        
        -- Set equipment column heights
        for i = 1, NUM_COLUMNS do
            equipColumnFrames[i]:SetHeight(equipMaxHeight)
        end
        
        -- Set Equipment Types container height
        equipmentTypesContainer:SetHeight(equipStartY + equipMaxHeight)

        -- ========================================
        -- Weapon Sets Container (below Equipment Types)
        -- ========================================
        -- Which weapon configurations to track for this scale, and which one is active.
        local wsFullWidth = NUM_COLUMNS * COLUMN_WIDTH + (NUM_COLUMNS - 1) * COLUMN_GAP
        local weaponSetsContainer = CreateFrame("Frame", nil, ns.ScaleEditorFrame)
        weaponSetsContainer:SetPoint("TOPLEFT", equipmentTypesContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING * 2)
        weaponSetsContainer:SetWidth(wsFullWidth)
        tinsert(StatWeightRows, weaponSetsContainer)

        -- Section header with separator
        local wsHeader = CreateFrame("Frame", nil, weaponSetsContainer)
        wsHeader:SetHeight(HEADER_HEIGHT + 4)
        wsHeader:SetWidth(wsFullWidth)
        wsHeader:SetPoint("TOPLEFT", weaponSetsContainer, "TOPLEFT", 0, 0)
        local wsSep = wsHeader:CreateTexture(nil, "BACKGROUND")
        wsSep:SetHeight(1)
        wsSep:SetPoint("TOPLEFT", wsHeader, "TOPLEFT", 0, 0)
        wsSep:SetPoint("TOPRIGHT", wsHeader, "TOPRIGHT", 0, 0)
        wsSep:SetColorTexture(unpack(COLORS.border))
        local wsLabel = wsHeader:CreateFontString(nil, "OVERLAY", FONT_H2)
        wsLabel:SetPoint("LEFT", wsHeader, "LEFT", 0, -6)
        wsLabel:SetText("Weapon Sets")
        wsLabel:SetTextColor(unpack(COLORS.textHeader))
        tinsert(StatWeightRows, wsHeader)

        local wsDesc = weaponSetsContainer:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        wsDesc:SetPoint("TOPLEFT", weaponSetsContainer, "TOPLEFT", 0, -(HEADER_HEIGHT + 4))
        wsDesc:SetPoint("RIGHT", weaponSetsContainer, "RIGHT", 0, 0)
        wsDesc:SetJustifyH("LEFT")
        wsDesc:SetText("Track the best of each enabled weapon configuration, and pick which one is active (drives the main/off-hand best-in-slot).")
        wsDesc:SetTextColor(unpack(COLORS.textDim))

        local wsDefs = Valuate:GetWeaponSetDefinitions()
        local wsCheckY = (HEADER_HEIGHT + 4) + ROW_HEIGHT + ROW_SPACING
        for idx, def in ipairs(wsDefs) do
            local cb = CreateFrame("CheckButton", nil, weaponSetsContainer)
            cb:SetSize(18, 18)
            cb:SetPoint("TOPLEFT", weaponSetsContainer, "TOPLEFT", (idx - 1) * (COLUMN_WIDTH + COLUMN_GAP), -wsCheckY)
            cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
            cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
            cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
            cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
            cb:SetChecked(Valuate:IsWeaponSetEnabled(scale, def.key))
            local cbLabel = cb:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            cbLabel:SetPoint("LEFT", cb, "RIGHT", 3, 0)
            cbLabel:SetText(def.label)
            cbLabel:SetTextColor(unpack(COLORS.textBody))
            cb:SetScript("OnClick", function(self)
                local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
                if not scale.WeaponSets then
                    -- Materialize the implicit "all enabled" default before editing.
                    scale.WeaponSets = {}
                    for _, d in ipairs(wsDefs) do scale.WeaponSets[d.key] = true end
                end
                scale.WeaponSets[def.key] = checked or nil
                Valuate:ScanBestEquipment()
                if Valuate.RefreshBestEquipmentDisplay then Valuate:RefreshBestEquipmentDisplay() end
                if Valuate.ResetTooltips then Valuate:ResetTooltips() end
            end)
            tinsert(StatWeightRows, cb)
        end

        -- Active-set selector: click to cycle Auto -> each enabled config.
        local function activeSetDisplay()
            local key = scale.ActiveWeaponSet
            if not key or key == "auto" then return "Auto (equipped / highest)" end
            for _, d in ipairs(wsDefs) do if d.key == key then return d.label end end
            return "Auto (equipped / highest)"
        end
        local wsActiveY = wsCheckY + ROW_HEIGHT + ROW_SPACING + 6
        local wsActiveLabel = weaponSetsContainer:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        wsActiveLabel:SetPoint("TOPLEFT", weaponSetsContainer, "TOPLEFT", 0, -wsActiveY)
        wsActiveLabel:SetText("Active set:")
        wsActiveLabel:SetTextColor(unpack(COLORS.textBody))
        local wsActiveButton = CreateStyledButton(weaponSetsContainer, activeSetDisplay(), 200, 20)
        wsActiveButton:SetPoint("LEFT", wsActiveLabel, "RIGHT", 8, 0)
        wsActiveButton:SetScript("OnClick", function(self)
            local order = { "auto" }
            for _, d in ipairs(wsDefs) do
                if Valuate:IsWeaponSetEnabled(scale, d.key) then tinsert(order, d.key) end
            end
            local cur = scale.ActiveWeaponSet or "auto"
            local curIdx = 1
            for i, k in ipairs(order) do if k == cur then curIdx = i break end end
            scale.ActiveWeaponSet = order[(curIdx % #order) + 1]
            self.label:SetText(activeSetDisplay())
            Valuate:ScanBestEquipment()
            if Valuate.RefreshBestEquipmentDisplay then Valuate:RefreshBestEquipmentDisplay() end
            if Valuate.ResetTooltips then Valuate:ResetTooltips() end
        end)
        tinsert(StatWeightRows, wsActiveButton)

        local weaponSetsHeight = wsActiveY + ROW_HEIGHT + ELEMENT_SPACING
        weaponSetsContainer:SetHeight(weaponSetsHeight)

        -- Total height is Item Stats + Equipment Types + Weapon Sets, with spacing.
        local totalContentHeight = itemStatsMaxHeight + ELEMENT_SPACING * 2 + equipStartY + equipMaxHeight
                                   + ELEMENT_SPACING * 2 + weaponSetsHeight
        
        -- Update ns.ScaleEditorFrame height
        if ns.ScaleEditorFrame then
            ns.ScaleEditorFrame:SetHeight(math.max(totalContentHeight, 100))
            
            -- Resize main window to fit content
            if ns.ValuateUIFrame then
                -- Calculate needed window height:
                -- Title bar (40) + Tab bar (30) + Scale editor header (40) + Element spacing (8) + Content + Bottom padding (PADDING)
                local neededHeight = 40 + 30 + 40 + ELEMENT_SPACING + totalContentHeight + PADDING
                local windowHeight = math.max(MIN_WINDOW_HEIGHT, math.min(MAX_WINDOW_HEIGHT, neededHeight))
                ns.ValuateUIFrame:SetHeight(windowHeight)
            end
        end
        
        return -- Exit early since we've handled equipment types
    end
    
    -- If no equipment categories, just set ns.ScaleEditorFrame height based on Item Stats
    if ns.ScaleEditorFrame then
        ns.ScaleEditorFrame:SetHeight(math.max(itemStatsMaxHeight, 100))
        
        -- Resize main window to fit content
        if ns.ValuateUIFrame then
            -- Calculate needed window height:
            -- Title bar (40) + Tab bar (30) + Scale editor header (40) + Element spacing (8) + Content + Bottom padding (PADDING)
            local neededHeight = 40 + 30 + 40 + ELEMENT_SPACING + itemStatsMaxHeight + PADDING
            local windowHeight = math.max(MIN_WINDOW_HEIGHT, math.min(MAX_WINDOW_HEIGHT, neededHeight))
            ns.ValuateUIFrame:SetHeight(windowHeight)
        end
    end
end

function ValuateUI_UpdateScaleEditor(scaleName, scale)
    ns.EditingScaleName = scaleName
    
    if not ns.ScaleEditorFrame then return end
    
    -- Show the editor container
    if ns.ScaleEditorFrame.container then
        ns.ScaleEditorFrame.container:Show()
    end
    
    -- Update name field
    if ns.ScaleEditorFrame.nameEditBox then
        ns.ScaleEditorFrame.nameEditBox:SetText(scale.DisplayName or scaleName)
    end
    
    
    -- Update stat weights
    UpdateStatWeightsList(scaleName, scale)
end

-- ========================================
-- Template Scale Creation
-- ========================================

-- Creates a scale from a template
-- template: The template data (from CLASS_SPEC_TEMPLATES)
-- Returns: scaleName if successful, nil if cancelled
function ValuateUI_CreateScaleFromTemplate(template)
    local scaleName = template.name
    
    -- Check if scale already exists
    if Valuate:GetScales()[scaleName] then
        Valuate:ShowConfirmDialog({
            text = "A scale named \"" .. scaleName .. "\" already exists.\n\nOverwrite it?",
            acceptText = "Overwrite",
            cancelText = "Cancel",
            onAccept = function()
                if ns.ValuateUI_OnTemplateOverwrite then
                    ns.ValuateUI_OnTemplateOverwrite(template)
                end
            end,
        })
        return nil
    end
    
    -- Create the scale
    local newScale = {
        DisplayName = scaleName,
        Color = template.color or "FFFFFF",  -- Use spec's color
        Visible = true,
        Icon = template.icon,
        Values = {},
        Unusable = {}
    }
    
    -- Copy stat weights from template
    if template.weights then
        for statName, value in pairs(template.weights) do
            newScale.Values[statName] = value
        end
    end
    
    -- Copy unusable stats from template
    if template.unusable then
        for statName, value in pairs(template.unusable) do
            newScale.Unusable[statName] = value
        end
    end
    
    Valuate:GetScales()[scaleName] = newScale
    
    -- Refresh list and select new scale
    UpdateScaleList()
    if ns.ScaleListButtons[scaleName] then
        ns.ScaleListButtons[scaleName]:GetScript("OnClick")(ns.ScaleListButtons[scaleName])
    end
    
    -- Refresh best equipment display to show new scale
    if Valuate.RefreshBestEquipmentDisplay then
        Valuate:RefreshBestEquipmentDisplay()
    end
    
    return scaleName
end

function ValuateUI_NewScale()
    local baseName = "New Scale"
    local name = baseName
    local counter = 1
    while Valuate:GetScales()[name] do
        name = baseName .. " " .. counter
        counter = counter + 1
    end
    
    local newScale = {
        DisplayName = name,
        Color = "FFFFFF",
        Visible = true,
        Values = {}
    }
    
    Valuate:GetScales()[name] = newScale
    
    -- Refresh list and select new scale
    UpdateScaleList()
    if ns.ScaleListButtons[name] then
        ns.ScaleListButtons[name]:GetScript("OnClick")(ns.ScaleListButtons[name])
    end
    
    -- Refresh best equipment display to show new scale
    if Valuate.RefreshBestEquipmentDisplay then
        Valuate:RefreshBestEquipmentDisplay()
    end
end

-- ========================================
-- Import/Export Dialog
-- ========================================

local ValuateImportExportDialog = nil

-- Creates the import/export dialog (reusable for both import and export)
local function CreateImportExportDialog()
    if ValuateImportExportDialog then
        return ValuateImportExportDialog
    end
    
    -- Main dialog frame
    local dialog = CreateFrame("Frame", "ValuateImportExportDialog", UIParent)
    dialog:SetWidth(600)
    dialog:SetHeight(300)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")  -- Above main UI
    dialog:SetBackdrop(BACKDROP_WINDOW)
    dialog:SetBackdropColor(unpack(COLORS.windowBg))
    dialog:SetBackdropBorderColor(unpack(COLORS.border))
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self)
        ns.IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    dialog:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.IsDraggingFrame = false
    end)
    dialog:Hide()
    
    -- Close on Escape
    table.insert(UISpecialFrames, "ValuateImportExportDialog")
    
    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    title:SetText("Import/Export")
    dialog.title = title
    
    -- Prompt text
    local prompt = dialog:CreateFontString(nil, "OVERLAY", FONT_BODY)
    prompt:SetPoint("TOP", title, "BOTTOM", 0, -10)
    prompt:SetWidth(560)
    prompt:SetJustifyH("LEFT")
    prompt:SetText("Prompt text")
    dialog.prompt = prompt
    
    -- Scroll frame for text box
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOP", prompt, "BOTTOM", 0, -10)
    scrollFrame:SetPoint("LEFT", dialog, "LEFT", 20, 0)
    scrollFrame:SetPoint("RIGHT", dialog, "RIGHT", -40, 0)
    scrollFrame:SetHeight(150)
    
    -- Multi-line EditBox
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)  -- No limit
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(_G[FONT_BODY])
    editBox:SetWidth(540)
    editBox:SetHeight(150)
    editBox:SetScript("OnEscapePressed", function(self)
        dialog:Hide()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        -- Auto-size height based on content
        local text = self:GetText() or ""
        local numLines = 1
        for _ in string.gmatch(text, "\n") do
            numLines = numLines + 1
        end
        local height = math.max(150, numLines * 14)
        self:SetHeight(height)
    end)
    
    scrollFrame:SetScrollChild(editBox)
    dialog.editBox = editBox
    dialog.scrollFrame = scrollFrame
    
    -- OK Button
    local okButton = CreateStyledButton(dialog, "OK", 100, BUTTON_HEIGHT)
    okButton:SetPoint("BOTTOM", dialog, "BOTTOM", -55, 15)
    okButton:SetScript("OnClick", function(self)
        if dialog.okCallback then
            dialog.okCallback(editBox:GetText())
        end
        dialog:Hide()
    end)
    dialog.okButton = okButton
    
    -- Cancel/Close Button
    local cancelButton = CreateStyledButton(dialog, "Cancel", 100, BUTTON_HEIGHT)
    cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", 55, 15)
    cancelButton:SetScript("OnClick", function(self)
        if dialog.cancelCallback then
            dialog.cancelCallback()
        end
        dialog:Hide()
    end)
    dialog.cancelButton = cancelButton
    
    ValuateImportExportDialog = dialog
    return dialog
end

-- Shows the export dialog with a scale tag
function Valuate:ShowExportDialog(scaleName)
    local scaleTag = self:GetScaleTag(scaleName)
    if not scaleTag then
        print("|cFFFF0000Valuate|r: Failed to generate export string for scale.")
        return
    end
    
    local dialog = CreateImportExportDialog()
    local scale = Valuate:GetScales()[scaleName]
    local displayName = scale and scale.DisplayName or scaleName
    
    dialog.title:SetText("Export Scale")
    dialog.prompt:SetText("Press Ctrl+C to copy the scale tag for |cFFFFFFFF" .. displayName .. "|r:")
    dialog.editBox:SetText(scaleTag)
    dialog.editBox:HighlightText()
    dialog.editBox:SetFocus()
    
    -- Only show Close button for export
    dialog.okButton:Hide()
    dialog.cancelButton:SetText("Close")
    dialog.cancelButton:ClearAllPoints()
    dialog.cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 15)
    
    dialog.okCallback = nil
    dialog.cancelCallback = nil
    
    dialog:Show()
end

-- Shows the import dialog for pasting a scale tag
function Valuate:ShowImportDialog()
    local dialog = CreateImportExportDialog()
    
    dialog.title:SetText("Import Scale")
    dialog.prompt:SetText("Press Ctrl+V to paste a scale tag:")
    dialog.editBox:SetText("")
    dialog.editBox:SetFocus()
    
    -- Show both OK and Cancel buttons
    dialog.okButton:Show()
    dialog.cancelButton:SetText("Cancel")
    dialog.cancelButton:ClearAllPoints()
    dialog.cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", 55, 15)
    
    dialog.okCallback = function(text)
        -- First check if scale exists (without overwriting)
        local status, scaleName, errorMessage = self:ImportScale(text, false)
        
        if status == Valuate.ImportResult.ALREADY_EXISTS then
            -- Scale already exists, show confirmation dialog
            Valuate:ShowConfirmDialog({
                text = "A scale named \"" .. scaleName .. "\" already exists.\n\nOverwrite it?",
                acceptText = "Overwrite",
                cancelText = "Cancel",
                onAccept = function()
                    -- User confirmed, now import with overwrite
                    local overwriteStatus, overwriteScaleName = self:ImportScale(text, true)

                    if overwriteStatus == Valuate.ImportResult.SUCCESS then
                        print("|cFF00FF00Valuate|r: Successfully overwrote scale |cFFFFFFFF" .. overwriteScaleName .. "|r")

                        -- Refresh the UI
                        if ns.ValuateUIFrame and ns.ValuateUIFrame:IsShown() then
                            UpdateScaleList()
                            if ns.ScaleListButtons[overwriteScaleName] then
                                ns.ScaleListButtons[overwriteScaleName]:GetScript("OnClick")(ns.ScaleListButtons[overwriteScaleName])
                            end
                        end
                    end
                end,
            })
            return
        end
        
        if status == Valuate.ImportResult.SUCCESS then
            print("|cFF00FF00Valuate|r: Successfully imported scale |cFFFFFFFF" .. scaleName .. "|r")
            
            -- Refresh the UI if it's open
            if ns.ValuateUIFrame and ns.ValuateUIFrame:IsShown() then
                UpdateScaleList()
                -- Select the imported scale
                if ns.ScaleListButtons[scaleName] then
                    ns.ScaleListButtons[scaleName]:GetScript("OnClick")(ns.ScaleListButtons[scaleName])
                end
            end
        elseif status == Valuate.ImportResult.VERSION_ERROR then
            print("|cFFFF0000Valuate|r: Import failed: Scale tag is from a newer version of Valuate. Please update the addon.")
        else
            print("|cFFFF0000Valuate|r: Import failed: Invalid scale tag format. Please check that you copied the entire tag.")
        end
    end
    
    dialog.cancelCallback = nil
    
    dialog:Show()
end

local function CreateScaleEditor(parent)
    -- Parent is now the scaleEditorContainer with proper size/positioning already set
    -- Header area (non-scrolling) for Scale Name - reduced height
    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    headerFrame:SetHeight(40)
    
    -- Scale Name (single line header)
    local nameLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
    nameLabel:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
    nameLabel:SetText("Scale Name:")
    
    local nameEditBox = CreateFrame("EditBox", nil, headerFrame)
    nameEditBox:SetHeight(22)
    nameEditBox:SetWidth(200)
    nameEditBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetFontObject(_G[FONT_BODY])
    nameEditBox:SetBackdrop(BACKDROP_INPUT)
    nameEditBox:SetBackdropColor(unpack(COLORS.inputBg))
    nameEditBox:SetBackdropBorderColor(unpack(COLORS.border))
    nameEditBox:SetTextInsets(6, 6, 0, 0)
    nameEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameEditBox:SetScript("OnEnterPressed", function(self)
        if not ns.EditingScaleName or not Valuate:GetScales()[ns.EditingScaleName] then
            self:ClearFocus()
            return
        end
        
        local newName = self:GetText()
        if newName and newName ~= "" then
            local scale = Valuate:GetScales()[ns.EditingScaleName]
            scale.DisplayName = newName
            
            -- If the name changed, update the scale key
            if newName ~= ns.EditingScaleName then
                Valuate:GetScales()[newName] = scale
                Valuate:GetScales()[ns.EditingScaleName] = nil
                ns.EditingScaleName = newName
                ns.CurrentSelectedScale = newName
                UpdateScaleList()
            end
        end
        self:ClearFocus()
    end)
    
    -- Import button
    local importButton = CreateStyledButton(headerFrame, "Import", 80, 22)
    importButton:SetPoint("LEFT", nameEditBox, "RIGHT", 10, 0)
    importButton:SetScript("OnClick", function(self)
        Valuate:ShowImportDialog()
    end)
    importButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_TOP") then
        GameTooltip:SetText("Import Scale", 1, 1, 1)
        GameTooltip:AddLine("Import a scale from a scale tag.", nil, nil, nil, true)
        GameTooltip:Show()
        end
    end)
    importButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Export button
    local exportButton = CreateStyledButton(headerFrame, "Export", 80, 22)
    exportButton:SetPoint("LEFT", importButton, "RIGHT", ELEMENT_SPACING, 0)
    exportButton:SetScript("OnClick", function(self)
        if not ns.EditingScaleName or not Valuate:GetScales()[ns.EditingScaleName] then
            return
        end
        Valuate:ShowExportDialog(ns.EditingScaleName)
    end)
    exportButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_TOP") then
        GameTooltip:SetText("Export Scale", 1, 1, 1)
        GameTooltip:AddLine("Export the current scale as a scale tag to share with others.", nil, nil, nil, true)
        GameTooltip:Show()
        end
    end)
    exportButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Reset button to clear all values (moved to the right)
    local resetButton = CreateStyledButton(headerFrame, "Reset Values", 90, 22)
    resetButton:SetPoint("LEFT", exportButton, "RIGHT", ELEMENT_SPACING, 0)
    resetButton:SetScript("OnClick", function(self)
        if not ns.EditingScaleName or not Valuate:GetScales()[ns.EditingScaleName] then
            return
        end
        
        local scaleName = ns.EditingScaleName
        local scale = Valuate:GetScales()[scaleName]
        
        Valuate:ShowConfirmDialog({
            text = "Are you sure you want to reset all values in the scale \"" .. (scale.DisplayName or scaleName) .. "\" to blank?",
            acceptText = "Reset",
            cancelText = "Cancel",
            onAccept = function()
                -- Clear all values and unusable flags
                scale.Values = {}
                scale.Unusable = {}

                -- Refresh the editor display
                ValuateUI_UpdateScaleEditor(scaleName, scale)

                -- Reset all tooltips to reflect the change immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end,
        })
    end)
    
    -- Content frame for stat weights (below header) - no scrollbar needed as everything fits
    local contentFrame = CreateFrame("Frame", nil, parent)
    contentFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    contentFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, PADDING)
    contentFrame:SetBackdrop(BACKDROP_PANEL)
    contentFrame:SetBackdropColor(unpack(COLORS.panelBg))
    contentFrame:SetBackdropBorderColor(unpack(COLORS.borderDark))
    
    -- Store references
    ns.ScaleEditorFrame = contentFrame
    ns.ScaleEditorFrame.container = parent
    ns.ScaleEditorFrame.nameEditBox = nameEditBox
    
    
    parent:Hide()
    return parent
end


-- ========================================
-- Character Window Scale Display
-- ========================================

local CharacterWindowFrame = nil
local CharacterWindowIconTexture = nil
local CharacterWindowNameText = nil
local CharacterWindowScoreText = nil
local CharacterWindowInitialized = false
local CharacterWindowUpdating = false

-- Equipment slot IDs (standard WoW order, skipping shirt/tabard)
-- 1=Head, 2=Neck, 3=Shoulder, 4=Shirt, 5=Chest, 6=Waist, 7=Legs, 8=Feet
-- 9=Wrist, 10=Hands, 11=Ring1, 12=Ring2, 13=Trinket1, 14=Trinket2
-- 15=Back, 16=MainHand, 17=OffHand, 18=Ranged, 19=Tabard
local EquipmentSlots = {
    { slotId = 1, name = "Head" },
    { slotId = 2, name = "Neck" },
    { slotId = 3, name = "Shoulder" },
    { slotId = 15, name = "Back" },
    { slotId = 5, name = "Chest" },
    { slotId = 9, name = "Wrist" },
    { slotId = 10, name = "Hands" },
    { slotId = 6, name = "Waist" },
    { slotId = 7, name = "Legs" },
    { slotId = 8, name = "Feet" },
    { slotId = 11, name = "Ring 1" },
    { slotId = 12, name = "Ring 2" },
    { slotId = 13, name = "Trinket 1" },
    { slotId = 14, name = "Trinket 2" },
    { slotId = 16, name = "Main Hand" },
    { slotId = 17, name = "Off Hand" },
    { slotId = 18, name = "Ranged" },
}

-- Helper function to get the correct character frame (Ascension vs standard WoW)
local function GetCharacterFrame()
    -- Ascension uses AscensionCharacterFrame
    if AscensionCharacterFrame then
        return AscensionCharacterFrame
    end
    -- Fallback to standard WoW PaperDollFrame
    return PaperDollFrame
end

-- Empty slot icon
local EMPTY_SLOT_ICON = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

-- Get individual item scores for breakdown (includes empty slots)
local function GetEquippedItemsBreakdown(scale)
    local breakdown = {}
    local totalScore = 0
    local slotCount = #EquipmentSlots
    
    for _, slotInfo in ipairs(EquipmentSlots) do
        local slotId = slotInfo.slotId
        local itemLink = GetInventoryItemLink("player", slotId)
        
        if itemLink then
            local itemName, _, itemRarity = GetItemInfo(itemLink)
            local itemTexture = GetInventoryItemTexture("player", slotId)
            
            -- Get item score using SCALED stats (same as tooltips)
            -- This ensures character window breakdown matches tooltip values
            local score = Valuate:GetEquippedItemScoreBySlotId(slotId, scale)
            
            -- Get item quality color
            local r, g, b = 1, 1, 1
            if itemRarity then
                r, g, b = GetItemQualityColor(itemRarity)
            end
            
            totalScore = totalScore + score
            
            tinsert(breakdown, {
                slotName = slotInfo.name,
                itemName = itemName or "Unknown",
                itemTexture = itemTexture,
                score = score,
                isEmpty = false,
                r = r, g = g, b = b
            })
        else
            -- Empty slot - show slot name
            tinsert(breakdown, {
                slotName = slotInfo.name,
                itemName = slotInfo.name .. " (Empty)",
                itemTexture = EMPTY_SLOT_ICON,
                score = 0,
                isEmpty = true,
                r = 0.5, g = 0.5, b = 0.5  -- Gray for empty
            })
        end
    end
    
    return breakdown, totalScore, slotCount
end

-- Show breakdown tooltip
local function ShowBreakdownTooltip(self)
    if ns.IsDraggingFrame then return end  -- Skip if dragging
    
    local selectedScaleName = Valuate:GetOptions().characterWindowScale
    local scales = Valuate:GetScales()
    if not selectedScaleName or not scales or not scales[selectedScaleName] then
        return
    end
    
    local scale = Valuate:GetScales()[selectedScaleName]
    if not scale then return end
    
    local color = scale.Color or "FFFFFF"
    local r, g, b = HexToRGB(color)
    local displayName = scale.DisplayName or selectedScaleName
    
    -- Get breakdown
    local breakdown, totalScore, slotCount = GetEquippedItemsBreakdown(scale)
    
    -- Create custom tooltip
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 0)
    GameTooltip:ClearLines()
    
    -- Icon sizes (30% bigger: 12 -> 16, 14 -> 18)
    local itemIconSize = 16
    local headerIconSize = 18
    
    -- Header with scale name and icon
    if scale.Icon and scale.Icon ~= "" then
        GameTooltip:AddLine("|T" .. scale.Icon .. ":" .. headerIconSize .. ":" .. headerIconSize .. ":0:0|t " .. displayName .. " Breakdown", r, g, b)
    else
        GameTooltip:AddLine(displayName .. " Breakdown", r, g, b)
    end
    GameTooltip:AddLine(" ")
    
    -- Format settings
    local decimals = Valuate:GetOptions().decimalPlaces or 1
    local formatStr = "%." .. decimals .. "f"
    
    -- Add each item with larger icons
    for _, item in ipairs(breakdown) do
        local scoreText = string.format(formatStr, item.score)
        -- Icon + item name on left, score on right (larger icon)
        local iconPath = item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
        local leftText = "|T" .. iconPath .. ":" .. itemIconSize .. ":" .. itemIconSize .. ":0:0|t "
        local itemColor = string.format("|cFF%02X%02X%02X", item.r * 255, item.g * 255, item.b * 255)
        leftText = leftText .. itemColor .. item.itemName .. "|r"
        
        -- Dim the score for empty slots or zero values
        local scoreColor = color
        if item.isEmpty then
            scoreColor = "666666"  -- Gray for empty
        elseif item.score == 0 then
            scoreColor = "999999"  -- Slightly less gray for zero
        end
        
        GameTooltip:AddDoubleLine(leftText, "|cFF" .. scoreColor .. scoreText .. "|r", 1, 1, 1, r, g, b)
    end
    
    -- Separator and totals (always show both)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("───────────────────────────────", 0.3, 0.3, 0.3)
    
    local totalText = string.format(formatStr, totalScore)
    local avgScore = slotCount > 0 and (totalScore / slotCount) or 0
    local avgText = string.format(formatStr, avgScore)
    
    GameTooltip:AddDoubleLine("Total", "|cFF" .. color .. totalText .. "|r", 1, 1, 1, r, g, b)
    GameTooltip:AddDoubleLine("Average", "|cFF" .. color .. avgText .. "|r", 1, 1, 1, r, g, b)
    
    GameTooltip:Show()
end

-- Hide breakdown tooltip  
local function HideBreakdownTooltip()
    GameTooltip:Hide()
end

-- Update the character window display
local function UpdateCharacterWindowDisplay()
    if CharacterWindowUpdating then
        return
    end

    if not CharacterWindowFrame then
        return
    end

    -- Skip while the character sheet is closed: this recomputes the total
    -- equipped score (parses ~17 item tooltips) and is triggered by ResetTooltips
    -- on nearly every option change. The character frame's OnShow hook refreshes
    -- the display when the sheet is reopened, so nothing goes stale.
    if not CharacterWindowFrame:IsVisible() then
        return
    end

    CharacterWindowUpdating = true
    
    -- Standardized padding values (must match frame creation)
    local PADDING_EDGE = 6
    local PADDING_ICON_TO_NAME = 4
    local PADDING_NAME_TO_VALUE = 8
    local ICON_SIZE = 14
    local MIN_WIDTH = 120
    
    -- Get selected scale from options
    local selectedScaleName = Valuate:GetOptions().characterWindowScale
    local scales = Valuate:GetScales()
    if not selectedScaleName or not scales or not scales[selectedScaleName] then
        -- Try to use first active scale
        local activeScales = Valuate:GetActiveScales()
        if #activeScales > 0 then
            selectedScaleName = activeScales[1]
            Valuate:GetOptions().characterWindowScale = selectedScaleName
        else
            -- No scales available - hide display
            if CharacterWindowIconTexture then CharacterWindowIconTexture:Hide() end
            if CharacterWindowNameText then CharacterWindowNameText:SetText("") end
            if CharacterWindowScoreText then CharacterWindowScoreText:SetText("--") end
            CharacterWindowUpdating = false
            return
        end
    end
    
    local scale = Valuate:GetScales()[selectedScaleName]
    if not scale then
        if CharacterWindowIconTexture then CharacterWindowIconTexture:Hide() end
        if CharacterWindowNameText then CharacterWindowNameText:SetText("") end
        if CharacterWindowScoreText then CharacterWindowScoreText:SetText("--") end
        CharacterWindowUpdating = false
        return
    end
    
    local color = scale.Color or "FFFFFF"
    local hasIcon = false
    
    -- Update icon
    if CharacterWindowIconTexture then
        local icon = scale.Icon
        if icon and icon ~= "" then
            CharacterWindowIconTexture:SetTexture(icon)
            CharacterWindowIconTexture:Show()
            hasIcon = true
            -- Reposition name text next to icon with standardized padding
            if CharacterWindowNameText then
                CharacterWindowNameText:SetPoint("LEFT", CharacterWindowIconTexture:GetParent(), "RIGHT", PADDING_ICON_TO_NAME, 0)
            end
        else
            CharacterWindowIconTexture:Hide()
            hasIcon = false
            -- Reposition name text to start of container with standardized padding
            if CharacterWindowNameText then
                CharacterWindowNameText:SetPoint("LEFT", CharacterWindowFrame, "LEFT", PADDING_EDGE, 0)
            end
        end
    end
    
    -- Update scale name with color
    if CharacterWindowNameText then
        local displayName = scale.DisplayName or selectedScaleName
        CharacterWindowNameText:SetText("|cFF" .. color .. displayName .. "|r")
    end
    
    -- Calculate and update score
    if CharacterWindowScoreText then
        local totalScore = Valuate:CalculateTotalEquippedScore(scale)
        local decimals = Valuate:GetOptions().decimalPlaces or 1
        local formatStr = "%." .. decimals .. "f"
        
        local displayMode = Valuate:GetOptions().characterWindowDisplayMode or "total"
        local displayValue = totalScore
        
        if displayMode == "average" then
            -- Calculate average (total slots = 17, excluding shirt/tabard)
            local slotCount = #EquipmentSlots
            displayValue = slotCount > 0 and (totalScore / slotCount) or 0
        end
        
        local scoreText = string.format(formatStr, displayValue)
        CharacterWindowScoreText:SetText("|cFF" .. color .. scoreText .. "|r")
    end
    
    -- Calculate dynamic width based on content
    if CharacterWindowFrame and CharacterWindowNameText and CharacterWindowScoreText then
        local nameWidth = CharacterWindowNameText:GetStringWidth()
        local scoreWidth = CharacterWindowScoreText:GetStringWidth()
        
        -- Calculate total width: edge padding + optional icon + padding + name + padding + score + edge padding
        local totalWidth = PADDING_EDGE  -- Left edge
        if hasIcon then
            totalWidth = totalWidth + ICON_SIZE + PADDING_ICON_TO_NAME
        end
        totalWidth = totalWidth + nameWidth + PADDING_NAME_TO_VALUE + scoreWidth + PADDING_EDGE  -- Right edge
        
        -- Ensure minimum width and round up
        totalWidth = math.max(MIN_WIDTH, math.ceil(totalWidth))
        
        CharacterWindowFrame:SetWidth(totalWidth)
    end
    
    CharacterWindowUpdating = false
end

-- Public API to refresh character window display (called from Settings)
-- Export UpdateScaleList for use by ImportExport
function Valuate:RefreshScaleList()
    if UpdateScaleList then
        UpdateScaleList()
    end
end

-- Export ValuateUI_UpdateScaleEditor for use by ImportExport  
function Valuate:RefreshStatEditor()
    if ns.EditingScaleName and Valuate:GetScales()[ns.EditingScaleName] then
        ValuateUI_UpdateScaleEditor(ns.EditingScaleName, Valuate:GetScales()[ns.EditingScaleName])
    end
end

function Valuate:RefreshCharacterWindowDisplay()
    if CharacterWindowFrame then
        UpdateCharacterWindowDisplay()
    end
end

-- Public API to refresh character window scale dropdown in settings
function Valuate:RefreshCharacterWindowScaleDropdown()
    local dropdown = _G["ValuateCharWindowScaleDropdown"]
    if dropdown and Valuate.GetOptions and Valuate:GetOptions().characterWindowScale then
        -- Helper function to format display text (matches the one in settings creation)
        local function GetCharScaleDisplayText(scaleName, includeIcon)
            local scales = Valuate:GetScales()
            if not scaleName or not scales or not scales[scaleName] then
                return "Select Scale"
            end
            local scale = Valuate:GetScales()[scaleName]
            local displayName = scale.DisplayName or scaleName
            local color = scale.Color or "FFFFFF"
            
            -- Build display text with optional icon
            local text = ""
            if includeIcon and scale.Icon and scale.Icon ~= "" then
                text = "|T" .. scale.Icon .. ":14:14:0:0|t "
            end
            text = text .. "|cFF" .. color .. displayName .. "|r"
            
            return text
        end
        
        -- Update the dropdown text
        local newText = GetCharScaleDisplayText(Valuate:GetOptions().characterWindowScale, true)
        UIDropDownMenu_SetText(dropdown, newText)
        
        -- Force update the button text (direct access to ensure visual update)
        local button = _G[dropdown:GetName() .. "Button"]
        if button then
            local buttonText = _G[dropdown:GetName() .. "Text"]
            if buttonText then
                buttonText:SetText(newText)
            end
        end
    end
end

-- Public API to refresh character window visibility (called from Settings toggle)
function Valuate:RefreshCharacterWindowVisibility()
    if not CharacterWindowFrame then return end
    
    local charFrame = GetCharacterFrame()
    if not charFrame then return end
    
    -- Check if feature is enabled
    if Valuate:GetOptions().showCharacterWindowDisplay == false then
        CharacterWindowFrame:Hide()
    elseif charFrame:IsVisible() then
        CharacterWindowFrame:Show()
        UpdateCharacterWindowDisplay()
    end
end

-- Create character window UI elements
local function CreateCharacterWindowUI()
    if CharacterWindowInitialized then
        return
    end
    
    local charFrame = GetCharacterFrame()
    if not charFrame then
        return
    end
    
    CharacterWindowInitialized = true
    
    if Valuate.GetOptions and Valuate:GetOptions().debug then
        local frameName = charFrame:GetName() or "unknown"
        print("|cFF00FF00[Valuate]|r Creating character window UI on " .. frameName)
    end
    
    -- Create sleek container button - compact size (Button so it's clickable)
    local container = CreateFrame("Button", "ValuateCharacterWindowFrame", charFrame)
    container:SetWidth(200)  -- Initial width, will be adjusted dynamically
    container:SetHeight(22)
    container:SetFrameLevel(charFrame:GetFrameLevel() + 10)
    container:SetFrameStrata("HIGH")
    container:EnableMouse(true)  -- Enable mouse for tooltip and clicks
    container:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Sleek styled background
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = BORDER_TOOLTIP,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
    
    -- Click handler - left click opens UI, right click cycles scales
    container:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            -- Open Valuate UI
            if Valuate and Valuate.ToggleUI then
                Valuate:ToggleUI()
            else
                print("|cFFFF0000Valuate|r: UI not available. Please reload UI with /reload")
            end
        elseif btn == "RightButton" then
            -- Cycle through scales
            if not Valuate or not Valuate.GetActiveScales or not Valuate.GetOptions or not Valuate.GetScales then
                return
            end
            
            local activeScales = Valuate:GetActiveScales()
            if #activeScales == 0 then
                print("|cFFFF0000Valuate|r: No active scales available")
                return
            end
            
            -- Find current scale index
            local currentScale = Valuate:GetOptions().characterWindowScale
            local currentIndex = 1
            for i, scaleName in ipairs(activeScales) do
                if scaleName == currentScale then
                    currentIndex = i
                    break
                end
            end
            
            -- Cycle to next scale (wrap around)
            local nextIndex = (currentIndex % #activeScales) + 1
            local nextScale = activeScales[nextIndex]
            
            -- Update the selected scale
            Valuate:GetOptions().characterWindowScale = nextScale
            
            -- Show notification
            local scale = Valuate:GetScales()[nextScale]
            if scale then
                local color = scale.Color or "FFFFFF"
                local displayName = scale.DisplayName or nextScale
                print("|cFF00FF00Valuate|r: Switched to scale |cFF" .. color .. displayName .. "|r")
            end
            
            -- Refresh the display
            if Valuate.RefreshCharacterWindowDisplay then
                Valuate:RefreshCharacterWindowDisplay()
            end
            
            -- Refresh the dropdown in settings if it exists
            if Valuate.RefreshCharacterWindowScaleDropdown then
                Valuate:RefreshCharacterWindowScaleDropdown()
            end
            
            -- Refresh the tooltip if currently shown
            if GameTooltip:IsOwned(self) and GameTooltip:IsVisible() then
                ShowBreakdownTooltip(self)
                -- Re-add click hints
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Left-click to open Valuate UI", 0.7, 0.7, 0.7)
                
                -- Show next scale in cycle hint
                local nextScaleText = "Right-click to cycle scales"
                if Valuate and Valuate.GetActiveScales and Valuate.GetOptions and Valuate.GetScales then
                    local activeScales = Valuate:GetActiveScales()
                    if #activeScales > 0 then
                        local currentScale = Valuate:GetOptions().characterWindowScale
                        local currentIndex = 1
                        for i, scaleName in ipairs(activeScales) do
                            if scaleName == currentScale then
                                currentIndex = i
                                break
                            end
                        end
                        local nextIndex = (currentIndex % #activeScales) + 1
                        local nextScaleName = activeScales[nextIndex]
                        local nextScale = Valuate:GetScales()[nextScaleName]
                        if nextScale then
                            local color = nextScale.Color or "FFFFFF"
                            local displayName = nextScale.DisplayName or nextScaleName
                            local icon = ""
                            if nextScale.Icon and nextScale.Icon ~= "" then
                                icon = "|T" .. nextScale.Icon .. ":14:14:0:0|t "
                            end
                            nextScaleText = nextScaleText .. ": " .. icon .. "|cFF" .. color .. displayName .. "|r"
                        end
                    end
                end
                GameTooltip:AddLine(nextScaleText, 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end
    end)
    
    -- Tooltip on hover - show item breakdown and click hint
    container:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)  -- Highlight border
        ShowBreakdownTooltip(self)
        -- Add click hints to tooltip (it's already shown by ShowBreakdownTooltip)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open Valuate UI", 0.7, 0.7, 0.7)
        
        -- Show next scale in cycle hint
        local nextScaleText = "Right-click to cycle scales"
        if Valuate and Valuate.GetActiveScales and Valuate.GetOptions and Valuate.GetScales then
            local activeScales = Valuate:GetActiveScales()
            if #activeScales > 0 then
                local currentScale = Valuate:GetOptions().characterWindowScale
                local currentIndex = 1
                for i, scaleName in ipairs(activeScales) do
                    if scaleName == currentScale then
                        currentIndex = i
                        break
                    end
                end
                local nextIndex = (currentIndex % #activeScales) + 1
                local nextScaleName = activeScales[nextIndex]
                local nextScale = Valuate:GetScales()[nextScaleName]
                if nextScale then
                    local color = nextScale.Color or "FFFFFF"
                    local displayName = nextScale.DisplayName or nextScaleName
                    local icon = ""
                    if nextScale.Icon and nextScale.Icon ~= "" then
                        icon = "|T" .. nextScale.Icon .. ":14:14:0:0|t "
                    end
                    nextScaleText = nextScaleText .. ": " .. icon .. "|cFF" .. color .. displayName .. "|r"
                end
            end
        end
        GameTooltip:AddLine(nextScaleText, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    container:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)  -- Restore border
        HideBreakdownTooltip()
    end)
    
    -- Position centered at top of character model area
    if AscensionPaperDollPanelModel then
        container:SetPoint("TOP", AscensionPaperDollPanelModel, "TOP", 0, -5)
    elseif AscensionPaperDollPanel then
        container:SetPoint("TOP", AscensionPaperDollPanel, "TOP", 0, -35)
    else
        container:SetPoint("TOP", charFrame, "TOP", 0, -75)
    end
    
    container:Show()
    
    -- Standardized padding values
    local PADDING_EDGE = 6           -- Padding from container edges
    local PADDING_ICON_TO_NAME = 4   -- Spacing between icon and name
    local PADDING_NAME_TO_VALUE = 8  -- Spacing between name and value
    
    -- Scale icon (small, left side)
    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(14, 14)
    iconFrame:SetPoint("LEFT", container, "LEFT", PADDING_EDGE, 0)
    
    local iconTexture = iconFrame:CreateTexture(nil, "OVERLAY")
    iconTexture:SetAllPoints(iconFrame)
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconTexture:Hide()
    
    -- Scale name (small, colored)
    local nameText = container:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    nameText:SetPoint("LEFT", container, "LEFT", PADDING_EDGE, 0)
    nameText:SetJustifyH("LEFT")
    
    -- Score display (right side)
    local scoreText = container:CreateFontString(nil, "OVERLAY", FONT_BODY)
    scoreText:SetPoint("RIGHT", container, "RIGHT", -PADDING_EDGE, 0)
    scoreText:SetJustifyH("RIGHT")
    scoreText:SetText("--")
    
    -- Store references
    CharacterWindowFrame = container
    CharacterWindowIconTexture = iconTexture
    CharacterWindowNameText = nameText
    CharacterWindowScoreText = scoreText
    
    -- Hook OnShow/OnHide of the character frame
    if not charFrame.valuateHooked then
        charFrame.valuateHooked = true
        charFrame:HookScript("OnShow", function()
            if CharacterWindowFrame and Valuate.GetOptions then
                -- Only show if feature is enabled
                if Valuate:GetOptions().showCharacterWindowDisplay ~= false then
                    CharacterWindowFrame:Show()
                    local updateFrame = CreateFrame("Frame")
                    updateFrame:SetScript("OnUpdate", function(self, elapsed)
                        self.elapsed = (self.elapsed or 0) + elapsed
                        if self.elapsed >= 0.1 then
                            UpdateCharacterWindowDisplay()
                            self:SetScript("OnUpdate", nil)
                        end
                    end)
                end
            end
        end)
        charFrame:HookScript("OnHide", function()
            if CharacterWindowFrame then
                CharacterWindowFrame:Hide()
            end
        end)
    end
    
    -- Initial update if already visible and feature enabled
    if Valuate.GetOptions and charFrame:IsVisible() and Valuate:GetOptions().showCharacterWindowDisplay ~= false then
        local initUpdateFrame = CreateFrame("Frame")
        initUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 0.3 then
                UpdateCharacterWindowDisplay()
                self:SetScript("OnUpdate", nil)
            end
        end)
    elseif Valuate.GetOptions and Valuate:GetOptions().showCharacterWindowDisplay == false then
        container:Hide()
    end
end

-- Create event frame for inventory changes (only created once)
local CharacterWindowEventFrame = CreateFrame("Frame")
local updateThrottleFrame = nil
CharacterWindowEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
CharacterWindowEventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit == "player" then
        local charFrame = GetCharacterFrame()
        if CharacterWindowInitialized and charFrame and charFrame:IsVisible() and CharacterWindowFrame then
            -- Throttle updates - only update after a short delay
            if not updateThrottleFrame then
                updateThrottleFrame = CreateFrame("Frame")
            end
            updateThrottleFrame:SetScript("OnUpdate", function(updateSelf, elapsed)
                updateSelf.elapsed = (updateSelf.elapsed or 0) + elapsed
                if updateSelf.elapsed >= 0.2 then
                    UpdateCharacterWindowDisplay()
                    updateSelf:SetScript("OnUpdate", nil)
                    updateSelf.elapsed = 0
                end
            end)
        end
    end
end)

-- Initialize when character frame becomes available
local function InitializeCharacterWindowUI()
    if CharacterWindowInitialized then
        return
    end
    
    local charFrame = GetCharacterFrame()
    if charFrame then
        CreateCharacterWindowUI()
        -- If character frame is already visible, update immediately
        if charFrame:IsVisible() then
            local updateFrame = CreateFrame("Frame")
            updateFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = (self.elapsed or 0) + elapsed
                if self.elapsed >= 0.3 then
                    if CharacterWindowFrame then
                        UpdateCharacterWindowDisplay()
                    end
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    else
        -- Wait for character UI to load
        local initFrame = CreateFrame("Frame")
        initFrame:RegisterEvent("ADDON_LOADED")
        initFrame:SetScript("OnEvent", function(self, event, addonName)
            -- Check for both Blizzard and Ascension character UI
            if addonName == "Blizzard_CharacterUI" or addonName == "Ascension_CharacterUI" then
                local cFrame = GetCharacterFrame()
                if cFrame and not CharacterWindowInitialized then
                    CreateCharacterWindowUI()
                    if cFrame:IsVisible() and CharacterWindowFrame then
                        UpdateCharacterWindowDisplay()
                    end
                end
                initFrame:UnregisterEvent("ADDON_LOADED")
            end
        end)
        
        -- Also try periodically in case event doesn't fire
        local retryFrame = CreateFrame("Frame")
        retryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 1 then
                local cFrame = GetCharacterFrame()
                if cFrame and not CharacterWindowInitialized then
                    CreateCharacterWindowUI()
                    if cFrame:IsVisible() and CharacterWindowFrame then
                        UpdateCharacterWindowDisplay()
                    end
                end
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- Create a simple initialization function that can be called from Valuate:Initialize
function Valuate:InitializeCharacterWindowUI()
    if Valuate.GetOptions and Valuate:GetOptions().debug then
        local charFrame = GetCharacterFrame()
        print("|cFF00FF00[Valuate]|r InitializeCharacterWindowUI called, initialized=" .. tostring(CharacterWindowInitialized) .. ", AscensionCharacterFrame=" .. tostring(AscensionCharacterFrame ~= nil) .. ", PaperDollFrame=" .. tostring(PaperDollFrame ~= nil))
    end
    if CharacterWindowInitialized then
        return
    end
    InitializeCharacterWindowUI()
end

-- Try to initialize immediately and also wait for character frame
local function TryInitialize()
    if CharacterWindowInitialized then
        return true
    end
    local charFrame = GetCharacterFrame()
    if charFrame then
        if Valuate.GetOptions and Valuate:GetOptions().debug then
            local frameName = charFrame:GetName() or "unknown"
            print("|cFF00FF00[Valuate]|r Character frame found (" .. frameName .. "), creating character window UI")
        end
        CreateCharacterWindowUI()
        return true
    end
    return false
end

-- Register for PLAYER_ENTERING_WORLD which fires after all frames are created
local charWindowEventFrame = CreateFrame("Frame")
charWindowEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
charWindowEventFrame:SetScript("OnEvent", function(self, event)
    local charFrame = GetCharacterFrame()
    if Valuate.GetOptions and Valuate:GetOptions().debug then
        print("|cFF00FF00[Valuate]|r PLAYER_ENTERING_WORLD fired, AscensionCharacterFrame=" .. tostring(AscensionCharacterFrame ~= nil) .. ", PaperDollFrame=" .. tostring(PaperDollFrame ~= nil))
    end
    if not CharacterWindowInitialized then
        if charFrame then
            CreateCharacterWindowUI()
        elseif Valuate.GetOptions and Valuate:GetOptions().debug then
            print("|cFFFF0000[Valuate]|r Character frame not found after PLAYER_ENTERING_WORLD!")
        end
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- Also try immediately in case we loaded late (but only if SavedVariables are ready)
local charFrameInit = GetCharacterFrame()
if charFrameInit and Valuate.GetOptions then
    if Valuate:GetOptions().debug then
        local frameName = charFrameInit:GetName() or "unknown"
        print("|cFF00FF00[Valuate]|r Character frame exists on file load (" .. frameName .. "), creating UI immediately")
    end
    TryInitialize()
end

-- ========================================
-- Public API
-- ========================================

function Valuate:ShowUI()
    local success, err = pcall(function()
        if not ns.ValuateUIFrame then
            CreateMainWindow()
            
            -- Create tab system (tabs outside window, panels inside content)
            local tabs = CreateTabSystem(ns.ValuateUIFrame, ns.ValuateUIFrame.contentFrame)
            ns.ValuateUIFrame.tabs = tabs
            
            -- Create scale list using the proper container hierarchy
            local scaleList = CreateScaleList(tabs.scalesPanel.scaleListContainer)
            
            -- Create scale editor using the proper container hierarchy
            local scaleEditor = CreateScaleEditor(tabs.scalesPanel.scaleEditorContainer)
            
            -- Create instructions panel
            local instructionsPanel = CreateInstructionsPanel(tabs.instructionsPanel)
            ns.ValuateUIFrame.instructionsPanel = instructionsPanel
            
            -- Create about panel
            local aboutPanel = CreateAboutPanel(tabs.aboutPanel)
            ns.ValuateUIFrame.aboutPanel = aboutPanel
            
            -- Create changelog panel
            local changelogPanel = CreateChangelogPanel(tabs.changelogPanel)
            ns.ValuateUIFrame.changelogPanel = changelogPanel
            
            -- Create settings panel
            local settingsPanel = CreateSettingsPanel(tabs.settingsPanel)
            ns.ValuateUIFrame.settingsPanel = settingsPanel
            
            -- Create best equipment panel
            CreateBestEquipmentPanel(tabs.bestEquipmentPanel)
        end
        
        -- Show first, then refresh: the best-equipment panel skips rebuilding
        -- while the window is hidden, so it must be shown before we refresh it.
        ns.ValuateUIFrame:Show()

        -- Open animation: a quick fade-in plus a spring scale-pop. Under Reduce
        -- Motion the Anim.* calls apply the final state instantly (no flash of 0).
        ns.ValuateUIFrame.closing = false
        ns.ValuateUIFrame:SetAlpha(0)
        ns.ValuateUIFrame:SetScale(0.94)
        Anim.fade(ns.ValuateUIFrame, 1, 0.22, "outQuad")
        Anim.scaleTo(ns.ValuateUIFrame, 1, 0.30, "outBack")

        -- Update dynamic lists now that the window is visible
        UpdateScaleList()
        if Valuate.RefreshBestEquipmentDisplay then
            Valuate:RefreshBestEquipmentDisplay()
        end
    end)
    
    if not success then
        print("|cFFFF0000Valuate|r: Error opening UI: " .. tostring(err))
        print("|cFFFF0000Valuate|r: Please report this error and try /reload")
    end
end

function Valuate:HideUI()
    if not ns.ValuateUIFrame or not ns.ValuateUIFrame:IsShown() then return end

    -- Reset helper so the window always reopens at full alpha/scale.
    local function finish()
        ns.ValuateUIFrame:Hide()
        ns.ValuateUIFrame:SetAlpha(1)
        ns.ValuateUIFrame:SetScale(1)
        ns.ValuateUIFrame.closing = false
    end

    if ReduceMotion() then finish(); return end

    -- Close animation: fade + shrink, then actually hide.
    ns.ValuateUIFrame.closing = true
    Anim.fade(ns.ValuateUIFrame, 0, 0.16, "outQuad")
    Anim.scaleTo(ns.ValuateUIFrame, 0.94, 0.16, "outQuad", finish)
end

function Valuate:ToggleUI()
    if not ns.ValuateUIFrame then
        Valuate:ShowUI()
        return
    end

    -- Treat a window mid-close-animation as already hidden, so a quick re-toggle
    -- reopens it rather than getting stuck.
    if ns.ValuateUIFrame:IsShown() and not ns.ValuateUIFrame.closing then
        Valuate:HideUI()
    else
        Valuate:ShowUI()
    end
end

-- Verify UI loaded


