-- Valuate - Stat Weight Calculator for WoW Ascension Bronzebeard
-- Interface: 30300 (WotLK 3.3.5a)

-- Addon namespace
Valuate = {}

-- Version info (read from .toc file automatically)
Valuate.version = GetAddOnMetadata("Valuate", "Version") or "Unknown"
Valuate.interface = 30300

-- Equipment slot to inventory slot mapping (for upgrade comparison)
local EquipSlotToInvNumber = {
    ["INVTYPE_AMMO"] = { 0 },
    ["INVTYPE_HEAD"] = { 1 },
    ["INVTYPE_NECK"] = { 2 },
    ["INVTYPE_SHOULDER"] = { 3 },
    ["INVTYPE_BODY"] = { 4 },
    ["INVTYPE_CHEST"] = { 5 },
    ["INVTYPE_ROBE"] = { 5 },
    ["INVTYPE_WAIST"] = { 6 },
    ["INVTYPE_LEGS"] = { 7 },
    ["INVTYPE_FEET"] = { 8 },
    ["INVTYPE_WRIST"] = { 9 },
    ["INVTYPE_HAND"] = { 10 },
    ["INVTYPE_FINGER"] = { 11, 12 },
    ["INVTYPE_TRINKET"] = { 13, 14 },
    ["INVTYPE_CLOAK"] = { 15 },
    ["INVTYPE_WEAPON"] = { 16, 17 },
    ["INVTYPE_SHIELD"] = { 17 },
    ["INVTYPE_2HWEAPON"] = { 16 },
    ["INVTYPE_WEAPONMAINHAND"] = { 16 },
    ["INVTYPE_WEAPONOFFHAND"] = { 17 },
    ["INVTYPE_HOLDABLE"] = { 17 },
    ["INVTYPE_RANGED"] = { 18 },
    ["INVTYPE_THROWN"] = { 18 },
    ["INVTYPE_RANGEDRIGHT"] = { 18 },
    ["INVTYPE_RELIC"] = { 18 },
}

-- Frame for event handling
local frame = CreateFrame("Frame")

