-- ui/Shared.lua
-- Design tokens shared by every Valuate UI file: spacing, sizing, colours, backdrops
-- and fonts.
--
-- These live on the addon's private table (`...`) because separate .lua files cannot
-- see each other's locals. Consumers re-localise them at the top of their file
-- (`local COLORS = ns.COLORS`), which keeps every existing reference unchanged and
-- costs nothing at runtime.
--
-- IMPORTANT: only put IMMUTABLE values here. Mutable state (frames, the currently
-- edited scale, ...) must be read and written as `ns.X` everywhere, because assigning
-- to a re-localised copy would not propagate to other files.

local _, ns = ...

-- ========================================
-- Shared mutable UI state
-- ========================================
-- All MUTABLE and shared across UI files, so they must always be read AND written as
-- ns.X. Re-localising any of these would break them: assigning to the local copy
-- would not propagate, and other files would keep seeing the old value.
ns.IsDraggingFrame = false          -- true while a frame is being dragged (suppresses tooltips)
ns.ValuateUIFrame = nil             -- the main window
ns.CurrentSelectedScale = nil       -- scale highlighted in the list
ns.EditingScaleName = nil           -- scale currently open in the editor
ns.OriginalScaleData = nil          -- pre-edit snapshot (revert support)
ns.ScaleEditorFrame = nil           -- the editor's content frame
ns.ScaleListButtons = {}            -- scaleName -> list button
ns.ValuateUI_OnTemplateOverwrite = nil  -- callback set by the template picker

-- ========================================
-- Spacing / sizing
-- ========================================
ns.PADDING = 12              -- Outer padding from window edges
ns.ELEMENT_SPACING = 8       -- Between major UI sections
ns.INNER_SPACING = 4         -- Within elements
ns.COLUMN_GAP = 6            -- Gap between stat columns

ns.BUTTON_HEIGHT = 24
ns.ENTRY_HEIGHT = 24
ns.SCROLLBAR_WIDTH = 20      -- Width reserved for scrollbars (18px bar + 2px gap)

-- Motion tokens, in the same spirit as COLORS: a small fixed vocabulary rather than
-- a number picked per animation.
--
-- These accumulated as eight different durations across about a dozen animations,
-- each reasonable alone. The effect of that is subtle but real - motion that varies
-- without meaning reads as slightly off rather than deliberate, in the same way
-- mismatched spacing does.
--
-- Pick by INTENT, not by feel:
ns.MOTION = {
    instant = 0.10,  -- press/click feedback; must feel like it already happened
    fast    = 0.16,  -- hover and other small state changes
    base    = 0.24,  -- dialogs and panels arriving; the default
    slow    = 0.34,  -- reveals where the motion itself carries the meaning
    count   = 0.55,  -- number roll-ups; long enough that the climb is readable

    -- Cascades (staggered reveals) are described by their TOTAL window, not by a
    -- per-item gap. A gap that looks lively across three settings columns turns a
    -- twenty-row list into a crawl, which is why every cascade here had drifted to
    -- its own hand-tuned number. Anim.staggerFor() divides `cascade` by the item
    -- count and clamps to [staggerMin, stagger].
    cascade    = 0.30,
    stagger    = 0.05,  -- widest per-item gap: below this, few items look simultaneous
    staggerMin = 0.02,  -- tightest: below this, many items look simultaneous anyway
}

-- Stat editor sizing (5-column layout)
ns.NUM_COLUMNS = 5           -- Number of stat columns
ns.COLUMN_WIDTH = 160        -- Each stat column width
ns.ROW_HEIGHT = 16           -- Stat row height
ns.ROW_SPACING = 1           -- Spacing between stat rows
ns.HEADER_HEIGHT = 14        -- Category header height
ns.HEADER_SPACING = 6        -- Spacing above headers

-- Scale list sizing
ns.SCALE_LIST_WIDTH = 200    -- Left panel width for scale list

-- Window width: padding + scale list + gap + editor content (columns + gaps) + padding
ns.EDITOR_CONTENT_WIDTH = ns.NUM_COLUMNS * ns.COLUMN_WIDTH + (ns.NUM_COLUMNS - 1) * ns.COLUMN_GAP
ns.WINDOW_WIDTH = ns.PADDING + ns.SCALE_LIST_WIDTH + ns.PADDING + ns.EDITOR_CONTENT_WIDTH + ns.PADDING
-- = 12 + 200 + 12 + (5*160 + 4*6) + 12 = 1060

