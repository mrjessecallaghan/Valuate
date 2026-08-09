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
local MOTION = ns.MOTION
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
-- TweenBackdrop honours reduceMotion itself, so callers never branch on it.
local TweenBackdrop = ns.TweenBackdrop
local HexToRGB, RGBToHex = ns.HexToRGB, ns.RGBToHex
local ShowIconPicker = ns.ShowIconPicker


-- ========================================
-- Scale List (Left Panel)
-- ========================================

local ScaleListFrame = nil

-- Forward declaration. The delete handler inside a row calls UpdateScaleList, and rows
-- are built ABOVE it - a `local function UpdateScaleList` further down would compile
-- that call to a nil global, which is silent: the scale would vanish from the saved
-- variables and stay on screen until you reopened the window. That exact shape (a local
-- declared below its reader) has cost this project three separate bugs.
local UpdateScaleList

-- The row pool.
--
-- WoW never frees a frame. SetParent(nil) does not free one; nothing does. This panel
-- used to build about five frames per scale on every call and orphan the previous set,
-- so creating, deleting, renaming or toggling a scale leaked permanently - slowly, but
-- with no upper bound across a session.
--
-- Rows are therefore built ONCE and repopulated, the same shape ui/BestEquipment.lua
-- uses. The rule that makes it safe: no handler may capture a scale. Every one reads
-- `self.scaleName` (or the row's) at the moment it runs, because a captured name on a
-- reused row is a click that acts on whatever scale used to be in that position - and
-- one of these buttons deletes a scale. tools/scalelisttest.js exists for that risk
-- specifically; it repopulates a pool with a different, shorter list and fires the
-- handlers to prove they follow.
local rowPool = {}

local function RowScale(row)
    return row.scaleName and Valuate:GetScales()[row.scaleName] or nil
end

-- Builds one row's structure. Called once per index, ever.
local function BuildScaleRow(index)
        local btn = CreateFrame("Button", nil, ScaleListFrame)
        btn:SetHeight(ENTRY_HEIGHT)
        btn:SetWidth(168)  -- Fits within scroll content area

        -- Anchored once, to the row above it in the POOL. Pool order never changes, so
        -- these points never need clearing - and a hidden row still anchors correctly
        -- because the rows after it are hidden too.
        if index == 1 then
            btn:SetPoint("TOP", ScaleListFrame, "TOP", 0, 0)
        else
            btn:SetPoint("TOP", rowPool[index - 1], "BOTTOM", 0, -2)
        end

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
        
        -- Color preview button (clickable to change color)
        local colorBtn = CreateFrame("Button", nil, btn)
        colorBtn:SetSize(14, 14)
        colorBtn:SetPoint("LEFT", visCheckbox, "RIGHT", 4, 0)

        local colorPreview = colorBtn:CreateTexture(nil, "OVERLAY")
        colorPreview:SetAllPoints(colorBtn)
        colorPreview:SetTexture(1, 1, 1, 1)

        -- Color picker on click
        colorBtn:SetScript("OnClick", function(self)
            local scale = RowScale(btn)
            if not scale then return end
            
            local currentColor = scale.Color or "FFFFFF"
            local cr, cg, cb = HexToRGB(currentColor)

            -- Captured at CLICK time, deliberately. The picker is modal, but the list
            -- can still be repopulated underneath it, and a callback that re-read the
            -- row would then recolour whichever scale had moved into this position.
            -- The swatch writes below are guarded on the row still showing this scale
            -- for the same reason.
            local scaleName = btn.scaleName

            ColorPickerFrame.previousValues = { cr, cg, cb }

            -- ColorPickerFrame belongs to Blizzard and is SHARED with every other addon.
            --
            -- We install func and cancelFunc on it and nothing ever removes them, so they
            -- outlive our use of the picker. Most addons set `func` before showing it, which
            -- displaces ours - but plenty set only `func` and leave `cancelFunc` alone. Then
            -- someone else's picker is cancelled, OUR cancelFunc runs, and it writes a
            -- Valuate scale's colour back to whatever previousValues we left behind.
            --
            -- The obvious fix - clear the fields when the picker hides - is the wrong one.
            -- The 3.3.5 cancel button hides the frame FIRST and calls cancelFunc after
            -- (which is why it passes previousValues explicitly), so clearing on OnHide
            -- would delete the callback moments before it was due to run and break cancel
            -- entirely. This is the sort of ordering I cannot check from here, so the fix
            -- must not depend on it.
            --
            -- Instead: a callback only acts while OUR func is still the installed one. That
            -- is precisely "is this still our session", it needs no cleanup, and it is
            -- correct whichever order Blizzard hides and cancels in.
            --
            -- Declared before the closures below so both can see it - the same
            -- local-above-its-readers rule that has cost this project three bugs.
            local myFunc

            myFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newColor = RGBToHex(newR, newG, newB)
                local scales = Valuate:GetScales()
                if scales[scaleName] then
                    scales[scaleName].Color = newColor
                end
                -- The swatch is the ONLY thing in a row that shows the scale's colour, and
                -- it is updated directly here. A full UpdateScaleList() used to follow,
                -- which was redundant - and ruinous.
                --
                -- WoW calls this on EVERY colour change, so it fires continuously while
                -- you drag the colour wheel. Each call rebuilt the whole list, and
                -- UpdateScaleList discards its buttons with SetParent(nil) - which does
                -- NOT free a frame in WoW. A few seconds of dragging with five scales
                -- therefore orphaned a couple of thousand frames, permanently.
                if btn.scaleName == scaleName then
                    colorPreview:SetVertexColor(newR, newG, newB, 1)
                end

                -- Reset tooltips to show new color immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            
            ColorPickerFrame.func = myFunc

            ColorPickerFrame.cancelFunc = function()
                -- Someone else owns the picker now, so this cancel is not ours to answer.
                if ColorPickerFrame.func ~= myFunc then return end

                local prev = ColorPickerFrame.previousValues
                local scales = Valuate:GetScales()
                if prev and scales[scaleName] then
                    scales[scaleName].Color = RGBToHex(prev[1], prev[2], prev[3])
                    -- Restore the swatch directly, for the same reason as above - and
                    -- only if this row still shows that scale.
                    if btn.scaleName == scaleName then
                        colorPreview:SetVertexColor(prev[1], prev[2], prev[3], 1)
                    end
                end

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

        -- The single place that decides how an icon slot looks: the scale's icon, or a
        -- dimmed placeholder when it has none. Three copies of this used to exist.
        local function ApplyIcon(icon)
            if icon and icon ~= "" then
                iconTexture:SetTexture(icon)
                iconTexture:SetVertexColor(1, 1, 1, 1)
            else
                iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                iconTexture:SetVertexColor(0.5, 0.5, 0.5, 0.5)
            end
        end

        -- Icon picker on click
        iconBtn:SetScript("OnClick", function(self)
            local scaleName = btn.scaleName
            ShowIconPicker(function(selectedIcon)
                if Valuate:GetScales()[scaleName] then
                    Valuate:GetScales()[scaleName].Icon = selectedIcon
                end
                -- Same guard as the colour picker: the picker is not modal to this
                -- list, so only touch the row if it still shows the scale you picked
                -- for.
                if btn.scaleName == scaleName then
                    ApplyIcon(selectedIcon)
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
            -- Read at CLICK time from the row, never captured at build time. This row
            -- has shown other scales and will show others again; a captured name here
            -- would delete whichever scale used to sit in this position. There is no
            -- undo for that.
            local scaleName = btn.scaleName
            if not scaleName then return end

            -- If Shift key is held down, delete immediately without confirmation
            if IsShiftKeyDown() then
                Valuate:GetScales()[scaleName] = nil
                -- Removing a scale IS a scoring-input change, which is what
                -- ResetTooltips says it is called for - it also drops the upgrade-arrow
                -- cache. Without it a tooltip already built for an item keeps that
                -- scale's cached border colour until you hover something else.
                if Valuate.ResetTooltips then Valuate:ResetTooltips() end
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
                    text = "Are you sure you want to delete the scale \"" ..
                        ((RowScale(btn) and RowScale(btn).DisplayName) or scaleName) .. "\"?",
                    acceptText = "Delete",
                    cancelText = "Cancel",
                    onAccept = function()
                        Valuate:GetScales()[scaleName] = nil
                        -- Same as the shift-delete path above.
                        if Valuate.ResetTooltips then Valuate:ResetTooltips() end
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
        
        -- Marks the scale treated as your CURRENT SPEC. That scale drives the
        -- character-sheet score, the upgrade prompt's baseline and the upgrade
        -- arrows - but it was only discoverable through a Settings dropdown named
        -- after the character window, so nothing here said which one it was.
        local primaryMark = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        primaryMark:SetPoint("RIGHT", deleteBtn, "LEFT", -4, 0)
        primaryMark:SetText("|cFFFFD100*|r")
        primaryMark:Hide()

        -- Scale name
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        nameLabel:SetPoint("LEFT", iconBtn, "RIGHT", 4, 0)
        nameLabel:SetPoint("RIGHT", primaryMark, "LEFT", -2, 0)
        nameLabel:SetJustifyH("LEFT")

        -- NOTE: the row's OnEnter/OnLeave are set further down (the hover highlight).
        -- Setting them here as well would silently replace that handler, so the
        -- tooltip is added there instead.
        
        -- Helper to update visual state based on visibility
        local function UpdateVisualState(visible)
            -- Read live: the colour and icon pickers write straight to the scale.
            local currentScale = RowScale(btn)
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
        
        -- Visibility checkbox click handler
        visCheckbox:SetScript("OnClick", function(self)
            local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
            local scale = RowScale(btn)
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
        
        -- Store references for visual updates. deleteBtn and primaryMark are exposed for
        -- the same reason as the rest: tools/scalelisttest.js drives this row the way a
        -- user does, and a control it cannot reach is a control nothing checks.
        btn.nameLabel = nameLabel
        btn.colorPreview = colorPreview
        btn.visCheckbox = visCheckbox
        btn.deleteBtn = deleteBtn
        btn.colorBtn = colorBtn
        btn.primaryMark = primaryMark
        btn.updateVisualState = UpdateVisualState
        btn.scaleColor = { r = 1, g = 1, b = 1 }

        -- Highlight on mouseover (only if visible), plus the row tooltip
        btn:SetScript("OnEnter", function(self)
            if ns.CurrentSelectedScale ~= self.scaleName then
                local scale = RowScale(self)
                local vis = scale and scale.Visible ~= false
                if vis then
                    -- Faded rather than snapped, matching the styled buttons
                    -- elsewhere. Border is left as-is so the selected row's accent
                    -- stays the only strong edge in the list.
                    TweenBackdrop(self, COLORS.buttonHover, COLORS.borderLight, MOTION.fast)
                end
            end

            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                local _, primaryName = Valuate:GetPrimaryScale()
                local scale = RowScale(self)
                GameTooltip:AddLine((scale and scale.DisplayName) or self.scaleName or "", 1, 1, 1)
                if primaryName == self.scaleName then
                    GameTooltip:AddLine("|cFFFFD100Current spec|r", 1, 1, 1)
                    GameTooltip:AddLine("Drives your character-sheet score, the upgrade prompt's baseline, and which items get a green upgrade arrow.", 0.8, 0.8, 0.8, true)
                else
                    GameTooltip:AddLine("Tick the box to include this scale in item tooltips.", 0.8, 0.8, 0.8, true)
                    GameTooltip:AddLine("Make it your current spec from Settings > Character Window Scale.", 0.7, 0.7, 0.7, true)
                end
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if ns.CurrentSelectedScale ~= self.scaleName then
                local scale = RowScale(self)
                local vis = scale and scale.Visible ~= false
                if vis then
                    TweenBackdrop(self, COLORS.buttonBg, COLORS.border, MOTION.fast)
                else
                    TweenBackdrop(self, COLORS.disabled, COLORS.border, MOTION.fast)
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
                -- Faded out over the same beat the new row fades in, so selection
                -- reads as a handoff between two rows rather than two separate pops.
                if prevVis then
                    TweenBackdrop(prevBtn, COLORS.buttonBg, COLORS.border, MOTION.fast)
                else
                    TweenBackdrop(prevBtn, COLORS.disabled, COLORS.borderDark, MOTION.fast)
                end
            end
            
            -- Select this one
            if not self.scaleName then return end
            ns.CurrentSelectedScale = self.scaleName
            -- Slightly quicker than the hover fade: a click should feel like it
            -- landed, not like it's still deciding.
            TweenBackdrop(self, COLORS.selected, COLORS.selectedBorder, MOTION.instant)

            -- Update editor with current scale data from ValuateScales
            ValuateUI_UpdateScaleEditor(self.scaleName, RowScale(self))
        end)

        -- Points this row at a scale. THE only place row identity changes.
        function btn.populate(name, scale)
            local wasEmpty = (btn.scaleName == nil)
            btn.scaleName = name

            local isVisible = scale.Visible ~= false
            visCheckbox:SetChecked(isVisible)
            ApplyIcon(scale.Icon)
            nameLabel:SetText(scale.DisplayName or name)

            local r, g, b = HexToRGB(scale.Color or "FFFFFF")
            btn.scaleColor.r, btn.scaleColor.g, btn.scaleColor.b = r, g, b
            UpdateVisualState(isVisible)

            local _, primaryName = Valuate:GetPrimaryScale()
            if primaryName == name then primaryMark:Show() else primaryMark:Hide() end

            -- Reset the hover/selected tint. A pooled row can be handed back mid-hover
            -- - delete a scale while the cursor is over the row below it and OnLeave
            -- never fires - which would otherwise leave the highlight stuck on.
            if ns.CurrentSelectedScale == name then
                btn:SetBackdropColor(unpack(COLORS.selected))
                btn:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
            else
                btn:SetBackdropBorderColor(unpack(COLORS.border))
            end

            btn:Show()

            -- Only a row that was not on screen a moment ago fades in. Rows that merely
            -- changed which scale they show do not: deleting the second of five scales
            -- shifts three rows up, and flashing all of them would say "three things
            -- happened" when one did. Same rule the upgrade arrows follow.
            if wasEmpty and ns.Anim then
                ns.Anim.revealIn(btn)
            end
        end

        -- Hands the row back to the pool. Clearing scaleName is what makes every
        -- handler above a no-op on a parked row, rather than one still wired to a scale
        -- that may since have been deleted.
        function btn.release()
            btn.scaleName = nil
            btn:Hide()
        end

        rowPool[index] = btn
        return btn
end

UpdateScaleList = function()
    if not ScaleListFrame then return end

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

    -- Rebuilt from scratch every time, never patched. A stale name left in here points
    -- ui/ScaleEditor.lua at a row now showing a different scale, and it selects rows by
    -- calling their OnClick directly.
    ns.ScaleListButtons = {}

    for i, scaleData in ipairs(scales) do
        local row = rowPool[i] or BuildScaleRow(i)
        row.populate(scaleData.name, scaleData.scale)
        ns.ScaleListButtons[scaleData.name] = row
        tinsert(ns.ScaleListButtons, row)
    end

    -- Park the surplus. These frames stay for the rest of the session either way; the
    -- point of the pool is that their number is bounded by the most scales you have
    -- ever had at once, instead of growing with every edit.
    for i = #scales + 1, #rowPool do
        rowPool[i].release()
    end


    -- Empty state. A default scale is created at load, so this only appears if you
    -- delete your last one mid-session - which previously left a blank panel with
    -- no indication of what to do next.
    --
    -- It named "New Blank Scale" and "+" until 0.66.0a. Both buttons had been renamed to
    -- "Blank" and "From Template" long before, so the one screen whose entire job is
    -- telling a stuck user what to click was pointing at two things that no longer
    -- existed. tools/scalelisttest.js now requires every button this text names to be a
    -- button that is actually on the panel.
    if not ScaleListFrame.emptyLabel then
        local empty = ScaleListFrame:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        empty:SetPoint("TOP", ScaleListFrame, "TOP", 0, -20)
        empty:SetWidth(160)
        empty:SetJustifyH("CENTER")
        empty:SetText("No scales yet.\n\nClick |cFF3FE0C8Make me a scale|r below and I will build one from the gear you are wearing.")
        empty:SetTextColor(unpack(COLORS.textDim))
        ScaleListFrame.emptyLabel = empty
    end
    if #scales == 0 then
        ScaleListFrame.emptyLabel:Show()
    else
        ScaleListFrame.emptyLabel:Hide()
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
    -- Three rows. Everything below anchors to this container's BOTTOM, so growing it
    -- shifts the list down on its own - no re-anchoring anywhere else.
    buttonContainer:SetHeight(BUTTON_HEIGHT * 3 + ELEMENT_SPACING * 2)

    -- The wizard goes FIRST and full width, in its own colour.
    --
    -- Same argument the comment below makes about Blank vs From Template, taken one step
    -- further: the person who needs help most cannot choose between 45 presets either,
    -- because that still assumes they know which one they are. The wizard is the only
    -- entry point here that answers that question for them, so it gets the top row and a
    -- slash command is not the only way to find it.
    local wizardButton = CreateStyledButton(buttonContainer, "Make me a scale", 200, BUTTON_HEIGHT)
    wizardButton:SetPoint("TOPLEFT", buttonContainer, "TOPLEFT", 0, 0)
    wizardButton.label:SetTextColor(ns.HexToRGB("3FE0C8"))
    wizardButton:SetScript("OnClick", function()
        if Valuate.ShowScaleWizard then Valuate:ShowScaleWizard() end
    end)
    -- HookScript: CreateStyledButton owns OnEnter/OnLeave for the hover fade, and
    -- replacing them kills the animation on this button alone.
    wizardButton:HookScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Make me a scale", 0.25, 0.88, 0.78)
            GameTooltip:AddLine("Reads the gear you are wearing, works out which build you " ..
                "most resemble, and creates an optimized scale from it.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Shows you what it would make first. Never overwrites a " ..
                "scale you already have.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    wizardButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Blank scale gets the SMALLER share, and the template button gets the words.
    --
    -- It was the other way round: "New Blank Scale" at 80% and the template picker as a
    -- 20%-wide "+". That put the emphasis exactly backwards for the person who needs it
    -- most. A new user cannot usefully fill in a blank scale - they do not yet know what
    -- their stat weights should be, which is the entire problem the addon solves - while
    -- the "+" hid 45 researched class/spec presets behind a symbol nobody hovers.
    local newButtonWidth = math.floor((200 - ELEMENT_SPACING) * 0.4)
    local newButton = CreateStyledButton(buttonContainer, "Blank", newButtonWidth, BUTTON_HEIGHT)
    newButton:SetPoint("TOPLEFT", wizardButton, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    newButton:SetScript("OnClick", function()
        ValuateUI_NewScale()
    end)
    
    -- Template button: now the wide one, and it says what it does.
    local templateButtonWidth = 200 - newButtonWidth - ELEMENT_SPACING
    local templateButton = CreateStyledButton(buttonContainer, "From Template", templateButtonWidth, BUTTON_HEIGHT)
    templateButton:SetPoint("TOPRIGHT", wizardButton, "BOTTOMRIGHT", 0, -ELEMENT_SPACING)
    templateButton:SetScript("OnClick", function()
        ValuateUI_ShowTemplatePicker()
    end)
    
    -- Scale Library (row 2, full width). Lives here rather than the editor header
    -- because it IS scale management, like the two buttons above it - and the header
    -- has no room left once the summary is accounted for.
    local libraryButton = CreateStyledButton(buttonContainer, "Scale Library", 200, BUTTON_HEIGHT)
    libraryButton:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    libraryButton:SetScript("OnClick", function()
        -- Read at click time: the library dialog is defined in ScaleEditor.lua,
        -- which loads after this file.
        if Valuate.ShowScaleLibrary then Valuate:ShowScaleLibrary() end
    end)
    libraryButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Scale Library", 1, 1, 1)
            GameTooltip:AddLine("Scales saved here are shared by ALL your characters.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Scales themselves are per-character, so without this a new character starts with none.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end
    end)
    libraryButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
