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

-- Slot ID to friendly name mapping
local SlotIdToName = {
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [16] = "Main Hand",
    [17] = "Off Hand",
}

-- Helper function to check if two weapon types are comparable
local function AreWeaponTypesComparable(hoverType, equippedType)
    -- Shields never compare to weapons
    if (hoverType == "INVTYPE_SHIELD" or hoverType == "INVTYPE_HOLDABLE") then
        return (equippedType == "INVTYPE_SHIELD" or equippedType == "INVTYPE_HOLDABLE")
    end
    if (equippedType == "INVTYPE_SHIELD" or equippedType == "INVTYPE_HOLDABLE") then
        return false
    end
    
    -- 2H weapons only compare to other 2H weapons
    if hoverType == "INVTYPE_2HWEAPON" then
        return equippedType == "INVTYPE_2HWEAPON"
    end
    if equippedType == "INVTYPE_2HWEAPON" then
        return false
    end
    
    -- 1H generic weapons (INVTYPE_WEAPON) compare to other 1H generic weapons
    if hoverType == "INVTYPE_WEAPON" then
        return equippedType == "INVTYPE_WEAPON"
    end
    
    -- Mainhand-only weapons compare to mainhand-only and 1H generic in mainhand slot
    if hoverType == "INVTYPE_WEAPONMAINHAND" then
        return equippedType == "INVTYPE_WEAPONMAINHAND" or equippedType == "INVTYPE_WEAPON"
    end
    
    -- Offhand-only weapons compare to offhand-only and 1H generic in offhand slot
    if hoverType == "INVTYPE_WEAPONOFFHAND" then
        return equippedType == "INVTYPE_WEAPONOFFHAND" or equippedType == "INVTYPE_WEAPON"
    end
    
    -- For all other cases, types should match
    return hoverType == equippedType
end

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
            normalizeDisplay = false,  -- Global normalize toggle for all displays
            showStatBreakdown = false,  -- Show detailed stat breakdown in tooltips
        }
    end
    
    -- Add normalizeDisplay option if it doesn't exist (for existing users)
    if ValuateOptions.normalizeDisplay == nil then
        ValuateOptions.normalizeDisplay = false
    end
    
    -- Add showStatBreakdown option if it doesn't exist (for existing users)
    if ValuateOptions.showStatBreakdown == nil then
        ValuateOptions.showStatBreakdown = false
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
            
            -- Check for relic types
            if ValuateRelicTypePatterns then
                for _, patternData in ipairs(ValuateRelicTypePatterns) do
                    if string.match(rightLineText, patternData[1]) then
                        stats[patternData[2]] = 1
                        if debug then
                            print("|cFF00FF00[DEBUG]|r Relic type: " .. patternData[2])
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
                -- Split by newlines in case multiple stats are in one GetText() result
                -- Some tooltips return multi-line strings from a single GetText() call
                local lines = {}
                for line in string.gmatch(lineText, "[^\r\n]+") do
                    table.insert(lines, line)
                end
                
                -- If no newlines found, process the original line
                if #lines == 0 then
                    table.insert(lines, lineText)
                end
                
                -- Process each line separately
                for _, line in ipairs(lines) do
                    local matched = false
                    for _, patternData in ipairs(ValuateStatPatterns) do
                        local pattern = patternData[1]
                        local statName = patternData[2]
                        
                        local matches = {string.match(line, pattern)}
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
                        print("|cFFFF8800[DEBUG]|r No pattern matched for: '" .. line .. "'")
                    end
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

-- Store default tooltip border colors
local DefaultTooltipBorderColor = nil

-- Unique marker for detecting Valuate lines in tooltips (nearly invisible color code)
local VALUATE_MARKER = "|cFF000001"
local VALUATE_MARKER_FULL = "|cFF000001|r"

-- Determine tooltip border color based on displayed scale
-- Returns r, g, b values (0-1 range) or nil if no coloring should be applied
local function GetTooltipBorderColor(stats, itemLink)
    -- Check if a character window scale is selected
    local scaleName = ValuateOptions.characterWindowScale
    if not scaleName or scaleName == "" then
        return nil  -- No scale selected, use default border
    end
    
    -- Get the scale data
    local scale = ValuateScales[scaleName]
    if not scale or not scale.Values then
        return nil  -- Invalid scale
    end
    
    -- Check if item is equippable
    local equipSlot = nil
    if itemLink then
        local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
        equipSlot = itemEquipLoc
    end
    
    if not equipSlot or equipSlot == "" then
        return nil  -- Non-equippable item, use default border
    end
    
    -- Check if item has any stats marked as unusable (banned) for this scale
    if scale.Unusable then
        -- First check parsed stats
        for statName, statValue in pairs(stats) do
            if scale.Unusable[statName] and statValue and statValue > 0 then
                return nil  -- Item has banned stat, use default border
            end
        end
        
        -- Also check equipment slot type directly (in case tooltip parsing missed weapon type)
        if equipSlot then
            if equipSlot == "INVTYPE_2HWEAPON" and scale.Unusable["TwoHandDps"] then
                return nil  -- Item is 2H weapon (banned), use default border
            elseif equipSlot == "INVTYPE_WEAPONOFFHAND" and scale.Unusable["OffHandDps"] then
                return nil  -- Item is offhand weapon (banned), use default border
            elseif (equipSlot == "INVTYPE_RANGED" or equipSlot == "INVTYPE_RANGEDRIGHT" or equipSlot == "INVTYPE_THROWN") and scale.Unusable["RangedDps"] then
                return nil  -- Item is ranged weapon (banned), use default border
            end
        end
    end
    
    -- Calculate item score
    local score = Valuate:CalculateItemScore(stats, scale)
    if not score or score <= 0 then
        return nil  -- No score, use default border
    end
    
    -- Get equipped item score for comparison
    local equippedScore = nil
    
    -- Try to get equipped score from shopping tooltip first (if comparing items)
    if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
        local equippedItemLink = ShoppingTooltip1:GetItem()
        if equippedItemLink then
            local _, _, _, _, _, _, _, _, shoppingEquipLoc = GetItemInfo(equippedItemLink)
            -- Check if items are comparable (uses smart weapon comparison logic)
            if shoppingEquipLoc and AreWeaponTypesComparable(equipSlot, shoppingEquipLoc) then
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
    
    if not equippedScore then
        return nil  -- No equipped item to compare, use default border
    end
    
    -- Determine border color based on comparison
    local diff = score - equippedScore
    
    if diff > 0 then
        return 0, 1, 0  -- Green for upgrades
    elseif diff < 0 then
        return 1, 0, 0  -- Red for downgrades
    else
        return nil  -- Equal scores - use default border
    end
