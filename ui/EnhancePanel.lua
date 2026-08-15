-- ui/EnhancePanel.lua
-- The "Enhance" tab: what each slot you are WEARING could still have on it.
--
-- Scoped to the gear you have equipped for your current scale, not to gear in general. An
-- enchant list for items you are not wearing is a shopping catalogue; this is a to-do list.
--
-- The ordering argument, which is the whole point: it recommends the best it can see, and
-- then keeps going. A +8 Armour enchant is worth having over an empty slot even when it is
-- nowhere near the best available - on a levelling character it is frequently the only one
-- affordable - so the runners-up stay on screen rather than being hidden behind the winner.
--
-- WHAT IT CANNOT SHOW, and says so rather than implying otherwise:
--   * enhancements you have not learned. The data is read live from your own profession
--     windows, because no trustworthy catalogue exists for this server (see ui/Enhance.lua).
--   * where to buy a recipe and for how much. Nothing on this machine knows.
-- An empty panel therefore means "I have not been shown any yet", which is a different
-- statement from "there are none", and the panel has to draw that distinction out loud - it
-- is the mistake this project has made three separate times (see CLAUDE.md).

local _, ns = ...

local PADDING, ELEMENT_SPACING = ns.PADDING, ns.ELEMENT_SPACING
local COLORS = ns.COLORS
local BACKDROP_PANEL = ns.BACKDROP_PANEL
local FONT_H2, FONT_BODY, FONT_SMALL = ns.FONT_H2, ns.FONT_BODY, ns.FONT_SMALL

-- A FLOOR, not the height. Rows are measured against their own text; see Refresh.
--
-- This was the height, flat, and it is the same defect fixed in the To Do panel three
-- releases ago (v0.159.0a) - written again, by me, in a file created after that fix. Both
-- columns here wrap: the left one gained a vendor note (a seller, a subzone, a zone and a
-- price) and the right one lists three alternatives with their scores. At these widths either
-- runs to two or three lines, and a fixed row draws the rest of them over whatever is below.
local ROW_HEIGHT = 46
local ROW_GAP = 4
local TEXT_TOP_PAD = 8
local TEXT_BOTTOM_PAD = 8
local LINE_GAP = 3
local ALTERNATIVES = 3

-- Session-scoped, not saved.
--
-- A filter you flick while looking at a panel is a way of reading it, not a preference about
-- how the addon should behave. Persisting it means opening the tab a week later and seeing a
-- filtered view you have forgotten setting - which reads as missing data rather than as a
-- filter, and sends you looking for a bug.
ns.EnhanceFilters = { onlyMissing = true, source = "all" }

local rowPool = {}

local function BuildRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row.__enhanceRow = true
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

    local accent = row:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    row.accent = accent

    local slotName = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
    slotName:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -TEXT_TOP_PAD)
    slotName:SetWidth(90)
    slotName:SetJustifyH("LEFT")
    slotName:SetTextColor(unpack(COLORS.textTitle))
    row.slotName = slotName

    local current = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    current:SetPoint("TOPLEFT", slotName, "BOTTOMLEFT", 0, -LINE_GAP)
    current:SetWidth(200)
    current:SetJustifyH("LEFT")
    row.current = current

    local best = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
    best:SetPoint("TOPLEFT", row, "TOPLEFT", 110, -TEXT_TOP_PAD)
    best:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    best:SetJustifyH("LEFT")
    row.best = best

    -- The runners-up, on the row rather than behind a click. Hiding them would undo the
    -- ordering this panel is for: the point is that second best is still worth having.
    local alts = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    alts:SetPoint("TOPLEFT", best, "BOTTOMLEFT", 0, -LINE_GAP)
    alts:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    alts:SetJustifyH("LEFT")
    alts:SetTextColor(unpack(COLORS.textDim))
    row.alts = alts

    local score = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
    score:SetPoint("RIGHT", row, "RIGHT", -12, 0)
    score:SetJustifyH("RIGHT")
    row.score = score

    rowPool[index] = row
    return row
end

