-- ImportExport.lua
-- Scale import/export functionality for Valuate

-- ========================================
-- Constants
-- ========================================

-- Current scale tag format version
local SCALE_TAG_VERSION = 1

-- Import result status codes
Valuate.ImportResult = {
    SUCCESS = 1,
    ALREADY_EXISTS = 2,
    TAG_ERROR = 3,
    VERSION_ERROR = 4,
}

-- ========================================
-- Export Functions
-- ========================================

-- Generates an export string (scale tag) for a scale
-- scaleName: Internal scale name (key in Valuate.db.profile.Scales)
-- Returns: Scale tag string, or nil if scale doesn't exist
function Valuate:GetScaleTag(scaleName)
    if not scaleName or scaleName == "" then
        return nil
    end
    
    local scale = self.db.profile.Scales[scaleName]
    if not scale then
        return nil
    end
    
    -- Start building the tag: {Valuate:v1:ScaleName{...}}
    local displayName = scale.DisplayName or scaleName
    local tag = string.format("{Valuate:v%d:%s{", SCALE_TAG_VERSION, displayName)
    
    local parts = {}
    
    -- Add Color (required, default to white if missing)
    local color = scale.Color or "FFFFFF"
    table.insert(parts, string.format("Color=%s", color))
    
    -- Add Visible flag (0 or 1)
    local visible = (scale.Visible ~= false) and 1 or 0
    table.insert(parts, string.format("Visible=%d", visible))
    
    -- Add Icon path if present
    if scale.Icon and scale.Icon ~= "" then
        table.insert(parts, string.format("Icon=%s", scale.Icon))
    end
    
    -- Add stat weights (skip zero values)
    if scale.Values then
        -- Sort stat names for consistent output
        local statNames = {}
        for statName, _ in pairs(scale.Values) do
            table.insert(statNames, statName)
        end
        table.sort(statNames)
        
        for _, statName in ipairs(statNames) do
            local value = scale.Values[statName]
            if value and value ~= 0 then
                table.insert(parts, string.format("%s=%s", statName, tostring(value)))
            end
        end
    end
    
    -- Add Unusable stats (banned stats)
    if scale.Unusable then
        local unusableNames = {}
        for statName, _ in pairs(scale.Unusable) do
            table.insert(unusableNames, statName)
        end
        table.sort(unusableNames)
        
        for _, statName in ipairs(unusableNames) do
            if scale.Unusable[statName] then
                table.insert(parts, string.format("Unusable.%s=1", statName))
            end
        end
    end
    
    -- Concatenate all parts with commas
    tag = tag .. table.concat(parts, ",")
    
    -- Close the tag
    tag = tag .. "}}"
    
    return tag
end

-- Exports all scales as a series of scale tags
-- Returns: String containing all scale tags separated by spaces
function Valuate:ExportAllScales()
    local tags = {}
    
    -- Get all scale names and sort them
    local scaleNames = {}
    for scaleName, _ in pairs(self.db.profile.Scales) do
        table.insert(scaleNames, scaleName)
    end
    table.sort(scaleNames)
    
    -- Generate tag for each scale
    for _, scaleName in ipairs(scaleNames) do
        local tag = self:GetScaleTag(scaleName)
        if tag then
            table.insert(tags, tag)
        end
    end
    
    -- Join with double space for readability
    return table.concat(tags, "  ")
end

-- ========================================
-- Import Functions
-- ========================================

-- Parses a scale tag and extracts the scale data
-- scaleTag: The import string
-- Returns: scaleName, scaleData, errorMessage, versionMessage
function Valuate:ParseScaleTag(scaleTag)
    if not scaleTag or type(scaleTag) ~= "string" then
        return nil, nil, "Invalid input: scale tag must be a non-empty string"
    end
    
    -- Trim whitespace
    scaleTag = strtrim(scaleTag)
    
    if scaleTag == "" then
        return nil, nil, "Invalid input: scale tag must be a non-empty string"
    end
    
    -- Parse the outer structure: {Valuate:v1:ScaleName{props}}
    local version, scaleName, propsString = string.match(scaleTag, "^{Valuate:v(%d+):([^{]+){(.+)}}$")
    
    if not version or not scaleName or not propsString then
        return nil, nil, "Invalid format: scale tag must be in format {Valuate:v1:Name{props}}"
    end
    
    version = tonumber(version)
    if not version then
        return nil, nil, "Invalid version number in scale tag"
    end
    
    -- Trim scale name
    scaleName = strtrim(scaleName)
    if scaleName == "" then
        return nil, nil, "Scale name cannot be empty"
    end
    
    -- Check version compatibility
    if version > SCALE_TAG_VERSION then
        -- Future version - we might not be able to parse it correctly
        return nil, nil, "This scale tag is from a newer version of Valuate (v" .. version .. "). Please update the addon.", version
    end
    
    -- Parse the properties string (key=value pairs separated by commas)
    local scaleData = {
        DisplayName = scaleName,
        Values = {},
        Unusable = {},
    }
    
    -- Split by commas, but need to handle icon paths that might contain commas
    -- We'll use a simple state machine approach
    local currentPos = 1
    while currentPos <= #propsString do
        -- Find the next key=value pair
        local keyStart, keyEnd, key, value
        
        -- Match pattern: Key=Value (where Value can contain backslashes for paths)
        -- Look for the equals sign
        local equalsPos = string.find(propsString, "=", currentPos, true)
        if not equalsPos then
            break
        end
        
        -- Extract key (everything before =)
        key = string.sub(propsString, currentPos, equalsPos - 1)
        key = strtrim(key)
        
        -- Extract value (everything until next comma or end)
        -- Special handling: if key is "Icon", value might have backslashes and go until next stat name pattern
        local valueStart = equalsPos + 1
        local valueEnd
        
        if key == "Icon" then
            -- Icon path - look for the next comma followed by a known key pattern
            -- Try to find ", followed by a capital letter (start of next key)
            valueEnd = string.find(propsString, ",[A-Z]", valueStart)
            if valueEnd then
                valueEnd = valueEnd - 1  -- Don't include the comma
            else
                valueEnd = #propsString  -- Go to end
            end
        else
            -- Regular value - find next comma
            valueEnd = string.find(propsString, ",", valueStart, true)
            if valueEnd then
                valueEnd = valueEnd - 1
            else
                valueEnd = #propsString
            end
        end
        
        value = string.sub(propsString, valueStart, valueEnd)
        value = strtrim(value)
        
        -- Process the key=value pair
        if key and value and key ~= "" and value ~= "" then
            if key == "Color" then
                scaleData.Color = value
            elseif key == "Visible" then
                scaleData.Visible = (tonumber(value) == 1)
            elseif key == "Icon" then
                scaleData.Icon = value
            elseif string.match(key, "^Unusable%.(.+)$") then
                -- Unusable stat (e.g., "Unusable.Intellect")
                local statName = string.match(key, "^Unusable%.(.+)$")
                if statName then
                    scaleData.Unusable[statName] = true
                end
            else
                -- Regular stat weight
                local numValue = tonumber(value)
                if numValue then
                    scaleData.Values[key] = numValue
                end
            end
        end
        
        -- Move to next key=value pair
        currentPos = valueEnd + 2  -- Skip comma
        if currentPos > #propsString then
            break
        end
    end
    
    -- Validate that we got at least some data
    if not next(scaleData.Values) then
        -- No stat values found
        return nil, nil, "No valid stat values found in scale tag"
    end
    
    -- Clean up empty Unusable table
    if not next(scaleData.Unusable) then
        scaleData.Unusable = nil
    end
    
    return scaleName, scaleData, nil, nil
