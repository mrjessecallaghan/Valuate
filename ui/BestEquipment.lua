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
local MOTION = ns.MOTION
local BACKDROP_WINDOW, BACKDROP_PANEL, BACKDROP_BUTTON, BACKDROP_INPUT =
    ns.BACKDROP_WINDOW, ns.BACKDROP_PANEL, ns.BACKDROP_BUTTON, ns.BACKDROP_INPUT
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton, ShowTooltipSafe = ns.CreateStyledButton, ns.ShowTooltipSafe
local HexToRGB = ns.HexToRGB
local Anim = ns.Anim
-- Used by the weapon-set activation flash; missed when this panel was extracted, so
-- clicking Equip All would have errored on a nil call.
local ValuateTween, EaseOutQuad = ns.ValuateTween, ns.EaseOutQuad


-- ========================================
-- Best Equipment Panel
-- ========================================

local BestEquipmentScrollFrame = nil
local BestEquipmentContentFrame = nil
-- (BestEquipmentScaleFrames removed: the panel now uses a persistent column pool)

-- What a slot's best item can be compared AGAINST. Three states, and they are not
-- interchangeable:
--
--   "new"       nothing equipped there. The best item is a pure gain and the slot is bare.
--   "unusable"  something equipped, but this scale bans one of its stats, so
--               CalculateItemScore returned nil. There is genuinely no number to compare.
--   "delta"     a real equipped score - INCLUDING zero and negative ones, both of which a
--               scale can legitimately produce - so show the difference.
--
-- Named and file-local for two reasons. It was written inline as
-- `if score > 0 ... elseif score == 0 or not score then "--" else "New" end`, where the
-- "New" arm was unreachable: a bare slot has nil stats, so `not score` caught it one
-- branch earlier and every empty slot rendered as a grey "--" meaning "no comparison" -
-- on exactly the slots where the comparison is easiest and the gain is largest.
--
-- And the row and its tooltip each carried their own copy of that branch, which is how
-- two answers to one question drift apart. One decision, two readers, one gate
-- (tools/bestequiptest.js).
local function SlotCompareState(equippedStats, equippedScore)
    if not equippedStats then return "new" end
    if not equippedScore then return "unusable" end
    return "delta"
end

-- ========================================
-- "What did that scan actually change?"
-- ========================================
-- A scan used to rewrite this panel in silence: rows changed and nothing said which.
-- With seventeen slots per scale across several columns, spotting the one that moved
-- meant remembering what was there before.
--
-- Keyed on scale+slot rather than on the row widget. Rows are pooled by column INDEX
-- and which scale a column shows changes as scales are toggled, so a widget-keyed
-- memory would end up comparing one scale's best item against another's.
--
-- The value is the item LINK, not the item id: a differently-enchanted version of the
-- same base item genuinely is a different best-in-slot, and the link distinguishes
-- them while the id does not.
local lastBestLink = {}

-- Deliberately NOT one of the MOTION tokens. Those describe transitions - something
-- moving from A to B - and this is a notification: it exists to be noticed after a
-- scan you were probably not watching. A second reads as "look here"; a quarter of
-- one reads as a flicker you are not sure you saw.
local CHANGE_FLASH_TIME = 1.0
local CHANGE_FLASH_PEAK = 0.30

local function FlashRowChanged(r)
    if not r or not r.changeFlash or not r.slotRow then return end
    local tex = r.changeFlash
    tex:SetAlpha(CHANGE_FLASH_PEAK)
    -- Owned, so a row that changes twice in quick succession restarts cleanly instead
    -- of running two fades that fight over the same alpha.
    --
    -- Under Reduce Motion the engine jumps to the final state, which for this tween is
    -- alpha 0 - so the row simply never lights up. That is the honest instant version:
    -- there is no "final frame" of a notification worth showing.
    Anim.owned(r.slotRow, "changeflash", {
        duration = CHANGE_FLASH_TIME,
        ease = "outCubic",
        onUpdate = function(e) tex:SetAlpha(CHANGE_FLASH_PEAK * (1 - e)) end,
        onDone = function() tex:SetAlpha(0) end,
    })
