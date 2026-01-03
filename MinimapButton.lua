-- Valuate Minimap Button
-- Adds a draggable minimap button for quick access to Valuate UI

local Valuate = Valuate
if not Valuate then return end

-- Minimap button state
local minimapButton = nil
local DEFAULT_POSITION = 200  -- Default angle in degrees

-- Color constants matching Valuate UI styling
local BUTTON_COLORS = {
    bg = { 0.15, 0.15, 0.15, 0.9 },
    border = { 0.35, 0.35, 0.35, 1 },
    borderLight = { 0.45, 0.45, 0.45, 1 },
    text = { 0.85, 0.85, 0.85, 1 },
    vText = { 0.75, 0.75, 0.75, 1 },  -- Grey stylized V
    accent = { 0.4, 0.7, 0.9, 1 },  -- Soft blue accent
}

-- Update button position based on angle (in degrees)
local function UpdateButtonPosition(angle)
    if not minimapButton then return end
    
    local rad = math.rad(angle or DEFAULT_POSITION)
    local radius = 80  -- Distance from minimap center
    
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius
    
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Create the minimap button
local function CreateMinimapButton()
    if minimapButton then return minimapButton end
    
    -- Initialize saved variables if needed
    if not ValuateOptions.minimapButtonAngle then
        ValuateOptions.minimapButtonAngle = DEFAULT_POSITION
    end
    if ValuateOptions.minimapButtonHidden == nil then
        ValuateOptions.minimapButtonHidden = false
    end
    
    -- Create the button frame
    minimapButton = CreateFrame("Button", "ValuateMinimapButton", Minimap)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetWidth(31)
    minimapButton:SetHeight(31)
    minimapButton:SetMovable(true)
    
    -- Create background texture for the button
    local background = minimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetWidth(20)
    background:SetHeight(20)
    background:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(unpack(BUTTON_COLORS.bg))
    minimapButton.background = background
    
    -- Highlight texture
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Create the "V" text - stylized grey letter (on ARTWORK layer, above background)
    local vText = minimapButton:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    vText:SetFont("Fonts\\FRIZQT__.TTF", 14, "THICKOUTLINE")
    vText:SetText("V")
    vText:SetTextColor(1, 1, 1, 1)  -- White text for better visibility
    -- Position using TOPLEFT anchor like other minimap buttons (VuhDo uses 7,-5 for 20x20 icons)
    -- Adjusting slightly for text vs texture positioning
    vText:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 9, -6)
    minimapButton.vText = vText
    
    -- Create overlay border (minimap button style) - should be on top
    local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    minimapButton.overlay = overlay
    
    -- Click handler
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" or btn == "RightButton" then
            -- Toggle Valuate UI
            if Valuate and Valuate.ToggleUI then
                Valuate:ToggleUI()
            else
                print("|cFFFF0000Valuate|r: UI not available. Please reload UI with /reload")
            end
        end
    end)
    
    -- Drag handler
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.vText:SetTextColor(unpack(BUTTON_COLORS.accent))  -- Highlight text when dragging
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            
            local angle = math.deg(math.atan2(py - my, px - mx))
            if angle < 0 then
                angle = angle + 360
            end
            
            UpdateButtonPosition(angle)
            
            -- Save position
            if ValuateOptions then
                ValuateOptions.minimapButtonAngle = angle
            end
        end)
    end)
    
    minimapButton:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.vText:SetTextColor(1, 1, 1, 1)  -- Restore white color
        self:SetScript("OnUpdate", nil)
    end)
    
    -- Hover effects
    minimapButton:SetScript("OnEnter", function(self)
        self.vText:SetTextColor(unpack(BUTTON_COLORS.accent))  -- Blue accent on hover
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cFF00FF00Valuate|r", 1, 1, 1)
        GameTooltip:AddLine("Left-click to open Valuate UI", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-click for options", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function(self)
        self.vText:SetTextColor(1, 1, 1, 1)  -- Back to white
        GameTooltip:Hide()
    end)
    
    -- Set initial position
    local savedAngle = ValuateOptions.minimapButtonAngle or DEFAULT_POSITION
    UpdateButtonPosition(savedAngle)
    
    -- Show or hide based on saved state
    if not ValuateOptions.minimapButtonHidden then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
    
    return minimapButton
end

-- Public API for showing/hiding the button
function Valuate:ShowMinimapButton()
    if not minimapButton then
        CreateMinimapButton()
    else
        minimapButton:Show()
    end
    if ValuateOptions then
        ValuateOptions.minimapButtonHidden = false
    end
end

function Valuate:HideMinimapButton()
    if minimapButton then
        minimapButton:Hide()
    end
    if ValuateOptions then
        ValuateOptions.minimapButtonHidden = true
    end
end

function Valuate:ToggleMinimapButton()
    if not minimapButton then
        CreateMinimapButton()
    end
    if minimapButton:IsShown() then
        Valuate:HideMinimapButton()
    else
        Valuate:ShowMinimapButton()
    end
end

-- Initialize the button when the addon loads
local initFrame = CreateFrame("Frame")
local function InitializeMinimapButton()
    -- ValuateOptions should already be initialized by Valuate:Initialize()
    -- Just check that it exists before trying to use it
    if ValuateOptions and not ValuateOptions.minimapButtonHidden then
        CreateMinimapButton()
    end
end

-- Try to initialize immediately if addon is already loaded
if IsAddOnLoaded("Valuate") then
    -- Addon is already loaded, wait for PLAYER_ENTERING_WORLD
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            InitializeMinimapButton()
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)
else
    -- Wait for addon to load
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "Valuate" then
            -- Wait for player to enter world before creating minimap button
            self:RegisterEvent("PLAYER_ENTERING_WORLD")
        elseif event == "PLAYER_ENTERING_WORLD" then
            InitializeMinimapButton()
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)
end

