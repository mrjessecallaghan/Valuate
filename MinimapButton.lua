-- Valuate Minimap Button
-- Adds a draggable minimap button for quick access to Valuate UI

local Valuate = Valuate
if not Valuate then return end

-- The addon's private table, for the shared animation engine. This file loads LAST in
-- the .toc, well after ui\Animations.lua, so ns.Anim is always published by the time
-- anything here runs.
local _, ns = ...

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
    local options = Valuate:GetOptions()
    if not options.minimapButtonAngle then
        options.minimapButtonAngle = DEFAULT_POSITION
    end
    if options.minimapButtonHidden == nil then
        options.minimapButtonHidden = false
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
        -- valuate-lint-ignore: raw-onupdate-needs-reason  cursor-follow drag, not an animation; sole owner of this slot
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
            local options = Valuate:GetOptions()
            if options then
                options.minimapButtonAngle = angle
            end
        end)
    end)
    
    -- One place that ends a drag, so the two ways out cannot drift apart.
    --
    -- The resting text colour depends on where the cursor is. Releasing the button while
    -- still hovering it used to hand back the un-hovered white, so the button looked
    -- un-hovered while the mouse sat on it, until you moved away and came back. OnEnter and
    -- OnLeave are the only other writers of this colour and they agree with this.
    local function EndDrag(self)
        self:UnlockHighlight()
        if self.IsMouseOver and self:IsMouseOver() then
            self.vText:SetTextColor(unpack(BUTTON_COLORS.accent))
        else
            self.vText:SetTextColor(1, 1, 1, 1)
        end
        -- valuate-lint-ignore: raw-onupdate-needs-reason  ends the drag started directly above
        self:SetScript("OnUpdate", nil)
    end

    minimapButton:SetScript("OnDragStop", EndDrag)

    -- Hiding the button mid-drag must end the drag too.
    --
    -- OnDragStop is the only thing that cleared the cursor-follow handler, and it needs the
    -- button to still be there to fire. Hide it while dragging - Settings has a toggle, and
    -- so does /valuate minimap - and the handler stays installed. Hidden frames get no
    -- OnUpdate, so nothing happens until you show it again, at which point the button
    -- resumes following the cursor with no mouse button held.
    --
    -- Same shape as the Settings keybind capture, which had exactly two exits and both
    -- needed the panel in front of you. An armed state must not be able to outlive the
    -- thing that armed it.
    minimapButton:SetScript("OnHide", function(self)
        if self:GetScript("OnUpdate") then EndDrag(self) end
    end)
    
    -- Hover effects
    minimapButton:SetScript("OnEnter", function(self)
        self.vText:SetTextColor(unpack(BUTTON_COLORS.accent))  -- Blue accent on hover
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cFF00FF00Valuate|r", 1, 1, 1)

        -- Status, not just controls. The three things worth knowing - which spec is
        -- active, what your gear scores, and whether anything is waiting - were all
        -- a window-open away, which is a poor trade for a glance.
        --
        -- Everything is guarded and pcall'd: this is a hover handler, so an error
        -- here fires on every pass of the mouse and would be miserable.
        local ok = pcall(function()
            local scale, scaleName = Valuate:GetPrimaryScale()
            if not scale then
                GameTooltip:AddLine("No active scale", 1, 0.5, 0.3)
                return
            end

            local label = scale.DisplayName or scaleName
            local colour = scale.Color or "FFFFFF"
            local decimals = Valuate:GetOptions().decimalPlaces or 1
            local fmt = "%." .. decimals .. "f"

            local total = Valuate.CalculateTotalEquippedScore
                and Valuate:CalculateTotalEquippedScore(scale) or nil
            if total then
                GameTooltip:AddDoubleLine("|cFF" .. colour .. label .. "|r",
                    string.format(fmt, total), 1, 1, 1, 1, 1, 1)
            else
                GameTooltip:AddLine("|cFF" .. colour .. label .. "|r", 1, 1, 1)
            end

            -- Whether the scale doing all this scoring is built on numbers nobody published.
            --
            -- The picker says so on hover, the list marks it, the editor repeats it and the
            -- login summary raises it - and this is the surface people actually LOOK at, the
            -- one that already answers "which spec, what score, anything waiting". A scale
            -- that is a guess belongs in that same glance.
            if scale.Inferred then
                GameTooltip:AddLine("|cFFFF8833? weights are a guess|r", 1, 1, 1)
            end

            if Valuate.CountEquippableUpgrades then
                local count, _, bankCount = Valuate:CountEquippableUpgrades(scaleName)
                if count > 0 then
                    GameTooltip:AddLine(string.format("|cFF00FF00%d upgrade%s in your bags|r",
                        count, count == 1 and "" or "s"), 1, 1, 1)
                elseif (bankCount or 0) == 0 then
                    GameTooltip:AddLine("|cFF888888Wearing your best|r", 1, 1, 1)
                end
                if (bankCount or 0) > 0 then
                    GameTooltip:AddLine(string.format("|cFFFF8800%d in your bank|r", bankCount), 1, 1, 1)
                end
            end
        end)
        if not ok then
            GameTooltip:AddLine("|cFFFF8800Status unavailable|r", 1, 1, 1)
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open Valuate UI", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag to move", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    
    minimapButton:SetScript("OnLeave", function(self)
        self.vText:SetTextColor(1, 1, 1, 1)  -- Back to white
        GameTooltip:Hide()
    end)
    
    -- Set initial position
    local options = Valuate:GetOptions()
    local savedAngle = options.minimapButtonAngle or DEFAULT_POSITION
    UpdateButtonPosition(savedAngle)
    
    -- Show or hide based on saved state
    if not options.minimapButtonHidden then
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
    local options = Valuate:GetOptions()
    if options then
        options.minimapButtonHidden = false
    end
end

function Valuate:HideMinimapButton()
    if minimapButton then
        minimapButton:Hide()
    end
    local options = Valuate:GetOptions()
    if options then
        options.minimapButtonHidden = true
    end
end

-- Makes the button match whatever the options currently say.
--
-- Position and visibility are otherwise read only when the button is CREATED, and
-- Show/Hide above WRITE the option rather than applying it - they are the user's action.
-- So anything that changes those options wholesale (loading a settings snapshot,
-- restoring defaults) moved the setting without moving the button, and the two only
-- agreed again after a reload.
function Valuate:ApplyMinimapButtonOptions()
    -- No button yet means it has not been created; creation reads these same options.
    if not minimapButton then return end
    local options = Valuate:GetOptions()
    UpdateButtonPosition(options.minimapButtonAngle or DEFAULT_POSITION)
    if options.minimapButtonHidden then
        minimapButton:Hide()
    else
        minimapButton:Show()
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

-- Briefly pulse the minimap button (a twin starburst glow + gentle scale bump) to
-- draw the eye when a gear upgrade for your current scale is available. Safe no-op
-- if the button is hidden.
--
-- Runs on the shared animation engine, NOT on this button's own OnUpdate. It used to
-- own that script slot - but so does the drag handler, and a frame only has one. A
-- pulse interrupted by a drag never reached its cleanup, so the starburst stayed
-- visible and the button stayed scaled up (to 1.14x) until some later pulse happened
-- to finish; a pulse arriving mid-drag stopped the button following the cursor. The
-- engine owns tweens by (frame, property), so the two no longer collide and the drag
-- handler is the only writer of this button's OnUpdate.
--
-- Owned by "pulse" so two upgrades in quick succession replace rather than stack -
-- otherwise both would be writing SetScale every frame and the first to finish would
-- snap the button back to 1 mid-pulse.
local pulseGlow
function Valuate:PulseMinimapButton()
    if not minimapButton or not minimapButton:IsShown() then return end
    local Anim = ns and ns.Anim
    if not Anim then return end
    -- ReduceMotion is checked here rather than left to the engine: the engine would
    -- jump to the final frame of the pulse, and this animation's "final state" is a
    -- hidden glow, so the honest instant version is simply not pulsing at all.
    if ns.ReduceMotion and ns.ReduceMotion() then return end

    if not pulseGlow then
        pulseGlow = minimapButton:CreateTexture(nil, "OVERLAY")
        pulseGlow:SetTexture("Interface\\Cooldown\\star4")
        pulseGlow:SetBlendMode("ADD")
        pulseGlow:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
        pulseGlow:SetVertexColor(0.40, 0.75, 1.0)
        pulseGlow:Hide()
    end

    pulseGlow:Show()
    Anim.owned(minimapButton, "pulse", {
        duration = (ns.MOTION and ns.MOTION.pulse) or 1.3,
        -- Linear, because the envelope below IS the shaping. An easing on top would
        -- distort the two pulses into uneven ones.
        ease = "linear",
        onUpdate = function(t)
            -- Two quick pulses inside a fading envelope.
            local env = 1 - t
            local pulse = math.abs(math.sin(t * math.pi * 3)) * env
            local size = 24 + pulse * 30
            pulseGlow:SetWidth(size)
            pulseGlow:SetHeight(size)
            pulseGlow:SetAlpha(pulse)
            minimapButton:SetScale(1 + pulse * 0.14)
        end,
        -- Runs on completion only. Cancelling (a second pulse replacing this one)
        -- deliberately does NOT run it: the replacement owns the cleanup, and firing
        -- this in between would snap the button back to scale 1 mid-pulse.
        onDone = function()
            pulseGlow:Hide()
            minimapButton:SetScale(1)
        end,
    })
end

-- Initialize the button when the addon loads
local initFrame = CreateFrame("Frame")
local function InitializeMinimapButton()
    -- Options should already be initialized by Valuate:Initialize()
    -- Just check that it exists before trying to use it
    local options = Valuate.GetOptions and Valuate:GetOptions()
    if options and not options.minimapButtonHidden then
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

