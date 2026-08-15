-- ui/ScaleEditor.lua
-- The right-hand scale editor: the stat-weight grid (5 columns of stat rows with value
-- boxes and ban checkboxes), the Equipment Types and Weapon Sets groups, and the
-- import/export dialogs.
--
-- StatWeightRows is file-local - it is the editor's own widget pool. Genuinely a pool
-- since v0.33.0a: it is built once and REPOPULATED when a different scale is opened.
-- Before that it was emptied and rebuilt, which orphaned ~250 frames per scale click,
-- because WoW never frees a frame. Shared state comes from the namespace
-- (ns.EditingScaleName, ns.ScaleEditorFrame, ns.ValuateUIFrame).
--
-- ValuateUI_UpdateScaleEditor / ValuateUI_CreateScaleFromTemplate / ValuateUI_NewScale
-- stay globals, and Valuate:ShowExportDialog / ShowImportDialog stay on the Valuate
-- table, because both are called from outside this file.

local _, ns = ...

local PADDING, ELEMENT_SPACING, INNER_SPACING, COLUMN_GAP =
    ns.PADDING, ns.ELEMENT_SPACING, ns.INNER_SPACING, ns.COLUMN_GAP
local BUTTON_HEIGHT, ENTRY_HEIGHT, SCROLLBAR_WIDTH =
    ns.BUTTON_HEIGHT, ns.ENTRY_HEIGHT, ns.SCROLLBAR_WIDTH
local NUM_COLUMNS, COLUMN_WIDTH, ROW_HEIGHT, ROW_SPACING, HEADER_HEIGHT, HEADER_SPACING =
    ns.NUM_COLUMNS, ns.COLUMN_WIDTH, ns.ROW_HEIGHT, ns.ROW_SPACING, ns.HEADER_HEIGHT, ns.HEADER_SPACING
local MIN_WINDOW_HEIGHT, MAX_WINDOW_HEIGHT = ns.MIN_WINDOW_HEIGHT, ns.MAX_WINDOW_HEIGHT
local COLORS = ns.COLORS
local MOTION = ns.MOTION
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
local ApplyStatValueValidation, ApplyWholeNumberValidation =
    ns.ApplyStatValueValidation, ns.ApplyWholeNumberValidation
local HexToRGB = ns.HexToRGB
local UpdateScaleList = ns.UpdateScaleList
-- Anim.tween honours reduceMotion itself, jumping to the final state, so callers
-- never branch on it.
local Anim = ns.Anim

-- ========================================
-- Scale Editor (Right Panel)
-- ========================================

local StatWeightRows = {}

-- The built stat grid, kept between calls so showing a different scale repopulates it
-- instead of rebuilding it. nil means "not built yet".
--
-- This is what makes the grid a real pool. WoW never frees a frame, and the old code
-- discarded roughly 250 of them on every scale you clicked.
--
-- Reuse is only attempted when the cached grid still belongs to the CURRENT editor
-- frame. If it does not - or if it was never cached, which is what happens on the
-- defensive no-equipment-categories path - the function falls through and rebuilds
-- exactly as it always did. The worst case of a stale cache is therefore the old
-- behaviour, not a broken editor.
local statGrid = nil

-- ========================================
-- Stat search
-- ========================================

-- The current filter, remembered across scale switches.
--
-- Kept rather than cleared because the rows are POOLED: their alpha survives a
-- repopulate anyway, so clearing the query while the rows stayed dim would leave the
-- box and the grid disagreeing. Remembering it also matches what you are usually
-- doing - comparing one stat across several scales.
local statQuery = ""

-- Dims the rows that do not match, instead of hiding them.
--
-- Same choice as the Settings search and for a stronger reason: this is a fixed
-- five-column grid built from static category tables, so hiding rows would either
-- leave holes or force a relayout of all sixty on every keystroke.
--
-- Dimming is done with the ROW's alpha, deliberately not its text colour.
-- ApplyWeightedLook already owns the label colour and the input border - it is what
-- marks a stat that carries a weight - and a second writer on that property is the
-- fault this codebase keeps finding. Alpha is uncontested, so the two compose: a
-- weighted stat that matches your search still reads as weighted.
--
-- Instant, with no tween. This runs on every keystroke, and an animated filter would
-- still be catching up with what you typed three characters ago.
local DIM_ALPHA = 0.25