end

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
                -- First check parsed stats
                for statName, statValue in pairs(stats) do
                    if scale.Unusable[statName] and statValue and statValue > 0 then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item has banned stat '" .. statName .. "'")
                        end
                        break
                    end
                end
                
                -- Also check equipment slot type directly (in case tooltip parsing missed weapon type)
                if not hasUnusableStat and equipSlot then
                    if equipSlot == "INVTYPE_2HWEAPON" and scale.Unusable["TwoHandDps"] then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is 2H weapon (banned by TwoHandDps)")
                        end
                    elseif equipSlot == "INVTYPE_WEAPONOFFHAND" and scale.Unusable["OffHandDps"] then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is offhand weapon (banned by OffHandDps)")
                        end
                    elseif (equipSlot == "INVTYPE_RANGED" or equipSlot == "INVTYPE_RANGEDRIGHT" or equipSlot == "INVTYPE_THROWN") and scale.Unusable["RangedDps"] then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is ranged weapon (banned by RangedDps)")
                        end
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
                    
                    -- Build icon prefix based on scale's Icon setting
                    local prefix = VALUATE_MARKER_FULL
                    local icon = scale.Icon
                    if icon and icon ~= "" then
                        prefix = prefix .. "|T" .. icon .. ":0|t "
                    end
                    
                    -- Show detailed stat breakdown if enabled
                    if ValuateOptions.showStatBreakdown then
                        -- Check if this is a multi-slot item for per-slot breakdown
                        local isMultiSlotBreakdown = isMultiSlot and compMode ~= "off"
                        
                        -- For non-multi-slot items, show breakdown once
                        if not isMultiSlotBreakdown then
                            -- Try to get equipped item stats for comparison
                            -- Only compare if itemLink is provided (hover tooltip), not for shopping tooltips (itemLink is nil)
                            local equippedStats = nil
                            if itemLink and equipSlot and equipSlot ~= "" then
                                -- Try shopping tooltip first for context
                                if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
                                    local equippedItemLink = ShoppingTooltip1:GetItem()
                                    if equippedItemLink then
                                        local _, _, _, _, _, _, _, _, shoppingEquipLoc = GetItemInfo(equippedItemLink)
                                        if shoppingEquipLoc and AreWeaponTypesComparable(equipSlot, shoppingEquipLoc) then
                                            equippedStats = Valuate:GetStatsFromDisplayedTooltip("ShoppingTooltip1")
                                        end
                                    end
                                end
                                
                                -- Fall back to getting equipped item stats the normal way
                                if not equippedStats then
                                    local invSlots = EquipSlotToInvNumber[equipSlot]
                                    if invSlots then
                                        for _, slotId in ipairs(invSlots) do
                                            local itemLink = GetInventoryItemLink("player", slotId)
                                            if itemLink then
                                                local _, _, _, _, _, _, _, _, equippedEquipLoc = GetItemInfo(itemLink)
                                                if equippedEquipLoc and AreWeaponTypesComparable(equipSlot, equippedEquipLoc) then
                                                    local tooltip = GetPrivateTooltip()
                                                    tooltip:ClearLines()
                                                    tooltip:SetInventoryItem("player", slotId)
                                                    equippedStats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                                                    break  -- Use first comparable equipped item
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            
                            -- Use comparison breakdown if we have equipped stats
                            local breakdown
                            if equippedStats then
                                breakdown = Valuate:CalculateStatBreakdownWithComparison(stats, equippedStats, scale)
                            else
                                breakdown = Valuate:CalculateStatBreakdown(stats, scale)
                            end
                        
                            if breakdown and #breakdown > 0 then
                                -- Display scale name as header for the breakdown
                                tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ":|r")
                            
                            -- Track totals for the summary line
                            local totalHoverContrib = 0
                            local totalEquippedContrib = 0
                            
                            -- Display each stat contribution
                            for _, entry in ipairs(breakdown) do
                                local statDisplayName = ValuateStatNames[entry.statName] or entry.statName
                                
                                if equippedStats and entry.equippedValue and compMode ~= "off" then
                                    -- With comparison (only if comparison mode is enabled)
                                    local hoverValueText = string.format(formatStr, entry.hoverValue)
                                    local weightText = string.format(formatStr, entry.hoverWeight)
                                    local hoverContribText = string.format(formatStr, entry.hoverContribution)
                                    local equippedContribText = string.format(formatStr, entry.equippedContribution)
                                    local diffText = string.format(formatStr, entry.diff)
                                    local percentText = string.format("%.1f", entry.percentDiff)
                                    
                                    -- Add to totals
                                    totalHoverContrib = totalHoverContrib + entry.hoverContribution
                                    totalEquippedContrib = totalEquippedContrib + entry.equippedContribution
                                    
                                    -- Determine color for the difference values only
                                    local diffColor
                                    local diffSign = ""
                                    if entry.diff > 0 then
                                        diffColor = "00FF00"  -- Green for upgrade
                                        diffSign = "+"
                                    elseif entry.diff < 0 then
                                        diffColor = "FF0000"  -- Red for downgrade
                                        diffSign = ""  -- Negative sign already in number
                                    else
                                        diffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                        diffSign = ""
                                    end
                                    
                                    -- Build comparison text based on comparison mode
                                    local comparisonPart = ""
                                    if compMode == "number" then
                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. "|r|cFF" .. color .. ")"
                                    elseif compMode == "percent" then
                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                    elseif compMode == "both" then
                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                    end
                                    
                                    -- Format: "  Stat: hoverValue × weight = hoverContrib (comparison)"
                                    -- Only show the hover item's value, not the equipped item's value
                                    if ValuateOptions.rightAlign then
                                        -- Right-aligned: split into left and right parts
                                        local leftPart = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            hoverValueText .. " × " .. weightText .. "|r"
                                        local rightPart = "|cFF" .. color .. hoverContribText .. comparisonPart .. "|r"
                                        tooltip:AddDoubleLine(leftPart, rightPart)
                                    else
                                        -- Normal: single line
                                        local breakdownLine = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            hoverValueText .. " × " .. weightText .. " = " .. hoverContribText .. 
                                            comparisonPart .. "|r"
                                        tooltip:AddLine(breakdownLine)
                                    end
                                else
                                    -- Without comparison (no equipped item or comparison mode is "off")
                                    local statValueText = string.format(formatStr, entry.statValue or entry.hoverValue)
                                    local weightText = string.format(formatStr, entry.weight or entry.hoverWeight)
                                    local contributionText = string.format(formatStr, entry.contribution or entry.hoverContribution)
                                    
                                    -- Add to total (no comparison)
                                    totalHoverContrib = totalHoverContrib + (entry.contribution or entry.hoverContribution)
                                    
                                    if ValuateOptions.rightAlign then
                                        -- Right-aligned: split into left and right parts
                                        local leftPart = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            statValueText .. " × " .. weightText .. "|r"
                                        local rightPart = "|cFF" .. color .. contributionText .. "|r"
                                        tooltip:AddDoubleLine(leftPart, rightPart)
                                    else
                                        -- Normal: single line
                                        local breakdownLine = "  " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                            statValueText .. " × " .. weightText .. " = " .. contributionText .. "|r"
                                        tooltip:AddLine(breakdownLine)
                                    end
                                end
                            end
                            
                            -- Display total line
                            if equippedStats and compMode ~= "off" then
                                -- With comparison - only show hover item's total with comparison
                                local totalHoverText = string.format(formatStr, totalHoverContrib)
                                local totalEquippedText = string.format(formatStr, totalEquippedContrib)
                                local totalDiff = totalHoverContrib - totalEquippedContrib
                                local totalDiffText = string.format(formatStr, totalDiff)
                                local totalPercentDiff = 0
                                if totalEquippedContrib ~= 0 then
                                    totalPercentDiff = (totalDiff / math.abs(totalEquippedContrib)) * 100
                                elseif totalDiff ~= 0 then
                                    totalPercentDiff = (totalDiff > 0) and 100 or -100
                                end
                                local totalPercentText = string.format("%.1f", totalPercentDiff)
                                
                                -- Determine color for total difference
                                local totalDiffColor
                                local totalDiffSign = ""
                                if totalDiff > 0 then
                                    totalDiffColor = "00FF00"
                                    totalDiffSign = "+"
                                elseif totalDiff < 0 then
                                    totalDiffColor = "FF0000"
                                    totalDiffSign = ""
                                else
                                    totalDiffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                    totalDiffSign = ""
                                end
                                
                                -- Build total comparison text
                                local totalComparisonPart = ""
                                if compMode == "number" then
                                    totalComparisonPart = " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. "|r|cFF" .. color .. ")"
                                elseif compMode == "percent" then
                                    totalComparisonPart = " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                elseif compMode == "both" then
                                    totalComparisonPart = " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. ", " .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                end
                                
                                if ValuateOptions.rightAlign then
                                    local leftPart = "  " .. prefix .. "|cFF" .. color .. "Total:|r"
                                    local rightPart = "|cFF" .. color .. totalHoverText .. totalComparisonPart .. "|r"
                                    tooltip:AddDoubleLine(leftPart, rightPart)
                                else
                                    local totalLine = "  " .. prefix .. "|cFF" .. color .. "Total: " .. totalHoverText .. 
                                        totalComparisonPart .. "|r"
                                    tooltip:AddLine(totalLine)
                                end
                            else
                                -- Without comparison
                                local totalText = string.format(formatStr, totalHoverContrib)
                                if ValuateOptions.rightAlign then
                                    local leftPart = "  " .. prefix .. "|cFF" .. color .. "Total:|r"
                                    local rightPart = "|cFF" .. color .. totalText .. "|r"
                                    tooltip:AddDoubleLine(leftPart, rightPart)
                                else
                                    local totalLine = "  " .. prefix .. "|cFF" .. color .. "Total: " .. totalText .. "|r"
                                    tooltip:AddLine(totalLine)
                                end
                            end
                            end
                        end
                    end
                    
                    -- Check if this is a multi-slot item type (rings, trinkets, 1H weapons)
                    local isMultiSlot = (equipSlot == "INVTYPE_FINGER" or equipSlot == "INVTYPE_TRINKET" or equipSlot == "INVTYPE_WEAPON")
                    
                    -- Calculate comparison if enabled and item is equippable
                    -- Only show multi-slot breakdown on hover tooltips (itemLink provided), not shopping tooltips
                    if compMode ~= "off" and equipSlot and equipSlot ~= "" and isMultiSlot and itemLink then
                        -- For multi-slot items, show individual comparisons
                        local equippedScores = Valuate:GetEquippedItemScores(equipSlot, scale)
                        
                        if equippedScores and next(equippedScores) then
                            -- Add scale name header (only once at the top)
                            if ValuateOptions.showStatBreakdown then
                                tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ":|r")
                            elseif showValue then
                                -- Show main line with item score (old behavior when breakdown is off)
                                if ValuateOptions.rightAlign then
                                    tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", "|cFF" .. color .. scoreText .. "|r")
                                else
                                    tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r")
                                end
                            end
                            
                            -- Add individual comparison lines for each equipped item
                            for slotId, equippedScore in pairs(equippedScores) do
                                local slotName = SlotIdToName[slotId] or ("Slot " .. slotId)
                                local diff = score - equippedScore
                                local diffColor = ""
                                local diffSign = ""
                                
                                if diff > 0 then
                                    diffColor = "|cFF00FF00"
                                    diffSign = "+"
                                elseif diff < 0 then
                                    diffColor = "|cFFFF0000"
                                    diffSign = ""
                                else
                                    diffColor = "|cFFFFFF00"
                                    diffSign = ""
                                end
                                
                                local diffText = string.format(formatStr, diff)
                                local slotComparisonText = ""
                                
                                if compMode == "number" then
                                    slotComparisonText = diffColor .. diffSign .. diffText .. "|r"
                                elseif compMode == "percent" then
                                    if equippedScore > 0 then
                                        local percent = (diff / equippedScore) * 100
                                        local percentText
                                        if math.abs(percent) >= 1000 then
                                            percentText = "HUGE!"
                                            slotComparisonText = diffColor .. diffSign .. percentText .. "|r"
                                        else
                                            percentText = string.format("%.1f", percent)
                                            slotComparisonText = diffColor .. diffSign .. percentText .. "%|r"
                                        end
                                    else
                                        slotComparisonText = diffColor .. "new|r"
                                    end
                                elseif compMode == "both" then
                                    if equippedScore > 0 then
                                        local percent = (diff / equippedScore) * 100
                                        local percentText
                                        if math.abs(percent) >= 1000 then
                                            percentText = "HUGE!"
                                            slotComparisonText = diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "|r"
                                        else
                                            percentText = string.format("%.1f", percent)
                                            slotComparisonText = diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%|r"
                                        end
                                    else
                                        slotComparisonText = diffColor .. diffSign .. diffText .. ", new|r"
                                    end
                                end
                                
                                -- Add slot comparison line
                                if ValuateOptions.rightAlign then
                                    tooltip:AddDoubleLine("  " .. prefix .. "|cFF" .. color .. slotName .. "|r", slotComparisonText)
                                else
                                    tooltip:AddLine("  " .. prefix .. "|cFF" .. color .. slotName .. ": " .. slotComparisonText .. "|r")
                                end
                                
                                -- Add stat breakdown for this specific equipped item if enabled
                                if ValuateOptions.showStatBreakdown then
                                    -- Get stats for this specific equipped item
                                    local itemLink = GetInventoryItemLink("player", slotId)
                                    if itemLink then
                                        local equipTooltip = GetPrivateTooltip()
                                        equipTooltip:ClearLines()
                                        equipTooltip:SetInventoryItem("player", slotId)
                                        local slotEquippedStats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                                        
                                        if slotEquippedStats then
                                            local slotBreakdown = Valuate:CalculateStatBreakdownWithComparison(stats, slotEquippedStats, scale)
                                            
                                            if slotBreakdown and #slotBreakdown > 0 then
                                                local slotTotalHover = 0
                                                local slotTotalEquipped = 0
                                                
                                                -- Display each stat for this slot
                                                for _, entry in ipairs(slotBreakdown) do
                                                    local statDisplayName = ValuateStatNames[entry.statName] or entry.statName
                                                    local hoverValueText = string.format(formatStr, entry.hoverValue)
                                                    local weightText = string.format(formatStr, entry.hoverWeight)
                                                    local hoverContribText = string.format(formatStr, entry.hoverContribution)
                                                    local equippedContribText = string.format(formatStr, entry.equippedContribution)
                                                    local diffText = string.format(formatStr, entry.diff)
                                                    local percentText = string.format("%.1f", entry.percentDiff)
                                                    
                                                    slotTotalHover = slotTotalHover + entry.hoverContribution
                                                    slotTotalEquipped = slotTotalEquipped + entry.equippedContribution
                                                    
                                                    -- Determine color for difference
                                                    local diffColor, diffSign = "", ""
                                                    if entry.diff > 0 then
                                                        diffColor = "00FF00"
                                                        diffSign = "+"
                                                    elseif entry.diff < 0 then
                                                        diffColor = "FF0000"
                                                        diffSign = ""
                                                    else
                                                        diffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                                        diffSign = ""
                                                    end
                                                    
                                                    -- Build comparison text
                                                    local comparisonPart = ""
                                                    if compMode == "number" then
                                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. "|r|cFF" .. color .. ")"
                                                    elseif compMode == "percent" then
                                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                                    elseif compMode == "both" then
                                                        comparisonPart = " (|r|cFF" .. diffColor .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%|r|cFF" .. color .. ")"
                                                    end
                                                    
                                                    -- Display stat line (indented more) - only show hover item's value
                                                    if ValuateOptions.rightAlign then
                                                        local leftPart = "    " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                                            hoverValueText .. " × " .. weightText .. "|r"
                                                        local rightPart = "|cFF" .. color .. hoverContribText .. comparisonPart .. "|r"
                                                        tooltip:AddDoubleLine(leftPart, rightPart)
                                                    else
                                                        local breakdownLine = "    " .. prefix .. "|cFF" .. color .. statDisplayName .. ": " .. 
                                                            hoverValueText .. " × " .. weightText .. " = " .. hoverContribText .. 
                                                            comparisonPart .. "|r"
                                                        tooltip:AddLine(breakdownLine)
                                                    end
                                                end
                                                
                                                -- Display total for this slot
                                                local totalHoverText = string.format(formatStr, slotTotalHover)
                                                local totalEquippedText = string.format(formatStr, slotTotalEquipped)
                                                local totalDiff = slotTotalHover - slotTotalEquipped
                                                local totalDiffText = string.format(formatStr, totalDiff)
                                                local totalPercentDiff = 0
                                                if slotTotalEquipped ~= 0 then
                                                    totalPercentDiff = (totalDiff / math.abs(slotTotalEquipped)) * 100
                                                elseif totalDiff ~= 0 then
                                                    totalPercentDiff = (totalDiff > 0) and 100 or -100
                                                end
                                                local totalPercentText = string.format("%.1f", totalPercentDiff)
                                                
                                                local totalDiffColor, totalDiffSign = "", ""
                                                if totalDiff > 0 then
                                                    totalDiffColor = "00FF00"
                                                    totalDiffSign = "+"
                                                elseif totalDiff < 0 then
                                                    totalDiffColor = "FF0000"
                                                    totalDiffSign = ""
                                                else
                                                    totalDiffColor = "FFFF00"  -- Yellow for no change (matches original scale comparison)
                                                    totalDiffSign = ""
                                                end
                                                
                                                local totalComparisonPart = ""
                                                if compMode == "number" then
                                                    totalComparisonPart = " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. "|r|cFF" .. color .. ")"
                                                elseif compMode == "percent" then
                                                    totalComparisonPart = " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                                elseif compMode == "both" then
                                                    totalComparisonPart = " (|r|cFF" .. totalDiffColor .. totalDiffSign .. totalDiffText .. ", " .. totalDiffSign .. totalPercentText .. "%|r|cFF" .. color .. ")"
                                                end
                                                
                                                if ValuateOptions.rightAlign then
                                                    local leftPart = "    " .. prefix .. "|cFF" .. color .. "Total:|r"
                                                    local rightPart = "|cFF" .. color .. totalHoverText .. totalComparisonPart .. "|r"
                                                    tooltip:AddDoubleLine(leftPart, rightPart)
                                                else
                                                    local totalLine = "    " .. prefix .. "|cFF" .. color .. "Total: " .. totalHoverText .. 
                                                        totalComparisonPart .. "|r"
                                                    tooltip:AddLine(totalLine)
                                                end
                                                
                                                -- Add blank line between slots for readability
                                                tooltip:AddLine(" ")
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            -- No equipped items in these slots (skip if stat breakdown already shown)
                            if showValue and not ValuateOptions.showStatBreakdown then
                                if ValuateOptions.rightAlign then
                                    tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", "|cFF" .. color .. scoreText .. "|r")
                                else
                                    tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r")
                                end
                            end
                        end
                    elseif compMode ~= "off" and equipSlot and equipSlot ~= "" then
                        -- Try to get equipped score from shopping tooltip first (if comparing items)
                        -- This ensures both items use the same scaled stats context
                        local equippedScore = nil
                        if ShoppingTooltip1 and ShoppingTooltip1:IsVisible() then
                            local equippedItemLink = ShoppingTooltip1:GetItem()
                            if equippedItemLink then
                                -- Check if this shopping tooltip shows the equipped item for this slot
                                local _, _, _, _, _, _, _, _, shoppingEquipLoc = GetItemInfo(equippedItemLink)
                                -- Check if items are comparable (uses smart weapon comparison logic)
                                if shoppingEquipLoc and AreWeaponTypesComparable(equipSlot, shoppingEquipLoc) then
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
                                    local percentText
                                    -- Use "HUGE!" for extreme percentages (>=1000% or <=-1000%)
                                    if math.abs(percent) >= 1000 then
                                        percentText = "HUGE!"
                                        comparisonText = " " .. diffColor .. "(" .. diffSign .. percentText .. ")|r"
                                    else
                                        percentText = string.format("%.1f", percent)
                                        comparisonText = " " .. diffColor .. "(" .. diffSign .. percentText .. "%)|r"
                                    end
                                else
                                    -- No equipped item, show as new
                                    comparisonText = " " .. diffColor .. "(new)|r"
                                end
                            elseif compMode == "both" then
                                if equippedScore > 0 then
                                    local percent = (diff / equippedScore) * 100
                                    local percentText
                                    -- Use "HUGE!" for extreme percentages (>=1000% or <=-1000%)
                                    if math.abs(percent) >= 1000 then
                                        percentText = "HUGE!"
                                        comparisonText = " " .. diffColor .. "(" .. diffSign .. diffText .. ", " .. diffSign .. percentText .. ")|r"
                                    else
                                        percentText = string.format("%.1f", percent)
                                        comparisonText = " " .. diffColor .. "(" .. diffSign .. diffText .. ", " .. diffSign .. percentText .. "%)|r"
                                    end
                                else
                                    comparisonText = " " .. diffColor .. "(" .. diffSign .. diffText .. ", new)|r"
                                end
                            end
                        end
                        
                        -- Build final display text for single-slot items (skip if stat breakdown already shown)
                        if not ValuateOptions.showStatBreakdown then
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
                    else
                        -- No comparison mode or not equippable - just show the score (skip if stat breakdown already shown)
                        if not ValuateOptions.showStatBreakdown then
                            if ValuateOptions.rightAlign then
                                tooltip:AddDoubleLine(prefix .. "|cFF" .. color .. displayName .. "|r", "|cFF" .. color .. scoreText .. "|r")
                            else
                                tooltip:AddLine(prefix .. "|cFF" .. color .. displayName .. ": " .. scoreText .. "|r")
                            end
                        end
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
        if not itemLink then
            -- No item, reset border to default
            if DefaultTooltipBorderColor then
                self:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
            end
            return
        end
        
        -- Check if our lines are already present
        if HasValuateLines(self) then
            ValuateLinesAdded = true
            -- Don't return yet - still need to update border color
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
        
        -- Apply border coloring based on displayed scale
        if CurrentTooltipStats and next(CurrentTooltipStats) then
            -- Store default border color on first run
            if not DefaultTooltipBorderColor then
                local r, g, b, a = self:GetBackdropBorderColor()
                DefaultTooltipBorderColor = {r, g, b, a}
            end
            
            -- Get border color based on displayed scale
            local r, g, b = GetTooltipBorderColor(CurrentTooltipStats, itemLink)
            if r and g and b then
                self:SetBackdropBorderColor(r, g, b, 1)
            else
                -- No coloring needed, use default
                if DefaultTooltipBorderColor then
                    self:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
                end
            end
        end
    end)
    
    -- Clear state when tooltip hides
    GameTooltip:HookScript("OnHide", function(self)
        CurrentTooltipItem = nil
        CurrentTooltipStats = nil
        ValuateLinesAdded = false
        
        -- Reset border color to default
        if DefaultTooltipBorderColor then
            self:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
        end
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
    -- Shopping tooltips show equipped items - display ONLY equipped item's values (no comparison)
    local function UpdateShoppingTooltip(tooltipName)
        local tooltip = getglobal(tooltipName)
        if not tooltip then return end
        
        -- Skip if our lines are already present
        if HasValuateLines(tooltip) then return end
        
        -- Shopping tooltips show equipped items - display only equipped item's stats (no comparison)
        local equippedStats = Valuate:GetStatsFromDisplayedTooltip(tooltipName)
        if equippedStats and next(equippedStats) then
            -- Pass nil for itemLink to prevent comparison (this is the equipped item, not hovered)
            AddScoreLinesToTooltip(tooltip, equippedStats, nil)
            tooltip:Show()  -- Resize tooltip to fit new lines
        end
        
        -- Apply border coloring for shopping tooltips
        local shoppingItemLink = tooltip:GetItem()
        if shoppingItemLink and equippedStats then
            -- Store default border color on first run
            if not DefaultTooltipBorderColor then
                local r, g, b, a = tooltip:GetBackdropBorderColor()
                DefaultTooltipBorderColor = {r, g, b, a}
            end
            
            -- Get border color based on equipped item
            local r, g, b = GetTooltipBorderColor(equippedStats, shoppingItemLink)
            if r and g and b then
                tooltip:SetBackdropBorderColor(r, g, b, 1)
            else
                -- No coloring needed, use default
                if DefaultTooltipBorderColor then
                    tooltip:SetBackdropBorderColor(unpack(DefaultTooltipBorderColor))
                end
            end
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
    
    -- Hook EquipCompare's ComparisonTooltip frames (if EquipCompare addon is loaded)
    if ComparisonTooltip1 and ComparisonTooltip1.SetHyperlinkCompareItem then
        hooksecurefunc(ComparisonTooltip1, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip1")
        end)
    end
    if ComparisonTooltip2 and ComparisonTooltip2.SetHyperlinkCompareItem then
        hooksecurefunc(ComparisonTooltip2, "SetHyperlinkCompareItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip2")
        end)
    end
    
    if ComparisonTooltip1 then
        hooksecurefunc(ComparisonTooltip1, "SetInventoryItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip1")
        end)
    end
    if ComparisonTooltip2 then
        hooksecurefunc(ComparisonTooltip2, "SetInventoryItem", function(self, ...)
            UpdateShoppingTooltip("ComparisonTooltip2")
        end)
    end
