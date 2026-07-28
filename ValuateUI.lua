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

-- Icon Picker state
local IconPickerFrame = nil
local IconPickerCallback = nil

-- Template Picker state
local TemplatePickerFrame = nil  -- Full picker (all classes)
local ClassSpecificPickerFrame = nil  -- Class-specific picker

-- Forward declaration for overwrite callback


-- ValuateOptions and ValuateScales are per-character SavedVariablesPerCharacter
-- accessed via Valuate:GetOptions() and Valuate:GetScales()


-- ========================================
-- Role Icon Configuration
-- ========================================

-- Role Icon Configuration
local ROLE_ICON_TEXTURE = "Interface\\LFGFRAME\\UI-LFG-ICON-ROLES"
local ROLE_ICON_COORDS = {
    DAMAGER = {72/256, 130/256, 69/256, 127/256},
    HEALER = {72/256, 130/256, 2/256, 60/256},
    TANK = {5/256, 63/256, 69/256, 127/256},
    SUPPORT = {72/256, 130/256, 69/256, 127/256}, -- Same as DAMAGER
}

-- Helper function to get role icon texture and coordinates
local function GetRoleIconAndCoords(role)
    if not role then
        role = "DAMAGER"
    end
    local coords = ROLE_ICON_COORDS[role] or ROLE_ICON_COORDS["DAMAGER"]
    return ROLE_ICON_TEXTURE, coords[1], coords[2], coords[3], coords[4]
end

-- Helper function to get role display name
local function GetRoleName(role)
    local roleNames = {
        TANK = "Tank",
        HEALER = "Healer",
        DAMAGER = "Damage",
        SUPPORT = "Support"
    }
    return roleNames[role] or "Damage"
end


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
-- Icon Picker Frame
-- ========================================

local function CreateIconPickerFrame()
    local frame = CreateFrame("Frame", "ValuateIconPickerFrame", UIParent)
    frame:SetSize(306, 440)  -- Increased height for more icons visible
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    frame:Hide()
    
    -- Make draggable
    frame:SetScript("OnDragStart", function(self)
        ns.IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.IsDraggingFrame = false
    end)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("Select Icon")
    title:SetTextColor(unpack(COLORS.textTitle))
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeBtn:SetBackdrop(BACKDROP_BUTTON)
    closeBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    closeBtn:SetBackdropBorderColor(unpack(COLORS.border))
    
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    closeLabel:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeLabel:SetText("×")
    closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.2, 0.2, 1)
        closeLabel:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Create scrollable content area
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 16)
    scrollFrame:EnableMouseWheel(true)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    
    -- Scrollbar
    local scrollbar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
    scrollbar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
    scrollbar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
    scrollbar:SetMinMaxValues(0, 1)
    scrollbar:SetValueStep(1)
    scrollbar:SetValue(0)
    scrollbar:SetWidth(16)
    
    -- Icon grid (8 columns, scrollable rows with virtual scrolling)
    local ICONS_PER_ROW = 8
    local ICON_SIZE = 28
    local ICON_SPACING = 4
    local ROW_HEIGHT = ICON_SIZE + ICON_SPACING
    
    local totalIcons = #SCALE_ICON_LIST
    local totalRows = math.ceil(totalIcons / ICONS_PER_ROW)
    local contentHeight = totalRows * ROW_HEIGHT + ICON_SPACING
    scrollChild:SetHeight(contentHeight)
    
    -- Virtual scrolling: only create buttons for visible + buffer rows
    local visibleRows = math.ceil(scrollFrame:GetHeight() / ROW_HEIGHT) + 2  -- +2 for buffer
    local maxButtons = visibleRows * ICONS_PER_ROW
    local buttonPool = {}
    
    -- Create a pool of reusable buttons
    for i = 1, maxButtons do
        local iconBtn = CreateFrame("Button", nil, scrollChild)
        iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
        iconBtn:Hide()
        
        -- Border/background for icon
        iconBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        iconBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
        iconBtn:SetBackdropBorderColor(unpack(COLORS.borderDark))
        
        local tex = iconBtn:CreateTexture(nil, "OVERLAY")
        tex:SetPoint("TOPLEFT", iconBtn, "TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", iconBtn, "BOTTOMRIGHT", -2, 2)
        iconBtn.tex = tex
        
        iconBtn:SetScript("OnClick", function(self)
            if IconPickerCallback and self.iconPath then
                IconPickerCallback(self.iconPath)
            end
            frame:Hide()
        end)
        
        iconBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            -- Show tooltip for "None" option
            if self.iconPath == "" and ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                GameTooltip:AddLine("No Icon", 1, 1, 1)
                GameTooltip:AddLine("Clear the icon for this scale.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end
        end)
        iconBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(COLORS.borderDark))
            self:SetBackdropColor(0.1, 0.1, 0.1, 1)
            GameTooltip:Hide()
        end)
        
        buttonPool[i] = iconBtn
    end
    
    -- Function to update visible buttons based on scroll position
    local function UpdateVisibleIcons()
        local scrollOffset = scrollFrame:GetVerticalScroll()
        local firstVisibleRow = math.floor(scrollOffset / ROW_HEIGHT)
        local lastVisibleRow = math.min(totalRows - 1, firstVisibleRow + visibleRows)
        
        local buttonIndex = 1
        for row = firstVisibleRow, lastVisibleRow do
            for col = 0, ICONS_PER_ROW - 1 do
                local iconIndex = row * ICONS_PER_ROW + col + 1
                if iconIndex <= totalIcons then
                    local iconBtn = buttonPool[buttonIndex]
                    if iconBtn then
                        local iconPath = SCALE_ICON_LIST[iconIndex]
                        iconBtn.iconPath = iconPath
                        
                        -- Update texture
                        if iconPath == "" then
                            iconBtn.tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                        else
                            iconBtn.tex:SetTexture(iconPath)
                        end
                        
                        -- Update position
                        iconBtn:ClearAllPoints()
                        iconBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT",
                            col * (ICON_SIZE + ICON_SPACING),
                            -row * ROW_HEIGHT)
                        iconBtn:Show()
                        
                        buttonIndex = buttonIndex + 1
                    end
                end
            end
        end
        
        -- Hide unused buttons
        for i = buttonIndex, maxButtons do
            buttonPool[i]:Hide()
        end
    end
    
    -- Update scrollbar with new callback
    scrollbar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
        UpdateVisibleIcons()
    end)
    
    -- Update mouse wheel to scroll by rows
    local function OnMouseWheel(self, delta)
        local current = scrollbar:GetValue()
        local minVal, maxVal = scrollbar:GetMinMaxValues()
        if delta < 0 and current < maxVal then
            scrollbar:SetValue(math.min(maxVal, current + ROW_HEIGHT * 2))
        elseif delta > 0 and current > minVal then
            scrollbar:SetValue(math.max(minVal, current - ROW_HEIGHT * 2))
        end
    end
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    scrollChild:SetScript("OnMouseWheel", OnMouseWheel)
    
    -- Update scrollbar range and show icons
    scrollFrame:SetScript("OnShow", function()
        local maxScroll = math.max(0, contentHeight - scrollFrame:GetHeight())
        scrollbar:SetMinMaxValues(0, maxScroll)
        scrollbar:SetValue(0)
        if maxScroll == 0 then
            scrollbar:Hide()
        else
            scrollbar:Show()
        end
        UpdateVisibleIcons()
    end)
    
    frame.UpdateVisibleIcons = UpdateVisibleIcons
    
    -- Hide when clicking outside or pressing Escape
    frame:SetScript("OnHide", function()
        IconPickerCallback = nil
    end)
    
    return frame
end

local function ShowIconPicker(callback)
    if not IconPickerFrame then
        IconPickerFrame = CreateIconPickerFrame()
    end
    IconPickerCallback = callback
    IconPickerFrame:Show()
end

-- ========================================
-- Class-Specific Template Picker Frame
-- ========================================

local function CreateClassSpecificPickerFrame()
    local frame = CreateFrame("Frame", "ValuateClassSpecificPickerFrame", UIParent)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    frame:Hide()
    
    -- Make draggable
    frame:SetScript("OnDragStart", function(self)
        ns.IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.IsDraggingFrame = false
    end)
    
    -- ESC key to close
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    
    -- Get player's class
    local _, playerClass = UnitClass("player")
    
    -- Find the class data
    local classData = nil
    for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
        if data.class:upper() == playerClass then
            classData = data
            break
        end
    end
    
    if not classData then
        -- Fallback to showing all classes if player class not found
        classData = CLASS_SPEC_TEMPLATES[1]
    end
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("Select Your Spec")
    title:SetTextColor(unpack(COLORS.textTitle))
    
    -- "Show All Classes" button
    local showAllButton = CreateStyledButton(frame, "Show All Classes", 150, BUTTON_HEIGHT)
    showAllButton:SetPoint("TOP", title, "BOTTOM", 0, -8)
    showAllButton:SetScript("OnClick", function()
        frame:Hide()
        ValuateUI_ShowFullTemplatePicker()
    end)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    
    local closeX = closeButton:CreateFontString(nil, "OVERLAY", FONT_H1)
    closeX:SetPoint("CENTER")
    closeX:SetText("×")
    closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    closeButton:SetScript("OnEnter", function()
        closeX:SetTextColor(1, 1, 1, 1)
    end)
    closeButton:SetScript("OnLeave", function()
        closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    
    -- Content area
    local contentTop = -85  -- Below title and "Show All Classes" button
    
    -- Temporary font string for measuring text widths
    local measureString = frame:CreateFontString(nil, "OVERLAY", FONT_BODY)
    
    -- Calculate column width - need to check description width too
    local maxWidth = 300  -- Minimum width for larger layout
    measureString:SetFont(FONT_BODY, 10)  -- Use smaller font for description
    for _, spec in ipairs(classData.specs) do
        -- Check description width (allowing for icon space)
        if spec.description then
            measureString:SetText(spec.description)
            local descWidth = measureString:GetStringWidth()
            -- Add icon space (36) + gap (8) + description + padding (12)
            local totalWidth = 36 + 8 + descWidth + 12
            if totalWidth > maxWidth then
                maxWidth = totalWidth
            end
        end
    end
    maxWidth = math.min(math.ceil(maxWidth), 400)  -- Cap at 400px
    
    -- Create content frame
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, contentTop)
    contentFrame:SetWidth(maxWidth)
    
    -- Class header
    local classHeader = contentFrame:CreateFontString(nil, "OVERLAY", FONT_H2)
    classHeader:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    classHeader:SetText(classData.class)
    local r, g, b = HexToRGB(classData.color)
    classHeader:SetTextColor(r, g, b, 1)
    
    -- Class description blurb
    local classDesc = nil
    local descHeight = 0
    if classData.description then
        classDesc = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        classDesc:SetPoint("TOPLEFT", classHeader, "BOTTOMLEFT", 0, -4)
        classDesc:SetWidth(maxWidth)  -- Explicitly set width for wrapping
        classDesc:SetJustifyH("LEFT")
        classDesc:SetJustifyV("TOP")
        classDesc:SetWordWrap(true)
        classDesc:SetText(classData.description)
        classDesc:SetTextColor(0.8, 0.8, 0.8, 1)  -- Slightly lighter than spec descriptions
        
        -- Get actual description height after text is set
        -- Need to wait a frame for text to render, so estimate for now
        measureString:SetFont("GameFontNormalSmall", 10)
        measureString:SetWidth(maxWidth)
        measureString:SetWordWrap(true)
        measureString:SetText(classData.description)
        -- Try to get height, fallback to estimated height
        local measuredHeight = measureString:GetStringHeight()
        if measuredHeight and measuredHeight > 0 then
            descHeight = measuredHeight
        else
            -- Estimate: ~12px per line, assume 2-3 lines
            descHeight = 30
        end
    end
    
    local yOffset = -18  -- Header height + spacing
    if classDesc then
        yOffset = yOffset - descHeight - 6  -- Header + description + spacing
    end
    
    -- Function to create a large spec button with description
    local buttonHeight = 80  -- Taller buttons to accommodate 2+ lines of description
    local function CreateSpecButtonWithRole(parent, template, yOffset, buttonWidth)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(buttonWidth, buttonHeight)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        
        -- Larger Spec Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", btn, "LEFT", 8, 0)
        icon:SetPoint("TOP", btn, "TOP", 0, -8)  -- Align to top with padding
        icon:SetTexture(template.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        -- Role Icon (overlaid on bottom-right of spec icon)
        local roleIcon = btn:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(18, 18)
        roleIcon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
        local roleTexture, l, r, t, b = GetRoleIconAndCoords(template.role)
        roleIcon:SetTexture(roleTexture)
        roleIcon:SetTexCoord(l, r, t, b)
        
        -- Name Label (larger font)
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_H2)
        nameLabel:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
        nameLabel:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText(template.name)
        nameLabel:SetTextColor(unpack(COLORS.textTitle))
        
        -- Description Label (smaller, wrapped, with proper height for 2+ lines)
        local descLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
        descLabel:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        descLabel:SetPoint("BOTTOM", btn, "BOTTOM", 0, 8)  -- Give it bottom padding
        descLabel:SetJustifyH("LEFT")
        descLabel:SetJustifyV("TOP")
        descLabel:SetWordWrap(true)
        descLabel:SetText(template.description or "")
        descLabel:SetTextColor(0.7, 0.7, 0.7, 1)
        
        -- Hover effects
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            self:SetBackdropBorderColor(unpack(COLORS.borderLight))
            nameLabel:SetTextColor(1, 1, 1, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonBg))
            self:SetBackdropBorderColor(unpack(COLORS.border))
            nameLabel:SetTextColor(unpack(COLORS.textTitle))
        end)
        
        -- Click handler
        btn.template = template
        btn:SetScript("OnClick", function(self, button)
            local created = ValuateUI_CreateScaleFromTemplate(self.template)
            
            -- Close window on normal click, keep open on shift-click
            if created and not IsShiftKeyDown() then
                frame:Hide()
            end
        end)
        
        return btn
    end
    
    -- Create spec buttons
    for _, spec in ipairs(classData.specs) do
        CreateSpecButtonWithRole(contentFrame, spec, yOffset, maxWidth)
        yOffset = yOffset - (buttonHeight + 4)  -- Button height + spacing
    end
    
    local contentHeight = math.abs(yOffset) + INNER_SPACING
    contentFrame:SetHeight(contentHeight)
    
    -- Calculate and set window size
    local windowWidth = PADDING + maxWidth + PADDING
    local windowHeight = 85 + contentHeight + PADDING  -- Title + show all button + content + padding
    
    -- Cap window height to prevent it from being too tall
    windowHeight = math.min(windowHeight, 600)
    
    frame:SetSize(windowWidth, windowHeight)
    
    -- Clean up temporary measurement string
    measureString:Hide()
    
    return frame
end

-- ========================================
-- Template Picker Frame (Full - All Classes)
-- ========================================

