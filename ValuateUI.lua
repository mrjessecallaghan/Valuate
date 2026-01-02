-- ValuateUI.lua
-- UI Window for Valuate stat weight calculator

-- ========================================
-- UI Constants
-- ========================================

-- Window dimensions
local WINDOW_WIDTH = 950
local WINDOW_HEIGHT = 600

-- Standardized spacing
local PADDING = 12              -- Outer padding from window edges
local ELEMENT_SPACING = 8       -- Between major UI sections
local INNER_SPACING = 4         -- Within elements
local COLUMN_GAP = 6            -- Gap between stat columns

-- Component sizing
local BUTTON_HEIGHT = 24
local ENTRY_HEIGHT = 24
local SCROLLBAR_WIDTH = 20      -- Width reserved for scrollbars (18px bar + 2px gap)

-- Stat editor sizing (4-column layout)
local COLUMN_WIDTH = 160        -- Each stat column width
local ROW_HEIGHT = 16           -- Stat row height
local ROW_SPACING = 1           -- Spacing between stat rows
local HEADER_HEIGHT = 14        -- Category header height
local HEADER_SPACING = 6        -- Spacing above headers

-- Scale list sizing
local SCALE_LIST_WIDTH = 200    -- Left panel width for scale list

-- ========================================
-- Color Palette (Modern, clean look)
-- ========================================
local COLORS = {
    -- Backgrounds
    windowBg = { 0.06, 0.06, 0.06, 0.98 },
    panelBg = { 0.04, 0.04, 0.04, 0.95 },
    inputBg = { 0.08, 0.08, 0.08, 0.95 },
    buttonBg = { 0.15, 0.15, 0.15, 1 },
    buttonHover = { 0.22, 0.22, 0.22, 1 },
    buttonPressed = { 0.1, 0.1, 0.1, 1 },
    
    -- Borders
    border = { 0.35, 0.35, 0.35, 1 },
    borderLight = { 0.45, 0.45, 0.45, 1 },
    borderDark = { 0.25, 0.25, 0.25, 1 },
    
    -- Text
    textTitle = { 0.9, 0.9, 0.9, 1 },
    textHeader = { 0.75, 0.75, 0.75, 1 },
    textBody = { 0.85, 0.85, 0.85, 1 },
    textDim = { 0.5, 0.5, 0.5, 1 },
    textAccent = { 0.4, 0.7, 0.9, 1 },  -- Soft blue accent
    
    -- States
    selected = { 0.25, 0.45, 0.65, 1 },
    selectedBorder = { 0.4, 0.6, 0.8, 1 },
    disabled = { 0.3, 0.3, 0.3, 0.6 },
}

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

-- Font Standards (all use white/highlight fonts for modern look)
local FONT_TITLE = "GameFontHighlightLarge"    -- ~16pt, white
local FONT_H1 = "GameFontHighlight"            -- ~12pt, white  
local FONT_H2 = "GameFontHighlightSmall"       -- ~10pt, white
local FONT_H3 = "GameFontHighlightSmall"       -- ~10pt, white
local FONT_BODY = "GameFontHighlight"          -- ~12pt, white
local FONT_SMALL = "GameFontHighlightSmall"    -- ~10pt, white

-- Main UI Frame
local ValuateUIFrame = nil
local CurrentSelectedScale = nil
local EditingScaleName = nil
local OriginalScaleData = nil

-- Icon Picker state
local IconPickerFrame = nil
local IconPickerCallback = nil

-- Curated icon list (safe, common icons that exist in WotLK 3.3.5a)
local SCALE_ICON_LIST = {
    -- Classes
    "Interface\\Icons\\ClassIcon_Warrior",
    "Interface\\Icons\\ClassIcon_Paladin",
    "Interface\\Icons\\ClassIcon_Hunter",
    "Interface\\Icons\\ClassIcon_Rogue",
    "Interface\\Icons\\ClassIcon_Priest",
    "Interface\\Icons\\ClassIcon_DeathKnight",
    "Interface\\Icons\\ClassIcon_Shaman",
    "Interface\\Icons\\ClassIcon_Mage",
    "Interface\\Icons\\ClassIcon_Warlock",
    "Interface\\Icons\\ClassIcon_Druid",
    
    -- Stats/Combat
    "Interface\\Icons\\Ability_Warrior_OffensiveStance",  -- Melee DPS
    "Interface\\Icons\\Spell_Holy_HolyBolt",              -- Healer
    "Interface\\Icons\\Ability_Defend",                    -- Tank
    "Interface\\Icons\\Spell_Fire_FireBolt02",            -- Caster
    "Interface\\Icons\\INV_Sword_04",                      -- Physical
    "Interface\\Icons\\Spell_Nature_StarFall",            -- Balance
    "Interface\\Icons\\Ability_DualWield",                 -- Dual Wield
    "Interface\\Icons\\INV_Shield_06",                     -- Shield
    "Interface\\Icons\\Spell_Shadow_ShadowBolt",          -- Shadow
    "Interface\\Icons\\Spell_Nature_Lightning",           -- Nature
    "Interface\\Icons\\Spell_Frost_FrostBolt02",          -- Frost
    "Interface\\Icons\\Spell_Holy_HolySmite",             -- Holy
    
    -- Generic/Misc
    "Interface\\Icons\\INV_Misc_Gear_01",
    "Interface\\Icons\\Trade_Engineering",
    "Interface\\Icons\\INV_Helmet_25",
    "Interface\\Icons\\Achievement_PVP_A_01",
    "Interface\\Icons\\Achievement_PVP_H_01",
    "Interface\\Icons\\INV_Jewelry_Ring_03",
    "Interface\\Icons\\INV_Misc_Book_09",
    "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
    "",  -- Empty = no icon (clear selection)
}

-- ValuateOptions and ValuateScales are initialized by Valuate:Initialize() in Valuate.lua
-- as simple SavedVariables tables

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

