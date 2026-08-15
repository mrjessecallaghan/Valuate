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
    -- Six characters is not the same as six HEX characters, and the difference is a
    -- crash rather than a wrong colour: tonumber("ZZ", 16) is nil, and nil/255 raises.
    --
    -- Worth guarding because these values are not ours. Scale colours come from saved
    -- variables and from imported scale tags - a hand-edited SavedVariables file or a
    -- malformed tag pasted from elsewhere is enough. The old version errored INSIDE
    -- whichever panel was mid-build, taking the whole panel down; falling back to
    -- white costs one wrong swatch.
    local r = tonumber(string.sub(hex, 1, 2), 16)
    local g = tonumber(string.sub(hex, 3, 4), 16)
    local b = tonumber(string.sub(hex, 5, 6), 16)
    if not r or not g or not b then
        return 1, 1, 1
    end
    return r / 255, g / 255, b / 255
end

local function RGBToHex(r, g, b)
    r = math.floor(math.max(0, math.min(1, r)) * 255)
    g = math.floor(math.max(0, math.min(1, g)) * 255)
    b = math.floor(math.max(0, math.min(1, b)) * 255)
    return string.format("%02X%02X%02X", r, g, b)
end


-- The hover and press behaviour of a button, separated from the making of one.
--
-- It lived inside CreateStyledButton, which meant a button built any other way had none of
-- it - and several are, because they need a label colour, an icon or an anchor the helper
-- does not take. Those buttons wore the same backdrop and looked identical whether the
-- mouse was over them or not.
--
-- HOOKED, not set: most of these buttons already use OnEnter to open a tooltip, and that is
-- the whole reason they were built by hand. Replacing their scripts to give them a hover
-- would have taken the tooltip away.
function ns.AttachButtonFeedback(btn)
    -- Hover fades in/out at the same speed; the press is instant so clicks still
    -- feel snappy, then the release eases back to the hover state.
    --
    -- In and out used to differ (0.12 / 0.18). Asymmetric hover can be deliberate,
    -- but nothing here documented it as such and every other control in the addon
    -- was symmetric, so this reads as drift rather than design. One duration now.
    btn:HookScript("OnEnter", function(self)
        TweenBackdrop(self, COLORS.buttonHover, COLORS.borderLight, MOTION.fast)
    end)
    btn:HookScript("OnLeave", function(self)
        TweenBackdrop(self, COLORS.buttonBg, COLORS.border, MOTION.fast)
    end)
    btn:HookScript("OnMouseDown", function(self)
        -- Stop the hover fade FIRST. This used to read
        --     self:SetScript("OnUpdate", nil)  -- cancel any running fade
        -- which stopped meaning anything when tweens moved onto the shared driver:
        -- TweenBackdrop never touches this frame's script slot, so the line cancelled
        -- nothing and the still-running hover fade overwrote the pressed colour on the
        -- very next frame. Clicking quickly after hovering showed no press at all.
        Anim.cancelProp(self, "backdrop")
        self:SetBackdropColor(unpack(COLORS.buttonPressed))
    end)
    btn:HookScript("OnMouseUp", function(self)
        TweenBackdrop(self, COLORS.buttonHover, COLORS.borderLight, MOTION.instant)
    end)
    return btn
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

    return ns.AttachButtonFeedback(btn)
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
-- Search box
-- ========================================

