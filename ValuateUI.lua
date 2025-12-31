-- ValuateUI.lua
-- UI Window for Valuate stat weight calculator

-- ========================================
-- UI Constants
-- ========================================
local PADDING = 12
local SPACING = 8
local BUTTON_HEIGHT = 24
local ENTRY_HEIGHT = 24
local SCROLLBAR_WIDTH = 20  -- Width reserved for scrollbars (18px bar + 2px gap)

-- Standardized Border Styles
local BORDER_TOOLTIP = "Interface\\Tooltips\\UI-Tooltip-Border"  -- Clean, minimal border
local BORDER_EDGE_SIZE = 12

-- Backdrop presets for consistent styling
local BACKDROP_WINDOW = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = 16,
    tile = false,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local BACKDROP_PANEL = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = BORDER_EDGE_SIZE,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local BACKDROP_INPUT = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = 10,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local BACKDROP_BUTTON = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = BORDER_EDGE_SIZE,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

-- Font Standards (WoW built-in fonts)
-- Title: Window titles, major headings
local FONT_TITLE = "GameFontNormalLarge"       -- ~16pt, yellow/gold
-- H1: Panel headers, section titles  
local FONT_H1 = "GameFontNormal"               -- ~12pt, yellow/gold
-- H2: Category headers, subsection titles
local FONT_H2 = "GameFontNormalSmall"          -- ~10pt, yellow/gold
-- H3: Minor headers, group labels
local FONT_H3 = "GameFontHighlightSmall"       -- ~10pt, white
-- Body: Regular text, labels, button text
local FONT_BODY = "GameFontHighlight"          -- ~12pt, white
-- Small: Compact text, stat labels
local FONT_SMALL = "GameFontHighlightSmall"    -- ~10pt, white

-- Main UI Frame
local ValuateUIFrame = nil
local CurrentSelectedScale = nil
local EditingScaleName = nil
local OriginalScaleData = nil

-- Ensure ValuateOptions exists
ValuateOptions = ValuateOptions or {}

-- Initialize UI Options
if not ValuateOptions.uiPosition then
    ValuateOptions.uiPosition = {}
end

-- ========================================
-- Utility Functions
-- ========================================

local function HexToRGB(hex)
    if not hex or #hex ~= 6 then
        return 1, 1, 1
    end
    local r = tonumber(string.sub(hex, 1, 2), 16) / 255
    local g = tonumber(string.sub(hex, 3, 4), 16) / 255
    local b = tonumber(string.sub(hex, 5, 6), 16) / 255
    return r, g, b
end

local function RGBToHex(r, g, b)
    r = math.floor(math.max(0, math.min(1, r)) * 255)
    g = math.floor(math.max(0, math.min(1, g)) * 255)
    b = math.floor(math.max(0, math.min(1, b)) * 255)
    return string.format("%02X%02X%02X", r, g, b)
end

-- ========================================
-- Main Window Creation
-- ========================================

local function CreateMainWindow()
    if ValuateUIFrame then
        return ValuateUIFrame
    end
    
    -- Main frame
    local frame = CreateFrame("Frame", "ValuateUIFrame", UIParent)
    frame:SetWidth(600)
    frame:SetHeight(500)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("DIALOG")  -- Above most UI elements
    
    -- Backdrop (standardized clean border)
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    -- Position (ensure ValuateOptions exists)
    ValuateOptions = ValuateOptions or {}
    if ValuateOptions.uiPosition and ValuateOptions.uiPosition.point and ValuateOptions.uiPosition.x and ValuateOptions.uiPosition.y then
        frame:SetPoint(ValuateOptions.uiPosition.point, UIParent, ValuateOptions.uiPosition.relativePoint or ValuateOptions.uiPosition.point, ValuateOptions.uiPosition.x, ValuateOptions.uiPosition.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Save position on move
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ValuateOptions = ValuateOptions or {}
        ValuateOptions.uiPosition = ValuateOptions.uiPosition or {}
        local point, _, relativePoint, x, y = self:GetPoint()
        ValuateOptions.uiPosition.point = point
        ValuateOptions.uiPosition.relativePoint = relativePoint
        ValuateOptions.uiPosition.x = x
        ValuateOptions.uiPosition.y = y
    end)
    
    -- Title bar background
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    titleBar:SetHeight(32)
    titleBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Header",
        edgeFile = nil,
        tile = true,
        tileSize = 256,
        edgeSize = 0
    })
    
    -- Title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", FONT_TITLE)
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText("Valuate")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        Valuate:HideUI()
    end)
    
    -- Content area (below title bar)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", PADDING, -PADDING)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
    frame.contentFrame = contentFrame
    
    -- Store reference
    ValuateUIFrame = frame
    frame:Hide()
    
    return frame