-- Creates a styled button with consistent look
local function CreateStyledButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width or 100)
    btn:SetHeight(height or BUTTON_HEIGHT)
    btn:SetBackdrop(BACKDROP_BUTTON)
    btn:SetBackdropColor(unpack(COLORS.buttonBg))
    btn:SetBackdropBorderColor(unpack(COLORS.border))
    
    local label = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text or "")
    label:SetTextColor(unpack(COLORS.textBody))
    btn.label = label
    
    -- Hover and click effects
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
        self:SetBackdropBorderColor(unpack(COLORS.borderLight))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonBg))
        self:SetBackdropBorderColor(unpack(COLORS.border))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonPressed))
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
    end)
    
    return btn
end

-- ========================================
-- Icon Picker Frame
-- ========================================

local function CreateIconPickerFrame()
    local frame = CreateFrame("Frame", "ValuateIconPickerFrame", UIParent)
    frame:SetSize(296, 220)
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
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
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
    
    -- Icon grid (8 columns x 4 rows = 32 icons visible)
    local ICONS_PER_ROW = 8
    local ICON_SIZE = 28
    local ICON_SPACING = 4
    
    frame.iconButtons = {}
    for i, iconPath in ipairs(SCALE_ICON_LIST) do
        local row = math.floor((i - 1) / ICONS_PER_ROW)
        local col = (i - 1) % ICONS_PER_ROW
        
        local iconBtn = CreateFrame("Button", nil, frame)
        iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
        iconBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 
            16 + col * (ICON_SIZE + ICON_SPACING),
            -40 - row * (ICON_SIZE + ICON_SPACING))
        
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
        if iconPath == "" then
            -- "None" icon - show an X or clear indicator
            tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        else
            tex:SetTexture(iconPath)
        end
        iconBtn.iconPath = iconPath
        iconBtn.tex = tex
        
        iconBtn:SetScript("OnClick", function(self)
            if IconPickerCallback then
                IconPickerCallback(self.iconPath)
            end
            frame:Hide()
        end)
        
        iconBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            -- Show tooltip for "None" option
            if self.iconPath == "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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
        
        frame.iconButtons[i] = iconBtn
    end
    
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
-- Main Window Creation
-- ========================================

