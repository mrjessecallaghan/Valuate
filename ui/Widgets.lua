-- ui/Widgets.lua
-- Reusable, stateless UI building blocks: input validation, colour conversion, the
-- standard styled button, and the drag-aware tooltip helper.
--
-- Everything here is a pure function (or builds a fresh frame), so consumers
-- re-localise them (`local CreateStyledButton = ns.CreateStyledButton`) and every
-- existing call site keeps working unchanged.

local _, ns = ...

local COLORS = ns.COLORS
local MOTION = ns.MOTION
local BACKDROP_BUTTON = ns.BACKDROP_BUTTON
local BUTTON_HEIGHT = ns.BUTTON_HEIGHT
local FONT_BODY = ns.FONT_BODY
-- From ui/Animations.lua (loaded before this file) - drives the button hover fade.
local TweenBackdrop = ns.TweenBackdrop
local Anim = ns.Anim

-- Validates and cleans numeric stat value input
-- Allows: up to 5 digits, one decimal point, minus sign at start only
-- Returns: cleaned string that meets validation rules
local function ValidateStatValueInput(text)
    if not text or text == "" then return "" end
    
    -- Allow lone minus sign temporarily (for better UX when typing)
    if text == "-" then return "-" end
    
    -- Check if starts with minus
    local hasNegative = text:sub(1, 1) == "-"
    local workingText = hasNegative and text:sub(2) or text
    
    -- Remove all invalid characters (keep only digits and one decimal)
    local cleaned = ""
    local decimalCount = 0
    local digitCount = 0
    
    for i = 1, #workingText do
        local char = workingText:sub(i, i)
        
        if char == "." then
            -- Only allow one decimal point
            if decimalCount == 0 then
                cleaned = cleaned .. char
                decimalCount = decimalCount + 1
            end
        elseif char:match("%d") then
            -- Only allow up to 5 digits total
            if digitCount < 5 then
                cleaned = cleaned .. char
                digitCount = digitCount + 1
            end
        end
        -- Silently skip any other characters
    end
    
    -- Prevent malformed inputs like ".", ".5" without leading zero is ok, but lone "." is not
    if cleaned == "." then
        cleaned = ""
    end
    
    -- Add back negative sign if it was present
    if hasNegative and cleaned ~= "" then
        cleaned = "-" .. cleaned
    end
    
    return cleaned
end

-- Validates whole number input (for decimal places setting)
-- Allows: only digits 0-9, no decimals or signs
-- Returns: cleaned string with only digits
local function ValidateWholeNumberInput(text)
    if not text or text == "" then return "" end
    
    -- Remove all non-digit characters
    local cleaned = text:gsub("[^0-9]", "")
    
    return cleaned
end

