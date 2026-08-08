-- ui/InfoPanels.lua
-- The three read-only content tabs: Instructions, About and Changelog.
--
-- Self-contained: they build static content from the design tokens and hold no state
-- that anything else touches, so they were among the safest panels to lift out.
-- Published on the namespace for ValuateUI.lua's ShowUI to call.

local _, ns = ...

local PADDING, ELEMENT_SPACING = ns.PADDING, ns.ELEMENT_SPACING
local SCROLLBAR_WIDTH = ns.SCROLLBAR_WIDTH
local COLORS = ns.COLORS
local BACKDROP_PANEL, BACKDROP_WINDOW = ns.BACKDROP_PANEL, ns.BACKDROP_WINDOW
local FONT_TITLE, FONT_H1, FONT_H2, FONT_H3, FONT_BODY, FONT_SMALL =
    ns.FONT_TITLE, ns.FONT_H1, ns.FONT_H2, ns.FONT_H3, ns.FONT_BODY, ns.FONT_SMALL
local CreateStyledButton = ns.CreateStyledButton
local ShowTooltipSafe = ns.ShowTooltipSafe

-- ========================================
-- Instructions Panel
-- ========================================

local function CreateInstructionsPanel(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Scroll frame for instructions content
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", PADDING, -PADDING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SCROLLBAR_WIDTH - PADDING, PADDING)
    scrollFrame:SetBackdrop(BACKDROP_PANEL)
    scrollFrame:SetBackdropColor(unpack(COLORS.panelBg))
    scrollFrame:SetBackdropBorderColor(unpack(COLORS.borderDark))
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newValue = current - (delta * 30)
        newValue = math.max(0, math.min(maxScroll, newValue))
        self:SetVerticalScroll(newValue)
        if scrollFrame.scrollBar then
            scrollFrame.scrollBar:SetValue(newValue)
        end
    end)
    
    -- Content frame for text
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(scrollFrame:GetWidth() - PADDING * 2)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -PADDING, PADDING)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(unpack(COLORS.windowBg))
    scrollBarBg:SetBackdropBorderColor(unpack(COLORS.borderDark))
    
    -- Scrollbar
    local scrollBar = CreateFrame("Slider", nil, scrollBarBg, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollBarBg, "TOPLEFT", 2, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollBarBg, "BOTTOMRIGHT", -2, 16)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(20)
    scrollBar.scrollFrame = scrollFrame
    scrollBar:SetScript("OnValueChanged", function(self, value)
        if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
            self.scrollFrame:SetVerticalScroll(value)
        end
    end)
    scrollBar:SetValue(0)
    scrollFrame.scrollBar = scrollBar
    
    -- Helper function to create a section header
    local function CreateSectionHeader(text, yOffset)
        local header = contentFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
        header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        header:SetPoint("RIGHT", contentFrame, "RIGHT", -PADDING, 0)
        header:SetJustifyH("LEFT")
        header:SetText(text)
        header:SetTextColor(unpack(COLORS.textAccent))
        return header
    end
    
    -- Helper function to create body text
    local function CreateBodyText(text, yOffset, width)
        local body = contentFrame:CreateFontString(nil, "OVERLAY", FONT_BODY)
        body:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        body:SetWidth(width or (contentFrame:GetWidth() - PADDING * 2))
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetText(text)
        body:SetTextColor(unpack(COLORS.textBody))
        return body
    end
    
    -- Build instructions content
    local currentY = -PADDING
    local lineHeight = 16
    local sectionSpacing = 20
    local paragraphSpacing = 8
    
    -- What Are Stat Weights?
    local header0 = CreateSectionHeader("What Are Stat Weights?", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text0a = CreateBodyText("Stat weights are numerical values that represent how valuable each stat is to your character. They help you objectively compare different pieces of gear by calculating a single score for each item based on its stats.", currentY)
    local text0aHeight = text0a:GetStringHeight()
    currentY = currentY - text0aHeight - paragraphSpacing
    
    local text0b = CreateBodyText("For example, if Attack Power is twice as valuable to you as Stamina, you might set Attack Power = 2.0 and Stamina = 1.0. The actual numbers don't matter—only the ratios between them. This means Attack Power = 2.0, Stamina = 1.0 is the same as Attack Power = 1.0, Stamina = 0.5.", currentY)
    local text0bHeight = text0b:GetStringHeight()
    currentY = currentY - text0bHeight - paragraphSpacing
    
    local text0c = CreateBodyText("How Valuate Calculates Scores:\nValuate multiplies each stat on an item by its weight, then adds them all together:\n\nScore = (Stat1 × Weight1) + (Stat2 × Weight2) + (Stat3 × Weight3) + ...\n\nFor example, an item with +10 Strength and +20 Stamina, using weights of Strength = 1.5 and Stamina = 1.0, would get a score of:\n(10 × 1.5) + (20 × 1.0) = 15 + 20 = 35", currentY)
    local text0cHeight = text0c:GetStringHeight()
    currentY = currentY - text0cHeight - paragraphSpacing
    
    local text0d = CreateBodyText("Higher scores always mean better items for that particular scale. When comparing two items, the one with the higher score is the better choice according to your stat weights.", currentY)
    local text0dHeight = text0d:GetStringHeight()
    currentY = currentY - text0dHeight - paragraphSpacing
    
    local text0e = CreateBodyText("Best Practices:\n• Set weights based on relative value—if Strength is worth 50% more than Stamina, use Strength = 1.5 and Stamina = 1.0\n• Create separate scales for different roles or builds (e.g., 'Fury DPS', 'Protection Tank', 'PvP')\n• Use the 'ban' checkbox for stats that are completely useless to a build (like Intellect for Warriors)\n• Start with simple weights and refine them as you learn what works for your character\n• Remember that stat weights can change based on your current gear, talents, and playstyle", currentY)
    local text0eHeight = text0e:GetStringHeight()
    currentY = currentY - text0eHeight - paragraphSpacing
    
    local text0f = CreateBodyText("Using Scores to Make Decisions:\nWhen you hover over an item in-game, Valuate displays scores for each of your active scales in the tooltip. Compare these scores with your currently equipped item to see if the new item is an upgrade. Green borders indicate upgrades, red borders indicate downgrades.", currentY)
    local text0fHeight = text0f:GetStringHeight()
    currentY = currentY - text0fHeight - sectionSpacing
    
    -- Getting Started
    local header1 = CreateSectionHeader("Getting Started", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text1 = CreateBodyText("Open the Valuate UI by typing /valuate or /val in chat. The window can be moved by dragging the title bar.", currentY)
    local text1Height = text1:GetStringHeight()
    currentY = currentY - text1Height - sectionSpacing
    
    -- Managing Scales
    local header2 = CreateSectionHeader("Managing Scales", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text2 = CreateBodyText("• Create a new scale: Click the 'New Scale' button in the left panel.\n• Rename a scale: Select it, then edit the 'Scale Name' field at the top of the editor.\n• Delete a scale: Click the × button on a scale in the list.\n• Select a scale: Click on it in the left panel to edit its stat weights.", currentY)
    local text2Height = text2:GetStringHeight()
    currentY = currentY - text2Height - sectionSpacing
    
    -- Setting Stat Weights
    local header3 = CreateSectionHeader("Setting Stat Weights", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text3 = CreateBodyText("To set a stat weight, click in the value field next to the stat name and enter a number. IMPORTANT: Press Enter after typing the value to save it. The value will not be saved until you press Enter.", currentY)
    local text3Height = text3:GetStringHeight()
    currentY = currentY - text3Height - paragraphSpacing
    
    local text3b = CreateBodyText("Stats are organized into categories (Primary Stats, Secondary Stats, etc.) and displayed in columns. You can set weights for any stat that applies to your character.", currentY)
    local text3bHeight = text3b:GetStringHeight()
    currentY = currentY - text3bHeight - sectionSpacing
    
    -- Visibility and Colors
    local header4 = CreateSectionHeader("Visibility and Colors", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text4 = CreateBodyText("• Toggle visibility: Use the checkbox on the left of each scale to show or hide it in item tooltips.\n• Change color: Click the colored square next to the visibility checkbox to open a color picker. This color is used to display the scale name in tooltips.", currentY)
    local text4Height = text4:GetStringHeight()
    currentY = currentY - text4Height - sectionSpacing
    
    -- Banning Stats
    local header5 = CreateSectionHeader("Banning Stats", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text5 = CreateBodyText("If a stat is unusable for a particular scale (e.g., Intellect for a Warrior), check the box to the right of the stat value field. Banned stats will be grayed out and items with those stats won't show a score for that scale.", currentY)
    local text5Height = text5:GetStringHeight()
    currentY = currentY - text5Height - sectionSpacing
    
    -- Tooltip Display
    local header6 = CreateSectionHeader("Tooltip Display", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text6 = CreateBodyText("When you hover over an item, Valuate displays the calculated score for each visible scale. The score is based on the item's stats multiplied by your scale weights. Higher scores indicate better items for that scale.", currentY)
    local text6Height = text6:GetStringHeight()
    currentY = currentY - text6Height - sectionSpacing
    
    -- Settings Options
    local header7 = CreateSectionHeader("Settings Options", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text7 = CreateBodyText("There are a lot of these, so the box at the top of the Settings tab filters them: type part of a name and everything else dims. Nothing moves while you filter.\n\n• Decimal Places: Control how many decimal places are shown in scores (0-4).\n• Right-Align Scores: When enabled, scores align to the right in tooltips for easier comparison.\n• Show Scale Value: Toggle whether the item's calculated score appears on tooltips.\n• Normalize Display: When enabled, all scores are normalized (highest stat weight = 1.0) for easier comparison across scales.\n• Comparison Mode: Choose how upgrade/downgrade differences are displayed (Number, Percentage, Both, or Off).", currentY)
    local text7Height = text7:GetStringHeight()
    currentY = currentY - text7Height - sectionSpacing
    
    -- Per-Character Profiles
    local header8 = CreateSectionHeader("Per-Character Profiles", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text8 = CreateBodyText("Starting in version 0.7.0, all settings and scales are saved per-character. This means:\n• Each character has completely independent scales and settings\n• Changes on one character don't affect your other characters\n• You can have different scales for different characters (e.g., DPS scales on your DPS character, tank scales on your tank)\n\nScale Library:\nBecause scales are per-character, a new character starts with none. The 'Scale Library' button under the scale list is shared by ALL your characters - save a scale once, then load it onto any character. Import/Export still works for sharing with other people.", currentY)
    local text8Height = text8:GetStringHeight()
    currentY = currentY - text8Height - sectionSpacing
    
    -- Finding Upgrades
    local headerUpgrades = CreateSectionHeader("Finding Upgrades", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local textUpgrades = CreateBodyText("Valuate can point out upgrades rather than making you check every tooltip:\n\n• Green arrows mark any item that beats what you're wearing - in your bags, at vendors, and on the loot window. They follow your CURRENT spec (Settings > Character Window Scale decides which that is; the scale list marks it with a star).\n• The upgrade popup names the single biggest gain, with its score. Click its icon to equip just that item, or Equip to take the whole set.\n• Best Equipment shows the best item per slot, including gear in your bank - those are marked, because Equip All can't reach them.\n• Items you can't use yet (too low level) are tracked separately as future upgrades, so they don't get vendored.", currentY)
    local textUpgradesHeight = textUpgrades:GetStringHeight()
    currentY = currentY - textUpgradesHeight - sectionSpacing

    -- Automation
    local headerAuto = CreateSectionHeader("Automation", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local textAuto = CreateBodyText("All of this is opt-in, under Settings. Every automated feature has a matching command that explains why it did nothing, which is usually faster than guessing:\n\n• Auto Roll - Needs upgrades, unlearned recipes for professions you have (even above your current skill), and crafting materials your professions use. /valuate rollcheck <item> explains any single decision.\n• Auto Delete / Auto Sell - clears junk to keep bag slots free. Deletion is irreversible, so ALWAYS run /valuate deletepreview first. While either is switched on, item tooltips tell you the verdict directly: junk items say whether anything is protecting them (best-in-slot, a quest item, an equipment set, a future upgrade) or that nothing is. Hover before you trust it.\n• Auto Accept / Turn In Quests, and picking the best quest reward.\n• /valuate report shows when each automation last ran and what it concluded - including 'ran and correctly did nothing', which is a different answer from 'never ran'.", currentY)
    local textAutoHeight = textAuto:GetStringHeight()
    currentY = currentY - textAutoHeight - sectionSpacing

    -- Tips and Tricks
    local header9 = CreateSectionHeader("Tips and Tricks", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text9 = CreateBodyText("• Stat weights save when you press Enter OR click away - the row flashes to confirm it.\n• Create multiple scales for different roles (e.g., 'DPS', 'Tank', 'Healer').\n• Use the visibility toggle to compare items for different builds without deleting scales.\n• Banned stats are useful for hybrid classes that can't use certain stats.\n• The scale name in the editor can be changed to rename the scale (this one still needs Enter).\n• Escape closes any Valuate window.", currentY)
    local text9Height = text9:GetStringHeight()
    currentY = currentY - text9Height - PADDING
    
    -- Set content frame height based on total content
    local totalHeight = math.abs(currentY) + PADDING
    contentFrame:SetHeight(math.max(totalHeight, scrollFrame:GetHeight()))
    
    -- Update scrollbar range
    local function UpdateScrollRange()
        local scrollFrameHeight = scrollFrame:GetHeight()
        local contentHeight = contentFrame:GetHeight()
        local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
        if scrollBar:GetValue() > maxScroll then
            scrollBar:SetValue(maxScroll)
        end
    end
    
    -- Update on frame size changes
    container:SetScript("OnSizeChanged", UpdateScrollRange)
    UpdateScrollRange()
    
    return container
end

-- ========================================
-- About Panel
-- ========================================

local function CreateAboutPanel(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Main content frame (non-scrollable, centered content)
    local contentFrame = CreateFrame("Frame", nil, container)
    contentFrame:SetPoint("CENTER", container, "CENTER", 0, 0)
    contentFrame:SetWidth(500)
    contentFrame:SetHeight(400)
    
    -- Helper function to create text elements
    local function CreateText(text, font, color, yOffset, justifyH)
        local fontString = contentFrame:CreateFontString(nil, "OVERLAY", font or FONT_BODY)
        fontString:SetPoint("TOP", contentFrame, "TOP", 0, yOffset)
        fontString:SetWidth(contentFrame:GetWidth() - 40)
        fontString:SetJustifyH(justifyH or "CENTER")
        fontString:SetJustifyV("TOP")
        fontString:SetText(text)
        if color then
            fontString:SetTextColor(unpack(color))
        else
            fontString:SetTextColor(unpack(COLORS.textBody))
        end
        return fontString
    end
    
    local currentY = -20
    local lineHeight = 20
    local sectionSpacing = 25
    local paragraphSpacing = 15
    
    -- Main header
    local header = CreateText("About Valuate", FONT_H1, COLORS.textAccent, currentY, "CENTER")
    currentY = currentY - header:GetStringHeight() - paragraphSpacing
    
    -- Description
    local description = CreateText(
        "Valuate is a stat weight calculator addon for World of Warcraft that helps you make informed gear decisions. " ..
        "By assigning custom weights to stats based on your character and playstyle, Valuate calculates item scores and " ..
        "displays them directly in tooltips, making it easy to compare gear at a glance.",
        FONT_BODY, COLORS.textBody, currentY, "LEFT"
    )
    currentY = currentY - description:GetStringHeight() - sectionSpacing
    
    -- Key Features header
    local featuresHeader = CreateText("Key Features", FONT_H1, COLORS.textAccent, currentY, "LEFT")
    currentY = currentY - featuresHeader:GetStringHeight() - paragraphSpacing
    
    -- Features list
    local features = CreateText(
        -- NOTE: this panel has a FIXED 400px height and no scroll frame, so keep this
        -- list to roughly its current length or it will overflow the panel.
        "• Per-character profiles - independent scales and settings\n" ..
        "• Customizable stat weight scales, with stat banning for hybrid builds\n" ..
        "• Real-time tooltip scores, comparisons and 'Best for' markers\n" ..
        "• Best Equipment panel - best-in-slot per scale, deltas, Equip All\n" ..
        "• Weapon sets - 2H, 1H+Shield, 1H+Off-Hand and Dual Wield tracked separately\n" ..
        "• Opt-in automation: quest rewards, loot rolls, upgrade prompt\n" ..
        "• Junk auto-delete and merchant sell/repair, with hard protections\n" ..
        "• Import/Export for sharing scales (carries weapon-set config)\n" ..
        "• Support for Ascension-specific stats (PvE Power, PvP Power, etc.)\n" ..
        "• Character window integration and a minimap button",
        FONT_BODY, COLORS.textBody, currentY, "LEFT"
    )
    currentY = currentY - features:GetStringHeight() - sectionSpacing
    
    -- Contact section
    local contactHeader = CreateText("Contact & Support", FONT_H1, COLORS.textAccent, currentY, "LEFT")
    currentY = currentY - contactHeader:GetStringHeight() - paragraphSpacing
    
    -- Discord contact with symbol
    local discordText = contentFrame:CreateFontString(nil, "OVERLAY", FONT_BODY)
    discordText:SetPoint("TOP", contentFrame, "TOP", 0, currentY)
    discordText:SetWidth(contentFrame:GetWidth() - 40)
    discordText:SetJustifyH("LEFT")
    discordText:SetText("◆ Discord: |cFF7289DAjessecallaghan|r")
    discordText:SetTextColor(unpack(COLORS.textBody))
    currentY = currentY - discordText:GetStringHeight() - 5
    
    -- Ko-fi support link
    local kofiText = contentFrame:CreateFontString(nil, "OVERLAY", FONT_BODY)
    kofiText:SetPoint("TOP", contentFrame, "TOP", 0, currentY)
    kofiText:SetWidth(contentFrame:GetWidth() - 40)
    kofiText:SetJustifyH("LEFT")
    kofiText:SetText("◆ Support: |cFFFF5E5Ehttps://ko-fi.com/jessecallaghan|r")
    kofiText:SetTextColor(unpack(COLORS.textBody))
    
    return container
end

-- ========================================
-- Changelog Panel
-- ========================================

local function CreateChangelogPanel(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Scroll frame for changelog content
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", PADDING, -PADDING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SCROLLBAR_WIDTH - PADDING, PADDING)
    scrollFrame:SetBackdrop(BACKDROP_PANEL)
    scrollFrame:SetBackdropColor(unpack(COLORS.panelBg))
    scrollFrame:SetBackdropBorderColor(unpack(COLORS.borderDark))
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newValue = current - (delta * 30)
        newValue = math.max(0, math.min(maxScroll, newValue))
        self:SetVerticalScroll(newValue)
        if scrollFrame.scrollBar then
            scrollFrame.scrollBar:SetValue(newValue)
        end
    end)
    
    -- Content frame for text
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(scrollFrame:GetWidth() - PADDING * 2)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -PADDING, PADDING)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(unpack(COLORS.windowBg))
    scrollBarBg:SetBackdropBorderColor(unpack(COLORS.borderDark))
    
    -- Scrollbar
    local scrollBar = CreateFrame("Slider", nil, scrollBarBg, "UIPanelScrollBarTemplate")
    scrollBar:SetPoint("TOPLEFT", scrollBarBg, "TOPLEFT", 2, -16)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollBarBg, "BOTTOMRIGHT", -2, 16)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(20)
    scrollBar.scrollFrame = scrollFrame
    scrollBar:SetScript("OnValueChanged", function(self, value)
        if self.scrollFrame and self.scrollFrame.SetVerticalScroll then
            self.scrollFrame:SetVerticalScroll(value)
        end
    end)
    scrollBar:SetValue(0)
    scrollFrame.scrollBar = scrollBar
    
    -- Helper function to create a version header
    local function CreateVersionHeader(text, yOffset)
        local header = contentFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
        header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        header:SetPoint("RIGHT", contentFrame, "RIGHT", -PADDING, 0)
        header:SetJustifyH("LEFT")
        header:SetText(text)
        header:SetTextColor(unpack(COLORS.textAccent))
        return header
    end
    
    -- Helper function to create changelog text
    local function CreateChangeText(text, yOffset, width)
        local body = contentFrame:CreateFontString(nil, "OVERLAY", FONT_BODY)
        body:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        body:SetWidth(width or (contentFrame:GetWidth() - PADDING * 2))
        body:SetJustifyH("LEFT")
        body:SetJustifyV("TOP")
        body:SetText(text)
        body:SetTextColor(unpack(COLORS.textBody))
        return body
    end
    
    -- Build changelog content
    local currentY = -PADDING
    local lineHeight = 16
    local versionSpacing = 30
    local paragraphSpacing = 10
    
    -- Version 0.49.1a (Current) - see CHANGELOG.md for the release-by-release detail.
    --
    -- This panel had drifted seventeen releases behind the .toc, which is worse than
    -- having no changelog: it reads as "nothing has happened since 0.17.2a". It is now
    -- checked by tools/tocsync.js - the newest version named here must match the .toc,
    -- so it cannot silently fall behind again.
    --
    -- Deliberately a SUMMARY, not one entry per patch. The full history lives in
    -- CHANGELOG.md; what belongs here is what a user would notice.
    local vCurrentHeader = CreateVersionHeader("Version 0.49.1a (Current) - what is new since 0.17.2a", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local vCurrentText = CreateChangeText(
        "• Settings has a SEARCH BOX. Type part of an option's name and everything\n" ..
        "   else dims. Nothing moves while you filter.\n" ..
        "• Item tooltips now tell you what cleanup would do. While auto-sell or\n" ..
        "   auto-delete is on, junk items say whether anything protects them\n" ..
        "   (best-in-slot, quest item, equipment set, future upgrade) or that\n" ..
        "   nothing does. Hover before you trust it.\n" ..
        "• Best Equipment marks the slots a scan CHANGED, so you can see what it did.\n" ..
        "• Upgrade arrows pop in when they arrive - and only when they are new,\n" ..
        "   never re-animating as you move things around your bags.\n" ..
        "• The window resizes smoothly instead of snapping between tabs.\n" ..
        "• FIXED: the Toggle UI keybind button could keep hold of your keyboard.\n" ..
        "   Right-clicking to clear while it was waiting for a key, or closing the\n" ..
        "   window mid-capture, left it armed - so it bound the next key you pressed\n" ..
        "   and swallowed your typing until then.\n" ..
        "• NEW: hover a stat's weight box in the Scale Editor and it tells you what\n" ..
        "   that weight is doing - its share of your equipped score, or that you are\n" ..
        "   carrying none of the stat. Type a new number and hover again; the share\n" ..
        "   moves with it.\n" ..
        "• NEW: /valuate weights - ranks your stat weights by how much they actually\n" ..
        "   contribute to the gear you are wearing, and names the ones doing nothing\n" ..
        "   because you carry none of that stat. A scale with fifteen weights looks\n" ..
        "   carefully tuned; this tells you which three are doing the work.\n" ..
        "• FIXED: 22 places drew their flat colours - accent bars, separators, row\n" ..
        "   highlights, header backgrounds - with a call that only exists on much\n" ..
        "   later game clients. They now use whichever one this client has. Run\n" ..
        "   /valuate verify solidcolour and check the coloured lines are all there.\n" ..
        "• FIXED: with Reduce Motion switched on, upgrade arrows were never released\n" ..
        "   when you closed a bag, so the addon kept working on invisible arrows for\n" ..
        "   the rest of the session. Only that setting was affected.\n" ..
        "• FIXED: if a scale gives a stat a NEGATIVE weight, the tooltip's percentage\n" ..
        "   came out backwards - an improvement over a negative score printed as\n" ..
        "   '+-50.0%' in green. And a huge downgrade said 'HUGE!' with no minus,\n" ..
        "   which reads as good news. Both now agree with the number beside them.\n" ..
        "• FIXED: a slot you are wearing NOTHING in showed a grey '--', the same as\n" ..
        "   'no comparison available'. It now says New, and the summary counts how\n" ..
        "   many empty slots you own something for - not how many are empty, since an\n" ..
        "   empty Off Hand is correct if you use a two-hander.\n" ..
        "• The scale list no longer leaks. It used to rebuild every row whenever you\n" ..
        "   added, deleted, renamed or recoloured a scale, and WoW never frees a frame -\n" ..
        "   so each edit cost you about ten frames per scale for the rest of the\n" ..
        "   session. Rows are now reused. A genuinely new scale fades in; rows that\n" ..
        "   merely shifted up do not.\n" ..
        "• The six things auto-delete promises never to touch - quest items, gear in\n" ..
        "   an equipment set, weapon-set members, best-in-slot, future upgrades and\n" ..
        "   anything that is an upgrade for any scale - are now executed by a build\n" ..
        "   gate that proves each one still protects, one at a time. Deletion is\n" ..
        "   irreversible, so it was the worst thing here to be taking on trust.\n" ..
        "• /valuate verify - a short list of behaviours worth checking by hand,\n" ..
        "   several of which set themselves up for you. /valuate verify next walks\n" ..
        "   you through them one at a time, and a tick expires by itself once the\n" ..
        "   behaviour it covered changes.\n" ..
        "• FIXED: an upgrade found during combat is now actually offered when you\n" ..
        "   leave combat. It never was - the flag was read from the wrong place.\n" ..
        "• FIXED: weapon-set toggles could silently do nothing after importing or\n" ..
        "   loading a scale over the one you were editing.\n" ..
        "• FIXED: /valuate export could hand you the wrong scale when two names\n" ..
        "   differed only by case. It now says which ones matched.\n" ..
        "• FIXED: a scale colour with a bad character took down the whole panel.\n" ..
        "• FIXED: buttons showed no pressed state on a fast click.\n" ..
        "• FIXED: adjusting a scale's colour leaked thousands of UI frames, and\n" ..
        "   clicking between scales leaked ~250 more each time.\n" ..
        "• FIXED: auto-delete no longer touches a bag slot that is mid-move.",
        currentY)
    currentY = currentY - vCurrentText:GetStringHeight() - versionSpacing

    -- Version 0.17.2a - junk isn't new
    local v0172Header = CreateVersionHeader("Version 0.17.2a - junk stops pretending to be new", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0172Text = CreateChangeText(
        "• NEW: junk no longer triggers the new-item highlight. AdiBags' own\n" ..
        "   'ignore junk' setting only covers grey QUALITY, so anything junk for\n" ..
        "   another reason - marked surplus, added to the Junk list by hand, or\n" ..
        "   flagged by Scrap - still glowed as new.\n" ..
        "• Uses the same junk classification as auto-delete and auto-sell, so all\n" ..
        "   three always agree rather than each deciding separately.\n" ..
        "• Toggle: \"Junk isn't new\" in the AdiBags Valuate options. On by default -\n" ..
        "   the hook can only ever suppress a highlight.",
        currentY
    )
    local v0172Height = v0172Text:GetStringHeight()
    currentY = currentY - v0172Height - versionSpacing

    -- Version 0.17.1a - auto-Need profession materials
    local v0171Header = CreateVersionHeader("Version 0.17.1a - auto-Need profession materials", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0171Text = CreateChangeText(
        "• NEW: auto-roll also Needs crafting materials your professions use -\n" ..
        "   cloth for Tailoring, herbs for Alchemy, metal for Blacksmithing.\n" ..
        "   Trade goods don't say what they're for, so this uses a subtype-to-\n" ..
        "   profession mapping.\n" ..
        "• Gathering professions are ignored - mining produces ore, so a miner\n" ..
        "   isn't short of it. Unmapped subtypes are left alone.\n" ..
        "• |cFFFF8800Worth knowing:|r materials drop far more often than recipes, so\n" ..
        "   this Needs a lot of common loot. Some groups consider that poor\n" ..
        "   etiquette - it's one click to turn off.\n" ..
        "• Toggle: 'Need Profession Materials', under Auto Roll Loot.",
        currentY
    )
    local v0171Height = v0171Text:GetStringHeight()
    currentY = currentY - v0171Height - versionSpacing

    -- Version 0.17.0a - auto-Need learnable recipes
    local v0170Header = CreateVersionHeader("Version 0.17.0a - auto-Need learnable recipes", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0170Text = CreateChangeText(
        "• NEW: auto-roll now Needs recipes for professions you actually have.\n" ..
        "   A recipe requiring more skill than you currently have STILL rolls Need -\n" ..
        "   you'll train into it, so the usual 'can you use this now' test is\n" ..
        "   deliberately skipped.\n" ..
        "• Recipes you already know, and recipes for professions you don't have,\n" ..
        "   are left alone.\n" ..
        "• If Need isn't offered (the client often disables it for something you\n" ..
        "   can't use yet), it falls back to Greed rather than passing.\n" ..
        "• /valuate roll lists the professions it detected - an empty list is the\n" ..
        "   one silent failure here, since no recipe would ever roll Need.\n" ..
        "• Toggle: 'Need Unlearned Recipes', under Auto Roll Loot.",
        currentY
    )
    local v0170Height = v0170Text:GetStringHeight()
    currentY = currentY - v0170Height - versionSpacing

    -- Version 0.16.1a - login scan
    local v0161Header = CreateVersionHeader("Version 0.16.1a - scans on login", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0161Text = CreateChangeText(
        "• NEW: best-in-slot refreshes when you log in. The saved data survives\n" ..
        "   across sessions but can be stale - gear arriving by mail, or a session\n" ..
        "   that ended mid-scan - and the panel, arrows and upgrade prompt were all\n" ..
        "   reading it until something else triggered a scan.\n" ..
        "• It runs TWICE, at 6s and 15s. Just after entering the world the client's\n" ..
        "   item cache is cold, so items it hasn't loaded get skipped - one early\n" ..
        "   scan can quietly give a WORSE result than not scanning. The second pass\n" ..
        "   catches the stragglers.\n" ..
        "• Runs in every Auto Scan mode except Off.",
        currentY
    )
    local v0161Height = v0161Text:GetStringHeight()
    currentY = currentY - v0161Height - versionSpacing

    -- Version 0.16.0a - unique-equipped, tabards, item names
    local v0160Header = CreateVersionHeader("Version 0.16.0a - Unique-Equipped respected", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0160Text = CreateChangeText(
        "• |cFFFF5555FIX|r: a Unique-Equipped ring was recommended for BOTH ring\n" ..
        "   slots. The scan limited items by how many copies you OWN, but\n" ..
        "   uniqueness limits how many you may WEAR - so the panel and the popup\n" ..
        "   suggested gear the game won't let you equip.\n" ..
        "• Uniqueness isn't exposed by the item API here, so it's read from the\n" ..
        "   tooltip - including the 'Unique-Equipped: <name> (1)' form that other\n" ..
        "   addons miss by matching the plain string exactly. Applied to\n" ..
        "   best-in-slot, the dual-wield off-hand pick, and future upgrades.\n" ..
        "• |cFFFF5555FIX|r: tabards and shirts are no longer scored - they can never\n" ..
        "   carry stats, so the number was meaningless.\n" ..
        "• |cFFFF5555FIX|r: item names were being stored as full item LINKS, which is\n" ..
        "   why the upgrade popup showed a bracketed blue name and ran out of room.\n" ..
        "   Fixing it also corrected three other displays whose colouring a link\n" ..
        "   was silently overriding.",
        currentY
    )
    local v0160Height = v0160Text:GetStringHeight()
    currentY = currentY - v0160Height - versionSpacing

    -- Version 0.15.2a - junk marking hardened
    local v0152Header = CreateVersionHeader("Version 0.15.2a - junk marking hardened", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0152Text = CreateChangeText(
        "• SAFETY: surplus-gear marking now refuses to mark anything until it has\n" ..
        "   trustworthy data. It reasons 'not in the best list, so surplus' - true\n" ..
        "   only once that list exists. Before the first scan, after a failed one,\n" ..
        "   or with no active scale, NOTHING is best-in-slot, so everything in your\n" ..
        "   bags would have been marked at once.\n" ..
        "• SAFETY: gear in a saved equipment set is protected - a PvP or fishing set\n" ..
        "   generally isn't best-in-slot, but you clearly want it.\n" ..
        "• SAFETY: slots Valuate has no opinion about are left alone.\n" ..
        "• NEW: /valuate junkmarks says which guard is holding it back, so 'nothing\n" ..
        "   is being marked' is never ambiguous.",
        currentY
    )
    local v0152Height = v0152Text:GetStringHeight()
    currentY = currentY - v0152Height - versionSpacing

    -- Version 0.15.1a - surplus gear as junk
    local v0151Header = CreateVersionHeader("Version 0.15.1a - mark surplus gear as junk", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0151Text = CreateChangeText(
        "• NEW (AdiBags): 'Mark surplus gear as junk'. Equippable gear that is not\n" ..
        "   best-in-slot and not a future upgrade goes to the Junk section.\n" ..
        "• It re-evaluates itself - if an item later becomes your best it stops\n" ..
        "   being marked on the next scan. No stale marks, no cleanup pass.\n" ..
        "• |cFFFF5555Off by default and capped at green.|r Auto-delete uses the\n" ..
        "   AdiBags junk filter as its deletable list, so anything marked here can\n" ..
        "   be deleted automatically if you also run auto-delete.\n" ..
        "• Never marks best-in-slot items, future upgrades or profession tools, and\n" ..
        "   leaves alone anything it is unsure about.",
        currentY
    )
    local v0151Height = v0151Text:GetStringHeight()
    currentY = currentY - v0151Height - versionSpacing

    -- Version 0.15.0a - upgrade popup
    local v0150Header = CreateVersionHeader("Version 0.15.0a - upgrades get their own popup", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0150Text = CreateChangeText(
        "• NEW: a proper upgrade popup. It used to reuse the same dialog that asks\n" ..
        "   'delete these 12 items?', so it could only be a block of text with two\n" ..
        "   equal buttons - and it said '3 upgrade(s) in your bags' without saying\n" ..
        "   which, or by how much.\n" ..
        "• It is now compact and specific: the best upgrade's icon with its quality\n" ..
        "   border, the item name, the actual score gain, and a headline in your\n" ..
        "   spec's colour. Hover the icon for the full item tooltip.\n" ..
        "• Dismiss is a quiet corner x, not a second full-width button.\n" ..
        "• Entrance animation and a soft glow pulse, both skipped under Reduce\n" ..
        "   Motion.\n" ..
        "• |cFFFF5555FIX|r: the 'nothing left to equip' path hid the OLD dialog, so\n" ..
        "   the new popup would have lingered offering gear you already wore.",
        currentY
    )
    local v0150Height = v0150Text:GetStringHeight()
    currentY = currentY - v0150Height - versionSpacing

    -- Version 0.14.5a - responsive "Always" scanning
    local v0145Header = CreateVersionHeader("Version 0.14.5a - responsive Always scanning", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0145Text = CreateChangeText(
        "• CHANGED: Auto Scan 'Always' now reacts to bag changes in about a second\n" ..
        "   instead of several. Four delays were stacking up before a scan could\n" ..
        "   run - the scheduled delay, a bag-quiet window, a minimum gap between\n" ..
        "   scans, and the burst cap - all sharing one conservative set of numbers.\n" ..
        "   During sustained looting a scan could be six seconds behind your bags.\n" ..
        "   Those numbers are now per-mode; the other modes keep the cautious ones.\n" ..
        "• CHANGED: equipping or unequipping anything re-scans in ~1.2s on Always\n" ..
        "   instead of 3.5s. Both directions were already covered, just slow.\n" ..
        "• The in-transit guards are unchanged - they are what stop a scan reading\n" ..
        "   a bag slot while an item is mid-move. Equip keeps a real settle window\n" ..
        "   (shorter, not removed), and bulk set swaps keep the longest one.",
        currentY
    )
    local v0145Height = v0145Text:GetStringHeight()
    currentY = currentY - v0145Height - versionSpacing

    -- Version 0.14.4a - tab polish
    local v0144Header = CreateVersionHeader("Version 0.14.4a - tab polish", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0144Text = CreateChangeText(
        "• NEW: the Scales list marks your CURRENT SPEC. That scale drives your\n" ..
        "   character score, the upgrade prompt and the green arrows - but the only\n" ..
        "   way to find out which it was involved a Settings dropdown named after\n" ..
        "   the character window. Hover any scale to see what it does.\n" ..
        "• NEW: empty state for the Scales list instead of a blank panel.\n" ..
        "• NEW: the upgrade arrow is bigger, glows, and pulses slowly so it reads\n" ..
        "   against bright item art. Respects Reduce Motion.\n" ..
        "• |cFFFF5555FIX|r: 'Upgrades in bags' was counting gear in your BANK.\n" ..
        "   Banked upgrades are now listed separately, and 'no upgrades in bags'\n" ..
        "   no longer appears when the upgrade is sitting in the bank.\n" ..
        "• CHANGED: Settings columns rebalanced - column 1 had 25 rows against 9\n" ..
        "   and 7, which is why options ran off the bottom.",
        currentY
    )
    local v0144Height = v0144Text:GetStringHeight()
    currentY = currentY - v0144Height - versionSpacing

    -- Version 0.14.2a - spec-aware arrows, tidier character sheet
    local v0142Header = CreateVersionHeader("Version 0.14.2a - spec-aware upgrade arrows", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0142Text = CreateChangeText(
        "• CHANGED: upgrade arrows now only show for your CURRENT spec. They used\n" ..
        "   to flag any active scale, so an arrow for a spec you weren't playing\n" ..
        "   looked exactly like one for the spec you were. Switching spec clears\n" ..
        "   the cached answers so no arrow lingers from the old one.\n" ..
        "• |cFFFF5555FIX|r: the character-sheet gear score no longer appears on the\n" ..
        "   Pets, Reputation, Skills or Currency tabs. It now belongs to the\n" ..
        "   equipment view itself, so it hides with it automatically.\n" ..
        "• |cFFFF5555FIX|r: tooltip totals now show what the percentage is measured\n" ..
        "   against ('4.4 vs 3.7'). The equipped score was being calculated and\n" ..
        "   then thrown away, which is why a better item could show a smaller\n" ..
        "   percentage than a worse one.\n" ..
        "• |cFFFF5555FIX|r: the Settings panel scrolls, so options can no longer\n" ..
        "   run off the bottom of the window.",
        currentY
    )
    local v0142Height = v0142Text:GetStringHeight()
    currentY = currentY - v0142Height - versionSpacing

    -- Version 0.14.0a - upgrade arrows
    local v0140Header = CreateVersionHeader("Version 0.14.0a - upgrade arrows", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0140Text = CreateChangeText(
        "• NEW: a green arrow pins to the top-right of any item icon that would be\n" ..
        "   an upgrade for one of your active scales - in your bags, at vendors,\n" ..
        "   and on the loot window. No more opening every tooltip to find out.\n" ..
        "• Deliberately NOT on the character or wardrobe panels: an arrow on gear\n" ..
        "   you're already wearing is noise.\n" ..
        "• Toggle with 'Upgrade Arrows' in Settings.",
        currentY
    )
    local v0140Height = v0140Text:GetStringHeight()
    currentY = currentY - v0140Height - versionSpacing

    -- Version 0.13.1a - stat weight page polish
    local v0131Header = CreateVersionHeader("Version 0.13.1a - stat weight page polish", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0131Text = CreateChangeText(
        "• |cFFFF5555FIX|r: typed values were thrown away unless you pressed Enter.\n" ..
        "   Clicking from one field to the next - the obvious way to fill in\n" ..
        "   several weights - discarded the edit. The number stayed on screen so\n" ..
        "   it looked applied, but never reached the scale. Affected stat weights\n" ..
        "   and six Settings fields (Keep Free Slots, Max/Min Value, Run Every,\n" ..
        "   Decimal Places, Value Source).\n" ..
        "• |cFFFF5555FIX|r: the scale name box showed text you typed but never\n" ..
        "   applied. Renames still need Enter; the field now shows the real name.\n" ..
        "• NEW: stat rows with a weight set stand out - with ~60 stats across five\n" ..
        "   columns, the ones you'd configured were impossible to spot.\n" ..
        "• NEW: editor header summary - stats weighted, stats banned, and your\n" ..
        "   current gear score for that scale. An empty scale now says outright\n" ..
        "   that it won't score anything.",
        currentY
    )
    local v0131Height = v0131Text:GetStringHeight()
    currentY = currentY - v0131Height - versionSpacing

    -- Version 0.13.0a - automation reliability
    local v0130Header = CreateVersionHeader("Version 0.13.0a - automation that actually runs", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0130Text = CreateChangeText(
        "• |cFFFF5555FIX|r: auto-delete, scanning and upgrade alerts could all go long\n" ..
        "   stretches without running. Each re-armed its timer on every event, and\n" ..
        "   ITEM_PUSH/BAG_UPDATE fire constantly while looting - so the deadline kept\n" ..
        "   moving and the work never ran during the very activity that wanted it.\n" ..
        "• |cFFFF5555FIX|r: work blocked by a safety guard was discarded, not retried.\n" ..
        "   A scan firing while bags settled was abandoned - the likely cause of\n" ..
        "   'the scan didn't pick up my new item'. Same for the upgrade popup.\n" ..
        "• NEW: junk cleanup also runs on a timer (60s default, /valuate junkinterval).\n" ..
        "• NEW: /valuate report shows when each automation last ran and what it did -\n" ..
        "   including 'ran and correctly did nothing', which used to look identical\n" ..
        "   to never running at all.\n" ..
        "• NEW: Skip Trivial Quests, and auto-accept now picks the first non-trivial\n" ..
        "   quest instead of always the first in the list.\n" ..
        "• NEW: /valuate profile - times the scan, scoring and tooltip parsing.",
        currentY
    )
    local v0130Height = v0130Text:GetStringHeight()
    currentY = currentY - v0130Height - versionSpacing

    -- Version 0.12.1a - upgrade alert options
    local v0121Header = CreateVersionHeader("Version 0.12.1a - upgrade alert options", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0121Text = CreateChangeText(
        "• NEW: upgrade alerts can be a chat message instead of a popup, with an\n" ..
        "   optional sound. One Settings control cycles Popup / +Sound / Chat.\n" ..
        "• NEW: 'Alert For Other Specs' - also lists your other active scales that\n" ..
        "   have upgrades waiting, so a drop for a spec you aren't running now\n" ..
        "   doesn't get vendored without you noticing.\n" ..
        "• NEW: /valuate equip - equips the best set for the active scale.\n" ..
        "• |cFFFF5555FIX|r: the upgrade prompt could offer to equip gear sitting in\n" ..
        "   your BANK - the button would then skip it. Banked upgrades are now\n" ..
        "   counted separately and named as such.",
        currentY
    )
    local v0121Height = v0121Text:GetStringHeight()
    currentY = currentY - v0121Height - versionSpacing

    -- Version 0.12.0a - bank-aware best-in-slot, deterministic results
    local v0120Header = CreateVersionHeader("Version 0.12.0a - bank-aware best-in-slot", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0120Text = CreateChangeText(
        "• NEW: your BANK now counts towards best-in-slot. Valuate snapshots it when\n" ..
        "   you visit a bank. Banked items get a bag icon, and Equip All skips them\n" ..
        "   and says how many - it can't reach the bank. Toggle in Settings.\n" ..
        "• NEW: /valuate bank - shows the snapshot, and when it contributes nothing\n" ..
        "   says which reason applies (never visited, option off, no gear found).\n" ..
        "• |cFFFF5555FIX|r: results could change between scans. Six sorts had no\n" ..
        "   tiebreaker, so equal-ranked items fell back on undefined ordering:\n" ..
        "   equal-scoring items swapped places (flipping 'Best for', the equipment\n" ..
        "   set and the AdiBags tag), the reported best scale varied, and\n" ..
        "   deletepreview could rank a different item than deletenow removed.\n" ..
        "• SAFETY: auto-delete, auto-sell and 'keep N slots free' stay strictly\n" ..
        "   bags-only and can never see your bank - now enforced by the build.",
        currentY
    )
    local v0120Height = v0120Text:GetStringHeight()
    currentY = currentY - v0120Height - versionSpacing

    -- Version 0.11.1a - weapon-set correctness, /valuate report
    local v0111Header = CreateVersionHeader("Version 0.11.1a - weapon-set fixes & /valuate report", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0111Text = CreateChangeText(
        "• NEW: /valuate report - one summary of your gear: upgrades waiting and what\n" ..
        "   they're worth, weapon sets with the active one marked, bag space, and\n" ..
        "   which automation is actually switched on.\n" ..
        "• NEW: /valuate selftest now checks every UI module actually loaded.\n" ..
        "• |cFFFF5555FIX|r: the active weapon set could change by itself. Ties (common\n" ..
        "   before you own a shield/off-hand) were resolved in arbitrary order, so your\n" ..
        "   Main/Off Hand and the upgrade prompt's baseline could flip with no gear\n" ..
        "   change. Now deterministic, preferring the set with more slots filled.\n" ..
        "• |cFFFF5555FIX|r: future upgrades ignored weapons for your OTHER setups - a 1H\n" ..
        "   that would improve your 1H+Shield set was invisible while you ran a 2H.\n" ..
        "• |cFFFF5555FIX|r: three nil-reference bugs in the split UI (one would have\n" ..
        "   errored building the Settings panel), and tooltips showing while dragging.\n" ..
        "• CHANGED: README and About refreshed; UI split finished (ValuateUI.lua is now\n" ..
        "   618 lines across 12 modules).",
        currentY
    )
    local v0111Height = v0111Text:GetStringHeight()
    currentY = currentY - v0111Height - versionSpacing

    -- Version 0.11.0a - merchant automation, upgrade prompts, rebuilt UI
    local v0110Header = CreateVersionHeader("Version 0.11.0a - merchant automation & upgrade prompts", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0110Text = CreateChangeText(
        "|cFFFFD700Mostly UNTESTED in-game - verify before relying on it.|r\n" ..
        "\n" ..
        "• NEW: bag-upgrade prompt - when an upgrade for your current spec is in your\n" ..
        "   bags, offers one-click 'Equip Best Set'. Fires on ANY item entering your\n" ..
        "   bags (loot, quest reward, mail, trade, craft) and waits until out of combat.\n" ..
        "   /valuate notify, /valuate notifycheck\n" ..
        "• NEW: auto-sell junk + auto-repair at merchants. Same junk rules and same\n" ..
        "   protections as auto-delete, but safer - you get gold and Buyback can undo it.\n" ..
        "   /valuate sell, /valuate sellnow, /valuate repair\n" ..
        "• NEW: /valuate deletenow - clean junk on demand (still respects Keep Free Slots).\n" ..
        "• NEW: animations - window open/close, tab crossfade, Best Equipment reveal with\n" ..
        "   score count-ups, upgrade pulse on the minimap. Reduce Motion turns it all off.\n" ..
        "• NEW: pick the active spec per Best Equipment column.\n" ..
        "• NEW: import/export now carries your weapon-set setup (scale tag v2).\n" ..
        "• |cFFFF5555FIX|r: bind-on-use items (e.g. vanity sync) were being BLOCKED by\n" ..
        "   Valuate tainting Blizzard's shared popup frames. Valuate now uses its own\n" ..
        "   dialog and never touches StaticPopup.\n" ..
        "• |cFFFF5555FIX|r: junk was not detected at all (0 junk from a full bag) - now\n" ..
        "   asks the AdiBags Junk module directly and honours your include/exclude lists.\n" ..
        "• |cFFFF5555FIX|r: a better weapon set could go invisible - 'Auto' followed what\n" ..
        "   you were WEARING, hiding a stronger 2H in your bags. Auto now means best.\n" ..
        "• |cFFFF5555FIX|r: the upgrade prompt often never appeared (a combat check ate it).\n" ..
        "• |cFFFF5555FIX|r: auto-delete ignored quest rewards/mail and refused to run in\n" ..
        "   combat - exactly when bags fill while AoE farming.\n" ..
        "• |cFFFF5555FIX|r: overlapping text in Settings; tooltips showing while dragging.\n" ..
        "• CHANGED: the UI was split into 11 modules (ValuateUI.lua 8,967 -> ~1,400 lines)\n" ..
        "   with a lint gate and /valuate selftest to keep it honest.",
        currentY
    )
    local v0110Height = v0110Text:GetStringHeight()
    currentY = currentY - v0110Height - versionSpacing

    -- Version 0.10.0a - weapon sets, loot & bag automation
    local v0100Header = CreateVersionHeader("Version 0.10.0a - weapon sets, loot & bag automation", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v0100Text = CreateChangeText(
        "|cFFFFD700All of this is UNTESTED in-game - verify before relying on it.|r\n" ..
        "\n" ..
        "• NEW: Weapon Sets - each scale tracks Two-Hander / 1H+Shield / 1H+Off-Hand /\n" ..
        "   Dual Wield separately instead of one winner per slot. Toggle each per scale\n" ..
        "   and pick the active set; gear for any enabled set is still kept.\n" ..
        "• NEW: Best Equipment weapon-sets panel, plus Equipped/Best and upgrade totals.\n" ..
        "• NEW: Equip All - equips a scale's whole best set in one click (skips locked\n" ..
        "   and already-worn slots), pins that weapon set active.\n" ..
        "• NEW: Save Set - saves what you're wearing as a WoW equipment set, named\n" ..
        "   after the scale + weapon set, e.g. 'Retribution (2H)'.\n" ..
        "• NEW: Auto Roll On Loot (off by default) - Need on upgrades for ANY scale,\n" ..
        "   Greed otherwise. Never Needs a non-upgrade. /valuate roll\n" ..
        "• NEW: Auto Accept Quests (off by default). /valuate accept\n" ..
        "• NEW: Junk auto-delete (off by default, |cFFFF5555deletion is permanent|r) -\n" ..
        "   keeps N bag slots free by removing the least valuable junk. Never deletes\n" ..
        "   best-in-slot, weapon-set, future-upgrade, quest or equipment-set items.\n" ..
        "   Can rank by a TSM price source instead of vendor value.\n" ..
        "   /valuate autodelete, /valuate deletepreview, /valuate keepfree <n>\n" ..
        "• NEW: AdiBags keeps future upgrades (gear you can't use yet) in their own\n" ..
        "   section, optionally merged into Best Items.\n" ..
        "• CHANGED: quest rewards now pick the biggest UPGRADE, not the highest score.\n" ..
        "• CHANGED: tooltips say which setup an item wins, e.g. 'Best two-hander for'.\n" ..
        "• CHANGED: refreshed UI - new palette, Best Equipment cards, tab accent and\n" ..
        "   subtle animations.\n" ..
        "• FIX: stats like 'Equip: Improves hit rating by 2' were silently ignored\n" ..
        "   (the patterns required the word 'your'). Affected many stats, not just hit.\n" ..
        "• FIX: the Dual Wield set only ever found a main hand.\n" ..
        "• FIX: 1H weapons leaked past a 1H ban.\n" ..
        "• FIX: AdiBags showed stale results and was out-prioritised by other filters.\n" ..
        "• FIX: Equip All silently skipped bind-on-equip upgrades.",
        currentY
    )
    local v0100Height = v0100Text:GetStringHeight()
    currentY = currentY - v0100Height - versionSpacing

    -- Version 0.9.5a - Best Equipment frame pooling
    local v095Header = CreateVersionHeader("Version 0.9.5a - Best Equipment frame pooling", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v095Text = CreateChangeText(
        "• PERF: the Best Equipment panel now reuses its frames instead of leaking a\n" ..
        "   new set every rebuild (WoW never frees frames)",
        currentY
    )
    local v095Height = v095Text:GetStringHeight()
    currentY = currentY - v095Height - versionSpacing

    -- Version 0.9.4a - auto quest turn-in
    local v094Header = CreateVersionHeader("Version 0.9.4a - auto quest turn-in", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v094Text = CreateChangeText(
        "• NEW: Auto Turn In Quests (Settings, off by default) - completes the quest\n" ..
        "   and takes the best reward for you. Requires Auto Choose Best Quest Reward;\n" ..
        "   won't auto-complete when a reward choice can't be scored.",
        currentY
    )
    local v094Height = v094Text:GetStringHeight()
    currentY = currentY - v094Height - versionSpacing

    -- Version 0.9.3a - layout & off-hand fixes
    local v093Header = CreateVersionHeader("Version 0.9.3a - layout & off-hand fixes", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v093Text = CreateChangeText(
        "• Fixed: item names were cut off in Best Equipment - name column widened\n" ..
        "• Fixed: 1H weapons no longer suggested for the off-hand unless you can\n" ..
        "   dual-wield (shields / held / off-hand items are unaffected)",
        currentY
    )
    local v093Height = v093Text:GetStringHeight()
    currentY = currentY - v093Height - versionSpacing

    -- Version 0.9.2a - ignore profession tools
    local v092Header = CreateVersionHeader("Version 0.9.2a - ignore profession tools", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v092Text = CreateChangeText(
        "• NEW: Ignore Profession Tools (Settings, on by default) - fishing poles,\n" ..
        "   mining picks, skinning knives, hammers, etc. are never scored, tracked,\n" ..
        "   shown, or filtered. Caster off-hand tomes/orbs are not affected.",
        currentY
    )
    local v092Height = v092Text:GetStringHeight()
    currentY = currentY - v092Height - versionSpacing

    -- Version 0.9.1a - improvement pass
    local v091Header = CreateVersionHeader("Version 0.9.1a - improvement pass", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v091Text = CreateChangeText(
        "• PERF: tooltip border color cached per item (was recomputed every frame)\n" ..
        "• PERF: Best Equipment & character-window skip refreshing while hidden\n" ..
        "• PERF: best-equipment scan parses each equipped item once, not per scale\n" ..
        "• Auto quest reward now skips rewards you can't use yet (level/proficiency)\n" ..
        "• Tooltip 'vs equipped' now matches the panel (all use scaled stats)\n" ..
        "• New /valuate scan and /valuate quest commands\n" ..
        "• PassLoot_Valuate no longer spams chat on every loot roll\n" ..
        "• Removed dead code; consolidated option defaults",
        currentY
    )
    local v091Height = v091Text:GetStringHeight()
    currentY = currentY - v091Height - versionSpacing

    -- Version 0.9.0a - Claude fork
    local v090Header = CreateVersionHeader("Version 0.9.0a - Claude fork", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v090Text = CreateChangeText(
        "• NEW: Best Equipment only picks items you can actually equip now (level +\n" ..
        "   proficiency). Not-yet-usable upgrades are kept as dimmed 'future' items\n" ..
        "• NEW: Auto Choose Best Quest Reward - pre-selects the highest-scoring quest\n" ..
        "   reward choice for your active scale (opt-in, see Settings)\n" ..
        "• Polished, bug-fixed fork - original preserved in an archive folder + git master\n" ..
        "• Fixed: shopping/comparison tooltips now get their green/red Valuate border\n" ..
        "• Fixed: auto-scan timers are now genuinely cancelable (no more overlapping scans)\n" ..
        "• Fixed: 'always' auto-scan mode on bag updates now actually works\n" ..
        "• Hardened timer handling for varying 3.3.5a C_Timer implementations\n" ..
        "• Internal cleanup; item-in-transit safety guards left intact",
        currentY
    )
    local v090Height = v090Text:GetStringHeight()
    currentY = currentY - v090Height - versionSpacing

    -- Version 0.7.0
    local v070Header = CreateVersionHeader("Version 0.7.0", currentY)
    currentY = currentY - lineHeight - paragraphSpacing

    local v070Text = CreateChangeText(
        "• Per-Character Profile System - Settings and scales are now saved per-character\n" ..
        "• Each character maintains completely independent scales and settings\n" ..
        "• Characters no longer share configurations - full isolation per character\n" ..
        "• Use Import/Export to share scales between your own characters if desired\n" ..
        "• Migrated from SavedVariables (account-wide) to SavedVariablesPerCharacter\n" ..
        "• Added accessor functions for clean per-character data access\n" ..
        "• UI positions, minimap button location, and all settings now per-character\n" ..
        "• BREAKING: Existing configs won't auto-transfer to all characters on upgrade",
        currentY
    )
    local v070Height = v070Text:GetStringHeight()
    currentY = currentY - v070Height - versionSpacing
    
    -- Version 0.6.2
    local v062Header = CreateVersionHeader("Version 0.6.2", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local v062Text = CreateChangeText(
        "• Added Import/Export functionality for sharing scales between characters and users\n" ..
        "• Implemented character window integration showing scores for equipped items\n" ..
        "• Added minimap button for quick addon access\n" ..
        "• Enhanced UI with tabbed interface for better organization\n" ..
        "• Added About and Changelog tabs\n" ..
        "• Improved stat definitions and parsing system\n" ..
        "• Added support for additional Ascension-specific stats\n" ..
        "• Various UI improvements and bug fixes",
        currentY
    )
    local v062Height = v062Text:GetStringHeight()
    currentY = currentY - v062Height - versionSpacing
    
    -- Version 0.3.0
    local v030Header = CreateVersionHeader("Version 0.3.0", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local v030Text = CreateChangeText(
        "• Removed vestigial cache system (was never actually used)\n" ..
        "• Removed /valuate cache and /valuate clearcache commands\n" ..
        "• Removed cache size setting from UI\n" ..
        "• Code cleanup to remove dead code paths",
        currentY
    )
    local v030Height = v030Text:GetStringHeight()
    currentY = currentY - v030Height - versionSpacing
    
    -- Version 0.2.0
    local v020Header = CreateVersionHeader("Version 0.2.0", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local v020Text = CreateChangeText(
        "• Added comprehensive stat parsing system with regex patterns\n" ..
        "• Implemented tooltip integration for displaying item scores\n" ..
        "• Created scale system for customizable stat weights\n" ..
        "• Built configuration UI with scale editor\n" ..
        "• Added color picker for scale customization\n" ..
        "• Implemented stat banning functionality\n" ..
        "• Added visibility toggles for scales\n" ..
        "• Improved slash command help menu",
        currentY
    )
    local v020Height = v020Text:GetStringHeight()
    currentY = currentY - v020Height - versionSpacing
    
    -- Version 0.1.0
    local v010Header = CreateVersionHeader("Version 0.1.0 (Initial Release)", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local v010Text = CreateChangeText(
        "• Initial addon structure and framework\n" ..
        "• Basic loading and initialization system\n" ..
        "• Slash command handler (/valuate, /val)\n" ..
        "• Version info command\n" ..
        "• Documentation structure (README, CHANGELOG, DEVELOPER, ASCENSION_DEV)\n" ..
        "• SavedVariables setup for persistent data storage",
        currentY
    )
    local v010Height = v010Text:GetStringHeight()
    currentY = currentY - v010Height - PADDING
    
    -- Set content frame height based on total content
    local totalHeight = math.abs(currentY) + PADDING
    contentFrame:SetHeight(math.max(totalHeight, scrollFrame:GetHeight()))
    
    -- Update scrollbar range
    local function UpdateScrollRange()
        local scrollFrameHeight = scrollFrame:GetHeight()
        local contentHeight = contentFrame:GetHeight()
        local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
        scrollBar:SetMinMaxValues(0, maxScroll)
        if scrollBar:GetValue() > maxScroll then
            scrollBar:SetValue(maxScroll)
        end
    end
    
    -- Update on frame size changes
    container:SetScript("OnSizeChanged", UpdateScrollRange)
    UpdateScrollRange()
    
    return container
end

ns.CreateInstructionsPanel = CreateInstructionsPanel
ns.CreateAboutPanel = CreateAboutPanel
ns.CreateChangelogPanel = CreateChangelogPanel