-- Event handler
local function OnEvent(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "Valuate" then
        -- Addon loaded, initialize
        Valuate:Initialize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Player entered world, can do additional setup here
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end

-- Initialize function
function Valuate:Initialize()
    -- Initialize SavedVariables with defaults if they don't exist
    if not ValuateOptions then
        ValuateOptions = {
            debug = false,
            decimalPlaces = 1,
            rightAlign = false,
            showScaleValue = true,
            comparisonMode = "number",
            characterWindowScale = nil,
            showCharacterWindowDisplay = true,
            minimapButtonHidden = false,
            characterWindowDisplayMode = "total",
            uiPosition = {},
        }
    end
    
    if not ValuateScales then
        ValuateScales = {}
    end
    
    -- Basic initialization
    print("|cFF00FF00Valuate|r loaded (v" .. self.version .. ")")
    
    -- Verify stat patterns loaded
    if not ValuateStatPatterns then
        print("|cFFFF0000Valuate|r: ERROR - StatDefinitions.lua failed to load!")
    end
    
    -- Hook into tooltips to parse scaled stats
    Valuate:HookTooltips()
    
    -- Create a default scale if none exist
    if not next(ValuateScales) then
        Valuate:CreateDefaultScale()
    end
    
    -- Initialize character window UI if available
    if Valuate.InitializeCharacterWindowUI then
        Valuate:InitializeCharacterWindowUI()
    end
end

-- Creates a simple default scale for testing
function Valuate:CreateDefaultScale()
    local defaultScale = {
        DisplayName = "Default",
        Color = "00FF00",
        Visible = true,
        Values = {}
    }
    
    ValuateScales["Default"] = defaultScale
end

-- ========================================
-- Stat Parsing System
-- ========================================

-- Helper function to strip color codes from text
local function StripColorCodes(text)
    if not text then return "" end
    -- Remove color codes like |cAARRGGBB| and |r|
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

-- Creates or gets the hidden tooltip used for parsing
local function GetPrivateTooltip()
    if not ValuatePrivateTooltip then
        ValuatePrivateTooltip = CreateFrame("GameTooltip", "ValuatePrivateTooltip", nil, "GameTooltipTemplate")
        ValuatePrivateTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return ValuatePrivateTooltip
end

-- Parses stats from tooltip text using regex patterns
-- Returns a table with stat names as keys and values as numbers
function Valuate:ParseStatsFromTooltip(tooltipName, debug)
    local stats = {}
    local tooltip = getglobal(tooltipName)
    
    if not tooltip then
        return nil
    end
    
    -- Ensure stat patterns are loaded
    if not ValuateStatPatterns then
        print("|cFFFF0000Valuate|r: Stat patterns not loaded. Please reload UI.")
        return nil
    end
    
    debug = debug or (ValuateOptions.debug == true)
    
    -- Track weapon slot type for assigning type-specific DPS/Speed
    local weaponSlotType = nil  -- IsMainHand, IsOffHand, IsOneHand, IsTwoHand, IsRanged
    local isMelee = false
    local isRanged = false
    
    -- First pass: identify weapon/armor slot type and item level
    for i = 1, tooltip:NumLines() do
        local leftText = getglobal(tooltipName .. "TextLeft" .. i)
        local rightText = getglobal(tooltipName .. "TextRight" .. i)
        
        if leftText then
            local rawText = leftText:GetText() or ""
            local lineText = StripColorCodes(rawText)
            
            -- Check for item level
            local itemLevel = string.match(lineText, "^Item Level (%d+)$")
            if itemLevel then
                stats["ItemLevel"] = tonumber(itemLevel)
                if debug then
                    print("|cFF00FF00[DEBUG]|r Item Level = " .. itemLevel)
                end
            end
            
            -- Check for weapon slot type (appears on left side)
            if ValuateWeaponSlotPatterns then
                for _, patternData in ipairs(ValuateWeaponSlotPatterns) do
                    if string.match(lineText, patternData[1]) then
                        weaponSlotType = patternData[2]
                        stats[patternData[2]] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Weapon slot: " .. patternData[2])
                        end
                        -- Determine if melee or ranged
                        if patternData[2] == "IsRanged" then
                            isRanged = true
                        else
                            isMelee = true
                        end
                        break
                    end
                end
            end
        end
        
        -- Check right side for weapon type (e.g., "Sword", "Axe")
        if rightText then
            local rawRightText = rightText:GetText() or ""
            local rightLineText = StripColorCodes(rawRightText)
            
            -- Check for weapon types
            if ValuateWeaponTypePatterns then
                for _, patternData in ipairs(ValuateWeaponTypePatterns) do
                    if string.match(rightLineText, patternData[1]) then
                        local statName = patternData[2]
                        -- Handle 2H weapon type conversion
                        if weaponSlotType == "IsTwoHand" then
                            if statName == "IsAxe" then statName = "Is2HAxe"
                            elseif statName == "IsMace" then statName = "Is2HMace"
                            elseif statName == "IsSword" then statName = "Is2HSword"
                            end
                        end
                        stats[statName] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Weapon type: " .. statName)
                        end
                        break
                    end
                end
            end
            
            -- Check for armor types
            if ValuateArmorTypePatterns then
                for _, patternData in ipairs(ValuateArmorTypePatterns) do
                    if string.match(rightLineText, patternData[1]) then
                        stats[patternData[2]] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Armor type: " .. patternData[2])
                        end
                        break
                    end
                end
            end
        end
    end
    
    -- Second pass: parse regular stats
    for i = 1, tooltip:NumLines() do
        local leftText = getglobal(tooltipName .. "TextLeft" .. i)
        if leftText then
            local rawText = leftText:GetText() or ""
            local lineText = StripColorCodes(rawText)
            
            if debug then
                print("|cFF8888FF[DEBUG]|r Line " .. i .. ": '" .. lineText .. "'")
            end
            
            -- Try to match against each stat pattern
            if lineText and lineText ~= "" then
                local matched = false
                for _, patternData in ipairs(ValuateStatPatterns) do
                    local pattern = patternData[1]
                    local statName = patternData[2]
                    
                    local matches = {string.match(lineText, pattern)}
                    if matches[1] then
                        local value = tonumber(matches[1])
                        if value then
                            stats[statName] = (stats[statName] or 0) + value
                            if debug then
                                print("|cFF00FF00[DEBUG]|r Matched " .. statName .. " = " .. value .. " (pattern: " .. pattern .. ")")
                            end
                            matched = true
                            break  -- Found a match, move to next line
                        end
                    end
                end
                if debug and not matched then
                    print("|cFFFF8800[DEBUG]|r No pattern matched for: '" .. lineText .. "'")
                end
            end
        end
    end
    
    -- Assign type-specific DPS and Speed based on weapon slot
    if stats["Dps"] then
        local dps = stats["Dps"]
        
        -- Assign to slot-specific DPS
        if stats["IsMainHand"] then
            stats["MainHandDps"] = dps
        end
        if stats["IsOffHand"] then
            stats["OffHandDps"] = dps
        end
        if stats["IsOneHand"] then
            stats["OneHandDps"] = dps
        end
        if stats["IsTwoHand"] then
            stats["TwoHandDps"] = dps
        end
        
        -- Assign to melee/ranged DPS
        if isMelee then
            stats["MeleeDps"] = dps
        end
        if isRanged or stats["IsRanged"] then
            stats["RangedDps"] = dps
        end
        
        if debug then
            print("|cFF00FF00[DEBUG]|r Assigned DPS to type-specific stats")
        end
    end
    
    if stats["Speed"] then
        local speed = stats["Speed"]
        
        -- Assign to melee/ranged Speed
        if isMelee then
            stats["MeleeSpeed"] = speed
        end
        if isRanged or stats["IsRanged"] then
            stats["RangedSpeed"] = speed
        end
        
        if debug then
            print("|cFF00FF00[DEBUG]|r Assigned Speed to type-specific stats")
        end
    end
    
    -- Calculate Feral AP from weapon DPS (for druids)
    -- Feral AP = (Weapon DPS - 54.8) * 14
    if stats["Dps"] and stats["IsStaff"] then
        local feralAP = math.floor((stats["Dps"] - 54.8) * 14)
        if feralAP > 0 then
            stats["FeralAP"] = feralAP
            if debug then
                print("|cFF00FF00[DEBUG]|r Calculated Feral AP = " .. feralAP)
            end
        end
    end
    
    return stats
end

-- Gets stats for an item link by parsing its tooltip
-- Returns a stats table, or nil if parsing fails
-- Note: For scaled items, this reads the base item stats, not scaled values
-- Scaled values are only available when reading from the actual displayed tooltip
function Valuate:GetStatsForItemLink(itemLink)
    if not itemLink then
        return nil
    end
    
    -- Parse tooltip from the item link
    -- Note: SetHyperlink uses base item data, not scaled values
    local tooltip = GetPrivateTooltip()
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    
    -- Parse the tooltip (note: this will show base stats, not scaled stats)
    local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip", ValuateOptions.debug)
    
    return stats
end

-- Gets stats directly from an already-displayed tooltip
-- This reads the actual tooltip text (includes scaled values)
-- tooltipName: Name of the tooltip frame (e.g., "GameTooltip")
function Valuate:GetStatsFromDisplayedTooltip(tooltipName)
    if not tooltipName then
        return nil
    end
    
    -- Parse the tooltip that's already displayed (this will have scaled values)
    return Valuate:ParseStatsFromTooltip(tooltipName)
end

-- ========================================
-- Tooltip Integration (Performance-Optimized)
-- ========================================

-- Track current item and whether we've added our lines
local CurrentTooltipItem = nil
local CurrentTooltipStats = nil
local ValuateLinesAdded = false

-- Unique marker for detecting Valuate lines in tooltips (nearly invisible color code)
local VALUATE_MARKER = "|cFF000001"
local VALUATE_MARKER_FULL = "|cFF000001|r"

-- Check if our Valuate lines are present in the tooltip
local function HasValuateLines(tooltip)
    if not tooltip then return false end
    local numLines = tooltip:NumLines()
    for i = 1, numLines do
        local leftText = getglobal(tooltip:GetName() .. "TextLeft" .. i)
        if leftText then
            local text = leftText:GetText()
            if text and text:find(VALUATE_MARKER, 1, true) then
                return true
            end
        end
    end
    return false
end

-- Add score lines to tooltip
local function AddScoreLinesToTooltip(tooltip, stats, itemLink)
    if not tooltip or not stats then return end
    
    -- Get active scales
    local activeScales = Valuate:GetActiveScales()
    if #activeScales == 0 then return end
    
    -- Get the item's equipment slot for comparison
    local equipSlot = nil
    if itemLink then
        local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
        equipSlot = itemEquipLoc
    end
    
    -- Calculate and display scores
    local hasScores = false
    for _, scaleName in ipairs(activeScales) do
        local scale = ValuateScales[scaleName]
        if scale then
            -- Check if item has any stats marked as unusable (banned) for this scale
            local hasUnusableStat = false
            if scale.Unusable then
                for statName, statValue in pairs(stats) do
                    if scale.Unusable[statName] and statValue and statValue > 0 then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item has banned stat '" .. statName .. "'")
                        end
                        break
                    end
                end
            end
            
            -- Only show score if no banned stats found on this item
            if not hasUnusableStat then
                local score = Valuate:CalculateItemScore(stats, scale)
                if score and score > 0 then
                    if not hasScores then
                        tooltip:AddLine(" ")
                        hasScores = true
                    end
                    local color = scale.Color or "FFFFFF"
                    local displayName = scale.DisplayName or scaleName
                    local decimals = ValuateOptions.decimalPlaces or 1
                    local formatStr = "%." .. decimals .. "f"
                    local scoreText = string.format(formatStr, score)
                    
                    -- Build the display text based on options
                    local showValue = ValuateOptions.showScaleValue ~= false
                    local compMode = ValuateOptions.comparisonMode or "number"
                    local comparisonText = ""
                    
                    -- Calculate comparison if enabled and item is equippable
                    if compMode ~= "off" and equipSlot and equipSlot ~= "" then
                        -- Try to get equipped score from shopping tooltip first (if comparing items)
                        -- This ensures both items use the same scaled stats context
                        local equippedScore = nil
                        if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
                            local equippedItemLink = ShoppingTooltip1:GetItem()
                            if equippedItemLink then
                                -- Check if this shopping tooltip shows the equipped item for this slot
                                local _, _, _, _, _, _, _, _, shoppingEquipLoc = GetItemInfo(equippedItemLink)
                                if shoppingEquipLoc == equipSlot then
                                    local equippedStats = Valuate:GetStatsFromDisplayedTooltip("ShoppingTooltip1")
                                    if equippedStats then
                                        equippedScore = Valuate:CalculateItemScore(equippedStats, scale)
                                    end
                                end
                            end
                        end
                        
                        -- Fall back to getting equipped score the normal way
                        if not equippedScore then
                            equippedScore = Valuate:GetEquippedItemScore(equipSlot, scale)
                        end
                        
                        if equippedScore then
                            local diff = score - equippedScore
                            local diffColor = ""
                            local diffSign = ""
                            
                            if diff > 0 then
                                diffColor = "|cFF00FF00"  -- Green for upgrades
                                diffSign = "+"
                            elseif diff < 0 then
                                diffColor = "|cFFFF0000"  -- Red for downgrades
                                diffSign = ""  -- Negative sign is included in the number
                            else
                                diffColor = "|cFFFFFF00"  -- Yellow for no change
                                diffSign = ""
                            end
                            
                            local diffText = string.format(formatStr, diff)
                            
                            if compMode == "number" then
                                comparisonText = " " .. diffColor .. "(" .. diffSign .. diffText .. ")|r"
                            elseif compMode == "percent" then
                                if equippedScore > 0 then
                                    local percent = (diff / equippedScore) * 100
                                    local percentText = string.format("%.1f", percent)
                                    comparisonText = " " .. diffColor .. "(" .. diffSign .. percentText .. "%)|r"
                                else
                                    -- No equipped item, show as new
                                    comparisonText = " " .. diffColor .. "(new)|r"
                                end
                            elseif compMode == "both" then
                                if equippedScore > 0 then
                                    local percent = (diff / equippedScore) * 100
                                    local percentText = string.format("%.1f", percent)
                                    comparisonText = " " .. diffColor .. "(" .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%)|r"
                                else
                                    comparisonText = " " .. diffColor .. "(" .. diffSign .. diffText .. ", new)|r"
                                end
                            end
                        end
                    end
                    
                    -- Build icon prefix based on scale's Icon setting
                    local prefix = VALUATE_MARKER_FULL
                    local icon = scale.Icon
                    if icon and icon ~= "" then
                        prefix = prefix .. "|T" .. icon .. ":0|t "
                    end
                    
                    -- Build final display text
                    local displayText
                    if showValue then
                        displayText = prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r" .. comparisonText
                    else
                        -- Show only comparison (no base score)
                        if comparisonText ~= "" then
                            -- Remove the leading space and parentheses from comparison text for cleaner display
                            local cleanComp = comparisonText:gsub("^ ", ""):gsub("%(", ""):gsub("%)", "")
                            displayText = prefix .. "|cFF" .. color .. displayName .. ":|r " .. cleanComp
                        else
                            -- No comparison available, show score anyway
                            displayText = prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r"
                        end
                    end
                    
                    if ValuateOptions.rightAlign then
                        -- Use AddDoubleLine for right-aligned scores
                        local rightText = "|cFF" .. color .. scoreText .. "|r" .. comparisonText
                        if not showValue and comparisonText ~= "" then
                            rightText = comparisonText:gsub("^ ", "")
                        end
                        tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", rightText)
                    else
                        tooltip:AddLine(displayText)
                    end
                end
            end
        end
    end
    
    if hasScores then
        tooltip:Show()  -- Resize tooltip to fit new lines
    end