local function ApplyStatFilter(query)
    statQuery = strlower(strtrim(query or ""))
    if not statGrid or not statGrid.rows then return 0, 0 end

    local shown, total = 0, 0
    for _, row in ipairs(statGrid.rows) do
        -- Stat rows are the ones that can be repopulated; the rest of this table is
        -- containers, column frames and section headers, which must never dim.
        if row.populate and row.statName then
            total = total + 1
            local display = ValuateStatNames[row.statName] or row.statName
            local match = statQuery == ""
                or string.find(strlower(display), statQuery, 1, true) ~= nil
                -- The raw key too: someone who knows the data can type "TwoHandDps"
                -- and not have to guess the label.
                or string.find(strlower(row.statName), statQuery, 1, true) ~= nil
            if match then shown = shown + 1 end
            row:SetAlpha(match and 1 or DIM_ALPHA)
        end
    end
    return shown, total
end

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
    
    -- A row with a weight set reads differently from an empty one. With ~60 stats
    -- across five columns, the handful you actually care about were impossible to
    -- pick out at a glance - every row looked identical.
    --
    -- Declared HERE, above every function that calls it (CommitValue below,
    -- UpdateBannedState further down). A local declared beneath its callers
    -- compiles to a nil global and errors on first use - the scope checker caught
    -- exactly that when this sat lower in the file.
    local function ApplyWeightedLook()
        local v = tonumber(editBox:GetText()) or 0
        if v ~= 0 then
            label:SetTextColor(unpack(COLORS.textAccent))
            editBox:SetBackdropBorderColor(unpack(COLORS.borderLight))
        else
            label:SetTextColor(unpack(COLORS.textBody))
            editBox:SetBackdropBorderColor(unpack(COLORS.border))
        end
    end

    -- Single commit path, shared by Enter and focus-loss.
    --
    -- Only Enter used to save. Typing a weight and then clicking another field -
    -- the obvious way to fill in several stats - discarded it silently: the number
    -- stayed on screen, so the edit looked accepted, but it never reached the scale
    -- and vanished on the next refresh.
    local function CommitValue()
        local value = tonumber(editBox:GetText()) or 0
        local editing = ns.EditingScaleName
        local currentScale = editing and Valuate:GetScales()[editing]
        if currentScale then
            if not currentScale.Values then currentScale.Values = {} end
            currentScale.Values[editBox.statName] = (value ~= 0) and value or nil

            -- Reset all tooltips to reflect the change immediately
            if Valuate.ResetTooltips then
                Valuate:ResetTooltips()
            end
        end
        ApplyWeightedLook()
        -- Read through ns at call time: this file defines the summary further down,
        -- so a local copy here would be nil.
        if ns.UpdateScaleEditorSummary then ns.UpdateScaleEditorSummary() end

        -- Brief accent flash on the input border, so a committed value is visibly
        -- acknowledged. Worth more here than anywhere else in the UI: until
        -- recently, clicking away from a field silently discarded the edit, and the
        -- box looked identical either way. Now "saved" has a tell.
        -- Owned by this box, so a second commit replaces the flash already running
        -- instead of two of them fighting over the same border colour.
        --
        -- More reachable since the stat grid became a pool (v0.33.0a): switching scales
        -- now REUSES this edit box, so a flash started under the previous scale would
        -- otherwise carry on painting over the row after it had been repopulated. It
        -- settles correctly either way - onDone hands the final look back to
        -- ApplyWeightedLook, which reads current state - but the transient belonged to
        -- a scale you were no longer looking at.
        Anim.owned(editBox, "commitflash", {
            duration = MOTION.slow, ease = "outQuad",
            onUpdate = function(e)
                -- Full accent at the start, easing back to the row's resting border,
                -- which differs depending on whether the row now carries a weight.
                local from = COLORS.textAccent
                local to = (value ~= 0) and COLORS.borderLight or COLORS.border
                editBox:SetBackdropBorderColor(
                    from[1] + (to[1] - from[1]) * e,
                    from[2] + (to[2] - from[2]) * e,
                    from[3] + (to[3] - from[3]) * e,
                    1)
            end,
            -- Hand the final look back to ApplyWeightedLook rather than leaving the
            -- tween's last frame as the resting state.
            onDone = ApplyWeightedLook,
        })
    end

    -- What this weight is actually doing, at the moment you are deciding what to type.
    --
    -- /valuate weights answers the same question for the whole scale, but the answer
    -- belongs here: with ~60 rows across five columns, "is this one worth tuning?" is asked
    -- per row, and going to the chat frame to find out breaks the thing you were doing.
    --
    -- Hover only, no layout. A share column on every row would need width this grid does
    -- not have, and would put a number next to fifty-odd stats that contribute nothing.
    editBox:SetScript("OnEnter", function(self)
        if not ShowTooltipSafe(self, "ANCHOR_RIGHT") then return end
        local statLabel = ValuateStatNames[statName] or statName
        GameTooltip:AddLine(statLabel, 1, 1, 1)

        local currentScale = ns.EditingScaleName and Valuate:GetScales()[ns.EditingScaleName]
        local entry, isIdle, slotsRead
        if currentScale and Valuate.GetStatShareInfo then
            entry, isIdle, slotsRead = Valuate:GetStatShareInfo(statName, currentScale)
        end

        if entry then
            GameTooltip:AddLine(string.format("|cFF00FF00%.1f%%|r of this scale's score on your gear",
                entry.share), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(string.format("You are wearing %s of it, weighted %s.",
                tostring(entry.value), tostring(entry.weight)), 0.7, 0.7, 0.7, true)
        elseif isIdle then
            -- Not an error. A weight for a stat you pick up twenty levels from now is a
            -- plan, and a tooltip that calls it a mistake teaches you to stop reading.
            GameTooltip:AddLine("|cFFFF8800You are carrying none of this stat|r", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("The weight is saved and changes nothing until you equip some.",
                0.7, 0.7, 0.7, true)
        elseif slotsRead and slotsRead > 0 then
            GameTooltip:AddLine("No weight set, so it does not count toward this scale.",
                0.7, 0.7, 0.7, true)
        else
            -- Says WHY there is no figure rather than showing a confident zero.
            GameTooltip:AddLine("Equipped gear not readable yet - hover again in a moment.",
                0.7, 0.7, 0.7, true)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFF888888/valuate weights ranks every stat at once|r", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    editBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Focus handling
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function(self)
        CommitValue()
        self:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", CommitValue)
    
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
            editBox:EnableMouse(true)
            editBox:EnableKeyboard(true)
            editBox:SetBackdropColor(unpack(COLORS.inputBg))
            -- Label colour and border now come from ApplyWeightedLook, so unbanning
            -- a stat that still holds a weight restores the highlight rather than
            -- flattening it back to the default look.
            ApplyWeightedLook()
        end
    end
    
    -- Everything that depends on WHICH scale is being edited, in one place.
    --
    -- Separated from construction so a row can be shown for a different scale instead
    -- of being thrown away and rebuilt. That is the whole reason the grid can be
    -- pooled: nothing else in this row captures the scale - every other handler reads
    -- ns.EditingScaleName when it runs.
    --
    -- It is called once during construction, so a freshly built row takes exactly the
    -- same path it always did.
    local function Populate(forScale)
        local isUnusable = (forScale and forScale.Unusable and forScale.Unusable[statName]) == true
        unusableCheckbox:SetChecked(isUnusable)

        if isUnusable then
            UpdateBannedState(true)   -- clears the text itself
        else
            local value = (forScale and forScale.Values and forScale.Values[statName])
            editBox:SetText((value and value ~= 0) and tostring(value) or "")
            -- Text FIRST. UpdateBannedState(false) finishes by calling
            -- ApplyWeightedLook, which reads the box - set the value afterwards and the
            -- highlight would still be describing the previous scale's weight.
            --
            -- A fresh row is already un-banned so this is a no-op for it; a REUSED row
            -- may have been banned by the scale shown before, and this is what clears
            -- that.
            UpdateBannedState(false)
        end
    end

    Populate(scale)

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
        if ns.UpdateScaleEditorSummary then ns.UpdateScaleEditorSummary() end
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
    row.populate = Populate
    row.statName = statName
    
    return row
end

-- Builds the stat grid once, then reuses it.
--
-- It used to discard every row and rebuild on each call - roughly 250 frames for ~60
-- stat rows plus their columns and containers. SetParent(nil) does not free a frame in
-- WoW, so each call orphaned all of them permanently: clicking through ten scales cost
-- on the order of 2,500 frames, and frame count is a global UI cost rather than just
-- this addon's problem. ui/BestEquipment.lua had already been rewritten around a pool
-- for exactly this reason; this function had not.
--
-- Three facts make the reuse safe, and it would not have been without them:
--
--   * The layout is scale-INVARIANT. It is generated from ValuateStatCategories and
--     ValuateEquipmentCategories, which are static data.
--   * A row captures nothing about its scale except two values. Every handler on it
--     already reads ns.EditingScaleName when it fires, so only row.populate has to run
--     again - and it is the same code a fresh row runs.
--   * UpdateBannedState is symmetric, so a row banned by the previous scale can be
--     cleanly un-banned rather than staying visually disabled.
--
-- The weapon-set widgets were the exception - they captured their scale table - which
-- is why that had to be fixed (v0.32.1a) before this was possible at all.
local function UpdateStatWeightsList(scaleName, scale)
    if not ns.ScaleEditorFrame then return end

    -- ---- Fast path: the grid already exists, so show this scale in it ----------
    --
    -- The layout is identical for every scale: it comes entirely from
    -- ValuateStatCategories and ValuateEquipmentCategories, which are static. Only the
    -- VALUES differ, and each row knows how to apply them - row.populate runs the same
    -- code a freshly built row runs, so a reused row cannot end up in a state a new one
    -- could not.
    if statGrid and statGrid.parent == ns.ScaleEditorFrame then
        for _, row in ipairs(statGrid.rows) do
            if row.populate then row.populate(scale) end
        end

        -- The weapon-set widgets are not rows and hold their own scale-dependent state.
        -- Their click handlers already read the scale being edited (see CurrentScale
        -- below), so only the displayed state needs refreshing.
        for _, entry in ipairs(statGrid.weaponSetChecks) do
            entry.cb:SetChecked(Valuate:IsWeaponSetEnabled(scale, entry.key))
        end
        if statGrid.activeSetButton and statGrid.activeSetDisplay then
            statGrid.activeSetButton.label:SetText(statGrid.activeSetDisplay())
        end

        -- Heights are a function of the layout, which has not changed - so they are
        -- reapplied from the values computed when it was built rather than recomputed.
        ns.ScaleEditorFrame.animContainers = statGrid.animContainers
        Anim.setHeight(ns.ScaleEditorFrame, statGrid.editorHeight, false)
        if ns.ValuateUIFrame and statGrid.windowHeight then
            Anim.setHeight(ns.ValuateUIFrame, statGrid.windowHeight, true)
        end
        return
    end

    -- ---- Slow path: build it (first time, or the editor frame was replaced) -----
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
    -- Tracked separately from StatWeightRows for the load fade: that table holds the
    -- containers AND every row inside them, so fading all of it would stack alpha.
    ns.ScaleEditorFrame.animContainers = { itemStatsContainer }
    
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
        if ns.ScaleEditorFrame.animContainers then
            tinsert(ns.ScaleEditorFrame.animContainers, equipmentTypesContainer)
        end
        
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
        ns.SetSolidColor(separator, unpack(COLORS.border))
        
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
        ns.SetSolidColor(wsSep, unpack(COLORS.border))
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
        -- The handlers below must read the CURRENT scale, not the one that was passed
        -- in when they were built.
        --
        -- CommitValue further up this file already does exactly this, and says why:
        -- importing a scale tag or loading one from the library REPLACES the scale
        -- table wholesale (scales[name] = newData). A captured reference then points at
        -- an orphan, so toggling a weapon set writes to a table nothing reads - the
        -- checkbox moves, the setting does not stick, and nothing errors.
        --
        -- Same reasoning, four functions apart; these had not been given it.
        local function CurrentScale()
            local editing = ns.EditingScaleName
            return editing and Valuate:GetScales()[editing] or nil
        end

        -- Collected so the fast path at the top can refresh their checked state
        -- without rebuilding them.
        local wsChecks = {}

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
                local cur = CurrentScale()
                if not cur then return end
                if not cur.WeaponSets then
                    -- Materialize the implicit "all enabled" default before editing.
                    cur.WeaponSets = {}
                    for _, d in ipairs(wsDefs) do cur.WeaponSets[d.key] = true end
                end
                cur.WeaponSets[def.key] = checked or nil
                Valuate:ScanBestEquipment()
                if Valuate.RefreshBestEquipmentDisplay then Valuate:RefreshBestEquipmentDisplay() end
                if Valuate.ResetTooltips then Valuate:ResetTooltips() end
            end)
            tinsert(StatWeightRows, cb)
            tinsert(wsChecks, { cb = cb, key = def.key })
        end

        -- Active-set selector: click to cycle Auto -> each enabled config.
        local function activeSetDisplay()
            local cur = CurrentScale()
            local key = cur and cur.ActiveWeaponSet
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
            local editScale = CurrentScale()
            if not editScale then return end
            local order = { "auto" }
            for _, d in ipairs(wsDefs) do
                if Valuate:IsWeaponSetEnabled(editScale, d.key) then tinsert(order, d.key) end
            end
            local cur = editScale.ActiveWeaponSet or "auto"
            local curIdx = 1
            for i, k in ipairs(order) do if k == cur then curIdx = i break end end
            editScale.ActiveWeaponSet = order[(curIdx % #order) + 1]
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
        local editorHeight = math.max(totalContentHeight, 100)
        local windowHeight = nil
        if ns.ScaleEditorFrame then
            Anim.setHeight(ns.ScaleEditorFrame, editorHeight, false)

            -- Resize main window to fit content
            if ns.ValuateUIFrame then
                -- Calculate needed window height:
                -- Title bar (40) + Tab bar (30) + Scale editor header (40) + Element spacing (8) + Content + Bottom padding (PADDING)
                local neededHeight = 40 + 30 + 40 + ELEMENT_SPACING + totalContentHeight + PADDING
                windowHeight = math.max(MIN_WINDOW_HEIGHT, math.min(MAX_WINDOW_HEIGHT, neededHeight))
                Anim.setHeight(ns.ValuateUIFrame, windowHeight, true)
            end
        end

        -- Cache what was just built, so the next scale reuses it. Recorded only on this
        -- path: it is the one that builds the complete grid, and caching a partial one
        -- would be worse than not caching at all.
        statGrid = {
            parent = ns.ScaleEditorFrame,
            rows = StatWeightRows,
            weaponSetChecks = wsChecks,
            activeSetButton = wsActiveButton,
            activeSetDisplay = activeSetDisplay,
            animContainers = ns.ScaleEditorFrame and ns.ScaleEditorFrame.animContainers or nil,
            editorHeight = editorHeight,
            windowHeight = windowHeight,
        }

        -- A freshly built grid starts at full alpha, so an active search has to be
        -- re-applied or the box would say one thing and the grid show another. The
        -- CACHED path above needs no such call: rows are pooled and populate never
        -- touches alpha, so their dim survives a repopulate by itself.
        ApplyStatFilter(statQuery)

        return -- Exit early since we've handled equipment types
    end
    
    -- If no equipment categories, just set ns.ScaleEditorFrame height based on Item Stats
    if ns.ScaleEditorFrame then
        Anim.setHeight(ns.ScaleEditorFrame, math.max(itemStatsMaxHeight, 100), false)
        
        -- Resize main window to fit content
        if ns.ValuateUIFrame then
            -- Calculate needed window height:
            -- Title bar (40) + Tab bar (30) + Scale editor header (40) + Element spacing (8) + Content + Bottom padding (PADDING)
            local neededHeight = 40 + 30 + 40 + ELEMENT_SPACING + itemStatsMaxHeight + PADDING
            local windowHeight = math.max(MIN_WINDOW_HEIGHT, math.min(MAX_WINDOW_HEIGHT, neededHeight))
            Anim.setHeight(ns.ValuateUIFrame, windowHeight, true)
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

    -- Refresh the header summary for the scale just loaded.
    if ns.UpdateScaleEditorSummary then ns.UpdateScaleEditorSummary() end

    -- Fade the stat grid in when switching scales, so the ~60 rows arrive as a
    -- change rather than an instant swap of one wall of numbers for another.
    --
    -- The CONTAINERS are faded, not the individual rows: StatWeightRows holds both
    -- containers and every row inside them, so tweening each entry would stack
    -- alpha (row alpha x container alpha) and leave rows visibly dimmer than the
    -- grid they sit in.
    local containers = ns.ScaleEditorFrame and ns.ScaleEditorFrame.animContainers
    if containers then
        local gap = Anim.staggerFor(#containers)
        for i, frame in ipairs(containers) do
            Anim.revealIn(frame, (i - 1) * gap)
        end
    end
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
        -- Carried onto the scale, not left behind on the template.
        --
        -- The picker's tooltip warns that six specs have weights nobody ever published, but a
        -- warning that lasts one hover is barely a warning: the instant you click, the scale
        -- it makes looks exactly like one built on researched numbers, and it stays that way
        -- for as long as you use it. This is what lets the scale keep saying it.
        Inferred = template.inferred or nil,
        Values = {},
        Unusable = {}
    }
    
    -- Copy stat weights from template, with the defensive floor applied.
    --
    -- The same treatment the wizard gives them. Building "From Template" is the other way a
    -- template becomes a real scale, and a build that values survivability through one door
    -- and not the other would be the sort of inconsistency nobody could explain.
    if template.weights then
        local weights = (Valuate.ApplyDefensiveFloor
            and Valuate:ApplyDefensiveFloor(template.weights, template.role))
            or template.weights
        for statName, value in pairs(weights) do
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
    
    -- Close on Escape. Routed through the shared helper like every other frame, so
    -- the duplicate guard applies here too.
    if ns.RegisterEscapeClose then ns.RegisterEscapeClose("ValuateImportExportDialog") end
    
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
    local scaleTag, whyNot = self:GetScaleTag(scaleName)
    if not scaleTag then
        -- Say WHICH problem. A refused export is almost always a name this addon
        -- cannot round-trip, and that is something the user can fix in ten seconds
        -- if told, and cannot fix at all if not.
        print("|cFFFF0000Valuate|r: " .. (whyNot or "Failed to generate export string for scale."))
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
-- ========================================
-- Scale Library dialog
-- ========================================
-- Scales are per-character, so the library is the only way to reuse one without
-- copying a tag by hand. Rows are POOLED and rebuilt on each open: the list is
-- small and changes rarely, so a pool is simpler than incremental updates and
-- cannot leave a stale row behind after a delete.
local ScaleLibraryFrame
local libraryRows = {}

local function RefreshScaleLibraryList()
    local frame = ScaleLibraryFrame
    if not frame then return end

    for _, row in ipairs(libraryRows) do row:Hide() end

    local names = Valuate:ListScaleLibrary()
    -- Show/Hide rather than SetShown: that is a later-expansion API which this
    -- client happens to have backported, and nothing else in Valuate relies on it.
    if #names == 0 then frame.emptyLabel:Show() else frame.emptyLabel:Hide() end

    local y = 0
    local rowGap = Anim.staggerFor(#names)
    for i, entryName in ipairs(names) do
        local row = libraryRows[i]
        if not row then
            row = CreateFrame("Frame", nil, frame.content)
            row:SetHeight(ENTRY_HEIGHT)
            row:SetPoint("LEFT", frame.content, "LEFT", 0, 0)
            row:SetPoint("RIGHT", frame.content, "RIGHT", 0, 0)

            row.label = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
            row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetTextColor(unpack(COLORS.textBody))

            row.deleteBtn = CreateStyledButton(row, "Delete", 60, 18)
            row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

            row.loadBtn = CreateStyledButton(row, "Load", 60, 18)
            row.loadBtn:SetPoint("RIGHT", row.deleteBtn, "LEFT", -6, 0)

            row.label:SetPoint("RIGHT", row.loadBtn, "LEFT", -6, 0)
            libraryRows[i] = row
        end

        row:SetPoint("TOP", frame.content, "TOP", 0, -y)
        row.label:SetText(entryName)

        -- Rebound every refresh so a row reused for a different entry never keeps
        -- the previous name in its closure.
        row.loadBtn:SetScript("OnClick", function()
            local ok, result = Valuate:LoadScaleFromLibrary(entryName, true)
            if ok then
                print("|cFF00FF00Valuate|r: Loaded '" .. tostring(result) .. "' onto this character.")
                UpdateScaleList()
                if Valuate.ScanBestEquipment then Valuate:ScanBestEquipment() end
            else
                print("|cFFFF0000Valuate|r: " .. tostring(result))
            end
        end)
        row.deleteBtn:SetScript("OnClick", function()
            Valuate:ShowConfirmDialog({
                text = "Remove \"" .. entryName .. "\" from the shared library?\n\n"
                    .. "Scales already on your characters are not affected.",
                acceptText = "Remove",
                cancelText = "Cancel",
                onAccept = function()
                    Valuate:DeleteScaleFromLibrary(entryName)
                    RefreshScaleLibraryList()
                end,
            })
        end)

        row:Show()
        -- Cascade the rows in, matching the reveals elsewhere. The gap shrinks as the
        -- library grows, so a dozen entries still finish in about the same time as three.
        Anim.revealIn(row, (i - 1) * rowGap, MOTION.fast)
        y = y + ENTRY_HEIGHT + 2
    end

    frame.content:SetHeight(math.max(y, 1))
end

local function CreateScaleLibraryFrame()
    local frame = CreateFrame("Frame", "ValuateScaleLibraryFrame", UIParent)
    if ns.RegisterEscapeClose then ns.RegisterEscapeClose("ValuateScaleLibraryFrame") end
    frame:SetWidth(360)
    frame:SetHeight(320)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.borderLight))
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("Scale Library")
    title:SetTextColor(unpack(COLORS.textAccent))

    local subtitle = frame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetText("Shared by all your characters")
    subtitle:SetTextColor(unpack(COLORS.textDim))

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 56)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 24)))
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(330)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    frame.content = content

    local empty = frame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    empty:SetPoint("CENTER", scroll, "CENTER", 0, 0)
    empty:SetWidth(300)
    empty:SetJustifyH("CENTER")
    empty:SetText("Nothing saved yet.\n\nUse |cFFFFFFFFSave Current Scale|r below to add the one you're editing.")
    empty:SetTextColor(unpack(COLORS.textDim))
    frame.emptyLabel = empty

    local saveBtn = CreateStyledButton(frame, "Save Current Scale", 150, 22)
    saveBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 16)
    saveBtn:SetScript("OnClick", function()
        local ok, result = Valuate:SaveScaleToLibrary(ns.EditingScaleName)
        if ok then
            print("|cFF00FF00Valuate|r: Saved '" .. result .. "' to the shared library.")
            RefreshScaleLibraryList()
        else
            print("|cFFFF0000Valuate|r: " .. tostring(result)
                .. " - select a scale in the list first.")
        end
    end)

    local closeBtn = CreateStyledButton(frame, "Close", 90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 16)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    ScaleLibraryFrame = frame
    return frame
