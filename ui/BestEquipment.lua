-- ui/BestEquipment.lua
-- The Best Equipment tab: per-scale columns of best-in-slot items, the weapon-set
-- panel, Equip All / Save Set / Clear, and the equipped-vs-best summary.
--
-- Keeps the v0.9.5a frame POOL (BuildBestEquipColumn builds a column's structure once;
-- UpdateBestEquipmentDisplay only sets content and rebinds closures) - WoW never frees
-- CreateFrame widgets, so rebuilding rows on every refresh leaked them.
--
-- Its scroll/content frames are file-local; the panel reaches shared state through
-- ns.ValuateUIFrame. Valuate.RefreshBestEquipmentDisplay and
-- Valuate.RevealBestEquipmentColumns are published on the Valuate table because the
-- core addon and the tab system call them.

local _, ns = ...

local PADDING, ELEMENT_SPACING, INNER_SPACING = ns.PADDING, ns.ELEMENT_SPACING, ns.INNER_SPACING
local BUTTON_HEIGHT, SCROLLBAR_WIDTH = ns.BUTTON_HEIGHT, ns.SCROLLBAR_WIDTH
local MIN_WINDOW_HEIGHT, MAX_WINDOW_HEIGHT = ns.MIN_WINDOW_HEIGHT, ns.MAX_WINDOW_HEIGHT
local COLORS = ns.COLORS
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
local HexToRGB = ns.HexToRGB
local Anim = ns.Anim


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

ns.CreateBestEquipmentPanel = CreateBestEquipmentPanel
