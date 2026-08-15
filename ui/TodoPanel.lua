-- ui/TodoPanel.lua
-- The "To Do" tab: everything worth doing about your gear, in the order that unblocks it.
--
-- Valuate:BuildTodoList has answered this question since it was written, and the answer only
-- ever reached a chat frame. Worse, the login line announced the list and then asked you to
-- go and type a command to read it:
--
--     [Valuate] 3 things worth doing - /valuate todo
--
-- Every item it produces already carries a `command` - it was built to be clicked from the
-- start. This is that.
--
-- The panel holds NO opinions about priority. Order, wording and what counts as worth doing
-- are all decided in BuildTodoList, which explains its own reasoning at length and is tested
-- by tools/todotest.js. Duplicating any of that here would give the addon two answers to the
-- same question, and the one on screen would be the one nobody was testing.

local _, ns = ...

local PADDING, ELEMENT_SPACING = ns.PADDING, ns.ELEMENT_SPACING
local COLORS = ns.COLORS
local BACKDROP_PANEL = ns.BACKDROP_PANEL
local FONT_H2, FONT_BODY, FONT_SMALL = ns.FONT_H2, ns.FONT_BODY, ns.FONT_SMALL

-- A FLOOR, not the height. Rows grow to fit their own text; see Refresh.
local ROW_HEIGHT = 40
local ROW_GAP = 6
local TEXT_TOP_PAD = 8
local TEXT_BOTTOM_PAD = 8
local DETAIL_GAP = 3

-- Rows are POOLED, not created per refresh.
--
-- The list is rebuilt every time the tab is opened, because a to-do list that is stale is
-- worse than none - it would have you chasing an upgrade you already equipped. Creating
-- frames on each rebuild would leak one row per visit for the whole session; WoW frames
-- cannot be destroyed, only hidden and reused.
local rowPool = {}