end

-- Records what this slot now holds and reports whether that is a CHANGE.
--
-- A nil previous value means this scale+slot has never been drawn, which is not a
-- change - it is the first sight of it. Without that distinction the first visit to
-- the tab would light up every row in every column and mean nothing at all.
-- Separator that cannot occur in a scale name (the UI validates them as text) and so
-- cannot make "Fire" + slot 12 collide with "Fire1" + slot 2.
local KEY_SEP = "\30"

local function NoteBestItemAndDetectChange(scaleName, slotId, bestItem)
    local key = scaleName .. KEY_SEP .. slotId
    local newLink = (bestItem and bestItem.itemLink) or ""
    local prevLink = lastBestLink[key]
    lastBestLink[key] = newLink
    return prevLink ~= nil and prevLink ~= newLink
end

-- valuate-lint-ignore: acting-paths-wait-for-transit  one item, by link, on a right-click
--
-- The rule is aimed at paths that act on a (bag, slot) pair, or on a cached scan, without
-- anybody watching. Neither applies here: the equip inside is EquipItemByName(link, slotId),
-- which finds the item by name wherever it has ended up rather than by coordinate, and it
-- runs because somebody right-clicked that specific row. A person doing that mid-swap means
-- it, and unlike an automation they have no next bag update to wait for.
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
    -- What a weapon set is NOT describing, when you have pinned a weapon slot.
--
-- A lock says "keep what is here". The scan honours that for the slot itself, but the weapon
-- SETS are recomputed from scratch every scan - they are a comparison between configurations,
-- and a pinned slot is not part of any comparison. So the Main Hand row can show your locked
-- axe while the set panel underneath claims this configuration's main hand is something else.
--
-- Both are true and they contradict each other on screen, which is the worst way to be right.
-- Rather than fold locks into the set arithmetic - where a pinned 2H would have to invalidate
-- the dual-wield set entirely, and "best set" would stop meaning anything - the sets keep
-- saying what they mean and the tooltip says which half of it you have overridden.
--
-- Returns a sentence, or nil when neither weapon slot is locked.
function ns.WeaponSetLockNote(be)
    if type(be) ~= "table" or type(be.locks) ~= "table" then return nil end

    local mh = be.locks[16] and (be[16] and be[16].itemName or "a weapon")
    local oh = be.locks[17] and (be[17] and be[17].itemName or "something")

    if mh and oh then
        return string.format("Both weapon slots are locked (%s, %s), so this set describes " ..
            "neither.", mh, oh)
    elseif mh then
        return string.format("Main Hand is locked to %s, so this set's main hand is not what " ..
            "you are tracking.", mh)
    elseif oh then
        return string.format("Off Hand is locked to %s, so this set's off hand is not what " ..
            "you are tracking.", oh)
    end
    return nil
end