end

-- Imports a scale from a scale tag
-- scaleTag: The import string
-- overwrite: If true, overwrite existing scale with same name; if false, fail if exists
-- Returns: status, scaleName, errorMessage
--   status: One of Valuate.ImportResult.*
--   scaleName: The name of the imported scale
--   errorMessage: Detailed error message if import failed
function Valuate:ImportScale(scaleTag, overwrite)
    local scaleName, scaleData, errorMessage, versionMessage = self:ParseScaleTag(scaleTag)
    
    if not scaleName then
        if versionMessage then
            return Valuate.ImportResult.VERSION_ERROR, nil, errorMessage
        else
            return Valuate.ImportResult.TAG_ERROR, nil, errorMessage
        end
    end
    
    -- Check if scale already exists
    local alreadyExists = (self.db.profile.Scales[scaleName] ~= nil)
    
    if alreadyExists and not overwrite then
        return Valuate.ImportResult.ALREADY_EXISTS, scaleName, nil
    end
    
    -- Import the scale
    self.db.profile.Scales[scaleName] = scaleData
    
    -- If the UI is loaded, refresh it
    if Valuate.RefreshScaleList then
        Valuate:RefreshScaleList()
    end
    
    if Valuate.RefreshStatEditor then
        Valuate:RefreshStatEditor()
    end
    
    return Valuate.ImportResult.SUCCESS, scaleName, nil
end

-- Parses multiple scale tags from a single string
-- text: String containing one or more scale tags
-- Returns: array of {scaleName, scaleData}, array of {error, tag}
function Valuate:ParseMultipleScaleTags(text)
    if not text or type(text) ~= "string" then
        return {}, {}
    end
    
    local parsedScales = {}
    local errors = {}
    
    -- Extract all scale tags using pattern matching
    -- Pattern: {Valuate:...}
    for scaleTag in string.gmatch(text, "{Valuate:[^}]+}}") do
        local scaleName, scaleData, errorMessage, versionMessage = self:ParseScaleTag(scaleTag)
        
        if scaleName and scaleData then
            table.insert(parsedScales, {
                name = scaleName,
                data = scaleData,
                tag = scaleTag
            })
        else
            table.insert(errors, {
                error = errorMessage or "Unknown error",
                tag = scaleTag
            })
        end
    end
    
    return parsedScales, errors
end

-- Imports multiple scales from a string containing multiple scale tags
-- text: String containing one or more scale tags
-- overwrite: If true, overwrite existing scales; if false, return list of conflicts
-- Returns: successCount, failCount, existingScales (array of scale names that exist)
function Valuate:ImportMultipleScales(text, overwrite)
    local parsedScales, errors = self:ParseMultipleScaleTags(text)
    
    local successCount = 0
    local failCount = #errors
    local existingScales = {}
    
    -- First pass: check for existing scales if not overwriting
    if not overwrite then
        for _, parsed in ipairs(parsedScales) do
            if self.db.profile.Scales[parsed.name] then
                table.insert(existingScales, parsed.name)
            end
        end
        
        -- If there are existing scales, return without importing
        if #existingScales > 0 then
            return 0, 0, existingScales
        end
    end
    
    -- Second pass: import all scales
    for _, parsed in ipairs(parsedScales) do
        self.db.profile.Scales[parsed.name] = parsed.data
        successCount = successCount + 1
    end
    
    -- Refresh UI once at the end
    if successCount > 0 then
        if Valuate.RefreshScaleList then
            Valuate:RefreshScaleList()
        end
        
        if Valuate.RefreshStatEditor then
            Valuate:RefreshStatEditor()
        end
    end
    
    return successCount, failCount, existingScales
end

