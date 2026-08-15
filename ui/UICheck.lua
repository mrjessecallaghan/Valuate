-- ui/UICheck.lua
-- /valuate uicheck - the questions only the running client can answer.
--
-- Sixty-six headless gates prove a great deal about this UI: that every tab is built the same
-- way, that buttons respond to the mouse, that rows are reused rather than leaked. What they
-- cannot prove is anything about PIXELS. The harness has no font metrics and does no layout;
-- its GetStringHeight is a rough model that says so in its own comment, and its GetBottom does
-- not exist at all, because there is nothing to resolve a position against.
--
-- So the defects that survive every gate are the ones with a coordinate in them:
--
--   * text drawn outside the frame that owns it - shipped in v0.158.0a, when a to-do row was
--     a fixed 40px and the detail on a guessed scale wrapped to three lines;
--   * a tab row grown wide enough to slide under the tab at the other end;
--   * anything pushed off the edge of the screen.
--
-- Each of those is obvious in half a second of looking and invisible to everything else. This
-- walks the real window in the real client and asks about them directly, using GetTop and
-- GetBottom - which return resolved screen coordinates, and so answer exactly the question
-- the harness cannot.
--
-- It is a DIAGNOSTIC, not a gate: it reports and returns counts. Nothing acts on the result.

local _, ns = ...

-- A pixel of slack. Anchors land on fractional coordinates and a font string sitting exactly
-- on its parent's edge is correct, not broken - flagging that would make this cry wolf on
-- every panel in the addon, which is the fastest way to make a diagnostic worthless.
local SLACK = 1

-- Depth cap. The window nests about six deep; anything past this is a cycle, and a diagnostic
-- that hangs the client is worse than no diagnostic.
local MAX_DEPTH = 12

-- Resolved geometry, or nil.
--
-- GetTop and friends return nil for a frame that is hidden or has no anchor the client can
-- resolve yet. That is not a defect - a hidden panel legitimately has no position - so every
-- check here treats "no coordinates" as "nothing to say" rather than as a failure.
local function Rect(f)
    -- All four, not just one. In the client they arrive together; in a mock they need not,
    -- and a checker that assumes the rest exist because the first did is a checker that
    -- errors instead of reporting.
    if not f then return nil end
    if not (f.GetTop and f.GetBottom and f.GetLeft and f.GetRight) then return nil end
    local top, bottom, left, right = f:GetTop(), f:GetBottom(), f:GetLeft(), f:GetRight()
    if not (top and bottom and left and right) then return nil end
    return { top = top, bottom = bottom, left = left, right = right }
end

local function Describe(region, parent)
    if region.GetText and region:GetText() then
        local text = region:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        text = text:gsub("\n", " ")
        if #text > 44 then text = text:sub(1, 41) .. "..." end
        if text ~= "" then return '"' .. text .. '"' end
    end
    local name = region.GetName and region:GetName()
    if name then return name end
    local pname = parent and parent.GetName and parent:GetName()
    return (region.GetObjectType and region:GetObjectType() or "region") ..
        (pname and (" in " .. pname) or "")
end