function ns.CreateEnhancePanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetAllPoints(parent)

    local title = panel:CreateFontString(nil, "OVERLAY", FONT_H2)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -PADDING)
    title:SetText("Enhancements")
    title:SetTextColor(unpack(COLORS.textTitle))

    local subtitle = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(unpack(COLORS.textDim))

    -- Filters. Two, because the data is live: everything collected is by definition something
    -- you already know how to apply, so "can I use this" is not a question that needs asking
    -- here. What is left worth filtering is which slots to look at, and which profession.
    local onlyMissing = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    onlyMissing:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -ELEMENT_SPACING)
    onlyMissing:SetWidth(20)
    onlyMissing:SetHeight(20)
    onlyMissing:SetChecked(ns.EnhanceFilters.onlyMissing)
    local onlyMissingLabel = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    onlyMissingLabel:SetPoint("LEFT", onlyMissing, "RIGHT", 2, 0)
    onlyMissingLabel:SetText("Only slots without one")
    onlyMissingLabel:SetTextColor(unpack(COLORS.textBody))

    local sourceBtn = ns.CreateStyledButton(panel, "All professions", 130, 20)
    sourceBtn:SetPoint("LEFT", onlyMissingLabel, "RIGHT", ELEMENT_SPACING * 2, 0)

    local list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", onlyMissing, "BOTTOMLEFT", 2, -ELEMENT_SPACING)
    list:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    list:SetHeight(1)

    -- Said out loud, because "nothing here" has two completely different meanings and this
    -- panel can genuinely be in either state.
    local empty = panel:CreateFontString(nil, "OVERLAY", FONT_BODY)
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    empty:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    empty:SetJustifyH("LEFT")
    empty:SetTextColor(unpack(COLORS.textBody))
    empty:Hide()

    -- What could not be read. Never dropped: an enhancement whose slot or stats could not be
    -- worked out is still one you might want, and discarding it would make the list above
    -- look complete when it is not.
    local unreadTitle = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    unreadTitle:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -ELEMENT_SPACING * 2)
    unreadTitle:SetJustifyH("LEFT")
    unreadTitle:SetTextColor(1, 0.6, 0.2, 1)
    unreadTitle:Hide()

    local unreadBody = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    unreadBody:SetPoint("TOPLEFT", unreadTitle, "BOTTOMLEFT", 0, -2)
    unreadBody:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    unreadBody:SetJustifyH("LEFT")
    unreadBody:SetTextColor(unpack(COLORS.textDim))
    unreadBody:Hide()

    local function SourceLabel()
        local s = ns.EnhanceFilters.source
        if s == "craft" then return "Enchanting only" end
        if s == "tradeskill" then return "Crafted only" end
        return "All professions"
    end

    local function Refresh()
        local scale, scaleName = nil, nil
        if Valuate.GetPrimaryScale then scale, scaleName = Valuate:GetPrimaryScale() end

        -- No scale, no ranking.
        --
        -- Every score on this panel is your stat weights applied to an enchant. With no active
        -- scale there are no weights, so everything lands on the same number and the list
        -- falls back to its tiebreaker - which is alphabetical, and would sit under a heading
        -- promising "best first". A confident ordering built on nothing.
        --
        -- Said as the whole answer rather than a note in the subtitle, because the ordering IS
        -- the panel: with nothing to rank by there is nothing here worth reading. The To Do
        -- tab draws the same line for the same reason.
        if not scaleName then
            for i = 1, #rowPool do rowPool[i]:Hide() end
            unreadTitle:Hide()
            unreadBody:Hide()
            list:SetHeight(1)
            empty:SetText("No active scale, so there is nothing to rank these against.\n\n" ..
                "Every number here is your own stat weights applied to an enchant. Pick or " ..
                "build a scale first - /valuate wizard - and this becomes a ranking rather " ..
                "than a list.")
            empty:Show()
            subtitle:SetText("For the gear you are wearing.")
            sourceBtn.label:SetText(SourceLabel())
            if ns.SetTabCount then ns.SetTabCount("enhance", 0) end
            return 0
        end

        local bySlot, unreadable = {}, {}
        if ns.CollectEnhancements then bySlot, unreadable = ns.CollectEnhancements() end

        local shown, offered = 0, 0
        for _, def in ipairs(ns.EQUIP_SLOTS or {}) do
            local worn = GetInventoryItemLink and GetInventoryItemLink("player", def.slotId)
            local ranked = ns.RankForSlot(bySlot, def.slotId, scale, scaleName)

            -- Filter by profession BEFORE deciding whether the row is worth showing, or a
            -- slot whose only options are all filtered out still takes up a line saying
            -- nothing.
            if ns.EnhanceFilters.source ~= "all" then
                local kept = {}
                for _, r in ipairs(ranked) do
                    if r.entry.source == ns.EnhanceFilters.source then kept[#kept + 1] = r end
                end
                ranked = kept
            end

            -- Field two of an item link is its enchant; zero means none. The cheapest check
            -- in the addon, and the same one FindMissingEnchants uses.
            local enchantId = worn and tonumber(worn:match("|?H?item:%d+:(%d+)") or "") or nil
            local hasOne = (enchantId or 0) > 0

            local wanted = worn ~= nil and #ranked > 0
            if wanted and ns.EnhanceFilters.onlyMissing and hasOne then wanted = false end

            if wanted then
                offered = offered + 1
                shown = shown + 1
                local row = rowPool[shown] or BuildRow(list, shown)
                row.slotName:SetText(def.name)
                row.current:SetText(hasOne and "|cFF888888already enhanced|r"
                    or "|cFFFF8800nothing on it|r")

                local top = ranked[1]
                row.best:SetText(top.entry.name)
                row.best:SetTextColor(0.55, 0.95, 0.55, 1)
                -- The estimate is admitted on the row, not buried in a tooltip. A number
                -- partly derived from someone's judgement about movement speed should not sit
                -- in the same column as one derived from your own stat weights in silence.
                row.score:SetText(string.format("%s%.0f|r",
                    top.estimated and "|cFFFFCC66~" or "|cFFFFFFFF", top.score))

                -- Where you met it, if you ever did. Nothing on this machine knows where
                -- recipes are sold, so this is only ever a note taken while standing in
                -- front of one - and its absence means "I have not seen this for sale",
                -- never "this is not sold anywhere".
                local cost, seller, where = nil, nil, nil
                if ns.LookupVendorNote then cost, seller, where = ns.LookupVendorNote(top.entry.name) end
                if seller or where then
                    row.current:SetText(row.current:GetText() .. "  |cFF6688AA" ..
                        (seller or "?") .. (where and (", " .. where) or "") ..
                        (cost and cost > 0 and string.format(" (%.0fg)", cost / 10000) or "") .. "|r")
                end

                local rest = {}
                for i = 2, math.min(#ranked, ALTERNATIVES + 1) do
                    rest[#rest + 1] = string.format("%s (%.0f)", ranked[i].entry.name, ranked[i].score)
                end
                if #ranked > ALTERNATIVES + 1 then
                    rest[#rest + 1] = string.format("and %d more", #ranked - ALTERNATIVES - 1)
                end
                row.alts:SetText(#rest > 0 and ("then: " .. table.concat(rest, "  ·  ")) or "")

                ns.SetSolidColor(row.accent, hasOne and 0.45 or 1.0, hasOne and 0.7 or 0.55,
                    hasOne and 1.0 or 0.1)

                -- Measured against BOTH columns, taking the taller.
                --
                -- They are independent: the left one is the slot and where you saw the
                -- recipe, the right one is the recommendation and its runners-up. Either can
                -- be the one that wraps, and sizing to only one of them puts the other
                -- through the bottom of the row - which is how this shipped.
                ns.FitRowHeight(row, {
                    floor = ROW_HEIGHT, top = TEXT_TOP_PAD, gap = LINE_GAP,
                    bottom = TEXT_BOTTOM_PAD,
                    columns = {
                        { row.slotName, row.current },
                        { row.best, row.alts },
                    },
                })
                row:Show()
            end
        end

        for i = shown + 1, #rowPool do rowPool[i]:Hide() end

        if shown == 0 then
            empty:Show()
            -- The distinction. Not knowing any enhancements and having every slot already
            -- done are opposite states that both produce an empty list.
            local any = false
            for _ in pairs(bySlot) do any = true break end
            if not any then
                empty:SetText("I have not been shown any enhancements yet.\n\n" ..
                    "They are read from your own profession windows while they are open - " ..
                    "open Enchanting or a crafting profession and come back. Run " ..
                    "/valuate enhancecheck to see what this client will tell me.")
            elseif ns.EnhanceFilters.onlyMissing then
                empty:SetText("Every slot that has an option already has an enhancement on " ..
                    "it. Untick 'Only slots without one' to see what else you could put on.")
            else
                empty:SetText("Nothing I know applies to the gear you are wearing.")
            end
            list:SetHeight(1)
        else
            empty:Hide()
            local total = 0
            for i = 1, shown do
                total = total + rowPool[i]:GetHeight() + (i > 1 and ROW_GAP or 0)
            end
            list:SetHeight(total)
        end

        if unreadable and #unreadable > 0 then
            unreadTitle:SetText(string.format("%d I could not read", #unreadable))
            local names = {}
            for i = 1, math.min(#unreadable, 6) do
                names[#names + 1] = unreadable[i].name .. " (" .. unreadable[i].why .. ")"
            end
            if #unreadable > 6 then
                names[#names + 1] = string.format("and %d more", #unreadable - 6)
            end
            unreadBody:SetText(table.concat(names, "\n"))
            unreadTitle:Show()
            unreadBody:Show()
        else
            unreadTitle:Hide()
            unreadBody:Hide()
        end

        subtitle:SetText(string.format(
            "For the gear you are wearing, scored by %s. Best first, then what is still " ..
            "better than nothing.", scaleName or "no scale"))
        sourceBtn.label:SetText(SourceLabel())

        -- On the tab, so you can see whether it is worth opening. Same argument as To Do:
        -- the count lives in here and the tab was the one place it was not shown.
        if ns.SetTabCount then ns.SetTabCount("enhance", offered) end

        return offered
    end

    onlyMissing:SetScript("OnClick", function(self)
        ns.EnhanceFilters.onlyMissing = self:GetChecked() and true or false
        Refresh()
    end)
    sourceBtn:SetScript("OnClick", function()
        local order = { all = "craft", craft = "tradeskill", tradeskill = "all" }
        ns.EnhanceFilters.source = order[ns.EnhanceFilters.source] or "all"
        Refresh()
    end)

    Refresh()
    panel.Refresh = Refresh
    ns.RefreshEnhancePanel = Refresh
    return panel
end
