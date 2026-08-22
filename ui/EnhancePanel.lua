-- ui/EnhancePanel.lua
-- The "Enhance" tab: every slot of the gear you are wearing, and what should be on it.
--
-- A ROW PER SLOT, ALWAYS. The first version drew a row only where it had something to offer,
-- which made the panel shorter and much harder to trust: a slot you had already enchanted, a
-- slot that takes no enhancement at all, a slot whose options you have simply never been shown,
-- and a slot you are wearing nothing in all looked identical from the outside - absent. Reading
-- it told you what it had found and nothing whatsoever about what it had missed.
--
-- So every slot is listed and every row answers for itself. ns.EnhanceSlotState turns those
-- into seven distinct words, and the point of it is that they are seven and not two.
--
-- The ordering argument, which is still the whole point of the right-hand column: it recommends
-- the best it can see, and then keeps going. A +8 Armour enchant is worth having over an empty
-- slot even when it is nowhere near the best available - on a levelling character it is
-- frequently the only one affordable - so the runners-up stay on screen rather than being
-- hidden behind the winner.
--
-- WHAT IT CANNOT SHOW, and says so rather than implying otherwise:
--   * enhancements you have not learned. The data is read live from your own profession
--     windows, because no trustworthy catalogue exists for this server (see ui/Enhance.lua).
--   * WHICH enhancement is already on a slot. The item link says an enchant is present, not
--     what it is, so "already enhanced" is the most this can honestly claim - it is never a
--     statement that the one on there is the best one.
--   * where to buy a recipe and for how much. Nothing on this machine knows.
-- An empty panel therefore means "I have not been shown any yet", which is a different
-- statement from "there are none", and the panel has to draw that distinction out loud - it
-- is the mistake this project has made three separate times (see CLAUDE.md).

local _, ns = ...

local PADDING, ELEMENT_SPACING = ns.PADDING, ns.ELEMENT_SPACING
local SCROLLBAR_WIDTH = ns.SCROLLBAR_WIDTH
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
local ROW_HEIGHT = 44
local ROW_GAP = 4
local TEXT_TOP_PAD = 8
local TEXT_BOTTOM_PAD = 8
local LINE_GAP = 3
local ALTERNATIVES = 3

-- The left column is a fixed width and the right one starts AFTER it.
--
-- They used to overlap: the worn-item line was 200 wide from x=12 and the recommendation began
-- at x=110, so a long item name was drawn through the enchant it was being offered. Both are
-- OVERLAY font strings, so nothing hid it - it simply rendered on top.
local LEFT_X = 12
local LEFT_W = 190
local RIGHT_X = LEFT_X + LEFT_W + 14
local SCORE_W = 74

-- Session-scoped, not saved.
--
-- A filter you flick while looking at a panel is a way of reading it, not a preference about
-- how the addon should behave. Persisting it means opening the tab a week later and seeing a
-- filtered view you have forgotten setting - which reads as missing data rather than as a
-- filter, and sends you looking for a bug.
--
-- onlyActionable defaults OFF: the panel's job is the whole picture, and a filter that hides
-- most of it by default would put the old behaviour back under a new name.
ns.EnhanceFilters = { onlyActionable = false, source = "all" }

-- One place for what each state looks like and what it says, so a state cannot end up drawn
-- like a different one. Accent colour first, then the message that goes where a recommendation
-- would be, then whether the row carries a score at all.
local STATE_STYLE = {
    recommend = { accent = { 1.00, 0.55, 0.10 }, text = { 0.55, 0.95, 0.55 } },
    blocked   = { accent = { 0.70, 0.55, 0.35 }, text = { 0.78, 0.62, 0.40 },
                  note = "nothing you can apply at this item level" },
    -- The note is the enhanced row with nothing to suggest beside it, which happens when the
    -- profession filter hides the options for a slot that is already done. Still "enhanced" -
    -- the slot is finished either way - so the filter must not be what the row talks about.
    enhanced  = { accent = { 0.40, 0.70, 1.00 }, text = { 0.55, 0.72, 0.90 },
                  note = "already enhanced" },
    filtered  = { accent = { 0.35, 0.38, 0.45 }, text = { 0.55, 0.58, 0.65 },
                  note = "hidden by the profession filter" },
    unknown   = { accent = { 0.55, 0.50, 0.35 }, text = { 0.70, 0.66, 0.50 },
                  note = "none shown to me yet" },
    none      = { accent = { 0.28, 0.30, 0.34 }, text = { 0.45, 0.47, 0.52 },
                  note = "nothing goes here" },
    empty     = { accent = { 0.28, 0.30, 0.34 }, text = { 0.45, 0.47, 0.52 },
                  note = "nothing equipped" },
}