end

-- ========================================
-- Tooltip Reset System
-- ========================================

--- Attempts to reset a single tooltip, causing Valuate scores to be recalculated
--- Similar to Pawn's PawnResetTooltip function, but handles Ascension's scaled stats
--- tooltipName: Name of the tooltip frame to reset (string)
--- Returns: true if successful, false/nil otherwise
local function ResetTooltip(tooltipName)
    local tooltip = getglobal(tooltipName)
    if not tooltip or not tooltip.IsShown or not tooltip:IsShown() or not tooltip.GetItem then 
        return false 
    end
    
    local _, itemLink = tooltip:GetItem()
    if not itemLink then 
        return false 
    end
    
    -- For GameTooltip and ShoppingTooltips, check if this is showing an equipped item
    -- If so, we need to use SetInventoryItem to preserve scaled stats
    local isEquippedItem = false
    local slotId = nil
    
    if tooltipName == "GameTooltip" or tooltipName == "ShoppingTooltip1" or tooltipName == "ShoppingTooltip2" then
        -- Check all equipment slots to see if this item is equipped
        for i = 1, 18 do
            if i ~= 4 then -- Skip shirt slot
                local equippedLink = GetInventoryItemLink("player", i)
                if equippedLink == itemLink then
                    isEquippedItem = true
                    slotId = i
                    break
                end
            end
        end
    end
    
    -- Force tooltip to refresh
    tooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
    
    if isEquippedItem and slotId then
        -- Use SetInventoryItem for equipped items to show SCALED stats
        tooltip:SetInventoryItem("player", slotId)
    else
        -- Use SetHyperlink for non-equipped items (shows base stats)
        tooltip:SetHyperlink(itemLink)
    end
    
    tooltip:Show()
    return true