end

-- Hooks into tooltip display functions to parse and display item scores
function Valuate:HookTooltips()
    -- Hook the Set* methods to parse stats and mark for update
    local function OnTooltipSet(self)
        local itemLink = self:GetItem()
        if itemLink then
            -- New item - reset state
            if CurrentTooltipItem ~= itemLink then
                CurrentTooltipItem = itemLink
                CurrentTooltipStats = nil
                ValuateLinesAdded = false
            end
        end
    end
    
    hooksecurefunc(GameTooltip, "SetBagItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetInventoryItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetHyperlink", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetLootItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetAuctionItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetMerchantItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetQuestItem", OnTooltipSet)
    hooksecurefunc(GameTooltip, "SetQuestLogItem", OnTooltipSet)
    
    -- Hook OnUpdate to continuously check and add our lines
    GameTooltip:HookScript("OnUpdate", function(self, elapsed)
        -- Only process if tooltip is visible and has an item
        if not self:IsVisible() then return end
        local itemLink = self:GetItem()
        if not itemLink then return end
        
        -- Check if our lines are already present
        if HasValuateLines(self) then
            ValuateLinesAdded = true
            return
        end
        
        -- If lines were added but are now gone, the tooltip was rebuilt - need to re-add
        -- Parse stats if we haven't yet for this item
        if not CurrentTooltipStats or CurrentTooltipItem ~= itemLink then
            CurrentTooltipItem = itemLink
            CurrentTooltipStats = Valuate:GetStatsFromDisplayedTooltip("GameTooltip")
            ValuateLinesAdded = false
        end
        
        -- Add our lines if we have stats
        if CurrentTooltipStats and next(CurrentTooltipStats) and not ValuateLinesAdded then
            AddScoreLinesToTooltip(self, CurrentTooltipStats, itemLink)
            ValuateLinesAdded = true
        end
    end)
    
    -- Clear state when tooltip hides
    GameTooltip:HookScript("OnHide", function(self)
        CurrentTooltipItem = nil
        CurrentTooltipStats = nil
        ValuateLinesAdded = false
    end)
    
    -- ========================================
    -- Shopping/Comparison Tooltip Hooks
    -- ========================================
    --
    -- IMPLEMENTATION NOTES (for future reference):
    -- 
    -- The shopping tooltips (ShoppingTooltip1, ShoppingTooltip2) show the "Currently Equipped"
    -- item when you hover over gear. Adding Valuate scores to these required special handling.
    --
    -- WHAT DIDN'T WORK:
    -- 1. OnUpdate hooks - Caused flickering because the tooltip gets rebuilt frequently by the
    --    game or other addons (like EquipCompare). Our lines would be added, then the tooltip
    --    would be rebuilt (removing our lines), then we'd add them again, causing flicker.
    -- 2. OnTooltipSetItem - This script hook doesn't fire on shopping tooltips.
    -- 3. Frame-based delays/throttling - Still caused flickering because the underlying
    --    rebuild issue wasn't addressed.
    --
    -- WHAT WORKS (Pawn-style approach):
    -- Hook the actual methods that SET the tooltip content:
    -- - SetHyperlinkCompareItem: Main method used by the game for comparison tooltips
    -- - SetInventoryItem: Used by EquipCompare addon
    --
    -- By hooking these methods with hooksecurefunc, our code runs immediately AFTER the
    -- tooltip content is set, before any rebuild can occur. This is a one-time addition
    -- per tooltip set, not a continuous loop, so there's no flickering.
    --
    -- Reference: This approach is used by Pawn addon (Pawn.lua lines 212-219)
    -- ========================================
    
    -- Update a shopping tooltip with Valuate scores (called from method hooks)
    local function UpdateShoppingTooltip(tooltipName)
        local tooltip = getglobal(tooltipName)
        if not tooltip then return end
        
        -- Skip if our lines are already present
        if HasValuateLines(tooltip) then return end
        
        -- Parse stats from the displayed tooltip (gets scaled values)
        local stats = Valuate:GetStatsFromDisplayedTooltip(tooltipName)
        if stats and next(stats) then
            -- nil itemLink = no upgrade comparison (this IS the equipped item)
            AddScoreLinesToTooltip(tooltip, stats, nil)
            tooltip:Show()  -- Resize tooltip to fit new lines
        end
    end
    
    -- Hook SetHyperlinkCompareItem - main comparison method used by the game
    if ShoppingTooltip1 and ShoppingTooltip1.SetHyperlinkCompareItem then
        hooksecurefunc(ShoppingTooltip1, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ShoppingTooltip1")
        end)
    end
    if ShoppingTooltip2 and ShoppingTooltip2.SetHyperlinkCompareItem then
        hooksecurefunc(ShoppingTooltip2, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ShoppingTooltip2")
        end)
    end
    
    -- Hook SetInventoryItem - used by EquipCompare addon for comparison tooltips
    if ShoppingTooltip1 then
        hooksecurefunc(ShoppingTooltip1, "SetInventoryItem", function(self, ...)
            UpdateShoppingTooltip("ShoppingTooltip1")
        end)
    end
    if ShoppingTooltip2 then
        hooksecurefunc(ShoppingTooltip2, "SetInventoryItem", function(self, ...)
            UpdateShoppingTooltip("ShoppingTooltip2")
        end)
    end
end

-- ========================================
-- Stat Weight System
-- ========================================

-- Calculate item score based on stat weights (scale)
-- stats: Table of stat values {Strength = 10, Stamina = 20, ...}
-- scale: Table of stat weights {Strength = 1.5, Stamina = 1.0, ...}
-- Returns: Total score (number)
function Valuate:CalculateItemScore(stats, scale)
    if not stats or not scale or not scale.Values then
        return nil
    end
    
    local total = 0
    local scaleValues = scale.Values
    
    -- Multiply each stat value by its weight and sum them
    for statName, statValue in pairs(stats) do
        local weight = scaleValues[statName]
        if weight and weight ~= 0 then
            total = total + (statValue * weight)
        end
    end
    
    return total
end

-- Gets the score of currently equipped item(s) for comparison
-- equipSlot: The equipment slot type (e.g., "INVTYPE_HEAD", "INVTYPE_FINGER")
-- scale: The scale data table to use for scoring
-- Returns: The lowest score among equipped items in that slot (for multi-slot items like rings)
function Valuate:GetEquippedItemScore(equipSlot, scale)
    local invSlots = EquipSlotToInvNumber[equipSlot]
    if not invSlots then return nil end
    
    local lowestScore = nil
    local tooltip = GetPrivateTooltip()
    
    for _, slotId in ipairs(invSlots) do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            tooltip:ClearLines()
            -- Use SetHyperlink instead of SetInventoryItem to get consistent base stats
            -- This ensures we're comparing the same type of stats (base vs base, not base vs scaled)
            tooltip:SetHyperlink(itemLink)
            local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
            if stats then
                local score = Valuate:CalculateItemScore(stats, scale)
                if score and (not lowestScore or score < lowestScore) then
                    lowestScore = score
                end
            end
        end
    end
    
    return lowestScore or 0
end

-- Calculates the total score for all currently equipped gear
-- scale: The scale data table to use for scoring
-- Returns: Total score (number) for all equipped items
function Valuate:CalculateTotalEquippedScore(scale)
    if not scale or not scale.Values then
        return 0
    end
    
    local totalScore = 0
    local tooltip = GetPrivateTooltip()
    
    -- Equipment slots: 1=head, 2=neck, 3=shoulder, 4=shirt(skip), 5=chest, 6=waist, 7=legs,
    -- 8=feet, 9=wrist, 10=hands, 11=finger1, 12=finger2, 13=trinket1, 14=trinket2,
    -- 15=back, 16=mainhand, 17=offhand, 18=ranged, 19=tabard(skip)
    for slotId = 1, 18 do
        -- Skip shirt (4) and tabard (19, but that's after 18 anyway)
        if slotId ~= 4 then
            local itemLink = GetInventoryItemLink("player", slotId)
            if itemLink then
                tooltip:ClearLines()
                tooltip:SetInventoryItem("player", slotId)
                local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                if stats then
                    local score = Valuate:CalculateItemScore(stats, scale)
                    if score then
                        totalScore = totalScore + score
                    end
                end
            end
        end
    end
    
    return totalScore
end

-- Gets all active scales (scales that should be displayed)
-- Returns: Table of scale names that are active
function Valuate:GetActiveScales()
    local active = {}
    
    if not ValuateScales then
        return active
    end
    
    for scaleName, scaleData in pairs(ValuateScales) do
        -- Check if scale has values and is visible
        if scaleData.Values and (scaleData.Visible ~= false) then  -- Default to visible if not set
            tinsert(active, scaleName)
        end
    end
    
    return active
end

-- Displays calculated scores on the tooltip
function Valuate:DisplayScoresOnTooltip(tooltip, stats)
    if not tooltip or not stats then
        if ValuateOptions.debug then
            print("|cFFFF8800[Valuate Debug]|r DisplayScoresOnTooltip: missing tooltip or stats")
        end
        return
    end
    
    -- Get active scales
    local activeScales = Valuate:GetActiveScales()
    
    if ValuateOptions.debug then
        print("|cFFFF8800[Valuate Debug]|r Found " .. #activeScales .. " active scale(s)")
    end
    
    -- If no active scales, don't display anything
    if #activeScales == 0 then
        if ValuateOptions.debug then
            print("|cFFFF8800[Valuate Debug]|r No active scales - cannot display scores")
        end
        return
    end
    
    -- Calculate scores for each active scale
    local scores = {}
    for _, scaleName in ipairs(activeScales) do
        local scale = ValuateScales[scaleName]
        if scale then
            -- Check if item has any stats marked as unusable for this scale
            local hasUnusableStat = false
            if scale.Unusable then
                for statName, statValue in pairs(stats) do
                    if scale.Unusable[statName] and statValue and statValue > 0 then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item has banned stat '" .. statName .. "'")
                        end
                        break
                    end
                end
            end
            
            if not hasUnusableStat then
                local score = Valuate:CalculateItemScore(stats, scale)
                if score and score ~= 0 then
                    scores[scaleName] = score
                    if ValuateOptions.debug then
                        print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' score: " .. score)
                    end
                end
            end
        end
    end
    
    -- If we have scores, display them
    if next(scores) then
        -- Add a blank line first
        tooltip:AddLine(" ")
        
        -- Display each scale's score
        for scaleName, score in pairs(scores) do
            local scale = ValuateScales[scaleName]
            local color = scale.Color or "FFFFFF"
            local displayName = scale.DisplayName or scaleName
            local lineText = "|cFF" .. color .. displayName .. ": " .. string.format("%.1f", score) .. "|r"
            tooltip:AddLine(lineText)
            
            if ValuateOptions.debug then
                print("|cFFFF8800[Valuate Debug]|r Added line to tooltip: " .. lineText)
            end
        end
        
        -- Show the tooltip with updated lines
        tooltip:Show()
    else
        if ValuateOptions.debug then
            print("|cFFFF8800[Valuate Debug]|r No scores to display (all were 0 or nil)")
        end
    end
end

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", OnEvent)

-- Slash command handler (basic)
SLASH_VALUATE1 = "/valuate"
SLASH_VALUATE2 = "/val"
SlashCmdList["VALUATE"] = function(msg)
    local command = strlower(strtrim(msg))
    
    -- Default behavior: open UI (unless help is explicitly requested)
    if command == "" then
        if Valuate.ToggleUI then
            Valuate:ToggleUI()
        else
            print("|cFFFF0000Valuate|r: UI not loaded. Please reload UI with /reload")
        end
        return
    end
    
    if command == "help" then
        print("|cFF00FF00Valuate|r - Stat Weight Calculator")
        print("Commands:")
        print("  /valuate or /val - Open the configuration UI")
        print("  /valuate help - Show this help")
        print("  /valuate version - Show version info")
        print("  /valuate test [itemlink] - Test parsing an item (shift-click item to link)")
        print("  /valuate debug - Toggle debug mode (shows tooltip text being parsed)")
        print("  /valuate scales - List all stat weight scales")
        print("  /valuate import - Import a scale from a scale tag")
        print("  /valuate export [scalename] - Export a scale as a scale tag")
        print("  /valuate ui - Open the configuration UI")
    elseif command == "version" then
        print("|cFF00FF00Valuate|r version " .. Valuate.version .. " (Interface " .. Valuate.interface .. ")")
    elseif strsub(command, 1, 4) == "test" then
        local itemLink = strsub(command, 6)
        if itemLink and itemLink ~= "" then
            -- Temporarily enable debug for test command
            local oldDebug = ValuateOptions.debug
            ValuateOptions.debug = true
            local stats = Valuate:GetStatsForItemLink(itemLink)
            ValuateOptions.debug = oldDebug
            if stats then
                print("|cFF00FF00Valuate|r: Parsed stats for item (base values, not scaled):")
                for statName, value in pairs(stats) do
                    local displayName = ValuateStatNames[statName] or statName
                    print("  " .. displayName .. ": " .. value)
                end
                print("|cFFFFFF00Note:|r For scaled items, hover over the item and use tooltip parsing (coming soon)")
            else
                print("|cFFFF0000Valuate|r: Failed to parse stats for item.")
            end
        else
            print("|cFFFF0000Valuate|r: Usage: /valuate test [itemlink]")
            print("  Shift-click an item in chat to get its link, then paste after 'test'")
        end
    elseif command == "debug" then
        ValuateOptions.debug = not ValuateOptions.debug
        print("|cFF00FF00Valuate|r: Debug mode " .. (ValuateOptions.debug and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif command == "scales" then
        local activeScales = Valuate:GetActiveScales()
        if #activeScales > 0 then
            print("|cFF00FF00Valuate|r: Active scales:")
            for _, scaleName in ipairs(activeScales) do
                local scale = ValuateScales[scaleName]
                local color = scale.Color or "FFFFFF"
                print("  |cFF" .. color .. (scale.DisplayName or scaleName) .. "|r")
            end
        else
            print("|cFFFF0000Valuate|r: No scales configured. Using default scale.")
        end
    elseif command == "import" then
        -- Open import dialog
        if Valuate.ShowImportDialog then
            Valuate:ShowImportDialog()
        else
            print("|cFFFF0000Valuate|r: UI not loaded. Please open Valuate UI first with /valuate")
        end
    elseif strsub(command, 1, 6) == "export" then
        -- Export a scale
        local scaleName = strtrim(strsub(command, 8))
        
        if scaleName == "" then
            -- No scale name specified - list available scales
            print("|cFF00FF00Valuate|r: Please specify a scale name to export.")
            print("Available scales:")
            for name, scale in pairs(ValuateScales) do
                local displayName = scale.DisplayName or name
                print("  " .. displayName)
            end
            print("Usage: /valuate export [scalename]")
        else
            -- Try to find the scale (case-insensitive, match by display name or internal name)
            local foundScale = nil
            local foundName = nil
            
            for name, scale in pairs(ValuateScales) do
                local displayName = scale.DisplayName or name
                if strlower(name) == strlower(scaleName) or strlower(displayName) == strlower(scaleName) then
                    foundScale = scale
                    foundName = name
                    break
                end
            end
            
            if foundScale and foundName then
                local scaleTag = Valuate:GetScaleTag(foundName)
                if scaleTag then
                    print("|cFF00FF00Valuate|r: Scale tag for |cFFFFFFFF" .. (foundScale.DisplayName or foundName) .. "|r:")
                    print(scaleTag)
                    print("|cFFFFFF00Tip:|r Open the Valuate UI (/valuate) to use the Export button for easier copying.")
                else
                    print("|cFFFF0000Valuate|r: Failed to generate export string for scale.")
                end
            else
                print("|cFFFF0000Valuate|r: Scale not found: " .. scaleName)
                print("Available scales:")
                for name, scale in pairs(ValuateScales) do
                    local displayName = scale.DisplayName or name
                    print("  " .. displayName)
                end
            end
        end
    elseif command == "ui" then
        if Valuate.ToggleUI then
            Valuate:ToggleUI()
        else
            print("|cFFFF0000Valuate|r: UI not loaded. Please reload UI with /reload")
        end
    else
        print("|cFF00FF00Valuate|r: Unknown command. Type |cFFFFFFFF/valuate help|r for available commands.")
    end
end

-- ========================================
-- Keybinding System
-- ========================================

-- Keybinding function that WoW calls when the key is pressed
-- This is registered in Bindings.xml
function ValuateToggleUI()
    if Valuate and Valuate.ToggleUI then
        Valuate:ToggleUI()
    else
        print("|cFFFF0000Valuate|r: UI not ready. Please try again or /reload.")
    end
end

