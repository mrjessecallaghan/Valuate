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

-- The sentence shown when the list is empty.
--
-- This is the most consequential sentence in the addon. An empty to-do list is not read as
-- "no rows"; it is read as "you are done", and people act on it by not acting.
--
-- It used to be fixed text: "Nothing outstanding. Your gear, gems and enchants are all up to
-- date for the scale you are using." Three specific claims, made whether or not any of the
-- three had actually been read. Mid equipment swap the sockets are not read at all, and the
-- panel cheerfully vouched for your gems.
--
-- So the claim now covers exactly what was examined, and no more. Note the wording: "among the
-- things I could check" is narrower than the old sentence and is not an apology - nothing is
-- broken, and a swap finishes on its own. Dressing a transient gap as a fault would send
-- people looking for one.
function ns.TodoEmptyText(unread)
    local all = "Nothing outstanding. Your gear, gems and enchants are all up to date " ..
        "for the scale you are using."
    if type(unread) ~= "table" or #unread == 0 then return all end
    return "Nothing outstanding among the things I could check just now - but " ..
        table.concat(unread, ", ") .. " went unread, so this is not the whole picture. " ..
        "Open this tab again in a moment."
end

-- Said on a NON-empty refresh too, and for the same reason the UI check says it: a list of
-- three jobs is just as much a statement about partial coverage as a clean bill is, and it is
-- the more dangerous of the two to over-read. You do the three things, come back, see nothing,
-- and take that as the window being finished with you.
--
-- Returns nil when everything was read, so the ordinary refresh shows no extra furniture.
function ns.TodoCoverageLine(unread)
    if type(unread) ~= "table" or #unread == 0 then return nil end
    return "Not read this refresh: " .. table.concat(unread, ", ") .. "."
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
    -- Set on every refresh by ns.TodoEmptyText, never here. A default written at build time is
    -- a claim made before anything has been looked at, which is the whole bug.
    empty:SetText("")
    empty:Hide()

    -- What went unread, shown BELOW the rows on a non-empty refresh.
    --
    -- Its own font string rather than a row: "a to-do you cannot act on is not a to-do", and a
    -- swap in flight is not something you can go and do. Putting it on the list would also put
    -- it in the tab's count, which is a number about work.
    local unreadNote = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    unreadNote:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    unreadNote:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    unreadNote:SetJustifyH("LEFT")
    unreadNote:SetTextColor(unpack(COLORS.textDim))
    unreadNote:Hide()

    -- Per-kind accent colours. Keyed by the `kind` field BuildTodoList already sets, so a
    -- new kind appearing there shows up here in the neutral colour rather than erroring -
    -- an unfamiliar entry should still be readable, just not colour-coded yet.
    local KIND_COLOR = {
        scan     = { 1.00, 0.35, 0.35 },  -- nothing below this is known yet; it is not a task, it is a blocker
        scale    = { 1.00, 0.82, 0.00 },  -- your weights are wrong; everything below depends on it
        guess    = { 1.00, 0.55, 0.10 },  -- your weights were never published, only inferred
        upgrade  = { 0.35, 0.90, 0.35 },  -- free, immediate, already in your bags
        bank     = { 0.70, 0.55, 0.95 },  -- yours already, but not from here - needs a trip
        sockets  = { 0.45, 0.70, 1.00 },  -- needs materials
        enchants = { 0.45, 0.70, 1.00 },  -- needs materials
    }
    local NEUTRAL = { 0.6, 0.6, 0.6 }

    local function Refresh()
        -- Two values, and NOT `Valuate.BuildTodoList and Valuate:BuildTodoList()`. Lua adjusts
        -- an `and` expression to a single value, so the second - which is the entire point -
        -- would silently be nil. Written that way first, here and in the to-do list itself,
        -- and caught both times.
        local items, unread = {}, nil
        if Valuate.BuildTodoList then items, unread = Valuate:BuildTodoList() end
        items = items or {}

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
            ns.FitRowHeight(row, {
                floor = ROW_HEIGHT, top = TEXT_TOP_PAD, gap = DETAIL_GAP,
                bottom = TEXT_BOTTOM_PAD,
                columns = { { row.text, row.detail } },
            })
            row:Show()
        end

        -- Hide the tail of the pool rather than leaving last visit's entries on screen.
        for i = #items + 1, #rowPool do
            rowPool[i]:Hide()
        end

        if #items == 0 then
            empty:SetText(ns.TodoEmptyText and ns.TodoEmptyText(unread) or "")
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

        -- Only on the non-empty refresh: when the list is empty the sentence above already
        -- carries it, and saying it twice on one screen reads as two different problems.
        local note = ns.TodoCoverageLine and ns.TodoCoverageLine(unread) or nil
        if note and #items > 0 then
            unreadNote:SetText(note)
            unreadNote:Show()
        else
            unreadNote:Hide()
        end

        -- Tell the tab, so the count is on it rather than only inside it.
        --
        -- Guarded because this file loads before ValuateUI.lua, which is where the tab row is
        -- built: the first Refresh runs during the panel's own construction, when there is no
        -- tab to label yet.
        if ns.SetTodoTabCount then ns.SetTodoTabCount(#items) end

        return #items
    end

    Refresh()
    panel.Refresh = Refresh
    ns.RefreshTodoPanel = Refresh
    return panel
end