-- One search box, three users: Settings, the Scale Editor's stat grid, and the icon picker.
--
-- They were written separately and had already drifted where it shows - Escape. Settings
-- cleared the text on the first press and released focus on a second; the stat search did
-- both at once; the icon search cleared if there was anything and always released. Three
-- behaviours for one key, in one addon.
--
-- The two-stage version wins, and not because it was first: while an EditBox has focus it
-- swallows Escape, so a box that releases focus in the same press as it clears gives you no
-- way to clear a search and then close the window with a second Escape. Two presses, two
-- distinct things, neither surprising.
--
-- What is NOT shared is the filtering. Settings walks a derived index, the stat grid dims
-- rows, the icon picker rebuilds a list; the caller does that through onQuery. This owns
-- the chrome, the hint and the keys - the parts that have no business differing.
--
-- opts: hint, fontObject, onQuery(text)  (all optional except onQuery)
-- Returns: box, hint  - the hint is returned because two callers position other things
-- against it, and re-finding it from the box would be worse.
local function CreateSearchBox(parent, opts)
    opts = opts or {}

    local box = CreateFrame("EditBox", opts.name, parent)
    box:SetHeight(opts.height or 20)
    box:SetAutoFocus(false)
    box:SetFontObject(opts.fontObject or "GameFontHighlightSmall")
    box:SetBackdrop(ns.BACKDROP_INPUT)
    box:SetBackdropColor(unpack(ns.COLORS.inputBg))
    box:SetBackdropBorderColor(unpack(ns.COLORS.border))
    box:SetTextInsets(6, 6, 0, 0)

    local hint = box:CreateFontString(nil, "OVERLAY", ns.FONT_SMALL)
    hint:SetPoint("LEFT", box, "LEFT", 7, 0)
    hint:SetText(opts.hint or "Search...")
    hint:SetTextColor(unpack(ns.COLORS.textDim))

    local function refreshHint(self)
        -- Hidden while focused even when empty: the placeholder sitting under a blinking
        -- caret reads as text you have to delete.
        if (self:GetText() or "") ~= "" or self.__searchFocused then
            hint:Hide()
        else
            hint:Show()
        end
    end

    box:SetScript("OnTextChanged", function(self)
        refreshHint(self)
        if opts.onQuery then opts.onQuery(self:GetText() or "") end
    end)

    box:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then
            -- Clear, and KEEP focus, so you can type a different search straight away.
            -- SetText fires OnTextChanged, which re-runs the filter.
            self:SetText("")
        else
            -- Already empty, so hand Escape back: the next press reaches the window.
            self:ClearFocus()
        end
    end)

    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self)
        self.__searchFocused = true
        refreshHint(self)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self.__searchFocused = false
        refreshHint(self)
    end)

    return box, hint
end

-- ========================================
-- Publish to the shared namespace
-- ========================================
ns.CreateSearchBox = CreateSearchBox
ns.RegisterEscapeClose = RegisterEscapeClose
ns.ValidateStatValueInput = ValidateStatValueInput
ns.ValidateWholeNumberInput = ValidateWholeNumberInput
ns.ApplyStatValueValidation = ApplyStatValueValidation
ns.ApplyWholeNumberValidation = ApplyWholeNumberValidation
ns.ShowTooltipSafe = ShowTooltipSafe
ns.HexToRGB = HexToRGB
ns.RGBToHex = RGBToHex
ns.CreateStyledButton = CreateStyledButton

-- Sizes a pooled row to the text actually in it.
--
-- WHY THIS IS SHARED. A fixed row height and a font string that wraps is a defect this
-- project has now shipped twice: the To Do panel in v0.158.0a, and the Enhance panel in
-- v0.167.0a - the second written in a file created after the first was fixed. Neither is
-- visible to any headless gate unless somebody thinks to measure, because nothing errors;
-- the second and third lines are simply drawn over whatever is below them.
--
-- Two implementations became two chances to forget. This is one, so the next panel that
-- needs it has an obvious thing to call rather than a pattern to remember.
--
-- opts.columns is a LIST OF LISTS, because a row can have independent stacks side by side
-- and either can be the one that wraps. Sizing to one of them is exactly how the Enhance
-- panel put its vendor note through the bottom of its own row.
function ns.FitRowHeight(row, opts)
    if not row or type(opts) ~= "table" then return end
    local top = opts.top or 8
    local gap = opts.gap or 3
    local bottom = opts.bottom or 8
    local floor = opts.floor or 0

    local tallest = 0
    for _, column in ipairs(opts.columns or {}) do
        local height, lines = 0, 0
        for _, fs in ipairs(column) do
            -- An empty or hidden string contributes nothing, not even its gap. Counting it
            -- would leave a blank line's worth of space under every row that omits one.
            local text = fs and fs.GetText and fs:GetText()
            if fs and text and text ~= "" and (not fs.IsShown or fs:IsShown()) then
                if lines > 0 then height = height + gap end
                height = height + (fs.GetStringHeight and fs:GetStringHeight() or 0)
                lines = lines + 1
            end
        end
        if height > tallest then tallest = height end
    end

    row:SetHeight(math.max(floor, top + tallest + bottom))
    return row:GetHeight()
end