local function CreateMainWindow()
    if ValuateUIFrame then
        return ValuateUIFrame
    end
    
    -- Main frame
    local frame = CreateFrame("Frame", "ValuateUIFrame", UIParent)
    frame:SetWidth(WINDOW_WIDTH)
    frame:SetHeight(WINDOW_HEIGHT)
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
    if ValuateOptions and ValuateOptions.uiPosition and ValuateOptions.uiPosition.point and ValuateOptions.uiPosition.x and ValuateOptions.uiPosition.y then
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
        if ValuateOptions then
            if not ValuateOptions.uiPosition then
                ValuateOptions.uiPosition = {}
            end
            local point, _, relativePoint, x, y = self:GetPoint()
            ValuateOptions.uiPosition.point = point
            ValuateOptions.uiPosition.relativePoint = relativePoint
            ValuateOptions.uiPosition.x = x
            ValuateOptions.uiPosition.y = y
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
    ValuateUIFrame = frame
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
        
        -- Show selected panel
        if tabPanels[tabName] then
            tabPanels[tabName]:Show()
        end
        
        -- Update tab buttons - selected vs unselected appearance
        for name, btn in pairs(tabs) do
            if name == tabName then
                -- Selected tab: brighter background and border
                btn:SetBackdropColor(unpack(COLORS.buttonHover))
                btn:SetBackdropBorderColor(unpack(COLORS.borderLight))
                btn.label:SetTextColor(unpack(COLORS.textBody))
            else
                -- Unselected tab: darker, recessed look
                btn:SetBackdropColor(unpack(COLORS.buttonPressed))
                btn:SetBackdropBorderColor(unpack(COLORS.borderDark))
                btn.label:SetTextColor(unpack(COLORS.textDim))
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
    
    local instructionsPanel = CreateFrame("Frame", nil, contentFrame)
    instructionsPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    instructionsPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    instructionsPanel:Hide()
    
    local settingsPanel = CreateFrame("Frame", nil, contentFrame)
    settingsPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    settingsPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    settingsPanel:Hide()
    
    -- Create tabs (Scales on left, Instructions and Settings on right)
    CreateTab("scales", "Scales", scalesPanel, "left")
    
    -- Create Settings tab first (anchored to right)
    local settingsTab = CreateTab("settings", "Settings", settingsPanel, "right")
    
    -- Create Instructions tab to the left of Settings
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
    
    -- Size button based on text
    instructionsBtn:SetWidth(instructionsLabel:GetStringWidth() + 40)
    
    -- Position Instructions tab to the left of Settings tab
    instructionsBtn:SetPoint("RIGHT", settingsTab, "LEFT", -4, 0)
    
    tabs["instructions"] = instructionsBtn
    tabPanels["instructions"] = instructionsPanel
    
    -- Select default tab
    SelectTab("scales")
    
    return {
        frame = tabFrame,
        scalesPanel = scalesPanel,
        instructionsPanel = instructionsPanel,
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
            local scale = ValuateScales[scaleData.name]
            if not scale then return end
            
            local currentColor = scale.Color or "FFFFFF"
            local cr, cg, cb = HexToRGB(currentColor)
            
            -- Store reference for callback
            local scaleName = scaleData.name
            
            ColorPickerFrame.previousValues = { cr, cg, cb }
            
            ColorPickerFrame.func = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newColor = RGBToHex(newR, newG, newB)
                if ValuateScales[scaleName] then
                    ValuateScales[scaleName].Color = newColor
                end
                colorPreview:SetVertexColor(newR, newG, newB, 1)
                -- Update the scale list to reflect new color
                UpdateScaleList()
            end
            
            ColorPickerFrame.cancelFunc = function()
                local prev = ColorPickerFrame.previousValues
                if prev and ValuateScales[scaleName] then
                    ValuateScales[scaleName].Color = RGBToHex(prev[1], prev[2], prev[3])
                end
                UpdateScaleList()
            end
            
            ColorPickerFrame.opacityFunc = nil
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(cr, cg, cb)
            ColorPickerFrame:Show()
        end)
        
        colorBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Change Color", 1, 1, 1)
            GameTooltip:AddLine("Click to change this scale's display color.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
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
                if ValuateScales[scaleName] then
                    ValuateScales[scaleName].Icon = selectedIcon
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
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Change Icon", 1, 1, 1)
            GameTooltip:AddLine("Click to select an icon for this scale's tooltip display.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
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
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Delete Scale", 1, 1, 1)
            GameTooltip:AddLine("Click to delete this scale.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        deleteBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            deleteLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            GameTooltip:Hide()
        end)
        deleteBtn:SetScript("OnClick", function(self)
            local scaleName = scaleData.name
            StaticPopupDialogs["VALUATE_DELETE_SCALE"] = {
                text = "Are you sure you want to delete the scale \"" .. (scaleData.scale.DisplayName or scaleName) .. "\"?",
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function()
                    ValuateScales[scaleName] = nil
                    if CurrentSelectedScale == scaleName then
                        CurrentSelectedScale = nil
                        EditingScaleName = nil
                        if ScaleEditorFrame and ScaleEditorFrame.container then
                            ScaleEditorFrame.container:Hide()
                        end
                    end
                    UpdateScaleList()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("VALUATE_DELETE_SCALE")
        end)
        
        -- Scale name
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        nameLabel:SetPoint("LEFT", iconBtn, "RIGHT", 4, 0)
        nameLabel:SetPoint("RIGHT", deleteBtn, "LEFT", -4, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText(scaleData.scale.DisplayName or scaleData.name)
        
        -- Helper to update visual state based on visibility
        local function UpdateVisualState(visible)
            -- Get current color from scale data (may have been updated by color picker)
            local currentColor = (ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Color) or "FFFFFF"
            local cr, cg, cb = HexToRGB(currentColor)
            
            -- Get current icon from scale data
            local currentScaleIcon = ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Icon
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
                    self:SetBackdropColor(unpack(COLORS.buttonHover))
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if CurrentSelectedScale ~= scaleData.name then
                local vis = ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Visible ~= false
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
            if CurrentSelectedScale and ScaleListButtons[CurrentSelectedScale] then
                local prevBtn = ScaleListButtons[CurrentSelectedScale]
                local prevVis = ValuateScales[CurrentSelectedScale] and ValuateScales[CurrentSelectedScale].Visible ~= false
                if prevVis then
                    prevBtn:SetBackdropColor(unpack(COLORS.buttonBg))
                    prevBtn:SetBackdropBorderColor(unpack(COLORS.border))
                else
                    prevBtn:SetBackdropColor(unpack(COLORS.disabled))
                    prevBtn:SetBackdropBorderColor(unpack(COLORS.borderDark))
                end
            end
            
            -- Select this one
            CurrentSelectedScale = scaleData.name
            self:SetBackdropColor(unpack(COLORS.selected))
            self:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
            
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
    local newButton = CreateStyledButton(container, "New Scale", nil, BUTTON_HEIGHT)
    newButton:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    newButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    newButton:SetScript("OnClick", function()
        ValuateUI_NewScale()
    end)
    
    -- Scroll frame for scale list (reserves space for scrollbar on right)
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("TOPRIGHT", newButton, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 0)
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
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(unpack(COLORS.windowBg))
    scrollBarBg:SetBackdropBorderColor(unpack(COLORS.borderDark))
    
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

-- Helper to create a stat row
local function CreateStatRow(parent, statName, scale, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(COLUMN_WIDTH)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    
    -- Stat label (shorter width for 4-column layout)
    local label = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(75)
    label:SetJustifyH("RIGHT")
    label:SetText((ValuateStatNames[statName] or statName) .. ":")
    
    -- Value input (compact)
    local editBox = CreateFrame("EditBox", nil, row)
    editBox:SetHeight(14)
    editBox:SetWidth(38)
    editBox:SetPoint("LEFT", label, "RIGHT", 2, 0)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(_G[FONT_SMALL])
    editBox:SetJustifyH("CENTER")
    editBox:SetBackdrop(BACKDROP_INPUT)
    editBox:SetBackdropColor(unpack(COLORS.inputBg))
    editBox:SetBackdropBorderColor(unpack(COLORS.border))
    editBox:SetTextInsets(2, 2, 0, 0)
    editBox.statName = statName
    
    -- Focus handling
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText()) or 0
        if EditingScaleName and ValuateScales[EditingScaleName] then
            local scale = ValuateScales[EditingScaleName]
            if not scale.Values then scale.Values = {} end
            if value ~= 0 then
                scale.Values[self.statName] = value
            else
                scale.Values[self.statName] = nil
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
        
        if EditingScaleName and ValuateScales[EditingScaleName] then
            local currentScale = ValuateScales[EditingScaleName]
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
        end
        
        UpdateBannedState(checked)
    end)
    
    -- Tooltip for unusable checkbox
    unusableCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Ban Stat", 1, 1, 1)
        GameTooltip:AddLine("Items with this stat won't show a score for this scale.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
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
    if not ScaleEditorFrame then return end
    
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
    
    -- Create 4 column frames
    local columnFrames = {}
    local columnHeights = {0, 0, 0, 0}
    
    for i = 1, 4 do
        local colFrame = CreateFrame("Frame", nil, ScaleEditorFrame)
        colFrame:SetWidth(COLUMN_WIDTH)
        colFrame:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", (i - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0)
        columnFrames[i] = colFrame
        tinsert(StatWeightRows, colFrame)
    end
    
    -- Populate each column with its categories
    for _, category in ipairs(ValuateStatCategories) do
        local col = category.column
        if col and col >= 1 and col <= 4 and columnFrames[col] then
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
    
    -- Find tallest column for scroll height (core stats section)
    local coreMaxHeight = 0
    for i = 1, 4 do
        if columnHeights[i] > coreMaxHeight then
            coreMaxHeight = columnHeights[i]
        end
    end
    
    -- Set column frame heights for core stats
    for i = 1, 4 do
        columnFrames[i]:SetHeight(coreMaxHeight)
    end
    
    -- ========================================
    -- Equipment Types Section (below core stats)
    -- ========================================
    local equipmentStartY = coreMaxHeight + ELEMENT_SPACING * 2
    
    if ValuateEquipmentCategories then
        -- Equipment section header
        local equipHeader = CreateFrame("Frame", nil, ScaleEditorFrame)
        equipHeader:SetHeight(HEADER_HEIGHT + 4)
        equipHeader:SetWidth(4 * COLUMN_WIDTH + 3 * COLUMN_GAP)
        equipHeader:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", 0, -equipmentStartY)
        
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
        
        local equipStartY = equipmentStartY + HEADER_HEIGHT + ELEMENT_SPACING
        
        -- Create equipment column frames
        local equipColumnFrames = {}
        local equipColumnHeights = {0, 0, 0, 0}
        
        for i = 1, 4 do
            local colFrame = CreateFrame("Frame", nil, ScaleEditorFrame)
            colFrame:SetWidth(COLUMN_WIDTH)
            colFrame:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", (i - 1) * (COLUMN_WIDTH + COLUMN_GAP), -equipStartY)
            equipColumnFrames[i] = colFrame
            tinsert(StatWeightRows, colFrame)
        end
        
        -- Populate equipment categories
        for _, category in ipairs(ValuateEquipmentCategories) do
            local col = category.column
            if col and col >= 1 and col <= 4 and equipColumnFrames[col] then
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
        for i = 1, 4 do
            if equipColumnHeights[i] > equipMaxHeight then
                equipMaxHeight = equipColumnHeights[i]
            end
        end
        
        -- Set equipment column heights
        for i = 1, 4 do
            equipColumnFrames[i]:SetHeight(equipMaxHeight)
        end
        
        -- Total height includes equipment section
        coreMaxHeight = equipStartY + equipMaxHeight
    end
    
    -- Update content frame height for scrolling
    if ScaleEditorFrame and ScaleEditorFrame.scrollFrame then
        ScaleEditorFrame:SetHeight(math.max(coreMaxHeight, 100))
        
        local scrollFrame = ScaleEditorFrame.scrollFrame
        local scrollBar = scrollFrame.scrollBar
        if scrollBar then
            local scrollFrameHeight = scrollFrame:GetHeight()
            local maxScroll = math.max(0, coreMaxHeight - scrollFrameHeight)
            scrollBar:SetMinMaxValues(0, maxScroll)
            scrollBar:SetValue(0)
        end
    end
end

function ValuateUI_UpdateScaleEditor(scaleName, scale)
    EditingScaleName = scaleName
    
    if not ScaleEditorFrame then return end
    
    -- Show the editor container
    if ScaleEditorFrame.container then
        ScaleEditorFrame.container:Show()
    end
    
    -- Update name field
    if ScaleEditorFrame.nameEditBox then
        ScaleEditorFrame.nameEditBox:SetText(scale.DisplayName or scaleName)
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
    dialog:SetFrameStrata("DIALOG")
    dialog:SetBackdrop(BACKDROP_WINDOW)
    dialog:SetBackdropColor(unpack(COLORS.windowBg))
    dialog:SetBackdropBorderColor(unpack(COLORS.border))
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
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
    local scale = self.db.profile.Scales[scaleName]
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
        local status, scaleName = self:ImportScale(text, true)  -- Allow overwrite
        
        if status == Valuate.ImportResult.SUCCESS then
            print("|cFF00FF00Valuate|r: Successfully imported scale |cFFFFFFFF" .. scaleName .. "|r")
            
            -- Refresh the UI if it's open
            if ValuateUIFrame and ValuateUIFrame:IsShown() then
                UpdateScaleList()
                -- Select the imported scale
                if ScaleListButtons[scaleName] then
                    ScaleListButtons[scaleName]:GetScript("OnClick")(ScaleListButtons[scaleName])
                end
            end
        elseif status == Valuate.ImportResult.ALREADY_EXISTS then
            print("|cFF00FF00Valuate|r: Overwrote existing scale |cFFFFFFFF" .. scaleName .. "|r")
            
            -- Refresh the UI
            if ValuateUIFrame and ValuateUIFrame:IsShown() then
                UpdateScaleList()
                if ScaleListButtons[scaleName] then
                    ScaleListButtons[scaleName]:GetScript("OnClick")(ScaleListButtons[scaleName])
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
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", SCALE_LIST_WIDTH + PADDING, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Header area (non-scrolling) for Scale Name - reduced height
    local headerFrame = CreateFrame("Frame", nil, container)
    headerFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
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
        if not EditingScaleName or not ValuateScales[EditingScaleName] then
            self:ClearFocus()
            return
        end
        
        local newName = self:GetText()
        if newName and newName ~= "" then
            local scale = ValuateScales[EditingScaleName]
            scale.DisplayName = newName
            
            -- If the name changed, update the scale key
            if newName ~= EditingScaleName then
                ValuateScales[newName] = scale
                ValuateScales[EditingScaleName] = nil
                EditingScaleName = newName
                CurrentSelectedScale = newName
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
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Import Scale", 1, 1, 1)
        GameTooltip:AddLine("Import a scale from a scale tag.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    importButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Export button
    local exportButton = CreateStyledButton(headerFrame, "Export", 80, 22)
    exportButton:SetPoint("LEFT", importButton, "RIGHT", ELEMENT_SPACING, 0)
    exportButton:SetScript("OnClick", function(self)
        if not EditingScaleName or not ValuateScales[EditingScaleName] then
            return
        end
        Valuate:ShowExportDialog(EditingScaleName)
    end)
    exportButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Export Scale", 1, 1, 1)
        GameTooltip:AddLine("Export the current scale as a scale tag to share with others.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    exportButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Reset button to clear all values (moved to the right)
    local resetButton = CreateStyledButton(headerFrame, "Reset Values", 90, 22)
    resetButton:SetPoint("LEFT", exportButton, "RIGHT", ELEMENT_SPACING, 0)
    resetButton:SetScript("OnClick", function(self)
        if not EditingScaleName or not ValuateScales[EditingScaleName] then
            return
        end
        
        local scaleName = EditingScaleName
        local scale = ValuateScales[scaleName]
        
        StaticPopupDialogs["VALUATE_RESET_SCALE"] = {
            text = "Are you sure you want to reset all values in the scale \"" .. (scale.DisplayName or scaleName) .. "\" to blank?",
            button1 = "Reset",
            button2 = "Cancel",
            OnAccept = function()
                -- Clear all values and unusable flags
                scale.Values = {}
                scale.Unusable = {}
                
                -- Refresh the editor display
                ValuateUI_UpdateScaleEditor(scaleName, scale)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("VALUATE_RESET_SCALE")
    end)
    
    -- Scroll frame for stat weights (below header, reserves space for scrollbar on right)
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 40)
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
    -- Width for 4 columns: 4 * COLUMN_WIDTH + 3 * COLUMN_GAP
    contentFrame:SetWidth(4 * COLUMN_WIDTH + 3 * COLUMN_GAP)
    contentFrame:SetHeight(600)  -- Initial height, updated dynamically
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop for visibility
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 0)
    scrollBarBg:SetWidth(SCROLLBAR_WIDTH)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(unpack(COLORS.windowBg))
    scrollBarBg:SetBackdropBorderColor(unpack(COLORS.borderDark))
    
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
    ScaleEditorFrame.statsHeader = statsHeader
    
    
    container:Hide()
    return container
end

-- ========================================
-- Instructions Panel
-- ========================================

local function CreateInstructionsPanel(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Scroll frame for instructions content
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", PADDING, -PADDING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SCROLLBAR_WIDTH - PADDING, PADDING)
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
    
    -- Content frame for text
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(scrollFrame:GetWidth() - PADDING * 2)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -PADDING, PADDING)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(unpack(COLORS.windowBg))
    scrollBarBg:SetBackdropBorderColor(unpack(COLORS.borderDark))
    
    -- Scrollbar
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
    
    -- Helper function to create a section header
    local function CreateSectionHeader(text, yOffset)
        local header = contentFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
        header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        header:SetPoint("RIGHT", contentFrame, "RIGHT", -PADDING, 0)
        header:SetJustifyH("LEFT")
        header:SetText(text)
        header:SetTextColor(unpack(COLORS.textAccent))
        return header
    end
    
    -- Helper function to create body text
    local function CreateBodyText(text, yOffset, width)
        local body = contentFrame:CreateFontString(nil, "OVERLAY", FONT_BODY)
        body:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        body:SetWidth(width or (contentFrame:GetWidth() - PADDING * 2))
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetText(text)
        body:SetTextColor(unpack(COLORS.textBody))
        return body
    end
    
    -- Build instructions content
    local currentY = -PADDING
    local lineHeight = 16
    local sectionSpacing = 20
    local paragraphSpacing = 8
    
    -- Getting Started
    local header1 = CreateSectionHeader("Getting Started", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text1 = CreateBodyText("Open the Valuate UI by typing /valuate or /val in chat. The window can be moved by dragging the title bar.", currentY)
    local text1Height = text1:GetStringHeight()
    currentY = currentY - text1Height - sectionSpacing
    
    -- Managing Scales
    local header2 = CreateSectionHeader("Managing Scales", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text2 = CreateBodyText("• Create a new scale: Click the 'New Scale' button in the left panel.\n• Rename a scale: Select it, then edit the 'Scale Name' field at the top of the editor.\n• Delete a scale: Click the × button on a scale in the list.\n• Select a scale: Click on it in the left panel to edit its stat weights.", currentY)
    local text2Height = text2:GetStringHeight()
    currentY = currentY - text2Height - sectionSpacing
    
    -- Setting Stat Weights
    local header3 = CreateSectionHeader("Setting Stat Weights", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text3 = CreateBodyText("To set a stat weight, click in the value field next to the stat name and enter a number. IMPORTANT: Press Enter after typing the value to save it. The value will not be saved until you press Enter.", currentY)
    local text3Height = text3:GetStringHeight()
    currentY = currentY - text3Height - paragraphSpacing
    
    local text3b = CreateBodyText("Stats are organized into categories (Primary Stats, Secondary Stats, etc.) and displayed in columns. You can set weights for any stat that applies to your character.", currentY)
    local text3bHeight = text3b:GetStringHeight()
    currentY = currentY - text3bHeight - sectionSpacing
    
    -- Visibility and Colors
    local header4 = CreateSectionHeader("Visibility and Colors", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text4 = CreateBodyText("• Toggle visibility: Use the checkbox on the left of each scale to show or hide it in item tooltips.\n• Change color: Click the colored square next to the visibility checkbox to open a color picker. This color is used to display the scale name in tooltips.", currentY)
    local text4Height = text4:GetStringHeight()
    currentY = currentY - text4Height - sectionSpacing
    
    -- Banning Stats
    local header5 = CreateSectionHeader("Banning Stats", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text5 = CreateBodyText("If a stat is unusable for a particular scale (e.g., Intellect for a Warrior), check the box to the right of the stat value field. Banned stats will be grayed out and items with those stats won't show a score for that scale.", currentY)
    local text5Height = text5:GetStringHeight()
    currentY = currentY - text5Height - sectionSpacing
    
    -- Tooltip Display
    local header6 = CreateSectionHeader("Tooltip Display", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text6 = CreateBodyText("When you hover over an item, Valuate displays the calculated score for each visible scale. The score is based on the item's stats multiplied by your scale weights. Higher scores indicate better items for that scale.", currentY)
    local text6Height = text6:GetStringHeight()
    currentY = currentY - text6Height - sectionSpacing
    
    -- Settings Options
    local header7 = CreateSectionHeader("Settings Options", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text7 = CreateBodyText("• Decimal Places: Control how many decimal places are shown in scores (0-4).\n• Right-Align Scores: When enabled, scores align to the right in tooltips for easier comparison.\n• Show Scale Value: Toggle whether the item's calculated score appears on tooltips.\n• Comparison Mode: Choose how upgrade/downgrade differences are displayed (Number, Percentage, Both, or Off).", currentY)
    local text7Height = text7:GetStringHeight()
    currentY = currentY - text7Height - sectionSpacing
    
    -- Tips and Tricks
    local header8 = CreateSectionHeader("Tips and Tricks", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text8 = CreateBodyText("• Remember to press Enter after entering stat values - they won't save automatically!\n• Create multiple scales for different roles (e.g., 'DPS', 'Tank', 'Healer').\n• Use the visibility toggle to compare items for different builds without deleting scales.\n• Banned stats are useful for hybrid classes that can't use certain stats.\n• The scale name in the editor can be changed to rename the scale.", currentY)
    local text8Height = text8:GetStringHeight()
    currentY = currentY - text8Height - PADDING
    
    -- Set content frame height based on total content
    local totalHeight = math.abs(currentY) + PADDING
    contentFrame:SetHeight(math.max(totalHeight, scrollFrame:GetHeight()))
    
    -- Update scrollbar range
    local function UpdateScrollRange()
        local scrollFrameHeight = scrollFrame:GetHeight()
        local contentHeight = contentFrame:GetHeight()
        local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
        if scrollBar:GetValue() > maxScroll then
            scrollBar:SetValue(maxScroll)
        end
    end
    
    -- Update on frame size changes
    container:SetScript("OnSizeChanged", UpdateScrollRange)
    UpdateScrollRange()
    
    return container
end

-- ========================================
-- Settings Panel
-- ========================================

local function CreateSettingsPanel(parent)
    
    -- Safety check: ensure SavedVariables are initialized
    if not Valuate or not ValuateOptions or not ValuateScales then
        
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
    decimalEditBox:SetWidth(38)
    decimalEditBox:SetPoint("LEFT", decimalLabel, "RIGHT", 2, 0)
    decimalEditBox:SetAutoFocus(false)
    decimalEditBox:SetFontObject(_G[FONT_SMALL])
    decimalEditBox:SetJustifyH("CENTER")
    decimalEditBox:SetBackdrop(BACKDROP_INPUT)
    decimalEditBox:SetBackdropColor(unpack(COLORS.inputBg))
    decimalEditBox:SetBackdropBorderColor(unpack(COLORS.border))
    decimalEditBox:SetTextInsets(2, 2, 0, 0)
    decimalEditBox:SetNumeric(true)
    decimalEditBox:SetNumber(ValuateOptions.decimalPlaces or 1)
    decimalEditBox:SetScript("OnEnterPressed", function(self)
        local value = self:GetNumber()
        value = math.max(0, math.min(4, value))
        ValuateOptions.decimalPlaces = value
        self:SetNumber(value)
        self:ClearFocus()
        Valuate:RefreshCharacterWindowDisplay()
    end)
    decimalEditBox:SetScript("OnEscapePressed", function(self)
        self:SetNumber(ValuateOptions.decimalPlaces or 1)
        self:ClearFocus()
    end)
    
    -- Right-Align Scores checkbox (Column 1)
    local alignCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    alignCheckbox:SetSize(24, 24)
    alignCheckbox:SetPoint("TOPLEFT", decimalLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local alignLabel = alignCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    alignLabel:SetPoint("LEFT", alignCheckbox, "RIGHT", 5, 0)
    alignLabel:SetText("Right-Align Scores")
    alignCheckbox:SetChecked(ValuateOptions.rightAlign == true)
    alignCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.rightAlign = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Show Scale Value checkbox (Column 1) - moved from Column 2
    local showScaleCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    showScaleCheckbox:SetSize(24, 24)
    showScaleCheckbox:SetPoint("TOPLEFT", alignCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local showScaleLabel = showScaleCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    showScaleLabel:SetPoint("LEFT", showScaleCheckbox, "RIGHT", 5, 0)
    showScaleLabel:SetText("Show Scale Value")
    showScaleCheckbox:SetChecked(ValuateOptions.showScaleValue ~= false)
    showScaleCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.showScaleValue = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    showScaleCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Scale Value", 1, 1, 1)
        GameTooltip:AddLine("Display the item's calculated scale score on tooltips.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    showScaleCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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
        { value = "percent", text = "Percentage (+13.8%)" },
        { value = "both", text = "Both (+15.2, +13.8%)" },
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
    UIDropDownMenu_SetText(compModeDropdown, GetCompModeText(ValuateOptions.comparisonMode or "number"))
    
    -- Dropdown initialization function
    UIDropDownMenu_Initialize(compModeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(comparisonModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (ValuateOptions.comparisonMode or "number") == mode.value
            info.func = function(self)
                ValuateOptions.comparisonMode = self.value
                UIDropDownMenu_SetText(compModeDropdown, GetCompModeText(self.value))
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Tooltip for dropdown
    compModeDropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Comparison Mode", 1, 1, 1)
        GameTooltip:AddLine("Choose how upgrade/downgrade differences are displayed.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Number: Shows the score difference (+15.2)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Percentage: Shows the percent change (+13.8%)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Both: Shows both number and percentage", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Off: Disables upgrade comparison", 0.7, 0.7, 0.7)
        GameTooltip:Show()
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
    if ValuateOptions.minimapButtonHidden == nil then
        ValuateOptions.minimapButtonHidden = false
    end
    minimapButtonCheckbox:SetChecked(not ValuateOptions.minimapButtonHidden)
    minimapButtonCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        ValuateOptions.minimapButtonHidden = not checked
        if Valuate.ToggleMinimapButton then
            if checked then
                Valuate:ShowMinimapButton()
            else
                Valuate:HideMinimapButton()
            end
        end
    end)
    minimapButtonCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Minimap Button", 1, 1, 1)
        GameTooltip:AddLine("Toggle the Valuate minimap button.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    minimapButtonCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[2] = columnHeights[2] + 24 + ELEMENT_SPACING
    
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
    if ValuateOptions.showCharacterWindowDisplay == nil then
        ValuateOptions.showCharacterWindowDisplay = true
    end
    charWindowCheckbox:SetChecked(ValuateOptions.showCharacterWindowDisplay)
    charWindowCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        ValuateOptions.showCharacterWindowDisplay = checked
        Valuate:RefreshCharacterWindowVisibility()
    end)
    charWindowCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Scale Display", 1, 1, 1)
        GameTooltip:AddLine("Toggle the scale value display on the character window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
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
    
    if not ValuateOptions.characterWindowDisplayMode then
        ValuateOptions.characterWindowDisplayMode = "total"
    end
    UIDropDownMenu_SetText(charModeDropdown, GetDisplayModeText(ValuateOptions.characterWindowDisplayMode))
    
    UIDropDownMenu_Initialize(charModeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(displayModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (ValuateOptions.characterWindowDisplayMode == mode.value)
            info.func = function(self)
                ValuateOptions.characterWindowDisplayMode = self.value
                UIDropDownMenu_SetText(charModeDropdown, GetDisplayModeText(self.value))
                Valuate:RefreshCharacterWindowDisplay()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    charModeDropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Display Mode", 1, 1, 1)
        GameTooltip:AddLine("Total: Sum of all equipped item scores", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Average: Average score per slot", 0.8, 0.8, 0.8)
        GameTooltip:Show()
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
    
    local function GetCharScaleDisplayText(scaleName)
        if not scaleName or not ValuateScales or not ValuateScales[scaleName] then
            return "Select Scale"
        end
        local scale = ValuateScales[scaleName]
        return scale.DisplayName or scaleName
    end
    
    UIDropDownMenu_SetText(charScaleDropdown, GetCharScaleDisplayText(ValuateOptions.characterWindowScale))
    
    UIDropDownMenu_Initialize(charScaleDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local scales = {}
        if ValuateScales then
            for name, scale in pairs(ValuateScales) do
                if scale.Values and (scale.Visible ~= false) then
                    tinsert(scales, { name = name, scale = scale })
                end
            end
        end
        table.sort(scales, function(a, b)
            return (a.scale.DisplayName or a.name) < (b.scale.DisplayName or b.name)
        end)
        for _, scaleData in ipairs(scales) do
            info.text = GetCharScaleDisplayText(scaleData.name)
            info.value = scaleData.name
            info.checked = (ValuateOptions.characterWindowScale == scaleData.name)
            info.func = function(self)
                ValuateOptions.characterWindowScale = self.value
                UIDropDownMenu_SetText(charScaleDropdown, GetCharScaleDisplayText(self.value))
                Valuate:RefreshCharacterWindowDisplay()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    charScaleDropdown:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Character Window Scale", 1, 1, 1)
        GameTooltip:AddLine("Select which scale to display on the character window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
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
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Toggle UI Keybind", 1, 1, 1)
        GameTooltip:AddLine("Left-click to set a new keybind.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click to clear the keybind.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
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
    debugCheckbox:SetChecked(ValuateOptions.debug == true)
    debugCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.debug = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- Store references for updating
    parent.charScaleDropdown = charScaleDropdown
    parent.GetCharScaleDisplayText = GetCharScaleDisplayText
    
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
            
            -- Get item score using the main addon's function
            local stats = Valuate:GetStatsForItemLink(itemLink)
            local score = 0
            if stats then
                score = Valuate:CalculateItemScore(stats, scale) or 0
            end
            
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
    local selectedScaleName = ValuateOptions.characterWindowScale
    if not selectedScaleName or not ValuateScales or not ValuateScales[selectedScaleName] then
        return
    end
    
    local scale = ValuateScales[selectedScaleName]
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
    local decimals = ValuateOptions.decimalPlaces or 1
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
    
    CharacterWindowUpdating = true
    
    -- Get selected scale from options
    local selectedScaleName = ValuateOptions.characterWindowScale
    if not selectedScaleName or not ValuateScales or not ValuateScales[selectedScaleName] then
        -- Try to use first active scale
        local activeScales = Valuate:GetActiveScales()
        if #activeScales > 0 then
            selectedScaleName = activeScales[1]
            ValuateOptions.characterWindowScale = selectedScaleName
        else
            -- No scales available - hide display
            if CharacterWindowIconTexture then CharacterWindowIconTexture:Hide() end
            if CharacterWindowNameText then CharacterWindowNameText:SetText("") end
            if CharacterWindowScoreText then CharacterWindowScoreText:SetText("--") end
            CharacterWindowUpdating = false
            return
        end
    end
    
    local scale = ValuateScales[selectedScaleName]
    if not scale then
        if CharacterWindowIconTexture then CharacterWindowIconTexture:Hide() end
        if CharacterWindowNameText then CharacterWindowNameText:SetText("") end
        if CharacterWindowScoreText then CharacterWindowScoreText:SetText("--") end
        CharacterWindowUpdating = false
        return
    end
    
    local color = scale.Color or "FFFFFF"
    
    -- Update icon
    if CharacterWindowIconTexture then
        local icon = scale.Icon
        if icon and icon ~= "" then
            CharacterWindowIconTexture:SetTexture(icon)
            CharacterWindowIconTexture:Show()
            -- Reposition name text next to icon
            if CharacterWindowNameText then
                CharacterWindowNameText:SetPoint("LEFT", CharacterWindowIconTexture:GetParent(), "RIGHT", 4, 0)
            end
        else
            CharacterWindowIconTexture:Hide()
            -- Reposition name text to start of container
            if CharacterWindowNameText then
                CharacterWindowNameText:SetPoint("LEFT", CharacterWindowFrame, "LEFT", 6, 0)
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
        local decimals = ValuateOptions.decimalPlaces or 1
        local formatStr = "%." .. decimals .. "f"
        
        local displayMode = ValuateOptions.characterWindowDisplayMode or "total"
        local displayValue = totalScore
        
        if displayMode == "average" then
            -- Calculate average (total slots = 17, excluding shirt/tabard)
            local slotCount = #EquipmentSlots
            displayValue = slotCount > 0 and (totalScore / slotCount) or 0
        end
        
        local scoreText = string.format(formatStr, displayValue)
        CharacterWindowScoreText:SetText("|cFF" .. color .. scoreText .. "|r")
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
    if EditingScaleName and ValuateScales[EditingScaleName] then
        ValuateUI_UpdateScaleEditor(EditingScaleName, ValuateScales[EditingScaleName])
    end
end

function Valuate:RefreshCharacterWindowDisplay()
    if CharacterWindowFrame then
        UpdateCharacterWindowDisplay()
    end
end

-- Public API to refresh character window visibility (called from Settings toggle)
function Valuate:RefreshCharacterWindowVisibility()
    if not CharacterWindowFrame then return end
    
    local charFrame = GetCharacterFrame()
    if not charFrame then return end
    
    -- Check if feature is enabled
    if ValuateOptions.showCharacterWindowDisplay == false then
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
    
    if ValuateOptions and ValuateOptions.debug then
        local frameName = charFrame:GetName() or "unknown"
        print("|cFF00FF00[Valuate]|r Creating character window UI on " .. frameName)
    end
    
    -- Create sleek container button - compact size (Button so it's clickable)
    local container = CreateFrame("Button", "ValuateCharacterWindowFrame", charFrame)
    container:SetWidth(140)
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
            if not Valuate or not Valuate.GetActiveScales or not ValuateOptions or not ValuateScales then
                return
            end
            
            local activeScales = Valuate:GetActiveScales()
            if #activeScales == 0 then
                print("|cFFFF0000Valuate|r: No active scales available")
                return
            end
            
            -- Find current scale index
            local currentScale = ValuateOptions.characterWindowScale
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
            ValuateOptions.characterWindowScale = nextScale
            
            -- Show notification
            local scale = ValuateScales[nextScale]
            if scale then
                local color = scale.Color or "FFFFFF"
                local displayName = scale.DisplayName or nextScale
                print("|cFF00FF00Valuate|r: Switched to scale |cFF" .. color .. displayName .. "|r")
            end
            
            -- Refresh the display
            if Valuate.RefreshCharacterWindowDisplay then
                Valuate:RefreshCharacterWindowDisplay()
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
        GameTooltip:AddLine("Right-click to cycle scales", 0.7, 0.7, 0.7)
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
    
    -- Scale icon (small, left side)
    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(14, 14)
    iconFrame:SetPoint("LEFT", container, "LEFT", 5, 0)
    
    local iconTexture = iconFrame:CreateTexture(nil, "OVERLAY")
    iconTexture:SetAllPoints(iconFrame)
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconTexture:Hide()
    
    -- Scale name (small, colored)
    local nameText = container:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    nameText:SetPoint("LEFT", container, "LEFT", 6, 0)
    nameText:SetJustifyH("LEFT")
    
    -- Score display (right side)
    local scoreText = container:CreateFontString(nil, "OVERLAY", FONT_BODY)
    scoreText:SetPoint("RIGHT", container, "RIGHT", -6, 0)
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
            if CharacterWindowFrame and ValuateOptions then
                -- Only show if feature is enabled
                if ValuateOptions.showCharacterWindowDisplay ~= false then
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
    if ValuateOptions and charFrame:IsVisible() and ValuateOptions.showCharacterWindowDisplay ~= false then
        local initUpdateFrame = CreateFrame("Frame")
        initUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 0.3 then
                UpdateCharacterWindowDisplay()
                self:SetScript("OnUpdate", nil)
            end
        end)
    elseif ValuateOptions and ValuateOptions.showCharacterWindowDisplay == false then
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
    if ValuateOptions and ValuateOptions.debug then
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
        if ValuateOptions and ValuateOptions.debug then
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
    if ValuateOptions and ValuateOptions.debug then
        print("|cFF00FF00[Valuate]|r PLAYER_ENTERING_WORLD fired, AscensionCharacterFrame=" .. tostring(AscensionCharacterFrame ~= nil) .. ", PaperDollFrame=" .. tostring(PaperDollFrame ~= nil))
    end
    if not CharacterWindowInitialized then
        if charFrame then
            CreateCharacterWindowUI()
        elseif ValuateOptions and ValuateOptions.debug then
            print("|cFFFF0000[Valuate]|r Character frame not found after PLAYER_ENTERING_WORLD!")
        end
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- Also try immediately in case we loaded late (but only if SavedVariables are ready)
local charFrameInit = GetCharacterFrame()
if charFrameInit and ValuateOptions then
    if ValuateOptions.debug then
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
        if not ValuateUIFrame then
            CreateMainWindow()
            
            -- Create tab system (tabs outside window, panels inside content)
            local tabs = CreateTabSystem(ValuateUIFrame, ValuateUIFrame.contentFrame)
            ValuateUIFrame.tabs = tabs
            
            -- Create scale list
            local scaleList = CreateScaleList(tabs.scalesPanel)
            
            -- Create scale editor
            local scaleEditor = CreateScaleEditor(tabs.scalesPanel)
            
            -- Create instructions panel
            local instructionsPanel = CreateInstructionsPanel(tabs.instructionsPanel)
            ValuateUIFrame.instructionsPanel = instructionsPanel
            
            -- Create settings panel
            local settingsPanel = CreateSettingsPanel(tabs.settingsPanel)
            ValuateUIFrame.settingsPanel = settingsPanel
        end
        
        -- Update dynamic lists
        UpdateScaleList()
        
        ValuateUIFrame:Show()
    end)
    
    if not success then
        print("|cFFFF0000Valuate|r: Error opening UI: " .. tostring(err))
        print("|cFFFF0000Valuate|r: Please report this error and try /reload")
    end
end

function Valuate:HideUI()
    if ValuateUIFrame then
        ValuateUIFrame:Hide()
    end
end

function Valuate:ToggleUI()
    if not ValuateUIFrame then
        Valuate:ShowUI()
        return
    end
    
    if ValuateUIFrame:IsShown() then
        Valuate:HideUI()
    else
        Valuate:ShowUI()
    end
end

-- Verify UI loaded