end

--- Resets all visible tooltips to recalculate Valuate scores
--- This should be called whenever scale settings change (stat weights, visibility, etc.)
--- Similar to Pawn's PawnResetTooltips function
function Valuate:ResetTooltips()
    -- Reset main tooltip
    ResetTooltip("GameTooltip")
    
    -- Reset item ref tooltips (shift-click item links in chat)
    ResetTooltip("ItemRefTooltip")
    
    -- Reset shopping/comparison tooltips
    ResetTooltip("ShoppingTooltip1")
    ResetTooltip("ShoppingTooltip2")
    
    -- Reset AtlasLoot tooltip if it exists (addon compatibility)
    ResetTooltip("AtlasLootTooltip")
    
    -- Reset EquipCompare tooltips if they exist (addon compatibility)
    ResetTooltip("ComparisonTooltip1")
    ResetTooltip("ComparisonTooltip2")
    
    -- Refresh character window display if it exists
    if Valuate.RefreshCharacterWindowDisplay then
        Valuate:RefreshCharacterWindowDisplay()
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
    
    -- Calculate normalization factor if global normalize display is enabled
    local normalizeFactor = 1
    if ValuateOptions and ValuateOptions.normalizeDisplay then
        local maxWeight = 0
        for statName, weight in pairs(scaleValues) do
            local absWeight = math.abs(weight)
            if absWeight > maxWeight then
                maxWeight = absWeight
            end
        end
        if maxWeight > 0 then
            normalizeFactor = 1 / maxWeight
        end
    end
    
    -- Multiply each stat value by its weight (and normalize if enabled) and sum them
    for statName, statValue in pairs(stats) do
        local weight = scaleValues[statName]
        if weight and weight ~= 0 then
            total = total + (statValue * weight * normalizeFactor)
        end
    end
    
    return total