end

function Valuate:ShowScaleLibrary()
    local frame = ScaleLibraryFrame or CreateScaleLibraryFrame()
    RefreshScaleLibraryList()
    frame:Show()
    Anim.popIn(frame)
end

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
    headerFrame:SetHeight(40)   -- grown to HEADER_HEIGHT_WARNED when a scale carries the guess warning
    
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

    -- Stat search, on the right of the same header row.
    --
    -- There are around sixty stat rows across five columns. Finding the one you want
    -- meant reading all of them, which is exactly the problem the Settings panel's
    -- search already solved for a smaller list.
    local searchCount = headerFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    searchCount:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
    searchCount:SetTextColor(unpack(COLORS.textDim))
    searchCount:SetText("")

    -- Named, unlike most frames here. Every stat weight box carries an OnTextChanged
    -- handler too (input validation), so "the EditBox that reacts to typing" does not
    -- identify this one - a name does, and it is the same thing the confirm dialog and the
    -- upgrade popup do.
    local searchBox = ns.CreateSearchBox(headerFrame, {
        name = "ValuateStatSearchBox",
        height = 22,
        hint = "Find a stat...",
        fontObject = _G[FONT_BODY],
        onQuery = function(text)
            local shown, total = ApplyStatFilter(text)
            if text == "" or total == 0 then
                searchCount:SetText("")
            elseif shown == 0 then
                -- Says nothing matched rather than leaving a uniformly dim grid looking
                -- like a rendering fault.
                searchCount:SetText("|cFFFF8800no match|r")
            else
                searchCount:SetText("|cFF888888" .. shown .. "/" .. total .. "|r")
            end
        end,
    })
    searchBox:SetWidth(150)
    searchBox:SetPoint("RIGHT", searchCount, "LEFT", -6, 0)

    searchBox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_BOTTOM") then
            GameTooltip:AddLine("Find a stat", 1, 1, 1)
            GameTooltip:AddLine("Dims the stats that do not match, rather than hiding them, so nothing moves while you type.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Matches the label or the internal name. Escape clears it.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    searchBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
                -- A rename moves the scale to a new key, so anything keyed on the old
                -- name is now stale: the "Best for" line, and the upgrade-arrow cache
                -- if this was your primary scale.
                if Valuate.ResetTooltips then Valuate:ResetTooltips() end
            end
        end
        self:ClearFocus()
    end)
    -- Renames deliberately commit on Enter ONLY - clicking away should never rename
    -- a scale by accident. But the box used to keep displaying the typed text after
    -- focus was lost, so it showed a name the scale did not actually have. Restore
    -- the real one instead of leaving the field lying about it.
    nameEditBox:SetScript("OnEditFocusLost", function(self)
        local editing = ns.EditingScaleName
        local scale = editing and Valuate:GetScales()[editing]
        if scale then
            self:SetText(scale.DisplayName or editing)
        end
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
    
    -- At-a-glance summary of what this scale actually contains. Anchored to the
    -- header's RIGHT edge, so it can't collide with the button row growing from the
    -- left however long the scale name gets.
    local summaryText = headerFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    summaryText:SetPoint("RIGHT", headerFrame, "RIGHT", -4, 0)
    summaryText:SetJustifyH("RIGHT")
    summaryText:SetTextColor(unpack(COLORS.textDim))

    -- The "these numbers were guessed" line. Its own font string rather than more text
    -- appended to the summary, because it needs to WRAP and the summary is a single
    -- right-aligned line - and because a caveat crammed onto the end of a stat count is a
    -- caveat nobody reads.
    --
    -- Anchored to nameLabel, not to headerFrame. The header is already summaryText's anchor,
    -- and two controls sharing one produce the overlap CheckColumnAnchors exists to catch.
    --
    -- The HEADER GROWS to fit it instead of the line being placed below the header: the stat
    -- grid anchors to the header's bottom edge, so a line placed outside would render
    -- underneath the grid. Growing the header moves the grid down for free, and on the
    -- ninety-five scales that are not guesses the layout is exactly what it was.
    local inferredText = headerFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    inferredText:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -INNER_SPACING)
    inferredText:SetJustifyH("LEFT")
    inferredText:Hide()

    local HEADER_HEIGHT_PLAIN = 40
    local HEADER_HEIGHT_WARNED = 62

    -- Published on ns because CreateStatRow is defined ABOVE this function and so
    -- cannot see a local declared here. Callers read ns at call time, never
    -- re-localise it.
    local function UpdateEditorSummary()
        local editing = ns.EditingScaleName
        local scale = editing and Valuate:GetScales()[editing]
        if not scale then
            summaryText:SetText("")
            return
        end

        local weighted, banned = 0, 0
        if scale.Values then
            for _, v in pairs(scale.Values) do
                if type(v) == "number" and v ~= 0 then weighted = weighted + 1 end
            end
        end
        if scale.Unusable then
            for _, v in pairs(scale.Unusable) do
                if v then banned = banned + 1 end
            end
        end

        if weighted == 0 then
            -- The most useful thing an empty scale can say is why it scores nothing.
            summaryText:SetText("|cFFFF8800No stats weighted|r - this scale won't score any item")
        else
            local parts = string.format("|cFFFFFFFF%d|r stat%s weighted", weighted, weighted == 1 and "" or "s")
            if banned > 0 then
                parts = parts .. string.format("  ·  |cFFFFFFFF%d|r banned", banned)
            end
            local total = Valuate.CalculateTotalEquippedScore
                and Valuate:CalculateTotalEquippedScore(scale) or nil
            if total and total > 0 then
                local decimals = Valuate:GetOptions().decimalPlaces or 1
                parts = parts .. string.format("  ·  gear " .. "|cFFFFFFFF%." .. decimals .. "f|r", total)
            end

            -- Where these numbers came from. Both facts were already stored on the scale and
            -- neither was ever shown, so a scale the wizard built from a Warrior Arms
            -- template looked identical to sixty numbers somebody typed in by hand.
            if scale.AutoSource then
                parts = parts .. string.format("  ·  from |cFFFFFFFF%s|r", tostring(scale.AutoSource))
            end

            summaryText:SetText(parts)
        end

        -- The warning outlives the click.
        --
        -- Six specs have no published stat priority, so theirs were read off their own prose.
        -- The picker says so while you hover, but that warning used to die the moment you
        -- committed - and the scale it made then looked exactly like one built on researched
        -- numbers for as long as you kept using it. This is the screen where you would act on
        -- it, so this is where it has to keep saying so.
        if scale.Inferred then
            -- Width is set here rather than by a second anchor point, so the header stays
            -- summaryText's alone. GetWidth is right by now; the header is already laid out.
            inferredText:SetWidth(math.max(120, (headerFrame:GetWidth() or 400) - 8))
            inferredText:SetText("|cFFFF8833These weights are a guess|r - no stat priority " ..
                "was ever published for this spec. Edit them as you learn what works.")
            inferredText:Show()
            headerFrame:SetHeight(HEADER_HEIGHT_WARNED)
        else
            inferredText:Hide()
            headerFrame:SetHeight(HEADER_HEIGHT_PLAIN)
        end
    end
    ns.UpdateScaleEditorSummary = UpdateEditorSummary

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



ns.CreateScaleEditor = CreateScaleEditor
