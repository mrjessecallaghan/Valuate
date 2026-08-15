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
local MOTION = ns.MOTION
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
-- Anim.tween honours the reduceMotion option itself, jumping straight to the final
-- state, so callers never need to branch on it.
local Anim = ns.Anim
local ApplyStatValueValidation, ApplyWholeNumberValidation =
    ns.ApplyStatValueValidation, ns.ApplyWholeNumberValidation
local HexToRGB = ns.HexToRGB


-- Settings Panel
-- ========================================

-- Structural safeguard against overlapping controls. The whole panel lays out by
-- anchoring each control's TOPLEFT to the previous control's BOTTOMLEFT; the failure
-- mode (which shipped once) is anchoring TWO controls to the SAME sibling at the SAME
-- offset, so they render on top of each other. This scans a column's child frames and
-- regions and warns loudly when that happens - so the mistake surfaces the instant you
-- open Settings instead of silently overlapping. Read-only.
--
-- The offset is part of the slot, and leaving it out of the key made this cry wolf: it
-- printed 53 times in the client on a layout with nothing wrong with it. Sharing an
-- anchor is normal and deliberate here. Every section header has a 2px accent rule at
-- -2 AND the first control a full gap below, both anchored to the header; several
-- checkboxes have a description line at -2 with the next control below it. Those are
-- stacked, not overlapping. A red error that fires on correct layout is worse than no
-- error at all - it teaches you to scroll past the one message that matters.
local function CheckColumnAnchors(colFrame, colName)
    if not colFrame or not colFrame.GetChildren then return 0 end
    local elements = {}
    for _, k in ipairs({ colFrame:GetChildren() }) do elements[#elements + 1] = k end
    for _, r in ipairs({ colFrame:GetRegions() }) do elements[#elements + 1] = r end

    -- Names the offender where it can. The old message said only "two controls", which
    -- left you to find them by eye in a column of forty.
    local function Describe(el)
        local text = el.GetText and el:GetText()
        if type(text) == "string" and text ~= "" then
            return '"' .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. '"'
        end
        return "an unlabelled " .. tostring(el.__type or "control")
    end

    local seen, collisions = {}, 0
    for _, el in ipairs(elements) do
        if el.GetNumPoints and el:GetNumPoints() > 0 then
            local point, relTo, relPoint, xOfs, yOfs = el:GetPoint(1)
            -- Only the vertical-stack anchor matters. Two elements occupy the same slot
            -- when they share the anchor AND the offset from it.
            if relTo and relTo ~= colFrame and point == "TOPLEFT" then
                local key = table.concat({ tostring(relTo), tostring(relPoint),
                    tostring(xOfs or 0), tostring(yOfs or 0) }, "|")
                if seen[key] then
                    collisions = collisions + 1
                    print("|cFFFF0000[Valuate]|r Settings layout bug: " .. Describe(seen[key]) ..
                        " and " .. Describe(el) .. " in " .. tostring(colName) ..
                        " sit at the same spot and will OVERLAP. Anchor each control below " ..
                        "the previous one, not to a shared sibling at the same offset.")
                else
                    seen[key] = el
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
    
    
    -- The panel scrolls.
    --
    -- Each control anchors to the previous one, so a column grows as long as its
    -- contents demand. The columns used to sit directly in `parent` at a fixed 500px,
    -- which meant anything past that simply ran off the bottom of the window with no
    -- way to reach it - and column 1 is now far taller than column 2 or 3.
    --
    -- columnHeights was already being tracked for exactly this and never used for
    -- anything; it now sizes the scroll child, so the panel can never outgrow its
    -- window again however many options get added.
    -- ---- Search box -------------------------------------------------------
    -- Forty-seven options across three columns. Knowing one exists and finding it are
    -- different problems, and only the first was solved.
    --
    -- This DIMS rather than hides. Every control here anchors to the one above it, so
    -- hiding a control would collapse the chain beneath it - which is the failure the
    -- settings-anchor-chain lint rule exists to catch. Alpha touches no anchors.
    -- Forward-declared: the shared box takes its onQuery at construction, and the filter
    -- it calls is defined further down this function.
    local ApplySettingsFilterRef
    local searchBox = ns.CreateSearchBox(parent, {
        hint = "Search settings...",
        onQuery = function(text)
            if ApplySettingsFilterRef then ApplySettingsFilterRef(text) end
        end,
    })
    searchBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 2, -2)
    searchBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(SCROLLBAR_WIDTH + 2), -2)

    -- Match count, right-aligned inside the box.
    --
    -- The filter DIMS rather than hides, which is what keeps the anchor chain intact -
    -- but it means a match further down the panel is dimmed-in-place and invisible
    -- until you scroll to it. Without a count there is no way to tell "nothing matches"
    -- from "the matches are below the fold", and those call for opposite reactions:
    -- one means refine the search, the other means keep scrolling.
    local searchCount = searchBox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    searchCount:SetPoint("RIGHT", searchBox, "RIGHT", -7, 0)
    searchCount:SetJustifyH("RIGHT")

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -24)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self:GetVerticalScrollRange()
        local newValue = self:GetVerticalScroll() - (delta * 40)
        newValue = math.max(0, math.min(maxScroll, newValue))
        self:SetVerticalScroll(newValue)
        if self.scrollBar then self.scrollBar:SetValue(newValue) end
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(availableWidth)
    content:SetHeight(1)  -- real height set once the columns are built
    scrollFrame:SetScrollChild(content)
    parent.settingsScrollFrame = scrollFrame

    local columnFrames = {}
    local columnHeights = {0, 0, 0}

    for i = 1, 3 do
        local colFrame = CreateFrame("Frame", nil, content)
        colFrame:SetWidth(settingsColumnWidth)
        colFrame:SetHeight(1)  -- sized from columnHeights once the build finishes
        colFrame:SetPoint("TOPLEFT", content, "TOPLEFT", PADDING + (i - 1) * (settingsColumnWidth + COLUMN_GAP), -PADDING)
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
    -- Adds the accent rule to a header that was built by hand. Used for the
    -- pre-existing headers in columns 2 and 3: re-anchoring them through
    -- CreateSectionHeader would risk their layout for no visual gain, so they just
    -- get the rule and match.
    -- Parameter deliberately NOT named `header`/`anchorTo`: settings-anchor-chain
    -- matches on identifier text, so two helpers sharing an anchor-parameter name
    -- read to it as two controls pinned to the same frame.
    local function AddHeaderRule(col, existingHeader)
        local rule = col:CreateTexture(nil, "BORDER")
        rule:SetPoint("TOPLEFT", existingHeader, "BOTTOMLEFT", 0, -2)
        rule:SetWidth(28)
        rule:SetHeight(2)
        ns.SetSolidColor(rule, unpack(COLORS.textAccent))
        return rule
    end

    -- Section header: title plus a short accent rule underneath, so a column reads
    -- as a few labelled groups instead of one long list of checkboxes.
    --
    -- `afterFrame` is the previous control in the column's chain, so headers join the
    -- same single chain everything else uses - the layout rule this panel depends on,
    -- and what CheckColumnAnchors verifies.
    local function CreateSectionHeader(col, colIndex, text, afterFrame, extraGap)
        local headerFrame = col:CreateFontString(nil, "OVERLAY", FONT_H1)
        if afterFrame then
            headerFrame:SetPoint("TOPLEFT", afterFrame, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 2 + (extraGap or 0)))
        else
            headerFrame:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
        end
        headerFrame:SetText(text)
        headerFrame:SetTextColor(unpack(COLORS.textAccent))

        -- Accent rule. A texture on the column, not a frame: BACKGROUND/BORDER
        -- textures always draw beneath the column's child frames, so it can never
        -- intercept a click or need frame-level juggling.
        local rule = col:CreateTexture(nil, "BORDER")
        rule:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -2)
        rule:SetWidth(28)
        rule:SetHeight(2)
        ns.SetSolidColor(rule, unpack(COLORS.textAccent))

        columnHeights[colIndex] = columnHeights[colIndex]
            + (afterFrame and (ELEMENT_SPACING * 2 + (extraGap or 0)) or 0)
            + HEADER_HEIGHT + ELEMENT_SPACING
        return headerFrame
    end

    local col1 = columnFrames[1]

    -- Display & Formatting Section Header
    local displayHeader = CreateSectionHeader(col1, 1, "Display & Formatting", nil)
    
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
    
    -- Shared by Enter and click-away, so the two can't drift apart.
    local function CommitDecimalPlaces(self)
        local text = self:GetText()
        local value = tonumber(text) or 1
        value = math.max(0, math.min(4, value))
        Valuate:GetOptions().decimalPlaces = value
        self:SetText(tostring(value))

        -- Reset all tooltips to show new decimal places immediately. Inside the
        -- shared commit so click-away refreshes them too, not just Enter.
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end
    decimalEditBox:SetScript("OnEditFocusLost", CommitDecimalPlaces)
    decimalEditBox:SetScript("OnEnterPressed", function(self)
        CommitDecimalPlaces(self)
        self:ClearFocus()
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
    local scanningHeader = CreateSectionHeader(col1, 1, "Scanning", scanVerboseCheckbox)
    autoScanLabel:SetPoint("TOPLEFT", scanningHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
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
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Always also reacts much faster - roughly a second after your bags change, rather than several. Use /valuate profile if you want to see what a scan costs.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    autoScanDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Auto Choose Best Quest Reward checkbox (Column 1, below the Auto Scan dropdown)
    local autoQuestCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    autoQuestCheckbox:SetSize(24, 24)
    -- extraGap clears the dropdown, which hangs below its label.
    local questsHeader = CreateSectionHeader(col1, 1, "Quests", autoScanLabel, 22)
    autoQuestCheckbox:SetPoint("TOPLEFT", questsHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

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
    local lootHeader = CreateSectionHeader(col1, 1, "Loot Rolling", autoAcceptCheckbox)
    autoRollCheckbox:SetPoint("TOPLEFT", lootHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

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

    -- Roll Need on unlearned recipes (Column 1, indented under Auto Roll since it
    -- only does anything when that is on)
    local rollRecipesCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    rollRecipesCheckbox:SetSize(24, 24)
    rollRecipesCheckbox:SetPoint("TOPLEFT", autoRollCheckbox, "BOTTOMLEFT", 16, -ELEMENT_SPACING)

    local rollRecipesLabel = rollRecipesCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    rollRecipesLabel:SetPoint("LEFT", rollRecipesCheckbox, "RIGHT", 5, 0)
    rollRecipesLabel:SetText("Need Unlearned Recipes")
    rollRecipesCheckbox:SetChecked(Valuate:GetOptions().autoRollRecipes ~= false)
    rollRecipesCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoRollRecipes = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    rollRecipesCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Need Unlearned Recipes", 1, 1, 1)
            GameTooltip:AddLine("Rolls Need on recipes for a profession you actually have and haven't learned yet.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Requiring a higher skill than you have is fine - you'll train into it, so it still rolls Need.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Recipes you already know, or for professions you don't have, are left alone.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Only applies while Auto Roll Loot is on.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    rollRecipesCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Roll Need on crafting materials (Column 1, below Need Unlearned Recipes)
    local rollMatsCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    rollMatsCheckbox:SetSize(24, 24)
    rollMatsCheckbox:SetPoint("TOPLEFT", rollRecipesCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local rollMatsLabel = rollMatsCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    rollMatsLabel:SetPoint("LEFT", rollMatsCheckbox, "RIGHT", 5, 0)
    rollMatsLabel:SetText("Need Profession Materials")
    rollMatsCheckbox:SetChecked(Valuate:GetOptions().autoRollTradeGoods ~= false)
    rollMatsCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().autoRollTradeGoods = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    rollMatsCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Need Profession Materials", 1, 1, 1)
            GameTooltip:AddLine("Rolls Need on crafting materials used by a profession you have - cloth for Tailoring, herbs for Alchemy, metal for Blacksmithing, and so on.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cFFFF8800Worth knowing:|r materials drop far more often than recipes, so this makes you roll Need on a lot of common loot. Some groups consider that poor etiquette - turn it off if yours does.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Gathering professions are ignored: mining produces ore, so a miner isn't short of it.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Only applies while Auto Roll Loot is on.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    rollMatsCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING

    -- Profession overrides (Column 1, below the roll sub-options).
    --
    -- MULTI-select, unlike every other dropdown here: you can have several
    -- professions, so this uses isNotRadio + keepShownOnClick so ticking one does
    -- not close the menu or clear the others.
    local professionsLabel = col1:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    professionsLabel:SetPoint("TOPLEFT", rollMatsCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    professionsLabel:SetText("Professions")

    local professionDropdown = CreateFrame("Frame", "ValuateProfessionDropdown", col1, "UIDropDownMenuTemplate")
    professionDropdown:SetPoint("LEFT", professionsLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(professionDropdown, 150)

    local function ProfessionSummary()
        local choices, detected = Valuate:GetProfessionOverrideChoices()
        local overrides = Valuate:GetOptions().professionOverrides or {}
        local n = 0
        for _, prof in ipairs(choices) do
            if detected[prof] or overrides[prof] then n = n + 1 end
        end
        if n == 0 then return "|cFFFF8800None detected|r" end
        return string.format("%d profession%s", n, n == 1 and "" or "s")
    end
    UIDropDownMenu_SetText(professionDropdown, ProfessionSummary())

    UIDropDownMenu_Initialize(professionDropdown, function(self, level)
        local choices, detected = Valuate:GetProfessionOverrideChoices()
        for _, prof in ipairs(choices) do
            -- A fresh info table per row: reusing one across AddButton calls leaks
            -- fields (notCheckable, disabled) into the next row.
            local info = UIDropDownMenu_CreateInfo()
            local isDetected = detected[prof]
            info.text = isDetected and (prof .. "  |cFF00FF00(detected)|r") or prof
            info.value = prof
            info.isNotRadio = true
            info.keepShownOnClick = true
            local overrides = Valuate:GetOptions().professionOverrides or {}
            info.checked = (isDetected or overrides[prof]) and true or false
            -- A detected profession is already yours; the tick is informational and
            -- unticking it would imply we could remove it, which overrides can't do.
            info.disabled = isDetected and true or false
            info.func = function(button)
                local o = Valuate:GetOptions()
                o.professionOverrides = o.professionOverrides or {}
                o.professionOverrides[prof] = (not o.professionOverrides[prof]) or nil
                UIDropDownMenu_SetText(professionDropdown, ProfessionSummary())
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    professionDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Professions", 1, 1, 1)
            GameTooltip:AddLine("Which professions auto-roll treats as yours when deciding to Need recipes and crafting materials.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Ones marked (detected) were read from your skill list and are always included - you can't untick them.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Tick any others to add them manually. Useful because the skill list returns nothing while its headers are collapsed, which would otherwise stop every recipe from rolling Need.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Gathering professions aren't listed: they have no recipes and produce materials rather than consuming them.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    professionDropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[1] = columnHeights[1] + 32 + ELEMENT_SPACING

    -- Notify Bag Upgrades checkbox (Column 1, below Auto Roll On Loot)
    local notifyCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    notifyCheckbox:SetSize(24, 24)
    -- -16 undoes the indent of the roll sub-options to return to the base column.
    -- -16 undoes the indent of the roll sub-options; extraGap clears the dropdown.
    local alertsCol1Header = CreateSectionHeader(col1, 1, "Upgrade Alerts", professionsLabel, 14)
    alertsCol1Header:SetPoint("TOPLEFT", professionsLabel, "BOTTOMLEFT", -16, -(ELEMENT_SPACING * 2 + 14))
    notifyCheckbox:SetPoint("TOPLEFT", alertsCol1Header, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

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
    local cleanupHeader = CreateSectionHeader(col1, 1, "Vendor & Cleanup", bindConfirmCheckbox)
    autoDeleteCheckbox:SetPoint("TOPLEFT", cleanupHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

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
    AddHeaderRule(col2, comparisonHeader)
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
    AddHeaderRule(col2, interfaceHeader)
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
    AddHeaderRule(col2, autoDeleteHeader)
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
        -- Commit on click-away too. Enter alone silently discarded the edit: the
        -- typed number stayed visible so it looked applied, but the option kept its
        -- old value. This helper backs Keep Free Slots, Max/Min Value and Run
        -- Every, so the bug affected all four.
        box:SetScript("OnEditFocusLost", function(self)
            onCommit(self)
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
    -- announce=false on click-away: the value still commits, but confirming it in
    -- chat every time focus moves would be noise.
    local function CommitValueSource(self, announce)
        local v = strtrim(self:GetText() or "")
        if v == "" then v = "vendor" end
        local changed = (Valuate:GetOptions().autoDeleteValueSource ~= v)
        Valuate:GetOptions().autoDeleteValueSource = v
        self:SetText(v)
        if announce and changed then
            print("|cFF00FF00Valuate|r: Value source set to '" .. v .. "'. Run /valuate deletepreview to confirm it resolves.")
        end
    end
    sourceBox:SetScript("OnEditFocusLost", function(self) CommitValueSource(self, false) end)
    sourceBox:SetScript("OnEnterPressed", function(self)
        CommitValueSource(self, true)
        self:ClearFocus()
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

    -- ---- Battlegrounds & Dungeons -------------------------------------------
    --
    -- Command-only until now, which meant the newest and most consequential automations in
    -- the addon - the ones that move your character - were invisible to anyone who does not
    -- read /valuate help. A feature nobody can find is a feature that does not exist.
    --
    -- Built in a loop, so five near-identical blocks cannot drift apart the way hand-copied
    -- ones do. Each control anchors to the PREVIOUS control, never to a shared sibling: two
    -- controls sharing an anchor is the overlap bug CheckColumnAnchors exists to catch.
    local bgHeader = CreateSectionHeader(col2, 2, "Battlegrounds & Dungeons", valueHint)

    local BG_TOGGLES = {
        { key = "autoRelease", label = "Release on death",
          tip = "Releases your spirit automatically. Never while you are dead in a party or raid instance with other people - someone is probably mid battle-rez, and throwing that away is not a preference anyone holds on purpose." },
        { key = "autoLeaveBattleground", label = "Leave a finished battleground",
          tip = "Leaves 8 seconds after the match ends, so the scoreboard stays readable. Switching this off DURING the countdown cancels it." },
        { key = "autoAcceptBattleground", label = "Take the battleground invite",
          tip = "Accepts the port the moment a queue pops - but never while you are in combat. Deliberately separate from re-queueing: being pulled out of a quest is a surprise you should have to ask for." },
        { key = "autoQueuePvP", label = "Re-queue for PvP",
          tip = "Queues for a random battleground after you leave one, or after a queue pop lapsed while you were away. Never queues while you are still inside a match." },
        { key = "autoQueueDungeon", label = "Re-queue for a dungeon",
          tip = "Queues for a random dungeon after one finishes." },
        { key = "notifyDungeonNoUpgrades", label = "Say when a dungeon is done with you",
          tip = "Asks whether to leave once every remaining boss has been checked and none of them drop anything that beats your gear. It stays quiet whenever a boss has no loot data - 'I don't know' must never be delivered as 'there is nothing here'. /valuate dungeon shows exactly what is known for where you are standing." },
    }

    local bgPrevious = bgHeader
    for _, toggle in ipairs(BG_TOGGLES) do
        local cb = CreateFrame("CheckButton", nil, col2, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", bgPrevious, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

        local lbl = cb:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        lbl:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        lbl:SetText(toggle.label)

        cb:SetChecked(Valuate:GetOptions()[toggle.key] == true)
        cb:SetScript("OnClick", function(self)
            Valuate:GetOptions()[toggle.key] =
                (self:GetChecked() == 1) or (self:GetChecked() == true)
        end)
        cb:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                GameTooltip:AddLine(toggle.label, 1, 1, 1)
                GameTooltip:AddLine(toggle.tip, 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine(" ")
                -- Every one of these depends on an API Ascension may not have. Saying so on
                -- the control itself beats finding out when it silently never fires.
                GameTooltip:AddLine("/valuate queuecheck says whether this client can actually do it.",
                    0.6, 0.9, 0.6, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        columnHeights[2] = columnHeights[2] + 24 + ELEMENT_SPACING
        bgPrevious = cb
    end

    -- Named separately from the loop's cursor on purpose. `bgPrevious` is loop STATE - a
    -- different frame on every pass - while this is one specific control, and anchoring to
    -- it twice really would be the overlap bug. Keeping the names apart means the lint rule
    -- still catches that, instead of being told to ignore a variable it cannot reason about.
    local lastBgToggle = bgPrevious

    local bgHint = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    bgHint:SetPoint("TOPLEFT", lastBgToggle, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    bgHint:SetWidth(settingsColumnWidth)
    bgHint:SetJustifyH("LEFT")
    bgHint:SetText("These act in the world. /valuate queuecheck lists which of\n" ..
                   "their APIs your client has.\n" ..
                   "A different scale inside battlegrounds: /valuate pvpscale make")
    bgHint:SetTextColor(unpack(COLORS.textDim))
    columnHeights[2] = columnHeights[2] + 40 + ELEMENT_SPACING

    -- ---- Messages & Convenience -----------------------------------------------
    --
    -- The last options with no control anywhere. Every one of them was reachable ONLY by
    -- typing a slash command you would have to already know exists - which the options gate
    -- counts as reachable, correctly, because it is asking whether a control exists at all.
    -- Discoverability is a different question, and it is the one that matters here: two of
    -- these move your gear without being asked twice.
    --
    -- Same table-driven loop as the battleground block, for the same reason: five near
    -- identical checkbox blocks written by hand drift apart, and these arrived one release
    -- at a time.
    local miscHeader = CreateSectionHeader(col2, 2, "Messages & Convenience", bgHint)

    local MISC_TOGGLES = {
        { key = "autoEquipOnLevelUp", label = "Equip upgrades when you level",
          tip = "On level-up, equips anything you are carrying that just became wearable and beats what you have on. Waits a few seconds first, so the rescan that levelling triggers has finished - equipping before that would put your current gear back on and announce it as a success." },
        { key = "autoLearnAppearances", label = "Learn appearances automatically",
          tip = "Adds looted items to your wardrobe without asking." },
        { key = "todoOnLogin", label = "Summarise what needs doing at login",
          tip = "One line at login: empty sockets, missing enchants, upgrades sitting in your bags. Informational only, so this one is ON by default - it never acts, it only counts." },
        { key = "showAltDetail", label = "Show extra tooltip detail on Alt",
          tip = "Holding Alt over an item expands the tooltip with the per-scale breakdown. Costs nothing until you hold the key, so it is on by default." },
        { key = "chatMessages", label = "Talk in chat",
          tip = "The running commentary - what was scanned, sold, equipped. Switching this off keeps the automations running and stops them narrating." },
        { key = "showStartupMessage", label = "Say hello at login",
          tip = "The one-line greeting when the addon loads." },
    }

    local miscPrevious = miscHeader
    for _, toggle in ipairs(MISC_TOGGLES) do
        local cb = CreateFrame("CheckButton", nil, col2, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", miscPrevious, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

        local lbl = cb:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        lbl:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        lbl:SetText(toggle.label)
        lbl:SetTextColor(unpack(COLORS.textBody))

        cb:SetChecked(Valuate:GetOptions()[toggle.key] == true)
        cb:SetScript("OnClick", function(self)
            Valuate:GetOptions()[toggle.key] =
                (self:GetChecked() == 1) or (self:GetChecked() == true)
        end)
        cb:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                GameTooltip:AddLine(toggle.label, 1, 1, 1)
                GameTooltip:AddLine(toggle.tip, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        columnHeights[2] = columnHeights[2] + 24 + ELEMENT_SPACING
        miscPrevious = cb
    end

    -- Named apart from the loop cursor, exactly as lastBgToggle is: one is loop state, the
    -- other is one specific control, and anchoring twice to the latter IS the overlap bug.
    local lastMiscToggle = miscPrevious

    local miscHint = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    miscHint:SetPoint("TOPLEFT", lastMiscToggle, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    miscHint:SetWidth(settingsColumnWidth)
    miscHint:SetJustifyH("LEFT")
    miscHint:SetText("Trivial quests are skipped below a level gap set with\n" ..
                     "/valuate trivial <n>.")
    miscHint:SetTextColor(unpack(COLORS.textDim))
    columnHeights[2] = columnHeights[2] + 28 + ELEMENT_SPACING

    -- ========================================
    -- COLUMN 3: Character Window, Keybindings, Advanced
    -- ========================================
    local col3 = columnFrames[3]
    
    -- Character Window Section Header
    local charWindowHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    charWindowHeader:SetPoint("TOPLEFT", col3, "TOPLEFT", 0, 0)
    charWindowHeader:SetText("Character Window")
    charWindowHeader:SetTextColor(unpack(COLORS.textAccent))
    AddHeaderRule(col3, charWindowHeader)
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
    AddHeaderRule(col3, keybindHeader)
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
        -- Ends the capture too, and sets the label from the binding we just cleared.
        --
        -- It used to only set the label. Right-click clears REGARDLESS of capture state,
        -- so clearing while "Press Key..." was showing left isCapturingKeybind true and the
        -- keyboard still enabled: the next key you pressed was silently bound, the button
        -- stayed capture-blue, and its hover styling stayed suppressed because both OnEnter
        -- and OnLeave skip themselves mid-capture.
        --
        -- On 3.3.5 that is worse than a stuck colour. There is no SetPropagateKeyboardInput
        -- until 4.0, so a frame with EnableKeyboard(true) CONSUMES what you type - an armed
        -- button sitting on a visible panel eats keystrokes.
        StopKeybindCapture()
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

    -- Closing the window mid-capture must disarm it.
    --
    -- Capture had exactly two exits, Escape and pressing a key, and both require the panel
    -- to be in front of you. Clicking away or closing the window left it armed forever:
    -- reopen Settings and the button still says "Press Key...", still has the keyboard, and
    -- binds the next thing you type. Hidden frames get no input, so the trap only springs
    -- when you come back - which is exactly when you have forgotten about it.
    keybindButton:SetScript("OnHide", function()
        if isCapturingKeybind then StopKeybindCapture() end
    end)
    
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- ========================================
    -- Alerts & Extras Section
    -- ========================================
    local alertsHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    alertsHeader:SetPoint("TOPLEFT", keybindLabel, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    alertsHeader:SetText("Alerts & Extras")
    alertsHeader:SetTextColor(unpack(COLORS.textAccent))
    AddHeaderRule(col3, alertsHeader)
    columnHeights[3] = columnHeights[3] + (ELEMENT_SPACING * 3) + HEADER_HEIGHT + ELEMENT_SPACING

    -- Alerts, bank and quest options (Column 3).
    -- Moved here from column 1, which had grown to 25 rows against 9 and 7 and was
    -- running off the bottom of the window.
    local includeBankCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
    includeBankCheckbox:SetSize(24, 24)
    includeBankCheckbox:SetPoint("TOPLEFT", alertsHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

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
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING

    -- Upgrade alert presentation (Column 3, below Include Bank Items).
    -- Style and sound are stored as two independent options but share ONE control:
    -- the column is a third of the window wide, so a second button on the notify
    -- row would have overflowed - the layout failure this panel already suffered.
    local alertLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    alertLabel:SetPoint("TOPLEFT", includeBankCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    alertLabel:SetText("Upgrade Alert")

    local function AlertStyleText()
        local o = Valuate:GetOptions()
        local base = (o.notifyBagUpgradeStyle == "chat") and "Chat" or "Popup"
        return o.notifyUpgradeSound and (base .. " + Sound") or base
    end
    local alertStyleButton = CreateStyledButton(col3, AlertStyleText(), 120, 18)
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
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING

    -- Other-spec upgrades checkbox (Column 3, below the Upgrade Alert row)
    local otherSpecCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
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
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING

    -- Skip Trivial Quests checkbox (Column 3, below Alert For Other Specs)
    local skipTrivialCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
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
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING

    -- Upgrade Arrows checkbox (Column 3, below Skip Trivial Quests)
    local arrowsCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
    arrowsCheckbox:SetSize(24, 24)
    arrowsCheckbox:SetPoint("TOPLEFT", skipTrivialCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)

    local arrowsLabel = arrowsCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    arrowsLabel:SetPoint("LEFT", arrowsCheckbox, "RIGHT", 5, 0)
    arrowsLabel:SetText("Upgrade Arrows")
    arrowsCheckbox:SetChecked(Valuate:GetOptions().showUpgradeArrows ~= false)
    arrowsCheckbox:SetScript("OnClick", function(self)
        Valuate:GetOptions().showUpgradeArrows = (self:GetChecked() == 1) or (self:GetChecked() == true)
        -- Repaint whatever is open so the change is visible immediately.
        if ns.RefreshUpgradeArrows then ns.RefreshUpgradeArrows() end
    end)
    arrowsCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Upgrade Arrows", 1, 1, 1)
            GameTooltip:AddLine("Pins a green arrow to the top-right of any item icon that would be an upgrade for your CURRENT spec.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Shown in your bags, at vendors, and on the loot window.", 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine("Deliberately NOT on the character or wardrobe panels - an arrow on gear you're already wearing is just noise.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    arrowsCheckbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING

    -- ========================================
    -- Advanced Section
    -- ========================================
    local advancedHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    advancedHeader:SetPoint("TOPLEFT", arrowsCheckbox, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    advancedHeader:SetText("Advanced")
    advancedHeader:SetTextColor(unpack(COLORS.textAccent))
    AddHeaderRule(col3, advancedHeader)
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

    -- Restore Defaults (Column 3, below Debug Mode). 48 options accumulate a lot of
    -- state, and there was no way back to a known one short of deleting saved
    -- variables entirely - which also takes your scales.
    local restoreButton = CreateStyledButton(col3, "Restore Default Settings", 180, 22)
    restoreButton:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    restoreButton:SetScript("OnClick", function()
        Valuate:ShowConfirmDialog({
            text = "Restore all Valuate settings to their defaults?\n\n"
                .. "|cFF00FF00Your scales, scale library and best-equipment data are NOT affected.|r\n"
                .. "Only the options on this page change.",
            acceptText = "Restore Defaults",
            cancelText = "Cancel",
            onAccept = function()
                local n = Valuate:RestoreDefaultOptions()
                print(string.format("|cFF00FF00[Valuate]|r Restored %d setting(s) to defaults.", n))
                -- The panel's controls still show the old values; rebuilding them
                -- means reopening the window, which is simpler and more honest than
                -- trying to refresh forty-odd widgets in place.
                print("|cFFAAAAAA[Valuate]|r Close and reopen this window to see the reset controls.")
            end,
        })
    end)
    restoreButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Restore Default Settings", 1, 1, 1)
            GameTooltip:AddLine("Puts every option on this page back to how it shipped.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Scales, the scale library and your best-equipment data are left alone - this only touches settings.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    restoreButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING

    -- Settings snapshot (Column 3, below Restore Defaults). Two buttons on one row:
    -- the column is about 270px wide, so 128 each with a gap fits comfortably.
    local snapshotLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    snapshotLabel:SetPoint("TOPLEFT", restoreButton, "BOTTOMLEFT", 0, -(ELEMENT_SPACING + 4))
    snapshotLabel:SetText("Share settings with your other characters:")
    snapshotLabel:SetTextColor(unpack(COLORS.textDim))

    local saveSettingsButton = CreateStyledButton(col3, "Save For Alts", 128, 22)
    saveSettingsButton:SetPoint("TOPLEFT", snapshotLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    saveSettingsButton:SetScript("OnClick", function()
        local n = Valuate:SaveSettingsSnapshot()
        print(string.format("|cFF00FF00[Valuate]|r Saved %d setting(s) for your other characters.", n))
    end)
    saveSettingsButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Save For Alts", 1, 1, 1)
            GameTooltip:AddLine("Stores this character's settings so any other character can load them.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Not included: window position, this character's professions, and the character-window scale - those describe the character, not your preferences.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    saveSettingsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local loadSettingsButton = CreateStyledButton(col3, "Load Saved", 128, 22)
    loadSettingsButton:SetPoint("LEFT", saveSettingsButton, "RIGHT", ELEMENT_SPACING, 0)
    loadSettingsButton:SetScript("OnClick", function()
        if not Valuate:HasSettingsSnapshot() then
            print("|cFFFF8800[Valuate]|r No settings saved yet - use Save For Alts on a character you've set up.")
            return
        end
        Valuate:ShowConfirmDialog({
            text = "Apply your saved settings to this character?\n\n"
                .. "|cFF00FF00Your scales are not affected.|r",
            acceptText = "Apply",
            cancelText = "Cancel",
            onAccept = function()
                local ok, result = Valuate:LoadSettingsSnapshot()
                if ok then
                    print(string.format("|cFF00FF00[Valuate]|r Applied %d saved setting(s).", result))
                    print("|cFFAAAAAA[Valuate]|r Close and reopen this window to see the updated controls.")
                else
                    print("|cFFFF0000[Valuate]|r " .. tostring(result))
                end
            end,
        })
    end)
    loadSettingsButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Load Saved", 1, 1, 1)
            GameTooltip:AddLine("Applies the settings you saved on another character. Your scales are untouched.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    loadSettingsButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    columnHeights[3] = columnHeights[3] + 44 + ELEMENT_SPACING
    
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

    -- Size the scroll child from the TALLEST column, so the scroll range covers
    -- everything regardless of how unevenly the columns are filled.
    local tallest = math.max(columnHeights[1], columnHeights[2], columnHeights[3])
    local contentHeight = tallest + PADDING * 2
    content:SetHeight(contentHeight)
    for i = 1, 3 do
        columnFrames[i]:SetHeight(tallest)
    end

    -- Slim scrollbar, matching the one on the Instructions panel. Hidden entirely
    -- when everything fits, so the common case stays clean.
    local scrollBar = CreateFrame("Slider", nil, scrollFrame)
    scrollBar:SetWidth(SCROLLBAR_WIDTH - 6)
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 2, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 2, 0)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetBackdrop(BACKDROP_INPUT)
    scrollBar:SetBackdropColor(unpack(COLORS.inputBg))
    scrollBar:SetBackdropBorderColor(unpack(COLORS.borderDark))

    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    thumb:SetWidth(SCROLLBAR_WIDTH - 8)
    thumb:SetHeight(40)
    thumb:SetVertexColor(unpack(COLORS.borderLight))
    scrollBar:SetThumbTexture(thumb)

    scrollBar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame.scrollBar = scrollBar

    -- The scroll range is only known once the frame has a real height, which is
    -- after the tab panel lays out. Recomputing on show keeps the bar honest if the
    -- window is resized between openings.
    scrollFrame:SetScript("OnShow", function(self)
        local range = math.max(0, contentHeight - self:GetHeight())
        scrollBar:SetMinMaxValues(0, range)
        scrollBar:SetValue(math.min(scrollBar:GetValue() or 0, range))
        if range > 0 then scrollBar:Show() else scrollBar:Hide() end
    end)

    -- Staggered column reveal on tab-open, matching the Best Equipment flourish so
    -- the two tabs feel like the same product. Columns rather than sections: the
    -- ten sections are flat children of three column frames, so fading the columns
    -- gets the cascade without needing every control grouped into its own frame.
    ns.RevealSettingsColumns = function()
        local gap = Anim.staggerFor(3)
        for i = 1, 3 do
            Anim.revealIn(columnFrames[i], (i - 1) * gap)
        end
    end

    -- ---- Search index -----------------------------------------------------
    -- DERIVED from the built UI, never hand-maintained. A list of "option -> search
    -- words" typed out by hand would be the eighth such list in this project, and the
    -- other seven have all drifted. This one cannot: it reads the labels that are
    -- actually on screen, so an option added tomorrow is searchable with no extra step.
    --
    -- The wrinkle is that a label is not reliably part of the control it names. About
    -- half are regions of their checkbox; the other half - the ones beside dropdowns
    -- and sliders - are regions of the COLUMN, so no amount of walking children finds
    -- them. What is reliable is that a label and the thing it labels sit on the same
    -- LINE, which is a property of the layout rather than of how it was written.
    --
    -- So: group everything in a column by vertical position, and let each group share
    -- its combined text. Section headers land on their own line and so form their own
    -- group, which is what makes a whole section recede when nothing in it matches.
    local LINE_TOLERANCE = 10   -- px; a label and its control are on the same line
    local searchIndex = nil

    local function BuildSearchIndex()
        local groups = {}
        for _, col in ipairs(columnFrames) do
            local entries = {}

            local function consider(el, isText)
                if not el or not el.GetTop then return end
                local top = el:GetTop()
                if not top then return end
                entries[#entries + 1] = { el = el, top = top, isText = isText }
            end

            local kids = { col:GetChildren() }
            for _, kid in ipairs(kids) do
                consider(kid, false)
                -- A control's own label rides along with it, so no separate lookup.
                local kidRegions = { kid:GetRegions() }
                for _, r in ipairs(kidRegions) do
                    if r and r.GetObjectType and r:GetObjectType() == "FontString" then
                        consider(r, true)
                    end
                end
            end
            local colRegions = { col:GetRegions() }
            for _, r in ipairs(colRegions) do
                if r and r.GetObjectType and r:GetObjectType() == "FontString" then
                    consider(r, true)
                end
            end

            table.sort(entries, function(a, b)
                if a.top ~= b.top then return a.top > b.top end
                -- Total order: equal tops must not sort arbitrarily, or the grouping
                -- below lands differently between runs.
                return tostring(a.el) < tostring(b.el)
            end)

            local current = nil
            for _, e in ipairs(entries) do
                if not current or (current.top - e.top) > LINE_TOLERANCE then
                    current = { top = e.top, els = {}, words = {} }
                    groups[#groups + 1] = current
                end
                current.els[#current.els + 1] = e.el
                if e.isText then
                    local t = e.el:GetText()
                    if t and t ~= "" then current.words[#current.words + 1] = t end
                end
            end
        end

        for _, g in ipairs(groups) do
            g.text = strlower(table.concat(g.words, " "))
        end
        return groups
    end

    -- Applying a filter is alpha only: no anchors move, so nothing can collapse.
    local DIMMED = 0.22

    local function ApplySettingsFilter(query)
        -- Built lazily, and only from a panel that has actually been laid out.
        -- GetTop() returns nil for a frame that has never been positioned, so an index
        -- built too early would be empty - and being cached, it would stay empty for
        -- the session, with searching silently doing nothing at all.
        --
        -- An implausible result is therefore NOT cached: the next keystroke tries
        -- again, so this heals itself rather than failing once and forever.
        if not searchIndex then
            if not parent:IsShown() then return end
            local built = BuildSearchIndex()
            if #built < 10 then return end
            searchIndex = built
        end
        query = strlower(strtrim(query or ""))

        -- Counted as we go. Only groups that carry TEXT count as matches: a spacer or
        -- a bare texture follows the filter visually but is not a setting anyone was
        -- looking for, and counting them would inflate every number.
        local matched = 0

        for _, g in ipairs(searchIndex) do
            -- A group with no text at all (a bare texture or spacer) follows the
            -- filter rather than staying lit, or clearing the page would leave odd
            -- bright fragments floating in the dimmed background.
            local show = (query == "") or (g.text ~= "" and g.text:find(query, 1, true) ~= nil)
            if show and g.text ~= "" and query ~= "" then matched = matched + 1 end
            local target = show and 1 or DIMMED
            for _, el in ipairs(g.els) do
                if el.SetAlpha then
                    if el.GetAlpha and math.abs((el:GetAlpha() or 1) - target) < 0.01 then
                        -- Already there. Skip, so typing another letter does not
                        -- restart forty-odd tweens that have nothing to do.
                    elseif Anim and Anim.owned then
                        local from = el:GetAlpha() or 1
                        Anim.owned(el, "searchdim", {
                            duration = MOTION.fast,
                            onUpdate = function(e) el:SetAlpha(from + (target - from) * e) end,
                            onDone = function() el:SetAlpha(target) end,
                        })
                    else
                        el:SetAlpha(target)
                    end
                end
            end
        end

        if query == "" then
            searchCount:SetText("")
        elseif matched == 0 then
            searchCount:SetText("|cFFFF5555no matches|r")
        else
            searchCount:SetText("|cFF888888" .. matched .. " match"
                .. (matched == 1 and "" or "es") .. "|r")
        end
    end

    -- The two-stage Escape and the hint handling now live in ns.CreateSearchBox; this
    -- panel is where that behaviour was first written, and it is the version that won.
    ApplySettingsFilterRef = ApplySettingsFilter

    -- Structural safeguard: warn immediately if any column has overlapping controls.
    CheckColumnAnchors(col1, "column 1")
    CheckColumnAnchors(col2, "column 2")
    CheckColumnAnchors(col3, "column 3")

    return parent
end

ns.CreateSettingsPanel = CreateSettingsPanel