end

-- Calculate detailed breakdown of stat contributions for an item
-- stats: Table of stat values {Strength = 10, Stamina = 20, ...}
-- scale: Table of stat weights {Strength = 1.5, Stamina = 1.0, ...}
-- Returns: Table of stat contributions sorted by value (descending)
--   Each entry: {statName, statValue, weight, contribution}
function Valuate:CalculateStatBreakdown(stats, scale)
    if not stats or not scale or not scale.Values then
        return nil
    end
    
    local breakdown = {}
    local scaleValues = scale.Values
    
    -- Calculate normalization factor if global normalize display is enabled
    local normalizeFactor = 1
    if ValuateOptions and ValuateOptions.normalizeDisplay then
        local maxWeight = 0
        for statName, weight in pairs(scaleValues) do
            local absWeight = math.abs(weight)
            if absWeight > maxWeight then
                maxWeight = absWeight
            end
        end
        if maxWeight > 0 then
            normalizeFactor = 1 / maxWeight
        end
    end
    
    -- Calculate contribution for each stat
    for statName, statValue in pairs(stats) do
        local weight = scaleValues[statName]
        if weight and weight ~= 0 and statValue and statValue ~= 0 then
            local normalizedWeight = weight * normalizeFactor
            local contribution = statValue * normalizedWeight
            table.insert(breakdown, {
                statName = statName,
                statValue = statValue,
                weight = normalizedWeight,
                contribution = contribution
            })
        end
    end
    
    -- Sort by contribution (descending)
    table.sort(breakdown, function(a, b)
        return math.abs(a.contribution) > math.abs(b.contribution)
    end)
    
    return breakdown