local EquipmentSlots = ns.EQUIP_SLOTS
    
    -- Scan button at top
    local scanButton = CreateFrame("Button", nil, parent)
    scanButton:SetHeight(BUTTON_HEIGHT)
    scanButton:SetWidth(200)
    scanButton:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING, -PADDING)
    scanButton:SetBackdrop(BACKDROP_BUTTON)
    scanButton:SetBackdropColor(unpack(COLORS.buttonBg))
    -- The odd one out among its own siblings.
    --
    -- Clear Items, Equip All and Save Set each carry this texture, with a comment saying
    -- why: the HIGHLIGHT layer is drawn only while the mouse is over the frame and needs no
    -- script, which is what lets a button keep hover feedback when its OnEnter is spoken
    -- for by a tooltip. Scan's OnEnter is a tooltip too. It just never got the texture.
    local scanHL = scanButton:CreateTexture(nil, "HIGHLIGHT")
    scanHL:SetAllPoints(scanButton)
    ns.SetSolidColor(scanHL, 1, 1, 1, 0.10)
    scanButton:SetBackdropBorderColor(unpack(COLORS.border))
    
    local scanLabel = scanButton:CreateFontString(nil, "OVERLAY", FONT_BODY)
    scanLabel:SetPoint("CENTER", scanButton, "CENTER", 0, 0)
    scanLabel:SetText("Scan Best Equipment")
    scanLabel:SetTextColor(unpack(COLORS.textBody))
    
    -- How old the data on screen is.
    --
    -- ValuateBestEquipment is SavedVariablesPerCharacter, so it survives logout: open
    -- this tab before anything triggers a scan and you are looking at LAST SESSION's
    -- best-in-slot, presented exactly like fresh results. Loot, vendor or level in
    -- between and it can be substantially wrong, with nothing saying so.
    --
    -- The heartbeat makes the distinction for free, and by accident of implementation:
    -- it is keyed on GetTime(), which resets at login, so "no heartbeat" means
    -- precisely "no scan since you logged in" - which is exactly the case worth
    -- flagging.
    local scanAgeText = parent:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    scanAgeText:SetPoint("LEFT", scanButton, "RIGHT", ELEMENT_SPACING, 0)
    scanAgeText:SetJustifyH("LEFT")

    local function UpdateScanAge()
        local ago = Valuate.GetAutomationHeartbeat and Valuate:GetAutomationHeartbeat("scan")
        if ago then
            local when = (SecondsToTime and ago >= 1) and SecondsToTime(ago) or "moments"
            scanAgeText:SetText("|cFF888888Scanned " .. when .. " ago|r")
            return
        end

        -- No heartbeat this session. THREE states, and this had two branches.
        --
        -- "Not scanned this session - these are last session's results" was printed for the
        -- absence of a heartbeat, full stop. A character who has never scanned at all has no
        -- heartbeat either, and no last session's results - so the panel told somebody
        -- looking at an empty grid that what they were seeing came from last time.
        --
        -- Same shape as the to-do list telling an unscanned character its gear was all up to
        -- date: a missing measurement read as a measurement of nothing.
        local stored = Valuate.GetBestEquipment and Valuate:GetBestEquipment()
        local haveStored = false
        if stored then for _ in pairs(stored) do haveStored = true break end end
        if haveStored then
            scanAgeText:SetText("|cFFFF8800Not scanned this session|r - these are last session's results")
        else
            scanAgeText:SetText("|cFFFF8800Never scanned|r - press Scan and there will be something here")
        end
    end
    parent.UpdateScanAge = UpdateScanAge
    UpdateScanAge()

    -- Keep it honest while you sit here.
    --
    -- Without this the label was its own bug: it is here to tell you the data might be
    -- old, and it would itself freeze at "Scanned moments ago" for as long as the tab
    -- stayed open. Leave it twenty minutes and it still claims the scan just happened -
    -- a staleness warning going stale is worse than none, because it is the thing you
    -- were relying on to notice.
    --
    -- The tick itself runs for the session; only the UPDATE is skipped while hidden.
    -- Stopping and restarting it would need an OnShow hook for one no-op comparison
    -- every twenty seconds, which is not a trade worth making - but it is worth saying
    -- accurately rather than claiming it only runs when visible.
    --
    -- ns.ValuateAfter is the shared timer, reachable from ui/ since v0.37.0a. Before
    -- that this file would have had to roll its own OnUpdate frame, which is precisely
    -- what that release was about.
    local function TickScanAge()
        if parent:IsShown() then UpdateScanAge() end
        if ns.ValuateAfter then ns.ValuateAfter(20, TickScanAge) end
    end
    if ns.ValuateAfter then ns.ValuateAfter(20, TickScanAge) end

    scanButton:SetScript("OnClick", function()
        Valuate:ScanBestEquipment()
        -- Refresh display after scan
        if Valuate.RefreshBestEquipmentDisplay then
            Valuate:RefreshBestEquipmentDisplay()
        end
        UpdateScanAge()
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
    ns.SetSolidColor(horizScrollbarBg, 0.1, 0.1, 0.1, 0.5)
    
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
        ns.SetSolidColor(cardBg, 0.10, 0.11, 0.14, 0.55)
        local leftEdge = scaleFrame:CreateTexture(nil, "BORDER")
        ns.SetSolidColor(leftEdge, unpack(COLORS.border))
        leftEdge:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 0, 0)
        leftEdge:SetPoint("BOTTOMLEFT", scaleFrame, "BOTTOMLEFT", 0, 0)
        leftEdge:SetWidth(1)
        local rightEdge = scaleFrame:CreateTexture(nil, "BORDER")
        ns.SetSolidColor(rightEdge, unpack(COLORS.border))
        rightEdge:SetPoint("TOPRIGHT", scaleFrame, "TOPRIGHT", 0, 0)
        rightEdge:SetPoint("BOTTOMRIGHT", scaleFrame, "BOTTOMRIGHT", 0, 0)
        rightEdge:SetWidth(1)
        local bottomEdge = scaleFrame:CreateTexture(nil, "BORDER")
        ns.SetSolidColor(bottomEdge, unpack(COLORS.border))
        bottomEdge:SetPoint("BOTTOMLEFT", scaleFrame, "BOTTOMLEFT", 0, 0)
        bottomEdge:SetPoint("BOTTOMRIGHT", scaleFrame, "BOTTOMRIGHT", 0, 0)
        bottomEdge:SetHeight(1)

        -- Header
        local headerContainer = CreateFrame("Frame", nil, scaleFrame)
        headerContainer:SetPoint("TOPLEFT", scaleFrame, "TOPLEFT", 0, 0)
        headerContainer:SetSize(BE_SCALE_WIDTH, BE_HEADER_HEIGHT)

        local headerBg = headerContainer:CreateTexture(nil, "BACKGROUND")
        headerBg:SetAllPoints(headerContainer)
        ns.SetSolidColor(headerBg, 0.05, 0.05, 0.05, 0.5)
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
        ns.SetSolidColor(headerDivider, unpack(COLORS.border))

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
        ns.SetSolidColor(abHL, 1, 0.82, 0.1, 0.10)
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
        ns.SetSolidColor(clearHL, 1, 1, 1, 0.10)

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
        ns.SetSolidColor(equipAllHL, 1, 1, 1, 0.10)

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
        ns.SetSolidColor(saveSetHL, 1, 1, 1, 0.10)

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

            -- Brief tint behind the whole row, used to mark a slot whose best item
            -- actually changed on the last scan. BACKGROUND layer on slotRow, so it
            -- sits behind the icon and text rather than washing them out. Starts
            -- invisible: most refreshes change nothing and must look like nothing.
            local changeFlash = slotRow:CreateTexture(nil, "BACKGROUND")
            changeFlash:SetAllPoints(slotRow)
            changeFlash:SetTexture("Interface\\Buttons\\WHITE8X8")
            changeFlash:SetVertexColor(0.35, 0.85, 0.45)
            changeFlash:SetAlpha(0)
            r.changeFlash = changeFlash

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

            -- Corner marker for gear that lives in the bank. Such an item can still be
            -- best-in-slot, but Equip All cannot reach it, so it must be visibly
            -- different from something sitting in your bags. Created AFTER
            -- qualityBorder so it draws above it (same layer = creation order).
            local bankBadge = slotFrame:CreateTexture(nil, "OVERLAY")
            bankBadge:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
            bankBadge:SetWidth(11)
            bankBadge:SetHeight(11)
            bankBadge:SetPoint("BOTTOMLEFT", slotFrame, "BOTTOMLEFT", 1, 1)
            bankBadge:Hide()
            r.bankBadge = bankBadge

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
            ns.SetSolidColor(hl, 1, 1, 1, 0.08)
            -- Flash overlay: pulses to confirm "this set is now active" after Equip All.
            local flash = btn:CreateTexture(nil, "OVERLAY")
            flash:SetAllPoints(btn)
            ns.SetSolidColor(flash, unpack(COLORS.textAccent))
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

        -- Hoisted: the row loop below asks this once per slot per column otherwise, and
        -- it cannot change midway through a single rebuild.
        local panelVisible = parent:IsShown()

        -- Refreshed on every redraw, not just when the Scan button is pressed: a
        -- background scan updates the rows without going near that button, and an age
        -- label that only tracked manual scans would be its own kind of lie.
        if parent.UpdateScanAge then parent.UpdateScanAge() end

        local activeScales = Valuate:GetActiveScales()
        local scales = Valuate:GetScales()
        local bestEquipment = Valuate:GetBestEquipment()

        -- Hide all pooled columns up front; needed ones are re-shown below.
        for _, col in ipairs(columnBundles) do col.frame:Hide() end

        if #activeScales == 0 then
            if not noScalesTextFrame then
                noScalesTextFrame = contentFrame:CreateFontString(nil, "OVERLAY", FONT_BODY)
                noScalesTextFrame:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
                noScalesTextFrame:SetWidth(360)
                noScalesTextFrame:SetJustifyH("CENTER")
                noScalesTextFrame:SetTextColor(unpack(COLORS.textDim))
            end

            -- Two different situations, and this used to give them one message.
            --
            -- "No active scales. Activate scales in the Scales tab" is correct when you have
            -- scales and none are switched on. It is WRONG for someone who has never made
            -- one - which is everybody, once - because it sends them to look for a switch
            -- that is not there, and the thing they actually need is a button on the same
            -- screen it points at.
            --
            -- The first screen a new user reaches should not describe a state they are not
            -- in. Wording matched to the scale list's own empty state, so the two screens
            -- agree about what to do next rather than each inventing a phrasing.
            local haveAny = false
            for _ in pairs(scales) do haveAny = true break end

            if haveAny then
                noScalesTextFrame:SetText(
                    "No |cFFFFFFFFactive|r scales.\n\n" ..
                    "You have scales, but none are switched on. Tick one in the " ..
                    "|cFF3FE0C8Scales|r tab and its best-in-slot appears here.")
            else
                noScalesTextFrame:SetText(
                    "No scales yet.\n\n" ..
                    "Open the |cFF3FE0C8Scales|r tab and click |cFF3FE0C8Make me a scale|r - " ..
                    "it builds one from the gear you are already wearing.")
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
            Anim.setHeight(ns.ValuateUIFrame,
                math.max(MIN_WINDOW_HEIGHT, math.min(MAX_WINDOW_HEIGHT, neededHeight)), true)
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
                if col.accentBar then ns.SetSolidColor(col.accentBar, cr, cg, cb, 0.95) end
                if col.headerBg then ns.SetSolidColor(col.headerBg, cr, cg, cb, 0.12) end
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

                        -- What it will actually do, before you commit to it. A button that
                        -- changes several slots at once should not need to be pressed to
                        -- find out how many.
                        local pending = col.pendingEquip or {}
                        if #pending == 0 then
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine("|cFF888888Nothing to change - you are already wearing this scale's best.|r",
                                0.8, 0.8, 0.8, true)
                        else
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(string.format("|cFF00FF00Would change %d slot%s:|r",
                                #pending, #pending == 1 and "" or "s"), 1, 1, 1)
                            -- Listed, not just counted, up to a point: "6 slots" tells you
                            -- the size of the change and not whether it is the one you
                            -- meant. Past eight the list is longer than the tooltip is
                            -- useful, so it says how many more.
                            local shown = math.min(#pending, 8)
                            for i = 1, shown do
                                GameTooltip:AddLine("   " .. pending[i], 0.7, 0.9, 0.7)
                            end
                            if #pending > shown then
                                GameTooltip:AddLine(string.format("   |cFF888888...and %d more|r",
                                    #pending - shown), 0.7, 0.7, 0.7)
                            end
                        end

                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Skips locked slots, bank items and anything already worn.", 0.7, 0.7, 0.7, true)
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
                local bankUpgradeTotal = 0
                local emptyFillable = 0

                -- Which slots Equip All would actually change.
                --
                -- Collected HERE rather than recomputed when the button is hovered: this
                -- loop already reads every slot's best and what is worn, and doing it again
                -- on hover would cost what a scan costs, on a mouse move.
                --
                -- The button is not gated behind a confirmation - equipping is reversible,
                -- the old gear is still in your bags - so the useful thing is not friction
                -- but knowing what is about to happen before you commit to it.
                col.pendingEquip = {}

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
                    -- Cleared unconditionally here so a pooled row can never keep a
                    -- stale bank badge; only the current-best branch turns it back on.
                    r.bankBadge:Hide()

                    local bestItem = bestEquipment[scaleName] and bestEquipment[scaleName][slotId]

                    -- Only while this panel is actually on screen. The enclosing guard
                    -- checks the WINDOW is shown, which is not the same thing: a scan
                    -- while you are reading the Settings tab would otherwise record the
                    -- new items, consume the change, and leave nothing to see when you
                    -- switch over. Skipping the record entirely means the comparison is
                    -- against the last state you actually looked at, which is the
                    -- question being asked - "what changed since I last saw this?"
                    if panelVisible then
                        if NoteBestItemAndDetectChange(scaleName, slotId, bestItem) then
                            FlashRowChanged(r)
                        else
                            -- Clear through the engine, not by writing alpha directly: a
                            -- fade may still be running on this pooled row from a previous
                            -- draw, and it would overwrite a bare SetAlpha on its next frame.
                            Anim.cancelProp(r.slotRow, "changeflash")
                            r.changeFlash:SetAlpha(0)
                        end
                    end
                    local equippedStats = GetEquippedStatsForSlot(slotId)
                    -- What you are wearing, so its hit is already in your total.
                    local equippedScore = equippedStats and Valuate:CalculateItemScore(equippedStats, scale, { worn = true }) or nil

                    -- Summary totals: best-achievable per slot is max(best, equipped);
                    -- upgrades are the positive best-over-equipped deltas.
                    -- Slots wearing NOTHING that you own something for.
                    --
                    -- Deliberately not "empty slots". Off Hand is empty by design if you
                    -- run a two-hander, and plenty of builds never fill Ranged - counting
                    -- those would nag about slots that are correct, which is the fastest
                    -- way to teach someone to ignore the line. If Valuate found no item
                    -- for the slot there is nothing to say; if it found one and you are
                    -- wearing nothing, that is worth a sentence.
                    --
                    -- Bank items are excluded for the same reason they are split out of
                    -- the upgrade total: Equip All cannot reach them.
                    if not equippedStats and bestItem and bestItem.source ~= "bank" then
                        emptyFillable = emptyFillable + 1
                    end

                    local eqSlotScore = equippedScore or 0
                    local bestSlotScore = (bestItem and bestItem.score) or 0
                    equippedTotal = equippedTotal + eqSlotScore
                    bestTotal = bestTotal + math.max(bestSlotScore, eqSlotScore)
                    if bestSlotScore > eqSlotScore then
                        -- Split by reachability. Banked gear is a real upgrade but is
                        -- not "in bags", and Equip All can't take it - counting it in
                        -- the same figure made this line say something untrue.
                        if bestItem and bestItem.source == "bank" then
                            bankUpgradeTotal = bankUpgradeTotal + (bestSlotScore - eqSlotScore)
                        else
                            upgradeTotal = upgradeTotal + (bestSlotScore - eqSlotScore)
                        end
                    end

                    -- Lock state + closures (rebound each update for this scaleName/slotId)
                    local isLocked = bestEquipment[scaleName] and bestEquipment[scaleName].locks and bestEquipment[scaleName].locks[slotId]

                    -- Would Equip All touch this slot? Mirrors what EquipBestSet skips:
                    -- locked slots, bank items it cannot reach, and anything already worn.
                    --
                    -- Compared by item ID, not by link. Two links for the same item differ
                    -- by enchant and suffix, so a link comparison would report every slot as
                    -- changing and the count would be a lie in the safe direction - which is
                    -- still a lie, and the sort that reads as the feature not working.
                    if bestItem and bestItem.itemLink and bestItem.source ~= "bank" and not isLocked then
                        local wornLink = GetInventoryItemLink and GetInventoryItemLink("player", slotId)
                        local bestId = string.match(bestItem.itemLink, "|Hitem:(%d+)")
                        local wornId = wornLink and string.match(wornLink, "|Hitem:(%d+)")
                        if bestId ~= wornId then
                            col.pendingEquip[#col.pendingEquip + 1] = slotInfo.name or ("slot " .. slotId)
                        end
                    end

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

                        if bestItem.source == "bank" then
                            r.bankBadge:Show()
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

                        -- The old inline branch also disagreed with the summary directly
                        -- above it, which counts an empty slot's whole score as an
                        -- upgrade: the total said "+120 in bags" and no row admitted to
                        -- being any of it.
                        local compareState = SlotCompareState(equippedStats, equippedScore)
                        if compareState == "new" then
                            comparisonText:SetText("|cFF00FF00New|r")
                        elseif compareState == "unusable" then
                            comparisonText:SetText("|cFF888888--|r")
                        else
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
                                if bestItem.source == "bank" then
                                    GameTooltip:AddLine(" ")
                                    GameTooltip:AddLine("|cFFFF8800In your bank|r", 1, 1, 1)
                                    GameTooltip:AddLine("Counted as best-in-slot, but Equip All can't reach it - withdraw it first.", 0.8, 0.8, 0.8, true)
                                end
                                GameTooltip:AddLine(" ")
                                GameTooltip:AddLine("Score for |cFF" .. color .. displayName .. "|r: |cFF" .. color .. string.format(formatStr, scoreValue) .. "|r", 1, 1, 1)
                                -- Same decision as the row, through the same function. The
                                -- tooltip used to go silent for anything but a positive
                                -- equipped score, so an empty slot said nothing at all
                                -- about why - the one case where a person is most likely
                                -- to be asking.
                                local tipState = SlotCompareState(equippedStats, equippedScore)
                                if tipState == "new" then
                                    GameTooltip:AddLine("|cFF00FF00Nothing equipped in this slot|r", 0.8, 0.8, 0.8)
                                elseif tipState == "unusable" then
                                    GameTooltip:AddLine("|cFF888888What you are wearing has a stat this scale bans, so there is no score to compare.|r", 0.8, 0.8, 0.8, true)
                                else
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

                                -- The future item for this slot, which is otherwise INVISIBLE.
                                --
                                -- The row can only draw one item, and it draws the future one
                                -- only when there is no equippable best at all. While
                                -- levelling that is the rare case: you have something in
                                -- every slot, so anything waiting sits behind it and the
                                -- panel you would plan gear from does not mention it.
                                local futureItem = bestEquipment[scaleName]
                                    and bestEquipment[scaleName].future
                                    and bestEquipment[scaleName].future[slotId]
                                if futureItem and futureItem.itemLink then
                                    GameTooltip:AddLine(" ")
                                    if futureItem.reqLevel and futureItem.reqLevel > 0 then
                                        GameTooltip:AddLine(string.format(
                                            "|cFF66CCFFWaiting at level %d:|r %s",
                                            futureItem.reqLevel,
                                            futureItem.itemName or "an item"), 1, 1, 1, true)
                                    else
                                        -- No usable level means something else is in the way,
                                        -- so the line does not invent one - same rule the
                                        -- item tooltip's future line follows.
                                        GameTooltip:AddLine(string.format(
                                            "|cFF66CCFFWaiting for this slot:|r %s",
                                            futureItem.itemName or "an item"), 1, 1, 1, true)
                                    end
                                    if futureItem.score then
                                        GameTooltip:AddLine(string.format("It would score " .. formatStr ..
                                            " here.", futureItem.score), 0.7, 0.7, 0.7)
                                    end
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
                                    -- Said HERE, on the line that claims a main and an off
                                    -- hand, because that claim is the one a lock contradicts.
                                    -- The slot row above shows your pinned weapon; this panel
                                    -- shows what the set would be. Both true, contradicting
                                    -- each other on screen, which is the worst way to be right.
                                    local lockNote = ns.WeaponSetLockNote and ns.WeaponSetLockNote(be)
                                    if lockNote then
                                        GameTooltip:AddLine(lockNote, 1, 0.82, 0.2, true)
                                    end
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
                local bankPart = ""
                if bankUpgradeTotal > 0.01 then
                    bankPart = "  |cFFFF8800+" .. string.format(formatStr, bankUpgradeTotal) .. " in bank|r"
                end
                -- An empty slot you can fill is the single most actionable thing this
                -- panel knows, and it was previously visible only as a grey "--" on the
                -- row. Levelling characters run around with a bare neck or one ring for
                -- hours; "+120 in bags" does not tell you that any of it is free.
                local emptyPart = ""
                if emptyFillable > 0 then
                    emptyPart = "  |cFF00FF00" .. emptyFillable ..
                        (emptyFillable == 1 and " empty slot" or " empty slots") .. " you can fill|r"
                end

                -- emptyPart is appended to EVERY branch. It is a statement about your
                -- slots, not about the score, so it stays true when the item filling the
                -- slot happens to be worth nothing to this scale - and a line that
                -- appears in two states out of three is a line nobody can rely on.
                if upgradeTotal > 0.01 then
                    col.upgradesText:SetText("|cFF00FF00Upgrades in bags: +"
                        .. string.format(formatStr, upgradeTotal) .. "|r" .. bankPart .. emptyPart)
                elseif bankPart ~= "" then
                    -- Don't claim there is nothing to gain when the gain is simply
                    -- sitting in the bank.
                    col.upgradesText:SetText("|cFF888888No upgrades in bags|r" .. bankPart .. emptyPart)
                else
                    col.upgradesText:SetText("|cFF888888No upgrades in bags|r" .. emptyPart)
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
        local colGap = Anim.staggerFor(#columnBundles)
        for i, col in ipairs(columnBundles) do
            if col.frame and col.frame:IsShown() then
                local colDelay = (i - 1) * colGap
                Anim.revealIn(col.frame, colDelay, MOTION.slow)
                local rowGap = Anim.staggerFor(#col.rows)

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
                        -- OWNED by the row, not a bare tween.
                        --
                        -- Rows are pooled, so `label` is the same FontString across
                        -- refreshes, and each count-up captures the score it started
                        -- with. Reveal, then switch tabs and come back - or let a scan
                        -- land mid-reveal - and the previous run's tweens were still
                        -- going, writing the OLD score over the new one and finishing on
                        -- it. The row would then display the previous scan's number
                        -- until something else redrew it.
                        --
                        -- The delays make it worse: an old tween can outlive a new one,
                        -- so it is not even reliably the newest value that wins.
                        --
                        -- `r` is our own row table, so nothing is written onto a
                        -- Blizzard frame (see ui/UpgradeArrows.lua, same reasoning).
                        Anim.owned(r, "scorecount", {
                            duration = MOTION.count, ease = "outCubic",
                            delay = colDelay + (rowIndex - 1) * rowGap,
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