-- Reading order for the coverage line: what to do first, then what is done, then what cannot
-- be. Written out rather than taken from pairs(STATE_STYLE), whose order is undefined and
-- would reshuffle the summary between openings.
local COVERAGE_ORDER = {
    { state = "recommend", label = "to enhance" },
    { state = "blocked",   label = "waiting on better gear" },
    { state = "unknown",   label = "not shown to me yet" },
    { state = "enhanced",  label = "already done" },
    { state = "filtered",  label = "filtered out" },
    { state = "empty",     label = "empty" },
    { state = "none",      label = "take none" },
}

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
    slotName:SetPoint("TOPLEFT", row, "TOPLEFT", LEFT_X, -TEXT_TOP_PAD)
    slotName:SetWidth(LEFT_W)
    slotName:SetJustifyH("LEFT")
    slotName:SetTextColor(unpack(COLORS.textTitle))
    row.slotName = slotName

    -- What you are actually wearing there. The tab is about YOUR gear, and a slot named with
    -- no item beside it makes "nothing equipped" and "something equipped I could not read"
    -- look the same.
    local worn = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    worn:SetPoint("TOPLEFT", slotName, "BOTTOMLEFT", 0, -LINE_GAP)
    worn:SetWidth(LEFT_W)
    worn:SetJustifyH("LEFT")
    row.worn = worn

    -- Where you met the recipe, if you ever did. Under the item because it is a separate
    -- errand from the recommendation itself.
    local note = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    note:SetPoint("TOPLEFT", worn, "BOTTOMLEFT", 0, -LINE_GAP)
    note:SetWidth(LEFT_W)
    note:SetJustifyH("LEFT")
    note:SetTextColor(0.40, 0.53, 0.67, 1)
    row.note = note

    local best = row:CreateFontString(nil, "OVERLAY", FONT_BODY)
    best:SetPoint("TOPLEFT", row, "TOPLEFT", RIGHT_X, -TEXT_TOP_PAD)
    best:SetPoint("RIGHT", row, "RIGHT", -SCORE_W, 0)
    best:SetJustifyH("LEFT")
    row.best = best

    -- The runners-up, on the row rather than behind a click. Hiding them would undo the
    -- ordering this panel is for: the point is that second best is still worth having.
    local alts = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    alts:SetPoint("TOPLEFT", best, "BOTTOMLEFT", 0, -LINE_GAP)
    alts:SetPoint("RIGHT", row, "RIGHT", -SCORE_W, 0)
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