end

-- Calculate detailed breakdown with comparison between two items
-- hoverStats: Stats of the item being hovered over
-- equippedStats: Stats of the equipped item to compare against
-- scale: Table of stat weights
-- Returns: Table of stat contributions with comparison data, sorted by hover contribution (descending)
--   Each entry: {statName, hoverValue, hoverWeight, hoverContribution, equippedValue, equippedContribution, diff, percentDiff}
function Valuate:CalculateStatBreakdownWithComparison(hoverStats, equippedStats, scale)
    if not hoverStats or not scale or not scale.Values then
        return nil
    end
    
    local breakdown = {}
    local scaleValues = scale.Values
    
    -- Calculate normalization factor if global normalize display is enabled
    local normalizeFactor = 1
    if ValuateOptions and ValuateOptions.normalizeDisplay then
        local maxWeight = 0
        for statName, weight in pairs(scaleValues) do
            local absWeight = math.abs(weight)
            if absWeight > maxWeight then
                maxWeight = absWeight
            end
        end
        if maxWeight > 0 then
            normalizeFactor = 1 / maxWeight
        end
    end
    
    -- Build union of all stat names from both items
    local allStats = {}
    for statName, _ in pairs(hoverStats) do
        allStats[statName] = true
    end
    if equippedStats then
        for statName, _ in pairs(equippedStats) do
            allStats[statName] = true
        end
    end
    
    -- Calculate contribution for each stat
    for statName, _ in pairs(allStats) do
        local weight = scaleValues[statName]
        if weight and weight ~= 0 then
            local hoverValue = hoverStats[statName] or 0
            local equippedValue = (equippedStats and equippedStats[statName]) or 0
            
            -- Only include if at least one item has this stat
            if hoverValue ~= 0 or equippedValue ~= 0 then
                local normalizedWeight = weight * normalizeFactor
                local hoverContribution = hoverValue * normalizedWeight
                local equippedContribution = equippedValue * normalizedWeight
                local diff = hoverContribution - equippedContribution
                
                local percentDiff = 0
                if equippedContribution ~= 0 then
                    percentDiff = (diff / math.abs(equippedContribution)) * 100
                elseif diff ~= 0 then
                    -- Equipped has 0, hover has something = infinite gain
                    percentDiff = (diff > 0) and 100 or -100
                end
                
                table.insert(breakdown, {
                    statName = statName,
                    hoverValue = hoverValue,
                    hoverWeight = normalizedWeight,
                    hoverContribution = hoverContribution,
                    equippedValue = equippedValue,
                    equippedContribution = equippedContribution,
                    diff = diff,
                    percentDiff = percentDiff
                })
            end
        end
    end
    
    -- Sort by hover contribution (descending)
    table.sort(breakdown, function(a, b)
        return math.abs(a.hoverContribution) > math.abs(b.hoverContribution)
    end)
    
    return breakdown
