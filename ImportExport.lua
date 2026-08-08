-- ImportExport.lua
-- Scale import/export functionality for Valuate

-- ========================================
-- Constants
-- ========================================

-- Current scale tag format version
-- v2 added weapon-set configuration (WeaponSet.<key>, ActiveWeaponSet).
-- Bumped so an older Valuate rejects the tag with a clear "update the addon" message
-- instead of silently importing "WeaponSet.TwoHand=1" as a bogus stat weight.
-- Older (v1) tags still import into this version - only NEWER tags are refused.
local SCALE_TAG_VERSION = 2

-- Import result status codes
Valuate.ImportResult = {
    SUCCESS = 1,
    ALREADY_EXISTS = 2,
    TAG_ERROR = 3,
    VERSION_ERROR = 4,
}

-- The scale tag is delimited by { } and Valuate's chat output uses |, so a display
-- name containing any of the three cannot appear in a tag unescaped.
--
-- This lives in ONE place because the producer and the consumer disagreed for as long
-- as it lived in two - which is to say, only the parser enforced it, and the exporter
-- happily wrote tags the parser then refused. Depending on the character, the result
-- was either a confusing rejection of Valuate's OWN output, or worse: a name
-- containing "{" parsed as a silently TRUNCATED name, so exporting "My{Scale" and
-- importing it produced a scale called "My" with no error at all.
--
-- Returns ok, reason.
function Valuate:IsValidScaleTagName(name)
    if type(name) ~= "string" or strtrim(name) == "" then
        return false, "Scale name cannot be empty"
    end
    if string.match(name, "[{}|]") then
        return false, "Scale name cannot contain '{', '}', or '|' characters"
    end
    return true
end

-- ========================================
-- Export Functions
-- ========================================

-- Generates an export string (scale tag) for a scale
-- scaleName: Internal scale name (key in scales table)
-- Returns: Scale tag string, or nil if scale doesn't exist
function Valuate:GetScaleTag(scaleName)
    if not scaleName or scaleName == "" then
        return nil
    end
    
    local scales = Valuate:GetScales()
    local scale = scales[scaleName]
    if not scale then
        return nil
    end
    
    -- Start building the tag: {Valuate:v1:ScaleName{...}}
    local displayName = scale.DisplayName or scaleName

    -- Refuse rather than emit a tag we cannot read back. Handing someone a tag that
    -- this very addon rejects is the worst outcome available: the error they get
    -- blames the tag's FORMAT, with nothing pointing at the name.
    local nameOk, nameReason = Valuate:IsValidScaleTagName(displayName)
    if not nameOk then
        return nil, nameReason .. " - rename '" .. tostring(displayName) .. "' before exporting it"
    end
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
    
    -- Add weapon-set configuration. A scale with no WeaponSets table means "all
    -- enabled", so only an explicit table is exported - that way an older scale keeps
    -- its implicit default instead of being frozen into whatever it resolved to.
    if scale.WeaponSets then
        local defs = Valuate.GetWeaponSetDefinitions and Valuate:GetWeaponSetDefinitions()
        if defs then
            for _, def in ipairs(defs) do
                table.insert(parts, string.format("WeaponSet.%s=%d",
                    def.key, scale.WeaponSets[def.key] and 1 or 0))
            end
        end
    end
    if scale.ActiveWeaponSet and scale.ActiveWeaponSet ~= "" then
        table.insert(parts, string.format("ActiveWeaponSet=%s", scale.ActiveWeaponSet))
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
    local scales = Valuate:GetScales()
    for scaleName, _ in pairs(scales) do
        table.insert(scaleNames, scaleName)
    end
    table.sort(scaleNames)
    
    -- Generate tag for each scale.
    --
    -- A scale that cannot be exported is REPORTED, not quietly dropped. Silently
    -- returning nine tags when you have ten is the same silent-loss failure this
    -- whole area was fixed for - and "export everything" is exactly when nobody
    -- counts the results.
    local skipped = {}
    for _, scaleName in ipairs(scaleNames) do
        local tag, why = self:GetScaleTag(scaleName)
        if tag then
            table.insert(tags, tag)
        else
            table.insert(skipped, { name = scaleName, reason = why })
        end
    end

    for _, s in ipairs(skipped) do
        print("|cFFFF8800Valuate|r: skipped '" .. s.name .. "' - " ..
            (s.reason or "could not be exported"))
    end

    -- Join with double space for readability
    return table.concat(tags, "  "), skipped
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
    
    -- Trim scale name, then apply the SAME rule the exporter applies. Shared so the
    -- two cannot drift: this check existing only here is what let the exporter emit
    -- tags this parser refuses.
    scaleName = strtrim(scaleName)
    local nameOk, nameReason = Valuate:IsValidScaleTagName(scaleName)
    if not nameOk then
        return nil, nil, nameReason
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
            -- Icon path - look for the next comma followed by a key=value pattern
            -- Pattern: ",KeyName=" where KeyName doesn't contain backslashes (stat names don't have them)
            -- This correctly handles icon paths with capital letters like "Interface\Icons\INV_Sword_04"
            local nextKeyStart = string.find(propsString, ",([^\\,=]+)=", valueStart)
            if nextKeyStart then
                valueEnd = nextKeyStart - 1  -- Don't include the comma
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
            elseif key == "ActiveWeaponSet" then
                scaleData.ActiveWeaponSet = value
            else
                -- Check if this is an Unusable stat (e.g., "Unusable.Intellect")
                local statName = string.match(key, "^Unusable%.(.+)$")
                if statName and statName ~= "" then
                    scaleData.Unusable[statName] = true
                else
                    -- Weapon-set toggle, e.g. "WeaponSet.TwoHand=1". Only create the
                    -- table when the tag actually carries one, so a tag without them
                    -- keeps the "nil = all enabled" default rather than importing as
                    -- all-disabled.
                    local wsKey = string.match(key, "^WeaponSet%.(.+)$")
                    if wsKey and wsKey ~= "" then
                        scaleData.WeaponSets = scaleData.WeaponSets or {}
                        scaleData.WeaponSets[wsKey] = (tonumber(value) == 1) or nil
                    else
                        -- Regular stat weight
                        local numValue = tonumber(value)
                        if numValue then
                            scaleData.Values[key] = numValue
                        end
                    end
                end
            end
        end
        
        -- Move to next key=value pair
        -- Skip comma (valueEnd points to the last char of value, so +2 skips comma and space)
        currentPos = valueEnd + 2
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
    local scales = Valuate:GetScales()
    local alreadyExists = (scales[scaleName] ~= nil)
    
    if alreadyExists and not overwrite then
        return Valuate.ImportResult.ALREADY_EXISTS, scaleName, nil
    end
    
    -- Import the scale
    scales[scaleName] = scaleData
    
    -- If the UI is loaded, refresh it
    if Valuate.RefreshScaleList then
        Valuate:RefreshScaleList()
    end
    
    if Valuate.RefreshStatEditor then
        Valuate:RefreshStatEditor()
    end
    
    -- Reset all tooltips to show the new/updated scale immediately
    if Valuate.ResetTooltips then
        Valuate:ResetTooltips()
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
        local scales = Valuate:GetScales()
        for _, parsed in ipairs(parsedScales) do
            if scales[parsed.name] then
                table.insert(existingScales, parsed.name)
            end
        end
        
        -- If there are existing scales, return without importing
        if #existingScales > 0 then
            return 0, 0, existingScales
        end
    end
    
    -- Second pass: import all scales
    local scales = Valuate:GetScales()
    for _, parsed in ipairs(parsedScales) do
        scales[parsed.name] = parsed.data
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
        
        -- Reset all tooltips to show the new/updated scales immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end
    
    return successCount, failCount, existingScales