-- The item you are wearing, in its own quality colour, straight out of the link.
--
-- From the LINK rather than GetItemInfo: the link carries both the name and the colour and is
-- available the moment the slot is read, where GetItemInfo returns nil until the client has
-- cached the item - which on a fresh login is most of them, for a second or two, on the one
-- panel you just opened.
local function WornLabel(link)
    if type(link) ~= "string" then return nil end
    local name = link:match("|h%[(.-)%]|h")
    if not name then return "|cFF888888(could not read this item)|r" end
    local hex = link:match("|c(%x%x%x%x%x%x%x%x)")
    if hex then return "|c" .. hex .. name .. "|r" end
    return name
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

    -- The whole seventeen slots in one line, so the panel can be read without being read.
    local coverage = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    coverage:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -4)
    coverage:SetPoint("RIGHT", panel, "RIGHT", -PADDING, 0)
    coverage:SetJustifyH("LEFT")
    coverage:SetTextColor(unpack(COLORS.textBody))

    -- Filters. Two, because the data is live: everything collected is by definition something
    -- you already know how to apply, so "can I use this" is not a question that needs asking
    -- here. What is left worth filtering is how much of the list to look at, and which
    -- profession.
    local onlyActionable = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    onlyActionable:SetPoint("TOPLEFT", coverage, "BOTTOMLEFT", -2, -ELEMENT_SPACING)
    onlyActionable:SetWidth(20)
    onlyActionable:SetHeight(20)
    onlyActionable:SetChecked(ns.EnhanceFilters.onlyActionable)
    local onlyLabel = panel:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    onlyLabel:SetPoint("LEFT", onlyActionable, "RIGHT", 2, 0)
    onlyLabel:SetText("Only slots with something to do")
    onlyLabel:SetTextColor(unpack(COLORS.textBody))

    local sourceBtn = ns.CreateStyledButton(panel, "All professions", 130, 20)
    sourceBtn:SetPoint("LEFT", onlyLabel, "RIGHT", ELEMENT_SPACING * 2, 0)

    -- Seventeen rows do not fit. The old panel drew as many as it had and let the rest run off
    -- the bottom of the window, which was survivable while it was showing three.
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel)
    scrollFrame:SetPoint("TOPLEFT", onlyActionable, "BOTTOMLEFT", 2, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -SCROLLBAR_WIDTH - PADDING, PADDING)
    scrollFrame:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(1)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    local scrollBar = CreateFrame("Slider", nil, panel, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
    -- THE HANDLER FIRST, before anything that can move the value.
    --
    -- UIPanelScrollBarTemplate ships its own OnValueChanged, and that one assumes the slider's
    -- parent IS the scroll frame - it calls SetVerticalScroll straight on it. This slider is
    -- parented to the panel, because a child of the scroll frame gets clipped to it and the
    -- bar sits outside its right edge.
    --
    -- SetScript REPLACES, so once ours is installed the template's is gone and the assumption
    -- never applies. Until then it is live, and v0.177.0a called SetValue(0) one line too
    -- early: the template's handler ran, hit a plain Frame, and threw inside the panel builder.
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(20)
    scrollBar:SetValue(0)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local _, maxScroll = scrollBar:GetMinMaxValues()
        local newValue = math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 30))
        self:SetVerticalScroll(newValue)
        scrollBar:SetValue(newValue)
    end)

    -- "I have not been shown any yet" is a statement about the WHOLE panel, so it cannot live
    -- in the no-rows message any more - there are always rows now. It sat there anyway for one
    -- build, which made the most important sentence in this file unreachable: seventeen slots
    -- each saying "none shown to me yet" tells you the state but never what to do about it.
    local hint = content:CreateFontString(nil, "OVERLAY", FONT_BODY)
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    hint:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(1, 0.82, 0.4, 1)

    local list = CreateFrame("Frame", nil, content)
    list:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    list:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    list:SetHeight(1)

    -- Said out loud, because "nothing here" has two completely different meanings and this
    -- panel can genuinely be in either state.
    local empty = content:CreateFontString(nil, "OVERLAY", FONT_BODY)
    empty:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    empty:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    empty:SetJustifyH("LEFT")
    empty:SetTextColor(unpack(COLORS.textBody))
    empty:Hide()

    -- What could not be read. Never dropped: an enhancement whose slot or stats could not be
    -- worked out is still one you might want, and discarding it would make the list above
    -- look complete when it is not.
    local unreadTitle = content:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    unreadTitle:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -ELEMENT_SPACING * 2)
    unreadTitle:SetJustifyH("LEFT")
    unreadTitle:SetTextColor(1, 0.6, 0.2, 1)
    unreadTitle:Hide()

    local unreadBody = content:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    unreadBody:SetPoint("TOPLEFT", unreadTitle, "BOTTOMLEFT", 0, -2)
    unreadBody:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    unreadBody:SetJustifyH("LEFT")
    unreadBody:SetTextColor(unpack(COLORS.textDim))
    unreadBody:Hide()

    local function SourceLabel()
        local s = ns.EnhanceFilters.source
        if s == "craft" then return "Enchanting only" end
        if s == "tradeskill" then return "Crafted only" end
        return "All professions"
    end

    -- Height of the scroll child, and whether the bar can move at all. Called once at the end
    -- of a refresh, when every row has been measured.
    -- Remembered, because how far there is to scroll depends on TWO numbers and only one of
    -- them changes when the list does. The other is the height of the frame the list is being
    -- read through, and that moves on its own: the window animates to its tab height AFTER the
    -- refresh that computed the range, and it is user-resizable besides.
    --
    -- Without this the range is whatever fitted the PREVIOUS tab, so arriving at Enhance for
    -- the first time in a session left the last row or two unreachable - and dragging the
    -- window taller never gave the scroll bar the news.
    local lastContentHeight = 1

    local function ApplyScrollRange()
        content:SetWidth(math.max(1, scrollFrame:GetWidth()))
        content:SetHeight(math.max(1, lastContentHeight))
        local range = math.max(0, lastContentHeight - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, range)
        if scrollBar:GetValue() > range then scrollBar:SetValue(range) end
        -- Nothing to scroll is not the same as a bar pinned at the top. Hidden, because a
        -- scroll bar that cannot move reads as a list that failed to load.
        if range > 0 then scrollBar:Show() else scrollBar:Hide() end
    end
    panel.ApplyScrollRange = ApplyScrollRange

    local function Resize(contentHeight)
        lastContentHeight = contentHeight
        ApplyScrollRange()
    end

    -- The frame telling us itself, rather than us guessing when it might have changed.
    scrollFrame:SetScript("OnSizeChanged", ApplyScrollRange)

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
            subtitle:SetText("Every slot of the gear you are wearing.")
            coverage:SetText("")
            hint:SetText("")
            sourceBtn.label:SetText(SourceLabel())
            Resize(120)
            if ns.SetTabCount then ns.SetTabCount("enhance", 0) end
            return 0
        end

        local bySlot, unreadable = {}, {}
        if ns.CollectEnhancements then bySlot, unreadable = ns.CollectEnhancements() end

        -- Has anything at all been collected? Read ONCE, because two places need it and the
        -- distinction it carries - "I have not looked" against "there are none" - is the one
        -- this project has got wrong three separate times. Two copies of the test is two
        -- chances for half the panel to answer the other question.
        local anyKnown = false
        for _ in pairs(bySlot) do anyKnown = true break end

        local shown, actionable = 0, 0
        local counts = {}
        for _, def in ipairs(ns.EQUIP_SLOTS or {}) do
            local worn = GetInventoryItemLink and GetInventoryItemLink("player", def.slotId)
            -- The worn item's EFFECTIVE level, so an enchant needing more than it sorts
            -- below the ones you can actually apply. Read from the tooltip rather than from
            -- GetItemInfo, because on a scaling server those are different numbers - see
            -- ns.WornItemLevel. Nil counts as "no constraint I could read", not "level 0".
            local wornLevel = worn and ns.WornItemLevel(def.slotId) or nil
            local all = ns.RankForSlot(bySlot, def.slotId, scale, scaleName, wornLevel)

            -- Filtered and unfiltered are BOTH kept, and the difference between them is a
            -- state of its own. Counting only what survives the profession filter would make
            -- an enchanting slot report "none shown to me yet" while you were looking at a
            -- crafted-only view - sending you off to open a profession window you have
            -- already opened, to find something the addon already had.
            local ranked = all
            if ns.EnhanceFilters.source ~= "all" then
                ranked = {}
                for _, r in ipairs(all) do
                    if r.entry.source == ns.EnhanceFilters.source then ranked[#ranked + 1] = r end
                end
            end

            local usable = 0
            for _, r in ipairs(ranked) do
                if not r.tooHigh then usable = usable + 1 end
            end

            -- Field two of an item link is its enchant; zero means none. The cheapest check
            -- in the addon, and the same one FindMissingEnchants uses.
            local enchantId = worn and tonumber(worn:match("|?H?item:%d+:(%d+)") or "") or nil

            local state = ns.EnhanceSlotState({
                slotId = def.slotId,
                hasItem = worn ~= nil,
                hasEnchant = (enchantId or 0) > 0,
                known = #all,
                shown = #ranked,
                usable = usable,
            })
            counts[state] = (counts[state] or 0) + 1
            if ns.EnhanceStateIsActionable(state) then actionable = actionable + 1 end

            if not (ns.EnhanceFilters.onlyActionable and not ns.EnhanceStateIsActionable(state)) then
                shown = shown + 1
                local row = rowPool[shown] or BuildRow(list, shown)
                local style = STATE_STYLE[state] or STATE_STYLE.none

                row.slotName:SetText(def.name)
                row.worn:SetText(WornLabel(worn) or "|cFF666666nothing equipped|r")

                -- A top only exists where there is something to rank, and "enhanced" is the
                -- one state that can arrive without one - the slot is done, and the filter is
                -- hiding what would otherwise be suggested for it. Every other state puts its
                -- own sentence in the same place, so the column is never blank and never
                -- reuses the previous slot's text.
                local top = ranked[1]
                if top and (state == "recommend" or state == "blocked" or state == "enhanced") then
                    local prefix, suffix = "", ""
                    if state == "enhanced" then
                        -- Never "you already have the best one". The link says an enchant is
                        -- present, not which, so the most this can honestly offer is what it
                        -- would pick if the slot were bare.
                        prefix = "|cFF888888already enhanced|r  ·  "
                        suffix = " |cFF888888- best I know for this slot|r"
                    end
                    if top.tooHigh then
                        suffix = string.format(" |cFFFF8800(needs item level %d)|r",
                            top.entry.reqLevel or 0)
                    end
                    row.best:SetText(prefix .. top.entry.name .. suffix)
                    -- The estimate is admitted on the row, not buried in a tooltip. A number
                    -- partly derived from someone's judgement about movement speed should not
                    -- sit in the same column as one derived from your own stat weights in
                    -- silence.
                    row.score:SetText(string.format("%s%.0f|r",
                        top.estimated and "|cFFFFCC66~" or "|cFFFFFFFF", top.score))
                else
                    row.best:SetText(style.note or "")
                    row.score:SetText("")
                end
                row.best:SetTextColor(style.text[1], style.text[2], style.text[3], 1)

                -- Where you met it, if you ever did. Nothing on this machine knows where
                -- recipes are sold, so this is only ever a note taken while standing in
                -- front of one - and its absence means "I have not seen this for sale",
                -- never "this is not sold anywhere".
                local noteText = ""
                if top and ns.LookupVendorNote then
                    local cost, seller, where = ns.LookupVendorNote(top.entry.name)
                    if seller or where then
                        noteText = (seller or "?") .. (where and (", " .. where) or "") ..
                            (cost and cost > 0 and string.format(" (%.0fg)", cost / 10000) or "")
                    end
                end
                row.note:SetText(noteText)

                local rest = {}
                for i = 2, math.min(#ranked, ALTERNATIVES + 1) do
                    -- A demoted enchant says WHY it is down here. Without that it reads as a
                    -- lower-scoring option, and the strongest enchant in the list sitting
                    -- third for no visible reason is worse than not showing it at all.
                    local alt = ranked[i]
                    rest[#rest + 1] = alt.tooHigh
                        and string.format("%s (needs item level %d)",
                            alt.entry.name, alt.entry.reqLevel or 0)
                        or string.format("%s (%.0f)", alt.entry.name, alt.score)
                end
                if #ranked > ALTERNATIVES + 1 then
                    rest[#rest + 1] = string.format("and %d more", #ranked - ALTERNATIVES - 1)
                end
                row.alts:SetText(#rest > 0 and ("then: " .. table.concat(rest, "  ·  ")) or "")

                ns.SetSolidColor(row.accent, style.accent[1], style.accent[2], style.accent[3])

                -- Measured against BOTH columns, taking the taller.
                --
                -- They are independent: the left one is the slot, the item on it and where you
                -- saw the recipe, the right one is the recommendation and its runners-up.
                -- Either can be the one that wraps, and sizing to only one of them puts the
                -- other through the bottom of the row - which is how this shipped.
                ns.FitRowHeight(row, {
                    floor = ROW_HEIGHT, top = TEXT_TOP_PAD, gap = LINE_GAP,
                    bottom = TEXT_BOTTOM_PAD,
                    columns = {
                        { row.slotName, row.worn, row.note },
                        { row.best, row.alts },
                    },
                })
                row:Show()
            end
        end

        for i = shown + 1, #rowPool do rowPool[i]:Hide() end

        -- Shown whatever the rows say, because it is the answer to "why is every slot blank"
        -- and no per-slot line can carry it.
        -- Where this came from, and how long ago.
        --
        -- A snapshot is not live data and must never be presented as though it were: if you
        -- learned an enchant on another character, or unlearned a profession, or the client
        -- simply named something differently that day, the list is a record of what was true
        -- once. Saying WHEN is the whole difference between a cache and a claim.
        if not anyKnown then
            -- The advice names THEIR professions, or says plainly that none of them makes
            -- anything that goes on gear. "Open a crafting profession" is useless to a
            -- miner-skinner, and worse than useless: it implies the feature would work if
            -- they went and did something, when for them it never will.
            hint:SetText("I have not been shown any enhancements yet.\n\n" ..
                (ns.EnhanceAdviceText and ns.EnhanceAdviceText() or "") ..
                "\n\nRun /valuate enhancecheck to see what this client will tell me.")
        else
            local books = ns.SnapshotBooks and ns.SnapshotBooks() or {}
            if #books > 0 then
                local names = {}
                for i = 1, math.min(#books, 4) do
                    names[#names + 1] = string.format("%s (%d)", books[i].name, books[i].count)
                end
                if #books > 4 then
                    names[#names + 1] = string.format("and %d more", #books - 4)
                end
                local age = ns.SnapshotAge and ns.SnapshotAge() or nil
                hint:SetText(string.format("Read from %s%s.  |cFF888888Open the window again " ..
                    "any time to refresh it.|r",
                    table.concat(names, ", "),
                    age and (", " .. ns.DescribeAge(age)) or ""))
            else
                hint:SetText("")
            end
        end

        local listHeight = 1
        if shown == 0 then
            empty:Show()
            -- The distinction, again. Not knowing any enhancements and having every slot
            -- already done are opposite states that both empty the list, and the second
            -- sentence is a lie in the first case: nothing is "already enhanced" on a
            -- character whose professions have never been opened.
            if not anyKnown then
                empty:SetText("Nothing to act on, because I have not been shown any " ..
                    "enhancements yet - see above.")
            else
                empty:SetText("Nothing to do: every slot is either already enhanced, takes " ..
                    "no enhancement, or has none I can offer at your item level. Untick " ..
                    "'Only slots with something to do' to see all of them.")
            end
        else
            empty:Hide()
            listHeight = 0
            for i = 1, shown do
                listHeight = listHeight + rowPool[i]:GetHeight() + (i > 1 and ROW_GAP or 0)
            end
        end
        list:SetHeight(listHeight)

        local extra = 0
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
            extra = ELEMENT_SPACING * 2 + unreadTitle:GetStringHeight() +
                unreadBody:GetStringHeight() + 2
        else
            unreadTitle:Hide()
            unreadBody:Hide()
        end

        -- Only the states that happened. A summary listing six categories at zero reads as a
        -- form to fill in rather than as a description of your character.
        local parts = {}
        for _, item in ipairs(COVERAGE_ORDER) do
            local n = counts[item.state]
            if n and n > 0 then
                parts[#parts + 1] = string.format("%d %s", n, item.label)
            end
        end
        coverage:SetText(string.format("%d slots: %s", #(ns.EQUIP_SLOTS or {}),
            #parts > 0 and table.concat(parts, "  ·  ") or "nothing read"))

        subtitle:SetText(string.format(
            "Every slot of the gear you are wearing, scored by %s. Best first, then what is " ..
            "still better than nothing.", scaleName or "no scale"))
        sourceBtn.label:SetText(SourceLabel())
        -- The hint is inside the scroll child, so it is part of how far there is to scroll.
        -- Leaving it out is how the last row ends up unreachable on exactly the character
        -- that most needs to read the panel.
        Resize(hint:GetStringHeight() + ELEMENT_SPACING + listHeight + extra + PADDING)

        -- On the tab, so you can see whether it is worth opening. Same argument as To Do: the
        -- count lives in here and the tab was the one place it was not shown.
        --
        -- ACTIONABLE, not shown. Now that every slot has a row, the row count is seventeen
        -- forever and says nothing at all - a tab badge that never changes is a decoration.
        if ns.SetTabCount then ns.SetTabCount("enhance", actionable) end

        return actionable
    end

    onlyActionable:SetScript("OnClick", function(self)
        ns.EnhanceFilters.onlyActionable = self:GetChecked() and true or false
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