end

-- Gets individual scores for each equipped item in multi-slot types (rings, trinkets, weapons)
-- equipSlot: The equipment slot type (e.g., "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPON")
-- scale: The scale data table to use for scoring
-- Returns: Table with slot IDs as keys and scores as values, or nil if not a multi-slot type
function Valuate:GetEquippedItemScores(equipSlot, scale)
    local invSlots = EquipSlotToInvNumber[equipSlot]
    if not invSlots or #invSlots <= 1 then return nil end
    
    local scores = {}
    local tooltip = GetPrivateTooltip()
    
    for _, slotId in ipairs(invSlots) do
        local itemLink = GetInventoryItemLink("player", slotId)
        if itemLink then
            -- Get the equipped item's type
            local _, _, _, _, _, _, _, _, equippedEquipLoc = GetItemInfo(itemLink)
            
            -- Check if these item types should be compared
            local shouldCompare = true
            if equippedEquipLoc then
                shouldCompare = AreWeaponTypesComparable(equipSlot, equippedEquipLoc)
            end
            
            if shouldCompare then
                tooltip:ClearLines()
                tooltip:SetHyperlink(itemLink)
                local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
                if stats then
                    local score = Valuate:CalculateItemScore(stats, scale)
                    if score then
                        scores[slotId] = score
                    end
                end
            end
        end
    end
    
    return next(scores) and scores or nil