local function CreateTemplatePickerFrame()
    local frame = CreateFrame("Frame", "ValuateTemplatePickerFrame", UIParent)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    frame:Hide()
    
    -- Make draggable
    frame:SetScript("OnDragStart", function(self)
        ns.IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ns.IsDraggingFrame = false
    end)
    
    -- ESC key to close
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("Select Class Spec Template")
    title:SetTextColor(unpack(COLORS.textTitle))
    
    -- Get player's class for the back button
    local _, playerClass = UnitClass("player")
    local playerClassName = nil
    for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
        if data.class:upper() == playerClass then
            playerClassName = data.class
            break
        end
    end
    
    -- "Back to My Class" button (only show if player class is found)
    local backButton = nil
    if playerClassName then
        backButton = CreateStyledButton(frame, "Back to " .. playerClassName, 150, BUTTON_HEIGHT)
        backButton:SetPoint("TOP", title, "BOTTOM", 0, -8)
        backButton:SetScript("OnClick", function()
            frame:Hide()
            ValuateUI_ShowTemplatePicker()
        end)
    end
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    
    local closeX = closeButton:CreateFontString(nil, "OVERLAY", FONT_H1)
    closeX:SetPoint("CENTER")
    closeX:SetText("×")
    closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    closeButton:SetScript("OnEnter", function()
        closeX:SetTextColor(1, 1, 1, 1)
    end)
    closeButton:SetScript("OnLeave", function()
        closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    
    -- Content area (adjust for back button if present)
    local contentTop = -45
    if backButton then
        contentTop = -45 - BUTTON_HEIGHT - 8  -- Title + button + spacing
    end
    
    -- Temporary font string for measuring text widths
    local measureString = frame:CreateFontString(nil, "OVERLAY", FONT_BODY)
    
    -- Create 3 columns
    local column1 = CreateFrame("Frame", nil, frame)
    column1:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, contentTop)
    
    local column2 = CreateFrame("Frame", nil, frame)
    
    local column3 = CreateFrame("Frame", nil, frame)
    
    -- Function to create a spec button with dynamic width and role icon
    local function CreateSpecButton(parent, template, classColor, yOffset, columnWidth)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(columnWidth, BUTTON_HEIGHT)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        
        -- Spec Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
        icon:SetTexture(template.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        -- Role Icon
        local roleIcon = btn:CreateTexture(nil, "ARTWORK")
        roleIcon:SetSize(14, 14)
        roleIcon:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        local roleTexture, l, r, t, b = GetRoleIconAndCoords(template.role)
        roleIcon:SetTexture(roleTexture)
        roleIcon:SetTexCoord(l, r, t, b)
        
        -- Name Label
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        nameLabel:SetPoint("LEFT", roleIcon, "RIGHT", 6, 0)
        nameLabel:SetText(template.name)
        nameLabel:SetTextColor(unpack(COLORS.textBody))
        
        -- Hover effects
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            self:SetBackdropBorderColor(unpack(COLORS.borderLight))
            
            -- Show tooltip with role
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(template.name, 1, 1, 1)
            GameTooltip:AddLine(GetRoleName(template.role), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonBg))
            self:SetBackdropBorderColor(unpack(COLORS.border))
            GameTooltip:Hide()
        end)
        
        -- Click handler (will be set by the picker)
        btn.template = template
        
        return btn
    end
    
    -- Populate columns with class/spec data (3 columns, 3 classes each)
    local column1Classes = {"Warrior", "Paladin", "Hunter"}
    local column2Classes = {"Rogue", "Priest", "Shaman"}
    local column3Classes = {"Mage", "Warlock", "Druid"}
    
    -- First pass: calculate required widths for each column
    local function CalculateColumnWidth(classList)
        local maxWidth = 100  -- Minimum width
        
        for _, className in ipairs(classList) do
            -- Find the class data
            local classData = nil
            for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
                if data.class == className then
                    classData = data
                    break
                end
            end
            
            if classData then
                -- Check each spec name width
                for _, spec in ipairs(classData.specs) do
                    measureString:SetText(spec.name)
                    local textWidth = measureString:GetStringWidth()
                    -- Add icon (16) + gap (4) + roleIcon (14) + gap (6) + text + padding (8)
                    local buttonWidth = 16 + 4 + 14 + 6 + textWidth + 8
                    if buttonWidth > maxWidth then
                        maxWidth = buttonWidth
                    end
                end
            end
        end
        
        return math.ceil(maxWidth)
    end
    
    local width1 = CalculateColumnWidth(column1Classes)
    local width2 = CalculateColumnWidth(column2Classes)
    local width3 = CalculateColumnWidth(column3Classes)
    
    -- Set column widths
    column1:SetWidth(width1)
    column2:SetWidth(width2)
    column3:SetWidth(width3)
    
    -- Position columns
    column2:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + width1 + ELEMENT_SPACING, contentTop)
    column3:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + width1 + ELEMENT_SPACING + width2 + ELEMENT_SPACING, contentTop)
    
    local function PopulateColumn(column, classList, columnWidth)
        local yOffset = 0
        
        for _, className in ipairs(classList) do
            -- Find the class data
            local classData = nil
            for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
                if data.class == className then
                    classData = data
                    break
                end
            end
            
            if classData then
                -- Class header
                local header = column:CreateFontString(nil, "OVERLAY", FONT_H2)
                header:SetPoint("TOPLEFT", column, "TOPLEFT", 0, yOffset)
                header:SetText(classData.class)
                local r, g, b = HexToRGB(classData.color)
                header:SetTextColor(r, g, b, 1)
                
                yOffset = yOffset - 18  -- Header height + spacing
                
                -- Spec buttons
                for _, spec in ipairs(classData.specs) do
                    local btn = CreateSpecButton(column, spec, spec.color, yOffset, columnWidth)
                    yOffset = yOffset - (BUTTON_HEIGHT + 2)  -- Button height + spacing
                end
                
                -- Extra spacing after each class
                yOffset = yOffset - INNER_SPACING
            end
        end
        
        return -yOffset  -- Return total height used
    end
    
    local height1 = PopulateColumn(column1, column1Classes, width1)
    local height2 = PopulateColumn(column2, column2Classes, width2)
    local height3 = PopulateColumn(column3, column3Classes, width3)
    
    -- Set column heights
    local maxHeight = math.max(height1, height2, height3)
    column1:SetHeight(maxHeight)
    column2:SetHeight(maxHeight)
    column3:SetHeight(maxHeight)
    
    -- Calculate and set window size
    local windowWidth = PADDING + width1 + ELEMENT_SPACING + width2 + ELEMENT_SPACING + width3 + PADDING
    local titleAreaHeight = 45  -- Title area
    if backButton then
        titleAreaHeight = 45 + BUTTON_HEIGHT + 8  -- Title + button + spacing
    end
    local windowHeight = titleAreaHeight + maxHeight + PADDING  -- Title area + content + bottom padding
    
    frame:SetSize(windowWidth, windowHeight)
    
    -- Clean up temporary measurement string
    measureString:Hide()
    
    return frame
end

-- Show the full template picker (all classes)
function ValuateUI_ShowFullTemplatePicker()
    if not TemplatePickerFrame then
        TemplatePickerFrame = CreateTemplatePickerFrame()
        
        -- Set up click handlers for all spec buttons after frame is created
        local function SetupButtonHandlers(frame)
            local children = {frame:GetChildren()}
            for _, child in ipairs(children) do
                if child.template then
                    child:SetScript("OnClick", function(self, button)
                        local created = ValuateUI_CreateScaleFromTemplate(self.template)
                        
                        -- Close window on normal click, keep open on shift-click
                        if created and not IsShiftKeyDown() then
                            TemplatePickerFrame:Hide()
                        end
                    end)
                end
                
                -- Recursively check children
                SetupButtonHandlers(child)
            end
        end
        
        SetupButtonHandlers(TemplatePickerFrame)
    end
    
    TemplatePickerFrame:Show()
end

-- Show the template picker (class-specific first)
function ValuateUI_ShowTemplatePicker()
    if not ClassSpecificPickerFrame then
        ClassSpecificPickerFrame = CreateClassSpecificPickerFrame()
    end
    ClassSpecificPickerFrame:Show()
end

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
-- Scale List (Left Panel)
-- ========================================

local ScaleListFrame = nil

