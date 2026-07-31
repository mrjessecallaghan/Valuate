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
local BACKDROP_WINDOW = ns.BACKDROP_WINDOW
local FONT_H2, FONT_BODY, FONT_SMALL = ns.FONT_H2, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton = ns.CreateStyledButton
local Anim = ns.Anim
local ShowTooltipSafe = ns.ShowTooltipSafe

local POPUP_W, POPUP_H = 300, 84
local ICON = 40

local popup

local function EnsurePopup()
    if popup then return popup end

    local f = CreateFrame("Frame", "ValuateUpgradePopup", UIParent)
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

    -- Which item, and for which spec.
    local subtitle = f:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(false)
    subtitle:SetTextColor(unpack(COLORS.textDim))
    f.subtitle = subtitle

    local equip = CreateStyledButton(f, "Equip", 88, 20)
    equip:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, -2)
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
    local iconHover = CreateFrame("Frame", nil, f)
    iconHover:SetAllPoints(icon)
    iconHover:EnableMouse(true)
    iconHover:SetScript("OnEnter", function(self)
        if f.itemLink and ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:SetHyperlink(f.itemLink)
            GameTooltip:Show()
        end
    end)
    iconHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- One driver for the glow pulse, running only while the popup is shown.
    f.pulse = 0
    f:SetScript("OnUpdate", function(self, e)
        if Valuate.GetOptions and Valuate:GetOptions().reduceMotion then
            self.glow:SetAlpha(0.5)
            return
        end
        self.pulse = self.pulse + (e or 0)
        self.glow:SetAlpha(0.35 + 0.3 * math.sin(self.pulse * (2 * math.pi / 1.6)))
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
    f.accent:SetColorTexture(r, g, b, 1)
    f.glow:SetVertexColor(r, g, b, 1)

    local top = opts.top
    f.itemLink = top and top.itemLink or nil

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
    local sub
    if top then
        sub = string.format("|cFFFFFFFF%s|r  |cFF00FF00+%." .. decimals .. "f|r  for %s",
            top.itemName or "an item", top.delta or 0, label)
    else
        sub = string.format("Waiting in your bags for %s", label)
    end
    if (opts.bankCount or 0) > 0 then
        sub = sub .. string.format("  |cFFFF8800(+%d in bank)|r", opts.bankCount)
    end
    f.subtitle:SetText(sub)

    f.equipButton.label:SetText(count > 1 and "Equip All" or "Equip")
    f.equipButton:SetScript("OnClick", function()
        Valuate:HideUpgradePopup()
        if opts.onEquip then opts.onEquip() end
    end)

    -- Entrance: a small overshoot so it arrives with some life rather than just
    -- appearing. Cheap, and skipped entirely under reduce-motion.
    f:Show()
    if Valuate:GetOptions().reduceMotion then
        f:SetAlpha(1)
        f:SetScale(1)
    else
        f:SetAlpha(0)
        f:SetScale(0.9)
        Anim.fade(f, 1, 0.18, "outQuad")
        Anim.scaleTo(f, 1, 0.32, "outBack")
    end
    return f
end

function Valuate:HideUpgradePopup()
    if popup then
        popup:Hide()
        popup:SetScale(1)
    end
end
