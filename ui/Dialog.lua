-- ui/Dialog.lua
-- Valuate's own confirmation dialog.
--
-- Its frame reference (valuateDialog) is state, but ONLY this file touches it, so it
-- stays a file-local - no ns.X conversion needed. The two entry points are published
-- on the Valuate table (not the namespace) because Valuate.lua calls them, and it
-- loads before this file: `if Valuate.ShowConfirmDialog then ... end`.

local _, ns = ...

local COLORS = ns.COLORS
local BACKDROP_WINDOW = ns.BACKDROP_WINDOW
local FONT_BODY = ns.FONT_BODY
local CreateStyledButton = ns.CreateStyledButton   -- ui/Widgets.lua
local Anim = ns.Anim                               -- ui/Animations.lua

-- ========================================
-- Custom confirm dialog (taint-free)
-- ========================================
-- Blizzard RECYCLES the shared StaticPopup1..4 frames. Showing one of OUR dialogs via
-- StaticPopup_Show taints the frame it lands on; when Blizzard later reuses that same
-- frame for a secure dialog - e.g. USE_BIND ("using this item will bind it to you") -
-- clicking its button taints the secure call, producing
--   "AddOn 'Valuate' tainted the call of the secure function 'ConfirmBindOnUse()'"
-- and blocking the item use. Note this happens even though we never call that
-- function: we only had to poison the shared frame. So Valuate uses its own dialog
-- frame and never touches StaticPopup.
local valuateDialog

local function EnsureDialog()
    if valuateDialog then return valuateDialog end

    local f = CreateFrame("Frame", "ValuateConfirmDialog", UIParent)
    -- Escape dismisses it. Safe because no caller passes onCancel - cancelling is
    -- purely "close without acting", which is exactly what hiding does. If a caller
    -- ever needs cleanup on cancel, this registration has to go.
    if ns.RegisterEscapeClose then ns.RegisterEscapeClose("ValuateConfirmDialog") end
    f:SetSize(400, 130)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(BACKDROP_WINDOW)
    f:SetBackdropColor(unpack(COLORS.windowBg))
    f:SetBackdropBorderColor(unpack(COLORS.borderLight))
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    accent:SetHeight(2)
    accent:SetColorTexture(unpack(COLORS.textAccent))

    local text = f:CreateFontString(nil, "OVERLAY", FONT_BODY)
    text:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -20)
    text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -20)
    text:SetJustifyH("CENTER")
    text:SetTextColor(unpack(COLORS.textBody))
    f.text = text

    local accept = CreateStyledButton(f, "Okay", 150, 24)
    accept:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 16)
    f.accept = accept

    local cancel = CreateStyledButton(f, "Cancel", 150, 24)
    cancel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 16)
    f.cancel = cancel

    valuateDialog = f
    return f
end

-- opts: text, acceptText, cancelText, onAccept, onCancel
function Valuate:ShowConfirmDialog(opts)
    opts = opts or {}
    local f = EnsureDialog()
    f.text:SetText(opts.text or "")
    f.accept.label:SetText(opts.acceptText or "Okay")
    f.cancel.label:SetText(opts.cancelText or "Cancel")

    f.accept:SetScript("OnClick", function()
        f:Hide()
        if opts.onAccept then opts.onAccept() end
    end)
    f.cancel:SetScript("OnClick", function()
        f:Hide()
        if opts.onCancel then opts.onCancel() end
    end)

    -- Size to fit the message.
    f:SetHeight(math.max(120, (f.text:GetStringHeight() or 20) + 90))

    f:Show()
    f:SetAlpha(0)
    Anim.fade(f, 1, 0.15, "outQuad")
    return f
end

function Valuate:HideConfirmDialog()
    if valuateDialog then valuateDialog:Hide() end
end
