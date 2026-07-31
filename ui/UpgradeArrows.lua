-- ui/UpgradeArrows.lua
-- Pins a green arrow to the top-right of any item icon that is an upgrade for one
-- of your scales: merchant window, loot window, and the default bag frames.
--
-- DELIBERATELY NOT the character/wardrobe panels. An arrow on gear you are already
-- wearing is noise - the whole point is to flag things you could acquire.
--
-- Two rules shape the implementation:
--
-- 1. We never write a field onto a Blizzard frame. Our textures live in a local
--    table keyed by the button, so nothing we do can taint a secure frame or
--    collide with another addon's field of the same name.
-- 2. Blizzard update functions are hooked with hooksecurefunc where they exist, and
--    every hook is guarded by a type check first - this is a modified client, and a
--    renamed FrameXML function must degrade to "no arrows", never to an error.

local _, ns = ...

local COLORS = ns.COLORS

-- button -> our texture. Keyed by the frame itself so nothing is stored on it.
local arrows = {}

-- Resolved once, on first use. SetTexture returns whether the file loaded on 3.3.5,
-- so we can pick a path that actually exists instead of assuming one.
local arrowTexturePath, arrowNeedsFlip

local function ResolveArrowTexture(tex)
    if arrowTexturePath then return arrowTexturePath, arrowNeedsFlip end

    -- Preferred: a genuine up arrow.
    if tex:SetTexture("Interface\\Buttons\\Arrow-Up-Up") then
        arrowTexturePath, arrowNeedsFlip = "Interface\\Buttons\\Arrow-Up-Up", false
    else
        -- Fallback: the down arrow flipped vertically. Confirmed present on this
        -- client (other installed addons reference it), so this always resolves.
        arrowTexturePath, arrowNeedsFlip = "Interface\\Buttons\\Arrow-Down-Down", true
    end
    return arrowTexturePath, arrowNeedsFlip
end

local function GetArrow(button)
    local arrow = arrows[button]
    if arrow then return arrow end

    arrow = button:CreateTexture(nil, "OVERLAY")
    local path, flip = ResolveArrowTexture(arrow)
    arrow:SetTexture(path)
    if flip then
        arrow:SetTexCoord(0, 1, 1, 0)
    end
    arrow:SetWidth(14)
    arrow:SetHeight(14)
    -- Top-right, nudged slightly outside so it doesn't cover the item's own art.
    arrow:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2, 2)
    arrow:SetVertexColor(0.1, 1.0, 0.1, 1)
    arrow:Hide()

    arrows[button] = arrow
    return arrow
end

-- The single entry point: show or hide the arrow for one button.
local function SetArrow(button, itemLink)
    if not button then return end

    local options = Valuate:GetOptions()
    if not options.showUpgradeArrows then
        local existing = arrows[button]
        if existing then existing:Hide() end
        return
    end

    if not itemLink then
        local existing = arrows[button]
        if existing then existing:Hide() end
        return
    end

    local isUpgrade = Valuate:IsItemLinkUpgrade(itemLink)
    if isUpgrade then
        GetArrow(button):Show()
    else
        local existing = arrows[button]
        if existing then existing:Hide() end
    end
end
ns.SetUpgradeArrow = SetArrow

-- ========================================
-- Merchant window
-- ========================================
local function UpdateMerchantArrows()
    -- Iterate while the button exists rather than assuming a page size: the count
    -- differs between clients, and this is how other addons here walk it.
    -- Page size comes from the client's own constant where it exists; 10 is the
    -- 3.3.5 default and only a fallback.
    local perPage = tonumber(MERCHANT_ITEMS_PER_PAGE) or 10
    local page = (MerchantFrame and MerchantFrame.page) or 1
    -- The buyback tab reuses these same buttons, and GetMerchantItemLink would
    -- return the wrong item for them.
    local onItemTab = not MerchantFrame or MerchantFrame.selectedTab == 1

    local i = 1
    while _G["MerchantItem" .. i .. "ItemButton"] do
        local button = _G["MerchantItem" .. i .. "ItemButton"]
        local link
        if onItemTab and GetMerchantItemLink then
            link = GetMerchantItemLink((page - 1) * perPage + i)
        end
        SetArrow(button, link)
        i = i + 1
    end
end

-- ========================================
-- Loot window
-- ========================================
local function UpdateLootArrows()
    local i = 1
    while _G["LootButton" .. i] do
        local button = _G["LootButton" .. i]
        -- Blizzard stores the loot slot on the button during its own update. We
        -- only READ it - writing Blizzard fields is what taints frames.
        local slot = button.slot
        local link = (button:IsShown() and slot and GetLootSlotLink) and GetLootSlotLink(slot) or nil
        SetArrow(button, link)
        i = i + 1
    end
end

-- ========================================
-- Default bag frames
-- ========================================
-- AdiBags replaces these entirely; it is handled in the Valuate-AdiBags module,
-- which gets a per-button message with the link already resolved. This path only
-- matters when AdiBags is disabled.
local function UpdateContainerArrows(frame)
    if not frame or not frame.GetName then return end
    local name = frame:GetName()
    if not name then return end

    local bagId = frame:GetID()
    local size = GetContainerNumSlots(bagId) or 0
    for i = 1, size do
        -- Blizzard numbers container buttons in reverse of the slot order.
        local button = _G[name .. "Item" .. (size - i + 1)]
        if button then
            SetArrow(button, GetContainerItemLink(bagId, i))
        end
    end
end

-- ========================================
-- Wiring
-- ========================================
local function RefreshAll()
    if MerchantFrame and MerchantFrame:IsShown() then UpdateMerchantArrows() end
    if LootFrame and LootFrame:IsShown() then UpdateLootArrows() end
end
ns.RefreshUpgradeArrows = RefreshAll

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function()
    -- Hooked on login rather than at file scope so FrameXML is definitely loaded.
    -- Each hook is guarded: on a modified client a missing function must mean "no
    -- arrows here", not a Lua error that takes the rest of the addon with it.
    if type(MerchantFrame_UpdateMerchantInfo) == "function" then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", UpdateMerchantArrows)
    end
    if type(LootFrame_Update) == "function" then
        hooksecurefunc("LootFrame_Update", UpdateLootArrows)
    end
    if type(ContainerFrame_Update) == "function" then
        hooksecurefunc("ContainerFrame_Update", UpdateContainerArrows)
    end

    -- A scan changes what counts as an upgrade, so repaint whatever is open.
    if Valuate.RegisterBestEquipmentListener then
        Valuate:RegisterBestEquipmentListener(RefreshAll)
    end
end)
