-- ui/ScaleList.lua
-- The left-hand scale list: the scrollable list of scales with their visibility
-- toggles, colour swatches and delete buttons.
--
-- ScaleListFrame is file-local (nothing outside this panel touches it). The genuinely
-- shared state it uses - ns.CurrentSelectedScale, ns.EditingScaleName,
-- ns.ScaleListButtons - lives on the namespace, which is why that conversion had to
-- happen before any panel could move.

local _, ns = ...

local PADDING, ELEMENT_SPACING, INNER_SPACING = ns.PADDING, ns.ELEMENT_SPACING, ns.INNER_SPACING
local BUTTON_HEIGHT, ENTRY_HEIGHT, SCROLLBAR_WIDTH = ns.BUTTON_HEIGHT, ns.ENTRY_HEIGHT, ns.SCROLLBAR_WIDTH
local SCALE_LIST_WIDTH = ns.SCALE_LIST_WIDTH
local COLORS = ns.COLORS
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
local HexToRGB, RGBToHex = ns.HexToRGB, ns.RGBToHex
local ShowIconPicker = ns.ShowIconPicker


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
        local da, db = (a.scale.DisplayName or a.name), (b.scale.DisplayName or b.name)
        if da ~= db then return da < db end
        return a.name < b.name  -- unique key breaks duplicate display names
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

ns.UpdateScaleList = UpdateScaleList
ns.CreateScaleList = CreateScaleList
