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