end

-- ========================================
-- Tab System
-- ========================================

local function CreateTabSystem(mainFrame, contentFrame)
    -- Tab bar sitting on the bottom border of the window
    local tabFrame = CreateFrame("Frame", nil, mainFrame)
    tabFrame:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 20, 1)  -- Sits just on the border
    tabFrame:SetHeight(24)
    tabFrame:SetWidth(200)
    
    local activeTab = "scales"
    local tabs = {}
    local tabPanels = {}
    
    local function SelectTab(tabName)
        activeTab = tabName
        
        -- Hide all panels
        for _, panel in pairs(tabPanels) do
            panel:Hide()
        end
        
        -- Show selected panel
        if tabPanels[tabName] then
            tabPanels[tabName]:Show()
        end
        
        -- Update tab buttons - selected vs unselected appearance
        for name, btn in pairs(tabs) do
            if name == tabName then
                -- Selected tab: brighter background and border
                btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
                btn:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
                btn.label:SetTextColor(1, 0.82, 0, 1)  -- Gold text
            else
                -- Unselected tab: darker, recessed look
                btn:SetBackdropColor(0.06, 0.06, 0.06, 1)
                btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
                btn.label:SetTextColor(0.5, 0.5, 0.5, 1)  -- Dim text
            end
        end
    end
    
    -- Create tab buttons dynamically - sitting on bottom border of window
    local function CreateTab(name, text, panel)
        local btn = CreateFrame("Button", nil, tabFrame)
        btn:SetHeight(22)
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
        btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        btn:SetScript("OnClick", function()
            SelectTab(name)
        end)
        
        local label = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        label:SetText(text)
        btn.label = label
        
        -- Size button based on text
        btn:SetWidth(label:GetStringWidth() + 40)
        
        -- Position tabs horizontally, outside bottom of window
        if not tabs.lastTab then
            btn:SetPoint("TOPLEFT", tabFrame, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", tabs.lastTab, "TOPRIGHT", -1, 0)
        end
        tabs.lastTab = btn
        tabs[name] = btn
        tabPanels[name] = panel
        
        return btn
    end
    
    -- Create panel containers - fill the entire content area
    local scalesPanel = CreateFrame("Frame", nil, contentFrame)
    scalesPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    scalesPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    
    local settingsPanel = CreateFrame("Frame", nil, contentFrame)
    settingsPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    settingsPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    settingsPanel:Hide()
    
    -- Create tabs
    CreateTab("scales", "Scales", scalesPanel)
    CreateTab("settings", "Settings", settingsPanel)
    
    -- Select default tab
    SelectTab("scales")
    
    return {
        frame = tabFrame,
        scalesPanel = scalesPanel,
        settingsPanel = settingsPanel,
        selectTab = SelectTab
    }
end

-- ========================================
-- Scale List (Left Panel)
-- ========================================

local ScaleListFrame = nil
local ScaleListButtons = {}

local function UpdateScaleList()
    if not ScaleListFrame then return end
    
    -- Clear existing buttons
    for _, btn in pairs(ScaleListButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    ScaleListButtons = {}
    
    -- Get all scales
    local scales = {}
    if ValuateScales then
        for name, scale in pairs(ValuateScales) do
            tinsert(scales, { name = name, scale = scale })
        end
    end
    
    -- Sort by display name
    table.sort(scales, function(a, b)
        return (a.scale.DisplayName or a.name) < (b.scale.DisplayName or b.name)
    end)
    
    -- Create button for each scale
    local lastButton = nil
    for i, scaleData in ipairs(scales) do
        local btn = CreateFrame("Button", nil, ScaleListFrame)
        btn:SetHeight(ENTRY_HEIGHT)
        btn:SetWidth(168)  -- Fits within scroll content area
        
        if i == 1 then
            btn:SetPoint("TOPLEFT", ScaleListFrame, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, -2)
        end
        lastButton = btn
        
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
        btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        
        -- Visibility checkbox (leftmost element)
        local visCheckbox = CreateFrame("CheckButton", nil, btn)
        visCheckbox:SetSize(14, 14)
        visCheckbox:SetPoint("LEFT", btn, "LEFT", 4, 0)
        visCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        visCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        visCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        visCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        
        local isVisible = scaleData.scale.Visible ~= false
        visCheckbox:SetChecked(isVisible)
        
        -- Color preview
        local colorPreview = btn:CreateTexture(nil, "OVERLAY")
        colorPreview:SetSize(14, 14)
        colorPreview:SetPoint("LEFT", visCheckbox, "RIGHT", 4, 0)
        local color = scaleData.scale.Color or "FFFFFF"
        local r, g, b = HexToRGB(color)
        colorPreview:SetTexture(1, 1, 1, 1)
        colorPreview:SetVertexColor(r, g, b, 1)
        
        -- Scale name
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        nameLabel:SetPoint("LEFT", colorPreview, "RIGHT", 4, 0)
        nameLabel:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText(scaleData.scale.DisplayName or scaleData.name)
        
        -- Helper to update visual state based on visibility
        local function UpdateVisualState(visible)
            if visible then
                nameLabel:SetTextColor(r, g, b, 1)
                colorPreview:SetVertexColor(r, g, b, 1)
                btn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
            else
                nameLabel:SetTextColor(0.4, 0.4, 0.4, 1)
                colorPreview:SetVertexColor(0.4, 0.4, 0.4, 1)
                btn:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
            end
        end
        
        -- Set initial visual state
        UpdateVisualState(isVisible)
        
        -- Visibility checkbox click handler
        visCheckbox:SetScript("OnClick", function(self)
            local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
            if ValuateScales[scaleData.name] then
                ValuateScales[scaleData.name].Visible = checked
            end
            UpdateVisualState(checked)
        end)
        
        -- Tooltip for visibility checkbox
        visCheckbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show in Tooltip", 1, 1, 1)
            GameTooltip:AddLine("Toggle whether this scale appears in item tooltips.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        visCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Store references for visual updates
        btn.nameLabel = nameLabel
        btn.colorPreview = colorPreview
        btn.visCheckbox = visCheckbox
        btn.updateVisualState = UpdateVisualState
        btn.scaleColor = { r = r, g = g, b = b }
        
        -- Highlight on mouseover (only if visible)
        btn:SetScript("OnEnter", function(self)
            if CurrentSelectedScale ~= scaleData.name then
                local vis = ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Visible ~= false
                if vis then
                    self:SetBackdropColor(0.3, 0.3, 0.3, 0.9)
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if CurrentSelectedScale ~= scaleData.name then
                local vis = ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Visible ~= false
                if vis then
                    self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                else
                    self:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
                end
            end
        end)
        
        -- Click to select
        btn:SetScript("OnClick", function(self)
            -- Deselect previous
            if CurrentSelectedScale and ScaleListButtons[CurrentSelectedScale] then
                local prevBtn = ScaleListButtons[CurrentSelectedScale]
                local prevVis = ValuateScales[CurrentSelectedScale] and ValuateScales[CurrentSelectedScale].Visible ~= false
                if prevVis then
                    prevBtn:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                else
                    prevBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.6)
                end
            end
            
            -- Select this one
            CurrentSelectedScale = scaleData.name
            self:SetBackdropColor(0.3, 0.5, 0.8, 1.0)
            
            -- Update editor with current scale data from ValuateScales
            ValuateUI_UpdateScaleEditor(scaleData.name, ValuateScales[scaleData.name])
        end)
        
        ScaleListButtons[scaleData.name] = btn
        tinsert(ScaleListButtons, btn)
    end
    
    -- Update scroll frame content height (account for spacing between entries)
    if ScaleListFrame then
        local contentHeight = #scales * (ENTRY_HEIGHT + 2)
        ScaleListFrame:SetHeight(math.max(contentHeight, 100))
        
        -- Update scrollbar range
        local scrollFrame = ScaleListFrame:GetParent()
        if scrollFrame and scrollFrame.scrollBar then
            local scrollBar = scrollFrame.scrollBar
            local scrollFrameHeight = scrollFrame:GetHeight()
            local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
            scrollBar:SetMinMaxValues(0, maxScroll)
            if scrollBar:GetValue() > maxScroll then
                scrollBar:SetValue(maxScroll)
            end
        end
    end
end

local function CreateScaleList(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    container:SetWidth(200)
    
    -- New Scale button
    local newButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    newButton:SetText("New Scale")
    newButton:SetHeight(BUTTON_HEIGHT)
    newButton:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    newButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    newButton:SetScript("OnClick", function()
        ValuateUI_NewScale()
    end)
    
    -- Delete button
    local deleteButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    deleteButton:SetText("Delete")
    deleteButton:SetHeight(BUTTON_HEIGHT)
    deleteButton:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 0, -SPACING)
    deleteButton:SetPoint("TOPRIGHT", newButton, "BOTTOMRIGHT", 0, -SPACING)
    deleteButton:SetScript("OnClick", function()
        if CurrentSelectedScale then
            ValuateUI_DeleteScale(CurrentSelectedScale)
        end
    end)
    
    -- Scroll frame for scale list (reserves space for scrollbar on right)
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", deleteButton, "BOTTOMLEFT", 0, -SPACING)
    scrollFrame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("TOPRIGHT", deleteButton, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, -SPACING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 0)
    scrollFrame:SetBackdrop(BACKDROP_PANEL)
    scrollFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
    scrollFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newValue = current - (delta * 30)
        newValue = math.max(0, math.min(maxScroll, newValue))
        self:SetVerticalScroll(newValue)
        if scrollFrame.scrollBar then
            scrollFrame.scrollBar:SetValue(newValue)
        end
    end)
    
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(170)  -- Content width (container width minus scrollbar)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop for visibility
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    scrollBarBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Scrollbar (positioned to the right of clip frame, inside container)
    local scrollBar = CreateFrame("Slider", nil, scrollBarBg, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollBarBg, "TOPLEFT", 2, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollBarBg, "BOTTOMRIGHT", -2, 16)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(20)
    scrollBar.scrollFrame = scrollFrame
    scrollBar:SetScript("OnValueChanged", function(self, value)
        if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
            self.scrollFrame:SetVerticalScroll(value)
        end
    end)
    scrollBar:SetValue(0)
    scrollFrame.scrollBar = scrollBar
    
    ScaleListFrame = contentFrame
    
    return container
end

-- ========================================
-- Scale Editor (Right Panel)
-- ========================================

local ScaleEditorFrame = nil
local StatWeightRows = {}

local function UpdateStatWeightsList(scaleName, scale)
    if not ScaleEditorFrame then return end
    
    -- Clear existing rows
    for _, row in pairs(StatWeightRows) do
        row:Hide()
        row:SetParent(nil)
    end
    StatWeightRows = {}
    
    -- Stat categories with headers
    local statCategories = {
        { header = "Primary", stats = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" } },
        { header = "Physical", stats = { "AttackPower", "HitRating", "CritRating", "HasteRating", "ExpertiseRating", "DPS" } },
        { header = "Spell", stats = { "SpellPower" } },
        { header = "Mitigation", stats = { "Armor", "DefenseRating", "DodgeRating", "ParryRating", "BlockRating", "BlockValue" } },
        { header = "PvP & Other", stats = { "ResilienceRating", "PVEPower", "PVPPower" } },
    }
    
    local ROW_HEIGHT = 18
    local ROW_SPACING = 1
    local HEADER_HEIGHT = 16
    local HEADER_SPACING = 4
    
    -- Create rows dynamically - anchor to content frame top
    local lastElement = nil
    local isFirstElement = true
    local totalHeight = 0
    
    for _, category in ipairs(statCategories) do
        -- Create category header
        local headerRow = CreateFrame("Frame", nil, ScaleEditorFrame)
        headerRow:SetHeight(HEADER_HEIGHT)
        headerRow:SetWidth(280)
        
        if isFirstElement then
            headerRow:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", 0, 0)
            isFirstElement = false
        else
            headerRow:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -HEADER_SPACING)
            totalHeight = totalHeight + HEADER_SPACING
        end
        lastElement = headerRow
        totalHeight = totalHeight + HEADER_HEIGHT
        
        local headerLabel = headerRow:CreateFontString(nil, "OVERLAY", FONT_H2)
        headerLabel:SetPoint("LEFT", headerRow, "LEFT", 0, 0)
        headerLabel:SetText(category.header)
        headerLabel:SetTextColor(0.7, 0.7, 0.5, 1)
        
        tinsert(StatWeightRows, headerRow)
        
        -- Create stat rows for this category
        for _, statName in ipairs(category.stats) do
            if ValuateStatNames[statName] then
                local row = CreateFrame("Frame", nil, ScaleEditorFrame)
                row:SetHeight(ROW_HEIGHT)
                row:SetWidth(280)
                row:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -ROW_SPACING)
                lastElement = row
                totalHeight = totalHeight + ROW_HEIGHT + ROW_SPACING
                
                -- Stat label
                local label = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
                label:SetPoint("LEFT", row, "LEFT", 8, 0)
                label:SetWidth(100)
                label:SetJustifyH("RIGHT")
                label:SetText(ValuateStatNames[statName] .. ":")
                
                -- Value input
                local editBox = CreateFrame("EditBox", nil, row)
                editBox:SetHeight(16)
                editBox:SetWidth(45)
                editBox:SetPoint("LEFT", label, "RIGHT", 4, 0)
                editBox:SetAutoFocus(false)
                editBox:SetFontObject(_G[FONT_SMALL])
                editBox:SetJustifyH("CENTER")
                editBox:SetBackdrop(BACKDROP_INPUT)
                editBox:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
                editBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
                editBox:SetTextInsets(2, 2, 0, 0)
                editBox.statName = statName
                
                -- Focus handling
                editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
                
                -- Unusable checkbox (ban stat)
                local unusableCheckbox = CreateFrame("CheckButton", nil, row)
                unusableCheckbox:SetSize(14, 14)
                unusableCheckbox:SetPoint("LEFT", editBox, "RIGHT", 4, 0)
                unusableCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
                unusableCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
                unusableCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
                unusableCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
                unusableCheckbox.statName = statName
                
                -- Helper function to update banned visual state
                local function UpdateBannedState(isBanned)
                    if isBanned then
                        -- Grey out and disable
                        label:SetTextColor(0.4, 0.4, 0.4, 1)
                        editBox:SetText("")
                        editBox:EnableMouse(false)
                        editBox:EnableKeyboard(false)
                        editBox:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
                        editBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
                    else
                        -- Restore normal state
                        label:SetTextColor(1, 1, 1, 1)
                        editBox:EnableMouse(true)
                        editBox:EnableKeyboard(true)
                        editBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                        editBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                    end
                end
                
                -- Check if this stat is marked as unusable
                local isUnusable = (scale and scale.Unusable and scale.Unusable[statName])
                unusableCheckbox:SetChecked(isUnusable == true)
                
                -- Set initial visual state based on whether banned
                if isUnusable then
                    UpdateBannedState(true)
                else
                    -- Show value only if not banned
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
                    
                    -- Immediately save to scale data
                    if EditingScaleName and ValuateScales[EditingScaleName] then
                        local currentScale = ValuateScales[EditingScaleName]
                        if not currentScale.Unusable then
                            currentScale.Unusable = {}
                        end
                        
                        if checked then
                            currentScale.Unusable[statName] = true
                            -- Clear the value when banning
                            if currentScale.Values then
                                currentScale.Values[statName] = nil
                            end
                        else
                            currentScale.Unusable[statName] = nil
                        end
                    end
                    
                    -- Update visual state
                    UpdateBannedState(checked)
                end)
                
                -- Tooltip for unusable checkbox
                unusableCheckbox:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine("Ban Stat", 1, 1, 1)
                    GameTooltip:AddLine("If checked, items with this stat will not show a score for this scale.", 0.8, 0.8, 0.8, true)
                    GameTooltip:Show()
                end)
                unusableCheckbox:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                
                -- Store references
                row.label = label
                row.editBox = editBox
                row.unusableCheckbox = unusableCheckbox
                row.updateBannedState = UpdateBannedState
                StatWeightRows[statName] = row
                tinsert(StatWeightRows, row)
            end
        end
    end
    
    -- Update content frame height for scrolling
    if ScaleEditorFrame and ScaleEditorFrame.scrollFrame then
        ScaleEditorFrame:SetHeight(math.max(totalHeight, 100))
        
        -- Update scrollbar range
        local scrollFrame = ScaleEditorFrame.scrollFrame
        local scrollBar = scrollFrame.scrollBar
        if scrollBar then
            local scrollFrameHeight = scrollFrame:GetHeight()
            local maxScroll = math.max(0, totalHeight - scrollFrameHeight)
            scrollBar:SetMinMaxValues(0, maxScroll)
            scrollBar:SetValue(0)  -- Reset scroll to top when changing scales
        end
    end