local function UpdateScaleList()
    if not ScaleListFrame then return end
    
    -- Clear existing buttons
    for _, btn in pairs(ns.ScaleListButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    ns.ScaleListButtons = {}
    
    -- Get all scales
    local scales = {}
    local scalesData = Valuate:GetScales()
    if scalesData then
        for name, scale in pairs(scalesData) do
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
        
        -- Center the scale buttons horizontally
        if i == 1 then
            btn:SetPoint("TOP", ScaleListFrame, "TOP", 0, 0)
        else
            btn:SetPoint("TOP", lastButton, "BOTTOM", 0, -2)
        end
        lastButton = btn
        
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        
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
        
        -- Color preview button (clickable to change color)
        local colorBtn = CreateFrame("Button", nil, btn)
        colorBtn:SetSize(14, 14)
        colorBtn:SetPoint("LEFT", visCheckbox, "RIGHT", 4, 0)
        
        local colorPreview = colorBtn:CreateTexture(nil, "OVERLAY")
        colorPreview:SetAllPoints(colorBtn)
        local color = scaleData.scale.Color or "FFFFFF"
        local r, g, b = HexToRGB(color)
        colorPreview:SetTexture(1, 1, 1, 1)
        colorPreview:SetVertexColor(r, g, b, 1)
        
        -- Color picker on click
        colorBtn:SetScript("OnClick", function(self)
            local scalesData = Valuate:GetScales()
            local scale = scalesData[scaleData.name]
            if not scale then return end
            
            local currentColor = scale.Color or "FFFFFF"
            local cr, cg, cb = HexToRGB(currentColor)
            
            -- Store reference for callback
            local scaleName = scaleData.name
            
            ColorPickerFrame.previousValues = { cr, cg, cb }
            
            ColorPickerFrame.func = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newColor = RGBToHex(newR, newG, newB)
                local scales = Valuate:GetScales()
                if scales[scaleName] then
                    scales[scaleName].Color = newColor
                end
                colorPreview:SetVertexColor(newR, newG, newB, 1)
                -- Update the scale list to reflect new color
                UpdateScaleList()
                
                -- Reset tooltips to show new color immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            
            ColorPickerFrame.cancelFunc = function()
                local prev = ColorPickerFrame.previousValues
                local scales = Valuate:GetScales()
                if prev and scales[scaleName] then
                    scales[scaleName].Color = RGBToHex(prev[1], prev[2], prev[3])
                end
                UpdateScaleList()
                
                -- Reset tooltips to restore original color
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            
            ColorPickerFrame.opacityFunc = nil
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(cr, cg, cb)
            ColorPickerFrame:Show()
        end)
        
        colorBtn:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Change Color", 1, 1, 1)
            GameTooltip:AddLine("Click to change this scale's display color.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            end
        end)
        colorBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Icon picker button (after color button)
        local iconBtn = CreateFrame("Button", nil, btn)
        iconBtn:SetSize(14, 14)
        iconBtn:SetPoint("LEFT", colorBtn, "RIGHT", 4, 0)
        
        local iconTexture = iconBtn:CreateTexture(nil, "OVERLAY")
        iconTexture:SetAllPoints(iconBtn)
        local currentIcon = scaleData.scale.Icon
        if currentIcon and currentIcon ~= "" then
            iconTexture:SetTexture(currentIcon)
            iconTexture:SetVertexColor(1, 1, 1, 1)
        else
            -- Default placeholder icon (dimmed when no icon set)
            iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            iconTexture:SetVertexColor(0.5, 0.5, 0.5, 0.5)
        end
        
        -- Icon picker on click
        iconBtn:SetScript("OnClick", function(self)
            local scaleName = scaleData.name
            ShowIconPicker(function(selectedIcon)
                if Valuate:GetScales()[scaleName] then
                    Valuate:GetScales()[scaleName].Icon = selectedIcon
                end
                if selectedIcon and selectedIcon ~= "" then
                    iconTexture:SetTexture(selectedIcon)
                    iconTexture:SetVertexColor(1, 1, 1, 1)
                else
                    iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    iconTexture:SetVertexColor(0.5, 0.5, 0.5, 0.5)
                end
            end)
        end)
        
        iconBtn:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Change Icon", 1, 1, 1)
            GameTooltip:AddLine("Click to select an icon for this scale's tooltip display.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            end
        end)
        iconBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Delete button (styled like close button)
        local deleteBtn = CreateFrame("Button", nil, btn)
        deleteBtn:SetSize(16, 16)
        deleteBtn:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        deleteBtn:SetBackdrop(BACKDROP_BUTTON)
        deleteBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
        deleteBtn:SetBackdropBorderColor(unpack(COLORS.border))
        
        local deleteLabel = deleteBtn:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        deleteLabel:SetPoint("CENTER", deleteBtn, "CENTER", 0, 0)
        deleteLabel:SetText("×")
        deleteLabel:SetTextColor(0.7, 0.7, 0.7, 1)
        
        deleteBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.5, 0.2, 0.2, 1)
            deleteLabel:SetTextColor(1, 1, 1, 1)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Delete Scale", 1, 1, 1)
            GameTooltip:AddLine("Click to delete this scale.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Shift-click to skip confirmation.", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
            end
        end)
        deleteBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            deleteLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            GameTooltip:Hide()
        end)
        deleteBtn:SetScript("OnClick", function(self)
            local scaleName = scaleData.name
            
            -- If Shift key is held down, delete immediately without confirmation
            if IsShiftKeyDown() then
                Valuate:GetScales()[scaleName] = nil
                if ns.CurrentSelectedScale == scaleName then
                    ns.CurrentSelectedScale = nil
                    ns.EditingScaleName = nil
                    if ns.ScaleEditorFrame and ns.ScaleEditorFrame.container then
                        ns.ScaleEditorFrame.container:Hide()
                    end
                end
                UpdateScaleList()
            else
                -- Show confirmation dialog (our own frame - see ShowConfirmDialog:
                -- StaticPopup frames are recycled and would taint secure dialogs)
                Valuate:ShowConfirmDialog({
                    text = "Are you sure you want to delete the scale \"" .. (scaleData.scale.DisplayName or scaleName) .. "\"?",
                    acceptText = "Delete",
                    cancelText = "Cancel",
                    onAccept = function()
                        Valuate:GetScales()[scaleName] = nil
                        if ns.CurrentSelectedScale == scaleName then
                            ns.CurrentSelectedScale = nil
                            ns.EditingScaleName = nil
                            if ns.ScaleEditorFrame and ns.ScaleEditorFrame.container then
                                ns.ScaleEditorFrame.container:Hide()
                            end
                        end
                        UpdateScaleList()

                        -- Clear best equipment data for this scale
                        if Valuate.ClearBestEquipmentForScale then
                            Valuate:ClearBestEquipmentForScale(scaleName)
                        end

                        -- Reset all tooltips to reflect the deletion immediately
                        if Valuate.ResetTooltips then
                            Valuate:ResetTooltips()
                        end
                    end,
                })
            end
        end)
        
        -- Scale name
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        nameLabel:SetPoint("LEFT", iconBtn, "RIGHT", 4, 0)
        nameLabel:SetPoint("RIGHT", deleteBtn, "LEFT", -4, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText(scaleData.scale.DisplayName or scaleData.name)
        
        -- Helper to update visual state based on visibility
        local function UpdateVisualState(visible)
            -- Get current scale from cache (may have been updated by color picker or icon picker)
            local currentScale = Valuate:GetScales()[scaleData.name]
            local currentColor = (currentScale and currentScale.Color) or "FFFFFF"
            local cr, cg, cb = HexToRGB(currentColor)
            
            -- Get current icon from scale data
            local currentScaleIcon = currentScale and currentScale.Icon
            local hasIcon = currentScaleIcon and currentScaleIcon ~= ""
            
            if visible then
                nameLabel:SetTextColor(cr, cg, cb, 1)
                colorPreview:SetVertexColor(cr, cg, cb, 1)
                btn:SetBackdropColor(unpack(COLORS.buttonBg))
                -- Update icon visual state
                if hasIcon then
                    iconTexture:SetVertexColor(1, 1, 1, 1)
                else
                    iconTexture:SetVertexColor(0.5, 0.5, 0.5, 0.5)
                end
            else
                nameLabel:SetTextColor(unpack(COLORS.textDim))
                colorPreview:SetVertexColor(unpack(COLORS.textDim))
                btn:SetBackdropColor(unpack(COLORS.disabled))
                iconTexture:SetVertexColor(0.3, 0.3, 0.3, 0.5)
            end
        end
        
        -- Set initial visual state
        UpdateVisualState(isVisible)
        
        -- Visibility checkbox click handler
        visCheckbox:SetScript("OnClick", function(self)
            local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
            local scale = Valuate:GetScales()[scaleData.name]
            if scale then
                scale.Visible = checked
                
                -- Reset all tooltips to reflect the visibility change immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            UpdateVisualState(checked)
        end)
        
        -- Tooltip for visibility checkbox
        visCheckbox:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Show in Tooltip", 1, 1, 1)
            GameTooltip:AddLine("Toggle whether this scale appears in item tooltips.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            end
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
            if ns.CurrentSelectedScale ~= scaleData.name then
                local scale = Valuate:GetScales()[scaleData.name]
                local vis = scale and scale.Visible ~= false
                if vis then
                    self:SetBackdropColor(unpack(COLORS.buttonHover))
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if ns.CurrentSelectedScale ~= scaleData.name then
                local scale = Valuate:GetScales()[scaleData.name]
                local vis = scale and scale.Visible ~= false
                if vis then
                    self:SetBackdropColor(unpack(COLORS.buttonBg))
                else
                    self:SetBackdropColor(unpack(COLORS.disabled))
                end
            end
        end)
        
        -- Click to select
        btn:SetScript("OnClick", function(self)
            -- Deselect previous
            if ns.CurrentSelectedScale and ns.ScaleListButtons[ns.CurrentSelectedScale] then
                local prevBtn = ns.ScaleListButtons[ns.CurrentSelectedScale]
                local prevScale = Valuate:GetScales()[ns.CurrentSelectedScale]
                local prevVis = prevScale and prevScale.Visible ~= false
                if prevVis then
                    prevBtn:SetBackdropColor(unpack(COLORS.buttonBg))
                    prevBtn:SetBackdropBorderColor(unpack(COLORS.border))
                else
                    prevBtn:SetBackdropColor(unpack(COLORS.disabled))
                    prevBtn:SetBackdropBorderColor(unpack(COLORS.borderDark))
                end
            end
            
            -- Select this one
            ns.CurrentSelectedScale = scaleData.name
            self:SetBackdropColor(unpack(COLORS.selected))
            self:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
            
            -- Update editor with current scale data from ValuateScales
            ValuateUI_UpdateScaleEditor(scaleData.name, Valuate:GetScales()[scaleData.name])
        end)
        
        ns.ScaleListButtons[scaleData.name] = btn
        tinsert(ns.ScaleListButtons, btn)
    end
    
    -- Update scroll frame content height (account for spacing between entries)
    if ScaleListFrame then
        local contentHeight = #scales * (ENTRY_HEIGHT + 2)
        ScaleListFrame:SetHeight(math.max(contentHeight, 100))
        
        -- Update scrollbar range and visibility
        local scrollFrame = ScaleListFrame:GetParent()
        if scrollFrame and scrollFrame.scrollBar then
            local scrollBar = scrollFrame.scrollBar
            local scrollBarBg = scrollFrame.scrollBarBg
            local scrollFrameHeight = scrollFrame:GetHeight()
            local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
            
            -- Check if scrolling is needed
            local needsScrollbar = contentHeight > scrollFrameHeight
            
            if needsScrollbar then
                -- Show scrollbar
                scrollBar:Show()
                if scrollBarBg then scrollBarBg:Show() end
                
                -- Position scrollFrame with scrollbar space reserved
                scrollFrame:ClearAllPoints()
                scrollFrame:SetPoint("TOPLEFT", scrollFrame.buttonContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMLEFT", scrollFrame:GetParent(), "BOTTOMLEFT", 0, PADDING)
                scrollFrame:SetPoint("TOPRIGHT", scrollFrame.buttonContainer, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMRIGHT", scrollFrame:GetParent(), "BOTTOMRIGHT", -SCROLLBAR_WIDTH, PADDING)
            else
                -- Hide scrollbar
                scrollBar:Hide()
                if scrollBarBg then scrollBarBg:Hide() end
                
                -- Position scrollFrame to fill full width (no scrollbar space)
                scrollFrame:ClearAllPoints()
                scrollFrame:SetPoint("TOPLEFT", scrollFrame.buttonContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMLEFT", scrollFrame:GetParent(), "BOTTOMLEFT", 0, PADDING)
                scrollFrame:SetPoint("TOPRIGHT", scrollFrame.buttonContainer, "BOTTOMRIGHT", 0, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMRIGHT", scrollFrame:GetParent(), "BOTTOMRIGHT", 0, PADDING)
            end
            
            scrollBar:SetMinMaxValues(0, maxScroll)
            if scrollBar:GetValue() > maxScroll then
                scrollBar:SetValue(maxScroll)
            end
        end
    end
end

-- Setup the template overwrite callback now that we have access to UpdateScaleList
ns.ValuateUI_OnTemplateOverwrite = function(template)
    if not template then return end
    
    local scaleName = template.name
    local scale = Valuate:GetScales()[scaleName]
    
    if scale then
        -- Overwrite existing scale with template data
        scale.DisplayName = scaleName
        scale.Color = template.color or "FFFFFF"  -- Use spec's color
        scale.Icon = template.icon
        scale.Values = {}
        
        -- Copy stat weights from template
        if template.weights then
            for statName, value in pairs(template.weights) do
                scale.Values[statName] = value
            end
        end
        
        -- Clear any unusable flags
        scale.Unusable = {}
        
        -- Refresh list and select the scale
        UpdateScaleList()
        if ns.ScaleListButtons[scaleName] then
            ns.ScaleListButtons[scaleName]:GetScript("OnClick")(ns.ScaleListButtons[scaleName])
        end
        
        -- Reset all tooltips to show the updated scale immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end
end

local function CreateScaleList(parent)
    -- Parent is now the scaleListContainer with proper size/positioning already set
    -- Button container for New Scale and Template buttons
    local buttonContainer = CreateFrame("Frame", nil, parent)
    buttonContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    buttonContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    buttonContainer:SetHeight(BUTTON_HEIGHT)
    
    -- New Blank Scale button (80% width)
    local newButtonWidth = math.floor((200 - ELEMENT_SPACING) * 0.8)
    local newButton = CreateStyledButton(buttonContainer, "New Blank Scale", newButtonWidth, BUTTON_HEIGHT)
    newButton:SetPoint("TOPLEFT", buttonContainer, "TOPLEFT", 0, 0)
    newButton:SetScript("OnClick", function()
        ValuateUI_NewScale()
    end)
    
    -- Template button (20% width) - "+" symbol
    local templateButtonWidth = 200 - newButtonWidth - ELEMENT_SPACING
    local templateButton = CreateStyledButton(buttonContainer, "+", templateButtonWidth, BUTTON_HEIGHT)
    templateButton:SetPoint("TOPRIGHT", buttonContainer, "TOPRIGHT", 0, 0)
    templateButton:SetScript("OnClick", function()
        ValuateUI_ShowTemplatePicker()
    end)
    
    -- Tooltip for template button
    templateButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
        self:SetBackdropBorderColor(unpack(COLORS.borderLight))
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:SetText("Create from Template", 1, 1, 1)
        GameTooltip:AddLine("Select a class/spec template", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
        end
    end)
    templateButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonBg))
        self:SetBackdropBorderColor(unpack(COLORS.border))
        GameTooltip:Hide()
    end)
    
    -- Scroll frame for scale list (initially takes full width, scrollbar space reserved only when needed)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetPoint("TOPLEFT", buttonContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, PADDING)
    scrollFrame:SetPoint("TOPRIGHT", buttonContainer, "BOTTOMRIGHT", 0, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, PADDING)
    scrollFrame:SetBackdrop(BACKDROP_PANEL)
    scrollFrame:SetBackdropColor(unpack(COLORS.panelBg))
    scrollFrame:SetBackdropBorderColor(unpack(COLORS.borderDark))
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
    contentFrame:SetWidth(180)  -- Content width (wider than buttons to allow centering)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop for visibility
    local scrollBarBg = CreateFrame("Frame", nil, parent)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, PADDING)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(unpack(COLORS.windowBg))
    scrollBarBg:SetBackdropBorderColor(unpack(COLORS.borderDark))
    scrollBarBg:Hide()  -- Start hidden, will be shown if needed
    
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
    scrollBar:Hide()  -- Start hidden, will be shown if needed
    scrollFrame.scrollBar = scrollBar
    scrollFrame.scrollBarBg = scrollBarBg
    scrollFrame.buttonContainer = buttonContainer
    
    ScaleListFrame = contentFrame
    
    return parent
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
-- Best Equipment Panel
-- ========================================

local BestEquipmentScrollFrame = nil
local BestEquipmentContentFrame = nil
-- (BestEquipmentScaleFrames removed: the panel now uses a persistent column pool)

local function CreateBestEquipmentPanel(parent)
    -- Safety check
    if not Valuate or not Valuate.GetOptions or not Valuate.GetScales then
        local errorText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        errorText:SetPoint("CENTER", parent, "CENTER", 0, 0)
        errorText:SetText("Best Equipment not available. Please /reload to initialize.")
        errorText:SetTextColor(1, 0.5, 0.5, 1)
        return parent
    end
    
    -- Equipment slot definitions (local to this function)
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
    
    -- Scan button at top
    local scanButton = CreateFrame("Button", nil, parent)
    scanButton:SetHeight(BUTTON_HEIGHT)
    scanButton:SetWidth(200)
    scanButton:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING, -PADDING)
    scanButton:SetBackdrop(BACKDROP_BUTTON)
    scanButton:SetBackdropColor(unpack(COLORS.buttonBg))
    scanButton:SetBackdropBorderColor(unpack(COLORS.border))
    
    local scanLabel = scanButton:CreateFontString(nil, "OVERLAY", FONT_BODY)
    scanLabel:SetPoint("CENTER", scanButton, "CENTER", 0, 0)
    scanLabel:SetText("Scan Best Equipment")
    scanLabel:SetTextColor(unpack(COLORS.textBody))
    
    scanButton:SetScript("OnClick", function()
        Valuate:ScanBestEquipment()
        -- Refresh display after scan
        if Valuate.RefreshBestEquipmentDisplay then
            Valuate:RefreshBestEquipmentDisplay()
        end
    end)
    
    scanButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Scan Best Equipment", 1, 1, 1)
            GameTooltip:AddLine("Scans all equipped items and items in your bags to find the best item for each slot per active scale.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)
    scanButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Create horizontal scrolling frame (wider to fit 3 scales comfortably)
    local scrollBarHeight = 18
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetPoint("TOPLEFT", scanButton, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    -- Extend to use full available width (reduce right padding)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING, PADDING + scrollBarHeight + 6)
    scrollFrame:SetBackdrop(BACKDROP_PANEL)
    scrollFrame:SetBackdropColor(unpack(COLORS.panelBg))
    scrollFrame:SetBackdropBorderColor(unpack(COLORS.border))
    
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    -- Height will be calculated based on actual content
    contentFrame:SetHeight(400)  -- Initial height, will be adjusted
    contentFrame:SetWidth(100)    -- Will be adjusted based on number of scales
    
    scrollFrame:SetScrollChild(contentFrame)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetHorizontalScroll()
        local maxScroll = self:GetHorizontalScrollRange()
        local newScroll = current - (delta * 50)
        newScroll = math.max(0, math.min(maxScroll, newScroll))
        self:SetHorizontalScroll(newScroll)
    end)
    
    -- Horizontal scrollbar at bottom (use full width)
    local horizScrollbar = CreateFrame("Slider", nil, parent)
    horizScrollbar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", PADDING, PADDING)
    horizScrollbar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING, PADDING)
    horizScrollbar:SetHeight(scrollBarHeight)
    horizScrollbar:SetOrientation("HORIZONTAL")
    horizScrollbar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    horizScrollbar:SetMinMaxValues(0, 100)
    horizScrollbar:SetValue(0)
    horizScrollbar:SetValueStep(1)
    horizScrollbar:Hide()  -- Hidden by default, shown when needed
    
    -- Scrollbar background
    local horizScrollbarBg = horizScrollbar:CreateTexture(nil, "BACKGROUND")
    horizScrollbarBg:SetAllPoints(horizScrollbar)
    horizScrollbarBg:SetColorTexture(0.1, 0.1, 0.1, 0.5)
    
    -- Scrollbar arrows (optional, can be hidden)
    local leftArrow = CreateFrame("Button", nil, horizScrollbar)
    leftArrow:SetSize(scrollBarHeight, scrollBarHeight)
    leftArrow:SetPoint("LEFT", horizScrollbar, "LEFT", 0, 0)
    leftArrow:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollLeftButton-Up")
    leftArrow:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollLeftButton-Down")
    leftArrow:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollLeftButton-Highlight")
    leftArrow:SetScript("OnClick", function()
        local current = horizScrollbar:GetValue()
        horizScrollbar:SetValue(math.max(0, current - 10))
    end)
    
    local rightArrow = CreateFrame("Button", nil, horizScrollbar)
    rightArrow:SetSize(scrollBarHeight, scrollBarHeight)
    rightArrow:SetPoint("RIGHT", horizScrollbar, "RIGHT", 0, 0)
    rightArrow:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollRightButton-Up")
    rightArrow:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollRightButton-Down")
    rightArrow:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollRightButton-Highlight")
    rightArrow:SetScript("OnClick", function()
        local current = horizScrollbar:GetValue()
        local max = horizScrollbar:GetMaxValue()
        horizScrollbar:SetValue(math.min(max, current + 10))
    end)
    
    -- Connect scrollbar to scroll frame
    horizScrollbar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetHorizontalScroll(value)
    end)
    
    scrollFrame:SetScript("OnHorizontalScroll", function(self, offset)
        horizScrollbar:SetValue(offset)
    end)
    
    -- Update scrollbar visibility and range
    scrollFrame:SetScript("OnSizeChanged", function(self)
        local range = self:GetHorizontalScrollRange()
        if range > 0 then
            horizScrollbar:Show()
            horizScrollbar:SetMinMaxValues(0, range)
        else
            horizScrollbar:Hide()
        end
    end)
    
    BestEquipmentScrollFrame = scrollFrame
    BestEquipmentContentFrame = contentFrame
    BestEquipmentHorizScrollbar = horizScrollbar
    
    -- Persistent pool of per-column widget bundles, reused across rebuilds so we
    -- never leak frames (WoW never garbage-collects CreateFrame widgets). Each
    -- bundle caches its column frame, header widgets, and an array of per-row
    -- widget bundles. BuildBestEquipColumn creates the static structure once;
    -- UpdateBestEquipmentDisplay only sets content and (re)binds per-slot closures.
    local columnBundles = {}
    local noScalesTextFrame

    -- Layout constants (shared by build + update)
    local BE_SCALE_WIDTH = 310
    local BE_SCALE_SPACING = 8
    local BE_SLOT_SIZE = 22
    local BE_SLOT_SPACING = 0
    local BE_HEADER_HEIGHT = 60
    local BE_VALUE_W = 44    -- item score column ("999.9")
    local BE_COMPARE_W = 50  -- comparison / "Lv 12" / "New"
    -- Weapon-sets + summary block appended below the equipment rows:
    -- title (16) + up to 4 set rows (4*18) + gap (8) + 2 summary lines (2*15).
    local BE_WS_ROW_H = 18
    local BE_WS_BLOCK_H = 16 + (4 * BE_WS_ROW_H) + 8 + (2 * 15) + 6

    -- Build one column's static widget structure (header + one row per equipment
    -- slot). No scale-specific content or closures are baked in here.
    local function BuildBestEquipColumn()
        local col = { rows = {} }

        local scaleFrame = CreateFrame("Frame", nil, contentFrame)
        scaleFrame:SetWidth(BE_SCALE_WIDTH)
        col.frame = scaleFrame

        -- Card: subtle lifted background + crisp side/bottom hairline borders. The top
        -- edge is left for the scale-colored accent bar in the header below.
        local cardBg = scaleFrame:CreateTexture(nil, "BACKGROUND")
        cardBg:SetAllPoints(scaleFrame)
        cardBg:SetColorTexture(0.10, 0.11, 0.14, 0.55)
        local leftEdge = scaleFrame:CreateTexture(nil, "BORDER")
        leftEdge:SetColorTexture(unpack(COLORS.border))
        leftEdge:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 0, 0)
        leftEdge:SetPoint("BOTTOMLEFT", scaleFrame, "BOTTOMLEFT", 0, 0)
        leftEdge:SetWidth(1)
        local rightEdge = scaleFrame:CreateTexture(nil, "BORDER")
        rightEdge:SetColorTexture(unpack(COLORS.border))
        rightEdge:SetPoint("TOPRIGHT", scaleFrame, "TOPRIGHT", 0, 0)
        rightEdge:SetPoint("BOTTOMRIGHT", scaleFrame, "BOTTOMRIGHT", 0, 0)
        rightEdge:SetWidth(1)
        local bottomEdge = scaleFrame:CreateTexture(nil, "BORDER")
        bottomEdge:SetColorTexture(unpack(COLORS.border))
        bottomEdge:SetPoint("BOTTOMLEFT", scaleFrame, "BOTTOMLEFT", 0, 0)
        bottomEdge:SetPoint("BOTTOMRIGHT", scaleFrame, "BOTTOMRIGHT", 0, 0)
        bottomEdge:SetHeight(1)

        -- Header
        local headerContainer = CreateFrame("Frame", nil, scaleFrame)
        headerContainer:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 0, 0)
        headerContainer:SetSize(BE_SCALE_WIDTH, BE_HEADER_HEIGHT)

        local headerBg = headerContainer:CreateTexture(nil, "BACKGROUND")
        headerBg:SetAllPoints(headerContainer)
        headerBg:SetColorTexture(0.05, 0.05, 0.05, 0.5)
        col.headerBg = headerBg

        -- Scale-colored accent bar across the top of the card header.
        local accentBar = headerContainer:CreateTexture(nil, "ARTWORK")
        accentBar:SetPoint("TOPLEFT", headerContainer, "TOPLEFT", 0, 0)
        accentBar:SetPoint("TOPRIGHT", headerContainer, "TOPRIGHT", 0, 0)
        accentBar:SetHeight(3)
        col.accentBar = accentBar

        -- Hairline divider under the header.
        local headerDivider = headerContainer:CreateTexture(nil, "ARTWORK")
        headerDivider:SetPoint("BOTTOMLEFT", headerContainer, "BOTTOMLEFT", 0, 0)
        headerDivider:SetPoint("BOTTOMRIGHT", headerContainer, "BOTTOMRIGHT", 0, 0)
        headerDivider:SetHeight(1)
        headerDivider:SetColorTexture(unpack(COLORS.border))

        local iconSize = 32
        local scaleIcon = headerContainer:CreateTexture(nil, "ARTWORK")
        scaleIcon:SetSize(iconSize, iconSize)
        scaleIcon:SetPoint("LEFT", headerContainer, "LEFT", 8, 0)
        scaleIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        col.scaleIcon = scaleIcon

        local iconBorder = headerContainer:CreateTexture(nil, "OVERLAY")
        iconBorder:SetSize(iconSize + 4, iconSize + 4)
        iconBorder:SetPoint("CENTER", scaleIcon, "CENTER", 0, 0)
        iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
        col.iconBorder = iconBorder

        local headerName = headerContainer:CreateFontString(nil, "OVERLAY", FONT_BODY)
        headerName:SetPoint("LEFT", scaleIcon, "RIGHT", 8, 4)
        headerName:SetWidth(120)
        headerName:SetJustifyH("LEFT")
        headerName:SetTextColor(unpack(COLORS.textHeader))
        col.headerName = headerName

        -- Active-spec indicator: a gold ring around the scale icon plus a caption under
        -- the name. The "active spec" is the scale that quest rewards, auto-roll and the
        -- bag-upgrade popup all use (Valuate:GetPrimaryScale).
        local activeRing = headerContainer:CreateTexture(nil, "OVERLAY")
        activeRing:SetSize(iconSize + 12, iconSize + 12)
        activeRing:SetPoint("CENTER", scaleIcon, "CENTER", 0, 0)
        activeRing:SetTexture("Interface\\Common\\WhiteIconFrame")
        activeRing:SetVertexColor(1, 0.82, 0.1, 1)
        activeRing:Hide()
        col.activeRing = activeRing

        local activeLabel = headerContainer:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        activeLabel:SetPoint("TOPLEFT", headerName, "BOTTOMLEFT", 0, -2)
        activeLabel:SetWidth(130)
        activeLabel:SetJustifyH("LEFT")
        col.activeLabel = activeLabel

        -- Clickable region over the icon + name that makes this scale the active spec.
        -- Only a hover highlight, so the icon and name stay visible underneath.
        local activeButton = CreateFrame("Button", nil, headerContainer)
        activeButton:SetPoint("TOPLEFT", headerContainer, "TOPLEFT", 2, -2)
        activeButton:SetSize(BE_SCALE_WIDTH - 95, BE_HEADER_HEIGHT - 4)
        activeButton:RegisterForClicks("LeftButtonUp")
        local abHL = activeButton:CreateTexture(nil, "HIGHLIGHT")
        abHL:SetAllPoints(activeButton)
        abHL:SetColorTexture(1, 0.82, 0.1, 0.10)
        col.activeButton = activeButton

        -- Three stacked action buttons fill the 60px header: Equip All / Save Set / Clear.
        local clearButton = CreateFrame("Button", nil, headerContainer)
        clearButton:SetHeight(18)
        clearButton:SetWidth(80)
        clearButton:SetPoint("TOPRIGHT", headerContainer, "TOPRIGHT", -5, -40)
        clearButton:SetBackdrop(BACKDROP_BUTTON)
        clearButton:SetBackdropColor(unpack(COLORS.buttonBg))
        clearButton:SetBackdropBorderColor(unpack(COLORS.border))
        -- Automatic mouseover highlight (HIGHLIGHT layer renders only while hovered),
        -- so these keep hover feedback even though their OnEnter shows a tooltip.
        local clearHL = clearButton:CreateTexture(nil, "HIGHLIGHT")
        clearHL:SetAllPoints(clearButton)
        clearHL:SetColorTexture(1, 1, 1, 0.10)

        local clearLabel = clearButton:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        clearLabel:SetPoint("CENTER", clearButton, "CENTER", 0, 0)
        clearLabel:SetText("Clear Items")
        clearLabel:SetTextColor(1, 0.3, 0.3, 1)
        clearButton:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                GameTooltip:AddLine("Clear Best Equipment", 1, 1, 1)
                GameTooltip:AddLine("Clears stored best equipment data for this scale.", 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Locked slots will be preserved.", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end)
        clearButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        col.clearButton = clearButton

        -- "Equip All": one-click equip of this scale's best-in-slot items.
        local equipAllButton = CreateFrame("Button", nil, headerContainer)
        equipAllButton:SetHeight(18)
        equipAllButton:SetWidth(80)
        equipAllButton:SetPoint("TOPRIGHT", headerContainer, "TOPRIGHT", -5, -2)
        equipAllButton:SetBackdrop(BACKDROP_BUTTON)
        equipAllButton:SetBackdropColor(unpack(COLORS.buttonBg))
        equipAllButton:SetBackdropBorderColor(unpack(COLORS.border))
        local equipAllHL = equipAllButton:CreateTexture(nil, "HIGHLIGHT")
        equipAllHL:SetAllPoints(equipAllButton)
        equipAllHL:SetColorTexture(1, 1, 1, 0.10)

        local equipAllLabel = equipAllButton:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        equipAllLabel:SetPoint("CENTER", equipAllButton, "CENTER", 0, 0)
        equipAllLabel:SetText("Equip All")
        equipAllLabel:SetTextColor(0.4, 1, 0.4, 1)
        equipAllButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        col.equipAllButton = equipAllButton

        -- "Save Set": snapshot what you're wearing into a WoW equipment set. Kept
        -- separate from Equip All so equipping never overwrites a saved set for you.
        local saveSetButton = CreateFrame("Button", nil, headerContainer)
        saveSetButton:SetHeight(18)
        saveSetButton:SetWidth(80)
        saveSetButton:SetPoint("TOPRIGHT", headerContainer, "TOPRIGHT", -5, -21)
        saveSetButton:SetBackdrop(BACKDROP_BUTTON)
        saveSetButton:SetBackdropColor(unpack(COLORS.buttonBg))
        saveSetButton:SetBackdropBorderColor(unpack(COLORS.border))
        local saveSetHL = saveSetButton:CreateTexture(nil, "HIGHLIGHT")
        saveSetHL:SetAllPoints(saveSetButton)
        saveSetHL:SetColorTexture(1, 1, 1, 0.10)

        local saveSetLabel = saveSetButton:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        saveSetLabel:SetPoint("CENTER", saveSetButton, "CENTER", 0, 0)
        saveSetLabel:SetText("Save Set")
        saveSetLabel:SetTextColor(0.6, 0.8, 1, 1)
        saveSetButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        col.saveSetButton = saveSetButton

        -- Equipment container + rows
        local equipmentContainer = CreateFrame("Frame", nil, scaleFrame)
        equipmentContainer:SetPoint("TOPLEFT", headerContainer, "BOTTOMLEFT", 0, -5)
        col.equipmentContainer = equipmentContainer

        local yOffset = 0
        for rowIndex = 1, #EquipmentSlots do
            local r = {}

            local slotRow = CreateFrame("Frame", nil, equipmentContainer)
            slotRow:SetSize(BE_SCALE_WIDTH - 10, BE_SLOT_SIZE)
            slotRow:SetPoint("TOPLEFT", equipmentContainer, "TOPLEFT", 3, yOffset)
            r.slotRow = slotRow

            local lockButton = CreateFrame("Button", nil, slotRow)
            lockButton:SetSize(16, 16)
            lockButton:SetPoint("LEFT", slotRow, "LEFT", 0, 0)
            local lockIcon = lockButton:CreateTexture(nil, "ARTWORK")
            lockIcon:SetAllPoints(lockButton)
            lockIcon:SetTexCoord(0, 1, 0, 1)
            lockButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r.lockButton = lockButton
            r.lockIcon = lockIcon

            local slotNameLabel = slotRow:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            slotNameLabel:SetPoint("LEFT", lockButton, "RIGHT", 4, 0)
            slotNameLabel:SetWidth(54)
            slotNameLabel:SetJustifyH("LEFT")
            slotNameLabel:SetTextColor(unpack(COLORS.textDim))
            r.slotNameLabel = slotNameLabel

            local slotFrame = CreateFrame("Button", nil, slotRow)
            slotFrame:SetSize(BE_SLOT_SIZE, BE_SLOT_SIZE)
            slotFrame:SetPoint("LEFT", slotNameLabel, "RIGHT", 1, 0)
            slotFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            r.slotFrame = slotFrame

            local slotBg = slotFrame:CreateTexture(nil, "BACKGROUND")
            slotBg:SetAllPoints(slotFrame)
            slotBg:SetTexture("Interface\\Buttons\\UI-EmptySlot")
            slotBg:SetAlpha(0.3)

            local icon = slotFrame:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", -2, 2)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.icon = icon

            local qualityBorder = slotFrame:CreateTexture(nil, "OVERLAY")
            qualityBorder:SetPoint("TOPLEFT", slotFrame, "TOPLEFT", 0, 0)
            qualityBorder:SetPoint("BOTTOMRIGHT", slotFrame, "BOTTOMRIGHT", 0, 0)
            qualityBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
            r.qualityBorder = qualityBorder

            local infoFrame = CreateFrame("Frame", nil, slotRow)
            infoFrame:SetPoint("LEFT", slotFrame, "RIGHT", 2, 0)
            infoFrame:SetPoint("RIGHT", slotRow, "RIGHT", 0, 0)
            infoFrame:SetHeight(BE_SLOT_SIZE)

            local itemNameText = infoFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            itemNameText:SetPoint("LEFT", infoFrame, "LEFT", 2, 0)
            itemNameText:SetPoint("RIGHT", infoFrame, "RIGHT", -(BE_VALUE_W + BE_COMPARE_W + 4), 0)
            itemNameText:SetJustifyH("LEFT")
            itemNameText:SetTextColor(1, 1, 1, 1)
            itemNameText:SetNonSpaceWrap(false)
            itemNameText:SetWordWrap(false)
            r.itemNameText = itemNameText

            local scoreText = infoFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            scoreText:SetPoint("RIGHT", infoFrame, "RIGHT", -BE_COMPARE_W - 2, 0)
            scoreText:SetWidth(BE_VALUE_W)
            scoreText:SetJustifyH("RIGHT")
            scoreText:SetTextColor(1, 1, 1, 1)
            r.scoreText = scoreText

            local comparisonText = infoFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            comparisonText:SetPoint("RIGHT", infoFrame, "RIGHT", 0, 0)
            comparisonText:SetWidth(BE_COMPARE_W)
            comparisonText:SetJustifyH("RIGHT")
            comparisonText:SetTextColor(0.7, 0.7, 0.7, 1)
            r.comparisonText = comparisonText

            col.rows[rowIndex] = r
            yOffset = yOffset - (BE_SLOT_SIZE + BE_SLOT_SPACING)
        end

        -- ---- Weapon Sets sub-panel (fixed 4 rows) + summary, below the rows ----
        -- Fixed structure so it fits the pool; rows are shown/populated per scale.
        local rowsHeight = #EquipmentSlots * (BE_SLOT_SIZE + BE_SLOT_SPACING)
        local wsTop = BE_HEADER_HEIGHT + 5 + rowsHeight + 10

        local wsTitle = scaleFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        wsTitle:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 8, -wsTop)
        wsTitle:SetText("Weapon Sets")
        wsTitle:SetTextColor(unpack(COLORS.textAccent))
        col.wsTitle = wsTitle

        col.wsRows = {}
        for i = 1, 4 do
            local wr = {}
            local btn = CreateFrame("Button", nil, scaleFrame)
            btn:SetSize(BE_SCALE_WIDTH - 16, BE_WS_ROW_H)
            btn:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 8, -(wsTop + 16 + (i - 1) * BE_WS_ROW_H))
            btn:RegisterForClicks("LeftButtonUp")
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints(btn)
            hl:SetColorTexture(1, 1, 1, 0.08)
            -- Flash overlay: pulses to confirm "this set is now active" after Equip All.
            local flash = btn:CreateTexture(nil, "OVERLAY")
            flash:SetAllPoints(btn)
            flash:SetColorTexture(unpack(COLORS.textAccent))
            flash:SetAlpha(0)
            flash:Hide()
            wr.flash = flash
            local lbl = btn:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            lbl:SetPoint("LEFT", btn, "LEFT", 2, 0)
            lbl:SetJustifyH("LEFT")
            wr.label = lbl
            local tot = btn:CreateFontString(nil, "OVERLAY", FONT_SMALL)
            tot:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
            tot:SetJustifyH("RIGHT")
            wr.total = tot
            wr.btn = btn
            col.wsRows[i] = wr
        end

        local summaryText = scaleFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        summaryText:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 8, -(wsTop + 16 + 4 * BE_WS_ROW_H + 8))
        summaryText:SetJustifyH("LEFT")
        col.summaryText = summaryText

        local upgradesText = scaleFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        upgradesText:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 8, -(wsTop + 16 + 4 * BE_WS_ROW_H + 8 + 15))
        upgradesText:SetJustifyH("LEFT")
        col.upgradesText = upgradesText

        return col
    end

    -- Briefly pulses the weapon-set row matching `key` to confirm it just became the
    -- active set (used after Equip All). Self-contained fade so it doesn't depend on
    -- any timer API; the OnUpdate clears itself when finished.
    local function FlashWeaponSetRow(col, key)
        if not col or not col.wsRows or not key then return end
        for _, wr in ipairs(col.wsRows) do
            if wr.key == key and wr.flash and wr.btn then
                local flash = wr.flash
                local FLASH_ALPHA, FLASH_TIME = 0.55, 0.9
                flash:SetAlpha(FLASH_ALPHA)
                flash:Show()
                -- Eased fade-out: bright immediately, then lingers as it settles.
                -- Driven by the row button since textures have no OnUpdate.
                ValuateTween(wr.btn, FLASH_TIME, function(t)
                    flash:SetAlpha(FLASH_ALPHA * (1 - EaseOutQuad(t)))
                end, function()
                    flash:SetAlpha(0)
                    flash:Hide()
                end)
                return
            end
        end
    end

    -- Function to update the display
    local function UpdateBestEquipmentDisplay()
        if not contentFrame then return end

        -- Skip the (expensive) rebuild while the window is closed. ScanBestEquipment
        -- calls this on every scan; there's no point rebuilding rows nobody can see.
        -- Valuate:ShowUI refreshes the panel when the window opens.
        if not ns.ValuateUIFrame or not ns.ValuateUIFrame:IsShown() then
            return
        end

        local activeScales = Valuate:GetActiveScales()
        local scales = Valuate:GetScales()
        local bestEquipment = Valuate:GetBestEquipment()

        -- Hide all pooled columns up front; needed ones are re-shown below.
        for _, col in ipairs(columnBundles) do col.frame:Hide() end

        if #activeScales == 0 then
            if not noScalesTextFrame then
                noScalesTextFrame = contentFrame:CreateFontString(nil, "OVERLAY", FONT_BODY)
                noScalesTextFrame:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
                noScalesTextFrame:SetText("No active scales. Activate scales in the Scales tab to see best equipment.")
                noScalesTextFrame:SetTextColor(unpack(COLORS.textDim))
            end
            noScalesTextFrame:Show()
            return
        end
        if noScalesTextFrame then noScalesTextFrame:Hide() end

        local numSlots = #EquipmentSlots
        local calculatedHeight = BE_HEADER_HEIGHT + (numSlots * (BE_SLOT_SIZE + BE_SLOT_SPACING)) + 10 + BE_WS_BLOCK_H
        contentFrame:SetWidth((#activeScales * BE_SCALE_WIDTH) + ((#activeScales - 1) * BE_SCALE_SPACING))
        contentFrame:SetHeight(calculatedHeight)

        -- Grow the window to fit the taller content (rows + weapon-sets + summary),
        -- but only while this tab is actually visible so we don't fight the scale
        -- editor's own sizing when a config toggle refreshes us from another tab.
        if ns.ValuateUIFrame and parent:IsShown() then
            -- title + tabs + scan row + content + generous chrome/margin so the
            -- summary lines never clip (a slightly tall window is harmless; clipping isn't).
            local neededHeight = 40 + 30 + 40 + calculatedHeight + PADDING + 60
            ns.ValuateUIFrame:SetHeight(math.max(MIN_WINDOW_HEIGHT, math.min(MAX_WINDOW_HEIGHT, neededHeight)))
        end

        -- Parse each equipped item's SCALED stats once per rebuild, cached by slot
        -- (the equipped item depends only on the slot, not the scale).
        local equippedStatsCache = {}
        local function GetEquippedStatsForSlot(slotId)
            local cached = equippedStatsCache[slotId]
            if cached ~= nil then
                return cached or nil
            end
            local link = GetInventoryItemLink("player", slotId)
            if not link then
                equippedStatsCache[slotId] = false
                return nil
            end
            local tooltip = Valuate:GetPrivateTooltip()
            tooltip:ClearLines()
            tooltip:SetInventoryItem("player", slotId)
            local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
            equippedStatsCache[slotId] = stats or false
            return stats
        end

        local decimals = Valuate:GetOptions().decimalPlaces or 1
        local formatStr = "%." .. decimals .. "f"

        -- Resolve the active spec once (honours the fallback when none is set).
        local _, primaryScaleName = Valuate:GetPrimaryScale()

        for i, scaleName in ipairs(activeScales) do
            local scale = scales[scaleName]
            if scale then
                local col = columnBundles[i]
                if not col then
                    col = BuildBestEquipColumn()
                    columnBundles[i] = col
                end

                col.frame:SetHeight(calculatedHeight)
                col.frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", (i - 1) * (BE_SCALE_WIDTH + BE_SCALE_SPACING), 0)
                col.equipmentContainer:SetSize(BE_SCALE_WIDTH, calculatedHeight - BE_HEADER_HEIGHT - 5)
                col.frame:Show()

                local color = scale.Color or "FFFFFF"
                local displayName = scale.DisplayName or scaleName
                local iconPath = scale.Icon or "Interface\\Icons\\INV_Misc_QuestionMark"

                col.scaleIcon:SetTexture(iconPath)
                local cr, cg, cb = HexToRGB(color)
                col.iconBorder:SetVertexColor(cr, cg, cb, 1)
                if col.accentBar then col.accentBar:SetColorTexture(cr, cg, cb, 0.95) end
                if col.headerBg then col.headerBg:SetColorTexture(cr, cg, cb, 0.12) end
                col.headerName:SetText("|cFF" .. color .. displayName .. "|r")

                -- Active-spec state. Compare against the RESOLVED primary scale so the
                -- indicator is right even when characterWindowScale is unset (in which
                -- case GetPrimaryScale falls back to the first active scale).
                local isActiveSpec = (scaleName == primaryScaleName)
                if col.activeRing then
                    if isActiveSpec then col.activeRing:Show() else col.activeRing:Hide() end
                end
                if col.activeLabel then
                    col.activeLabel:SetText(isActiveSpec
                        and "|cFFFFD100* ACTIVE SPEC|r"
                        or "|cFF707070click to activate|r")
                end
                if col.activeButton then
                    col.activeButton:SetScript("OnClick", function()
                        if isActiveSpec then return end
                        Valuate:GetOptions().characterWindowScale = scaleName
                        -- Keep every consumer in sync: character window, its dropdown,
                        -- tooltips, and this panel's indicators.
                        if Valuate.RefreshCharacterWindowDisplay then Valuate:RefreshCharacterWindowDisplay() end
                        if Valuate.RefreshCharacterWindowScaleDropdown then Valuate:RefreshCharacterWindowScaleDropdown() end
                        if Valuate.ResetTooltips then Valuate:ResetTooltips() end
                        if Valuate.RefreshBestEquipmentDisplay then Valuate:RefreshBestEquipmentDisplay() end
                        print("|cFF00FF00Valuate|r: Active spec set to |cFF" .. color .. displayName .. "|r.")
                    end)
                    col.activeButton:SetScript("OnEnter", function(self)
                        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                            GameTooltip:AddLine(displayName, 1, 1, 1)
                            if isActiveSpec then
                                GameTooltip:AddLine("This is your ACTIVE SPEC.", 1, 0.82, 0.1, true)
                            else
                                GameTooltip:AddLine("Click to make this your active spec.", 0.8, 0.8, 0.8, true)
                            end
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine("The active spec is the scale used for quest-reward picks, loot rolls, the bag-upgrade prompt, and the character-window score.", 0.7, 0.7, 0.7, true)
                            GameTooltip:Show()
                        end
                    end)
                    col.activeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end
                col.clearButton:SetScript("OnClick", function()
                    Valuate:ClearBestEquipmentForScale(scaleName)
                end)
                col.equipAllButton:SetScript("OnClick", function()
                    if Valuate.EquipBestSet then Valuate:EquipBestSet(scaleName) end
                    -- Pulse the set that was actually equipped. Read the RESOLVED key
                    -- from the scan data, not scale.ActiveWeaponSet - on an "auto" scale
                    -- that field is literally "auto" and would match no row.
                    local be = Valuate:GetBestEquipment()[scaleName]
                    FlashWeaponSetRow(col, be and be.activeWeaponSet)
                end)
                col.equipAllButton:SetScript("OnEnter", function(self)
                    if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                        GameTooltip:AddLine("Equip All", 1, 1, 1)
                        GameTooltip:AddLine("Equip every best-in-slot item for this scale at once.", 0.8, 0.8, 0.8, true)
                        GameTooltip:AddLine("Skips locked slots and anything already worn.", 0.7, 0.7, 0.7, true)
                        GameTooltip:AddLine("Marks this weapon set as active. Does not touch your saved equipment sets.", 0.7, 0.7, 0.7, true)
                        GameTooltip:Show()
                    end
                end)
                col.saveSetButton:SetScript("OnClick", function()
                    if Valuate.SaveEquipmentSetForScale then
                        Valuate:SaveEquipmentSetForScale(scaleName)
                    end
                end)
                col.saveSetButton:SetScript("OnEnter", function(self)
                    if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                        GameTooltip:AddLine("Save Set", 1, 1, 1)
                        GameTooltip:AddLine("Save the gear you are CURRENTLY WEARING as a WoW equipment set for this scale, usable from the character panel or an /equipset macro.", 0.8, 0.8, 0.8, true)
                        local short = Valuate.GetActiveWeaponSetShort and Valuate:GetActiveWeaponSetShort(scaleName)
                        local setName = (scale.DisplayName or scaleName) .. (short and (" (" .. short .. ")") or "")
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Set name: " .. setName, 0.6, 0.8, 1, true)
                        GameTooltip:AddLine("Overwrites an existing set with that name. Tip: Equip All first so you're wearing the best gear.", 0.7, 0.7, 0.7, true)
                        GameTooltip:Show()
                    end
                end)

                -- Running totals for the summary block (accumulated in the row loop).
                local equippedTotal, bestTotal, upgradeTotal = 0, 0, 0

                for rowIndex, slotInfo in ipairs(EquipmentSlots) do
                    local slotId = slotInfo.slotId
                    local r = col.rows[rowIndex]
                    local icon, qualityBorder = r.icon, r.qualityBorder
                    local itemNameText, scoreText, comparisonText = r.itemNameText, r.scoreText, r.comparisonText
                    local slotFrame, lockButton, lockIcon = r.slotFrame, r.lockButton, r.lockIcon

                    r.slotNameLabel:SetText(slotInfo.name)

                    -- Reset mutable icon state (pooled widgets keep their last look;
                    -- the "future" branch dims/desaturates the icon, so undo that here).
                    if icon.SetDesaturated then icon:SetDesaturated(false) end
                    icon:SetAlpha(1)

                    local bestItem = bestEquipment[scaleName] and bestEquipment[scaleName][slotId]
                    local equippedStats = GetEquippedStatsForSlot(slotId)
                    local equippedScore = equippedStats and Valuate:CalculateItemScore(equippedStats, scale) or nil

                    -- Summary totals: best-achievable per slot is max(best, equipped);
                    -- upgrades are the positive best-over-equipped deltas.
                    local eqSlotScore = equippedScore or 0
                    local bestSlotScore = (bestItem and bestItem.score) or 0
                    equippedTotal = equippedTotal + eqSlotScore
                    bestTotal = bestTotal + math.max(bestSlotScore, eqSlotScore)
                    if bestSlotScore > eqSlotScore then
                        upgradeTotal = upgradeTotal + (bestSlotScore - eqSlotScore)
                    end

                    -- Lock state + closures (rebound each update for this scaleName/slotId)
                    local isLocked = bestEquipment[scaleName] and bestEquipment[scaleName].locks and bestEquipment[scaleName].locks[slotId]
                    if isLocked then
                        lockIcon:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
                        lockIcon:SetAlpha(1.0)
                    else
                        lockIcon:SetTexture("Interface\\Buttons\\LockButton-Border")
                        lockIcon:SetAlpha(0.4)
                    end
                    lockButton:SetScript("OnClick", function(self)
                        if not bestEquipment[scaleName] then bestEquipment[scaleName] = {} end
                        if not bestEquipment[scaleName].locks then
                            bestEquipment[scaleName].locks = {}
                        end
                        local newLockState = not bestEquipment[scaleName].locks[slotId]
                        bestEquipment[scaleName].locks[slotId] = newLockState or nil
                        if newLockState then
                            lockIcon:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
                            lockIcon:SetAlpha(1.0)
                        else
                            lockIcon:SetTexture("Interface\\Buttons\\LockButton-Border")
                            lockIcon:SetAlpha(0.4)
                        end
                        if GameTooltip:IsOwned(self) then
                            GameTooltip:Hide()
                            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                                local locked = bestEquipment[scaleName] and bestEquipment[scaleName].locks and bestEquipment[scaleName].locks[slotId]
                                if locked then
                                    GameTooltip:AddLine("Slot Locked", 1, 1, 1)
                                    GameTooltip:AddLine("This slot won't be updated during scans.", 0.8, 0.8, 0.8)
                                    GameTooltip:AddLine("Click to unlock.", 0.7, 0.7, 0.7)
                                else
                                    GameTooltip:AddLine("Slot Unlocked", 1, 1, 1)
                                    GameTooltip:AddLine("This slot will be updated during scans.", 0.8, 0.8, 0.8)
                                    GameTooltip:AddLine("Click to lock.", 0.7, 0.7, 0.7)
                                end
                                GameTooltip:Show()
                            end
                        end
                    end)
                    lockButton:SetScript("OnEnter", function(self)
                        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                            local locked = bestEquipment[scaleName] and bestEquipment[scaleName].locks and bestEquipment[scaleName].locks[slotId]
                            if locked then
                                GameTooltip:AddLine("Slot Locked", 1, 1, 1)
                                GameTooltip:AddLine("This slot won't be updated during scans.", 0.8, 0.8, 0.8)
                                GameTooltip:AddLine("Click to unlock.", 0.7, 0.7, 0.7)
                            else
                                GameTooltip:AddLine("Slot Unlocked", 1, 1, 1)
                                GameTooltip:AddLine("This slot will be updated during scans.", 0.8, 0.8, 0.8)
                                GameTooltip:AddLine("Click to lock.", 0.7, 0.7, 0.7)
                            end
                            GameTooltip:Show()
                        end
                    end)

                    if bestItem and bestItem.itemLink then
                        local itemTexture = bestItem.itemTexture
                        if not itemTexture then
                            local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(bestItem.itemLink)
                            itemTexture = tex
                        end
                        if itemTexture then
                            icon:SetTexture(itemTexture)
                            icon:Show()
                        else
                            icon:Hide()
                        end

                        local itemQuality = bestItem.itemQuality or 0
                        if itemQuality and itemQuality > 0 then
                            local r2, g2, b2 = GetItemQualityColor(itemQuality)
                            qualityBorder:SetVertexColor(r2, g2, b2, 1)
                            qualityBorder:Show()
                        else
                            qualityBorder:Hide()
                        end

                        local scoreValue = bestItem.score or 0
                        scoreText:SetText("|cFF" .. color .. string.format(formatStr, scoreValue) .. "|r")
                        -- Remember the final value so the tab-open reveal can count up to
                        -- it. Cleared on rows that have no score (below), so a pooled row
                        -- can't animate a stale number.
                        r.animScore, r.animColor = scoreValue, color

                        local itemName = bestItem.itemName or "Unknown"
                        if itemQuality and itemQuality > 0 then
                            local r2, g2, b2 = GetItemQualityColor(itemQuality)
                            local hexColor = string.format("%02x%02x%02x", r2 * 255, g2 * 255, b2 * 255)
                            itemNameText:SetText("|cFF" .. hexColor .. itemName .. "|r")
                        else
                            itemNameText:SetText(itemName)
                        end

                        if equippedScore and equippedScore > 0 then
                            local diff = scoreValue - equippedScore
                            if math.abs(diff) < 0.01 then diff = 0 end
                            local diffColor = "FFFFFF"
                            local diffSign = ""
                            if diff > 0.01 then
                                diffColor = "00FF00"
                                diffSign = "+"
                            elseif diff < -0.01 then
                                diffColor = "FF0000"
                            else
                                diffColor = "FFFF00"
                                diff = 0
                            end
                            comparisonText:SetText("|cFF" .. diffColor .. diffSign .. string.format(formatStr, diff) .. "|r")
                        elseif equippedScore == 0 or not equippedScore then
                            comparisonText:SetText("|cFF888888--|r")
                        else
                            comparisonText:SetText("|cFF00FF00New|r")
                        end

                        slotFrame:SetScript("OnEnter", function(self)
                            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                                GameTooltip:SetHyperlink(bestItem.itemLink)
                                local options = Valuate:GetOptions()
                                if options.showBestFor ~= false then
                                    local bestForLine = Valuate:BuildBestForLine(bestItem.itemLink)
                                    if bestForLine then
                                        GameTooltip:AddLine(" ")
                                        GameTooltip:AddLine(bestForLine, 1, 1, 1)
                                    end
                                end
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("Score for |cFF" .. color .. displayName .. "|r: |cFF" .. color .. string.format(formatStr, scoreValue) .. "|r", 1, 1, 1)
                                if equippedScore and equippedScore > 0 then
                                    local diff = scoreValue - equippedScore
                                    if math.abs(diff) < 0.01 then diff = 0 end
                                    local diffColor = "FFFFFF"
                                    local diffSign = ""
                                    if diff > 0.01 then
                                        diffColor = "00FF00"
                                        diffSign = "+"
                                    elseif diff < -0.01 then
                                        diffColor = "FF0000"
                                    else
                                        diffColor = "FFFF00"
                                        diff = 0
                                    end
                                    GameTooltip:AddLine("vs Equipped: |cFF" .. diffColor .. diffSign .. string.format(formatStr, diff) .. "|r", 0.8, 0.8, 0.8)
                                end
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("|cFF888888Right-click to equip|r", 0.6, 0.6, 0.6)
                                GameTooltip:Show()
                            end
                        end)
                        slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        slotFrame:SetScript("OnClick", function(self, button)
                            if button == "RightButton" and bestItem and bestItem.itemLink then
                                -- Mark this as a Valuate-initiated equip so a BoE's bind
                                -- prompt is auto-confirmed (manual equips still prompt).
                                if Valuate.MarkEquipIntent then Valuate:MarkEquipIntent(8) end
                                EquipItemByName(bestItem.itemLink, slotId)
                                local slotName = slotInfo.name or "slot"
                                print("|cFF" .. color .. "Valuate|r: Equipping " .. bestItem.itemLink .. " to " .. slotName)
                            end
                        end)
                    else
                        -- No currently-equippable best. Show a not-yet-usable "future"
                        -- upgrade dimmed if one exists; otherwise mark the slot empty.
                        local futureItem = bestEquipment[scaleName] and bestEquipment[scaleName].future
                            and bestEquipment[scaleName].future[slotId]

                        if futureItem and futureItem.itemLink then
                            local itemTexture = futureItem.itemTexture
                            if not itemTexture then
                                local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(futureItem.itemLink)
                                itemTexture = tex
                            end
                            if itemTexture then
                                icon:SetTexture(itemTexture)
                                if icon.SetDesaturated then icon:SetDesaturated(true) end
                                icon:SetAlpha(0.5)
                                icon:Show()
                            else
                                icon:Hide()
                            end

                            local itemQuality = futureItem.itemQuality or 0
                            if itemQuality > 0 then
                                local r2, g2, b2 = GetItemQualityColor(itemQuality)
                                qualityBorder:SetVertexColor(r2, g2, b2, 0.5)
                                qualityBorder:Show()
                            else
                                qualityBorder:Hide()
                            end

                            itemNameText:SetText("|cFF888888" .. (futureItem.itemName or "Unknown") .. "|r")
                            scoreText:SetText("|cFF888888" .. string.format(formatStr, futureItem.score or 0) .. "|r")
                            r.animScore, r.animColor = nil, nil  -- dimmed future row: no count-up
                            if futureItem.reqLevel and futureItem.reqLevel > 0 then
                                comparisonText:SetText("|cFF808080Lv " .. futureItem.reqLevel .. "|r")
                            else
                                comparisonText:SetText("|cFF808080Locked|r")
                            end

                            slotFrame:SetScript("OnEnter", function(self)
                                if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                                    GameTooltip:SetHyperlink(futureItem.itemLink)
                                    GameTooltip:AddLine(" ")
                                    GameTooltip:AddLine("|cFFFFCC00Future upgrade|r - not equippable yet", 1, 0.8, 0)
                                    if futureItem.reqLevel and futureItem.reqLevel > 0 then
                                        GameTooltip:AddLine("Requires level " .. futureItem.reqLevel .. ".", 0.8, 0.8, 0.8)
                                    else
                                        GameTooltip:AddLine("You can't use this yet (unlearned proficiency or other requirement).", 0.8, 0.8, 0.8, true)
                                    end
                                    GameTooltip:AddLine("Kept for reference - Valuate won't auto-equip it.", 0.6, 0.6, 0.6)
                                    GameTooltip:Show()
                                end
                            end)
                            slotFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
                            slotFrame:SetScript("OnClick", nil)
                        else
                            icon:Hide()
                            qualityBorder:Hide()
                            itemNameText:SetText("|cFF888888No item found|r")
                            scoreText:SetText("--")
                            comparisonText:SetText("")
                            r.animScore, r.animColor = nil, nil  -- empty slot: no count-up
                            slotFrame:SetScript("OnEnter", nil)
                            slotFrame:SetScript("OnLeave", nil)
                            slotFrame:SetScript("OnClick", nil)
                        end
                    end
                end

                -- Populate the weapon-sets sub-panel + summary for this scale.
                local be = bestEquipment[scaleName]
                local wsData = be and be.weaponSets
                local activeKey = be and be.activeWeaponSet
                local wsIndex = 0
                for _, def in ipairs(Valuate:GetWeaponSetDefinitions()) do
                    local set = wsData and wsData[def.key]
                    if set then
                        wsIndex = wsIndex + 1
                        local wr = col.wsRows[wsIndex]
                        if wr then
                            wr.key = def.key  -- lets FlashWeaponSetRow find this row
                            local isActive = (def.key == activeKey)
                            local labelColor = isActive and "FFFFD700" or "FFBBBBBB"
                            local marker = isActive and "|cFFFFD700>|r " or ""
                            wr.label:SetText(marker .. "|c" .. labelColor .. def.label .. "|r")
                            wr.total:SetText("|cFF" .. color .. string.format(formatStr, set.total or 0) .. "|r")
                            wr.btn:Show()
                            wr.btn:SetScript("OnClick", function()
                                scale.ActiveWeaponSet = def.key
                                Valuate:ScanBestEquipment()
                                if Valuate.RefreshBestEquipmentDisplay then Valuate:RefreshBestEquipmentDisplay() end
                                if Valuate.ResetTooltips then Valuate:ResetTooltips() end
                            end)
                            wr.btn:SetScript("OnEnter", function(self)
                                if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                                    GameTooltip:AddLine(def.label, 1, 1, 1)
                                    if set.mh and set.mh.itemName then GameTooltip:AddLine("Main: " .. set.mh.itemName, 0.8, 0.8, 0.8) end
                                    if set.oh and set.oh.itemName then GameTooltip:AddLine("Off: " .. set.oh.itemName, 0.8, 0.8, 0.8) end
                                    GameTooltip:AddLine("Set total: " .. string.format(formatStr, set.total or 0), 0.7, 0.9, 0.7)
                                    GameTooltip:AddLine(isActive and "Currently active" or "Click to make this the active set", 0.6, 0.6, 0.6)
                                    GameTooltip:Show()
                                end
                            end)
                            wr.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        end
                    end
                end
                for j = wsIndex + 1, 4 do
                    if col.wsRows[j] then
                        col.wsRows[j].btn:Hide()
                        col.wsRows[j].key = nil  -- don't let a stale key match the flash
                    end
                end
                col.wsTitle:SetText(wsIndex == 0 and "Weapon Sets |cFF808080(none enabled / owned)|r" or "Weapon Sets")

                col.summaryText:SetText("Equipped: |cFF" .. color .. string.format(formatStr, equippedTotal)
                    .. "|r   Best: |cFF" .. color .. string.format(formatStr, bestTotal) .. "|r")
                if upgradeTotal > 0.01 then
                    col.upgradesText:SetText("|cFF00FF00Upgrades in bags: +" .. string.format(formatStr, upgradeTotal) .. "|r")
                else
                    col.upgradesText:SetText("|cFF888888No upgrades in bags|r")
                end
            end
        end

        -- Hide any surplus columns left over from a previous larger scale count.
        local extra = #activeScales + 1
        while columnBundles[extra] do
            columnBundles[extra].frame:Hide()
            extra = extra + 1
        end
    end
    
    -- Store update function for external access
    Valuate.RefreshBestEquipmentDisplay = UpdateBestEquipmentDisplay

    -- Staggered reveal of the visible scale columns. Called on tab-open only (not on
    -- every background refresh), so the effect stays a flourish rather than a nag:
    -- each column rises + fades in slightly after the previous one.
    Valuate.RevealBestEquipmentColumns = function()
        local decimals = Valuate:GetOptions().decimalPlaces or 1
        local fmt = "%." .. decimals .. "f"
        for i, col in ipairs(columnBundles) do
            if col.frame and col.frame:IsShown() then
                local f = col.frame
                local colDelay = (i - 1) * 0.06
                f:SetAlpha(0)
                Anim.tween({
                    duration = 0.34, delay = colDelay, ease = "outCubic",
                    onUpdate = function(e) f:SetAlpha(e) end,
                })

                -- Score count-up: each row's number rolls from 0 to its value, staggered
                -- down the column so the numbers cascade. Only rows with a real score
                -- animate (future/empty rows cleared animScore), and the tween always
                -- lands exactly on the final value.
                for rowIndex, r in ipairs(col.rows) do
                    if r.animScore and r.animScore > 0 and r.scoreText then
                        local target, hex, label = r.animScore, r.animColor or "FFFFFF", r.scoreText
                        local function render(v)
                            label:SetText("|cFF" .. hex .. string.format(fmt, v) .. "|r")
                        end
                        render(0)
                        Anim.tween({
                            duration = 0.55, ease = "outCubic",
                            delay = colDelay + (rowIndex - 1) * 0.025,
                            onUpdate = function(e) render(target * e) end,
                            onDone = function() render(target) end,
                        })
                    end
                end
            end
        end
    end

    -- Initial update
    UpdateBestEquipmentDisplay()

    return parent
end

-- Settings Panel
-- ========================================

-- Structural safeguard against overlapping controls. The whole panel lays out by
-- anchoring each control's TOPLEFT to the previous control's BOTTOMLEFT; the failure
-- mode (which shipped once) is anchoring TWO controls to the SAME sibling, so they
-- render on top of each other. This scans a column's child frames and font-string
-- regions and warns loudly if any two share an anchor - so the mistake surfaces the
-- instant you open Settings instead of silently overlapping. Read-only.
local function CheckColumnAnchors(colFrame, colName)
    if not colFrame or not colFrame.GetChildren then return 0 end
    local elements = {}
    for _, k in ipairs({ colFrame:GetChildren() }) do elements[#elements + 1] = k end
    for _, r in ipairs({ colFrame:GetRegions() }) do elements[#elements + 1] = r end

    local seen, collisions = {}, 0
    for _, el in ipairs(elements) do
        if el.GetNumPoints and el:GetNumPoints() > 0 then
            local point, relTo, relPoint = el:GetPoint(1)
            -- Only the vertical-stack anchor matters; a shared (relativeTo, relativePoint)
            -- means two controls occupy the same slot.
            if relTo and relTo ~= colFrame and point == "TOPLEFT" then
                local key = tostring(relTo) .. "|" .. tostring(relPoint)
                if seen[key] then
                    collisions = collisions + 1
                    print("|cFFFF0000[Valuate]|r Settings layout bug: two controls in " ..
                        tostring(colName) .. " share an anchor and will OVERLAP. Anchor each " ..
                        "control below the previous one, not to a shared sibling.")
                else
                    seen[key] = true
                end
            end
        end
    end
    return collisions
end

local function CreateSettingsPanel(parent)
    
    -- Safety check: ensure SavedVariables are initialized
    if not Valuate or not Valuate.GetOptions or not Valuate.GetScales then
        
        local errorText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        errorText:SetPoint("CENTER", parent, "CENTER", 0, 0)
        errorText:SetText("Settings not available. Please /reload to initialize.")
        errorText:SetTextColor(1, 0.5, 0.5, 1)
        return parent
    end
    
    -- Calculate column width for 3 columns
    -- Content area is WINDOW_WIDTH - (2 * PADDING) = 950 - 24 = 926
    local availableWidth = WINDOW_WIDTH - (2 * PADDING)
    local settingsColumnWidth = (availableWidth - (2 * COLUMN_GAP)) / 3
    
    
    -- Create 3 column frames directly in parent
    local columnFrames = {}
    local columnHeights = {0, 0, 0}
    
    for i = 1, 3 do
        local colFrame = CreateFrame("Frame", nil, parent)
        colFrame:SetWidth(settingsColumnWidth)
        colFrame:SetHeight(500)  -- FIX: Set explicit height
        colFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING + (i - 1) * (settingsColumnWidth + COLUMN_GAP), -PADDING)
        columnFrames[i] = colFrame
        columnHeights[i] = 0
    end
    
    -- Helper function to add element to column with spacing
    local function AddToColumn(colIndex, element, height)
        if colIndex < 1 or colIndex > 3 then return end
        local colFrame = columnFrames[colIndex]
        local yOffset = -columnHeights[colIndex]
        element:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, yOffset)
        columnHeights[colIndex] = columnHeights[colIndex] + height + ELEMENT_SPACING
    end
    
    -- ========================================
    -- COLUMN 1: Display & Formatting
    -- ========================================
    local col1 = columnFrames[1]
    
    -- Display & Formatting Section Header
    local displayHeader = col1:CreateFontString(nil, "OVERLAY", FONT_H1)
    displayHeader:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, 0)
    displayHeader:SetText("Display & Formatting")
    displayHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[1] = HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Decimal Places (Column 1)
    local decimalLabel = col1:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    decimalLabel:SetPoint("TOPLEFT", displayHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    decimalLabel:SetText("Decimal Places:")
    
    columnHeights[1] = columnHeights[1] + 14 + ELEMENT_SPACING
    
    local decimalEditBox = CreateFrame("EditBox", nil, col1)
    decimalEditBox:SetHeight(14)
    decimalEditBox:SetWidth(45)
    decimalEditBox:SetPoint("LEFT", decimalLabel, "RIGHT", 2, 0)
    decimalEditBox:SetAutoFocus(false)
    decimalEditBox:SetFontObject(_G[FONT_SMALL])
    decimalEditBox:SetJustifyH("CENTER")
    decimalEditBox:SetBackdrop(BACKDROP_INPUT)
    decimalEditBox:SetBackdropColor(unpack(COLORS.inputBg))
    decimalEditBox:SetBackdropBorderColor(unpack(COLORS.border))
    decimalEditBox:SetTextInsets(2, 2, 0, 0)
    decimalEditBox:SetText(tostring(Valuate:GetOptions().decimalPlaces or 1))
    
    -- Apply whole number validation (digits only, no decimals or signs)
    ApplyWholeNumberValidation(decimalEditBox)
    
    decimalEditBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 1
        value = math.max(0, math.min(4, value))
        Valuate:GetOptions().decimalPlaces = value
        self:SetText(tostring(value))
        self:ClearFocus()
        
        -- Reset all tooltips to show new decimal places immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    decimalEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(Valuate:GetOptions().decimalPlaces or 1))
        self:ClearFocus()
    end)
    
    -- Right-Align Scores checkbox (Column 1)
    local alignCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    alignCheckbox:SetSize(24, 24)
    alignCheckbox:SetPoint("TOPLEFT", decimalLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local alignLabel = alignCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    alignLabel:SetPoint("LEFT", alignCheckbox, "RIGHT", 5, 0)
    alignLabel:SetText("Right-Align Scores")
    alignCheckbox:SetChecked(Valuate:GetOptions().rightAlign == true)
    alignCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().rightAlign = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        -- Reset all tooltips to show new alignment immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Show Scale Value dropdown (Column 1) - moved from Column 2
    local showScaleLabel = col1:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    showScaleLabel:SetPoint("TOPLEFT", alignCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    showScaleLabel:SetText("Show Scale Value:")
    
    local showScaleModes = {
        { value = "all", text = "ON all" },
        { value = "current", text = "On current scale only" },
    }
    
    local showScaleDropdown = CreateFrame("Frame", "ValuateShowScaleDropdown", col1, "UIDropDownMenuTemplate")
    showScaleDropdown:SetPoint("LEFT", showScaleLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(showScaleDropdown, 180)
    
    columnHeights[1] = columnHeights[1] + 32 + ELEMENT_SPACING
    
    local function GetShowScaleText(value)
        for _, mode in ipairs(showScaleModes) do
            if mode.value == value then
                return mode.text
            end
        end
        return "ON all"
    end
    
    -- Set initial text
    local currentShowScale = Valuate:GetOptions().showScaleValue or "all"
    UIDropDownMenu_SetText(showScaleDropdown, GetShowScaleText(currentShowScale))
    
    -- Dropdown initialization function
    UIDropDownMenu_Initialize(showScaleDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(showScaleModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (Valuate:GetOptions().showScaleValue or "all") == mode.value
            info.func = function(self)
                Valuate:GetOptions().showScaleValue = self.value
                UIDropDownMenu_SetText(showScaleDropdown, GetShowScaleText(self.value))
                
                -- Reset all tooltips to show/hide scale values immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Tooltip for dropdown
    showScaleDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Show Scale Value", 1, 1, 1)
            GameTooltip:AddLine("Controls which scale values are displayed on tooltips.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("ON all: Show values for all active scales", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("On current scale only: Show value only for the current scale", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    showScaleDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Show Best For checkbox (Column 1)
    local showBestForCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    showBestForCheckbox:SetSize(24, 24)
    showBestForCheckbox:SetPoint("TOPLEFT", showScaleLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local showBestForLabel = showBestForCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    showBestForLabel:SetPoint("LEFT", showBestForCheckbox, "RIGHT", 5, 0)
    showBestForLabel:SetText("Show Best For")
    showBestForCheckbox:SetChecked(Valuate:GetOptions().showBestFor ~= false)
    showBestForCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().showBestFor = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        -- Reset all tooltips to show/hide "Best for" immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    showBestForCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Show Best For", 1, 1, 1)
            GameTooltip:AddLine("Display the 'Best for' indicator on tooltips for items that are best in slot for any active scale.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    showBestForCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Normalize Display checkbox (Column 1)
    local normalizeCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    normalizeCheckbox:SetSize(24, 24)
    normalizeCheckbox:SetPoint("TOPLEFT", showBestForCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local normalizeLabel = normalizeCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    normalizeLabel:SetPoint("LEFT", normalizeCheckbox, "RIGHT", 5, 0)
    normalizeLabel:SetText("Normalize Display")
    normalizeCheckbox:SetChecked(Valuate:GetOptions().normalizeDisplay == true)
    normalizeCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().normalizeDisplay = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        -- Reset all tooltips to show normalized/non-normalized values immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    normalizeCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Normalize Display", 1, 1, 1)
            GameTooltip:AddLine("When enabled, all scores are normalized so the highest stat weight = 1.0. This makes it easier to compare items across different scales. Your original stat weights are never changed.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    normalizeCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Show Stat Breakdown checkbox (Column 1)
    local breakdownCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    breakdownCheckbox:SetSize(24, 24)
    breakdownCheckbox:SetPoint("TOPLEFT", normalizeCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local breakdownLabel = breakdownCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    breakdownLabel:SetPoint("LEFT", breakdownCheckbox, "RIGHT", 5, 0)
    breakdownLabel:SetText("Show Stat Breakdown")
    breakdownCheckbox:SetChecked(Valuate:GetOptions().showStatBreakdown == true)
    breakdownCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().showStatBreakdown = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        -- Reset all tooltips to show/hide breakdown immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    breakdownCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Show Stat Breakdown", 1, 1, 1)
            GameTooltip:AddLine("When enabled, shows detailed calculation breakdown for each stat on item tooltips. Each line shows: stat value × weight = contribution, followed by the total.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    breakdownCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Scan Verbose checkbox (Column 1)
    local scanVerboseCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    scanVerboseCheckbox:SetSize(24, 24)
    scanVerboseCheckbox:SetPoint("TOPLEFT", breakdownCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local scanVerboseLabel = scanVerboseCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    scanVerboseLabel:SetPoint("LEFT", scanVerboseCheckbox, "RIGHT", 5, 0)
    scanVerboseLabel:SetText("Scan Verbose Messages")
    
    -- Default to disabled if not set
    if Valuate:GetOptions().scanVerbose == nil then
        Valuate:GetOptions().scanVerbose = false
    end
    scanVerboseCheckbox:SetChecked(Valuate:GetOptions().scanVerbose == true)
    scanVerboseCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().scanVerbose = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    scanVerboseCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Scan Verbose Messages", 1, 1, 1)
            GameTooltip:AddLine("When enabled, displays completion messages in chat after scanning best equipment. Disabled by default to keep chat clean.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    scanVerboseCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Auto Scan dropdown (Column 1)
    local autoScanLabel = col1:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoScanLabel:SetPoint("TOPLEFT", scanVerboseCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    autoScanLabel:SetText("Auto Scan:")
    
    local autoScanModes = {
        { value = "off", text = "Off" },
        { value = "onEquipmentChange", text = "On Equipment Change" },
        { value = "onLoot", text = "On Loot" },
        { value = "always", text = "Always" },
    }
    
    local autoScanDropdown = CreateFrame("Frame", "ValuateAutoScanDropdown", col1, "UIDropDownMenuTemplate")
    autoScanDropdown:SetPoint("LEFT", autoScanLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(autoScanDropdown, 180)
    
    columnHeights[1] = columnHeights[1] + 32 + ELEMENT_SPACING
    
    local function GetAutoScanText(value)
        for _, mode in ipairs(autoScanModes) do
            if mode.value == value then
                return mode.text
            end
        end
        return "On Equipment Change"
    end
    
    -- Set initial text
    local currentAutoScan = Valuate:GetOptions().autoScan or "onEquipmentChange"
    UIDropDownMenu_SetText(autoScanDropdown, GetAutoScanText(currentAutoScan))
    
    -- Dropdown initialization function
    UIDropDownMenu_Initialize(autoScanDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(autoScanModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (Valuate:GetOptions().autoScan or "onEquipmentChange") == mode.value
            info.func = function(self)
                Valuate:GetOptions().autoScan = self.value
                UIDropDownMenu_SetText(autoScanDropdown, GetAutoScanText(self.value))
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Tooltip for dropdown
    autoScanDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Scan", 1, 1, 1)
            GameTooltip:AddLine("Controls when the best equipment scan runs automatically.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Off: Never scan automatically", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("On Equipment Change: Scan when you change equipment", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("On Loot: Scan when you loot items", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Always: Scan on equipment changes, loot, and bag updates", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    autoScanDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Auto Choose Best Quest Reward checkbox (Column 1, below the Auto Scan dropdown)
    local autoQuestCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoQuestCheckbox:SetSize(24, 24)
    autoQuestCheckbox:SetPoint("TOPLEFT", autoScanLabel, "BOTTOMLEFT", 0, -36)

    local autoQuestLabel = autoQuestCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoQuestLabel:SetPoint("LEFT", autoQuestCheckbox, "RIGHT", 5, 0)
    autoQuestLabel:SetText("Auto Choose Best Quest Reward")
    autoQuestCheckbox:SetChecked(Valuate:GetOptions().autoQuestReward == true)
    autoQuestCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoQuestReward = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    autoQuestCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Choose Best Quest Reward", 1, 1, 1)
            GameTooltip:AddLine("When a quest offers a choice of rewards, Valuate automatically pre-selects the highest-scoring one for your active scale (the character-window scale, or the first active scale).", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("It only highlights the reward - you still click 'Complete Quest' yourself. Non-gear rewards (bags, consumables) are left for you to decide.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    autoQuestCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Auto Turn In Quests checkbox (Column 1, indented under Auto Choose Best Quest Reward)
    local autoTurnInCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoTurnInCheckbox:SetSize(24, 24)
    autoTurnInCheckbox:SetPoint("TOPLEFT", autoQuestCheckbox, "BOTTOMLEFT", 16, -ELEMENT_SPACING)

    local autoTurnInLabel = autoTurnInCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoTurnInLabel:SetPoint("LEFT", autoTurnInCheckbox, "RIGHT", 5, 0)
    autoTurnInLabel:SetText("Auto Turn In Quests")
    autoTurnInCheckbox:SetChecked(Valuate:GetOptions().autoQuestTurnIn == true)
    autoTurnInCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoQuestTurnIn = (self:GetChecked() == 1) or (self:GetChecked() == true)
        if Valuate:GetOptions().autoQuestTurnIn and not Valuate:GetOptions().autoQuestReward then
            print("|cFFFFAA00Valuate|r: Also enable 'Auto Choose Best Quest Reward' above for turn-in to work.")
        end
    end)
    autoTurnInCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Turn In Quests", 1, 1, 1)
            GameTooltip:AddLine("Goes beyond pre-selecting: at a quest's reward screen, Valuate actually completes the quest and takes the best-scoring reward - and advances the 'do you have the items?' screen for you.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Requires 'Auto Choose Best Quest Reward'. If a reward choice can't be scored (all bags/consumables), the quest is NOT auto-completed so you can decide.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Warning: this hands in quests automatically. Leave off if you like to read or pick rewards yourself.", 1, 0.5, 0.5, true)
            GameTooltip:Show()
        end
    end)
    autoTurnInCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Ignore Profession Tools checkbox (Column 1, below Auto Turn In Quests;
    -- -16 x-offset undoes the turn-in checkbox's indent to return to the base column)
    local ignoreToolsCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    ignoreToolsCheckbox:SetSize(24, 24)
    ignoreToolsCheckbox:SetPoint("TOPLEFT", autoTurnInCheckbox, "BOTTOMLEFT", -16, -ELEMENT_SPACING)

    local ignoreToolsLabel = ignoreToolsCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    ignoreToolsLabel:SetPoint("LEFT", ignoreToolsCheckbox, "RIGHT", 5, 0)
    ignoreToolsLabel:SetText("Ignore Profession Tools")
    ignoreToolsCheckbox:SetChecked(Valuate:GetOptions().ignoreProfessionTools ~= false)
    ignoreToolsCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().ignoreProfessionTools = (self:GetChecked() == 1) or (self:GetChecked() == true)
        -- Re-evaluate tooltips and re-scan so the change takes effect immediately
        if Valuate.ResetTooltips then Valuate:ResetTooltips() end
        if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
    end)
    ignoreToolsCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Ignore Profession Tools", 1, 1, 1)
            GameTooltip:AddLine("When enabled, Valuate never scores, displays, tracks, or filters on profession tools - fishing poles, mining picks, skinning knives, blacksmith hammers, engineering tools, and similar.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Caster off-hand tomes/orbs are NOT affected - only weapon-type tools.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    ignoreToolsCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Auto Accept Quests checkbox (Column 1, below Ignore Profession Tools)
    local autoAcceptCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoAcceptCheckbox:SetSize(24, 24)
    autoAcceptCheckbox:SetPoint("TOPLEFT", ignoreToolsCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local autoAcceptLabel = autoAcceptCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoAcceptLabel:SetPoint("LEFT", autoAcceptCheckbox, "RIGHT", 5, 0)
    autoAcceptLabel:SetText("Auto Accept Quests")
    autoAcceptCheckbox:SetChecked(Valuate:GetOptions().autoAcceptQuests == true)
    autoAcceptCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoAcceptQuests = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    autoAcceptCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Accept Quests", 1, 1, 1)
            GameTooltip:AddLine("Automatically accepts quests offered by NPCs - including escort/party-shared confirmations and quests listed in a gossip or multi-quest greeting window.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Warning: accepts every quest an NPC offers. Leave off if you like to pick and read quests yourself.", 1, 0.5, 0.5, true)
            GameTooltip:Show()
        end
    end)
    autoAcceptCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Auto Roll On Loot checkbox (Column 1, below Auto Accept Quests)
    local autoRollCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoRollCheckbox:SetSize(24, 24)
    autoRollCheckbox:SetPoint("TOPLEFT", autoAcceptCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local autoRollLabel = autoRollCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoRollLabel:SetPoint("LEFT", autoRollCheckbox, "RIGHT", 5, 0)
    autoRollLabel:SetText("Auto Roll On Loot")
    autoRollCheckbox:SetChecked(Valuate:GetOptions().autoRollLoot == true)
    autoRollCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoRollLoot = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    autoRollCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Roll On Loot", 1, 1, 1)
            GameTooltip:AddLine("On a group loot roll, Valuate rolls NEED when the item is an upgrade for any of your scales (including inactive ones), and GREED otherwise. It never rolls Need on something that isn't an upgrade.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("An item you can't equip yet (higher level required) still counts as an upgrade if it beats your best.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Warning: rolls automatically on your behalf. Auto-Need can be contentious in groups.", 1, 0.5, 0.5, true)
            GameTooltip:Show()
        end
    end)
    autoRollCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Notify Bag Upgrades checkbox (Column 1, below Auto Roll On Loot)
    local notifyCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    notifyCheckbox:SetSize(24, 24)
    notifyCheckbox:SetPoint("TOPLEFT", autoRollCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local notifyLabel = notifyCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    notifyLabel:SetPoint("LEFT", notifyCheckbox, "RIGHT", 5, 0)
    notifyLabel:SetText("Notify Bag Upgrades")
    notifyCheckbox:SetChecked(Valuate:GetOptions().notifyBagUpgrade == true)
    notifyCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().notifyBagUpgrade = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    notifyCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Notify Bag Upgrades", 1, 1, 1)
            GameTooltip:AddLine("When an equippable upgrade for your CURRENT scale is sitting in your bags, pops a prompt (out of combat) to equip the best set in one click.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Enabling this scans after each loot so the check is accurate. Click the mode button to the right to change how often it re-prompts.", 0.6, 0.9, 0.6, true)
            GameTooltip:Show()
        end
    end)
    notifyCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Re-prompt frequency: click to toggle everyLoot <-> oncePerUpgrade.
    local function NotifyModeText()
        return (Valuate:GetOptions().notifyBagUpgradeMode == "oncePerUpgrade")
            and "Once per upgrade" or "Every loot"
    end
    local notifyModeButton = CreateStyledButton(col1, NotifyModeText(), 120, 18)
    notifyModeButton:SetPoint("LEFT", notifyLabel, "RIGHT", 8, 0)
    notifyModeButton:SetScript("OnClick", function(self)
        local o = Valuate:GetOptions()
        o.notifyBagUpgradeMode = (o.notifyBagUpgradeMode == "oncePerUpgrade") and "everyLoot" or "oncePerUpgrade"
        self.label:SetText(NotifyModeText())
    end)
    notifyModeButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Re-prompt frequency", 1, 1, 1)
            GameTooltip:AddLine("Every loot: re-shows the prompt after each loot event while an upgrade sits in your bags.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Once per upgrade: only prompts when the available upgrades actually change.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    notifyModeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Auto Confirm Bind On Loot checkbox (Column 1, below Notify Bag Upgrades)
    local bindConfirmCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    bindConfirmCheckbox:SetSize(24, 24)
    bindConfirmCheckbox:SetPoint("TOPLEFT", notifyCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local bindConfirmLabel = bindConfirmCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    bindConfirmLabel:SetPoint("LEFT", bindConfirmCheckbox, "RIGHT", 5, 0)
    bindConfirmLabel:SetText("Auto Confirm Bind On Loot")
    bindConfirmCheckbox:SetChecked(Valuate:GetOptions().autoConfirmBindOnLoot == true)
    bindConfirmCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoConfirmBindOnLoot = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    bindConfirmCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Confirm Bind On Loot", 1, 1, 1)
            GameTooltip:AddLine("Skips the 'this item will bind to you' prompt when YOU loot a bind-on-pickup item.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Does not apply to USING an item - that prompt is left alone, because automating it makes the client block the item use.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Not needed for Equip All or right-click-to-equip - Valuate already confirms binds for equips it starts itself, and manual equips always keep their prompt.", 0.6, 0.9, 0.6, true)
            GameTooltip:AddLine("Warning: binding an item destroys its trade / auction value.", 1, 0.5, 0.5, true)
            GameTooltip:Show()
        end
    end)
    bindConfirmCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Auto Delete Junk checkbox (Column 1) - DESTRUCTIVE, so it warns loudly.
    local autoDeleteCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoDeleteCheckbox:SetSize(24, 24)
    autoDeleteCheckbox:SetPoint("TOPLEFT", bindConfirmCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local autoDeleteLabel = autoDeleteCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoDeleteLabel:SetPoint("LEFT", autoDeleteCheckbox, "RIGHT", 5, 0)
    autoDeleteLabel:SetText("Auto Delete Junk")
    autoDeleteLabel:SetTextColor(1, 0.6, 0.6, 1)
    autoDeleteCheckbox:SetChecked(Valuate:GetOptions().autoDeleteJunk == true)
    autoDeleteCheckbox:SetScript("OnClick", function(self)
        local on = (self:GetChecked() == 1) or (self:GetChecked() == true)
        Valuate:GetOptions().autoDeleteJunk = on
        if on then
            print("|cFFFF5555Valuate|r: Auto Delete Junk is ON - deletions are PERMANENT. Use /valuate deletepreview to see what it would remove.")
        end
    end)
    autoDeleteCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Delete Junk", 1, 1, 1)
            GameTooltip:AddLine("After looting, deletes the least valuable junk until the configured number of bag slots is free. Only touches items AdiBags classes as Junk (honouring its include/exclude lists), or grey items when AdiBags isn't loaded.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Never deletes: best-in-slot, weapon-set members, future upgrades, anything that's an upgrade for any scale, quest items, or items in a WoW equipment set.", 0.6, 0.9, 0.6, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("WARNING: deletion is PERMANENT - WoW has no undo. Every deletion is printed to chat; watch it on your first few runs. /valuate deletepreview shows what would go without deleting.", 1, 0.4, 0.4, true)
            GameTooltip:Show()
        end
    end)
    autoDeleteCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Dry-run sub-toggle (indented under Auto Delete Junk)
    local dryRunCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    dryRunCheckbox:SetSize(24, 24)
    dryRunCheckbox:SetPoint("TOPLEFT", autoDeleteCheckbox, "BOTTOMLEFT", 16, -ELEMENT_SPACING)

    local dryRunLabel = dryRunCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    dryRunLabel:SetPoint("LEFT", dryRunCheckbox, "RIGHT", 5, 0)
    dryRunLabel:SetText("Dry Run (log only)")
    dryRunCheckbox:SetChecked(Valuate:GetOptions().autoDeleteDryRun == true)
    dryRunCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoDeleteDryRun = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    dryRunCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Dry Run", 1, 1, 1)
            GameTooltip:AddLine("Log what auto-delete WOULD remove, without deleting anything. Useful to validate the rules before trusting it.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    dryRunCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Auto Sell Junk checkbox (Column 1, below Dry Run; -16 undoes its indent)
    local autoSellCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoSellCheckbox:SetSize(24, 24)
    autoSellCheckbox:SetPoint("TOPLEFT", dryRunCheckbox, "BOTTOMLEFT", -16, -ELEMENT_SPACING)

    local autoSellLabel = autoSellCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoSellLabel:SetPoint("LEFT", autoSellCheckbox, "RIGHT", 5, 0)
    autoSellLabel:SetText("Auto Sell Junk At Merchants")
    autoSellCheckbox:SetChecked(Valuate:GetOptions().autoSellJunk == true)
    autoSellCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoSellJunk = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    autoSellCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Sell Junk At Merchants", 1, 1, 1)
            GameTooltip:AddLine("When you open a vendor, sells everything the Junk rules match - the same classification and the same protections as auto-delete.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Safer than deleting: you get the gold, and the vendor's Buyback tab can recover a mistake.", 0.6, 0.9, 0.6, true)
            GameTooltip:Show()
        end
    end)
    autoSellCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Auto Repair checkbox (Column 1, below Auto Sell Junk)
    local autoRepairCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoRepairCheckbox:SetSize(24, 24)
    autoRepairCheckbox:SetPoint("TOPLEFT", autoSellCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local autoRepairLabel = autoRepairCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    autoRepairLabel:SetPoint("LEFT", autoRepairCheckbox, "RIGHT", 5, 0)
    autoRepairLabel:SetText("Auto Repair")
    autoRepairCheckbox:SetChecked(Valuate:GetOptions().autoRepair == true)
    autoRepairCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoRepair = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    autoRepairCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Auto Repair", 1, 1, 1)
            GameTooltip:AddLine("Repairs all your gear when you open a merchant that offers repairs, and reports the cost.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Won't repair if you can't afford it.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    autoRepairCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Guild-funds sub-toggle (indented under Auto Repair)
    local guildRepairCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    guildRepairCheckbox:SetSize(24, 24)
    guildRepairCheckbox:SetPoint("TOPLEFT", autoRepairCheckbox, "BOTTOMLEFT", 16, -ELEMENT_SPACING)

    local guildRepairLabel = guildRepairCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    guildRepairLabel:SetPoint("LEFT", guildRepairCheckbox, "RIGHT", 5, 0)
    guildRepairLabel:SetText("Use Guild Funds First")
    guildRepairCheckbox:SetChecked(Valuate:GetOptions().autoRepairGuildFirst == true)
    guildRepairCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoRepairGuildFirst = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    guildRepairCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Use Guild Funds First", 1, 1, 1)
            GameTooltip:AddLine("Try the guild bank's repair funds before your own money. Falls back to your gold if guild repair isn't available.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    guildRepairCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- ========================================
    -- COLUMN 2: Upgrade Comparison & Interface
    -- ========================================
    local col2 = columnFrames[2]
    
    -- Upgrade Comparison Section Header (Column 2)
    local comparisonHeader = col2:CreateFontString(nil, "OVERLAY", FONT_H1)
    comparisonHeader:SetPoint("TOPLEFT", col2, "TOPLEFT", 0, 0)
    comparisonHeader:SetText("Upgrade Comparison")
    comparisonHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[2] = HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Comparison Mode dropdown (Column 2)
    local compModeLabel = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    compModeLabel:SetPoint("TOPLEFT", comparisonHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    compModeLabel:SetText("Comparison Mode:")
    
    local comparisonModes = {
        { value = "number", text = "Number (+15.2)" },
        { value = "percent", text = "Percentage (+13.8% or +HUGE!)" },
        { value = "both", text = "Both (+15.2, +13.8% or +HUGE!)" },
        { value = "off", text = "Off" },
    }
    
    local compModeDropdown = CreateFrame("Frame", "ValuateComparisonModeDropdown", col2, "UIDropDownMenuTemplate")
    compModeDropdown:SetPoint("LEFT", compModeLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(compModeDropdown, 150)
    
    columnHeights[2] = columnHeights[2] + 32 + ELEMENT_SPACING
    
    local function GetCompModeText(value)
        for _, mode in ipairs(comparisonModes) do
            if mode.value == value then
                return mode.text
            end
        end
        return "Number (+15.2)"
    end
    
    -- Set initial text
    UIDropDownMenu_SetText(compModeDropdown, GetCompModeText(Valuate:GetOptions().comparisonMode or "number"))
    
    -- Dropdown initialization function
    UIDropDownMenu_Initialize(compModeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(comparisonModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (Valuate:GetOptions().comparisonMode or "number") == mode.value
            info.func = function(self)
                Valuate:GetOptions().comparisonMode = self.value
                UIDropDownMenu_SetText(compModeDropdown, GetCompModeText(self.value))
                
                -- Reset all tooltips to show new comparison mode immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Tooltip for dropdown
    compModeDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Comparison Mode", 1, 1, 1)
        GameTooltip:AddLine("Choose how upgrade/downgrade differences are displayed.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Number: Shows the score difference (+15.2)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Percentage: Shows the percent change (+13.8%)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Both: Shows both number and percentage", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Off: Disables upgrade comparison", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Note: Percentages of 1000% or greater are displayed as", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("'HUGE!' to keep tooltips clean and readable.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        end
    end)
    compModeDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Interface Section Header (Column 2)
    local interfaceHeader = col2:CreateFontString(nil, "OVERLAY", FONT_H1)
    interfaceHeader:SetPoint("TOPLEFT", compModeLabel, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    interfaceHeader:SetText("Interface")
    interfaceHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[2] = columnHeights[2] + (ELEMENT_SPACING * 3) + HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Show Minimap Button checkbox (Column 2) - moved from Column 3
    local minimapButtonCheckbox = CreateFrame("CheckButton", nil, col2, "UICheckButtonTemplate")
    minimapButtonCheckbox:SetSize(24, 24)
    minimapButtonCheckbox:SetPoint("TOPLEFT", interfaceHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local minimapButtonLabel = minimapButtonCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    minimapButtonLabel:SetPoint("LEFT", minimapButtonCheckbox, "RIGHT", 5, 0)
    minimapButtonLabel:SetText("Show Minimap Button")
    
    -- Default to enabled if not set
    if Valuate:GetOptions().minimapButtonHidden == nil then
        Valuate:GetOptions().minimapButtonHidden = false
    end
    minimapButtonCheckbox:SetChecked(not Valuate:GetOptions().minimapButtonHidden)
    minimapButtonCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        Valuate:GetOptions().minimapButtonHidden = not checked
        if Valuate.ToggleMinimapButton then
            if checked then
                Valuate:ShowMinimapButton()
            else
                Valuate:HideMinimapButton()
            end
        end
    end)
    minimapButtonCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Show Minimap Button", 1, 1, 1)
        GameTooltip:AddLine("Toggle the Valuate minimap button.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    minimapButtonCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[2] = columnHeights[2] + 24 + ELEMENT_SPACING

    -- Reduce Motion checkbox (Column 2, below Show Minimap Button)
    local reduceMotionCheckbox = CreateFrame("CheckButton", nil, col2, "UICheckButtonTemplate")
    reduceMotionCheckbox:SetSize(24, 24)
    reduceMotionCheckbox:SetPoint("TOPLEFT", minimapButtonCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local reduceMotionLabel = reduceMotionCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    reduceMotionLabel:SetPoint("LEFT", reduceMotionCheckbox, "RIGHT", 5, 0)
    reduceMotionLabel:SetText("Reduce Motion")
    reduceMotionCheckbox:SetChecked(Valuate:GetOptions().reduceMotion == true)
    reduceMotionCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().reduceMotion = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    reduceMotionCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Reduce Motion", 1, 1, 1)
            GameTooltip:AddLine("Collapse all Valuate UI animations - window open/close, tab and column reveals, hovers, flashes - to instant. For a calmer UI or a small performance saving.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    reduceMotionCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[2] = columnHeights[2] + 24 + ELEMENT_SPACING

    -- ========================================
    -- Auto Delete tuning (Column 2)
    -- ========================================
    local autoDeleteHeader = col2:CreateFontString(nil, "OVERLAY", FONT_H1)
    autoDeleteHeader:SetPoint("TOPLEFT", reduceMotionCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING * 2)
    autoDeleteHeader:SetText("Auto Delete")
    autoDeleteHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[2] = columnHeights[2] + 20 + ELEMENT_SPACING

    -- Helper: a small labelled numeric input row in column 2.
    local function CreateCol2NumberRow(labelText, anchorTo, yGap, initialText, validator, onCommit, resetText)
        local lbl = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        lbl:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -yGap)
        lbl:SetText(labelText)

        local box = CreateFrame("EditBox", nil, col2)
        box:SetHeight(14)
        box:SetWidth(55)
        box:SetPoint("LEFT", lbl, "RIGHT", 4, 0)
        box:SetAutoFocus(false)
        box:SetFontObject(_G[FONT_SMALL])
        box:SetJustifyH("CENTER")
        box:SetBackdrop(BACKDROP_INPUT)
        box:SetBackdropColor(unpack(COLORS.inputBg))
        box:SetBackdropBorderColor(unpack(COLORS.border))
        box:SetTextInsets(2, 2, 0, 0)
        box:SetText(initialText)
        if validator then validator(box) end
        box:SetScript("OnEnterPressed", function(self)
            onCommit(self)
            self:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(resetText())
            self:ClearFocus()
        end)
        columnHeights[2] = columnHeights[2] + 16 + ELEMENT_SPACING
        return lbl, box
    end

    local function GoldText(copper)
        return string.format("%.2f", (copper or 0) / 10000)
    end

    -- Keep Free Slots
    local keepFreeLabel = CreateCol2NumberRow(
        "Keep Free Slots:", autoDeleteHeader, ELEMENT_SPACING,
        tostring(Valuate:GetOptions().autoDeleteKeepFree or 4),
        ApplyWholeNumberValidation,
        function(self)
            local v = math.max(0, math.min(60, tonumber(self:GetText()) or 4))
            Valuate:GetOptions().autoDeleteKeepFree = v
            self:SetText(tostring(v))
        end,
        function() return tostring(Valuate:GetOptions().autoDeleteKeepFree or 4) end)

    -- Max Quality (click to cycle)
    local QUALITY_NAMES = { [0] = "Poor (grey)", [1] = "Common (white)", [2] = "Uncommon (green)", [3] = "Rare (blue)" }
    local qualityLabel = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    qualityLabel:SetPoint("TOPLEFT", keepFreeLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING - 4)
    qualityLabel:SetText("Max Quality:")

    local function QualityText()
        local q = Valuate:GetOptions().autoDeleteMaxQuality or 2
        return QUALITY_NAMES[q] or tostring(q)
    end
    local qualityButton = CreateStyledButton(col2, QualityText(), 116, 18)
    qualityButton:SetPoint("LEFT", qualityLabel, "RIGHT", 4, 0)
    qualityButton:SetScript("OnClick", function(self)
        local q = ((Valuate:GetOptions().autoDeleteMaxQuality or 2) + 1) % 4
        Valuate:GetOptions().autoDeleteMaxQuality = q
        self.label:SetText(QualityText())
    end)
    qualityButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Max Quality", 1, 1, 1)
            GameTooltip:AddLine("Never auto-delete an item above this quality. Click to cycle.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Poor (grey) is the safest setting - greys are pure vendor trash.", 0.6, 0.9, 0.6, true)
            GameTooltip:Show()
        end
    end)
    qualityButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[2] = columnHeights[2] + 20 + ELEMENT_SPACING

    -- Value ceiling / floor (entered in gold, stored as copper)
    local maxValLabel = CreateCol2NumberRow(
        "Max Value (g):", qualityLabel, ELEMENT_SPACING + 6,
        GoldText(Valuate:GetOptions().autoDeleteMaxValue),
        ApplyStatValueValidation,
        function(self)
            local g = math.max(0, tonumber(self:GetText()) or 0)
            Valuate:GetOptions().autoDeleteMaxValue = math.floor(g * 10000)
            self:SetText(GoldText(Valuate:GetOptions().autoDeleteMaxValue))
        end,
        function() return GoldText(Valuate:GetOptions().autoDeleteMaxValue) end)

    local minValLabel = CreateCol2NumberRow(
        "Min Value (g):", maxValLabel, ELEMENT_SPACING,
        GoldText(Valuate:GetOptions().autoDeleteMinValue),
        ApplyStatValueValidation,
        function(self)
            local g = math.max(0, tonumber(self:GetText()) or 0)
            Valuate:GetOptions().autoDeleteMinValue = math.floor(g * 10000)
            self:SetText(GoldText(Valuate:GetOptions().autoDeleteMinValue))
        end,
        function() return GoldText(Valuate:GetOptions().autoDeleteMinValue) end)

    -- Price source: "vendor" or a TSM price source / custom price string.
    local sourceLabel = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    sourceLabel:SetPoint("TOPLEFT", minValLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING - 4)
    sourceLabel:SetText("Value Source:")

    local sourceBox = CreateFrame("EditBox", nil, col2)
    sourceBox:SetHeight(14)
    sourceBox:SetWidth(110)
    sourceBox:SetPoint("LEFT", sourceLabel, "RIGHT", 4, 0)
    sourceBox:SetAutoFocus(false)
    sourceBox:SetFontObject(_G[FONT_SMALL])
    sourceBox:SetJustifyH("CENTER")
    sourceBox:SetBackdrop(BACKDROP_INPUT)
    sourceBox:SetBackdropColor(unpack(COLORS.inputBg))
    sourceBox:SetBackdropBorderColor(unpack(COLORS.border))
    sourceBox:SetTextInsets(2, 2, 0, 0)
    sourceBox:SetText(Valuate:GetOptions().autoDeleteValueSource or "vendor")
    sourceBox:SetScript("OnEnterPressed", function(self)
        local v = strtrim(self:GetText() or "")
        if v == "" then v = "vendor" end
        Valuate:GetOptions().autoDeleteValueSource = v
        self:SetText(v)
        self:ClearFocus()
        print("|cFF00FF00Valuate|r: Value source set to '" .. v .. "'. Run /valuate deletepreview to confirm it resolves.")
    end)
    sourceBox:SetScript("OnEscapePressed", function(self)
        self:SetText(Valuate:GetOptions().autoDeleteValueSource or "vendor")
        self:ClearFocus()
    end)
    sourceBox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Value Source", 1, 1, 1)
            GameTooltip:AddLine("Which price to rank junk by. Default 'vendor' uses the vendor sell price.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("With TradeSkillMaster you can use a price source instead, e.g. DBMarket, DBMinBuyout, DBHistorical - or a custom price string like max(dbmarket,vendorsell).", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Always falls back to vendor sell price if the source is unavailable or has no data for an item. The preview reports when it falls back.", 0.6, 0.9, 0.6, true)
            GameTooltip:Show()
        end
    end)
    sourceBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[2] = columnHeights[2] + 16 + ELEMENT_SPACING

    -- Explain the two bounds, since "floor" is the non-obvious one.
    local valueHint = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    valueHint:SetPoint("TOPLEFT", sourceLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    valueHint:SetWidth(settingsColumnWidth)
    valueHint:SetJustifyH("LEFT")
    valueHint:SetText("Only stacks worth between Min and Max are deletable.\nMax 0 = no ceiling, Min 0 = no floor.\nA tiny Min (0.0001 = 1c) skips unsellable items.")
    valueHint:SetTextColor(unpack(COLORS.textDim))
    columnHeights[2] = columnHeights[2] + 40 + ELEMENT_SPACING

    -- ========================================
    -- COLUMN 3: Character Window, Keybindings, Advanced
    -- ========================================
    local col3 = columnFrames[3]
    
    -- Character Window Section Header
    local charWindowHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    charWindowHeader:SetPoint("TOPLEFT", col3, "TOPLEFT", 0, 0)
    charWindowHeader:SetText("Character Window")
    charWindowHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[3] = HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Enable Character Window Display checkbox
    local charWindowCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
    charWindowCheckbox:SetSize(24, 24)
    charWindowCheckbox:SetPoint("TOPLEFT", charWindowHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local charWindowLabel = charWindowCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    charWindowLabel:SetPoint("LEFT", charWindowCheckbox, "RIGHT", 5, 0)
    charWindowLabel:SetText("Show Scale Display")
    
    -- Default to enabled if not set
    if Valuate:GetOptions().showCharacterWindowDisplay == nil then
        Valuate:GetOptions().showCharacterWindowDisplay = true
    end
    charWindowCheckbox:SetChecked(Valuate:GetOptions().showCharacterWindowDisplay)
    charWindowCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        Valuate:GetOptions().showCharacterWindowDisplay = checked
        Valuate:RefreshCharacterWindowVisibility()
    end)
    charWindowCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Show Scale Display", 1, 1, 1)
        GameTooltip:AddLine("Toggle the scale value display on the character window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    charWindowCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- Display Mode dropdown (moved up from after keybindings)
    local charModeLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    charModeLabel:SetPoint("TOPLEFT", charWindowCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    charModeLabel:SetText("Display Mode:")
    
    local charModeDropdown = CreateFrame("Frame", "ValuateCharWindowModeDropdown", col3, "UIDropDownMenuTemplate")
    charModeDropdown:SetPoint("LEFT", charModeLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(charModeDropdown, 100)
    
    columnHeights[3] = columnHeights[3] + 32 + ELEMENT_SPACING
    
    local displayModes = {
        { value = "total", text = "Total" },
        { value = "average", text = "Average" },
    }
    
    local function GetDisplayModeText(value)
        for _, mode in ipairs(displayModes) do
            if mode.value == value then
                return mode.text
            end
        end
        return "Total"
    end
    
    if not Valuate:GetOptions().characterWindowDisplayMode then
        Valuate:GetOptions().characterWindowDisplayMode = "total"
    end
    UIDropDownMenu_SetText(charModeDropdown, GetDisplayModeText(Valuate:GetOptions().characterWindowDisplayMode))
    
    UIDropDownMenu_Initialize(charModeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(displayModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (Valuate:GetOptions().characterWindowDisplayMode == mode.value)
            info.func = function(self)
                Valuate:GetOptions().characterWindowDisplayMode = self.value
                UIDropDownMenu_SetText(charModeDropdown, GetDisplayModeText(self.value))
                Valuate:RefreshCharacterWindowDisplay()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    charModeDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Display Mode", 1, 1, 1)
        GameTooltip:AddLine("Total: Sum of all equipped item scores", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Average: Average score per slot", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        end
    end)
    charModeDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Character Window Scale dropdown (moved up from after Display Mode)
    local charScaleLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    charScaleLabel:SetPoint("TOPLEFT", charModeLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    charScaleLabel:SetText("Display Scale:")
    
    local charScaleDropdown = CreateFrame("Frame", "ValuateCharWindowScaleDropdown", col3, "UIDropDownMenuTemplate")
    charScaleDropdown:SetPoint("LEFT", charScaleLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(charScaleDropdown, 180)
    
    columnHeights[3] = columnHeights[3] + 32 + ELEMENT_SPACING
    
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
    
    UIDropDownMenu_SetText(charScaleDropdown, GetCharScaleDisplayText(Valuate:GetOptions().characterWindowScale, true))
    
    UIDropDownMenu_Initialize(charScaleDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local scales = {}
        local scalesData = Valuate:GetScales()
        if scalesData then
            for name, scale in pairs(scalesData) do
                if scale.Values and (scale.Visible ~= false) then
                    tinsert(scales, { name = name, scale = scale })
                end
            end
        end
        table.sort(scales, function(a, b)
            return (a.scale.DisplayName or a.name) < (b.scale.DisplayName or b.name)
        end)
        for _, scaleData in ipairs(scales) do
            info.text = GetCharScaleDisplayText(scaleData.name, true)
            info.value = scaleData.name
            info.checked = (Valuate:GetOptions().characterWindowScale == scaleData.name)
            info.func = function(self)
                Valuate:GetOptions().characterWindowScale = self.value
                UIDropDownMenu_SetText(charScaleDropdown, GetCharScaleDisplayText(self.value, true))
                Valuate:RefreshCharacterWindowDisplay()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    charScaleDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Character Window Scale", 1, 1, 1)
        GameTooltip:AddLine("Select which scale to display on the character window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    charScaleDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- ========================================
    -- Keybindings Section
    -- ========================================
    local keybindHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    keybindHeader:SetPoint("TOPLEFT", charScaleLabel, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    keybindHeader:SetText("Keybindings")
    keybindHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[3] = columnHeights[3] + (ELEMENT_SPACING * 3) + HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Open Valuate UI Keybind Button
    local keybindLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    keybindLabel:SetPoint("TOPLEFT", keybindHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    keybindLabel:SetText("Toggle UI:")
    
    local keybindButton = CreateStyledButton(col3, "Not Bound", settingsColumnWidth - 75, 24)
    keybindButton:SetPoint("LEFT", keybindLabel, "RIGHT", 5, 0)
    keybindButton:EnableKeyboard(false)  -- Only enable when capturing
    keybindButton:EnableMouseWheel(true)
    
    -- State variables for keybind capture
    local isCapturingKeybind = false
    local capturedKeys = {}
    
    -- Function to get current keybind text
    local function GetKeybindText()
        local key1, key2 = GetBindingKey("VALUATE_TOGGLE_UI")
        if key1 then
            return key1
        else
            return "Not Bound"
        end
    end
    
    -- Function to format key name for display
    local function FormatKeyName(key)
        if not key then return "Not Bound" end
        -- Make it more readable
        key = key:gsub("CTRL%-", "Ctrl+")
        key = key:gsub("ALT%-", "Alt+")
        key = key:gsub("SHIFT%-", "Shift+")
        key = key:gsub("BUTTON", "Mouse")
        return key
    end
    
    -- Update button text
    keybindButton.label:SetText(FormatKeyName(GetKeybindText()))
    
    -- Start capturing keybind
    local function StartKeybindCapture()
        isCapturingKeybind = true
        capturedKeys = {}
        keybindButton.label:SetText("Press Key...")
        keybindButton:SetBackdropColor(0.2, 0.3, 0.5, 1)
        keybindButton:EnableKeyboard(true)  -- Enable keyboard capture
    end
    
    -- Stop capturing keybind
    local function StopKeybindCapture()
        isCapturingKeybind = false
        capturedKeys = {}
        keybindButton.label:SetText(FormatKeyName(GetKeybindText()))
        keybindButton:SetBackdropColor(unpack(COLORS.buttonBg))
        keybindButton:EnableKeyboard(false)  -- Disable keyboard capture
    end
    
    -- Set the keybind
    local function SetKeybind(key)
        if key and key ~= "" then
            local oldBinding = GetBindingAction(key)
            if oldBinding and oldBinding ~= "" and oldBinding ~= "VALUATE_TOGGLE_UI" then
                -- Warn about overwriting existing binding
                print("|cFFFFFF00Valuate|r: Key " .. FormatKeyName(key) .. " was bound to " .. oldBinding .. ", now bound to Valuate.")
            end
            
            -- Clear old bindings for VALUATE_TOGGLE_UI
            local key1, key2 = GetBindingKey("VALUATE_TOGGLE_UI")
            if key1 then SetBinding(key1) end
            if key2 then SetBinding(key2) end
            
            -- Set new binding
            SetBinding(key, "VALUATE_TOGGLE_UI")
            SaveBindings(GetCurrentBindingSet())
        end
        StopKeybindCapture()
    end
    
    -- Clear the keybind
    local function ClearKeybind()
        local key1, key2 = GetBindingKey("VALUATE_TOGGLE_UI")
        if key1 then SetBinding(key1) end
        if key2 then SetBinding(key2) end
        SaveBindings(GetCurrentBindingSet())
        keybindButton.label:SetText("Not Bound")
    end
    
    -- Button click handler
    keybindButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Right-click to clear
            ClearKeybind()
        elseif not isCapturingKeybind then
            -- Left-click to start capture
            StartKeybindCapture()
        end
    end)
    
    -- Capture key presses
    keybindButton:SetScript("OnKeyDown", function(self, key)
        if not isCapturingKeybind then return end
        
        -- Allow escape to cancel
        if key == "ESCAPE" then
            StopKeybindCapture()
            return
        end
        
        -- Ignore modifier keys by themselves (wait for actual key press)
        if key == "LSHIFT" or key == "RSHIFT" or 
           key == "LCTRL" or key == "RCTRL" or 
           key == "LALT" or key == "RALT" then
            return
        end
        
        -- Build modifier prefix
        local modifier = ""
        if IsShiftKeyDown() then modifier = modifier .. "SHIFT-" end
        if IsControlKeyDown() then modifier = modifier .. "CTRL-" end
        if IsAltKeyDown() then modifier = modifier .. "ALT-" end
        
        -- Construct full key binding
        local fullKey = modifier .. key
        SetKeybind(fullKey)
    end)
    
    -- Capture mouse clicks
    keybindButton:SetScript("OnMouseDown", function(self, button)
        if not isCapturingKeybind then return end
        if button == "LeftButton" or button == "RightButton" then return end
        
        -- Build modifier prefix
        local modifier = ""
        if IsShiftKeyDown() then modifier = modifier .. "SHIFT-" end
        if IsControlKeyDown() then modifier = modifier .. "CTRL-" end
        if IsAltKeyDown() then modifier = modifier .. "ALT-" end
        
        -- Construct mouse button binding
        local mouseKey = modifier .. string.upper(button)
        SetKeybind(mouseKey)
    end)
    
    keybindButton:SetScript("OnEnter", function(self)
        if not isCapturingKeybind then
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            self:SetBackdropBorderColor(unpack(COLORS.borderLight))
        end
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Toggle UI Keybind", 1, 1, 1)
        GameTooltip:AddLine("Left-click to set a new keybind.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click to clear the keybind.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    
    keybindButton:SetScript("OnLeave", function(self)
        if not isCapturingKeybind then
            self:SetBackdropColor(unpack(COLORS.buttonBg))
            self:SetBackdropBorderColor(unpack(COLORS.border))
        end
        GameTooltip:Hide()
    end)
    
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- ========================================
    -- Advanced Section
    -- ========================================
    local advancedHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    advancedHeader:SetPoint("TOPLEFT", keybindLabel, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    advancedHeader:SetText("Advanced")
    advancedHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[3] = columnHeights[3] + (ELEMENT_SPACING * 3) + HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Debug Mode checkbox (moved from Column 2)
    local debugCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
    debugCheckbox:SetSize(24, 24)
    debugCheckbox:SetPoint("TOPLEFT", advancedHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local debugLabel = debugCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    debugLabel:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
    debugLabel:SetText("Debug Mode")
    debugCheckbox:SetChecked(Valuate:GetOptions().debug == true)
    debugCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().debug = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- ========================================
    -- Delete Saved Variables Button (Bottom Right)
    -- ========================================
    local deleteButton = CreateStyledButton(parent, "Delete Saved Variables", 180, 30)
    deleteButton:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING, PADDING)
    
    -- Override border color to red
    deleteButton:SetBackdropBorderColor(0.8, 0, 0, 1)
    
    -- Custom hover effects for red border
    deleteButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
        self:SetBackdropBorderColor(1, 0.2, 0.2, 1)  -- Brighter red on hover
        if ShowTooltipSafe(self, "ANCHOR_TOP") then
            GameTooltip:AddLine("Delete Saved Variables", 1, 0.2, 0.2)
            GameTooltip:AddLine("Deletes all addon data including scales and settings.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("This action requires a UI reload.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    deleteButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonBg))
        self:SetBackdropBorderColor(0.8, 0, 0, 1)  -- Back to red
        GameTooltip:Hide()
    end)
    
    -- Click handler with confirmation dialog
    deleteButton:SetScript("OnClick", function(self)
        Valuate:ShowConfirmDialog({
            text = "Are you sure you want to delete ALL Valuate saved data?\n\nThis will delete:\n- All scales\n- All settings\n- All options\n\nThis action cannot be undone!\n\nThe UI will reload after deletion.",
            acceptText = "Delete Everything",
            cancelText = "Cancel",
            onAccept = function()
                -- Clear all saved variables (per-character)
                ValuateOptions = nil
                ValuateScales = nil

                -- Reload UI to reinitialize with defaults
                ReloadUI()
            end,
        })
    end)
    
    -- Store references for updating
    parent.charScaleDropdown = charScaleDropdown
    parent.GetCharScaleDisplayText = GetCharScaleDisplayText

    -- Structural safeguard: warn immediately if any column has overlapping controls.
    CheckColumnAnchors(col1, "column 1")
    CheckColumnAnchors(col2, "column 2")
    CheckColumnAnchors(col3, "column 3")

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


