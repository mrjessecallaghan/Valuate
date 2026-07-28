-- ui/Pickers.lua
-- The icon picker and the two template pickers (full and class-specific), plus the
-- role-icon helpers they share.
--
-- Their frame state (IconPickerFrame, TemplatePickerFrame, ...) stays FILE-LOCAL: only
-- these pickers touch it, so it never needed the ns.X treatment that genuinely shared
-- state got. ValuateUI_ShowFullTemplatePicker / ValuateUI_ShowTemplatePicker remain
-- globals because they are invoked from outside this file.

local _, ns = ...

local PADDING, ELEMENT_SPACING, INNER_SPACING = ns.PADDING, ns.ELEMENT_SPACING, ns.INNER_SPACING
local BUTTON_HEIGHT, SCROLLBAR_WIDTH = ns.BUTTON_HEIGHT, ns.SCROLLBAR_WIDTH
local COLORS = ns.COLORS
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local SCALE_ICON_LIST, CLASS_SPEC_TEMPLATES = ns.SCALE_ICON_LIST, ns.CLASS_SPEC_TEMPLATES
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
local HexToRGB = ns.HexToRGB

-- Picker frame state (file-local by design - see header)
local IconPickerFrame = nil
local IconPickerCallback = nil
local TemplatePickerFrame = nil       -- Full picker (all classes)
local ClassSpecificPickerFrame = nil  -- Class-specific picker

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

ns.ShowIconPicker = ShowIconPicker
ns.GetRoleIconAndCoords = GetRoleIconAndCoords
ns.GetRoleName = GetRoleName