end


-- ============================================================================
-- Scale library (shared across all your characters)
-- ============================================================================
-- Scales are SavedVariablesPerCharacter, so every new character starts with none
-- and the only way to move one was to export a tag, write it down, and paste it
-- back. The library is a small ACCOUNT-WIDE store that removes that chore.
--
-- It holds scale TAGS, not scale tables. That reuses GetScaleTag/ImportScale
-- wholesale - the same serialisation the export box uses, already handling the v2
-- weapon-set fields - so the library can never drift from what a pasted tag does,
-- and there is no second format to keep in step.

function Valuate:GetScaleLibrary()
    if not ValuateScaleLibrary then ValuateScaleLibrary = {} end
    return ValuateScaleLibrary
end

-- Stores a scale under its display name. Returns true, entryName - or false, err.
function Valuate:SaveScaleToLibrary(scaleName)
    if not scaleName then return false, "no scale given" end
    local scale = Valuate:GetScales()[scaleName]
    if not scale then return false, "no such scale on this character" end

    local tag, why = Valuate:GetScaleTag(scaleName)
    -- Pass the reason through. "couldn't serialise that scale" is unactionable when
    -- the actual problem is a brace in the name, which the user can simply fix.
    if not tag or tag == "" then return false, why or "couldn't serialise that scale" end

    local entryName = scale.DisplayName or scaleName
    Valuate:GetScaleLibrary()[entryName] = tag
    return true, entryName
end

-- Copies a library entry onto THIS character. overwrite mirrors ImportScale.
-- Returns ok, messageOrScaleName.
--
-- ImportScale returns (resultCode, scaleName, errorMessage), and EVERY code is a
-- truthy number - SUCCESS is 1, TAG_ERROR is 3. Returning it straight through would
-- make callers read a failure as success, so the translation happens here, once.
function Valuate:LoadScaleFromLibrary(entryName, overwrite)
    if not entryName then return false, "no entry given" end
    local tag = Valuate:GetScaleLibrary()[entryName]
    if not tag then return false, "no library entry called '" .. tostring(entryName) .. "'" end

    local status, scaleName, errorMessage = Valuate:ImportScale(tag, overwrite)
    if status == Valuate.ImportResult.SUCCESS then
        return true, scaleName
    elseif status == Valuate.ImportResult.ALREADY_EXISTS then
        return false, "'" .. tostring(scaleName) .. "' already exists on this character"
    end
    return false, errorMessage or "the stored tag could not be read"
end

function Valuate:DeleteScaleFromLibrary(entryName)
    if not entryName then return false end
    local lib = Valuate:GetScaleLibrary()
    if lib[entryName] == nil then return false end
    lib[entryName] = nil
    return true
end

-- Sorted for stable output: pairs() order is undefined, and a list that reshuffles
-- between calls is needlessly hard to read.
function Valuate:ListScaleLibrary()
    local names = {}
    for name in pairs(Valuate:GetScaleLibrary()) do names[#names + 1] = name end
    table.sort(names)
    return names
end