end

function ValuateUI_UpdateScaleEditor(scaleName, scale)
    EditingScaleName = scaleName
    
    -- Save original for cancel
    OriginalScaleData = {}
    if scale then
        for k, v in pairs(scale) do
            OriginalScaleData[k] = v
        end
        if scale.Values then
            OriginalScaleData.Values = {}
            for k, v in pairs(scale.Values) do
                OriginalScaleData.Values[k] = v
            end
        end
    end
    
    if not ScaleEditorFrame then return end
    
    -- Show the editor container
    if ScaleEditorFrame.container then
        ScaleEditorFrame.container:Show()
    end
    
    -- Update name field
    if ScaleEditorFrame.nameEditBox then
        ScaleEditorFrame.nameEditBox:SetText(scale.DisplayName or scaleName)
    end
    
    -- Update color preview
    if ScaleEditorFrame.colorButton then
        local color = scale.Color or "FFFFFF"
        local r, g, b = HexToRGB(color)
        ScaleEditorFrame.colorButton.preview:SetVertexColor(r, g, b, 1)
    end
    
    -- Update stat weights
    UpdateStatWeightsList(scaleName, scale)
end

function ValuateUI_NewScale()
    local baseName = "New Scale"
    local name = baseName
    local counter = 1
    while ValuateScales[name] do
        name = baseName .. " " .. counter
        counter = counter + 1
    end
    
    local newScale = {
        DisplayName = name,
        Color = "FFFFFF",
        Visible = true,
        Values = {}
    }
    
    ValuateScales[name] = newScale
    
    -- Refresh list and select new scale
    UpdateScaleList()
    if ScaleListButtons[name] then
        ScaleListButtons[name]:GetScript("OnClick")(ScaleListButtons[name])
    end
