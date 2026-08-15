-- ui/UpgradePopup.lua
-- The "you found an upgrade" popup.
--
-- Deliberately NOT the shared confirm dialog. That one also asks "delete these 12
-- items?", where a celebratory look would be actively misleading - and it has to
-- stay plain, wide and readable. This one has one job and can be compact, specific
-- and pleased with itself: it names the item, shows its icon, and says how much
-- better it is.
--
-- Taint note: like every Valuate dialog this is our own frame. StaticPopup1..4 are
-- recycled by Blizzard, so showing one of ours through StaticPopup_Show poisons the
-- frame for later secure use (see ui/Dialog.lua). We never touch them.

local _, ns = ...

local COLORS = ns.COLORS
local MOTION = ns.MOTION
local BACKDROP_WINDOW = ns.BACKDROP_WINDOW
local FONT_H2, FONT_BODY, FONT_SMALL = ns.FONT_H2, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton = ns.CreateStyledButton
local Anim = ns.Anim
local ShowTooltipSafe = ns.ShowTooltipSafe

-- Wider and slightly taller than the first cut: item names are long ("Sentinel's
-- Medallion of Blistering Fury"), and at 300px they ran out of room.
local POPUP_W, POPUP_H = 356, 96
local ICON = 40

local popup

-- valuate-lint-ignore: acting-paths-wait-for-transit  one item, by link, on a button press
--
-- Same reasoning as the Best Equipment panel: EquipItemByName addresses the item by link,
-- not by bag coordinate, and the click is a person acting on the item the popup is showing
-- them. The popup also refuses in combat a few lines down, which is the refusal that matters
-- for a button.
local function EnsurePopup()
    if popup then return popup end

    local f = CreateFrame("Frame", "ValuateUpgradePopup", UIParent)
    -- Safe to Escape-close: it's a notification, so hiding it IS dismissing it.
    if ns.RegisterEscapeClose then ns.RegisterEscapeClose("ValuateUpgradePopup") end
    f:SetWidth(POPUP_W)
    f:SetHeight(POPUP_H)
    f:SetPoint("TOP", UIParent, "TOP", 0, -160)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(BACKDROP_WINDOW)
    f:SetBackdropColor(unpack(COLORS.windowBg))
    f:SetBackdropBorderColor(unpack(COLORS.borderLight))
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Accent bar, tinted to the scale's colour so the popup reads as "this spec".
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    accent:SetHeight(2)
    f.accent = accent

    -- Item icon, with a glow behind it that pulses while the popup is up.
    local glow = f:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\Cooldown\\star4")
    glow:SetBlendMode("ADD")
    glow:SetWidth(ICON * 2.2)
    glow:SetHeight(ICON * 2.2)
    f.glow = glow

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(ICON)
    icon:SetHeight(ICON)
    icon:SetPoint("LEFT", f, "LEFT", 12, 2)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.icon = icon
    glow:SetPoint("CENTER", icon, "CENTER", 0, 0)

    local iconBorder = f:CreateTexture(nil, "OVERLAY")
    iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    iconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    iconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    f.iconBorder = iconBorder

    -- Headline: the celebratory bit.
    local title = f:CreateFontString(nil, "OVERLAY", FONT_H2)
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetJustifyH("LEFT")
    f.title = title

    -- The item, on its own line so a long name has the full width to itself
    -- instead of sharing it with the score and spec.
    local itemLine = f:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    itemLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    itemLine:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    itemLine:SetJustifyH("LEFT")
    itemLine:SetWordWrap(false)
    f.itemLine = itemLine

    -- Gain and spec, below it.
    local subtitle = f:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    subtitle:SetPoint("TOPLEFT", itemLine, "BOTTOMLEFT", 0, -2)
    subtitle:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)
    subtitle:SetTextColor(unpack(COLORS.textDim))
    f.subtitle = subtitle

    -- Button spans the bottom rather than sitting beside the icon: the text column
    -- now needs the whole width above it.
    local equip = CreateStyledButton(f, "Equip", 104, 20)
    equip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    f.equipButton = equip

    -- Dismiss is a small corner ×, not a second full-width button: this is a
    -- notification, so declining should be quiet and take no visual weight.
    local close = CreateFrame("Button", nil, f)
    close:SetWidth(16)
    close:SetHeight(16)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    local closeLabel = close:CreateFontString(nil, "OVERLAY", FONT_BODY)
    closeLabel:SetPoint("CENTER", close, "CENTER", 0, 0)
    closeLabel:SetText("×")
    closeLabel:SetTextColor(0.6, 0.6, 0.6, 1)
    close:SetScript("OnEnter", function() closeLabel:SetTextColor(1, 1, 1, 1) end)
    close:SetScript("OnLeave", function() closeLabel:SetTextColor(0.6, 0.6, 0.6, 1) end)
    close:SetScript("OnClick", function() Valuate:HideUpgradePopup() end)
    f.closeButton = close

    -- Hovering the icon shows the actual item, so "is it really better?" is one
    -- mouse move away rather than a trip to the bags.
    -- Clicking the icon equips JUST that item. The Equip button takes the whole set,
    -- which is the wrong granularity when you only want the one thing the popup is
    -- actually telling you about - and that was the only option until now.
    local iconHover = CreateFrame("Button", nil, f)
    iconHover:SetAllPoints(icon)
    iconHover:RegisterForClicks("LeftButtonUp")
    iconHover:SetScript("OnEnter", function(self)
        if f.itemLink and ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:SetHyperlink(f.itemLink)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to equip just this item.", 0.6, 1, 0.6)
            GameTooltip:Show()
        end
        -- Slight lift on hover so the icon reads as clickable rather than decorative.
        if icon.SetTexCoord then icon:SetTexCoord(0.10, 0.90, 0.10, 0.90) end
    end)
    iconHover:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if icon.SetTexCoord then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    end)
    iconHover:SetScript("OnClick", function()
        if not f.itemLink or not f.itemSlotId then return end
        -- Same guard EquipBestSet uses: equipping is blocked in combat, and saying so
        -- beats a click that silently does nothing.
        if InCombatLockdown() then
            print("|cFFFF0000[Valuate]|r Can't change equipment in combat.")
            return
        end
        -- Tell the bind-confirm handler this equip is ours, so a BoE upgrade doesn't
        -- stall on the "this will bind to you" popup.
        if Valuate.MarkEquipIntent then Valuate:MarkEquipIntent(8) end
        EquipItemByName(f.itemLink, f.itemSlotId)
        Valuate:HideUpgradePopup()
    end)

    -- One driver for the glow pulse, running only while the popup is shown.
    f.pulse = 0
    -- valuate-lint-ignore: raw-onupdate-needs-reason  endless glow pulse the tween engine cannot express; popIn uses named props, no clash
    f:SetScript("OnUpdate", function(self, e)
        if ns.ReduceMotion and ns.ReduceMotion() then
            self.glow:SetAlpha(0.5)
            return
        end
        self.pulse = self.pulse + (e or 0)
        -- MOTION.pulse: this was 1.6 while the arrows and the minimap button ran at 1.3,
        -- with nothing written down to say why. One rhythm for everything that breathes.
        local period = (ns.MOTION and ns.MOTION.pulse) or 1.3
        self.glow:SetAlpha(0.35 + 0.3 * math.sin(self.pulse * (2 * math.pi / period)))
    end)

    popup = f
    return f