ns.MIN_WINDOW_HEIGHT = 600
ns.MAX_WINDOW_HEIGHT = 900

-- ========================================
-- Colour palette (cool-dark theme)
-- ========================================
ns.COLORS = {
    -- Backgrounds (near-black with a subtle cool slate tint for depth)
    windowBg = { 0.055, 0.060, 0.075, 0.98 },
    panelBg = { 0.035, 0.040, 0.052, 0.96 },
    inputBg = { 0.090, 0.100, 0.120, 1 },
    buttonBg = { 0.145, 0.155, 0.185, 1 },
    buttonHover = { 0.240, 0.270, 0.340, 1 },
    buttonPressed = { 0.100, 0.110, 0.140, 1 },

    -- Borders (cool, subtle, crisp)
    border = { 0.26, 0.29, 0.36, 1 },
    borderLight = { 0.42, 0.48, 0.60, 1 },
    borderDark = { 0.14, 0.16, 0.20, 1 },

    -- Text (crisp, cool-neutral hierarchy)
    textTitle = { 0.96, 0.97, 1.00, 1 },
    textHeader = { 0.70, 0.77, 0.90, 1 },
    textBody = { 0.85, 0.87, 0.92, 1 },
    textDim = { 0.46, 0.50, 0.60, 1 },
    textAccent = { 0.38, 0.72, 1.00, 1 },   -- vivid azure accent

    -- States
    selected = { 0.16, 0.32, 0.52, 1 },
    selectedBorder = { 0.36, 0.62, 0.95, 1 },
    disabled = { 0.24, 0.25, 0.30, 0.6 },
}

-- ========================================
-- Borders / backdrops
-- ========================================
ns.BORDER_TOOLTIP = "Interface\\Tooltips\\UI-Tooltip-Border"  -- Clean, minimal border
ns.BORDER_EDGE_SIZE = 12

ns.BACKDROP_WINDOW = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = ns.BORDER_TOOLTIP,
    edgeSize = 16,
    tile = false,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

ns.BACKDROP_PANEL = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = ns.BORDER_TOOLTIP,
    edgeSize = ns.BORDER_EDGE_SIZE,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

ns.BACKDROP_INPUT = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = ns.BORDER_TOOLTIP,
    edgeSize = 10,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

ns.BACKDROP_BUTTON = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = ns.BORDER_TOOLTIP,
    edgeSize = ns.BORDER_EDGE_SIZE,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

-- ========================================
-- Fonts
-- ========================================
ns.FONT_TITLE = "GameFontHighlightLarge"    -- ~16pt, white
ns.FONT_H1 = "GameFontHighlight"            -- ~12pt, white
ns.FONT_H2 = "GameFontHighlightSmall"       -- ~10pt, white
ns.FONT_H3 = "GameFontHighlightSmall"       -- ~10pt, white
ns.FONT_BODY = "GameFontHighlight"          -- ~12pt, white
ns.FONT_SMALL = "GameFontHighlightSmall"    -- ~10pt, white

-- ========================================
-- Client compatibility
-- ========================================

-- Fills a texture with a flat colour, on whichever client this is.
--
-- `Texture:SetColorTexture` arrived in Legion (7.0). This addon targets Interface 30300,
-- where the call does not exist and the equivalent is `SetTexture(r, g, b, a)` - passing
-- numbers instead of a path. Twenty-two call sites across six files used the modern name;
-- one place in ui/ScaleList.lua used the 3.3.5 form, which is the tell that this was a
-- habit rather than a decision.
--
-- Whether it matters depends on the client: Ascension ships a customised 3.3.5a and may
-- well have backported it. Rather than guess, ASK the texture. If the method is there it
-- is used; if not, the WotLK form is. Correct on both, and it costs one lookup on a call
-- that only runs while building UI.
--
-- Every accent bar, separator, row highlight, header background and change-flash in the
-- addon goes through this, so on a client without the modern call the alternative is an
-- error for each one at build time - which in Lua means the rest of that function never
-- runs.
function ns.SetSolidColor(tex, r, g, b, a)
    if not tex then return end
    if tex.SetColorTexture then
        tex:SetColorTexture(r, g, b, a)
    else
        -- 3.3.5a: SetTexture doubles as the solid-colour setter.
        tex:SetTexture(r, g, b, a)
    end
end