local function BuildRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    -- Marked so a gate can find these among the window's several hundred frames. The rows
    -- are anonymous and pooled, and identifying them by size or parent would break the
    -- moment either changed for a layout reason.
    row.__todoRow = true
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT", parent, "LEFT", 0, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    if index == 1 then
        row:SetPoint("TOP", parent, "TOP", 0, 0)
    else
        row:SetPoint("TOP", rowPool[index - 1], "BOTTOM", 0, -ROW_GAP)
    end
    row:SetBackdrop(BACKDROP_PANEL)
    row:SetBackdropColor(unpack(COLORS.panelBg))
    row:SetBackdropBorderColor(unpack(COLORS.borderDark))

    -- The accent says WHICH kind of thing this is at a glance, and is coloured per kind by
    -- Refresh. A stale scale and a free upgrade want to look different before you read them.
    local accent = row:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    row.accent = accent

    local text = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
    text:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -TEXT_TOP_PAD)
    text:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(unpack(COLORS.textTitle))
    row.text = text

    local detail = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    detail:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -DETAIL_GAP)
    detail:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    detail:SetJustifyH("LEFT")
    detail:SetTextColor(unpack(COLORS.textDim))
    row.detail = detail

    -- One button per row, running that item's own command. The command comes from the item,
    -- not from a table here: BuildTodoList decides what each entry means, and a second
    -- mapping in this file would be free to disagree with it.
    local go = ns.CreateStyledButton(row, "Show me", 96, 20)
    go:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.go = go

    -- Handlers installed ONCE, reading row.command, which Refresh updates.
    --
    -- Rows are pooled, so anything installed inside Refresh is installed again on every
    -- visit to the tab. For SetScript that merely replaces; for HookScript it CHAINS, and
    -- a row would accumulate one more tooltip handler per refresh for the whole session -
    -- invisible, because they all draw the same tooltip.
    go:SetScript("OnClick", function()
        -- Through the REAL slash handler, the same way /valuate verify drives it. Every one
        -- of these commands already prints a considered answer; routing around it to call
        -- the underlying function would put a second, untested printer on screen next to
        -- the tested one.
        local handler = SlashCmdList and SlashCmdList["VALUATE"]
        if row.command and type(handler) == "function" then
            handler((row.command:gsub("^/valuate%s*", "")))
        end
    end)
    go:HookScript("OnEnter", function(self)
        if ns.ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine(row.command or "", 1, 1, 1)
            GameTooltip:AddLine("Runs this for you, the same as typing it.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    go:HookScript("OnLeave", function() GameTooltip:Hide() end)

    rowPool[index] = row
    return row
end

function ns.CreateTodoPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)

    local title = panel:CreateFontString(nil, "OVERLAY", FONT_H2)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -PADDING)
    title:SetText("What is worth doing")
    title:SetTextColor(unpack(COLORS.textTitle))

    local subtitle = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(unpack(COLORS.textDim))
    subtitle:SetText("In the order that unblocks the rest. Refreshed each time you open this tab.")

    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -ELEMENT_SPACING * 2)
    list:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    list:SetHeight(1)

    -- Shown when there is nothing to do, which is a real answer and not an error.
    --
    -- BuildTodoList returns an empty list rather than a heading with nothing under it,
    -- deliberately: "a to-do list that always has entries is one you stop opening." The
    -- panel has to say so out loud, or an empty list reads as a panel that failed to load.
    local empty = panel:CreateFontString(nil, "OVERLAY", FONT_BODY)
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    empty:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    empty:SetJustifyH("LEFT")
    empty:SetTextColor(unpack(COLORS.textBody))
    empty:SetText("Nothing outstanding. Your gear, gems and enchants are all up to date " ..
        "for the scale you are using.")
    empty:Hide()

    -- Per-kind accent colours. Keyed by the `kind` field BuildTodoList already sets, so a
    -- new kind appearing there shows up here in the neutral colour rather than erroring -
    -- an unfamiliar entry should still be readable, just not colour-coded yet.
    local KIND_COLOR = {
        scale    = { 1.00, 0.82, 0.00 },  -- your weights are wrong; everything below depends on it
        guess    = { 1.00, 0.55, 0.10 },  -- your weights were never published, only inferred
        upgrade  = { 0.35, 0.90, 0.35 },  -- free, immediate, already in your bags
        sockets  = { 0.45, 0.70, 1.00 },  -- needs materials
        enchants = { 0.45, 0.70, 1.00 },  -- needs materials
    }
    local NEUTRAL = { 0.6, 0.6, 0.6 }

    local function Refresh()
        local items = (Valuate.BuildTodoList and Valuate:BuildTodoList()) or {}

        for i, item in ipairs(items) do
            local row = rowPool[i] or BuildRow(list, i)
            row.text:SetText(item.text or "")
            if item.detail then
                row.detail:SetText(item.detail)
                row.detail:Show()
            else
                row.detail:SetText("")
                row.detail:Hide()
            end
            ns.SetSolidColor(row.accent, unpack(KIND_COLOR[item.kind] or NEUTRAL))

            -- Data, not a closure. The handlers were installed once when the row was built
            -- and read this field, so a reused row runs the command it is CURRENTLY showing
            -- rather than the one it was first given.
            row.command = item.command

            -- Sized to what is actually in it, not to a number picked when the row was
            -- designed. ROW_HEIGHT is a floor now rather than the height.
            --
            -- These details are sentences, not labels - the one on a guessed scale runs to
            -- two hundred characters and wraps to three lines at this width. A fixed 40px
            -- row put the second and third of them outside their own backdrop, on top of
            -- whatever came next.
            local h = TEXT_TOP_PAD + row.text:GetStringHeight()
            if item.detail then
                h = h + DETAIL_GAP + row.detail:GetStringHeight()
            end
            row:SetHeight(math.max(ROW_HEIGHT, h + TEXT_BOTTOM_PAD))
            row:Show()
        end

        -- Hide the tail of the pool rather than leaving last visit's entries on screen.
        for i = #items + 1, #rowPool do
            rowPool[i]:Hide()
        end

        if #items == 0 then
            empty:Show()
            list:SetHeight(1)
        else
            empty:Hide()
            -- Summed from the rows themselves, because they no longer share a height.
            local total = 0
            for i = 1, #items do
                total = total + rowPool[i]:GetHeight() + (i > 1 and ROW_GAP or 0)
            end
            list:SetHeight(total)
        end

        return #items
    end

    Refresh()
    panel.Refresh = Refresh
    ns.RefreshTodoPanel = Refresh
    return panel
end