end

-- opts: count, bankCount, scale, scaleName, top {itemLink,itemName,itemTexture,
--       itemQuality,delta}, onEquip
function Valuate:ShowUpgradePopup(opts)
    opts = opts or {}
    local f = EnsurePopup()
    local scale = opts.scale
    local label = (scale and (scale.DisplayName or opts.scaleName)) or opts.scaleName or "your spec"

    local hex = (scale and scale.Color) or "FFD100"
    local r, g, b = ns.HexToRGB(hex)
    ns.SetSolidColor(f.accent, r, g, b, 1)
    f.glow:SetVertexColor(r, g, b, 1)

    local top = opts.top
    f.itemLink = top and top.itemLink or nil
    -- EquipItemByName needs the target slot for multi-slot gear (rings, trinkets,
    -- one-handers), or it picks a slot itself and can undo the assignment the scan
    -- worked out.
    f.itemSlotId = top and top.slotId or nil

    if top and top.itemTexture then
        f.icon:SetTexture(top.itemTexture)
        f.icon:Show()
        f.iconBorder:Show()
        f.glow:Show()
        if top.itemQuality and top.itemQuality > 0 then
            local qr, qg, qb = GetItemQualityColor(top.itemQuality)
            f.iconBorder:SetVertexColor(qr, qg, qb, 1)
        else
            f.iconBorder:SetVertexColor(0.6, 0.6, 0.6, 1)
        end
    else
        f.icon:Hide()
        f.iconBorder:Hide()
        f.glow:Hide()
    end

    local count = opts.count or 1
    f.title:SetText(count > 1
        and string.format("|cFF%s%d upgrades!|r", hex, count)
        or string.format("|cFF%sUpgrade found!|r", hex))

    -- Name the item and the gain; that is what makes this feel like a find rather
    -- than a counter ticking over.
    local decimals = Valuate:GetOptions().decimalPlaces or 1

    if top then
        -- Prefer the plain name over the item link. A link carries its own colour
        -- and |h markers, so it can't be safely shortened and it ignores any colour
        -- we set. GetItemInfo's FIRST return is the name (the second is the link).
        local name = top.itemName
        if top.itemLink then
            local plain = GetItemInfo(top.itemLink)
            if plain then name = plain end
        end
        name = name or "an item"

        local qr, qg, qb = 1, 1, 1
        if top.itemQuality and top.itemQuality > 0 then
            qr, qg, qb = GetItemQualityColor(top.itemQuality)
        end
        f.itemLine:SetTextColor(qr, qg, qb, 1)
        f.itemLine:SetText(name)

        -- Trim only if it genuinely doesn't fit. Safe now that this is a plain
        -- string: doing it to a link would corrupt the escape sequence.
        local avail = f.itemLine:GetWidth() or 0
        if avail > 0 and (f.itemLine:GetStringWidth() or 0) > avail then
            local trimmed = name
            while #trimmed > 4 and (f.itemLine:GetStringWidth() or 0) > avail do
                trimmed = trimmed:sub(1, #trimmed - 2)
                f.itemLine:SetText(trimmed .. "...")
            end
        end
    else
        f.itemLine:SetTextColor(unpack(COLORS.textBody))
        f.itemLine:SetText("Waiting in your bags")
    end

    local sub = string.format("|cFF00FF00+%." .. decimals .. "f|r  for %s",
        (top and top.delta) or 0, label)
    if (opts.bankCount or 0) > 0 then
        sub = sub .. string.format("   |cFFFF8800+%d in bank|r", opts.bankCount)
    end
    f.subtitle:SetText(sub)

    f.equipButton.label:SetText(count > 1 and "Equip All" or "Equip")
    f.equipButton:SetScript("OnClick", function()
        -- Checked BEFORE hiding, and that is the whole point of the guard being here as
        -- well as inside EquipBestSet.
        --
        -- EquipBestSet does refuse in combat and prints exactly this line, so the message
        -- was never missing. What was missing is the popup: it dismissed itself first, so a
        -- click that could not possibly work took the upgrade off your screen and left you
        -- to remember what it was. The icon beside this button has always checked first and
        -- stayed open - the more prominent control had the worse behaviour.
        if InCombatLockdown() then
            print("|cFFFF0000[Valuate]|r Can't change equipment in combat.")
            return
        end
        Valuate:HideUpgradePopup()
        if opts.onEquip then opts.onEquip() end
    end)

    -- Shared entrance, so this arrives exactly like the pickers and dialogs rather
    -- than carrying its own timings. Anim.popIn handles reduceMotion itself.
    f:Show()
    Anim.popIn(f, 0.9, MOTION.slow)
    return f
end

function Valuate:HideUpgradePopup()
    if popup then
        popup:Hide()
        popup:SetScale(1)
    end
end
