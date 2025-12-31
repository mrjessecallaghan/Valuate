-- Valuate - Stat Weight Calculator for WoW Ascension Bronzebeard
-- Version: 0.2.0
-- Interface: 30300 (WotLK 3.3.5a)

-- Addon namespace
Valuate = {}

-- Version info
Valuate.version = "0.2.0"
Valuate.interface = 30300

-- Initialize saved variables
ValuateDB = ValuateDB or {}
ValuateOptions = ValuateOptions or {}
ValuateScales = ValuateScales or {}

-- Default options (set defaults before using them)
if not ValuateOptions.cacheSize then
    ValuateOptions.cacheSize = 150  -- Max number of items to cache
end
if ValuateOptions.debug == nil then
    ValuateOptions.debug = false
end
if ValuateOptions.decimalPlaces == nil then
    ValuateOptions.decimalPlaces = 1  -- Number of decimal places for scores
end
if ValuateOptions.rightAlign == nil then
    ValuateOptions.rightAlign = false  -- Right-align scores in tooltip
end

-- Item cache (LRU - Least Recently Used)
-- Array of cached items, with newest items at the end
local ItemCache = {}

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
    -- Basic initialization
    print("|cFF00FF00Valuate|r loaded (v" .. self.version .. ")")
    
    -- Ensure options are set (in case they weren't loaded properly)
    if not ValuateOptions.cacheSize then
        ValuateOptions.cacheSize = 150
    end
    if ValuateOptions.debug == nil then
        ValuateOptions.debug = false
    end
    
    -- Initialize scales if empty
    if not ValuateScales then
        ValuateScales = {}
    end
    
    -- Verify stat patterns loaded
    if not ValuateStatPatterns then
        print("|cFFFF0000Valuate|r: ERROR - StatDefinitions.lua failed to load!")
    end
    
    -- Clear cache on load (fresh start each session)
    Valuate:ClearCache()
    
    -- Hook into tooltips to parse scaled stats
    Valuate:HookTooltips()
    
    -- Create a default scale if none exist
    if not next(ValuateScales) then
        Valuate:CreateDefaultScale()
    end
end

-- Creates a simple default scale for testing
function Valuate:CreateDefaultScale()
    local defaultScale = {
        DisplayName = "Default",
        Color = "00FF00",
        Visible = true,
        Values = {
            Strength = 1.0,
            Agility = 1.0,
            Stamina = 1.0,
            Intellect = 1.0,
            Spirit = 1.0,
            AttackPower = 1.0,
            HitRating = 1.0,
            CritRating = 1.0,
            HasteRating = 1.0,
            ExpertiseRating = 1.0,
            DefenseRating = 1.0,
            DodgeRating = 1.0,
            ParryRating = 1.0,
            BlockRating = 1.0,
            ResilienceRating = 1.0,
            SpellPower = 1.0,
            Armor = 0.1,
            DPS = 10.0,
            BlockValue = 1.0,
            PVEPower = 1.0,
            PVPPower = 1.0,
        }
    }
    
    ValuateScales["Default"] = defaultScale
end

-- ========================================
-- Item Cache System (Performance Foundation)
-- ========================================

-- Creates an empty cached item structure
function Valuate:CreateEmptyCachedItem(itemLink, itemName)
    return {
        Link = itemLink,
        Name = itemName,
        Stats = {},  -- Parsed stats table
        -- Future: Add more fields as needed (Rarity, Level, ID, etc.)
    }
end

-- Searches the cache for an item by link or name
-- Returns cached item if found, nil otherwise
function Valuate:GetCachedItem(itemLink, itemName)
    -- Cache disabled in debug mode
    if ValuateOptions.debug then
        return nil
    end
    
    -- Cache empty, nothing to find
    if not ItemCache or #ItemCache == 0 then
        return nil
    end
    
    -- Search cache (newest items are at the end, so search backwards for efficiency)
    for i = #ItemCache, 1, -1 do
        local cached = ItemCache[i]
        if cached then
            -- Match by link first (most reliable)
            if itemLink and cached.Link and itemLink == cached.Link then
                -- Move to end (mark as recently used) and return
                tremove(ItemCache, i)
                tinsert(ItemCache, cached)
                return cached
            -- Fall back to name match
            elseif itemName and cached.Name and itemName == cached.Name then
                tremove(ItemCache, i)
                tinsert(ItemCache, cached)
                return cached
            end
        end
    end
    
    return nil
end

-- Adds an item to the cache (LRU - adds to end, removes from front if needed)
function Valuate:CacheItem(item)
    -- Cache disabled in debug mode or if item is invalid
    if ValuateOptions.debug or not item then
        return
    end
    
    -- Get cache size (always read from options to ensure it's current)
    local maxSize = ValuateOptions.cacheSize or 150
    
    -- Cache size of 0 or less means caching is disabled
    if maxSize <= 0 then
        return
    end
    
    -- Ensure cache exists
    if not ItemCache then
        ItemCache = {}
    end
    
    -- Add to end (most recently used)
    tinsert(ItemCache, item)
    
    -- Remove oldest items if cache exceeds max size
    while #ItemCache > maxSize do
        tremove(ItemCache, 1)  -- Remove from front (oldest)
    end
end

-- Clears the entire item cache
function Valuate:ClearCache()
    ItemCache = {}
end

-- Gets cache statistics (for debugging/testing)
function Valuate:GetCacheStats()
    local maxSize = ValuateOptions.cacheSize or 150
    return {
        size = ItemCache and #ItemCache or 0,
        maxSize = maxSize,
        enabled = maxSize > 0 and not (ValuateOptions.debug == true)
    }
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
    
    -- Iterate through all tooltip lines
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
    
    return stats
end

-- Gets stats for an item link by parsing its tooltip
-- Returns a stats table, or nil if parsing fails
-- Note: For scaled items, this reads the base item stats, not scaled values
-- Scaled values are only available when reading from the actual displayed tooltip
function Valuate:GetStatsForItemLink(itemLink, useCache)
    if not itemLink then
        return nil
    end
    
    -- Check cache first (unless explicitly disabled)
    if useCache ~= false then
        local cached = Valuate:GetCachedItem(itemLink, nil)
        if cached and cached.Stats then
            return cached.Stats
        end
    end
    
    -- Parse tooltip from the item link
    -- Note: SetHyperlink uses base item data, not scaled values
    local tooltip = GetPrivateTooltip()
    tooltip:ClearLines()
    tooltip:SetHyperlink(itemLink)
    
    -- Parse the tooltip (note: this will show base stats, not scaled stats)
    local stats = Valuate:ParseStatsFromTooltip("ValuatePrivateTooltip", ValuateOptions.debug)
    
    -- Cache the result if we got stats and caching is enabled
    if stats and useCache ~= false then
        local cached = Valuate:GetCachedItem(itemLink, nil)
        if not cached then
            cached = Valuate:CreateEmptyCachedItem(itemLink, nil)
        end
        cached.Stats = stats
        Valuate:CacheItem(cached)
    end
    
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

-- Check if our Valuate lines are present in the tooltip
local function HasValuateLines(tooltip)
    if not tooltip then return false end
    local numLines = tooltip:NumLines()
    for i = 1, numLines do
        local leftText = getglobal(tooltip:GetName() .. "TextLeft" .. i)
        if leftText then
            local text = leftText:GetText()
            if text and text:find("Valuate:") then
                return true
            end
        end
    end
    return false
end

-- Add score lines to tooltip
local function AddScoreLinesToTooltip(tooltip, stats)
    if not tooltip or not stats then return end
    
    -- Get active scales
    local activeScales = Valuate:GetActiveScales()
    if #activeScales == 0 then return end
    
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
                    
                    if ValuateOptions.rightAlign then
                        -- Use AddDoubleLine for right-aligned scores
                        tooltip:AddDoubleLine("|cFFFFFFFFValuate:|r |cFF" .. color .. displayName .. "|r", "|cFF" .. color .. scoreText .. "|r")
                    else
                        tooltip:AddLine("|cFFFFFFFFValuate:|r |cFF" .. color .. displayName .. ": " .. scoreText .. "|r")
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
            AddScoreLinesToTooltip(self, CurrentTooltipStats)
            ValuateLinesAdded = true
        end
    end)
    
    -- Clear state when tooltip hides
    GameTooltip:HookScript("OnHide", function(self)
        CurrentTooltipItem = nil
        CurrentTooltipStats = nil
        ValuateLinesAdded = false
    end)
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
    
    if command == "" or command == "help" then
        print("|cFF00FF00Valuate|r - Stat Weight Calculator")
        print("Commands:")
        print("  /valuate or /val - Show this help")
        print("  /valuate version - Show version info")
        print("  /valuate cache - Show cache statistics")
        print("  /valuate clearcache - Clear the item cache")
        print("  /valuate test [itemlink] - Test parsing an item (shift-click item to link)")
        print("  /valuate debug - Toggle debug mode (shows tooltip text being parsed)")
        print("  /valuate scales - List all stat weight scales")
        print("  /valuate ui - Open the configuration UI")
    elseif command == "version" then
        print("|cFF00FF00Valuate|r version " .. Valuate.version .. " (Interface " .. Valuate.interface .. ")")
    elseif command == "cache" then
        local stats = Valuate:GetCacheStats()
        print("|cFF00FF00Valuate|r Cache Statistics:")
        print("  Size: " .. stats.size .. " / " .. stats.maxSize)
        print("  Status: " .. (stats.enabled and "|cFF00FF00Enabled|r" or "|cFFFF0000Disabled|r"))
    elseif command == "clearcache" then
        Valuate:ClearCache()
        print("|cFF00FF00Valuate|r: Item cache cleared.")
    elseif strsub(command, 1, 4) == "test" then
        local itemLink = strsub(command, 6)
        if itemLink and itemLink ~= "" then
            -- Temporarily enable debug for test command
            local oldDebug = ValuateOptions.debug
            ValuateOptions.debug = true
            -- Parse without cache to get fresh data
            local stats = Valuate:GetStatsForItemLink(itemLink, false)
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
    elseif command == "ui" then
        Valuate:ToggleUI()
    else
        print("|cFF00FF00Valuate|r: Unknown command. Type /valuate help for available commands.")
    end
end