end

function ValuateUI_DeleteScale(scaleName)
    if not scaleName or not ValuateScales[scaleName] then return end
    
    -- Confirmation dialog (simple)
    StaticPopup_Show("VALUATE_DELETE_SCALE", scaleName, nil, { scaleName = scaleName })
end

-- Handle delete confirmation (register on first use)
if not StaticPopupDialogs["VALUATE_DELETE_SCALE"] then
    StaticPopupDialogs["VALUATE_DELETE_SCALE"] = {
        text = "Delete scale '%s'?",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function(self, data)
            if data and data.scaleName then
                ValuateScales[data.scaleName] = nil
                if CurrentSelectedScale == data.scaleName then
                    CurrentSelectedScale = nil
                    EditingScaleName = nil
                    -- Hide the container, not the content frame
                    if ScaleEditorFrame and ScaleEditorFrame.container then
                        ScaleEditorFrame.container:Hide()
                    end
                end
                UpdateScaleList()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

local function CreateScaleEditor(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 200 + PADDING, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Header area (non-scrolling) for Scale Name and Color
    local headerFrame = CreateFrame("Frame", nil, container)
    headerFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    headerFrame:SetHeight(70)
    
    -- Scale Name
    local nameLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
    nameLabel:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 0, 0)
    nameLabel:SetText("Scale Name:")
    
    local nameEditBox = CreateFrame("EditBox", nil, headerFrame)
    nameEditBox:SetHeight(22)
    nameEditBox:SetWidth(200)
    nameEditBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetFontObject(_G[FONT_BODY])
    nameEditBox:SetBackdrop(BACKDROP_INPUT)
    nameEditBox:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    nameEditBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    nameEditBox:SetTextInsets(6, 6, 0, 0)
    nameEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    
    -- Color Picker
    local colorLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
    colorLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -SPACING - 4)
    colorLabel:SetText("Color:")
    
    local colorButton = CreateFrame("Button", nil, headerFrame)
    colorButton:SetSize(60, 20)
    colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
    colorButton:SetBackdrop(BACKDROP_INPUT)
    colorButton:SetBackdropColor(1, 1, 1, 1)
    colorButton:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    local preview = colorButton:CreateTexture(nil, "OVERLAY")
    preview:SetAllPoints(colorButton)
    preview:SetTexture(1, 1, 1, 1)
    preview:SetVertexColor(1, 1, 1, 1)
    colorButton.preview = preview
    
    colorButton:SetScript("OnClick", function()
        if not EditingScaleName or not ValuateScales[EditingScaleName] then return end
        
        local scale = ValuateScales[EditingScaleName]
        local color = scale.Color or "FFFFFF"
        local r, g, b = HexToRGB(color)
        
        ColorPickerFrame.func = function()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newColor = RGBToHex(newR, newG, newB)
            scale.Color = newColor
            preview:SetVertexColor(newR, newG, newB, 1)
        end
        
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:Show()
    end)
    
    -- Stat weights header (in header area)
    local statsHeader = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
    statsHeader:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -SPACING - 4)
    statsHeader:SetText("Stat Weights:")
    
    -- Scroll frame for stat weights (below header, reserves space for scrollbar on right)
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -SPACING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 40)
    scrollFrame:SetBackdrop(BACKDROP_PANEL)
    scrollFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
    scrollFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newValue = current - (delta * 30)
        newValue = math.max(0, math.min(maxScroll, newValue))
        self:SetVerticalScroll(newValue)
        if scrollFrame.scrollBar then
            scrollFrame.scrollBar:SetValue(newValue)
        end
    end)
    
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(280)  -- Content width for labels + input boxes + checkbox
    contentFrame:SetHeight(600)  -- Initial height, updated dynamically
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop for visibility
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 0)
    scrollBarBg:SetWidth(SCROLLBAR_WIDTH)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    scrollBarBg:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Scrollbar (inside the backdrop)
    local scrollBar = CreateFrame("Slider", nil, scrollBarBg, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollBarBg, "TOPLEFT", 2, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollBarBg, "BOTTOMRIGHT", -2, 16)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(20)
    scrollBar.scrollFrame = scrollFrame
    scrollBar:SetScript("OnValueChanged", function(self, value)
        if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
            self.scrollFrame:SetVerticalScroll(value)
        end
    end)
    scrollBar:SetValue(0)
    scrollFrame.scrollBar = scrollBar
    
    -- Store references
    ScaleEditorFrame = contentFrame
    ScaleEditorFrame.scrollFrame = scrollFrame
    ScaleEditorFrame.container = container
    ScaleEditorFrame.nameEditBox = nameEditBox
    ScaleEditorFrame.colorButton = colorButton
    ScaleEditorFrame.statsHeader = statsHeader
    
    -- Save/Cancel buttons
    local saveButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    saveButton:SetText("Save")
    saveButton:SetHeight(BUTTON_HEIGHT)
    saveButton:SetWidth(80)
    saveButton:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, PADDING)
    saveButton:SetScript("OnClick", function()
        if not EditingScaleName or not ValuateScales[EditingScaleName] then return end
        
        local scale = ValuateScales[EditingScaleName]
        
        -- Update display name
        scale.DisplayName = nameEditBox:GetText() or EditingScaleName
        
        -- Update stat values and unusable flags
        if not scale.Values then
            scale.Values = {}
        end
        if not scale.Unusable then
            scale.Unusable = {}
        end
        for statName, row in pairs(StatWeightRows) do
            if row and row.editBox then
                -- Check if stat is banned first
                local isBanned = false
                if row.unusableCheckbox then
                    isBanned = (row.unusableCheckbox:GetChecked() == 1) or (row.unusableCheckbox:GetChecked() == true)
                    if isBanned then
                        scale.Unusable[statName] = true
                        scale.Values[statName] = nil  -- Clear value for banned stats
                    else
                        scale.Unusable[statName] = nil
                        -- Only save value if not banned
                        local text = row.editBox:GetText()
                        local value = tonumber(text) or 0
                        if value ~= 0 then
                            scale.Values[statName] = value
                        else
                            scale.Values[statName] = nil
                        end
                    end
                end
            end
        end
        
        -- Refresh scale list (name might have changed)
        UpdateScaleList()
        
        -- Update editor with new name if it changed
        if scale.DisplayName ~= EditingScaleName then
            -- Name changed, need to update the scale key
            ValuateScales[scale.DisplayName] = scale
            ValuateScales[EditingScaleName] = nil
            EditingScaleName = scale.DisplayName
            CurrentSelectedScale = scale.DisplayName
        end
        
        OriginalScaleData = nil
    end)
    
    local cancelButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    cancelButton:SetText("Cancel")
    cancelButton:SetHeight(BUTTON_HEIGHT)
    cancelButton:SetWidth(80)
    cancelButton:SetPoint("LEFT", saveButton, "RIGHT", SPACING, 0)
    cancelButton:SetScript("OnClick", function()
        if OriginalScaleData and EditingScaleName and ValuateScales[EditingScaleName] then
            -- Restore original data
            for k in pairs(ValuateScales[EditingScaleName]) do
                if k ~= "Values" then
                    ValuateScales[EditingScaleName][k] = nil
                end
            end
            for k, v in pairs(OriginalScaleData) do
                if k ~= "Values" then
                    ValuateScales[EditingScaleName][k] = v
                end
            end
            if OriginalScaleData.Values then
                ValuateScales[EditingScaleName].Values = {}
                for k, v in pairs(OriginalScaleData.Values) do
                    ValuateScales[EditingScaleName].Values[k] = v
                end
            end
        end
        OriginalScaleData = nil
        if EditingScaleName and ValuateScales[EditingScaleName] then
            ValuateUI_UpdateScaleEditor(EditingScaleName, ValuateScales[EditingScaleName])
        end
    end)
    
    container:Hide()
    return container
