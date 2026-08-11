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

    -- The rhythm of anything that breathes rather than arrives: the upgrade-arrow glow,
    -- the minimap attention pulse, the upgrade popup's icon glow.
    --
    -- Added because there were THREE of these and no token for them - 1.3, 1.3 and 1.6,
    -- two agreeing by coincidence and one differing for no reason anyone had written down.
    -- Several things pulsing at slightly different rates is the "motion that varies without
    -- meaning" this table exists to stop; it reads as an interface assembled rather than
    -- designed, and it is the sort of thing you feel without being able to name.
    --
    -- 1.3s: slow enough to read as breathing rather than blinking, quick enough that a
    -- glance catches it mid-cycle.
    pulse   = 1.3,

    -- Cascades (staggered reveals) are described by their TOTAL window, not by a
    -- per-item gap. A gap that looks lively across three settings columns turns a
    -- twenty-row list into a crawl, which is why every cascade here had drifted to
    -- its own hand-tuned number. Anim.staggerFor() divides `cascade` by the item
    -- count and clamps to [staggerMin, stagger].
    cascade    = 0.30,
    stagger    = 0.05,  -- widest per-item gap: below this, few items look simultaneous
    staggerMin = 0.02,  -- tightest: below this, many items look simultaneous anyway
}

-- Published on the PUBLIC table, for the integration addons.
--
-- Valuate-AdiBags draws its own pulsing marker and cannot see `ns` - it is a separate
-- addon with its own namespace - so before this it carried a copy of the number. A copy
-- is how the popup ended up at 1.6 while everything else ran at 1.3, and a rhythm that is
-- only coincidentally shared is not shared at all.
Valuate = Valuate or {}
Valuate.PulsePeriod = ns.MOTION.pulse

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
    -- Softened from 0.240/0.270/0.340, which was a 2.8x luminance jump off buttonBg -
    -- loud for a dark theme, and it made dim text on a hovered row measure 3.26:1. Still a
    -- clear ~1.7x lift, so the affordance survives; it just stops shouting.
    buttonHover = { 0.195, 0.215, 0.270, 1 },
    buttonPressed = { 0.100, 0.110, 0.140, 1 },

    -- Borders (cool, subtle, crisp)
    border = { 0.26, 0.29, 0.36, 1 },
    borderLight = { 0.42, 0.48, 0.60, 1 },
    borderDark = { 0.14, 0.16, 0.20, 1 },

    -- Text (crisp, cool-neutral hierarchy)
    --
    -- Ordered by measured contrast against windowBg, not by eye: title > header > body >
    -- dim, each step clearly separated. tools/contrast.js enforces both the ordering and
    -- the floors, because "looks about right" is how this drifted in the first place.
    --
    -- It was genuinely inverted before v0.74.0a. textHeader sat at 10.9 against a textBody
    -- of 14.2, so every section heading was QUIETER than the paragraph beneath it - the
    -- reason the panels read as slightly flat and hard to scan without anyone being able to
    -- say why.
    textTitle = { 0.97, 0.98, 1.00, 1 },
    textHeader = { 0.89, 0.92, 0.98, 1 },
    textBody = { 0.78, 0.81, 0.88, 1 },
    -- Raised from 0.46/0.50/0.60. It was 3.73 against buttonBg - below the 4.5 needed for
    -- body-sized text - and this is the token hints and secondary labels use, which is
    -- exactly the text someone is squinting at when they are already unsure.
    textDim = { 0.60, 0.64, 0.72, 1 },
    textAccent = { 0.45, 0.76, 1.00, 1 },   -- vivid azure accent

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
-- Six names, three sizes. That was the type scale until v0.74.0a: FONT_H1 and FONT_BODY were
-- the same font, and FONT_H2, FONT_H3 and FONT_SMALL were all a second one. So a section
-- heading was exactly the same size as the paragraph under it, and a sub-heading was the size
-- of small print - which, together with a heading colour that measured DIMMER than body text,
-- is the whole reason these panels read as flat and hard to scan.
--
-- v0.75.0a: REVERTED to stock font templates after v0.74.0a broke the UI in the client.
--
-- The custom-font-object version shipped with a fallback that could not fire. It read:
--
--     local applied = pcall(font.SetFont, font, FONT_PATH, size)
--     if not applied or (font.GetFont and not font:GetFont()) then return fallbackTemplate end
--
-- Two holes, either one fatal. `pcall` returns success THEN the call's own result, and only
-- the first was captured - so a SetFont that returned false without erroring read as success.
-- And a 3.3.5 Font object has no GetFont method, which makes `font.GetFont` nil, which makes
-- the whole second clause falsy. DefineFont therefore returned the NAME of a font object with
-- no font set, and the first SetText against it threw "Font not set" while the window was
-- being built - so the UI would not open at all, and a relog did not help because the same
-- code ran again.
--
-- The lesson is not "write a better guard". It is that the guard was never executed against
-- the real client, and a mock that answers SetFont with `true` agrees with the mistake. Six
-- names mapping to three sizes is a cosmetic problem; a window that will not open is not, and
-- the two are not worth trading.
-- Stock templates, which the client is guaranteed to have. FONT_H1 and FONT_BODY being the
-- same object is a real flatness problem, but it is the one this codebase shipped with for
-- its whole life, and the fix for it has to be verified in the game before it goes back in.
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