-- Applies validation to an EditBox for stat values
local function ApplyStatValueValidation(editBox)
    -- Intercept text changes (handles both typing and pasting)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            local validText = ValidateStatValueInput(text)
            
            if text ~= validText then
                local cursorPos = self:GetCursorPosition()
                self:SetText(validText)
                -- Adjust cursor position to stay at roughly the same place
                self:SetCursorPosition(math.min(cursorPos, #validText))
            end
        end
    end)
end

-- Applies validation to an EditBox for whole numbers
local function ApplyWholeNumberValidation(editBox)
    -- Intercept text changes (handles both typing and pasting)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            local validText = ValidateWholeNumberInput(text)
            
            if text ~= validText then
                local cursorPos = self:GetCursorPosition()
                self:SetText(validText)
                -- Adjust cursor position to stay at roughly the same place
                self:SetCursorPosition(math.min(cursorPos, #validText))
            end
        end
    end)
end


-- Safe tooltip display: suppressed while a frame is being dragged.
-- NOTE: ns.IsDraggingFrame is shared MUTABLE state, so it is read through the
-- namespace rather than re-localised - a local copy would never see updates.
-- (Previously this read a local declared *below* the function, so it silently
-- resolved to a nil global and the drag check never actually suppressed anything.)
local function ShowTooltipSafe(frame, anchorType)
    if not ns.IsDraggingFrame then
        GameTooltip:SetOwner(frame, anchorType or "ANCHOR_RIGHT")
        return true
    end
    return false
end

-- ========================================
-- Utility Functions
-- ========================================

local function HexToRGB(hex)
    if not hex or #hex ~= 6 then
        return 1, 1, 1
    end
    local r = tonumber(string.sub(hex, 1, 2), 16) / 255
    local g = tonumber(string.sub(hex, 3, 4), 16) / 255
    local b = tonumber(string.sub(hex, 5, 6), 16) / 255
    return r, g, b
end

local function RGBToHex(r, g, b)
    r = math.floor(math.max(0, math.min(1, r)) * 255)
    g = math.floor(math.max(0, math.min(1, g)) * 255)
    b = math.floor(math.max(0, math.min(1, b)) * 255)
    return string.format("%02X%02X%02X", r, g, b)
end


local function CreateStyledButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width or 100)
    btn:SetHeight(height or BUTTON_HEIGHT)
    btn:SetBackdrop(BACKDROP_BUTTON)
    btn:SetBackdropColor(unpack(COLORS.buttonBg))
    btn:SetBackdropBorderColor(unpack(COLORS.border))
    
    local label = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text or "")
    label:SetTextColor(unpack(COLORS.textBody))
    btn.label = label
    
    -- Hover fades in/out at the same speed; the press is instant so clicks still
    -- feel snappy, then the release eases back to the hover state.
    --
    -- In and out used to differ (0.12 / 0.18). Asymmetric hover can be deliberate,
    -- but nothing here documented it as such and every other control in the addon
    -- was symmetric, so this reads as drift rather than design. One duration now.
    btn:SetScript("OnEnter", function(self)
        TweenBackdrop(self, COLORS.buttonHover, COLORS.borderLight, MOTION.fast)
    end)
    btn:SetScript("OnLeave", function(self)
        TweenBackdrop(self, COLORS.buttonBg, COLORS.border, MOTION.fast)
    end)
    btn:SetScript("OnMouseDown", function(self)
        -- Stop the hover fade FIRST. This used to read
        --     self:SetScript("OnUpdate", nil)  -- cancel any running fade
        -- which stopped meaning anything when tweens moved onto the shared driver:
        -- TweenBackdrop never touches this frame's script slot, so the line cancelled
        -- nothing and the still-running hover fade overwrote the pressed colour on the
        -- very next frame. Clicking quickly after hovering showed no press at all.
        Anim.cancelProp(self, "backdrop")
        self:SetBackdropColor(unpack(COLORS.buttonPressed))
    end)
    btn:SetScript("OnMouseUp", function(self)
        TweenBackdrop(self, COLORS.buttonHover, COLORS.borderLight, MOTION.instant)
    end)
    
    return btn
end

-- Makes Escape close a frame, the way it closes Blizzard's own windows.
--
-- UISpecialFrames is just a list of GLOBAL frame names, so the frame must have been
-- created with one. WoW hides the frame directly - it does not run OnHide-style
-- callbacks or any cancel handler, so only register frames where "hidden" and
-- "dismissed" mean the same thing.
--
-- Guarded against double registration: the list is shared across every addon, and a
-- duplicate entry is pure noise in a table Blizzard walks on every Escape press.
local function RegisterEscapeClose(frameName)
    if type(frameName) ~= "string" or not UISpecialFrames then return false end
    for _, name in ipairs(UISpecialFrames) do
        if name == frameName then return false end
    end
    tinsert(UISpecialFrames, frameName)
    return true
end

-- ========================================
-- Publish to the shared namespace
-- ========================================
ns.RegisterEscapeClose = RegisterEscapeClose
ns.ValidateStatValueInput = ValidateStatValueInput
ns.ValidateWholeNumberInput = ValidateWholeNumberInput
ns.ApplyStatValueValidation = ApplyStatValueValidation
ns.ApplyWholeNumberValidation = ApplyWholeNumberValidation
ns.ShowTooltipSafe = ShowTooltipSafe
ns.HexToRGB = HexToRGB
ns.RGBToHex = RGBToHex
ns.CreateStyledButton = CreateStyledButton
