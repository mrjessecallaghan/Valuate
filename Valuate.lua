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
    
    -- Clear cache on load (fresh start each session)
    Valuate:ClearCache()
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
    else
        print("|cFF00FF00Valuate|r: Unknown command. Type /valuate help for available commands.")
    end
end