end

-- ========================================
-- Settings Panel
-- ========================================

local function CreateSettingsPanel(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Cache Size
    local cacheLabel = container:CreateFontString(nil, "OVERLAY", FONT_BODY)
    cacheLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    cacheLabel:SetText("Cache Size:")
    
    local cacheEditBox = CreateFrame("EditBox", nil, container)
    cacheEditBox:SetHeight(20)
    cacheEditBox:SetWidth(60)
    cacheEditBox:SetPoint("LEFT", cacheLabel, "RIGHT", 10, 0)
    cacheEditBox:SetAutoFocus(false)
    cacheEditBox:SetFontObject(_G[FONT_BODY])
    cacheEditBox:SetJustifyH("CENTER")
    cacheEditBox:SetBackdrop(BACKDROP_INPUT)
    cacheEditBox:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    cacheEditBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    cacheEditBox:SetTextInsets(4, 4, 0, 0)
    cacheEditBox:SetNumeric(true)
    cacheEditBox:SetNumber(ValuateOptions.cacheSize or 150)
    cacheEditBox:SetScript("OnEnterPressed", function(self)
        local value = self:GetNumber()
        value = math.max(0, math.min(1000, value))
        ValuateOptions.cacheSize = value
        self:SetNumber(value)
        self:ClearFocus()
    end)
    cacheEditBox:SetScript("OnEscapePressed", function(self)
        self:SetNumber(ValuateOptions.cacheSize or 150)
        self:ClearFocus()
    end)
    
    -- Decimal Places
    local decimalLabel = container:CreateFontString(nil, "OVERLAY", FONT_BODY)
    decimalLabel:SetPoint("TOPLEFT", cacheLabel, "BOTTOMLEFT", 0, -SPACING - 4)
    decimalLabel:SetText("Decimal Places:")
    
    local decimalEditBox = CreateFrame("EditBox", nil, container)
    decimalEditBox:SetHeight(20)
    decimalEditBox:SetWidth(40)
    decimalEditBox:SetPoint("LEFT", decimalLabel, "RIGHT", 10, 0)
    decimalEditBox:SetAutoFocus(false)
    decimalEditBox:SetFontObject(_G[FONT_BODY])
    decimalEditBox:SetJustifyH("CENTER")
    decimalEditBox:SetBackdrop(BACKDROP_INPUT)
    decimalEditBox:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    decimalEditBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    decimalEditBox:SetTextInsets(4, 4, 0, 0)
    decimalEditBox:SetNumeric(true)
    decimalEditBox:SetNumber(ValuateOptions.decimalPlaces or 1)
    decimalEditBox:SetScript("OnEnterPressed", function(self)
        local value = self:GetNumber()
        value = math.max(0, math.min(4, value))
        ValuateOptions.decimalPlaces = value
        self:SetNumber(value)
        self:ClearFocus()
    end)
    decimalEditBox:SetScript("OnEscapePressed", function(self)
        self:SetNumber(ValuateOptions.decimalPlaces or 1)
        self:ClearFocus()
    end)
    
    -- Right-Align Values checkbox
    local alignCheckbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    alignCheckbox:SetSize(24, 24)
    alignCheckbox:SetPoint("TOPLEFT", decimalLabel, "BOTTOMLEFT", 0, -SPACING)
    
    local alignLabel = alignCheckbox:CreateFontString(nil, "OVERLAY", FONT_BODY)
    alignLabel:SetPoint("LEFT", alignCheckbox, "RIGHT", 5, 0)
    alignLabel:SetText("Right-Align Scores")
    alignCheckbox:SetChecked(ValuateOptions.rightAlign == true)
    alignCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.rightAlign = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    
    -- Debug Mode
    local debugCheckbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    debugCheckbox:SetSize(24, 24)
    debugCheckbox:SetPoint("TOPLEFT", alignCheckbox, "BOTTOMLEFT", 0, -SPACING)
    
    local debugLabel = debugCheckbox:CreateFontString(nil, "OVERLAY", FONT_BODY)
    debugLabel:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
    debugLabel:SetText("Debug Mode")
    debugCheckbox:SetChecked(ValuateOptions.debug == true)
    debugCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.debug = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    
    return container
end

-- ========================================
-- Public API
-- ========================================

function Valuate:ShowUI()
    if not ValuateUIFrame then
        CreateMainWindow()
        
        -- Create tab system (tabs outside window, panels inside content)
        local tabs = CreateTabSystem(ValuateUIFrame, ValuateUIFrame.contentFrame)
        ValuateUIFrame.tabs = tabs
        
        -- Create scale list
        local scaleList = CreateScaleList(tabs.scalesPanel)
        
        -- Create scale editor
        local scaleEditor = CreateScaleEditor(tabs.scalesPanel)
        
        -- Create settings panel
        local settingsPanel = CreateSettingsPanel(tabs.settingsPanel)
        ValuateUIFrame.settingsPanel = settingsPanel
    end
    
    -- Update dynamic lists
    UpdateScaleList()
    
    ValuateUIFrame:Show()
end

function Valuate:HideUI()
    if ValuateUIFrame then
        ValuateUIFrame:Hide()
    end
end

function Valuate:ToggleUI()
    if ValuateUIFrame and ValuateUIFrame:IsVisible() then
        Valuate:HideUI()
    else
        Valuate:ShowUI()
    end
end

