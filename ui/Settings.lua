-- ui/Settings.lua
-- The Settings tab: display/formatting options, all the automation toggles (quest,
-- loot roll, bag-upgrade prompt, junk delete, merchant sell/repair), the Auto Delete
-- tuning group, character-window options, keybinding and Advanced.
--
-- Also home to CheckColumnAnchors: the panel lays out by anchoring each control to the
-- PREVIOUS one, and anchoring two controls to the same frame renders them on top of
-- each other (a bug that shipped once). It warns at build time if that recurs.

local _, ns = ...

local PADDING, ELEMENT_SPACING, INNER_SPACING, COLUMN_GAP =
    ns.PADDING, ns.ELEMENT_SPACING, ns.INNER_SPACING, ns.COLUMN_GAP
local BUTTON_HEIGHT, ENTRY_HEIGHT, SCROLLBAR_WIDTH =
    ns.BUTTON_HEIGHT, ns.ENTRY_HEIGHT, ns.SCROLLBAR_WIDTH
local WINDOW_WIDTH = ns.WINDOW_WIDTH
-- Load-bearing: the column layout does `columnHeights[1] = HEADER_HEIGHT + ...`,
-- which errors on nil. It was missed when this panel was extracted.
local HEADER_HEIGHT = ns.HEADER_HEIGHT
local COLORS = ns.COLORS
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
local ApplyStatValueValidation, ApplyWholeNumberValidation =
    ns.ApplyStatValueValidation, ns.ApplyWholeNumberValidation