end

-- Gets the score of an equipped item in a specific inventory slot using SCALED stats
-- slotId: The inventory slot ID (1-18)
-- scale: The scale data table to use for scoring
-- Returns: The score for the item in that slot, or 0 if no item/no score
function Valuate:GetEquippedItemScoreBySlotId(slotId, scale)
    if not slotId or not scale or not scale.Values then
        return 0
    end
    
    local itemLink = GetInventoryItemLink("player", slotId)
    if not itemLink then
        return 0
    end
    
    local tooltip = GetPrivateTooltip()
    tooltip:ClearLines()
    -- Use SetInventoryItem to get SCALED stats (same as what's shown in tooltips)
    tooltip:SetInventoryItem("player", slotId)
    local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip")
    
    if stats then
        local score = Valuate:CalculateItemScore(stats, scale)
        return score or 0
    end
    
    return 0
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
            -- Get the equipped item's type
            local _, _, _, _, _, _, _, _, equippedEquipLoc = GetItemInfo(itemLink)
            
            -- Check if these item types should be compared
            local shouldCompare = true
            if equippedEquipLoc then
                shouldCompare = AreWeaponTypesComparable(equipSlot, equippedEquipLoc)
            end
            
            if shouldCompare then
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
    
    -- Get the item's equipment slot for banned stat checking
    local equipSlot = nil
    if tooltip then
        local itemLink = tooltip:GetItem()
        if itemLink then
            local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(itemLink)
            equipSlot = itemEquipLoc
        end
    end
    
    -- Calculate scores for each active scale
    local scores = {}
    for _, scaleName in ipairs(activeScales) do
        local scale = ValuateScales[scaleName]
        if scale then
            -- Check if item has any stats marked as unusable for this scale
            local hasUnusableStat = false
            if scale.Unusable then
                -- First check parsed stats
                for statName, statValue in pairs(stats) do
                    if scale.Unusable[statName] and statValue and statValue > 0 then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item has banned stat '" .. statName .. "'")
                        end
                        break
                    end
                end
                
                -- Also check equipment slot type directly (in case tooltip parsing missed weapon type)
                if not hasUnusableStat and equipSlot then
                    if equipSlot == "INVTYPE_2HWEAPON" and scale.Unusable["TwoHandDps"] then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is 2H weapon (banned by TwoHandDps)")
                        end
                    elseif equipSlot == "INVTYPE_WEAPONOFFHAND" and scale.Unusable["OffHandDps"] then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is offhand weapon (banned by OffHandDps)")
                        end
                    elseif (equipSlot == "INVTYPE_RANGED" or equipSlot == "INVTYPE_RANGEDRIGHT" or equipSlot == "INVTYPE_THROWN") and scale.Unusable["RangedDps"] then
                        hasUnusableStat = true
                        if ValuateOptions.debug then
                            print("|cFFFF8800[Valuate Debug]|r Scale '" .. scaleName .. "' skipped: item is ranged weapon (banned by RangedDps)")
                        end
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