-- Walks frames and their regions, calling visit(region, parent, isRegion).
local function Walk(frame, visit, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if not frame or depth > MAX_DEPTH or seen[frame] then return end
    seen[frame] = true

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, r in ipairs(regions) do
            if r then visit(r, frame, true) end
        end
    end
    if frame.GetChildren then
        local kids = { frame:GetChildren() }
        for _, c in ipairs(kids) do
            if c then
                visit(c, frame, false)
                Walk(c, visit, depth + 1, seen)
            end
        end
    end
end

-- quiet: measure and return, printing nothing.
--
-- For /valuate selfverify, which runs everything the addon can judge on its own and wants a
-- verdict rather than a report. It also must NOT open the window as the command form does -
-- a diagnostic that changes what is on your screen in order to inspect it is measuring
-- something you did not have.
function ns.RunUICheck(quiet)
    if not ns.ValuateUIFrame or not ns.ValuateUIFrame:IsShown() then
        if quiet then return nil, 0 end
        if Valuate.ShowUI then Valuate:ShowUI() end
    end
    local root = ns.ValuateUIFrame
    if not root then
        print("|cFFFF0000[Valuate]|r The window is not built, so there is nothing to check.")
        return 0, 0
    end

    local problems, examined = {}, 0
    local function report(what)
        problems[#problems + 1] = what
    end

    -- ---- 1. nothing is drawn outside the frame that owns it -----------------------------
    --
    -- The one that shipped. A fixed-height row and a detail line that wrapped to three put
    -- the second and third lines over whatever came next - correct in every gate, wrong on
    -- screen, and visible instantly to anyone who opened the tab.
    --
    -- Only VISIBLE things, and only where both rectangles resolve. A hidden row in a frame
    -- pool has no position and is not a defect.
    Walk(root, function(child, parent, isRegion)
        if not (child.IsShown and child:IsShown()) then return end
        if not (parent.IsShown and parent:IsShown()) then return end
        local c, p = Rect(child), Rect(parent)
        if not (c and p) then return end
        examined = examined + 1

        local over = {}
        if c.bottom < p.bottom - SLACK then over[#over + 1] = "below" end
        if c.top > p.top + SLACK then over[#over + 1] = "above" end
        if c.left < p.left - SLACK then over[#over + 1] = "left of" end
        if c.right > p.right + SLACK then over[#over + 1] = "right of" end
        if #over > 0 then
            report(string.format("%s spills %s its parent (%s)",
                isRegion and "text/texture" or "frame",
                table.concat(over, " and "), Describe(child, parent)))
        end
    end)

    -- ---- 2. nothing is off the screen ---------------------------------------------------
    --
    -- The window is clamped to the screen, but its CONTENTS are not: a panel that grew past
    -- the window, or a tab row that outgrew its row, ends up somewhere nobody can click.
    local screen = Rect(UIParent)
    if screen then
        Walk(root, function(child, _, isRegion)
            if isRegion then return end
            if not (child.IsShown and child:IsShown()) then return end
            local c = Rect(child)
            if not c then return end
            if c.right < screen.left or c.left > screen.right
               or c.top < screen.bottom or c.bottom > screen.top then
                report("a frame is off the edge of the screen (" .. Describe(child, nil) .. ")")
            end
        end)
    end

    -- ---- 3. the tab you are on is marked, and only that one -----------------------------
    --
    -- Four of six tabs had no accent texture at all until v0.156.0a, and the gate that now
    -- catches that can only see whether the texture EXISTS and what Show/Hide was called on
    -- it. Whether it is actually drawn - the draw layer, the anchor, the parent's strata -
    -- is a client question.
    local tabs = root.tabs and root.tabs.buttons
    if tabs then
        local lit, total = 0, 0
        for _, btn in pairs(tabs) do
            total = total + 1
            if btn.accent and btn.accent.IsShown and btn.accent:IsShown() then
                lit = lit + 1
                local a, b = Rect(btn.accent), Rect(btn)
                if a and b and (a.left < b.left - SLACK or a.right > b.right + SLACK) then
                    report("a tab's accent bar is wider than the tab it marks")
                end
            end
        end
        examined = examined + total
        if lit == 0 then
            report(string.format("none of the %d tabs is marked as current", total))
        elseif lit > 1 then
            report(string.format("%d of %d tabs are marked as current at once", lit, total))
        end
    end

    -- ---- 4. every button answers the mouse ----------------------------------------------
    --
    -- Same shape as the gate that found fourteen of these, but asked of the live frames: a
    -- HIGHLIGHT-layer texture is drawn by the client and needs no script, so a button has
    -- feedback if it has one of those OR a hover handler. Both are legitimate here.
    Walk(root, function(child, _, isRegion)
        if isRegion then return end
        if not (child.GetObjectType and child:GetObjectType() == "Button") then return end
        if not (child.IsShown and child:IsShown()) then return end
        if not child.GetBackdrop or not child:GetBackdrop() then return end
        examined = examined + 1

        if child.GetScript and child:GetScript("OnEnter") then return end
        local regions = { child:GetRegions() }
        for _, r in ipairs(regions) do
            if r and r.GetDrawLayer and r:GetDrawLayer() == "HIGHLIGHT" then return end
        end
        report("a button gives no sign it can be clicked (" .. Describe(child, nil) .. ")")
    end)

    -- ---- the report ----------------------------------------------------------------------
    if quiet then return #problems, examined end
    if #problems == 0 then
        print(string.format(
            "|cFF00FF00[Valuate]|r UI check: |cFF00FF00clean|r - %d things measured against the real client.",
            examined))
        print("  |cFFAAAAAAThis is the half the headless gates cannot see: real fonts, real anchors, " ..
              "real positions.|r")
    else
        print(string.format("|cFFFF8800[Valuate]|r UI check: %d problem%s in %d things measured.",
            #problems, #problems == 1 and "" or "s", examined))
        -- Deduplicated: a pooled row that is wrong is wrong in every copy, and twenty
        -- identical lines say nothing the first one did not.
        local seen, shown = {}, 0
        for _, p in ipairs(problems) do
            if not seen[p] then
                seen[p] = true
                shown = shown + 1
                if shown <= 12 then print("  |cFFFF8800-|r " .. p) end
            end
        end
        if shown > 12 then
            print(string.format("  |cFFAAAAAA...and %d more distinct.|r", shown - 12))
        end
    end

    return #problems, examined
end