local HexToRGB = ns.HexToRGB


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

    -- Include Bank Items checkbox (Column 1, below Guild Repair; -16 x-offset undoes
    -- the guild-repair indent to return to the base column)
    local includeBankCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    includeBankCheckbox:SetSize(24, 24)
    includeBankCheckbox:SetPoint("TOPLEFT", guildRepairCheckbox, "BOTTOMLEFT", -16, -ELEMENT_SPACING)

    local includeBankLabel = includeBankCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    includeBankLabel:SetPoint("LEFT", includeBankCheckbox, "RIGHT", 5, 0)
    includeBankLabel:SetText("Include Bank Items")
    includeBankCheckbox:SetChecked(Valuate:GetOptions().includeBankItems ~= false)
    includeBankCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().includeBankItems = (self:GetChecked() == 1) or (self:GetChecked() == true)
        if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
    end)
    includeBankCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Include Bank Items", 1, 1, 1)
            GameTooltip:AddLine("Counts gear stored in your bank when working out best-in-slot. Banked items are marked with a bag icon, and Equip All skips them - you must withdraw them first.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("The bank is only readable while it is open, so Valuate uses a snapshot taken on your last visit. Run /valuate bank to see it.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Auto-delete and auto-sell never touch the bank.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    includeBankCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Upgrade alert presentation (Column 1, below Include Bank Items).
    -- Style and sound are stored as two independent options but share ONE control:
    -- the column is a third of the window wide, so a second button on the notify
    -- row would have overflowed - the layout failure this panel already suffered.
    local alertLabel = col1:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    alertLabel:SetPoint("TOPLEFT", includeBankCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    alertLabel:SetText("Upgrade Alert")

    local function AlertStyleText()
        local o = Valuate:GetOptions()
        local base = (o.notifyBagUpgradeStyle == "chat") and "Chat" or "Popup"
        return o.notifyUpgradeSound and (base .. " + Sound") or base
    end
    local alertStyleButton = CreateStyledButton(col1, AlertStyleText(), 120, 18)
    alertStyleButton:SetPoint("LEFT", alertLabel, "RIGHT", 8, 0)
    alertStyleButton:SetScript("OnClick", function(self)
        local o = Valuate:GetOptions()
        -- Cycle: Popup -> Popup + Sound -> Chat -> Chat + Sound -> Popup
        if o.notifyBagUpgradeStyle == "chat" then
            if o.notifyUpgradeSound then
                o.notifyBagUpgradeStyle, o.notifyUpgradeSound = "dialog", false
            else
                o.notifyUpgradeSound = true
            end
        else
            if o.notifyUpgradeSound then
                o.notifyBagUpgradeStyle, o.notifyUpgradeSound = "chat", false
            else
                o.notifyUpgradeSound = true
            end
        end
        self.label:SetText(AlertStyleText())
    end)
    alertStyleButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Upgrade Alert", 1, 1, 1)
            GameTooltip:AddLine("Popup: a dialog with an Equip button.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Chat: a message only - nothing steals focus mid-fight. Use /valuate equip to wear the set.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Applies to the 'Notify Bag Upgrades' alert above.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    alertStyleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Other-spec upgrades checkbox (Column 1, below the Upgrade Alert row)
    local otherSpecCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    otherSpecCheckbox:SetSize(24, 24)
    otherSpecCheckbox:SetPoint("TOPLEFT", alertLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local otherSpecLabel = otherSpecCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    otherSpecLabel:SetPoint("LEFT", otherSpecCheckbox, "RIGHT", 5, 0)
    otherSpecLabel:SetText("Alert For Other Specs")
    otherSpecCheckbox:SetChecked(Valuate:GetOptions().notifyOtherSpecUpgrades == true)
    otherSpecCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().notifyOtherSpecUpgrades = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    otherSpecCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Alert For Other Specs", 1, 1, 1)
            GameTooltip:AddLine("The upgrade alert normally only considers your active scale. With this on it also lists your other active scales that have upgrades waiting.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Useful on a classless server, where a drop often suits a spec you aren't currently running - and would otherwise be vendored without you noticing.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    otherSpecCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Skip Trivial Quests checkbox (Column 1, below Alert For Other Specs)
    local skipTrivialCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    skipTrivialCheckbox:SetSize(24, 24)
    skipTrivialCheckbox:SetPoint("TOPLEFT", otherSpecCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local skipTrivialLabel = skipTrivialCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    skipTrivialLabel:SetPoint("LEFT", skipTrivialCheckbox, "RIGHT", 5, 0)
    skipTrivialLabel:SetText("Skip Trivial Quests")
    skipTrivialCheckbox:SetChecked(Valuate:GetOptions().autoAcceptSkipTrivial == true)
    skipTrivialCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoAcceptSkipTrivial = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    skipTrivialCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Skip Trivial Quests", 1, 1, 1)
            GameTooltip:AddLine("With Auto Accept Quests on, don't accept quests 8 or more levels below you - useful while levelling back through old content.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Valuate now picks the first non-trivial quest an NPC offers instead of always the first in the list.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("If a quest's level can't be read, it is accepted anyway - silently declining a quest you wanted would be worse than accepting a grey one.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    skipTrivialCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
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

    -- How often cleanup runs on its own, on top of the loot/bag-event triggers.
    local intervalLabel = CreateCol2NumberRow(
        "Run Every (s):", sourceLabel, ELEMENT_SPACING + 4,
        tostring(Valuate:GetOptions().autoDeleteIntervalSecs or 60),
        ApplyWholeNumberValidation,
        function(self)
            local v = math.max(0, math.min(3600, tonumber(self:GetText()) or 60))
            Valuate:GetOptions().autoDeleteIntervalSecs = v
            self:SetText(tostring(v))
        end,
        function() return tostring(Valuate:GetOptions().autoDeleteIntervalSecs or 60) end)

    -- Explain the two bounds, since "floor" is the non-obvious one.
    local valueHint = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    valueHint:SetPoint("TOPLEFT", intervalLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    valueHint:SetWidth(settingsColumnWidth)
    valueHint:SetJustifyH("LEFT")
    valueHint:SetText("Only stacks worth between Min and Max are deletable.\nMax 0 = no ceiling, Min 0 = no floor.\nA tiny Min (0.0001 = 1c) skips unsellable items.\nRun Every 0 = only clean up on loot and bag events.")
    valueHint:SetTextColor(unpack(COLORS.textDim))
    columnHeights[2] = columnHeights[2] + 52 + ELEMENT_SPACING

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
            local da, db = (a.scale.DisplayName or a.name), (b.scale.DisplayName or b.name)
            if da ~= db then return da < db end
            return a.name < b.name  -- unique key breaks duplicate display names
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

ns.CreateSettingsPanel = CreateSettingsPanel
