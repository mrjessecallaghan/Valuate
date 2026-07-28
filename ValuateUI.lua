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

-- Scale editor panel (defined in ui/ScaleEditor.lua)
local CreateScaleEditor = ns.CreateScaleEditor

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
        -- (no `frame` field: it referenced an undefined `tabFrame`, so it was always
        -- nil, and nothing ever read it. Removed rather than left as a nil trap.)
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


