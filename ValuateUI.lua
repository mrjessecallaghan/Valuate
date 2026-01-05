-- ValuateUI.lua
-- UI Window for Valuate stat weight calculator

-- ========================================
-- UI Constants
-- ========================================

-- Window dimensions
local WINDOW_WIDTH = 950
local MIN_WINDOW_HEIGHT = 600
local MAX_WINDOW_HEIGHT = 900

-- Standardized spacing
local PADDING = 12              -- Outer padding from window edges
local ELEMENT_SPACING = 8       -- Between major UI sections
local INNER_SPACING = 4         -- Within elements
local COLUMN_GAP = 6            -- Gap between stat columns

-- Component sizing
local BUTTON_HEIGHT = 24
local ENTRY_HEIGHT = 24
local SCROLLBAR_WIDTH = 20      -- Width reserved for scrollbars (18px bar + 2px gap)

-- Stat editor sizing (4-column layout)
local COLUMN_WIDTH = 160        -- Each stat column width
local ROW_HEIGHT = 16           -- Stat row height
local ROW_SPACING = 1           -- Spacing between stat rows
local HEADER_HEIGHT = 14        -- Category header height
local HEADER_SPACING = 6        -- Spacing above headers

-- Scale list sizing
local SCALE_LIST_WIDTH = 200    -- Left panel width for scale list

-- ========================================
-- Color Palette (Modern, clean look)
-- ========================================
local COLORS = {
    -- Backgrounds
    windowBg = { 0.06, 0.06, 0.06, 0.98 },
    panelBg = { 0.04, 0.04, 0.04, 0.95 },
    inputBg = { 0.08, 0.08, 0.08, 0.95 },
    buttonBg = { 0.15, 0.15, 0.15, 1 },
    buttonHover = { 0.22, 0.22, 0.22, 1 },
    buttonPressed = { 0.1, 0.1, 0.1, 1 },
    
    -- Borders
    border = { 0.35, 0.35, 0.35, 1 },
    borderLight = { 0.45, 0.45, 0.45, 1 },
    borderDark = { 0.25, 0.25, 0.25, 1 },
    
    -- Text
    textTitle = { 0.9, 0.9, 0.9, 1 },
    textHeader = { 0.75, 0.75, 0.75, 1 },
    textBody = { 0.85, 0.85, 0.85, 1 },
    textDim = { 0.5, 0.5, 0.5, 1 },
    textAccent = { 0.4, 0.7, 0.9, 1 },  -- Soft blue accent
    
    -- States
    selected = { 0.25, 0.45, 0.65, 1 },
    selectedBorder = { 0.4, 0.6, 0.8, 1 },
    disabled = { 0.3, 0.3, 0.3, 0.6 },
}

-- Standardized Border Styles
local BORDER_TOOLTIP = "Interface\\Tooltips\\UI-Tooltip-Border"  -- Clean, minimal border
local BORDER_EDGE_SIZE = 12

-- Backdrop presets for consistent styling
local BACKDROP_WINDOW = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = 16,
    tile = false,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
}

local BACKDROP_PANEL = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = BORDER_EDGE_SIZE,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local BACKDROP_INPUT = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = 10,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

local BACKDROP_BUTTON = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = BORDER_TOOLTIP,
    edgeSize = BORDER_EDGE_SIZE,
    tile = false,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

-- ========================================
-- Input Validation Functions
-- ========================================

-- Validates and cleans numeric stat value input
-- Allows: up to 5 digits, one decimal point, minus sign at start only
-- Returns: cleaned string that meets validation rules
local function ValidateStatValueInput(text)
    if not text or text == "" then return "" end
    
    -- Allow lone minus sign temporarily (for better UX when typing)
    if text == "-" then return "-" end
    
    -- Check if starts with minus
    local hasNegative = text:sub(1, 1) == "-"
    local workingText = hasNegative and text:sub(2) or text
    
    -- Remove all invalid characters (keep only digits and one decimal)
    local cleaned = ""
    local decimalCount = 0
    local digitCount = 0
    
    for i = 1, #workingText do
        local char = workingText:sub(i, i)
        
        if char == "." then
            -- Only allow one decimal point
            if decimalCount == 0 then
                cleaned = cleaned .. char
                decimalCount = decimalCount + 1
            end
        elseif char:match("%d") then
            -- Only allow up to 5 digits total
            if digitCount < 5 then
                cleaned = cleaned .. char
                digitCount = digitCount + 1
            end
        end
        -- Silently skip any other characters
    end
    
    -- Prevent malformed inputs like ".", ".5" without leading zero is ok, but lone "." is not
    if cleaned == "." then
        cleaned = ""
    end
    
    -- Add back negative sign if it was present
    if hasNegative and cleaned ~= "" then
        cleaned = "-" .. cleaned
    end
    
    return cleaned
end

-- Validates whole number input (for decimal places setting)
-- Allows: only digits 0-9, no decimals or signs
-- Returns: cleaned string with only digits
local function ValidateWholeNumberInput(text)
    if not text or text == "" then return "" end
    
    -- Remove all non-digit characters
    local cleaned = text:gsub("[^0-9]", "")
    
    return cleaned
end

-- Applies validation to an EditBox for stat values
local function ApplyStatValueValidation(editBox)
    -- Intercept text changes (handles both typing and pasting)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            local validText = ValidateStatValueInput(text)
            
            if text ~= validText then
                local cursorPos = self:GetCursorPosition()
                self:SetText(validText)
                -- Adjust cursor position to stay at roughly the same place
                self:SetCursorPosition(math.min(cursorPos, #validText))
            end
        end
    end)
end

-- Applies validation to an EditBox for whole numbers
local function ApplyWholeNumberValidation(editBox)
    -- Intercept text changes (handles both typing and pasting)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local text = self:GetText()
            local validText = ValidateWholeNumberInput(text)
            
            if text ~= validText then
                local cursorPos = self:GetCursorPosition()
                self:SetText(validText)
                -- Adjust cursor position to stay at roughly the same place
                self:SetCursorPosition(math.min(cursorPos, #validText))
            end
        end
    end)
end

-- Font Standards (all use white/highlight fonts for modern look)
local FONT_TITLE = "GameFontHighlightLarge"    -- ~16pt, white
local FONT_H1 = "GameFontHighlight"            -- ~12pt, white  
local FONT_H2 = "GameFontHighlightSmall"       -- ~10pt, white
local FONT_H3 = "GameFontHighlightSmall"       -- ~10pt, white
local FONT_BODY = "GameFontHighlight"          -- ~12pt, white
local FONT_SMALL = "GameFontHighlightSmall"    -- ~10pt, white

-- Helper function: Safe tooltip display (checks if dragging)
local function ShowTooltipSafe(frame, anchorType)
    if not IsDraggingFrame then
        GameTooltip:SetOwner(frame, anchorType or "ANCHOR_RIGHT")
        return true
    end
    return false
end

-- Main UI Frame
local ValuateUIFrame = nil
local CurrentSelectedScale = nil
local EditingScaleName = nil
local OriginalScaleData = nil
local IsDraggingFrame = false  -- Track if any frame is being dragged

-- Icon Picker state
local IconPickerFrame = nil
local IconPickerCallback = nil

-- Template Picker state
local TemplatePickerFrame = nil  -- Full picker (all classes)
local ClassSpecificPickerFrame = nil  -- Class-specific picker

-- Forward declaration for overwrite callback
local ValuateUI_OnTemplateOverwrite = nil

-- Curated icon list (safe, common icons that exist in WotLK 3.3.5a)
local SCALE_ICON_LIST = {
    -- No Icon Option (always first)
    "",  -- Empty = no icon (clear selection)
    
    -- Classes
    "Interface\\Icons\\ClassIcon_Warrior",
    "Interface\\Icons\\ClassIcon_Paladin",
    "Interface\\Icons\\ClassIcon_Hunter",
    "Interface\\Icons\\ClassIcon_Rogue",
    "Interface\\Icons\\ClassIcon_Priest",
    "Interface\\Icons\\ClassIcon_DeathKnight",
    "Interface\\Icons\\ClassIcon_Shaman",
    "Interface\\Icons\\ClassIcon_Mage",
    "Interface\\Icons\\ClassIcon_Warlock",
    "Interface\\Icons\\ClassIcon_Druid",
    
    -- Warrior Abilities
    "Interface\\Icons\\Ability_Warrior_OffensiveStance",
    "Interface\\Icons\\Ability_Warrior_DefensiveStance",
    "Interface\\Icons\\Ability_Warrior_BattleShout",
    "Interface\\Icons\\Ability_Warrior_InnerRage",
    "Interface\\Icons\\Ability_Warrior_SavageBlow",
    "Interface\\Icons\\Ability_Warrior_Charge",
    "Interface\\Icons\\Ability_Warrior_BattleShout",
    "Interface\\Icons\\Ability_Warrior_Revenge",
    "Interface\\Icons\\Ability_Warrior_Sunder",
    "Interface\\Icons\\Ability_Warrior_ShieldBash",
    
    -- Paladin Abilities
    "Interface\\Icons\\Spell_Holy_HolyBolt",
    "Interface\\Icons\\Spell_Holy_HolySmite",
    "Interface\\Icons\\Spell_Holy_SealOfMight",
    "Interface\\Icons\\Spell_Holy_SealOfWrath",
    "Interface\\Icons\\Spell_Holy_DivineIntervention",
    "Interface\\Icons\\Spell_Holy_LayOnHands",
    "Interface\\Icons\\Ability_Paladin_ShieldoftheTemplar",
    "Interface\\Icons\\Spell_Holy_RighteousFury",
    "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    "Interface\\Icons\\Spell_Holy_AuraOfLight",
    
    -- Hunter Abilities
    "Interface\\Icons\\Ability_Hunter_AimedShot",
    "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
    "Interface\\Icons\\Ability_Hunter_BeastCall",
    "Interface\\Icons\\Ability_Hunter_SilencingShot",
    "Interface\\Icons\\Ability_Hunter_RunningShot",
    "Interface\\Icons\\Ability_Hunter_RapidFire",
    "Interface\\Icons\\Ability_Hunter_SteadyShot",
    "Interface\\Icons\\Ability_Hunter_Pet_Bear",
    "Interface\\Icons\\Ability_Hunter_Pet_Cat",
    "Interface\\Icons\\Ability_Hunter_Pet_Wolf",
    
    -- Rogue Abilities
    "Interface\\Icons\\Ability_Rogue_Eviscerate",
    "Interface\\Icons\\Ability_Rogue_ShadowDance",
    "Interface\\Icons\\Ability_Rogue_Ambush",
    "Interface\\Icons\\Ability_Rogue_Feint",
    "Interface\\Icons\\Ability_Rogue_SliceDice",
    "Interface\\Icons\\Ability_Rogue_Sprint",
    "Interface\\Icons\\Ability_Rogue_Garrote",
    "Interface\\Icons\\Ability_Rogue_KidneyShot",
    "Interface\\Icons\\Ability_Rogue_RuptureFemaleBloodElf",
    "Interface\\Icons\\Ability_Rogue_Dismantle",
    
    -- Priest Abilities
    "Interface\\Icons\\Spell_Holy_PowerWordShield",
    "Interface\\Icons\\Spell_Holy_FlashHeal",
    "Interface\\Icons\\Spell_Holy_GuardianSpirit",
    "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Spell_Shadow_VampiricEmbrace",
    "Interface\\Icons\\Spell_Shadow_Shadowform",
    "Interface\\Icons\\Spell_Holy_Renew",
    "Interface\\Icons\\Spell_Holy_DivineSpirit",
    "Interface\\Icons\\Spell_Holy_Resurrection",
    
    -- Death Knight Abilities
    "Interface\\Icons\\Spell_Deathknight_IceTouch",
    "Interface\\Icons\\Spell_Deathknight_Strangulate",
    "Interface\\Icons\\Spell_Shadow_DeathScream",
    "Interface\\Icons\\Spell_Deathknight_FrostPresence",
    "Interface\\Icons\\Spell_Deathknight_BloodPresence",
    "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
    "Interface\\Icons\\Spell_Deathknight_DeathStrike",
    "Interface\\Icons\\Spell_Shadow_SoulLeech_2",
    "Interface\\Icons\\Spell_Shadow_RaiseDead",
    "Interface\\Icons\\Spell_Shadow_AnimateDead",
    
    -- Shaman Abilities
    "Interface\\Icons\\Spell_Nature_Lightning",
    "Interface\\Icons\\Spell_Nature_LightningShield",
    "Interface\\Icons\\Spell_Nature_MagicImmunity",
    "Interface\\Icons\\Spell_Nature_ChainLightning",
    "Interface\\Icons\\Spell_Shaman_LavaLash",
    "Interface\\Icons\\Spell_Fire_Elemental_Totem",
    "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
    "Interface\\Icons\\Spell_Nature_MagicImmunity",
    "Interface\\Icons\\Spell_Shaman_Hex",
    "Interface\\Icons\\Ability_Shaman_Stormstrike",
    
    -- Mage Abilities
    "Interface\\Icons\\Spell_Fire_FireBolt02",
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Arcane_Blast",
    "Interface\\Icons\\Spell_Fire_Flamebolt",
    "Interface\\Icons\\Spell_Frost_IceStorm",
    "Interface\\Icons\\Spell_Arcane_Blink",
    "Interface\\Icons\\Spell_Fire_MeteorStorm",
    "Interface\\Icons\\Spell_Frost_FrostNova",
    "Interface\\Icons\\Spell_Arcane_MassDispel",
    "Interface\\Icons\\Spell_Arcane_PortalDalaran",
    
    -- Warlock Abilities
    "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
    "Interface\\Icons\\Spell_Shadow_CurseOfTounges",
    "Interface\\Icons\\Spell_Shadow_DeathCoil",
    "Interface\\Icons\\Spell_Shadow_MetamorphosisStun",
    "Interface\\Icons\\Spell_Shadow_RainOfFire",
    "Interface\\Icons\\Spell_Shadow_SiphonMana",
    "Interface\\Icons\\Spell_Shadow_SummonFelHunter",
    "Interface\\Icons\\Spell_Shadow_SummonImp",
    "Interface\\Icons\\Spell_Shadow_UnstableAffliction_3",
    
    -- Druid Abilities
    "Interface\\Icons\\Spell_Nature_StarFall",
    "Interface\\Icons\\Spell_Nature_HealingTouch",
    "Interface\\Icons\\Ability_Racial_BearForm",
    "Interface\\Icons\\Ability_Druid_CatForm",
    "Interface\\Icons\\Spell_Nature_ForceOfNature",
    "Interface\\Icons\\Ability_Druid_TreeofLife",
    "Interface\\Icons\\Spell_Nature_Rejuvenation",
    "Interface\\Icons\\Spell_Nature_ThornAura",
    "Interface\\Icons\\Ability_Druid_Enrage",
    "Interface\\Icons\\Ability_Druid_Swipe",
    
    -- Weapon Icons
    "Interface\\Icons\\INV_Sword_04",
    "Interface\\Icons\\INV_Sword_27",
    "Interface\\Icons\\INV_Axe_09",
    "Interface\\Icons\\INV_Mace_01MD",
    "Interface\\Icons\\INV_Staff_13",
    "Interface\\Icons\\INV_Weapon_Bow_07",
    "Interface\\Icons\\INV_Weapon_Crossbow_06",
    "Interface\\Icons\\INV_Weapon_Rifle_01",
    "Interface\\Icons\\INV_ThrowingKnife_04",
    "Interface\\Icons\\INV_Wand_07",
    
    -- Shield/Offhand
    "Interface\\Icons\\INV_Shield_06",
    "Interface\\Icons\\INV_Shield_17",
    "Interface\\Icons\\INV_Offhand_Hyjal_D_01",
    "Interface\\Icons\\Ability_Defend",
    
    -- Dual Wield & Combat Styles
    "Interface\\Icons\\Ability_DualWield",
    "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
    "Interface\\Icons\\Ability_Backstab",
    "Interface\\Icons\\Ability_MeleeDamage",
    
    -- Armor Types
    "Interface\\Icons\\INV_Helmet_25",
    "Interface\\Icons\\INV_Chest_Leather_08",
    "Interface\\Icons\\INV_Chest_Chain_03",
    "Interface\\Icons\\INV_Chest_Plate01",
    "Interface\\Icons\\INV_Shoulder_23",
    "Interface\\Icons\\INV_Gauntlets_19",
    "Interface\\Icons\\INV_Belt_20",
    "Interface\\Icons\\INV_Pants_06",
    "Interface\\Icons\\INV_Boots_Plate_01",
    
    -- Jewelry
    "Interface\\Icons\\INV_Jewelry_Ring_03",
    "Interface\\Icons\\INV_Jewelry_Ring_08",
    "Interface\\Icons\\INV_Jewelry_Necklace_05",
    "Interface\\Icons\\INV_Jewelry_Talisman_03",
    
    -- Spell Schools
    "Interface\\Icons\\Spell_Fire_FlameShock",
    "Interface\\Icons\\Spell_Frost_FrostShock",
    "Interface\\Icons\\Spell_Nature_NatureTouchGrow",
    "Interface\\Icons\\Spell_Arcane_StarFire",
    "Interface\\Icons\\Spell_Shadow_ChillTouch",
    "Interface\\Icons\\Spell_Holy_InnerFire",
    
    -- Stats & Attributes
    "Interface\\Icons\\Spell_ChargePositive",
    "Interface\\Icons\\Spell_ChargeNegative",
    "Interface\\Icons\\Spell_Misc_Drink",
    "Interface\\Icons\\Spell_Holy_MindVision",
    "Interface\\Icons\\Ability_Racial_Avatar",
    "Interface\\Icons\\Ability_Stealth",
    
    -- Gems & Crafting
    "Interface\\Icons\\INV_Misc_Gem_02",
    "Interface\\Icons\\INV_Misc_Gem_Ruby_01",
    "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
    "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
    "Interface\\Icons\\INV_Misc_Gem_Diamond_01",
    "Interface\\Icons\\Trade_Engineering",
    "Interface\\Icons\\Trade_Blacksmithing",
    "Interface\\Icons\\Trade_Engraving",
    "Interface\\Icons\\Trade_Alchemy",
    
    -- PvP Icons
    "Interface\\Icons\\Achievement_PVP_A_01",
    "Interface\\Icons\\Achievement_PVP_H_01",
    "Interface\\Icons\\Achievement_Arena_2v2_1",
    "Interface\\Icons\\Achievement_Arena_3v3_1",
    "Interface\\Icons\\Achievement_Arena_5v5_1",
    "Interface\\Icons\\Achievement_BG_killXenemies_generalsroom",
    
    -- Raid & Dungeon
    "Interface\\Icons\\Achievement_Boss_Archimonde",
    "Interface\\Icons\\Achievement_Boss_Illidan",
    "Interface\\Icons\\Achievement_Boss_LichKing",
    "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    "Interface\\Icons\\Achievement_Dungeon_UlduarRaid_Misc_05",
    
    -- Misc Useful Icons
    "Interface\\Icons\\INV_Misc_Gear_01",
    "Interface\\Icons\\INV_Misc_Book_09",
    "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
    "Interface\\Icons\\INV_Misc_MonsterClaw_04",
    "Interface\\Icons\\INV_Misc_MonsterFang_01",
    "Interface\\Icons\\Ability_Hunter_BeastTaming",
    "Interface\\Icons\\INV_Misc_QuestionMark",
    "Interface\\Icons\\Spell_Misc_EmotionHappy",
    "Interface\\Icons\\Spell_Misc_EmotionAfraid",
    "Interface\\Icons\\Spell_Shadow_Skull",
    "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    "Interface\\Icons\\Achievement_General",
    "Interface\\Icons\\Achievement_Reputation_01",
    "Interface\\Icons\\Achievement_Quests_Completed_08",
    "Interface\\Icons\\Trade_Engineering",
    "Interface\\Icons\\INV_Misc_Coin_01",
    "Interface\\Icons\\INV_Misc_Trophy_Gold",
    "Interface\\Icons\\INV_Misc_Trophy_Silver",
    "Interface\\Icons\\INV_Misc_Trophy_Bronze",
    "Interface\\Icons\\Spell_Holy_MindSooth",
    "Interface\\Icons\\Ability_Tracking",
    
    -- Special Effects
    "Interface\\Icons\\Spell_Nature_ShamanRage",
    "Interface\\Icons\\Spell_Shadow_MindSteal",
    "Interface\\Icons\\Spell_Holy_Dizzy",
    "Interface\\Icons\\Spell_Nature_Polymorph",
    "Interface\\Icons\\Spell_Ice_Lament",
    "Interface\\Icons\\Spell_Fire_SoulBurn",
    "Interface\\Icons\\Ability_Rogue_MasterOfSubtlety",
    "Interface\\Icons\\Spell_Nature_WispSplode",
    
    -- More Weapons - Swords
    "Interface\\Icons\\INV_Sword_01",
    "Interface\\Icons\\INV_Sword_02",
    "Interface\\Icons\\INV_Sword_05",
    "Interface\\Icons\\INV_Sword_06",
    "Interface\\Icons\\INV_Sword_09",
    "Interface\\Icons\\INV_Sword_11",
    "Interface\\Icons\\INV_Sword_15",
    "Interface\\Icons\\INV_Sword_18",
    "Interface\\Icons\\INV_Sword_20",
    "Interface\\Icons\\INV_Sword_27",
    "Interface\\Icons\\INV_Sword_39",
    "Interface\\Icons\\INV_Sword_48",
    "Interface\\Icons\\INV_Sword_62",
    
    -- More Weapons - Axes
    "Interface\\Icons\\INV_Axe_01",
    "Interface\\Icons\\INV_Axe_02",
    "Interface\\Icons\\INV_Axe_03",
    "Interface\\Icons\\INV_Axe_06",
    "Interface\\Icons\\INV_Axe_11",
    "Interface\\Icons\\INV_Axe_23",
    "Interface\\Icons\\INV_Axe_68",
    "Interface\\Icons\\INV_Axe_80",
    "Interface\\Icons\\INV_Axe_113",
    
    -- More Weapons - Maces
    "Interface\\Icons\\INV_Mace_01",
    "Interface\\Icons\\INV_Mace_02",
    "Interface\\Icons\\INV_Mace_03",
    "Interface\\Icons\\INV_Mace_04",
    "Interface\\Icons\\INV_Mace_07",
    "Interface\\Icons\\INV_Mace_11",
    "Interface\\Icons\\INV_Mace_15",
    "Interface\\Icons\\INV_Hammer_01",
    "Interface\\Icons\\INV_Hammer_02",
    "Interface\\Icons\\INV_Hammer_09",
    "Interface\\Icons\\INV_Hammer_15",
    "Interface\\Icons\\INV_Hammer_20",
    
    -- More Weapons - Daggers
    "Interface\\Icons\\INV_Weapon_ShortBlade_05",
    "Interface\\Icons\\INV_Weapon_ShortBlade_12",
    "Interface\\Icons\\INV_Weapon_ShortBlade_15",
    "Interface\\Icons\\INV_Weapon_ShortBlade_25",
    "Interface\\Icons\\INV_Weapon_ShortBlade_78",
    
    -- More Weapons - Staves
    "Interface\\Icons\\INV_Staff_01",
    "Interface\\Icons\\INV_Staff_02",
    "Interface\\Icons\\INV_Staff_05",
    "Interface\\Icons\\INV_Staff_08",
    "Interface\\Icons\\INV_Staff_13",
    "Interface\\Icons\\INV_Staff_30",
    "Interface\\Icons\\INV_Staff_56",
    
    -- More Weapons - Polearms
    "Interface\\Icons\\INV_Spear_01",
    "Interface\\Icons\\INV_Spear_02",
    "Interface\\Icons\\INV_Spear_03",
    "Interface\\Icons\\INV_Spear_05",
    "Interface\\Icons\\INV_Spear_07",
    
    -- More Weapons - Fist Weapons
    "Interface\\Icons\\INV_Gauntlets_05",
    "Interface\\Icons\\INV_Gauntlets_04",
    "Interface\\Icons\\INV_Weapon_Hand_01",
    
    -- More Ranged Weapons
    "Interface\\Icons\\INV_Weapon_Bow_01",
    "Interface\\Icons\\INV_Weapon_Bow_08",
    "Interface\\Icons\\INV_Weapon_Bow_13",
    "Interface\\Icons\\INV_Weapon_Crossbow_02",
    "Interface\\Icons\\INV_Weapon_Crossbow_07",
    "Interface\\Icons\\INV_Weapon_Rifle_07",
    "Interface\\Icons\\INV_Weapon_Rifle_08",
    
    -- More Shields
    "Interface\\Icons\\INV_Shield_01",
    "Interface\\Icons\\INV_Shield_02",
    "Interface\\Icons\\INV_Shield_04",
    "Interface\\Icons\\INV_Shield_05",
    "Interface\\Icons\\INV_Shield_09",
    "Interface\\Icons\\INV_Shield_19",
    "Interface\\Icons\\INV_Shield_20",
    "Interface\\Icons\\INV_Shield_27",
    
    -- Totems & Relics
    "Interface\\Icons\\INV_Misc_MonsterClaw_03",
    "Interface\\Icons\\Spell_Frost_SummonWaterElemental_2",
    "Interface\\Icons\\Spell_Fire_TotemOfWrath",
    "Interface\\Icons\\Spell_Nature_EarthBindTotem",
    "Interface\\Icons\\Spell_Fire_SearingTotem",
    "Interface\\Icons\\INV_Relics_IdolofFerocity",
    "Interface\\Icons\\INV_Relics_LibramofHope",
    "Interface\\Icons\\INV_Relics_TotemofRage",
    "Interface\\Icons\\INV_Jewelry_Talisman_07",
    
    -- More Armor - Helmets
    "Interface\\Icons\\INV_Helmet_01",
    "Interface\\Icons\\INV_Helmet_03",
    "Interface\\Icons\\INV_Helmet_08",
    "Interface\\Icons\\INV_Helmet_09",
    "Interface\\Icons\\INV_Helmet_15",
    "Interface\\Icons\\INV_Helmet_23",
    "Interface\\Icons\\INV_Helmet_31",
    "Interface\\Icons\\INV_Helmet_62",
    "Interface\\Icons\\INV_Helmet_74",
    "Interface\\Icons\\INV_Helmet_96",
    
    -- More Armor - Chest
    "Interface\\Icons\\INV_Chest_Cloth_07",
    "Interface\\Icons\\INV_Chest_Cloth_25",
    "Interface\\Icons\\INV_Chest_Cloth_45",
    "Interface\\Icons\\INV_Chest_Leather_01",
    "Interface\\Icons\\INV_Chest_Leather_03",
    "Interface\\Icons\\INV_Chest_Leather_06",
    "Interface\\Icons\\INV_Chest_Chain_11",
    "Interface\\Icons\\INV_Chest_Chain_16",
    "Interface\\Icons\\INV_Chest_Plate03",
    "Interface\\Icons\\INV_Chest_Plate06",
    "Interface\\Icons\\INV_Chest_Plate16",
    
    -- More Armor - Shoulders
    "Interface\\Icons\\INV_Shoulder_01",
    "Interface\\Icons\\INV_Shoulder_02",
    "Interface\\Icons\\INV_Shoulder_05",
    "Interface\\Icons\\INV_Shoulder_10",
    "Interface\\Icons\\INV_Shoulder_14",
    "Interface\\Icons\\INV_Shoulder_22",
    "Interface\\Icons\\INV_Shoulder_25",
    "Interface\\Icons\\INV_Shoulder_36",
    
    -- More Armor - Gloves
    "Interface\\Icons\\INV_Gauntlets_03",
    "Interface\\Icons\\INV_Gauntlets_09",
    "Interface\\Icons\\INV_Gauntlets_17",
    "Interface\\Icons\\INV_Gauntlets_27",
    "Interface\\Icons\\INV_Gauntlets_32",
    "Interface\\Icons\\INV_Gauntlets_62",
    
    -- More Armor - Legs
    "Interface\\Icons\\INV_Pants_01",
    "Interface\\Icons\\INV_Pants_02",
    "Interface\\Icons\\INV_Pants_03",
    "Interface\\Icons\\INV_Pants_04",
    "Interface\\Icons\\INV_Pants_08",
    "Interface\\Icons\\INV_Pants_14",
    
    -- More Armor - Boots
    "Interface\\Icons\\INV_Boots_01",
    "Interface\\Icons\\INV_Boots_02",
    "Interface\\Icons\\INV_Boots_05",
    "Interface\\Icons\\INV_Boots_08",
    "Interface\\Icons\\INV_Boots_Chain_04",
    "Interface\\Icons\\INV_Boots_Plate_03",
    
    -- More Armor - Belts
    "Interface\\Icons\\INV_Belt_01",
    "Interface\\Icons\\INV_Belt_03",
    "Interface\\Icons\\INV_Belt_07",
    "Interface\\Icons\\INV_Belt_09",
    "Interface\\Icons\\INV_Belt_13",
    "Interface\\Icons\\INV_Belt_16",
    "Interface\\Icons\\INV_Belt_23",
    
    -- More Armor - Cloaks
    "Interface\\Icons\\INV_Misc_Cape_02",
    "Interface\\Icons\\INV_Misc_Cape_07",
    "Interface\\Icons\\INV_Misc_Cape_11",
    "Interface\\Icons\\INV_Misc_Cape_18",
    "Interface\\Icons\\INV_Misc_Cape_20",
    
    -- More Jewelry - Rings
    "Interface\\Icons\\INV_Jewelry_Ring_01",
    "Interface\\Icons\\INV_Jewelry_Ring_02",
    "Interface\\Icons\\INV_Jewelry_Ring_04",
    "Interface\\Icons\\INV_Jewelry_Ring_05",
    "Interface\\Icons\\INV_Jewelry_Ring_07",
    "Interface\\Icons\\INV_Jewelry_Ring_11",
    "Interface\\Icons\\INV_Jewelry_Ring_15",
    "Interface\\Icons\\INV_Jewelry_Ring_36",
    "Interface\\Icons\\INV_Jewelry_Ring_51",
    
    -- More Jewelry - Necklaces
    "Interface\\Icons\\INV_Jewelry_Necklace_01",
    "Interface\\Icons\\INV_Jewelry_Necklace_03",
    "Interface\\Icons\\INV_Jewelry_Necklace_07",
    "Interface\\Icons\\INV_Jewelry_Necklace_08",
    "Interface\\Icons\\INV_Jewelry_Necklace_12",
    "Interface\\Icons\\INV_Jewelry_Necklace_16",
    
    -- Trinkets
    "Interface\\Icons\\INV_Jewelry_Talisman_01",
    "Interface\\Icons\\INV_Jewelry_Talisman_04",
    "Interface\\Icons\\INV_Jewelry_Talisman_06",
    "Interface\\Icons\\INV_Jewelry_Talisman_08",
    "Interface\\Icons\\INV_Jewelry_Talisman_11",
    "Interface\\Icons\\INV_Misc_PocketWatch_01",
    "Interface\\Icons\\INV_Misc_PocketWatch_02",
    "Interface\\Icons\\INV_Misc_Rune_01",
    "Interface\\Icons\\INV_Misc_Rune_06",
    
    -- More Gems
    "Interface\\Icons\\INV_Misc_Gem_01",
    "Interface\\Icons\\INV_Misc_Gem_03",
    "Interface\\Icons\\INV_Misc_Gem_04",
    "Interface\\Icons\\INV_Misc_Gem_05",
    "Interface\\Icons\\INV_Misc_Gem_Stone_01",
    "Interface\\Icons\\INV_Misc_Gem_Bloodstone_01",
    "Interface\\Icons\\INV_Misc_Gem_Topaz_01",
    "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
    "Interface\\Icons\\INV_Misc_Gem_Pearl_01",
    "Interface\\Icons\\INV_Misc_Gem_Pearl_03",
    "Interface\\Icons\\INV_Misc_Gem_Opal_01",
    "Interface\\Icons\\INV_Misc_Gem_Variety_01",
    
    -- More Spell Effects - Fire
    "Interface\\Icons\\Spell_Fire_Immolation",
    "Interface\\Icons\\Spell_Fire_Fire",
    "Interface\\Icons\\Spell_Fire_FelFlameRing",
    "Interface\\Icons\\Spell_Fire_FelFlameStrike",
    "Interface\\Icons\\Spell_Fire_FelfireGreen",
    "Interface\\Icons\\Spell_Fire_Burnout",
    "Interface\\Icons\\Spell_Fire_BlueFlameRing",
    "Interface\\Icons\\Spell_Fire_BlueHellfire",
    "Interface\\Icons\\Spell_Fire_Volcano",
    "Interface\\Icons\\Spell_Fire_Twilightimmolation",
    
    -- More Spell Effects - Frost
    "Interface\\Icons\\Spell_Frost_IceFloes",
    "Interface\\Icons\\Spell_Frost_Frost",
    "Interface\\Icons\\Spell_Frost_FreezingBreath",
    "Interface\\Icons\\Spell_Frost_FrostArmor02",
    "Interface\\Icons\\Spell_Frost_FrostBlast",
    "Interface\\Icons\\Spell_Frost_ChillingBlast",
    "Interface\\Icons\\Spell_Frost_ArcticWinds",
    "Interface\\Icons\\Spell_Frost_Glacier",
    "Interface\\Icons\\Spell_Ice_MagicDamage",
    
    -- More Spell Effects - Nature
    "Interface\\Icons\\Spell_Nature_Thorns",
    "Interface\\Icons\\Spell_Nature_NatureTouched",
    "Interface\\Icons\\Spell_Nature_NatureWrath",
    "Interface\\Icons\\Spell_Nature_Regeneration",
    "Interface\\Icons\\Spell_Nature_Earthquake",
    "Interface\\Icons\\Spell_Nature_Cyclone",
    "Interface\\Icons\\Spell_Nature_StormReach",
    "Interface\\Icons\\Spell_Nature_RavenForm",
    "Interface\\Icons\\Spell_Nature_Tranquility",
    "Interface\\Icons\\Spell_Nature_ResistNature",
    
    -- More Spell Effects - Shadow
    "Interface\\Icons\\Spell_Shadow_DarkRitual",
    "Interface\\Icons\\Spell_Shadow_DemonicFortitude",
    "Interface\\Icons\\Spell_Shadow_DemonicEmpathy",
    "Interface\\Icons\\Spell_Shadow_DemonBreath",
    "Interface\\Icons\\Spell_Shadow_NightOfTheDead",
    "Interface\\Icons\\Spell_Shadow_Shadowfiend",
    "Interface\\Icons\\Spell_Shadow_Shades",
    "Interface\\Icons\\Spell_Shadow_ShadowEmbrace",
    "Interface\\Icons\\Spell_Shadow_Twilight",
    "Interface\\Icons\\Spell_Shadow_Possession",
    
    -- More Spell Effects - Holy/Light
    "Interface\\Icons\\Spell_Holy_Heal",
    "Interface\\Icons\\Spell_Holy_HolyProtection",
    "Interface\\Icons\\Spell_Holy_Silence",
    "Interface\\Icons\\Spell_Holy_SealOfWisdom",
    "Interface\\Icons\\Spell_Holy_Purify",
    "Interface\\Icons\\Spell_Holy_PrayerOfMentalAgility",
    "Interface\\Icons\\Spell_Holy_PrayerOfSpirit",
    "Interface\\Icons\\Spell_Holy_SummonChampion",
    "Interface\\Icons\\Spell_Holy_AshesToAshes",
    "Interface\\Icons\\Spell_Holy_BlessedRecovery",
    
    -- More Spell Effects - Arcane
    "Interface\\Icons\\Spell_Arcane_ArcanePotency",
    "Interface\\Icons\\Spell_Arcane_ArcaneResilience",
    "Interface\\Icons\\Spell_Arcane_ArcaneTorrent",
    "Interface\\Icons\\Spell_Arcane_MindMastery",
    "Interface\\Icons\\Spell_Arcane_PrismaticCloak",
    "Interface\\Icons\\Spell_Arcane_StudentOfMagic",
    "Interface\\Icons\\Spell_Arcane_Arcane01",
    "Interface\\Icons\\Spell_Arcane_Arcane02",
    "Interface\\Icons\\Spell_Arcane_Arcane03",
    
    -- Stat Icons
    "Interface\\Icons\\Ability_Warrior_StrengthOfArmsMortal",
    "Interface\\Icons\\Ability_Hunter_Pet_Dragonhawk",
    "Interface\\Icons\\Spell_Nature_AstralRecalGroup",
    "Interface\\Icons\\Ability_Warrior_Trauma",
    "Interface\\Icons\\Ability_Warrior_Vigilance",
    "Interface\\Icons\\Ability_Warrior_VictoryRush",
    "Interface\\Icons\\Ability_Warrior_WarCry",
    "Interface\\Icons\\Spell_Holy_ElunesGrace",
    "Interface\\Icons\\Spell_Holy_MindSooth",
    
    -- Profession Icons - More Detailed
    "Interface\\Icons\\Trade_Alchemy",
    "Interface\\Icons\\Trade_BlackSmithing",
    "Interface\\Icons\\Trade_BrewPoison",
    "Interface\\Icons\\Trade_Engineering",
    "Interface\\Icons\\Trade_Engraving",
    "Interface\\Icons\\Trade_Fishing",
    "Interface\\Icons\\Trade_Herbalism",
    "Interface\\Icons\\Trade_LeatherWorking",
    "Interface\\Icons\\Trade_Mining",
    "Interface\\Icons\\Trade_Tailoring",
    "Interface\\Icons\\INV_Inscription_Tradeskill01",
    "Interface\\Icons\\INV_Misc_Food_15",
    "Interface\\Icons\\INV_Misc_Food_95_Tacodish",
    "Interface\\Icons\\INV_Drink_05",
    
    -- Consumables
    "Interface\\Icons\\INV_Potion_01",
    "Interface\\Icons\\INV_Potion_02",
    "Interface\\Icons\\INV_Potion_03",
    "Interface\\Icons\\INV_Potion_52",
    "Interface\\Icons\\INV_Potion_54",
    "Interface\\Icons\\INV_Potion_61",
    "Interface\\Icons\\INV_Alchemy_Elixir_01",
    "Interface\\Icons\\INV_Alchemy_Elixir_02",
    "Interface\\Icons\\INV_Alchemy_Elixir_04",
    "Interface\\Icons\\Spell_Shadow_ImpPhaseShift",
    
    -- More Achievements
    "Interface\\Icons\\Achievement_General_StayClassy",
    "Interface\\Icons\\Achievement_Character_Human_Female",
    "Interface\\Icons\\Achievement_Character_Human_Male",
    "Interface\\Icons\\Achievement_Character_Orc_Female",
    "Interface\\Icons\\Achievement_Character_Orc_Male",
    "Interface\\Icons\\Achievement_Feats_of_strength_01",
    "Interface\\Icons\\Achievement_Feats_of_strength_02",
    "Interface\\Icons\\Achievement_BG_winWSG",
    "Interface\\Icons\\Achievement_BG_winAB",
    "Interface\\Icons\\Achievement_BG_winAV",
    "Interface\\Icons\\Achievement_BG_winEOTS",
    
    -- Boss & Creature Icons
    "Interface\\Icons\\INV_Misc_Head_Dragon_Black",
    "Interface\\Icons\\INV_Misc_Head_Dragon_Blue",
    "Interface\\Icons\\INV_Misc_Head_Dragon_Bronze",
    "Interface\\Icons\\INV_Misc_Head_Dragon_Green",
    "Interface\\Icons\\INV_Misc_Head_Dragon_Red",
    "Interface\\Icons\\INV_Misc_MonsterHead_01",
    "Interface\\Icons\\INV_Misc_MonsterHead_02",
    "Interface\\Icons\\INV_Misc_MonsterHead_03",
    "Interface\\Icons\\Ability_Mount_Drake_Proto",
    "Interface\\Icons\\Ability_Mount_Drake_Twilight",
    
    -- Elements & Nature
    "Interface\\Icons\\Spell_Fire_ElementalDevastation",
    "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
    "Interface\\Icons\\Spell_Nature_ElementalShields",
    "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
    "Interface\\Icons\\Spell_Arcane_TeleportStormwind",
    "Interface\\Icons\\Spell_Arcane_TeleportIronForge",
    
    -- Money & Rewards
    "Interface\\Icons\\INV_Misc_Coin_02",
    "Interface\\Icons\\INV_Misc_Coin_16",
    "Interface\\Icons\\INV_Misc_Coin_17",
    "Interface\\Icons\\INV_Misc_Bag_10",
    "Interface\\Icons\\INV_Misc_Bag_16",
    "Interface\\Icons\\INV_Misc_Bag_26",
    "Interface\\Icons\\INV_Box_01",
    "Interface\\Icons\\INV_Box_02",
    "Interface\\Icons\\INV_Box_04",
    "Interface\\Icons\\INV_Chest_Cloth_04",
    
    -- Misc Useful
    "Interface\\Icons\\INV_Misc_ArmorKit_03",
    "Interface\\Icons\\INV_Misc_ArmorKit_17",
    "Interface\\Icons\\INV_Misc_Note_01",
    "Interface\\Icons\\INV_Scroll_02",
    "Interface\\Icons\\INV_Scroll_05",
    "Interface\\Icons\\INV_Banner_02",
    "Interface\\Icons\\INV_Misc_Map02",
    "Interface\\Icons\\INV_Misc_Orb_01",
    "Interface\\Icons\\INV_Misc_Orb_02",
    "Interface\\Icons\\INV_Misc_Orb_03",
    "Interface\\Icons\\INV_Misc_Orb_04",
    "Interface\\Icons\\INV_Misc_Orb_05",
    "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
    "Interface\\Icons\\Ability_Ambush",
    "Interface\\Icons\\Ability_Kick",
    "Interface\\Icons\\Ability_Vanish",
    
    -- Buffs & Debuffs
    "Interface\\Icons\\Spell_Magic_MageArmor",
    "Interface\\Icons\\Spell_Magic_LesserInvisibilty",
    "Interface\\Icons\\Spell_Magic_GreaterInvisibilty",
    "Interface\\Icons\\Spell_Holy_BlessingOfStrength",
    "Interface\\Icons\\Spell_Holy_BlessingOfStamina",
    "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom",
    "Interface\\Icons\\Spell_Holy_GreaterBlessingofSalvation",
    "Interface\\Icons\\Spell_Holy_GreaterHeal",
    "Interface\\Icons\\Ability_Warrior_CommandingShout",
    "Interface\\Icons\\Ability_Warrior_BattleShout",
    
    -- Racial Abilities
    "Interface\\Icons\\Ability_Racial_BloodRage",
    "Interface\\Icons\\Ability_Racial_BerserkerRage",
    "Interface\\Icons\\Ability_Racial_Cannibalize",
    "Interface\\Icons\\Ability_Racial_ForgedInFlames",
    "Interface\\Icons\\Spell_Shadow_RaceUndead",
    "Interface\\Icons\\Spell_Nature_TimeStop",
    
    -- Mounts & Pets
    "Interface\\Icons\\Ability_Mount_RidingHorse",
    "Interface\\Icons\\Ability_Mount_Dreadsteed",
    "Interface\\Icons\\Ability_Mount_ChargedDeathcharger",
    "Interface\\Icons\\Ability_Mount_GriffonGold",
    "Interface\\Icons\\Ability_Mount_WhiteTiger",
    "Interface\\Icons\\INV_Misc_Fish_02",
    "Interface\\Icons\\Ability_Hunter_Pet_Bat",
    "Interface\\Icons\\Ability_Hunter_Pet_Boar",
    "Interface\\Icons\\Ability_Hunter_Pet_Crab",
    "Interface\\Icons\\Ability_Hunter_Pet_Gorilla",
    "Interface\\Icons\\Ability_Hunter_Pet_Owl",
    "Interface\\Icons\\Ability_Hunter_Pet_Raptor",
    "Interface\\Icons\\Ability_Hunter_Pet_Spider",
    "Interface\\Icons\\Ability_Hunter_Pet_WindSerpent",
}

-- ValuateOptions and ValuateScales are initialized by Valuate:Initialize() in Valuate.lua
-- as simple SavedVariables tables

-- ========================================
-- Class/Spec Templates
-- ========================================

-- Template data for creating pre-configured scales for each class/spec
local CLASS_SPEC_TEMPLATES = {
    {
        class = "Warrior",
        color = "C79C6E",
        description = "Masters of melee combat, warriors charge into battle with unyielding strength and indomitable will.",
        specs = {
            {
                name = "Arms",
                icon = "Interface\\Icons\\Ability_Warrior_SavageBlow",
                color = "FF4444",  -- Red - aggressive DPS
                role = "DAMAGER",
                description = "Master of two-handed weapons, delivering devastating strikes and mortal wounds.",
                weights = {
                    Strength = 1.0, AttackPower = 0.5, CritRating = 0.8, HitRating = 1.0,
                    HasteRating = 0.6, ExpertiseRating = 0.9, ArmorPenetration = 0.7,
                    Agility = 0.3, Stamina = 0.2, Armor = 0.05, Spirit = 0.005,
                    Hp5 = 0.01, Health = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, FireResist = 0.01, FrostResist = 0.01,
                    ShadowResist = 0.01, NatureResist = 0.01, ArcaneResist = 0.01,
                    AllResist = 0.01, TwoHandDps = 0.75
                },
                unusable = {
                    -- Weapons (class cannot use)
                    IsWand = true, IsStaff = true,
                    -- Weapons (spec uses 2H only)
                    IsAxe = true, IsMace = true, IsSword = true, IsDagger = true, IsFist = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (2H only spec)
                    OffHandDPS = true, MainHandDPS = true, OneHandDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true,
                    -- Caster Stats (non-caster class)
                    Intellect = true, Mana = true, Mp5 = true, SpellPower = true,
                    SpellPenetration = true, HolySpellPower = true, FireSpellPower = true,
                    FrostSpellPower = true, ShadowSpellPower = true, NatureSpellPower = true,
                    ArcaneSpellPower = true
                }
            },
            {
                name = "Fury",
                icon = "Interface\\Icons\\Ability_Warrior_InnerRage",
                color = "FF8800",  -- Orange - berserker fury
                role = "DAMAGER",
                description = "Berserker wielding dual weapons, striking with reckless fury and brutal speed.",
                weights = {
                    Strength = 1.0, AttackPower = 0.5, CritRating = 0.9, HitRating = 1.0,
                    HasteRating = 0.7, ExpertiseRating = 0.9, ArmorPenetration = 0.8,
                    Agility = 0.3, Stamina = 0.2, Armor = 0.05, Spirit = 0.005,
                    Hp5 = 0.01, Health = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, FireResist = 0.01, FrostResist = 0.01,
                    ShadowResist = 0.01, NatureResist = 0.01, ArcaneResist = 0.01,
                    AllResist = 0.01, MainHandDps = 0.7, OffHandDps = 0.5, OneHandDps = 0.6
                },
                unusable = {
                    -- Weapons
                    IsWand = true, IsStaff = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true,
                    -- Caster Stats (non-caster class)
                    Intellect = true, Mana = true, Mp5 = true, SpellPower = true,
                    SpellPenetration = true, HolySpellPower = true, FireSpellPower = true,
                    FrostSpellPower = true, ShadowSpellPower = true, NatureSpellPower = true,
                    ArcaneSpellPower = true
                }
            },
            {
                name = "Protection",
                icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
                color = "4488FF",  -- Blue - defensive steel
                role = "TANK",
                description = "Stalwart defender using shield and heavy armor to protect allies from harm.",
                weights = {
                    Stamina = 1.0, Armor = 0.5, DefenseRating = 0.8, DodgeRating = 0.7,
                    ParryRating = 0.7, BlockRating = 0.6, BlockValue = 0.5,
                    Strength = 0.4, HitRating = 0.5, ExpertiseRating = 0.6,
                    Agility = 0.3, AttackPower = 0.3, CritRating = 0.4, HasteRating = 0.3,
                    ArmorPenetration = 0.35, Health = 0.3, Hp5 = 0.1, Spirit = 0.01,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, OneHandDps = 0.5, MainHandDps = 0.5
                },
                unusable = {
                    -- Weapons
                    IsWand = true, IsStaff = true,
                    IsPolearm = true, Is2HAxe = true, Is2HMace = true, Is2HSword = true,
                    -- Offhands
                    IsFrill = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (uses shield in offhand)
                    OffHandDPS = true, TwoHandDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Caster Stats (non-caster class)
                    Intellect = true, Mana = true, Mp5 = true, SpellPower = true,
                    SpellPenetration = true, HolySpellPower = true, FireSpellPower = true,
                    FrostSpellPower = true, ShadowSpellPower = true, NatureSpellPower = true,
                    ArcaneSpellPower = true
                }
            }
        }
    },
    {
        class = "Paladin",
        color = "F58CBA",
        description = "Holy champions wielding the Light to protect the innocent and smite the wicked with righteous fury.",
        specs = {
            {
                name = "Holy",
                icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
                color = "FFD700",  -- Gold - holy light
                role = "HEALER",
                description = "Channel divine light to heal wounds and protect allies with holy shields.",
                weights = {
                    Intellect = 1.0, SpellPower = 0.9, CritRating = 0.7, HasteRating = 0.6,
                    Mp5 = 0.8, Spirit = 0.5, Stamina = 0.3, Armor = 0.05,
                    Strength = 0.005, Agility = 0.005, Mana = 0.15, Health = 0.01, Hp5 = 0.03,
                    AttackPower = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, BlockRating = 0.005, BlockValue = 0.4, SpellPenetration = 0.4,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, HolySpellPower = 0.8, OneHandDps = 0.1, IsLibram = 0.3
                },
                unusable = {
                    -- Weapons (class cannot use)
                    IsDagger = true, IsFist = true, IsStaff = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Weapons (spec uses 1H + shield, not 2H)
                    Is2HAxe = true, Is2HMace = true, Is2HSword = true, IsPolearm = true,
                    -- Offhands
                    IsFrill = true,
                    -- Relics
                    IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (uses shield, bans all 2H, can't use ranged)
                    OffHandDPS = true, TwoHandDPS = true, RangedDPS = true, RangedAP = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Off-school Spell Power
                    FireSpellPower = true, FrostSpellPower = true, ShadowSpellPower = true,
                    NatureSpellPower = true, ArcaneSpellPower = true
                }
            },
            {
                name = "Protection",
                icon = "Interface\\Icons\\Ability_Paladin_ShieldoftheTemplar",
                color = "AAAAAA",  -- Silver - protective shield
                role = "TANK",
                description = "Righteous guardian combining holy magic with shield mastery to defend the weak.",
                weights = {
                    Stamina = 1.0, Armor = 0.5, DefenseRating = 0.8, DodgeRating = 0.7,
                    ParryRating = 0.7, BlockRating = 0.6, BlockValue = 0.5,
                    Strength = 0.4, HitRating = 0.5, ExpertiseRating = 0.6, SpellPower = 0.3,
                    Agility = 0.3, Intellect = 0.25, AttackPower = 0.3, CritRating = 0.4,
                    HasteRating = 0.3, ArmorPenetration = 0.35,
                    Health = 0.3, Hp5 = 0.1, Mana = 0.07, Mp5 = 0.05, Spirit = 0.01,
                    SpellPenetration = 0.3, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01, HolySpellPower = 0.4,
                    OneHandDps = 0.4, MainHandDps = 0.4, IsLibram = 0.3
                },
                unusable = {
                    -- Weapons
                    IsDagger = true, IsFist = true, IsStaff = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    IsPolearm = true, Is2HAxe = true, Is2HMace = true, Is2HSword = true,
                    -- Offhands
                    IsFrill = true,
                    -- Relics
                    IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (uses shield, bans all 2H, can't use ranged)
                    OffHandDPS = true, TwoHandDPS = true, RangedDPS = true, RangedAP = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Off-school Spell Power
                    FireSpellPower = true, FrostSpellPower = true, ShadowSpellPower = true,
                    NatureSpellPower = true, ArcaneSpellPower = true
                }
            },
            {
                name = "Retribution",
                icon = "Interface\\Icons\\Spell_Holy_AuraOfLight",
                color = "CC0000",  -- Crimson - righteous vengeance
                role = "SUPPORT",
                description = "Holy warrior bringing righteous vengeance with two-handed strikes and sacred buffs.",
                weights = {
                    Strength = 1.0, AttackPower = 0.5, CritRating = 0.8, HitRating = 1.0,
                    HasteRating = 0.6, ExpertiseRating = 0.9, ArmorPenetration = 0.7,
                    Agility = 0.3, SpellPower = 0.3, Intellect = 0.3, Stamina = 0.2,
                    Armor = 0.05, Spirit = 0.005, Mp5 = 0.02, Hp5 = 0.01, Mana = 0.02,
                    Health = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, SpellPenetration = 0.2, FireResist = 0.01,
                    FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, HolySpellPower = 0.3,
                    TwoHandDps = 0.75, IsLibram = 0.3
                },
                unusable = {
                    -- Weapons (class cannot use)
                    IsDagger = true, IsFist = true, IsStaff = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Weapons (spec uses 2H only, not 1H)
                    IsAxe = true, IsMace = true, IsSword = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Relics
                    IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (2H only spec, can't use ranged)
                    OffHandDPS = true, MainHandDPS = true, OneHandDPS = true, RangedDPS = true,
                    RangedAP = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true,
                    -- Off-school Spell Power
                    FireSpellPower = true, FrostSpellPower = true, ShadowSpellPower = true,
                    NatureSpellPower = true, ArcaneSpellPower = true
                }
            }
        }
    },
    {
        class = "Hunter",
        color = "ABD473",
        description = "Survivalists of the wild, tracking prey with precision and fighting alongside loyal beasts.",
        specs = {
            {
                name = "Beast Mastery",
                icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
                color = "44CC44",  -- Green - beast nature
                role = "DAMAGER",
                description = "Bond with your pet to unleash primal fury and coordinated attacks together.",
                weights = {
                    Agility = 1.0, AttackPower = 0.6, RangedAP = 0.6, CritRating = 0.8,
                    HitRating = 1.0, HasteRating = 0.5, ArmorPenetration = 0.7,
                    Intellect = 0.2, Stamina = 0.2, Armor = 0.05, Strength = 0.005,
                    Spirit = 0.005, Mp5 = 0.02, Hp5 = 0.01, Mana = 0.02, Health = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, SpellPower = 0.005, RangedDps = 0.65
                },
                unusable = {
                    -- Weapons
                    IsMace = true, IsWand = true, IsStaff = true, IsThrown = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true,
                    -- Spell School Power
                    ShadowSpellPower = true, HolySpellPower = true
                }
            },
            {
                name = "Marksmanship",
                icon = "Interface\\Icons\\Ability_Marksmanship",
                color = "4488DD",  -- Blue - precision aim
                role = "DAMAGER",
                description = "Sniper specializing in precise, powerful ranged attacks from a safe distance.",
                weights = {
                    Agility = 1.0, AttackPower = 0.6, RangedAP = 0.6, CritRating = 0.9,
                    HitRating = 1.0, HasteRating = 0.6, ArmorPenetration = 0.8,
                    Intellect = 0.2, Stamina = 0.2, Armor = 0.05, Strength = 0.005,
                    Spirit = 0.005, Mp5 = 0.02, Hp5 = 0.01, Mana = 0.02, Health = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, SpellPower = 0.005, RangedDps = 0.7
                },
                unusable = {
                    -- Weapons
                    IsMace = true, IsWand = true, IsStaff = true, IsThrown = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true,
                    -- Spell School Power
                    ShadowSpellPower = true, HolySpellPower = true
                }
            },
            {
                name = "Survival",
                icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike",
                color = "AA6633",  -- Brown - wilderness survival
                role = "DAMAGER",
                description = "Wilderness expert using traps, poisons, and tactical strikes to bring down prey.",
                weights = {
                    Agility = 1.0, AttackPower = 0.6, RangedAP = 0.6, CritRating = 0.8,
                    HitRating = 1.0, HasteRating = 0.7, ArmorPenetration = 0.9,
                    Intellect = 0.2, Stamina = 0.2, Armor = 0.05, Strength = 0.005,
                    Spirit = 0.005, Mp5 = 0.02, Hp5 = 0.01, Mana = 0.02, Health = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, SpellPower = 0.005, RangedDps = 0.7
                },
                unusable = {
                    -- Weapons
                    IsMace = true, IsWand = true, IsStaff = true, IsThrown = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true,
                    -- Spell School Power
                    ShadowSpellPower = true, HolySpellPower = true
                }
            }
        }
    },
    {
        class = "Rogue",
        color = "FFF569",
        description = "Shadowy assassins striking from the darkness with deadly precision and cunning guile.",
        specs = {
            {
                name = "Assassination",
                icon = "Interface\\Icons\\Ability_Rogue_Eviscerate",
                color = "00DD00",  -- Bright green - poison/venom
                role = "DAMAGER",
                description = "Silent killer using deadly poisons and precise strikes from the shadows.",
                weights = {
                    Agility = 1.0, AttackPower = 0.5, CritRating = 0.8, HitRating = 1.0,
                    HasteRating = 0.7, ExpertiseRating = 0.9, ArmorPenetration = 0.8,
                    Strength = 0.2, Stamina = 0.2, Armor = 0.05, Intellect = 0.005,
                    Spirit = 0.005, Mp5 = 0.005, Hp5 = 0.01, Health = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, SpellPower = 0.005,
                    MainHandDps = 0.7, OffHandDps = 0.5, OneHandDps = 0.6
                },
                unusable = {
                    -- Weapons
                    IsStaff = true, IsPolearm = true, Is2HAxe = true, Is2HMace = true, Is2HSword = true, IsWand = true, IsFist = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (all 2H weapons banned)
                    TwoHandDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Combat",
                icon = "Interface\\Icons\\Ability_BackStab",
                color = "DD0000",  -- Red - bloodthirsty combat
                role = "DAMAGER",
                description = "Swashbuckler delivering lightning-fast blade strikes in close combat.",
                weights = {
                    Agility = 1.0, AttackPower = 0.5, CritRating = 0.7, HitRating = 1.0,
                    HasteRating = 0.8, ExpertiseRating = 0.9, ArmorPenetration = 0.7,
                    Strength = 0.2, Stamina = 0.2, Armor = 0.05, Intellect = 0.005,
                    Spirit = 0.005, Mp5 = 0.005, Hp5 = 0.01, Health = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, SpellPower = 0.005,
                    MainHandDps = 0.7, OffHandDps = 0.5, OneHandDps = 0.6
                },
                unusable = {
                    -- Weapons
                    IsStaff = true, IsPolearm = true, Is2HAxe = true, Is2HMace = true, Is2HSword = true, IsWand = true, IsFist = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (all 2H weapons banned)
                    TwoHandDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Subtlety",
                icon = "Interface\\Icons\\Ability_Stealth",
                color = "6600AA",  -- Purple - shadowy stealth
                role = "DAMAGER",
                description = "Master of shadows, striking from stealth with calculated precision and trickery.",
                weights = {
                    Agility = 1.0, AttackPower = 0.5, CritRating = 0.9, HitRating = 1.0,
                    HasteRating = 0.6, ExpertiseRating = 0.9, ArmorPenetration = 0.8,
                    Strength = 0.2, Stamina = 0.2, Armor = 0.05, Intellect = 0.005,
                    Spirit = 0.005, Mp5 = 0.005, Hp5 = 0.01, Health = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, SpellPower = 0.005,
                    MainHandDps = 0.7, OffHandDps = 0.5, OneHandDps = 0.6
                },
                unusable = {
                    -- Weapons
                    IsStaff = true, IsPolearm = true, Is2HAxe = true, Is2HMace = true, Is2HSword = true, IsWand = true, IsFist = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (all 2H weapons banned)
                    TwoHandDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            }
        }
    },
    {
        class = "Priest",
        color = "FFFFFF",
        description = "Devoted servants of faith, channeling divine power to heal allies or embrace shadow to destroy enemies.",
        specs = {
            {
                name = "Discipline",
                icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
                color = "DDDDDD",  -- Light gray - discipline/balance
                role = "HEALER",
                description = "Balance light and shadow, preventing damage with shields and healing wounds.",
                weights = {
                    Intellect = 1.0, SpellPower = 0.9, CritRating = 0.7, HasteRating = 0.8,
                    Mp5 = 0.7, Spirit = 0.6, Stamina = 0.3, Armor = 0.05,
                    Strength = 0.005, Agility = 0.005, Mana = 0.15, Health = 0.01, Hp5 = 0.03,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.4, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    ShadowSpellPower = 0.02, HolySpellPower = 0.8, Dps = 0.08
                },
                unusable = {
                    -- Weapons
                    Is2HMace = true, IsSword = true, Is2HSword = true, IsAxe = true, Is2HAxe = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Holy",
                icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit",
                color = "FFEE66",  -- Bright yellow - holy radiance
                role = "HEALER",
                description = "Devoted healer wielding divine power to restore health and grant salvation.",
                weights = {
                    Intellect = 1.0, SpellPower = 0.9, CritRating = 0.6, HasteRating = 0.7,
                    Mp5 = 0.8, Spirit = 0.7, Stamina = 0.3, Armor = 0.05,
                    Strength = 0.005, Agility = 0.005, Mana = 0.15, Health = 0.01, Hp5 = 0.03,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.4, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    ShadowSpellPower = 0.02, HolySpellPower = 0.9, Dps = 0.08
                },
                unusable = {
                    -- Weapons
                    Is2HMace = true, IsSword = true, Is2HSword = true, IsAxe = true, Is2HAxe = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Shadow",
                icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
                color = "8800CC",  -- Purple - shadow magic
                role = "DAMAGER",
                description = "Embrace the darkness to drain life and inflict torment with shadow magic.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.8,
                    HasteRating = 0.9, Spirit = 0.5, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01,
                    ShadowResist = 0.01, NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    ShadowSpellPower = 1.0, HolySpellPower = 0.02, Dps = 0.1
                },
                unusable = {
                    -- Weapons
                    Is2HMace = true, IsSword = true, Is2HSword = true, IsAxe = true, Is2HAxe = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            }
        }
    },
    {
        class = "Shaman",
        color = "0070DE",
        description = "Spiritual guides communing with the elements to call upon nature's raw power and ancestral wisdom.",
        specs = {
            {
                name = "Elemental",
                icon = "Interface\\Icons\\Spell_Nature_Lightning",
                color = "3399FF",  -- Bright blue - lightning storm
                role = "DAMAGER",
                description = "Harness lightning, fire, and earth to devastate foes with elemental fury.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.8,
                    HasteRating = 0.9, Mp5 = 0.5, Spirit = 0.4, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    NatureSpellPower = 1.0, FireSpellPower = 0.03, Dps = 0.1, IsTotem = 0.3
                },
                unusable = {
                    -- Weapons
                    IsSword = true, Is2HSword = true, IsPolearm = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    Is2HAxe = true, Is2HMace = true,
                    -- Offhands
                    IsFrill = true,
                    -- Armor
                    IsPlate = true,
                    -- Relics
                    IsLibram = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (can't use ranged)
                    RangedDPS = true,
                    -- Feral Stats
                    FeralAP = true
                }
            },
            {
                name = "Enhancement",
                icon = "Interface\\Icons\\Spell_Nature_LightningShield",
                color = "FF6622",  -- Orange - fiery enhancement
                role = "DAMAGER",
                description = "Infuse weapons with elemental power for devastating melee strikes.",
                weights = {
                    Agility = 1.0, AttackPower = 0.6, CritRating = 0.8, HitRating = 1.0,
                    HasteRating = 0.7, ExpertiseRating = 0.9, ArmorPenetration = 0.7,
                    Intellect = 0.4, Strength = 0.5, Stamina = 0.2, Armor = 0.05,
                    Spirit = 0.005, Mp5 = 0.02, Hp5 = 0.01, Mana = 0.02, Health = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    SpellPenetration = 0.2, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    NatureSpellPower = 0.3, FireSpellPower = 0.3,
                    MainHandDps = 0.7, OffHandDps = 0.5, OneHandDps = 0.6, IsTotem = 0.3
                },
                unusable = {
                    -- Weapons
                    IsSword = true, Is2HSword = true, IsPolearm = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true, IsStaff = true,
                    -- Offhands
                    IsFrill = true,
                    -- Armor
                    IsPlate = true,
                    -- Relics
                    IsLibram = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (can't use ranged)
                    RangedDPS = true,
                    -- Feral Stats
                    FeralAP = true
                }
            },
            {
                name = "Restoration",
                icon = "Interface\\Icons\\Spell_Nature_MagicImmunity",
                color = "22DD77",  -- Teal green - healing waters
                role = "HEALER",
                description = "Channel healing waters and ancestral spirits to restore and cleanse allies.",
                weights = {
                    Intellect = 1.0, SpellPower = 0.9, CritRating = 0.6, HasteRating = 0.7,
                    Mp5 = 0.8, Spirit = 0.5, Stamina = 0.3, Armor = 0.05,
                    Strength = 0.005, Agility = 0.005, Mana = 0.15, Health = 0.01, Hp5 = 0.03,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.4, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    NatureSpellPower = 0.8, FireSpellPower = 0.3, Dps = 0.08, IsTotem = 0.3
                },
                unusable = {
                    -- Weapons
                    IsSword = true, Is2HSword = true, IsPolearm = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    Is2HAxe = true, Is2HMace = true,
                    -- Offhands
                    IsFrill = true,
                    -- Armor
                    IsPlate = true,
                    -- Relics
                    IsLibram = true, IsSigil = true, IsIdol = true,
                    -- DPS Stats (can't use ranged)
                    RangedDPS = true,
                    -- Feral Stats
                    FeralAP = true
                }
            }
        }
    },
    {
        class = "Mage",
        color = "69CCF0",
        description = "Scholars of arcane magic, wielding raw mystical energy to reshape reality and devastate foes.",
        specs = {
            {
                name = "Arcane",
                icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
                color = "AA44FF",  -- Purple - arcane magic
                role = "DAMAGER",
                description = "Manipulate raw arcane energy for devastating magical bombardments.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.7,
                    HasteRating = 0.9, Spirit = 0.4, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    ArcaneSpellPower = 1.0, FireSpellPower = 0.02, FrostSpellPower = 0.02, Dps = 0.1
                },
                unusable = {
                    -- Weapons
                    Is2HSword = true, IsAxe = true, Is2HAxe = true, IsMace = true, Is2HMace = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Fire",
                icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
                color = "FF4400",  -- Red-orange - burning flames
                role = "DAMAGER",
                description = "Pyromancer igniting enemies with explosive fire spells and burning damage.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.9,
                    HasteRating = 0.8, Spirit = 0.3, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    FireSpellPower = 1.0, ArcaneSpellPower = 0.02, FrostSpellPower = 0.02, Dps = 0.1
                },
                unusable = {
                    -- Weapons
                    Is2HSword = true, IsAxe = true, Is2HAxe = true, IsMace = true, Is2HMace = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Frost",
                icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
                color = "00DDFF",  -- Cyan - ice cold
                role = "DAMAGER",
                description = "Freeze and shatter foes with ice spells, slowing and controlling the battlefield.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.8,
                    HasteRating = 0.9, Spirit = 0.3, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    FrostSpellPower = 1.0, FireSpellPower = 0.02, ArcaneSpellPower = 0.02, Dps = 0.1
                },
                unusable = {
                    -- Weapons
                    Is2HSword = true, IsAxe = true, Is2HAxe = true, IsMace = true, Is2HMace = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            }
        }
    },
    {
        class = "Warlock",
        color = "9482C9",
        description = "Dark practitioners of fel magic, commanding demons and wielding destructive forces from the Twisting Nether.",
        specs = {
            {
                name = "Affliction",
                icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",
                color = "00BB44",  -- Green - disease/decay
                role = "DAMAGER",
                description = "Spread disease and corruption, watching enemies wither from curses over time.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.7,
                    HasteRating = 0.9, Spirit = 0.5, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    FireSpellPower = 0.5, ShadowSpellPower = 1.0, Dps = 0.1
                },
                unusable = {
                    -- Weapons
                    Is2HSword = true, IsAxe = true, Is2HAxe = true, IsMace = true, Is2HMace = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Demonology",
                icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
                color = "AA22AA",  -- Purple - demonic power
                role = "DAMAGER",
                description = "Command powerful demons and transform with demonic energy for destruction.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.8,
                    HasteRating = 0.8, Spirit = 0.4, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    FireSpellPower = 0.5, ShadowSpellPower = 1.0, Dps = 0.1
                },
                unusable = {
                    -- Weapons
                    Is2HSword = true, IsAxe = true, Is2HAxe = true, IsMace = true, Is2HMace = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Destruction",
                icon = "Interface\\Icons\\Spell_Shadow_RainOfFire",
                color = "EE3300",  -- Red - destructive fire
                role = "DAMAGER",
                description = "Rain hellfire and chaos upon enemies with destructive fel magic.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.9,
                    HasteRating = 0.8, Spirit = 0.3, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    FireSpellPower = 1.0, ShadowSpellPower = 0.5, Dps = 0.1
                },
                unusable = {
                    -- Weapons
                    Is2HSword = true, IsAxe = true, Is2HAxe = true, IsMace = true, Is2HMace = true,
                    IsPolearm = true, IsFist = true, IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsShield = true,
                    -- Armor
                    IsLeather = true, IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true, IsIdol = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            }
        }
    },
    {
        class = "Druid",
        color = "FF7D0A",
        description = "Guardians of nature, shapeshifting between forms to protect the wilds and maintain the balance of life.",
        specs = {
            {
                name = "Balance",
                icon = "Interface\\Icons\\Spell_Nature_StarFall",
                color = "4488FF",  -- Blue - celestial balance
                role = "DAMAGER",
                description = "Balance lunar and solar energies to call down cosmic wrath from the heavens.",
                weights = {
                    Intellect = 1.0, SpellPower = 1.0, HitRating = 1.0, CritRating = 0.8,
                    HasteRating = 0.9, Spirit = 0.6, Stamina = 0.25, Armor = 0.03,
                    Strength = 0.005, Agility = 0.005, Mana = 0.12, Health = 0.005, Hp5 = 0.005,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, SpellPenetration = 0.5, FireResist = 0.01, FrostResist = 0.01,
                    ShadowResist = 0.01, NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    ArcaneSpellPower = 1.0, NatureSpellPower = 0.8, Dps = 0.1, IsIdol = 0.3
                },
                unusable = {
                    -- Weapons
                    IsSword = true, Is2HSword = true, IsAxe = true, Is2HAxe = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true,
                    -- DPS Stats (can't use ranged)
                    RangedDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Feral DPS",
                icon = "Interface\\Icons\\Ability_Druid_CatForm",
                color = "FFAA00",  -- Orange - cat ferocity
                role = "DAMAGER",
                description = "Transform into a savage cat, ripping and tearing foes with primal fury.",
                weights = {
                    Agility = 1.0, Strength = 0.5, FeralAP = 0.8, AttackPower = 0.5,
                    CritRating = 0.8, HitRating = 1.0, HasteRating = 0.7,
                    ExpertiseRating = 0.9, ArmorPenetration = 0.8, Stamina = 0.2, Armor = 0.05,
                    Spirit = 0.005, Mp5 = 0.02, Hp5 = 0.01, Mana = 0.02, Health = 0.005,
                    Intellect = 0.03, DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, SpellPower = 0.005,
                    TwoHandDps = 0.75, IsIdol = 0.3
                },
                unusable = {
                    -- Weapons
                    IsSword = true, Is2HSword = true, IsAxe = true, Is2HAxe = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true,
                    -- DPS Stats (can't use ranged)
                    RangedDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Feral Tank",
                icon = "Interface\\Icons\\Ability_Racial_BearForm",
                color = "996633",  -- Brown - bear strength
                role = "TANK",
                description = "Become a mighty bear with thick hide and crushing strength to protect allies.",
                weights = {
                    Stamina = 1.0, Agility = 0.8, Armor = 0.7, DodgeRating = 0.8,
                    FeralAP = 0.5, Strength = 0.4, HitRating = 0.5,
                    ExpertiseRating = 0.6, DefenseRating = 0.3,
                    Health = 0.35, Hp5 = 0.1, Mp5 = 0.05, Mana = 0.06, Spirit = 0.01, Intellect = 0.05,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01, NatureResist = 0.01,
                    ArcaneResist = 0.01, AllResist = 0.01, TwoHandDps = 0.45, IsIdol = 0.3
                },
                unusable = {
                    -- Weapons
                    IsSword = true, Is2HSword = true, IsAxe = true, Is2HAxe = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true,
                    -- DPS Stats (can't use ranged)
                    RangedDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            },
            {
                name = "Restoration",
                icon = "Interface\\Icons\\Spell_Nature_HealingTouch",
                color = "11DD55",  -- Green - nature's healing
                role = "HEALER",
                description = "Nurture allies with nature's gift, healing wounds with rejuvenation over time.",
                weights = {
                    Intellect = 1.0, SpellPower = 0.9, CritRating = 0.6, HasteRating = 0.8,
                    Mp5 = 0.7, Spirit = 0.7, Stamina = 0.3, Armor = 0.05,
                    Strength = 0.005, Agility = 0.005, Mana = 0.15, Health = 0.01, Hp5 = 0.03,
                    AttackPower = 0.005, RangedAP = 0.005, DefenseRating = 0.005, DodgeRating = 0.005,
                    ParryRating = 0.005, ExpertiseRating = 0.005, ArmorPenetration = 0.005,
                    SpellPenetration = 0.4, FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01,
                    NatureSpellPower = 0.9, Dps = 0.08, IsIdol = 0.3
                },
                unusable = {
                    -- Weapons
                    IsSword = true, Is2HSword = true, IsAxe = true, Is2HAxe = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands
                    IsFrill = true, IsShield = true,
                    -- Armor
                    IsMail = true, IsPlate = true,
                    -- Relics
                    IsLibram = true, IsTotem = true, IsSigil = true,
                    -- DPS Stats (can't use ranged)
                    RangedDPS = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            }
        }
    }
}

-- ========================================
-- Role Icon Configuration
-- ========================================

-- Role Icon Configuration
local ROLE_ICON_TEXTURE = "Interface\\LFGFRAME\\UI-LFG-ICON-ROLES"
local ROLE_ICON_COORDS = {
    DAMAGER = {72/256, 130/256, 69/256, 127/256},
    HEALER = {72/256, 130/256, 2/256, 60/256},
    TANK = {5/256, 63/256, 69/256, 127/256},
    SUPPORT = {72/256, 130/256, 69/256, 127/256}, -- Same as DAMAGER
}

-- Helper function to get role icon texture and coordinates
local function GetRoleIconAndCoords(role)
    if not role then
        role = "DAMAGER"
    end
    local coords = ROLE_ICON_COORDS[role] or ROLE_ICON_COORDS["DAMAGER"]
    return ROLE_ICON_TEXTURE, coords[1], coords[2], coords[3], coords[4]
end

-- Helper function to get role display name
local function GetRoleName(role)
    local roleNames = {
        TANK = "Tank",
        HEALER = "Healer",
        DAMAGER = "Damage",
        SUPPORT = "Support"
    }
    return roleNames[role] or "Damage"
end

-- ========================================
-- Utility Functions
-- ========================================

local function HexToRGB(hex)
    if not hex or #hex ~= 6 then
        return 1, 1, 1
    end
    local r = tonumber(string.sub(hex, 1, 2), 16) / 255
    local g = tonumber(string.sub(hex, 3, 4), 16) / 255
    local b = tonumber(string.sub(hex, 5, 6), 16) / 255
    return r, g, b
end

local function RGBToHex(r, g, b)
    r = math.floor(math.max(0, math.min(1, r)) * 255)
    g = math.floor(math.max(0, math.min(1, g)) * 255)
    b = math.floor(math.max(0, math.min(1, b)) * 255)
    return string.format("%02X%02X%02X", r, g, b)
end

-- Creates a styled button with consistent look
local function CreateStyledButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width or 100)
    btn:SetHeight(height or BUTTON_HEIGHT)
    btn:SetBackdrop(BACKDROP_BUTTON)
    btn:SetBackdropColor(unpack(COLORS.buttonBg))
    btn:SetBackdropBorderColor(unpack(COLORS.border))
    
    local label = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText(text or "")
    label:SetTextColor(unpack(COLORS.textBody))
    btn.label = label
    
    -- Hover and click effects
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
        self:SetBackdropBorderColor(unpack(COLORS.borderLight))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonBg))
        self:SetBackdropBorderColor(unpack(COLORS.border))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonPressed))
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
    end)
    
    return btn
end

-- ========================================
-- Icon Picker Frame
-- ========================================

local function CreateIconPickerFrame()
    local frame = CreateFrame("Frame", "ValuateIconPickerFrame", UIParent)
    frame:SetSize(306, 440)  -- Increased height for more icons visible
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    frame:Hide()
    
    -- Make draggable
    frame:SetScript("OnDragStart", function(self)
        IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IsDraggingFrame = false
    end)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    title:SetText("Select Icon")
    title:SetTextColor(unpack(COLORS.textTitle))
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeBtn:SetBackdrop(BACKDROP_BUTTON)
    closeBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    closeBtn:SetBackdropBorderColor(unpack(COLORS.border))
    
    local closeLabel = closeBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    closeLabel:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeLabel:SetText("×")
    closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.2, 0.2, 1)
        closeLabel:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Create scrollable content area
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 16)
    scrollFrame:EnableMouseWheel(true)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    
    -- Scrollbar
    local scrollbar = CreateFrame("Slider", nil, scrollFrame, "UIPanelScrollBarTemplate")
    scrollbar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
    scrollbar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
    scrollbar:SetMinMaxValues(0, 1)
    scrollbar:SetValueStep(1)
    scrollbar:SetValue(0)
    scrollbar:SetWidth(16)
    
    -- Icon grid (8 columns, scrollable rows with virtual scrolling)
    local ICONS_PER_ROW = 8
    local ICON_SIZE = 28
    local ICON_SPACING = 4
    local ROW_HEIGHT = ICON_SIZE + ICON_SPACING
    
    local totalIcons = #SCALE_ICON_LIST
    local totalRows = math.ceil(totalIcons / ICONS_PER_ROW)
    local contentHeight = totalRows * ROW_HEIGHT + ICON_SPACING
    scrollChild:SetHeight(contentHeight)
    
    -- Virtual scrolling: only create buttons for visible + buffer rows
    local visibleRows = math.ceil(scrollFrame:GetHeight() / ROW_HEIGHT) + 2  -- +2 for buffer
    local maxButtons = visibleRows * ICONS_PER_ROW
    local buttonPool = {}
    
    -- Create a pool of reusable buttons
    for i = 1, maxButtons do
        local iconBtn = CreateFrame("Button", nil, scrollChild)
        iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
        iconBtn:Hide()
        
        -- Border/background for icon
        iconBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        iconBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
        iconBtn:SetBackdropBorderColor(unpack(COLORS.borderDark))
        
        local tex = iconBtn:CreateTexture(nil, "OVERLAY")
        tex:SetPoint("TOPLEFT", iconBtn, "TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", iconBtn, "BOTTOMRIGHT", -2, 2)
        iconBtn.tex = tex
        
        iconBtn:SetScript("OnClick", function(self)
            if IconPickerCallback and self.iconPath then
                IconPickerCallback(self.iconPath)
            end
            frame:Hide()
        end)
        
        iconBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            -- Show tooltip for "None" option
            if self.iconPath == "" and ShowTooltipSafe(self, "ANCHOR_RIGHT") then
                GameTooltip:AddLine("No Icon", 1, 1, 1)
                GameTooltip:AddLine("Clear the icon for this scale.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end
        end)
        iconBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(COLORS.borderDark))
            self:SetBackdropColor(0.1, 0.1, 0.1, 1)
            GameTooltip:Hide()
        end)
        
        buttonPool[i] = iconBtn
    end
    
    -- Function to update visible buttons based on scroll position
    local function UpdateVisibleIcons()
        local scrollOffset = scrollFrame:GetVerticalScroll()
        local firstVisibleRow = math.floor(scrollOffset / ROW_HEIGHT)
        local lastVisibleRow = math.min(totalRows - 1, firstVisibleRow + visibleRows)
        
        local buttonIndex = 1
        for row = firstVisibleRow, lastVisibleRow do
            for col = 0, ICONS_PER_ROW - 1 do
                local iconIndex = row * ICONS_PER_ROW + col + 1
                if iconIndex <= totalIcons then
                    local iconBtn = buttonPool[buttonIndex]
                    if iconBtn then
                        local iconPath = SCALE_ICON_LIST[iconIndex]
                        iconBtn.iconPath = iconPath
                        
                        -- Update texture
                        if iconPath == "" then
                            iconBtn.tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                        else
                            iconBtn.tex:SetTexture(iconPath)
                        end
                        
                        -- Update position
                        iconBtn:ClearAllPoints()
                        iconBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT",
                            col * (ICON_SIZE + ICON_SPACING),
                            -row * ROW_HEIGHT)
                        iconBtn:Show()
                        
                        buttonIndex = buttonIndex + 1
                    end
                end
            end
        end
        
        -- Hide unused buttons
        for i = buttonIndex, maxButtons do
            buttonPool[i]:Hide()
        end
    end
    
    -- Update scrollbar with new callback
    scrollbar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetVerticalScroll(value)
        UpdateVisibleIcons()
    end)
    
    -- Update mouse wheel to scroll by rows
    local function OnMouseWheel(self, delta)
        local current = scrollbar:GetValue()
        local minVal, maxVal = scrollbar:GetMinMaxValues()
        if delta < 0 and current < maxVal then
            scrollbar:SetValue(math.min(maxVal, current + ROW_HEIGHT * 2))
        elseif delta > 0 and current > minVal then
            scrollbar:SetValue(math.max(minVal, current - ROW_HEIGHT * 2))
        end
    end
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)
    scrollChild:SetScript("OnMouseWheel", OnMouseWheel)
    
    -- Update scrollbar range and show icons
    scrollFrame:SetScript("OnShow", function()
        local maxScroll = math.max(0, contentHeight - scrollFrame:GetHeight())
        scrollbar:SetMinMaxValues(0, maxScroll)
        scrollbar:SetValue(0)
        if maxScroll == 0 then
            scrollbar:Hide()
        else
            scrollbar:Show()
        end
        UpdateVisibleIcons()
    end)
    
    frame.UpdateVisibleIcons = UpdateVisibleIcons
    
    -- Hide when clicking outside or pressing Escape
    frame:SetScript("OnHide", function()
        IconPickerCallback = nil
    end)
    
    return frame
end

local function ShowIconPicker(callback)
    if not IconPickerFrame then
        IconPickerFrame = CreateIconPickerFrame()
    end
    IconPickerCallback = callback
    IconPickerFrame:Show()
end

-- ========================================
-- Class-Specific Template Picker Frame
-- ========================================

local function CreateClassSpecificPickerFrame()
    local frame = CreateFrame("Frame", "ValuateClassSpecificPickerFrame", UIParent)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    frame:Hide()
    
    -- Make draggable
    frame:SetScript("OnDragStart", function(self)
        IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IsDraggingFrame = false
    end)
    
    -- ESC key to close
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    
    -- Get player's class
    local _, playerClass = UnitClass("player")
    
    -- Find the class data
    local classData = nil
    for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
        if data.class:upper() == playerClass then
            classData = data
            break
        end
    end
    
    if not classData then
        -- Fallback to showing all classes if player class not found
        classData = CLASS_SPEC_TEMPLATES[1]
    end
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("Select Your Spec")
    title:SetTextColor(unpack(COLORS.textTitle))
    
    -- "Show All Classes" button
    local showAllButton = CreateStyledButton(frame, "Show All Classes", 150, BUTTON_HEIGHT)
    showAllButton:SetPoint("TOP", title, "BOTTOM", 0, -8)
    showAllButton:SetScript("OnClick", function()
        frame:Hide()
        ValuateUI_ShowFullTemplatePicker()
    end)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    
    local closeX = closeButton:CreateFontString(nil, "OVERLAY", FONT_H1)
    closeX:SetPoint("CENTER")
    closeX:SetText("×")
    closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    closeButton:SetScript("OnEnter", function()
        closeX:SetTextColor(1, 1, 1, 1)
    end)
    closeButton:SetScript("OnLeave", function()
        closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    
    -- Content area
    local contentTop = -85  -- Below title and "Show All Classes" button
    
    -- Temporary font string for measuring text widths
    local measureString = frame:CreateFontString(nil, "OVERLAY", FONT_BODY)
    
    -- Calculate column width - need to check description width too
    local maxWidth = 300  -- Minimum width for larger layout
    measureString:SetFont(FONT_BODY, 10)  -- Use smaller font for description
    for _, spec in ipairs(classData.specs) do
        -- Check description width (allowing for icon space)
        if spec.description then
            measureString:SetText(spec.description)
            local descWidth = measureString:GetStringWidth()
            -- Add icon space (36) + gap (8) + description + padding (12)
            local totalWidth = 36 + 8 + descWidth + 12
            if totalWidth > maxWidth then
                maxWidth = totalWidth
            end
        end
    end
    maxWidth = math.min(math.ceil(maxWidth), 400)  -- Cap at 400px
    
    -- Create content frame
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, contentTop)
    contentFrame:SetWidth(maxWidth)
    
    -- Class header
    local classHeader = contentFrame:CreateFontString(nil, "OVERLAY", FONT_H2)
    classHeader:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    classHeader:SetText(classData.class)
    local r, g, b = HexToRGB(classData.color)
    classHeader:SetTextColor(r, g, b, 1)
    
    -- Class description blurb
    local classDesc = nil
    local descHeight = 0
    if classData.description then
        classDesc = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        classDesc:SetPoint("TOPLEFT", classHeader, "BOTTOMLEFT", 0, -4)
        classDesc:SetWidth(maxWidth)  -- Explicitly set width for wrapping
        classDesc:SetJustifyH("LEFT")
        classDesc:SetJustifyV("TOP")
        classDesc:SetWordWrap(true)
        classDesc:SetText(classData.description)
        classDesc:SetTextColor(0.8, 0.8, 0.8, 1)  -- Slightly lighter than spec descriptions
        
        -- Get actual description height after text is set
        -- Need to wait a frame for text to render, so estimate for now
        measureString:SetFont("GameFontNormalSmall", 10)
        measureString:SetWidth(maxWidth)
        measureString:SetWordWrap(true)
        measureString:SetText(classData.description)
        -- Try to get height, fallback to estimated height
        local measuredHeight = measureString:GetStringHeight()
        if measuredHeight and measuredHeight > 0 then
            descHeight = measuredHeight
        else
            -- Estimate: ~12px per line, assume 2-3 lines
            descHeight = 30
        end
    end
    
    local yOffset = -18  -- Header height + spacing
    if classDesc then
        yOffset = yOffset - descHeight - 6  -- Header + description + spacing
    end
    
    -- Function to create a large spec button with description
    local buttonHeight = 80  -- Taller buttons to accommodate 2+ lines of description
    local function CreateSpecButtonWithRole(parent, template, yOffset, buttonWidth)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(buttonWidth, buttonHeight)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        
        -- Larger Spec Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", btn, "LEFT", 8, 0)
        icon:SetPoint("TOP", btn, "TOP", 0, -8)  -- Align to top with padding
        icon:SetTexture(template.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        -- Role Icon (overlaid on bottom-right of spec icon)
        local roleIcon = btn:CreateTexture(nil, "OVERLAY")
        roleIcon:SetSize(18, 18)
        roleIcon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
        local roleTexture, l, r, t, b = GetRoleIconAndCoords(template.role)
        roleIcon:SetTexture(roleTexture)
        roleIcon:SetTexCoord(l, r, t, b)
        
        -- Name Label (larger font)
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_H2)
        nameLabel:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -4)
        nameLabel:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText(template.name)
        nameLabel:SetTextColor(unpack(COLORS.textTitle))
        
        -- Description Label (smaller, wrapped, with proper height for 2+ lines)
        local descLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
        descLabel:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        descLabel:SetPoint("BOTTOM", btn, "BOTTOM", 0, 8)  -- Give it bottom padding
        descLabel:SetJustifyH("LEFT")
        descLabel:SetJustifyV("TOP")
        descLabel:SetWordWrap(true)
        descLabel:SetText(template.description or "")
        descLabel:SetTextColor(0.7, 0.7, 0.7, 1)
        
        -- Hover effects
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            self:SetBackdropBorderColor(unpack(COLORS.borderLight))
            nameLabel:SetTextColor(1, 1, 1, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonBg))
            self:SetBackdropBorderColor(unpack(COLORS.border))
            nameLabel:SetTextColor(unpack(COLORS.textTitle))
        end)
        
        -- Click handler
        btn.template = template
        btn:SetScript("OnClick", function(self, button)
            local created = ValuateUI_CreateScaleFromTemplate(self.template)
            
            -- Close window on normal click, keep open on shift-click
            if created and not IsShiftKeyDown() then
                frame:Hide()
            end
        end)
        
        return btn
    end
    
    -- Create spec buttons
    for _, spec in ipairs(classData.specs) do
        CreateSpecButtonWithRole(contentFrame, spec, yOffset, maxWidth)
        yOffset = yOffset - (buttonHeight + 4)  -- Button height + spacing
    end
    
    local contentHeight = math.abs(yOffset) + INNER_SPACING
    contentFrame:SetHeight(contentHeight)
    
    -- Calculate and set window size
    local windowWidth = PADDING + maxWidth + PADDING
    local windowHeight = 85 + contentHeight + PADDING  -- Title + show all button + content + padding
    
    -- Cap window height to prevent it from being too tall
    windowHeight = math.min(windowHeight, 600)
    
    frame:SetSize(windowWidth, windowHeight)
    
    -- Clean up temporary measurement string
    measureString:Hide()
    
    return frame
end

-- ========================================
-- Template Picker Frame (Full - All Classes)
-- ========================================

local function CreateTemplatePickerFrame()
    local frame = CreateFrame("Frame", "ValuateTemplatePickerFrame", UIParent)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    frame:Hide()
    
    -- Make draggable
    frame:SetScript("OnDragStart", function(self)
        IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IsDraggingFrame = false
    end)
    
    -- ESC key to close
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("Select Class Spec Template")
    title:SetTextColor(unpack(COLORS.textTitle))
    
    -- Get player's class for the back button
    local _, playerClass = UnitClass("player")
    local playerClassName = nil
    for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
        if data.class:upper() == playerClass then
            playerClassName = data.class
            break
        end
    end
    
    -- "Back to My Class" button (only show if player class is found)
    local backButton = nil
    if playerClassName then
        backButton = CreateStyledButton(frame, "Back to " .. playerClassName, 150, BUTTON_HEIGHT)
        backButton:SetPoint("TOP", title, "BOTTOM", 0, -8)
        backButton:SetScript("OnClick", function()
            frame:Hide()
            ValuateUI_ShowTemplatePicker()
        end)
    end
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    
    local closeX = closeButton:CreateFontString(nil, "OVERLAY", FONT_H1)
    closeX:SetPoint("CENTER")
    closeX:SetText("×")
    closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    closeButton:SetScript("OnEnter", function()
        closeX:SetTextColor(1, 1, 1, 1)
    end)
    closeButton:SetScript("OnLeave", function()
        closeX:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    
    -- Content area (adjust for back button if present)
    local contentTop = -45
    if backButton then
        contentTop = -45 - BUTTON_HEIGHT - 8  -- Title + button + spacing
    end
    
    -- Temporary font string for measuring text widths
    local measureString = frame:CreateFontString(nil, "OVERLAY", FONT_BODY)
    
    -- Create 3 columns
    local column1 = CreateFrame("Frame", nil, frame)
    column1:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, contentTop)
    
    local column2 = CreateFrame("Frame", nil, frame)
    
    local column3 = CreateFrame("Frame", nil, frame)
    
    -- Function to create a spec button with dynamic width and role icon
    local function CreateSpecButton(parent, template, classColor, yOffset, columnWidth)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(columnWidth, BUTTON_HEIGHT)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        
        -- Spec Icon
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", btn, "LEFT", 4, 0)
        icon:SetTexture(template.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        -- Role Icon
        local roleIcon = btn:CreateTexture(nil, "ARTWORK")
        roleIcon:SetSize(14, 14)
        roleIcon:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        local roleTexture, l, r, t, b = GetRoleIconAndCoords(template.role)
        roleIcon:SetTexture(roleTexture)
        roleIcon:SetTexCoord(l, r, t, b)
        
        -- Name Label
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        nameLabel:SetPoint("LEFT", roleIcon, "RIGHT", 6, 0)
        nameLabel:SetText(template.name)
        nameLabel:SetTextColor(unpack(COLORS.textBody))
        
        -- Hover effects
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            self:SetBackdropBorderColor(unpack(COLORS.borderLight))
            
            -- Show tooltip with role
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(template.name, 1, 1, 1)
            GameTooltip:AddLine(GetRoleName(template.role), 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(COLORS.buttonBg))
            self:SetBackdropBorderColor(unpack(COLORS.border))
            GameTooltip:Hide()
        end)
        
        -- Click handler (will be set by the picker)
        btn.template = template
        
        return btn
    end
    
    -- Populate columns with class/spec data (3 columns, 3 classes each)
    local column1Classes = {"Warrior", "Paladin", "Hunter"}
    local column2Classes = {"Rogue", "Priest", "Shaman"}
    local column3Classes = {"Mage", "Warlock", "Druid"}
    
    -- First pass: calculate required widths for each column
    local function CalculateColumnWidth(classList)
        local maxWidth = 100  -- Minimum width
        
        for _, className in ipairs(classList) do
            -- Find the class data
            local classData = nil
            for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
                if data.class == className then
                    classData = data
                    break
                end
            end
            
            if classData then
                -- Check each spec name width
                for _, spec in ipairs(classData.specs) do
                    measureString:SetText(spec.name)
                    local textWidth = measureString:GetStringWidth()
                    -- Add icon (16) + gap (4) + roleIcon (14) + gap (6) + text + padding (8)
                    local buttonWidth = 16 + 4 + 14 + 6 + textWidth + 8
                    if buttonWidth > maxWidth then
                        maxWidth = buttonWidth
                    end
                end
            end
        end
        
        return math.ceil(maxWidth)
    end
    
    local width1 = CalculateColumnWidth(column1Classes)
    local width2 = CalculateColumnWidth(column2Classes)
    local width3 = CalculateColumnWidth(column3Classes)
    
    -- Set column widths
    column1:SetWidth(width1)
    column2:SetWidth(width2)
    column3:SetWidth(width3)
    
    -- Position columns
    column2:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + width1 + ELEMENT_SPACING, contentTop)
    column3:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING + width1 + ELEMENT_SPACING + width2 + ELEMENT_SPACING, contentTop)
    
    local function PopulateColumn(column, classList, columnWidth)
        local yOffset = 0
        
        for _, className in ipairs(classList) do
            -- Find the class data
            local classData = nil
            for _, data in ipairs(CLASS_SPEC_TEMPLATES) do
                if data.class == className then
                    classData = data
                    break
                end
            end
            
            if classData then
                -- Class header
                local header = column:CreateFontString(nil, "OVERLAY", FONT_H2)
                header:SetPoint("TOPLEFT", column, "TOPLEFT", 0, yOffset)
                header:SetText(classData.class)
                local r, g, b = HexToRGB(classData.color)
                header:SetTextColor(r, g, b, 1)
                
                yOffset = yOffset - 18  -- Header height + spacing
                
                -- Spec buttons
                for _, spec in ipairs(classData.specs) do
                    local btn = CreateSpecButton(column, spec, spec.color, yOffset, columnWidth)
                    yOffset = yOffset - (BUTTON_HEIGHT + 2)  -- Button height + spacing
                end
                
                -- Extra spacing after each class
                yOffset = yOffset - INNER_SPACING
            end
        end
        
        return -yOffset  -- Return total height used
    end
    
    local height1 = PopulateColumn(column1, column1Classes, width1)
    local height2 = PopulateColumn(column2, column2Classes, width2)
    local height3 = PopulateColumn(column3, column3Classes, width3)
    
    -- Set column heights
    local maxHeight = math.max(height1, height2, height3)
    column1:SetHeight(maxHeight)
    column2:SetHeight(maxHeight)
    column3:SetHeight(maxHeight)
    
    -- Calculate and set window size
    local windowWidth = PADDING + width1 + ELEMENT_SPACING + width2 + ELEMENT_SPACING + width3 + PADDING
    local titleAreaHeight = 45  -- Title area
    if backButton then
        titleAreaHeight = 45 + BUTTON_HEIGHT + 8  -- Title + button + spacing
    end
    local windowHeight = titleAreaHeight + maxHeight + PADDING  -- Title area + content + bottom padding
    
    frame:SetSize(windowWidth, windowHeight)
    
    -- Clean up temporary measurement string
    measureString:Hide()
    
    return frame
end

-- Show the full template picker (all classes)
function ValuateUI_ShowFullTemplatePicker()
    if not TemplatePickerFrame then
        TemplatePickerFrame = CreateTemplatePickerFrame()
        
        -- Set up click handlers for all spec buttons after frame is created
        local function SetupButtonHandlers(frame)
            local children = {frame:GetChildren()}
            for _, child in ipairs(children) do
                if child.template then
                    child:SetScript("OnClick", function(self, button)
                        local created = ValuateUI_CreateScaleFromTemplate(self.template)
                        
                        -- Close window on normal click, keep open on shift-click
                        if created and not IsShiftKeyDown() then
                            TemplatePickerFrame:Hide()
                        end
                    end)
                end
                
                -- Recursively check children
                SetupButtonHandlers(child)
            end
        end
        
        SetupButtonHandlers(TemplatePickerFrame)
    end
    
    TemplatePickerFrame:Show()
end

-- Show the template picker (class-specific first)
function ValuateUI_ShowTemplatePicker()
    if not ClassSpecificPickerFrame then
        ClassSpecificPickerFrame = CreateClassSpecificPickerFrame()
    end
    ClassSpecificPickerFrame:Show()
end

-- ========================================
-- Main Window Creation
-- ========================================

local function CreateMainWindow()
    if ValuateUIFrame then
        return ValuateUIFrame
    end
    
    -- Main frame
    local frame = CreateFrame("Frame", "ValuateUIFrame", UIParent)
    frame:SetWidth(WINDOW_WIDTH)
    frame:SetHeight(MIN_WINDOW_HEIGHT)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("DIALOG")  -- Above most UI elements
    
    -- Backdrop (standardized clean border)
    frame:SetBackdrop(BACKDROP_WINDOW)
    frame:SetBackdropColor(unpack(COLORS.windowBg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))
    
    -- Position (restored from saved settings)
    if ValuateOptions and ValuateOptions.uiPosition and ValuateOptions.uiPosition.point and ValuateOptions.uiPosition.x and ValuateOptions.uiPosition.y then
        frame:SetPoint(ValuateOptions.uiPosition.point, UIParent, ValuateOptions.uiPosition.relativePoint or ValuateOptions.uiPosition.point, ValuateOptions.uiPosition.x, ValuateOptions.uiPosition.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    -- Save position on move
    frame:SetScript("OnDragStart", function(self)
        IsDraggingFrame = true
        GameTooltip:Hide()  -- Hide any visible tooltips
        self:StartMoving()
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IsDraggingFrame = false
        if ValuateOptions then
            if not ValuateOptions.uiPosition then
                ValuateOptions.uiPosition = {}
            end
            local point, _, relativePoint, x, y = self:GetPoint()
            ValuateOptions.uiPosition.point = point
            ValuateOptions.uiPosition.relativePoint = relativePoint
            ValuateOptions.uiPosition.x = x
            ValuateOptions.uiPosition.y = y
        end
    end)
    
    -- Title bar (clean, minimal)
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -8)
    titleBar:SetHeight(24)
    
    -- Title text (centered)
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", FONT_TITLE)
    titleText:SetPoint("CENTER", frame, "TOP", 0, -20)
    titleText:SetText("Valuate")
    titleText:SetTextColor(unpack(COLORS.textTitle))
    
    -- Version text (smaller, next to title)
    local versionText = titleBar:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    versionText:SetPoint("LEFT", titleText, "RIGHT", 6, 0)
    versionText:SetText("v" .. (Valuate.version or "?"))
    versionText:SetTextColor(unpack(COLORS.textDim))
    
    -- Close button (custom styled)
    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(18, 18)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    closeButton:SetBackdrop(BACKDROP_BUTTON)
    closeButton:SetBackdropColor(0.2, 0.2, 0.2, 1)
    closeButton:SetBackdropBorderColor(unpack(COLORS.border))
    
    local closeLabel = closeButton:CreateFontString(nil, "OVERLAY", FONT_BODY)
    closeLabel:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
    closeLabel:SetText("×")
    closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.5, 0.2, 0.2, 1)
        closeLabel:SetTextColor(1, 1, 1, 1)
    end)
    closeButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        closeLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    closeButton:SetScript("OnClick", function()
        Valuate:HideUI()
    end)
    
    -- Content area (below title bar)
    local contentFrame = CreateFrame("Frame", nil, frame)
    contentFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", PADDING, -PADDING)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING, PADDING)
    frame.contentFrame = contentFrame
    
    -- Store reference
    ValuateUIFrame = frame
    frame:Hide()
    
    return frame
end

-- ========================================
-- Tab System
-- ========================================

local function CreateTabSystem(mainFrame, contentFrame)
    local activeTab = "scales"
    local tabs = {}
    local tabPanels = {}
    
    local function SelectTab(tabName)
        activeTab = tabName
        
        -- Hide all panels
        for _, panel in pairs(tabPanels) do
            panel:Hide()
        end
        
        -- Show selected panel
        if tabPanels[tabName] then
            tabPanels[tabName]:Show()
        end
        
        -- Adjust window height based on tab
        if ValuateUIFrame then
            if tabName == "scales" then
                -- Scales tab: Restore dynamic height if a scale is already selected
                if EditingScaleName and ValuateScales[EditingScaleName] then
                    -- Trigger resize by refreshing the scale editor
                    ValuateUI_UpdateScaleEditor(EditingScaleName, ValuateScales[EditingScaleName])
                end
            else
                -- Instructions, About, Changelog, and Settings tabs: Use minimum height with proper spacing
                ValuateUIFrame:SetHeight(MIN_WINDOW_HEIGHT)
            end
        end
        
        -- Update tab buttons - selected vs unselected appearance
        for name, btn in pairs(tabs) do
            if name == tabName then
                -- Selected tab: brighter background and border
                btn:SetBackdropColor(unpack(COLORS.buttonHover))
                btn:SetBackdropBorderColor(unpack(COLORS.borderLight))
                btn.label:SetTextColor(unpack(COLORS.textBody))
            else
                -- Unselected tab: darker, recessed look
                btn:SetBackdropColor(unpack(COLORS.buttonPressed))
                btn:SetBackdropBorderColor(unpack(COLORS.borderDark))
                btn.label:SetTextColor(unpack(COLORS.textDim))
            end
        end
    end
    
    -- Create tab buttons dynamically - sitting on bottom border of window
    local function CreateTab(name, text, panel, anchorSide)
        local btn = CreateFrame("Button", nil, mainFrame)  -- Parent to mainFrame for proper anchoring
        btn:SetHeight(22)
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        btn:SetScript("OnClick", function()
            SelectTab(name)
        end)
        
        local label = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        label:SetPoint("CENTER", btn, "CENTER", 0, 0)
        label:SetText(text)
        label:SetTextColor(unpack(COLORS.textBody))
        btn.label = label
        
        -- Size button based on text
        btn:SetWidth(label:GetStringWidth() + 40)
        
        -- Position tab on specified side of window bottom
        if anchorSide == "right" then
            btn:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -20, -21)
        else
            btn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 20, -21)
        end
        
        tabs[name] = btn
        tabPanels[name] = panel
        
        return btn
    end
    
    -- Create panel containers - fill the entire content area
    local scalesPanel = CreateFrame("Frame", nil, contentFrame)
    scalesPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    scalesPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    
    local instructionsPanel = CreateFrame("Frame", nil, contentFrame)
    instructionsPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    instructionsPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    instructionsPanel:Hide()
    
    local settingsPanel = CreateFrame("Frame", nil, contentFrame)
    settingsPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    settingsPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    settingsPanel:Hide()
    
    local aboutPanel = CreateFrame("Frame", nil, contentFrame)
    aboutPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    aboutPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    aboutPanel:Hide()
    
    local changelogPanel = CreateFrame("Frame", nil, contentFrame)
    changelogPanel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    changelogPanel:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
    changelogPanel:Hide()
    
    -- Create tabs (Scales on left, Instructions/About/Changelog/Settings on right)
    CreateTab("scales", "Scales", scalesPanel, "left")
    
    -- Create Settings tab first (anchored to right)
    local settingsTab = CreateTab("settings", "Settings", settingsPanel, "right")
    
    -- Create Changelog tab to the left of Settings
    local changelogBtn = CreateFrame("Button", nil, mainFrame)
    changelogBtn:SetHeight(22)
    changelogBtn:SetBackdrop(BACKDROP_BUTTON)
    changelogBtn:SetBackdropColor(unpack(COLORS.buttonBg))
    changelogBtn:SetBackdropBorderColor(unpack(COLORS.border))
    changelogBtn:SetScript("OnClick", function()
        SelectTab("changelog")
    end)
    
    local changelogLabel = changelogBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    changelogLabel:SetPoint("CENTER", changelogBtn, "CENTER", 0, 0)
    changelogLabel:SetText("Changelog")
    changelogLabel:SetTextColor(unpack(COLORS.textBody))
    changelogBtn.label = changelogLabel
    changelogBtn:SetWidth(changelogLabel:GetStringWidth() + 40)
    changelogBtn:SetPoint("RIGHT", settingsTab, "LEFT", -4, 0)
    
    tabs["changelog"] = changelogBtn
    tabPanels["changelog"] = changelogPanel
    
    -- Create About tab to the left of Changelog
    local aboutBtn = CreateFrame("Button", nil, mainFrame)
    aboutBtn:SetHeight(22)
    aboutBtn:SetBackdrop(BACKDROP_BUTTON)
    aboutBtn:SetBackdropColor(unpack(COLORS.buttonBg))
    aboutBtn:SetBackdropBorderColor(unpack(COLORS.border))
    aboutBtn:SetScript("OnClick", function()
        SelectTab("about")
    end)
    
    local aboutLabel = aboutBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    aboutLabel:SetPoint("CENTER", aboutBtn, "CENTER", 0, 0)
    aboutLabel:SetText("About")
    aboutLabel:SetTextColor(unpack(COLORS.textBody))
    aboutBtn.label = aboutLabel
    aboutBtn:SetWidth(aboutLabel:GetStringWidth() + 40)
    aboutBtn:SetPoint("RIGHT", changelogBtn, "LEFT", -4, 0)
    
    tabs["about"] = aboutBtn
    tabPanels["about"] = aboutPanel
    
    -- Create Instructions tab to the left of About
    local instructionsBtn = CreateFrame("Button", nil, mainFrame)
    instructionsBtn:SetHeight(22)
    instructionsBtn:SetBackdrop(BACKDROP_BUTTON)
    instructionsBtn:SetBackdropColor(unpack(COLORS.buttonBg))
    instructionsBtn:SetBackdropBorderColor(unpack(COLORS.border))
    instructionsBtn:SetScript("OnClick", function()
        SelectTab("instructions")
    end)
    
    local instructionsLabel = instructionsBtn:CreateFontString(nil, "OVERLAY", FONT_BODY)
    instructionsLabel:SetPoint("CENTER", instructionsBtn, "CENTER", 0, 0)
    instructionsLabel:SetText("Instructions")
    instructionsLabel:SetTextColor(unpack(COLORS.textBody))
    instructionsBtn.label = instructionsLabel
    instructionsBtn:SetWidth(instructionsLabel:GetStringWidth() + 40)
    instructionsBtn:SetPoint("RIGHT", aboutBtn, "LEFT", -4, 0)
    
    tabs["instructions"] = instructionsBtn
    tabPanels["instructions"] = instructionsPanel
    
    -- Select default tab
    SelectTab("scales")
    
    return {
        frame = tabFrame,
        scalesPanel = scalesPanel,
        instructionsPanel = instructionsPanel,
        aboutPanel = aboutPanel,
        changelogPanel = changelogPanel,
        settingsPanel = settingsPanel,
        selectTab = SelectTab
    }
end

-- ========================================
-- Scale List (Left Panel)
-- ========================================

local ScaleListFrame = nil
local ScaleListButtons = {}

local function UpdateScaleList()
    if not ScaleListFrame then return end
    
    -- Clear existing buttons
    for _, btn in pairs(ScaleListButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    ScaleListButtons = {}
    
    -- Get all scales
    local scales = {}
    if ValuateScales then
        for name, scale in pairs(ValuateScales) do
            tinsert(scales, { name = name, scale = scale })
        end
    end
    
    -- Sort by display name
    table.sort(scales, function(a, b)
        return (a.scale.DisplayName or a.name) < (b.scale.DisplayName or b.name)
    end)
    
    -- Create button for each scale
    local lastButton = nil
    for i, scaleData in ipairs(scales) do
        local btn = CreateFrame("Button", nil, ScaleListFrame)
        btn:SetHeight(ENTRY_HEIGHT)
        btn:SetWidth(168)  -- Fits within scroll content area
        
        -- Center the scale buttons horizontally
        if i == 1 then
            btn:SetPoint("TOP", ScaleListFrame, "TOP", 0, 0)
        else
            btn:SetPoint("TOP", lastButton, "BOTTOM", 0, -2)
        end
        lastButton = btn
        
        btn:SetBackdrop(BACKDROP_BUTTON)
        btn:SetBackdropColor(unpack(COLORS.buttonBg))
        btn:SetBackdropBorderColor(unpack(COLORS.border))
        
        -- Visibility checkbox (leftmost element)
        local visCheckbox = CreateFrame("CheckButton", nil, btn)
        visCheckbox:SetSize(14, 14)
        visCheckbox:SetPoint("LEFT", btn, "LEFT", 4, 0)
        visCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        visCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        visCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        visCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        
        local isVisible = scaleData.scale.Visible ~= false
        visCheckbox:SetChecked(isVisible)
        
        -- Color preview button (clickable to change color)
        local colorBtn = CreateFrame("Button", nil, btn)
        colorBtn:SetSize(14, 14)
        colorBtn:SetPoint("LEFT", visCheckbox, "RIGHT", 4, 0)
        
        local colorPreview = colorBtn:CreateTexture(nil, "OVERLAY")
        colorPreview:SetAllPoints(colorBtn)
        local color = scaleData.scale.Color or "FFFFFF"
        local r, g, b = HexToRGB(color)
        colorPreview:SetTexture(1, 1, 1, 1)
        colorPreview:SetVertexColor(r, g, b, 1)
        
        -- Color picker on click
        colorBtn:SetScript("OnClick", function(self)
            local scale = ValuateScales[scaleData.name]
            if not scale then return end
            
            local currentColor = scale.Color or "FFFFFF"
            local cr, cg, cb = HexToRGB(currentColor)
            
            -- Store reference for callback
            local scaleName = scaleData.name
            
            ColorPickerFrame.previousValues = { cr, cg, cb }
            
            ColorPickerFrame.func = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newColor = RGBToHex(newR, newG, newB)
                if ValuateScales[scaleName] then
                    ValuateScales[scaleName].Color = newColor
                end
                colorPreview:SetVertexColor(newR, newG, newB, 1)
                -- Update the scale list to reflect new color
                UpdateScaleList()
                
                -- Reset tooltips to show new color immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            
            ColorPickerFrame.cancelFunc = function()
                local prev = ColorPickerFrame.previousValues
                if prev and ValuateScales[scaleName] then
                    ValuateScales[scaleName].Color = RGBToHex(prev[1], prev[2], prev[3])
                end
                UpdateScaleList()
                
                -- Reset tooltips to restore original color
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            
            ColorPickerFrame.opacityFunc = nil
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(cr, cg, cb)
            ColorPickerFrame:Show()
        end)
        
        colorBtn:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Change Color", 1, 1, 1)
            GameTooltip:AddLine("Click to change this scale's display color.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            end
        end)
        colorBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Icon picker button (after color button)
        local iconBtn = CreateFrame("Button", nil, btn)
        iconBtn:SetSize(14, 14)
        iconBtn:SetPoint("LEFT", colorBtn, "RIGHT", 4, 0)
        
        local iconTexture = iconBtn:CreateTexture(nil, "OVERLAY")
        iconTexture:SetAllPoints(iconBtn)
        local currentIcon = scaleData.scale.Icon
        if currentIcon and currentIcon ~= "" then
            iconTexture:SetTexture(currentIcon)
            iconTexture:SetVertexColor(1, 1, 1, 1)
        else
            -- Default placeholder icon (dimmed when no icon set)
            iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            iconTexture:SetVertexColor(0.5, 0.5, 0.5, 0.5)
        end
        
        -- Icon picker on click
        iconBtn:SetScript("OnClick", function(self)
            local scaleName = scaleData.name
            ShowIconPicker(function(selectedIcon)
                if ValuateScales[scaleName] then
                    ValuateScales[scaleName].Icon = selectedIcon
                end
                if selectedIcon and selectedIcon ~= "" then
                    iconTexture:SetTexture(selectedIcon)
                    iconTexture:SetVertexColor(1, 1, 1, 1)
                else
                    iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                    iconTexture:SetVertexColor(0.5, 0.5, 0.5, 0.5)
                end
            end)
        end)
        
        iconBtn:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Change Icon", 1, 1, 1)
            GameTooltip:AddLine("Click to select an icon for this scale's tooltip display.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            end
        end)
        iconBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Delete button (styled like close button)
        local deleteBtn = CreateFrame("Button", nil, btn)
        deleteBtn:SetSize(16, 16)
        deleteBtn:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        deleteBtn:SetBackdrop(BACKDROP_BUTTON)
        deleteBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
        deleteBtn:SetBackdropBorderColor(unpack(COLORS.border))
        
        local deleteLabel = deleteBtn:CreateFontString(nil, "OVERLAY", FONT_SMALL)
        deleteLabel:SetPoint("CENTER", deleteBtn, "CENTER", 0, 0)
        deleteLabel:SetText("×")
        deleteLabel:SetTextColor(0.7, 0.7, 0.7, 1)
        
        deleteBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.5, 0.2, 0.2, 1)
            deleteLabel:SetTextColor(1, 1, 1, 1)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Delete Scale", 1, 1, 1)
            GameTooltip:AddLine("Click to delete this scale.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Shift-click to skip confirmation.", 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
            end
        end)
        deleteBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            deleteLabel:SetTextColor(0.7, 0.7, 0.7, 1)
            GameTooltip:Hide()
        end)
        deleteBtn:SetScript("OnClick", function(self)
            local scaleName = scaleData.name
            
            -- If Shift key is held down, delete immediately without confirmation
            if IsShiftKeyDown() then
                ValuateScales[scaleName] = nil
                if CurrentSelectedScale == scaleName then
                    CurrentSelectedScale = nil
                    EditingScaleName = nil
                    if ScaleEditorFrame and ScaleEditorFrame.container then
                        ScaleEditorFrame.container:Hide()
                    end
                end
                UpdateScaleList()
            else
                -- Show confirmation dialog
                StaticPopupDialogs["VALUATE_DELETE_SCALE"] = {
                    text = "Are you sure you want to delete the scale \"" .. (scaleData.scale.DisplayName or scaleName) .. "\"?",
                    button1 = "Delete",
                    button2 = "Cancel",
                    OnAccept = function()
                        ValuateScales[scaleName] = nil
                        if CurrentSelectedScale == scaleName then
                            CurrentSelectedScale = nil
                            EditingScaleName = nil
                            if ScaleEditorFrame and ScaleEditorFrame.container then
                                ScaleEditorFrame.container:Hide()
                            end
                        end
                        UpdateScaleList()
                        
                        -- Reset all tooltips to reflect the deletion immediately
                        if Valuate.ResetTooltips then
                            Valuate:ResetTooltips()
                        end
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                }
                StaticPopup_Show("VALUATE_DELETE_SCALE")
            end
        end)
        
        -- Scale name
        local nameLabel = btn:CreateFontString(nil, "OVERLAY", FONT_BODY)
        nameLabel:SetPoint("LEFT", iconBtn, "RIGHT", 4, 0)
        nameLabel:SetPoint("RIGHT", deleteBtn, "LEFT", -4, 0)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText(scaleData.scale.DisplayName or scaleData.name)
        
        -- Helper to update visual state based on visibility
        local function UpdateVisualState(visible)
            -- Get current color from scale data (may have been updated by color picker)
            local currentColor = (ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Color) or "FFFFFF"
            local cr, cg, cb = HexToRGB(currentColor)
            
            -- Get current icon from scale data
            local currentScaleIcon = ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Icon
            local hasIcon = currentScaleIcon and currentScaleIcon ~= ""
            
            if visible then
                nameLabel:SetTextColor(cr, cg, cb, 1)
                colorPreview:SetVertexColor(cr, cg, cb, 1)
                btn:SetBackdropColor(unpack(COLORS.buttonBg))
                -- Update icon visual state
                if hasIcon then
                    iconTexture:SetVertexColor(1, 1, 1, 1)
                else
                    iconTexture:SetVertexColor(0.5, 0.5, 0.5, 0.5)
                end
            else
                nameLabel:SetTextColor(unpack(COLORS.textDim))
                colorPreview:SetVertexColor(unpack(COLORS.textDim))
                btn:SetBackdropColor(unpack(COLORS.disabled))
                iconTexture:SetVertexColor(0.3, 0.3, 0.3, 0.5)
            end
        end
        
        -- Set initial visual state
        UpdateVisualState(isVisible)
        
        -- Visibility checkbox click handler
        visCheckbox:SetScript("OnClick", function(self)
            local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
            if ValuateScales[scaleData.name] then
                ValuateScales[scaleData.name].Visible = checked
                
                -- Reset all tooltips to reflect the visibility change immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            UpdateVisualState(checked)
        end)
        
        -- Tooltip for visibility checkbox
        visCheckbox:SetScript("OnEnter", function(self)
            if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Show in Tooltip", 1, 1, 1)
            GameTooltip:AddLine("Toggle whether this scale appears in item tooltips.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            end
        end)
        visCheckbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        
        -- Store references for visual updates
        btn.nameLabel = nameLabel
        btn.colorPreview = colorPreview
        btn.visCheckbox = visCheckbox
        btn.updateVisualState = UpdateVisualState
        btn.scaleColor = { r = r, g = g, b = b }
        
        -- Highlight on mouseover (only if visible)
        btn:SetScript("OnEnter", function(self)
            if CurrentSelectedScale ~= scaleData.name then
                local vis = ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Visible ~= false
                if vis then
                    self:SetBackdropColor(unpack(COLORS.buttonHover))
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if CurrentSelectedScale ~= scaleData.name then
                local vis = ValuateScales[scaleData.name] and ValuateScales[scaleData.name].Visible ~= false
                if vis then
                    self:SetBackdropColor(unpack(COLORS.buttonBg))
                else
                    self:SetBackdropColor(unpack(COLORS.disabled))
                end
            end
        end)
        
        -- Click to select
        btn:SetScript("OnClick", function(self)
            -- Deselect previous
            if CurrentSelectedScale and ScaleListButtons[CurrentSelectedScale] then
                local prevBtn = ScaleListButtons[CurrentSelectedScale]
                local prevVis = ValuateScales[CurrentSelectedScale] and ValuateScales[CurrentSelectedScale].Visible ~= false
                if prevVis then
                    prevBtn:SetBackdropColor(unpack(COLORS.buttonBg))
                    prevBtn:SetBackdropBorderColor(unpack(COLORS.border))
                else
                    prevBtn:SetBackdropColor(unpack(COLORS.disabled))
                    prevBtn:SetBackdropBorderColor(unpack(COLORS.borderDark))
                end
            end
            
            -- Select this one
            CurrentSelectedScale = scaleData.name
            self:SetBackdropColor(unpack(COLORS.selected))
            self:SetBackdropBorderColor(unpack(COLORS.selectedBorder))
            
            -- Update editor with current scale data from ValuateScales
            ValuateUI_UpdateScaleEditor(scaleData.name, ValuateScales[scaleData.name])
        end)
        
        ScaleListButtons[scaleData.name] = btn
        tinsert(ScaleListButtons, btn)
    end
    
    -- Update scroll frame content height (account for spacing between entries)
    if ScaleListFrame then
        local contentHeight = #scales * (ENTRY_HEIGHT + 2)
        ScaleListFrame:SetHeight(math.max(contentHeight, 100))
        
        -- Update scrollbar range and visibility
        local scrollFrame = ScaleListFrame:GetParent()
        if scrollFrame and scrollFrame.scrollBar then
            local scrollBar = scrollFrame.scrollBar
            local scrollBarBg = scrollFrame.scrollBarBg
            local scrollFrameHeight = scrollFrame:GetHeight()
            local maxScroll = math.max(0, contentHeight - scrollFrameHeight)
            
            -- Check if scrolling is needed
            local needsScrollbar = contentHeight > scrollFrameHeight
            
            if needsScrollbar then
                -- Show scrollbar
                scrollBar:Show()
                if scrollBarBg then scrollBarBg:Show() end
                
                -- Position scrollFrame with scrollbar space reserved
                scrollFrame:ClearAllPoints()
                scrollFrame:SetPoint("TOPLEFT", scrollFrame.buttonContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMLEFT", scrollFrame:GetParent(), "BOTTOMLEFT", 0, PADDING)
                scrollFrame:SetPoint("TOPRIGHT", scrollFrame.buttonContainer, "BOTTOMRIGHT", -SCROLLBAR_WIDTH, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMRIGHT", scrollFrame:GetParent(), "BOTTOMRIGHT", -SCROLLBAR_WIDTH, PADDING)
            else
                -- Hide scrollbar
                scrollBar:Hide()
                if scrollBarBg then scrollBarBg:Hide() end
                
                -- Position scrollFrame to fill full width (no scrollbar space)
                scrollFrame:ClearAllPoints()
                scrollFrame:SetPoint("TOPLEFT", scrollFrame.buttonContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMLEFT", scrollFrame:GetParent(), "BOTTOMLEFT", 0, PADDING)
                scrollFrame:SetPoint("TOPRIGHT", scrollFrame.buttonContainer, "BOTTOMRIGHT", 0, -ELEMENT_SPACING)
                scrollFrame:SetPoint("BOTTOMRIGHT", scrollFrame:GetParent(), "BOTTOMRIGHT", 0, PADDING)
            end
            
            scrollBar:SetMinMaxValues(0, maxScroll)
            if scrollBar:GetValue() > maxScroll then
                scrollBar:SetValue(maxScroll)
            end
        end
    end
end

-- Setup the template overwrite callback now that we have access to UpdateScaleList
ValuateUI_OnTemplateOverwrite = function(template)
    if not template then return end
    
    local scaleName = template.name
    local scale = ValuateScales[scaleName]
    
    if scale then
        -- Overwrite existing scale with template data
        scale.DisplayName = scaleName
        scale.Color = template.color or "FFFFFF"  -- Use spec's color
        scale.Icon = template.icon
        scale.Values = {}
        
        -- Copy stat weights from template
        if template.weights then
            for statName, value in pairs(template.weights) do
                scale.Values[statName] = value
            end
        end
        
        -- Clear any unusable flags
        scale.Unusable = {}
        
        -- Refresh list and select the scale
        UpdateScaleList()
        if ScaleListButtons[scaleName] then
            ScaleListButtons[scaleName]:GetScript("OnClick")(ScaleListButtons[scaleName])
        end
        
        -- Reset all tooltips to show the updated scale immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end
end

local function CreateScaleList(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    container:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    container:SetWidth(200)
    
    -- Button container for New Scale and Template buttons
    local buttonContainer = CreateFrame("Frame", nil, container)
    buttonContainer:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    buttonContainer:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    buttonContainer:SetHeight(BUTTON_HEIGHT)
    
    -- New Blank Scale button (80% width)
    local newButtonWidth = math.floor((200 - ELEMENT_SPACING) * 0.8)
    local newButton = CreateStyledButton(buttonContainer, "New Blank Scale", newButtonWidth, BUTTON_HEIGHT)
    newButton:SetPoint("TOPLEFT", buttonContainer, "TOPLEFT", 0, 0)
    newButton:SetScript("OnClick", function()
        ValuateUI_NewScale()
    end)
    
    -- Template button (20% width) - "+" symbol
    local templateButtonWidth = 200 - newButtonWidth - ELEMENT_SPACING
    local templateButton = CreateStyledButton(buttonContainer, "+", templateButtonWidth, BUTTON_HEIGHT)
    templateButton:SetPoint("TOPRIGHT", buttonContainer, "TOPRIGHT", 0, 0)
    templateButton:SetScript("OnClick", function()
        ValuateUI_ShowTemplatePicker()
    end)
    
    -- Tooltip for template button
    templateButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
        self:SetBackdropBorderColor(unpack(COLORS.borderLight))
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:SetText("Create from Template", 1, 1, 1)
        GameTooltip:AddLine("Select a class/spec template", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
        end
    end)
    templateButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonBg))
        self:SetBackdropBorderColor(unpack(COLORS.border))
        GameTooltip:Hide()
    end)
    
    -- Scroll frame for scale list (initially takes full width, scrollbar space reserved only when needed)
    local scrollFrame = CreateFrame("ScrollFrame", nil, container)
    scrollFrame:SetPoint("TOPLEFT", buttonContainer, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, PADDING)
    scrollFrame:SetPoint("TOPRIGHT", buttonContainer, "BOTTOMRIGHT", 0, -ELEMENT_SPACING)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, PADDING)
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
    
    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetWidth(180)  -- Content width (wider than buttons to allow centering)
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Scrollbar backdrop for visibility
    local scrollBarBg = CreateFrame("Frame", nil, container)
    scrollBarBg:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollBarBg:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, PADDING)
    scrollBarBg:SetBackdrop(BACKDROP_PANEL)
    scrollBarBg:SetBackdropColor(unpack(COLORS.windowBg))
    scrollBarBg:SetBackdropBorderColor(unpack(COLORS.borderDark))
    scrollBarBg:Hide()  -- Start hidden, will be shown if needed
    
    -- Scrollbar (positioned to the right of clip frame, inside container)
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
    scrollBar:Hide()  -- Start hidden, will be shown if needed
    scrollFrame.scrollBar = scrollBar
    scrollFrame.scrollBarBg = scrollBarBg
    scrollFrame.buttonContainer = buttonContainer
    
    ScaleListFrame = contentFrame
    
    return container
end

-- ========================================
-- Scale Editor (Right Panel)
-- ========================================

local ScaleEditorFrame = nil
local StatWeightRows = {}

-- Helper to create a stat row
local function CreateStatRow(parent, statName, scale, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(COLUMN_WIDTH)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
    
    -- Stat label (shorter width for 4-column layout)
    local label = row:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(75)
    label:SetJustifyH("RIGHT")
    label:SetText((ValuateStatNames[statName] or statName) .. ":")
    
    -- Value input (compact, with validation)
    local editBox = CreateFrame("EditBox", nil, row)
    editBox:SetHeight(14)
    editBox:SetWidth(52)  -- Width for comfortable display of 5 digits + minus + decimal
    editBox:SetPoint("LEFT", label, "RIGHT", 2, 0)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")  -- Using smaller font for compact display
    editBox:SetJustifyH("CENTER")
    editBox:SetBackdrop(BACKDROP_INPUT)
    editBox:SetBackdropColor(unpack(COLORS.inputBg))
    editBox:SetBackdropBorderColor(unpack(COLORS.border))
    editBox:SetTextInsets(2, 2, 0, 0)
    editBox.statName = statName
    
    -- Apply input validation (max 5 digits, one decimal, minus at start only)
    ApplyStatValueValidation(editBox)
    
    -- Focus handling
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText()) or 0
        if EditingScaleName and ValuateScales[EditingScaleName] then
            local scale = ValuateScales[EditingScaleName]
            if not scale.Values then scale.Values = {} end
            if value ~= 0 then
                scale.Values[self.statName] = value
            else
                scale.Values[self.statName] = nil
            end
            
            -- Reset all tooltips to reflect the change immediately
            if Valuate.ResetTooltips then
                Valuate:ResetTooltips()
            end
        end
        self:ClearFocus()
    end)
    
    -- Unusable checkbox (ban stat) - smaller for compact layout
    local unusableCheckbox = CreateFrame("CheckButton", nil, row)
    unusableCheckbox:SetSize(12, 12)
    unusableCheckbox:SetPoint("LEFT", editBox, "RIGHT", 2, 0)
    unusableCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    unusableCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    unusableCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    unusableCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    unusableCheckbox.statName = statName
    
    -- Helper function to update banned visual state
    local function UpdateBannedState(isBanned)
        if isBanned then
            label:SetTextColor(unpack(COLORS.textDim))
            editBox:SetText("")
            editBox:EnableMouse(false)
            editBox:EnableKeyboard(false)
            editBox:SetBackdropColor(unpack(COLORS.disabled))
            editBox:SetBackdropBorderColor(unpack(COLORS.borderDark))
        else
            label:SetTextColor(unpack(COLORS.textBody))
            editBox:EnableMouse(true)
            editBox:EnableKeyboard(true)
            editBox:SetBackdropColor(unpack(COLORS.inputBg))
            editBox:SetBackdropBorderColor(unpack(COLORS.border))
        end
    end
    
    -- Check if this stat is marked as unusable
    local isUnusable = (scale and scale.Unusable and scale.Unusable[statName])
    unusableCheckbox:SetChecked(isUnusable == true)
    
    -- Set initial visual state
    if isUnusable then
        UpdateBannedState(true)
    else
        local value = (scale and scale.Values and scale.Values[statName])
        if value and value ~= 0 then
            editBox:SetText(tostring(value))
        else
            editBox:SetText("")
        end
    end
    
    -- OnClick handler for ban checkbox
    unusableCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        if EditingScaleName and ValuateScales[EditingScaleName] then
            local currentScale = ValuateScales[EditingScaleName]
            if not currentScale.Unusable then
                currentScale.Unusable = {}
            end
            
            if checked then
                currentScale.Unusable[statName] = true
                if currentScale.Values then
                    currentScale.Values[statName] = nil
                end
            else
                currentScale.Unusable[statName] = nil
            end
            
            -- Reset all tooltips to reflect the change immediately
            if Valuate.ResetTooltips then
                Valuate:ResetTooltips()
            end
        end
        
        UpdateBannedState(checked)
    end)
    
    -- Tooltip for unusable checkbox
    unusableCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Ban Stat", 1, 1, 1)
        GameTooltip:AddLine("Items with this stat won't show a score for this scale.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    unusableCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    row.label = label
    row.editBox = editBox
    row.unusableCheckbox = unusableCheckbox
    row.updateBannedState = UpdateBannedState
    
    return row
end

local function UpdateStatWeightsList(scaleName, scale)
    if not ScaleEditorFrame then return end
    
    -- Clear existing rows
    for _, row in pairs(StatWeightRows) do
        if row.Hide then row:Hide() end
        if row.SetParent then row:SetParent(nil) end
    end
    StatWeightRows = {}
    
    -- Use categories from StatDefinitions.lua
    if not ValuateStatCategories then
        print("|cFFFF0000Valuate|r: Stat categories not defined!")
        return
    end
    
    -- Create 4 column frames
    local columnFrames = {}
    local columnHeights = {0, 0, 0, 0}
    
    for i = 1, 4 do
        local colFrame = CreateFrame("Frame", nil, ScaleEditorFrame)
        colFrame:SetWidth(COLUMN_WIDTH)
        colFrame:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", (i - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0)
        columnFrames[i] = colFrame
        tinsert(StatWeightRows, colFrame)
    end
    
    -- Populate each column with its categories
    for _, category in ipairs(ValuateStatCategories) do
        local col = category.column
        if col and col >= 1 and col <= 4 and columnFrames[col] then
            local colFrame = columnFrames[col]
            local yOffset = -columnHeights[col]
            
            -- Create category header
            local headerFrame = CreateFrame("Frame", nil, colFrame)
            headerFrame:SetHeight(HEADER_HEIGHT)
            headerFrame:SetWidth(COLUMN_WIDTH)
            
            if columnHeights[col] > 0 then
                yOffset = yOffset - HEADER_SPACING
            end
            headerFrame:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, yOffset)
            
            local headerLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H3)
            headerLabel:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
            headerLabel:SetText(category.header)
            headerLabel:SetTextColor(unpack(COLORS.textAccent))
            
            tinsert(StatWeightRows, headerFrame)
            
            if columnHeights[col] > 0 then
                columnHeights[col] = columnHeights[col] + HEADER_SPACING
            end
            columnHeights[col] = columnHeights[col] + HEADER_HEIGHT
            
            -- Create stat rows for this category
            for _, statName in ipairs(category.stats) do
                if ValuateStatNames[statName] then
                    local rowYOffset = -columnHeights[col] - ROW_SPACING
                    local row = CreateStatRow(colFrame, statName, scale, rowYOffset)
                    
                    StatWeightRows[statName] = row
                    tinsert(StatWeightRows, row)
                    columnHeights[col] = columnHeights[col] + ROW_HEIGHT + ROW_SPACING
                end
            end
        end
    end
    
    -- Find tallest column for scroll height (core stats section)
    local coreMaxHeight = 0
    for i = 1, 4 do
        if columnHeights[i] > coreMaxHeight then
            coreMaxHeight = columnHeights[i]
        end
    end
    
    -- Set column frame heights for core stats
    for i = 1, 4 do
        columnFrames[i]:SetHeight(coreMaxHeight)
    end
    
    -- ========================================
    -- Equipment Types Section (below core stats)
    -- ========================================
    local equipmentStartY = coreMaxHeight + ELEMENT_SPACING * 2
    
    if ValuateEquipmentCategories then
        -- Equipment section header
        local equipHeader = CreateFrame("Frame", nil, ScaleEditorFrame)
        equipHeader:SetHeight(HEADER_HEIGHT + 4)
        equipHeader:SetWidth(4 * COLUMN_WIDTH + 3 * COLUMN_GAP)
        equipHeader:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", 0, -equipmentStartY)
        
        -- Separator line
        local separator = equipHeader:CreateTexture(nil, "BACKGROUND")
        separator:SetHeight(1)
        separator:SetPoint("TOPLEFT", equipHeader, "TOPLEFT", 0, 0)
        separator:SetPoint("TOPRIGHT", equipHeader, "TOPRIGHT", 0, 0)
        separator:SetColorTexture(unpack(COLORS.border))
        
        local equipLabel = equipHeader:CreateFontString(nil, "OVERLAY", FONT_H2)
        equipLabel:SetPoint("LEFT", equipHeader, "LEFT", 0, -6)
        equipLabel:SetText("Equipment Types")
        equipLabel:SetTextColor(unpack(COLORS.textHeader))
        
        tinsert(StatWeightRows, equipHeader)
        
        local equipStartY = equipmentStartY + HEADER_HEIGHT + ELEMENT_SPACING
        
        -- Separate categories by row
        local row1Categories = {}
        local row2Categories = {}
        
        for _, category in ipairs(ValuateEquipmentCategories) do
            if category.row == 2 then
                tinsert(row2Categories, category)
            else
                tinsert(row1Categories, category)
            end
        end
        
        -- Create equipment column frames for row 1
        local equipColumnFrames = {}
        local equipColumnHeights = {0, 0, 0, 0}
        
        for i = 1, 4 do
            local colFrame = CreateFrame("Frame", nil, ScaleEditorFrame)
            colFrame:SetWidth(COLUMN_WIDTH)
            colFrame:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", (i - 1) * (COLUMN_WIDTH + COLUMN_GAP), -equipStartY)
            equipColumnFrames[i] = colFrame
            tinsert(StatWeightRows, colFrame)
        end
        
        -- Populate row 1 equipment categories
        for _, category in ipairs(row1Categories) do
            local col = category.column
            if col and col >= 1 and col <= 4 and equipColumnFrames[col] then
                local colFrame = equipColumnFrames[col]
                local yOffset = -equipColumnHeights[col]
                
                -- Create category header
                local headerFrame = CreateFrame("Frame", nil, colFrame)
                headerFrame:SetHeight(HEADER_HEIGHT)
                headerFrame:SetWidth(COLUMN_WIDTH)
                headerFrame:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, yOffset)
                
                local headerLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H3)
                headerLabel:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
                headerLabel:SetText(category.header)
                headerLabel:SetTextColor(unpack(COLORS.textAccent))
                
                tinsert(StatWeightRows, headerFrame)
                equipColumnHeights[col] = equipColumnHeights[col] + HEADER_HEIGHT
                
                -- Create stat rows for equipment types
                for _, statName in ipairs(category.stats) do
                    if ValuateStatNames[statName] then
                        local rowYOffset = -equipColumnHeights[col] - ROW_SPACING
                        local row = CreateStatRow(colFrame, statName, scale, rowYOffset)
                        
                        StatWeightRows[statName] = row
                        tinsert(StatWeightRows, row)
                        equipColumnHeights[col] = equipColumnHeights[col] + ROW_HEIGHT + ROW_SPACING
                    end
                end
            end
        end
        
        -- Find tallest equipment column in row 1
        local equipMaxHeight = 0
        for i = 1, 4 do
            if equipColumnHeights[i] > equipMaxHeight then
                equipMaxHeight = equipColumnHeights[i]
            end
        end
        
        -- Set equipment column heights for row 1
        for i = 1, 4 do
            equipColumnFrames[i]:SetHeight(equipMaxHeight)
        end
        
        local row1Height = equipMaxHeight
        
        -- Handle row 2 categories (Relics)
        if #row2Categories > 0 then
            local row2StartY = equipStartY + row1Height + HEADER_SPACING
            
            -- Create column frames for row 2
            local row2ColumnFrames = {}
            local row2ColumnHeights = {0, 0, 0, 0}
            
            for i = 1, 4 do
                local colFrame = CreateFrame("Frame", nil, ScaleEditorFrame)
                colFrame:SetWidth(COLUMN_WIDTH)
                colFrame:SetPoint("TOPLEFT", ScaleEditorFrame, "TOPLEFT", (i - 1) * (COLUMN_WIDTH + COLUMN_GAP), -row2StartY)
                row2ColumnFrames[i] = colFrame
                tinsert(StatWeightRows, colFrame)
            end
            
            -- Populate row 2 equipment categories
            for _, category in ipairs(row2Categories) do
                local col = category.column
                if col and col >= 1 and col <= 4 and row2ColumnFrames[col] then
                    local colFrame = row2ColumnFrames[col]
                    local yOffset = -row2ColumnHeights[col]
                    
                    -- Create category header
                    local headerFrame = CreateFrame("Frame", nil, colFrame)
                    headerFrame:SetHeight(HEADER_HEIGHT)
                    headerFrame:SetWidth(COLUMN_WIDTH)
                    headerFrame:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, yOffset)
                    
                    local headerLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H3)
                    headerLabel:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
                    headerLabel:SetText(category.header)
                    headerLabel:SetTextColor(unpack(COLORS.textAccent))
                    
                    tinsert(StatWeightRows, headerFrame)
                    row2ColumnHeights[col] = row2ColumnHeights[col] + HEADER_HEIGHT
                    
                    -- Create stat rows for equipment types
                    for _, statName in ipairs(category.stats) do
                        if ValuateStatNames[statName] then
                            local rowYOffset = -row2ColumnHeights[col] - ROW_SPACING
                            local row = CreateStatRow(colFrame, statName, scale, rowYOffset)
                            
                            StatWeightRows[statName] = row
                            tinsert(StatWeightRows, row)
                            row2ColumnHeights[col] = row2ColumnHeights[col] + ROW_HEIGHT + ROW_SPACING
                        end
                    end
                end
            end
            
            -- Find tallest column in row 2
            local row2MaxHeight = 0
            for i = 1, 4 do
                if row2ColumnHeights[i] > row2MaxHeight then
                    row2MaxHeight = row2ColumnHeights[i]
                end
            end
            
            -- Set row 2 column heights
            for i = 1, 4 do
                row2ColumnFrames[i]:SetHeight(row2MaxHeight)
            end
            
            -- Total height includes both rows
            coreMaxHeight = row2StartY + row2MaxHeight
        else
            -- Total height includes only row 1
            coreMaxHeight = equipStartY + equipMaxHeight
        end
    end
    
    -- Update content frame height (no scrolling needed)
    if ScaleEditorFrame then
        ScaleEditorFrame:SetHeight(math.max(coreMaxHeight, 100))
        
        -- Resize main window to fit content
        if ValuateUIFrame then
            -- Calculate needed window height:
            -- Title bar (40) + Tab bar (30) + Scale editor header (40) + Element spacing (8) + Content (coreMaxHeight) + Bottom padding (PADDING)
            local neededHeight = 40 + 30 + 40 + ELEMENT_SPACING + coreMaxHeight + PADDING
            local windowHeight = math.max(MIN_WINDOW_HEIGHT, math.min(MAX_WINDOW_HEIGHT, neededHeight))
            ValuateUIFrame:SetHeight(windowHeight)
        end
    end
end

function ValuateUI_UpdateScaleEditor(scaleName, scale)
    EditingScaleName = scaleName
    
    if not ScaleEditorFrame then return end
    
    -- Show the editor container
    if ScaleEditorFrame.container then
        ScaleEditorFrame.container:Show()
    end
    
    -- Update name field
    if ScaleEditorFrame.nameEditBox then
        ScaleEditorFrame.nameEditBox:SetText(scale.DisplayName or scaleName)
    end
    
    
    -- Update stat weights
    UpdateStatWeightsList(scaleName, scale)
end

-- ========================================
-- Template Scale Creation
-- ========================================

-- Creates a scale from a template
-- template: The template data (from CLASS_SPEC_TEMPLATES)
-- Returns: scaleName if successful, nil if cancelled
function ValuateUI_CreateScaleFromTemplate(template)
    local scaleName = template.name
    
    -- Check if scale already exists
    if ValuateScales[scaleName] then
        -- Define the overwrite dialog dynamically with access to local scope
        StaticPopupDialogs["VALUATE_TEMPLATE_OVERWRITE"] = {
            text = "A scale named \"" .. scaleName .. "\" already exists.\n\nOverwrite it?",
            button1 = "Overwrite",
            button2 = "Cancel",
            OnAccept = function()
                if ValuateUI_OnTemplateOverwrite then
                    ValuateUI_OnTemplateOverwrite(template)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("VALUATE_TEMPLATE_OVERWRITE")
        return nil
    end
    
    -- Create the scale
    local newScale = {
        DisplayName = scaleName,
        Color = template.color or "FFFFFF",  -- Use spec's color
        Visible = true,
        Icon = template.icon,
        Values = {},
        Unusable = {}
    }
    
    -- Copy stat weights from template
    if template.weights then
        for statName, value in pairs(template.weights) do
            newScale.Values[statName] = value
        end
    end
    
    -- Copy unusable stats from template
    if template.unusable then
        for statName, value in pairs(template.unusable) do
            newScale.Unusable[statName] = value
        end
    end
    
    ValuateScales[scaleName] = newScale
    
    -- Refresh list and select new scale
    UpdateScaleList()
    if ScaleListButtons[scaleName] then
        ScaleListButtons[scaleName]:GetScript("OnClick")(ScaleListButtons[scaleName])
    end
    
    return scaleName
end

function ValuateUI_NewScale()
    local baseName = "New Scale"
    local name = baseName
    local counter = 1
    while ValuateScales[name] do
        name = baseName .. " " .. counter
        counter = counter + 1
    end
    
    local newScale = {
        DisplayName = name,
        Color = "FFFFFF",
        Visible = true,
        Values = {}
    }
    
    ValuateScales[name] = newScale
    
    -- Refresh list and select new scale
    UpdateScaleList()
    if ScaleListButtons[name] then
        ScaleListButtons[name]:GetScript("OnClick")(ScaleListButtons[name])
    end
end

-- ========================================
-- Import/Export Dialog
-- ========================================

local ValuateImportExportDialog = nil

-- Creates the import/export dialog (reusable for both import and export)
local function CreateImportExportDialog()
    if ValuateImportExportDialog then
        return ValuateImportExportDialog
    end
    
    -- Main dialog frame
    local dialog = CreateFrame("Frame", "ValuateImportExportDialog", UIParent)
    dialog:SetWidth(600)
    dialog:SetHeight(300)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")  -- Above main UI
    dialog:SetBackdrop(BACKDROP_WINDOW)
    dialog:SetBackdropColor(unpack(COLORS.windowBg))
    dialog:SetBackdropBorderColor(unpack(COLORS.border))
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self)
        IsDraggingFrame = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    dialog:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        IsDraggingFrame = false
    end)
    dialog:Hide()
    
    -- Close on Escape
    table.insert(UISpecialFrames, "ValuateImportExportDialog")
    
    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", FONT_H1)
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    title:SetText("Import/Export")
    dialog.title = title
    
    -- Prompt text
    local prompt = dialog:CreateFontString(nil, "OVERLAY", FONT_BODY)
    prompt:SetPoint("TOP", title, "BOTTOM", 0, -10)
    prompt:SetWidth(560)
    prompt:SetJustifyH("LEFT")
    prompt:SetText("Prompt text")
    dialog.prompt = prompt
    
    -- Scroll frame for text box
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOP", prompt, "BOTTOM", 0, -10)
    scrollFrame:SetPoint("LEFT", dialog, "LEFT", 20, 0)
    scrollFrame:SetPoint("RIGHT", dialog, "RIGHT", -40, 0)
    scrollFrame:SetHeight(150)
    
    -- Multi-line EditBox
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)  -- No limit
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(_G[FONT_BODY])
    editBox:SetWidth(540)
    editBox:SetHeight(150)
    editBox:SetScript("OnEscapePressed", function(self)
        dialog:Hide()
    end)
    editBox:SetScript("OnTextChanged", function(self)
        -- Auto-size height based on content
        local text = self:GetText() or ""
        local numLines = 1
        for _ in string.gmatch(text, "\n") do
            numLines = numLines + 1
        end
        local height = math.max(150, numLines * 14)
        self:SetHeight(height)
    end)
    
    scrollFrame:SetScrollChild(editBox)
    dialog.editBox = editBox
    dialog.scrollFrame = scrollFrame
    
    -- OK Button
    local okButton = CreateStyledButton(dialog, "OK", 100, BUTTON_HEIGHT)
    okButton:SetPoint("BOTTOM", dialog, "BOTTOM", -55, 15)
    okButton:SetScript("OnClick", function(self)
        if dialog.okCallback then
            dialog.okCallback(editBox:GetText())
        end
        dialog:Hide()
    end)
    dialog.okButton = okButton
    
    -- Cancel/Close Button
    local cancelButton = CreateStyledButton(dialog, "Cancel", 100, BUTTON_HEIGHT)
    cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", 55, 15)
    cancelButton:SetScript("OnClick", function(self)
        if dialog.cancelCallback then
            dialog.cancelCallback()
        end
        dialog:Hide()
    end)
    dialog.cancelButton = cancelButton
    
    ValuateImportExportDialog = dialog
    return dialog
end

-- Shows the export dialog with a scale tag
function Valuate:ShowExportDialog(scaleName)
    local scaleTag = self:GetScaleTag(scaleName)
    if not scaleTag then
        print("|cFFFF0000Valuate|r: Failed to generate export string for scale.")
        return
    end
    
    local dialog = CreateImportExportDialog()
    local scale = ValuateScales[scaleName]
    local displayName = scale and scale.DisplayName or scaleName
    
    dialog.title:SetText("Export Scale")
    dialog.prompt:SetText("Press Ctrl+C to copy the scale tag for |cFFFFFFFF" .. displayName .. "|r:")
    dialog.editBox:SetText(scaleTag)
    dialog.editBox:HighlightText()
    dialog.editBox:SetFocus()
    
    -- Only show Close button for export
    dialog.okButton:Hide()
    dialog.cancelButton:SetText("Close")
    dialog.cancelButton:ClearAllPoints()
    dialog.cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 15)
    
    dialog.okCallback = nil
    dialog.cancelCallback = nil
    
    dialog:Show()
end

-- Shows the import dialog for pasting a scale tag
function Valuate:ShowImportDialog()
    local dialog = CreateImportExportDialog()
    
    dialog.title:SetText("Import Scale")
    dialog.prompt:SetText("Press Ctrl+V to paste a scale tag:")
    dialog.editBox:SetText("")
    dialog.editBox:SetFocus()
    
    -- Show both OK and Cancel buttons
    dialog.okButton:Show()
    dialog.cancelButton:SetText("Cancel")
    dialog.cancelButton:ClearAllPoints()
    dialog.cancelButton:SetPoint("BOTTOM", dialog, "BOTTOM", 55, 15)
    
    dialog.okCallback = function(text)
        -- First check if scale exists (without overwriting)
        local status, scaleName, errorMessage = self:ImportScale(text, false)
        
        if status == Valuate.ImportResult.ALREADY_EXISTS then
            -- Scale already exists, show confirmation dialog
            StaticPopupDialogs["VALUATE_IMPORT_OVERWRITE"] = {
                text = "A scale named \"" .. scaleName .. "\" already exists.\n\nOverwrite it?",
                button1 = "Overwrite",
                button2 = "Cancel",
                OnAccept = function()
                    -- User confirmed, now import with overwrite
                    local overwriteStatus, overwriteScaleName = self:ImportScale(text, true)
                    
                    if overwriteStatus == Valuate.ImportResult.SUCCESS then
                        print("|cFF00FF00Valuate|r: Successfully overwrote scale |cFFFFFFFF" .. overwriteScaleName .. "|r")
                        
                        -- Refresh the UI
                        if ValuateUIFrame and ValuateUIFrame:IsShown() then
                            UpdateScaleList()
                            if ScaleListButtons[overwriteScaleName] then
                                ScaleListButtons[overwriteScaleName]:GetScript("OnClick")(ScaleListButtons[overwriteScaleName])
                            end
                        end
                    end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("VALUATE_IMPORT_OVERWRITE")
            return
        end
        
        if status == Valuate.ImportResult.SUCCESS then
            print("|cFF00FF00Valuate|r: Successfully imported scale |cFFFFFFFF" .. scaleName .. "|r")
            
            -- Refresh the UI if it's open
            if ValuateUIFrame and ValuateUIFrame:IsShown() then
                UpdateScaleList()
                -- Select the imported scale
                if ScaleListButtons[scaleName] then
                    ScaleListButtons[scaleName]:GetScript("OnClick")(ScaleListButtons[scaleName])
                end
            end
        elseif status == Valuate.ImportResult.VERSION_ERROR then
            print("|cFFFF0000Valuate|r: Import failed: Scale tag is from a newer version of Valuate. Please update the addon.")
        else
            print("|cFFFF0000Valuate|r: Import failed: Invalid scale tag format. Please check that you copied the entire tag.")
        end
    end
    
    dialog.cancelCallback = nil
    
    dialog:Show()
end

local function CreateScaleEditor(parent)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", SCALE_LIST_WIDTH + PADDING, 0)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    
    -- Header area (non-scrolling) for Scale Name - reduced height
    local headerFrame = CreateFrame("Frame", nil, container)
    headerFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    headerFrame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    headerFrame:SetHeight(40)
    
    -- Scale Name (single line header)
    local nameLabel = headerFrame:CreateFontString(nil, "OVERLAY", FONT_H1)
    nameLabel:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
    nameLabel:SetText("Scale Name:")
    
    local nameEditBox = CreateFrame("EditBox", nil, headerFrame)
    nameEditBox:SetHeight(22)
    nameEditBox:SetWidth(200)
    nameEditBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetFontObject(_G[FONT_BODY])
    nameEditBox:SetBackdrop(BACKDROP_INPUT)
    nameEditBox:SetBackdropColor(unpack(COLORS.inputBg))
    nameEditBox:SetBackdropBorderColor(unpack(COLORS.border))
    nameEditBox:SetTextInsets(6, 6, 0, 0)
    nameEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameEditBox:SetScript("OnEnterPressed", function(self)
        if not EditingScaleName or not ValuateScales[EditingScaleName] then
            self:ClearFocus()
            return
        end
        
        local newName = self:GetText()
        if newName and newName ~= "" then
            local scale = ValuateScales[EditingScaleName]
            scale.DisplayName = newName
            
            -- If the name changed, update the scale key
            if newName ~= EditingScaleName then
                ValuateScales[newName] = scale
                ValuateScales[EditingScaleName] = nil
                EditingScaleName = newName
                CurrentSelectedScale = newName
                UpdateScaleList()
            end
        end
        self:ClearFocus()
    end)
    
    -- Import button
    local importButton = CreateStyledButton(headerFrame, "Import", 80, 22)
    importButton:SetPoint("LEFT", nameEditBox, "RIGHT", 10, 0)
    importButton:SetScript("OnClick", function(self)
        Valuate:ShowImportDialog()
    end)
    importButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_TOP") then
        GameTooltip:SetText("Import Scale", 1, 1, 1)
        GameTooltip:AddLine("Import a scale from a scale tag.", nil, nil, nil, true)
        GameTooltip:Show()
        end
    end)
    importButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Export button
    local exportButton = CreateStyledButton(headerFrame, "Export", 80, 22)
    exportButton:SetPoint("LEFT", importButton, "RIGHT", ELEMENT_SPACING, 0)
    exportButton:SetScript("OnClick", function(self)
        if not EditingScaleName or not ValuateScales[EditingScaleName] then
            return
        end
        Valuate:ShowExportDialog(EditingScaleName)
    end)
    exportButton:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_TOP") then
        GameTooltip:SetText("Export Scale", 1, 1, 1)
        GameTooltip:AddLine("Export the current scale as a scale tag to share with others.", nil, nil, nil, true)
        GameTooltip:Show()
        end
    end)
    exportButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Reset button to clear all values (moved to the right)
    local resetButton = CreateStyledButton(headerFrame, "Reset Values", 90, 22)
    resetButton:SetPoint("LEFT", exportButton, "RIGHT", ELEMENT_SPACING, 0)
    resetButton:SetScript("OnClick", function(self)
        if not EditingScaleName or not ValuateScales[EditingScaleName] then
            return
        end
        
        local scaleName = EditingScaleName
        local scale = ValuateScales[scaleName]
        
        StaticPopupDialogs["VALUATE_RESET_SCALE"] = {
            text = "Are you sure you want to reset all values in the scale \"" .. (scale.DisplayName or scaleName) .. "\" to blank?",
            button1 = "Reset",
            button2 = "Cancel",
            OnAccept = function()
                -- Clear all values and unusable flags
                scale.Values = {}
                scale.Unusable = {}
                
                -- Refresh the editor display
                ValuateUI_UpdateScaleEditor(scaleName, scale)
                
                -- Reset all tooltips to reflect the change immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("VALUATE_RESET_SCALE")
    end)
    
    -- Content frame for stat weights (below header) - no scrollbar needed as everything fits
    local contentFrame = CreateFrame("Frame", nil, container)
    contentFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    contentFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, PADDING)
    contentFrame:SetBackdrop(BACKDROP_PANEL)
    contentFrame:SetBackdropColor(unpack(COLORS.panelBg))
    contentFrame:SetBackdropBorderColor(unpack(COLORS.borderDark))
    
    -- Store references
    ScaleEditorFrame = contentFrame
    ScaleEditorFrame.container = container
    ScaleEditorFrame.nameEditBox = nameEditBox
    
    
    container:Hide()
    return container
end

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
    
    local text7 = CreateBodyText("• Decimal Places: Control how many decimal places are shown in scores (0-4).\n• Right-Align Scores: When enabled, scores align to the right in tooltips for easier comparison.\n• Show Scale Value: Toggle whether the item's calculated score appears on tooltips.\n• Normalize Display: When enabled, all scores are normalized (highest stat weight = 1.0) for easier comparison across scales.\n• Comparison Mode: Choose how upgrade/downgrade differences are displayed (Number, Percentage, Both, or Off).", currentY)
    local text7Height = text7:GetStringHeight()
    currentY = currentY - text7Height - sectionSpacing
    
    -- Tips and Tricks
    local header8 = CreateSectionHeader("Tips and Tricks", currentY)
    currentY = currentY - lineHeight - paragraphSpacing
    
    local text8 = CreateBodyText("• Remember to press Enter after entering stat values - they won't save automatically!\n• Create multiple scales for different roles (e.g., 'DPS', 'Tank', 'Healer').\n• Use the visibility toggle to compare items for different builds without deleting scales.\n• Banned stats are useful for hybrid classes that can't use certain stats.\n• The scale name in the editor can be changed to rename the scale.", currentY)
    local text8Height = text8:GetStringHeight()
    currentY = currentY - text8Height - PADDING
    
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
        "• Customizable stat weight scales for different builds and roles\n" ..
        "• Real-time tooltip integration showing item scores\n" ..
        "• Multiple scale support with individual visibility toggles\n" ..
        "• Color-coded scale identification for quick recognition\n" ..
        "• Stat banning system for hybrid builds and class restrictions\n" ..
        "• Import/Export functionality for sharing scales\n" ..
        "• Support for Ascension-specific stats (PvE Power, PvP Power, etc.)\n" ..
        "• Character window integration for at-a-glance gear evaluation\n" ..
        "• Minimap button for quick access",
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
    
    -- Version 0.6.2 (Current)
    local v062Header = CreateVersionHeader("Version 0.6.2 (Current)", currentY)
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

-- ========================================
-- Settings Panel
-- ========================================

local function CreateSettingsPanel(parent)
    
    -- Safety check: ensure SavedVariables are initialized
    if not Valuate or not ValuateOptions or not ValuateScales then
        
        local errorText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        errorText:SetPoint("CENTER", parent, "CENTER", 0, 0)
        errorText:SetText("Settings not available. Please /reload to initialize.")
        errorText:SetTextColor(1, 0.5, 0.5, 1)
        return parent
    end
    
    -- Calculate column width for 3 columns
    -- Content area is WINDOW_WIDTH - (2 * PADDING) = 950 - 24 = 926
    local availableWidth = WINDOW_WIDTH - (2 * PADDING)
    local settingsColumnWidth = (availableWidth - (2 * COLUMN_GAP)) / 3
    
    
    -- Create 3 column frames directly in parent
    local columnFrames = {}
    local columnHeights = {0, 0, 0}
    
    for i = 1, 3 do
        local colFrame = CreateFrame("Frame", nil, parent)
        colFrame:SetWidth(settingsColumnWidth)
        colFrame:SetHeight(500)  -- FIX: Set explicit height
        colFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", PADDING + (i - 1) * (settingsColumnWidth + COLUMN_GAP), -PADDING)
        columnFrames[i] = colFrame
        columnHeights[i] = 0
    end
    
    -- Helper function to add element to column with spacing
    local function AddToColumn(colIndex, element, height)
        if colIndex < 1 or colIndex > 3 then return end
        local colFrame = columnFrames[colIndex]
        local yOffset = -columnHeights[colIndex]
        element:SetPoint("TOPLEFT", colFrame, "TOPLEFT", 0, yOffset)
        columnHeights[colIndex] = columnHeights[colIndex] + height + ELEMENT_SPACING
    end
    
    -- ========================================
    -- COLUMN 1: Display & Formatting
    -- ========================================
    local col1 = columnFrames[1]
    
    -- Display & Formatting Section Header
    local displayHeader = col1:CreateFontString(nil, "OVERLAY", FONT_H1)
    displayHeader:SetPoint("TOPLEFT", col1, "TOPLEFT", 0, 0)
    displayHeader:SetText("Display & Formatting")
    displayHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[1] = HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Decimal Places (Column 1)
    local decimalLabel = col1:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    decimalLabel:SetPoint("TOPLEFT", displayHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    decimalLabel:SetText("Decimal Places:")
    
    columnHeights[1] = columnHeights[1] + 14 + ELEMENT_SPACING
    
    local decimalEditBox = CreateFrame("EditBox", nil, col1)
    decimalEditBox:SetHeight(14)
    decimalEditBox:SetWidth(45)
    decimalEditBox:SetPoint("LEFT", decimalLabel, "RIGHT", 2, 0)
    decimalEditBox:SetAutoFocus(false)
    decimalEditBox:SetFontObject(_G[FONT_SMALL])
    decimalEditBox:SetJustifyH("CENTER")
    decimalEditBox:SetBackdrop(BACKDROP_INPUT)
    decimalEditBox:SetBackdropColor(unpack(COLORS.inputBg))
    decimalEditBox:SetBackdropBorderColor(unpack(COLORS.border))
    decimalEditBox:SetTextInsets(2, 2, 0, 0)
    decimalEditBox:SetText(tostring(ValuateOptions.decimalPlaces or 1))
    
    -- Apply whole number validation (digits only, no decimals or signs)
    ApplyWholeNumberValidation(decimalEditBox)
    
    decimalEditBox:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        local value = tonumber(text) or 1
        value = math.max(0, math.min(4, value))
        ValuateOptions.decimalPlaces = value
        self:SetText(tostring(value))
        self:ClearFocus()
        
        -- Reset all tooltips to show new decimal places immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    decimalEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(ValuateOptions.decimalPlaces or 1))
        self:ClearFocus()
    end)
    
    -- Right-Align Scores checkbox (Column 1)
    local alignCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    alignCheckbox:SetSize(24, 24)
    alignCheckbox:SetPoint("TOPLEFT", decimalLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local alignLabel = alignCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    alignLabel:SetPoint("LEFT", alignCheckbox, "RIGHT", 5, 0)
    alignLabel:SetText("Right-Align Scores")
    alignCheckbox:SetChecked(ValuateOptions.rightAlign == true)
    alignCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.rightAlign = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        -- Reset all tooltips to show new alignment immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Show Scale Value checkbox (Column 1) - moved from Column 2
    local showScaleCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    showScaleCheckbox:SetSize(24, 24)
    showScaleCheckbox:SetPoint("TOPLEFT", alignCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local showScaleLabel = showScaleCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    showScaleLabel:SetPoint("LEFT", showScaleCheckbox, "RIGHT", 5, 0)
    showScaleLabel:SetText("Show Scale Value")
    showScaleCheckbox:SetChecked(ValuateOptions.showScaleValue ~= false)
    showScaleCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.showScaleValue = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        -- Reset all tooltips to show/hide scale values immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    showScaleCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Show Scale Value", 1, 1, 1)
        GameTooltip:AddLine("Display the item's calculated scale score on tooltips.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    showScaleCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- Normalize Display checkbox (Column 1)
    local normalizeCheckbox = CreateFrame("CheckButton", nil, col1, "UICheckButtonTemplate")
    normalizeCheckbox:SetSize(24, 24)
    normalizeCheckbox:SetPoint("TOPLEFT", showScaleCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local normalizeLabel = normalizeCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    normalizeLabel:SetPoint("LEFT", normalizeCheckbox, "RIGHT", 5, 0)
    normalizeLabel:SetText("Normalize Display")
    normalizeCheckbox:SetChecked(ValuateOptions.normalizeDisplay == true)
    normalizeCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.normalizeDisplay = (self:GetChecked() == 1) or (self:GetChecked() == true)
        
        -- Reset all tooltips to show normalized/non-normalized values immediately
        if Valuate.ResetTooltips then
            Valuate:ResetTooltips()
        end
    end)
    normalizeCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
            GameTooltip:AddLine("Normalize Display", 1, 1, 1)
            GameTooltip:AddLine("When enabled, all scores are normalized so the highest stat weight = 1.0. This makes it easier to compare items across different scales. Your original stat weights are never changed.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    normalizeCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[1] = columnHeights[1] + 24 + ELEMENT_SPACING
    
    -- ========================================
    -- COLUMN 2: Upgrade Comparison & Interface
    -- ========================================
    local col2 = columnFrames[2]
    
    -- Upgrade Comparison Section Header (Column 2)
    local comparisonHeader = col2:CreateFontString(nil, "OVERLAY", FONT_H1)
    comparisonHeader:SetPoint("TOPLEFT", col2, "TOPLEFT", 0, 0)
    comparisonHeader:SetText("Upgrade Comparison")
    comparisonHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[2] = HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Comparison Mode dropdown (Column 2)
    local compModeLabel = col2:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    compModeLabel:SetPoint("TOPLEFT", comparisonHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    compModeLabel:SetText("Comparison Mode:")
    
    local comparisonModes = {
        { value = "number", text = "Number (+15.2)" },
        { value = "percent", text = "Percentage (+13.8% or +HUGE!)" },
        { value = "both", text = "Both (+15.2, +13.8% or +HUGE!)" },
        { value = "off", text = "Off" },
    }
    
    local compModeDropdown = CreateFrame("Frame", "ValuateComparisonModeDropdown", col2, "UIDropDownMenuTemplate")
    compModeDropdown:SetPoint("LEFT", compModeLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(compModeDropdown, 150)
    
    columnHeights[2] = columnHeights[2] + 32 + ELEMENT_SPACING
    
    local function GetCompModeText(value)
        for _, mode in ipairs(comparisonModes) do
            if mode.value == value then
                return mode.text
            end
        end
        return "Number (+15.2)"
    end
    
    -- Set initial text
    UIDropDownMenu_SetText(compModeDropdown, GetCompModeText(ValuateOptions.comparisonMode or "number"))
    
    -- Dropdown initialization function
    UIDropDownMenu_Initialize(compModeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(comparisonModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (ValuateOptions.comparisonMode or "number") == mode.value
            info.func = function(self)
                ValuateOptions.comparisonMode = self.value
                UIDropDownMenu_SetText(compModeDropdown, GetCompModeText(self.value))
                
                -- Reset all tooltips to show new comparison mode immediately
                if Valuate.ResetTooltips then
                    Valuate:ResetTooltips()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    -- Tooltip for dropdown
    compModeDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Comparison Mode", 1, 1, 1)
        GameTooltip:AddLine("Choose how upgrade/downgrade differences are displayed.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Number: Shows the score difference (+15.2)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Percentage: Shows the percent change (+13.8%)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Both: Shows both number and percentage", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Off: Disables upgrade comparison", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Note: Percentages of 1000% or greater are displayed as", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("'HUGE!' to keep tooltips clean and readable.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
        end
    end)
    compModeDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Interface Section Header (Column 2)
    local interfaceHeader = col2:CreateFontString(nil, "OVERLAY", FONT_H1)
    interfaceHeader:SetPoint("TOPLEFT", compModeLabel, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    interfaceHeader:SetText("Interface")
    interfaceHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[2] = columnHeights[2] + (ELEMENT_SPACING * 3) + HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Show Minimap Button checkbox (Column 2) - moved from Column 3
    local minimapButtonCheckbox = CreateFrame("CheckButton", nil, col2, "UICheckButtonTemplate")
    minimapButtonCheckbox:SetSize(24, 24)
    minimapButtonCheckbox:SetPoint("TOPLEFT", interfaceHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local minimapButtonLabel = minimapButtonCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    minimapButtonLabel:SetPoint("LEFT", minimapButtonCheckbox, "RIGHT", 5, 0)
    minimapButtonLabel:SetText("Show Minimap Button")
    
    -- Default to enabled if not set
    if ValuateOptions.minimapButtonHidden == nil then
        ValuateOptions.minimapButtonHidden = false
    end
    minimapButtonCheckbox:SetChecked(not ValuateOptions.minimapButtonHidden)
    minimapButtonCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        ValuateOptions.minimapButtonHidden = not checked
        if Valuate.ToggleMinimapButton then
            if checked then
                Valuate:ShowMinimapButton()
            else
                Valuate:HideMinimapButton()
            end
        end
    end)
    minimapButtonCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Show Minimap Button", 1, 1, 1)
        GameTooltip:AddLine("Toggle the Valuate minimap button.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    minimapButtonCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[2] = columnHeights[2] + 24 + ELEMENT_SPACING
    
    -- ========================================
    -- COLUMN 3: Character Window, Keybindings, Advanced
    -- ========================================
    local col3 = columnFrames[3]
    
    -- Character Window Section Header
    local charWindowHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    charWindowHeader:SetPoint("TOPLEFT", col3, "TOPLEFT", 0, 0)
    charWindowHeader:SetText("Character Window")
    charWindowHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[3] = HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Enable Character Window Display checkbox
    local charWindowCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
    charWindowCheckbox:SetSize(24, 24)
    charWindowCheckbox:SetPoint("TOPLEFT", charWindowHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local charWindowLabel = charWindowCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    charWindowLabel:SetPoint("LEFT", charWindowCheckbox, "RIGHT", 5, 0)
    charWindowLabel:SetText("Show Scale Display")
    
    -- Default to enabled if not set
    if ValuateOptions.showCharacterWindowDisplay == nil then
        ValuateOptions.showCharacterWindowDisplay = true
    end
    charWindowCheckbox:SetChecked(ValuateOptions.showCharacterWindowDisplay)
    charWindowCheckbox:SetScript("OnClick", function(self)
        local checked = (self:GetChecked() == 1) or (self:GetChecked() == true)
        ValuateOptions.showCharacterWindowDisplay = checked
        Valuate:RefreshCharacterWindowVisibility()
    end)
    charWindowCheckbox:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Show Scale Display", 1, 1, 1)
        GameTooltip:AddLine("Toggle the scale value display on the character window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    charWindowCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- Display Mode dropdown (moved up from after keybindings)
    local charModeLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    charModeLabel:SetPoint("TOPLEFT", charWindowCheckbox, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    charModeLabel:SetText("Display Mode:")
    
    local charModeDropdown = CreateFrame("Frame", "ValuateCharWindowModeDropdown", col3, "UIDropDownMenuTemplate")
    charModeDropdown:SetPoint("LEFT", charModeLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(charModeDropdown, 100)
    
    columnHeights[3] = columnHeights[3] + 32 + ELEMENT_SPACING
    
    local displayModes = {
        { value = "total", text = "Total" },
        { value = "average", text = "Average" },
    }
    
    local function GetDisplayModeText(value)
        for _, mode in ipairs(displayModes) do
            if mode.value == value then
                return mode.text
            end
        end
        return "Total"
    end
    
    if not ValuateOptions.characterWindowDisplayMode then
        ValuateOptions.characterWindowDisplayMode = "total"
    end
    UIDropDownMenu_SetText(charModeDropdown, GetDisplayModeText(ValuateOptions.characterWindowDisplayMode))
    
    UIDropDownMenu_Initialize(charModeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(displayModes) do
            info.text = mode.text
            info.value = mode.value
            info.checked = (ValuateOptions.characterWindowDisplayMode == mode.value)
            info.func = function(self)
                ValuateOptions.characterWindowDisplayMode = self.value
                UIDropDownMenu_SetText(charModeDropdown, GetDisplayModeText(self.value))
                Valuate:RefreshCharacterWindowDisplay()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    charModeDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Display Mode", 1, 1, 1)
        GameTooltip:AddLine("Total: Sum of all equipped item scores", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Average: Average score per slot", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        end
    end)
    charModeDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Character Window Scale dropdown (moved up from after Display Mode)
    local charScaleLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    charScaleLabel:SetPoint("TOPLEFT", charModeLabel, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    charScaleLabel:SetText("Display Scale:")
    
    local charScaleDropdown = CreateFrame("Frame", "ValuateCharWindowScaleDropdown", col3, "UIDropDownMenuTemplate")
    charScaleDropdown:SetPoint("LEFT", charScaleLabel, "RIGHT", -5, -2)
    UIDropDownMenu_SetWidth(charScaleDropdown, 180)
    
    columnHeights[3] = columnHeights[3] + 32 + ELEMENT_SPACING
    
    local function GetCharScaleDisplayText(scaleName, includeIcon)
        if not scaleName or not ValuateScales or not ValuateScales[scaleName] then
            return "Select Scale"
        end
        local scale = ValuateScales[scaleName]
        local displayName = scale.DisplayName or scaleName
        local color = scale.Color or "FFFFFF"
        
        -- Build display text with optional icon
        local text = ""
        if includeIcon and scale.Icon and scale.Icon ~= "" then
            text = "|T" .. scale.Icon .. ":14:14:0:0|t "
        end
        text = text .. "|cFF" .. color .. displayName .. "|r"
        
        return text
    end
    
    UIDropDownMenu_SetText(charScaleDropdown, GetCharScaleDisplayText(ValuateOptions.characterWindowScale, true))
    
    UIDropDownMenu_Initialize(charScaleDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local scales = {}
        if ValuateScales then
            for name, scale in pairs(ValuateScales) do
                if scale.Values and (scale.Visible ~= false) then
                    tinsert(scales, { name = name, scale = scale })
                end
            end
        end
        table.sort(scales, function(a, b)
            return (a.scale.DisplayName or a.name) < (b.scale.DisplayName or b.name)
        end)
        for _, scaleData in ipairs(scales) do
            info.text = GetCharScaleDisplayText(scaleData.name, true)
            info.value = scaleData.name
            info.checked = (ValuateOptions.characterWindowScale == scaleData.name)
            info.func = function(self)
                ValuateOptions.characterWindowScale = self.value
                UIDropDownMenu_SetText(charScaleDropdown, GetCharScaleDisplayText(self.value, true))
                Valuate:RefreshCharacterWindowDisplay()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    charScaleDropdown:SetScript("OnEnter", function(self)
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Character Window Scale", 1, 1, 1)
        GameTooltip:AddLine("Select which scale to display on the character window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    charScaleDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- ========================================
    -- Keybindings Section
    -- ========================================
    local keybindHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    keybindHeader:SetPoint("TOPLEFT", charScaleLabel, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    keybindHeader:SetText("Keybindings")
    keybindHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[3] = columnHeights[3] + (ELEMENT_SPACING * 3) + HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Open Valuate UI Keybind Button
    local keybindLabel = col3:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    keybindLabel:SetPoint("TOPLEFT", keybindHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    keybindLabel:SetText("Toggle UI:")
    
    local keybindButton = CreateStyledButton(col3, "Not Bound", settingsColumnWidth - 75, 24)
    keybindButton:SetPoint("LEFT", keybindLabel, "RIGHT", 5, 0)
    keybindButton:EnableKeyboard(false)  -- Only enable when capturing
    keybindButton:EnableMouseWheel(true)
    
    -- State variables for keybind capture
    local isCapturingKeybind = false
    local capturedKeys = {}
    
    -- Function to get current keybind text
    local function GetKeybindText()
        local key1, key2 = GetBindingKey("VALUATE_TOGGLE_UI")
        if key1 then
            return key1
        else
            return "Not Bound"
        end
    end
    
    -- Function to format key name for display
    local function FormatKeyName(key)
        if not key then return "Not Bound" end
        -- Make it more readable
        key = key:gsub("CTRL%-", "Ctrl+")
        key = key:gsub("ALT%-", "Alt+")
        key = key:gsub("SHIFT%-", "Shift+")
        key = key:gsub("BUTTON", "Mouse")
        return key
    end
    
    -- Update button text
    keybindButton.label:SetText(FormatKeyName(GetKeybindText()))
    
    -- Start capturing keybind
    local function StartKeybindCapture()
        isCapturingKeybind = true
        capturedKeys = {}
        keybindButton.label:SetText("Press Key...")
        keybindButton:SetBackdropColor(0.2, 0.3, 0.5, 1)
        keybindButton:EnableKeyboard(true)  -- Enable keyboard capture
    end
    
    -- Stop capturing keybind
    local function StopKeybindCapture()
        isCapturingKeybind = false
        capturedKeys = {}
        keybindButton.label:SetText(FormatKeyName(GetKeybindText()))
        keybindButton:SetBackdropColor(unpack(COLORS.buttonBg))
        keybindButton:EnableKeyboard(false)  -- Disable keyboard capture
    end
    
    -- Set the keybind
    local function SetKeybind(key)
        if key and key ~= "" then
            local oldBinding = GetBindingAction(key)
            if oldBinding and oldBinding ~= "" and oldBinding ~= "VALUATE_TOGGLE_UI" then
                -- Warn about overwriting existing binding
                print("|cFFFFFF00Valuate|r: Key " .. FormatKeyName(key) .. " was bound to " .. oldBinding .. ", now bound to Valuate.")
            end
            
            -- Clear old bindings for VALUATE_TOGGLE_UI
            local key1, key2 = GetBindingKey("VALUATE_TOGGLE_UI")
            if key1 then SetBinding(key1) end
            if key2 then SetBinding(key2) end
            
            -- Set new binding
            SetBinding(key, "VALUATE_TOGGLE_UI")
            SaveBindings(GetCurrentBindingSet())
        end
        StopKeybindCapture()
    end
    
    -- Clear the keybind
    local function ClearKeybind()
        local key1, key2 = GetBindingKey("VALUATE_TOGGLE_UI")
        if key1 then SetBinding(key1) end
        if key2 then SetBinding(key2) end
        SaveBindings(GetCurrentBindingSet())
        keybindButton.label:SetText("Not Bound")
    end
    
    -- Button click handler
    keybindButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Right-click to clear
            ClearKeybind()
        elseif not isCapturingKeybind then
            -- Left-click to start capture
            StartKeybindCapture()
        end
    end)
    
    -- Capture key presses
    keybindButton:SetScript("OnKeyDown", function(self, key)
        if not isCapturingKeybind then return end
        
        -- Allow escape to cancel
        if key == "ESCAPE" then
            StopKeybindCapture()
            return
        end
        
        -- Ignore modifier keys by themselves (wait for actual key press)
        if key == "LSHIFT" or key == "RSHIFT" or 
           key == "LCTRL" or key == "RCTRL" or 
           key == "LALT" or key == "RALT" then
            return
        end
        
        -- Build modifier prefix
        local modifier = ""
        if IsShiftKeyDown() then modifier = modifier .. "SHIFT-" end
        if IsControlKeyDown() then modifier = modifier .. "CTRL-" end
        if IsAltKeyDown() then modifier = modifier .. "ALT-" end
        
        -- Construct full key binding
        local fullKey = modifier .. key
        SetKeybind(fullKey)
    end)
    
    -- Capture mouse clicks
    keybindButton:SetScript("OnMouseDown", function(self, button)
        if not isCapturingKeybind then return end
        if button == "LeftButton" or button == "RightButton" then return end
        
        -- Build modifier prefix
        local modifier = ""
        if IsShiftKeyDown() then modifier = modifier .. "SHIFT-" end
        if IsControlKeyDown() then modifier = modifier .. "CTRL-" end
        if IsAltKeyDown() then modifier = modifier .. "ALT-" end
        
        -- Construct mouse button binding
        local mouseKey = modifier .. string.upper(button)
        SetKeybind(mouseKey)
    end)
    
    keybindButton:SetScript("OnEnter", function(self)
        if not isCapturingKeybind then
            self:SetBackdropColor(unpack(COLORS.buttonHover))
            self:SetBackdropBorderColor(unpack(COLORS.borderLight))
        end
        if ShowTooltipSafe(self, "ANCHOR_RIGHT") then
        GameTooltip:AddLine("Toggle UI Keybind", 1, 1, 1)
        GameTooltip:AddLine("Left-click to set a new keybind.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click to clear the keybind.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        end
    end)
    
    keybindButton:SetScript("OnLeave", function(self)
        if not isCapturingKeybind then
            self:SetBackdropColor(unpack(COLORS.buttonBg))
            self:SetBackdropBorderColor(unpack(COLORS.border))
        end
        GameTooltip:Hide()
    end)
    
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- ========================================
    -- Advanced Section
    -- ========================================
    local advancedHeader = col3:CreateFontString(nil, "OVERLAY", FONT_H1)
    advancedHeader:SetPoint("TOPLEFT", keybindLabel, "BOTTOMLEFT", 0, -(ELEMENT_SPACING * 3))
    advancedHeader:SetText("Advanced")
    advancedHeader:SetTextColor(unpack(COLORS.textAccent))
    columnHeights[3] = columnHeights[3] + (ELEMENT_SPACING * 3) + HEADER_HEIGHT + ELEMENT_SPACING
    
    -- Debug Mode checkbox (moved from Column 2)
    local debugCheckbox = CreateFrame("CheckButton", nil, col3, "UICheckButtonTemplate")
    debugCheckbox:SetSize(24, 24)
    debugCheckbox:SetPoint("TOPLEFT", advancedHeader, "BOTTOMLEFT", 0, -ELEMENT_SPACING)
    
    local debugLabel = debugCheckbox:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    debugLabel:SetPoint("LEFT", debugCheckbox, "RIGHT", 5, 0)
    debugLabel:SetText("Debug Mode")
    debugCheckbox:SetChecked(ValuateOptions.debug == true)
    debugCheckbox:SetScript("OnClick", function(self)
        ValuateOptions.debug = (self:GetChecked() == 1) or (self:GetChecked() == true)
    end)
    columnHeights[3] = columnHeights[3] + 24 + ELEMENT_SPACING
    
    -- ========================================
    -- Delete Saved Variables Button (Bottom Right)
    -- ========================================
    local deleteButton = CreateStyledButton(parent, "Delete Saved Variables", 180, 30)
    deleteButton:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -PADDING, PADDING)
    
    -- Override border color to red
    deleteButton:SetBackdropBorderColor(0.8, 0, 0, 1)
    
    -- Custom hover effects for red border
    deleteButton:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonHover))
        self:SetBackdropBorderColor(1, 0.2, 0.2, 1)  -- Brighter red on hover
        if ShowTooltipSafe(self, "ANCHOR_TOP") then
            GameTooltip:AddLine("Delete Saved Variables", 1, 0.2, 0.2)
            GameTooltip:AddLine("Deletes all addon data including scales and settings.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("This action requires a UI reload.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    deleteButton:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.buttonBg))
        self:SetBackdropBorderColor(0.8, 0, 0, 1)  -- Back to red
        GameTooltip:Hide()
    end)
    
    -- Click handler with confirmation dialog
    deleteButton:SetScript("OnClick", function(self)
        StaticPopupDialogs["VALUATE_DELETE_SAVEDVARS"] = {
            text = "Are you sure you want to delete ALL Valuate saved data?\n\nThis will delete:\n- All scales\n- All settings\n- All options\n\nThis action cannot be undone!\n\nThe UI will reload after deletion.",
            button1 = "Delete Everything",
            button2 = "Cancel",
            OnAccept = function()
                -- Clear all saved variables
                ValuateOptions = nil
                ValuateScales = nil
                
                -- Reload UI to reinitialize with defaults
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("VALUATE_DELETE_SAVEDVARS")
    end)
    
    -- Store references for updating
    parent.charScaleDropdown = charScaleDropdown
    parent.GetCharScaleDisplayText = GetCharScaleDisplayText
    
    return parent
end

-- ========================================
-- Character Window Scale Display
-- ========================================

local CharacterWindowFrame = nil
local CharacterWindowIconTexture = nil
local CharacterWindowNameText = nil
local CharacterWindowScoreText = nil
local CharacterWindowInitialized = false
local CharacterWindowUpdating = false

-- Equipment slot IDs (standard WoW order, skipping shirt/tabard)
-- 1=Head, 2=Neck, 3=Shoulder, 4=Shirt, 5=Chest, 6=Waist, 7=Legs, 8=Feet
-- 9=Wrist, 10=Hands, 11=Ring1, 12=Ring2, 13=Trinket1, 14=Trinket2
-- 15=Back, 16=MainHand, 17=OffHand, 18=Ranged, 19=Tabard
local EquipmentSlots = {
    { slotId = 1, name = "Head" },
    { slotId = 2, name = "Neck" },
    { slotId = 3, name = "Shoulder" },
    { slotId = 15, name = "Back" },
    { slotId = 5, name = "Chest" },
    { slotId = 9, name = "Wrist" },
    { slotId = 10, name = "Hands" },
    { slotId = 6, name = "Waist" },
    { slotId = 7, name = "Legs" },
    { slotId = 8, name = "Feet" },
    { slotId = 11, name = "Ring 1" },
    { slotId = 12, name = "Ring 2" },
    { slotId = 13, name = "Trinket 1" },
    { slotId = 14, name = "Trinket 2" },
    { slotId = 16, name = "Main Hand" },
    { slotId = 17, name = "Off Hand" },
    { slotId = 18, name = "Ranged" },
}

-- Helper function to get the correct character frame (Ascension vs standard WoW)
local function GetCharacterFrame()
    -- Ascension uses AscensionCharacterFrame
    if AscensionCharacterFrame then
        return AscensionCharacterFrame
    end
    -- Fallback to standard WoW PaperDollFrame
    return PaperDollFrame
end

-- Empty slot icon
local EMPTY_SLOT_ICON = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

-- Get individual item scores for breakdown (includes empty slots)
local function GetEquippedItemsBreakdown(scale)
    local breakdown = {}
    local totalScore = 0
    local slotCount = #EquipmentSlots
    
    for _, slotInfo in ipairs(EquipmentSlots) do
        local slotId = slotInfo.slotId
        local itemLink = GetInventoryItemLink("player", slotId)
        
        if itemLink then
            local itemName, _, itemRarity = GetItemInfo(itemLink)
            local itemTexture = GetInventoryItemTexture("player", slotId)
            
            -- Get item score using SCALED stats (same as tooltips)
            -- This ensures character window breakdown matches tooltip values
            local score = Valuate:GetEquippedItemScoreBySlotId(slotId, scale)
            
            -- Get item quality color
            local r, g, b = 1, 1, 1
            if itemRarity then
                r, g, b = GetItemQualityColor(itemRarity)
            end
            
            totalScore = totalScore + score
            
            tinsert(breakdown, {
                slotName = slotInfo.name,
                itemName = itemName or "Unknown",
                itemTexture = itemTexture,
                score = score,
                isEmpty = false,
                r = r, g = g, b = b
            })
        else
            -- Empty slot - show slot name
            tinsert(breakdown, {
                slotName = slotInfo.name,
                itemName = slotInfo.name .. " (Empty)",
                itemTexture = EMPTY_SLOT_ICON,
                score = 0,
                isEmpty = true,
                r = 0.5, g = 0.5, b = 0.5  -- Gray for empty
            })
        end
    end
    
    return breakdown, totalScore, slotCount
end

-- Show breakdown tooltip
local function ShowBreakdownTooltip(self)
    if IsDraggingFrame then return end  -- Skip if dragging
    
    local selectedScaleName = ValuateOptions.characterWindowScale
    if not selectedScaleName or not ValuateScales or not ValuateScales[selectedScaleName] then
        return
    end
    
    local scale = ValuateScales[selectedScaleName]
    if not scale then return end
    
    local color = scale.Color or "FFFFFF"
    local r, g, b = HexToRGB(color)
    local displayName = scale.DisplayName or selectedScaleName
    
    -- Get breakdown
    local breakdown, totalScore, slotCount = GetEquippedItemsBreakdown(scale)
    
    -- Create custom tooltip
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 0)
    GameTooltip:ClearLines()
    
    -- Icon sizes (30% bigger: 12 -> 16, 14 -> 18)
    local itemIconSize = 16
    local headerIconSize = 18
    
    -- Header with scale name and icon
    if scale.Icon and scale.Icon ~= "" then
        GameTooltip:AddLine("|T" .. scale.Icon .. ":" .. headerIconSize .. ":" .. headerIconSize .. ":0:0|t " .. displayName .. " Breakdown", r, g, b)
    else
        GameTooltip:AddLine(displayName .. " Breakdown", r, g, b)
    end
    GameTooltip:AddLine(" ")
    
    -- Format settings
    local decimals = ValuateOptions.decimalPlaces or 1
    local formatStr = "%." .. decimals .. "f"
    
    -- Add each item with larger icons
    for _, item in ipairs(breakdown) do
        local scoreText = string.format(formatStr, item.score)
        -- Icon + item name on left, score on right (larger icon)
        local iconPath = item.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
        local leftText = "|T" .. iconPath .. ":" .. itemIconSize .. ":" .. itemIconSize .. ":0:0|t "
        local itemColor = string.format("|cFF%02X%02X%02X", item.r * 255, item.g * 255, item.b * 255)
        leftText = leftText .. itemColor .. item.itemName .. "|r"
        
        -- Dim the score for empty slots or zero values
        local scoreColor = color
        if item.isEmpty then
            scoreColor = "666666"  -- Gray for empty
        elseif item.score == 0 then
            scoreColor = "999999"  -- Slightly less gray for zero
        end
        
        GameTooltip:AddDoubleLine(leftText, "|cFF" .. scoreColor .. scoreText .. "|r", 1, 1, 1, r, g, b)
    end
    
    -- Separator and totals (always show both)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("───────────────────────────────", 0.3, 0.3, 0.3)
    
    local totalText = string.format(formatStr, totalScore)
    local avgScore = slotCount > 0 and (totalScore / slotCount) or 0
    local avgText = string.format(formatStr, avgScore)
    
    GameTooltip:AddDoubleLine("Total", "|cFF" .. color .. totalText .. "|r", 1, 1, 1, r, g, b)
    GameTooltip:AddDoubleLine("Average", "|cFF" .. color .. avgText .. "|r", 1, 1, 1, r, g, b)
    
    GameTooltip:Show()
end

-- Hide breakdown tooltip  
local function HideBreakdownTooltip()
    GameTooltip:Hide()
end

-- Update the character window display
local function UpdateCharacterWindowDisplay()
    if CharacterWindowUpdating then
        return
    end
    
    if not CharacterWindowFrame then
        return
    end
    
    CharacterWindowUpdating = true
    
    -- Standardized padding values (must match frame creation)
    local PADDING_EDGE = 6
    local PADDING_ICON_TO_NAME = 4
    local PADDING_NAME_TO_VALUE = 8
    local ICON_SIZE = 14
    local MIN_WIDTH = 120
    
    -- Get selected scale from options
    local selectedScaleName = ValuateOptions.characterWindowScale
    if not selectedScaleName or not ValuateScales or not ValuateScales[selectedScaleName] then
        -- Try to use first active scale
        local activeScales = Valuate:GetActiveScales()
        if #activeScales > 0 then
            selectedScaleName = activeScales[1]
            ValuateOptions.characterWindowScale = selectedScaleName
        else
            -- No scales available - hide display
            if CharacterWindowIconTexture then CharacterWindowIconTexture:Hide() end
            if CharacterWindowNameText then CharacterWindowNameText:SetText("") end
            if CharacterWindowScoreText then CharacterWindowScoreText:SetText("--") end
            CharacterWindowUpdating = false
            return
        end
    end
    
    local scale = ValuateScales[selectedScaleName]
    if not scale then
        if CharacterWindowIconTexture then CharacterWindowIconTexture:Hide() end
        if CharacterWindowNameText then CharacterWindowNameText:SetText("") end
        if CharacterWindowScoreText then CharacterWindowScoreText:SetText("--") end
        CharacterWindowUpdating = false
        return
    end
    
    local color = scale.Color or "FFFFFF"
    local hasIcon = false
    
    -- Update icon
    if CharacterWindowIconTexture then
        local icon = scale.Icon
        if icon and icon ~= "" then
            CharacterWindowIconTexture:SetTexture(icon)
            CharacterWindowIconTexture:Show()
            hasIcon = true
            -- Reposition name text next to icon with standardized padding
            if CharacterWindowNameText then
                CharacterWindowNameText:SetPoint("LEFT", CharacterWindowIconTexture:GetParent(), "RIGHT", PADDING_ICON_TO_NAME, 0)
            end
        else
            CharacterWindowIconTexture:Hide()
            hasIcon = false
            -- Reposition name text to start of container with standardized padding
            if CharacterWindowNameText then
                CharacterWindowNameText:SetPoint("LEFT", CharacterWindowFrame, "LEFT", PADDING_EDGE, 0)
            end
        end
    end
    
    -- Update scale name with color
    if CharacterWindowNameText then
        local displayName = scale.DisplayName or selectedScaleName
        CharacterWindowNameText:SetText("|cFF" .. color .. displayName .. "|r")
    end
    
    -- Calculate and update score
    if CharacterWindowScoreText then
        local totalScore = Valuate:CalculateTotalEquippedScore(scale)
        local decimals = ValuateOptions.decimalPlaces or 1
        local formatStr = "%." .. decimals .. "f"
        
        local displayMode = ValuateOptions.characterWindowDisplayMode or "total"
        local displayValue = totalScore
        
        if displayMode == "average" then
            -- Calculate average (total slots = 17, excluding shirt/tabard)
            local slotCount = #EquipmentSlots
            displayValue = slotCount > 0 and (totalScore / slotCount) or 0
        end
        
        local scoreText = string.format(formatStr, displayValue)
        CharacterWindowScoreText:SetText("|cFF" .. color .. scoreText .. "|r")
    end
    
    -- Calculate dynamic width based on content
    if CharacterWindowFrame and CharacterWindowNameText and CharacterWindowScoreText then
        local nameWidth = CharacterWindowNameText:GetStringWidth()
        local scoreWidth = CharacterWindowScoreText:GetStringWidth()
        
        -- Calculate total width: edge padding + optional icon + padding + name + padding + score + edge padding
        local totalWidth = PADDING_EDGE  -- Left edge
        if hasIcon then
            totalWidth = totalWidth + ICON_SIZE + PADDING_ICON_TO_NAME
        end
        totalWidth = totalWidth + nameWidth + PADDING_NAME_TO_VALUE + scoreWidth + PADDING_EDGE  -- Right edge
        
        -- Ensure minimum width and round up
        totalWidth = math.max(MIN_WIDTH, math.ceil(totalWidth))
        
        CharacterWindowFrame:SetWidth(totalWidth)
    end
    
    CharacterWindowUpdating = false
end

-- Public API to refresh character window display (called from Settings)
-- Export UpdateScaleList for use by ImportExport
function Valuate:RefreshScaleList()
    if UpdateScaleList then
        UpdateScaleList()
    end
end

-- Export ValuateUI_UpdateScaleEditor for use by ImportExport  
function Valuate:RefreshStatEditor()
    if EditingScaleName and ValuateScales[EditingScaleName] then
        ValuateUI_UpdateScaleEditor(EditingScaleName, ValuateScales[EditingScaleName])
    end
end

function Valuate:RefreshCharacterWindowDisplay()
    if CharacterWindowFrame then
        UpdateCharacterWindowDisplay()
    end
end

-- Public API to refresh character window scale dropdown in settings
function Valuate:RefreshCharacterWindowScaleDropdown()
    local dropdown = _G["ValuateCharWindowScaleDropdown"]
    if dropdown and ValuateOptions and ValuateOptions.characterWindowScale then
        -- Helper function to format display text (matches the one in settings creation)
        local function GetCharScaleDisplayText(scaleName, includeIcon)
            if not scaleName or not ValuateScales or not ValuateScales[scaleName] then
                return "Select Scale"
            end
            local scale = ValuateScales[scaleName]
            local displayName = scale.DisplayName or scaleName
            local color = scale.Color or "FFFFFF"
            
            -- Build display text with optional icon
            local text = ""
            if includeIcon and scale.Icon and scale.Icon ~= "" then
                text = "|T" .. scale.Icon .. ":14:14:0:0|t "
            end
            text = text .. "|cFF" .. color .. displayName .. "|r"
            
            return text
        end
        
        -- Update the dropdown text
        local newText = GetCharScaleDisplayText(ValuateOptions.characterWindowScale, true)
        UIDropDownMenu_SetText(dropdown, newText)
        
        -- Force update the button text (direct access to ensure visual update)
        local button = _G[dropdown:GetName() .. "Button"]
        if button then
            local buttonText = _G[dropdown:GetName() .. "Text"]
            if buttonText then
                buttonText:SetText(newText)
            end
        end
    end
end

-- Public API to refresh character window visibility (called from Settings toggle)
function Valuate:RefreshCharacterWindowVisibility()
    if not CharacterWindowFrame then return end
    
    local charFrame = GetCharacterFrame()
    if not charFrame then return end
    
    -- Check if feature is enabled
    if ValuateOptions.showCharacterWindowDisplay == false then
        CharacterWindowFrame:Hide()
    elseif charFrame:IsVisible() then
        CharacterWindowFrame:Show()
        UpdateCharacterWindowDisplay()
    end
end

-- Create character window UI elements
local function CreateCharacterWindowUI()
    if CharacterWindowInitialized then
        return
    end
    
    local charFrame = GetCharacterFrame()
    if not charFrame then
        return
    end
    
    CharacterWindowInitialized = true
    
    if ValuateOptions and ValuateOptions.debug then
        local frameName = charFrame:GetName() or "unknown"
        print("|cFF00FF00[Valuate]|r Creating character window UI on " .. frameName)
    end
    
    -- Create sleek container button - compact size (Button so it's clickable)
    local container = CreateFrame("Button", "ValuateCharacterWindowFrame", charFrame)
    container:SetWidth(200)  -- Initial width, will be adjusted dynamically
    container:SetHeight(22)
    container:SetFrameLevel(charFrame:GetFrameLevel() + 10)
    container:SetFrameStrata("HIGH")
    container:EnableMouse(true)  -- Enable mouse for tooltip and clicks
    container:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Sleek styled background
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = BORDER_TOOLTIP,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    container:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
    
    -- Click handler - left click opens UI, right click cycles scales
    container:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            -- Open Valuate UI
            if Valuate and Valuate.ToggleUI then
                Valuate:ToggleUI()
            else
                print("|cFFFF0000Valuate|r: UI not available. Please reload UI with /reload")
            end
        elseif btn == "RightButton" then
            -- Cycle through scales
            if not Valuate or not Valuate.GetActiveScales or not ValuateOptions or not ValuateScales then
                return
            end
            
            local activeScales = Valuate:GetActiveScales()
            if #activeScales == 0 then
                print("|cFFFF0000Valuate|r: No active scales available")
                return
            end
            
            -- Find current scale index
            local currentScale = ValuateOptions.characterWindowScale
            local currentIndex = 1
            for i, scaleName in ipairs(activeScales) do
                if scaleName == currentScale then
                    currentIndex = i
                    break
                end
            end
            
            -- Cycle to next scale (wrap around)
            local nextIndex = (currentIndex % #activeScales) + 1
            local nextScale = activeScales[nextIndex]
            
            -- Update the selected scale
            ValuateOptions.characterWindowScale = nextScale
            
            -- Show notification
            local scale = ValuateScales[nextScale]
            if scale then
                local color = scale.Color or "FFFFFF"
                local displayName = scale.DisplayName or nextScale
                print("|cFF00FF00Valuate|r: Switched to scale |cFF" .. color .. displayName .. "|r")
            end
            
            -- Refresh the display
            if Valuate.RefreshCharacterWindowDisplay then
                Valuate:RefreshCharacterWindowDisplay()
            end
            
            -- Refresh the dropdown in settings if it exists
            if Valuate.RefreshCharacterWindowScaleDropdown then
                Valuate:RefreshCharacterWindowScaleDropdown()
            end
            
            -- Refresh the tooltip if currently shown
            if GameTooltip:IsOwned(self) and GameTooltip:IsVisible() then
                ShowBreakdownTooltip(self)
                -- Re-add click hints
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Left-click to open Valuate UI", 0.7, 0.7, 0.7)
                
                -- Show next scale in cycle hint
                local nextScaleText = "Right-click to cycle scales"
                if Valuate and Valuate.GetActiveScales and ValuateOptions and ValuateScales then
                    local activeScales = Valuate:GetActiveScales()
                    if #activeScales > 0 then
                        local currentScale = ValuateOptions.characterWindowScale
                        local currentIndex = 1
                        for i, scaleName in ipairs(activeScales) do
                            if scaleName == currentScale then
                                currentIndex = i
                                break
                            end
                        end
                        local nextIndex = (currentIndex % #activeScales) + 1
                        local nextScaleName = activeScales[nextIndex]
                        local nextScale = ValuateScales[nextScaleName]
                        if nextScale then
                            local color = nextScale.Color or "FFFFFF"
                            local displayName = nextScale.DisplayName or nextScaleName
                            local icon = ""
                            if nextScale.Icon and nextScale.Icon ~= "" then
                                icon = "|T" .. nextScale.Icon .. ":14:14:0:0|t "
                            end
                            nextScaleText = nextScaleText .. ": " .. icon .. "|cFF" .. color .. displayName .. "|r"
                        end
                    end
                end
                GameTooltip:AddLine(nextScaleText, 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end
    end)
    
    -- Tooltip on hover - show item breakdown and click hint
    container:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)  -- Highlight border
        ShowBreakdownTooltip(self)
        -- Add click hints to tooltip (it's already shown by ShowBreakdownTooltip)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open Valuate UI", 0.7, 0.7, 0.7)
        
        -- Show next scale in cycle hint
        local nextScaleText = "Right-click to cycle scales"
        if Valuate and Valuate.GetActiveScales and ValuateOptions and ValuateScales then
            local activeScales = Valuate:GetActiveScales()
            if #activeScales > 0 then
                local currentScale = ValuateOptions.characterWindowScale
                local currentIndex = 1
                for i, scaleName in ipairs(activeScales) do
                    if scaleName == currentScale then
                        currentIndex = i
                        break
                    end
                end
                local nextIndex = (currentIndex % #activeScales) + 1
                local nextScaleName = activeScales[nextIndex]
                local nextScale = ValuateScales[nextScaleName]
                if nextScale then
                    local color = nextScale.Color or "FFFFFF"
                    local displayName = nextScale.DisplayName or nextScaleName
                    local icon = ""
                    if nextScale.Icon and nextScale.Icon ~= "" then
                        icon = "|T" .. nextScale.Icon .. ":14:14:0:0|t "
                    end
                    nextScaleText = nextScaleText .. ": " .. icon .. "|cFF" .. color .. displayName .. "|r"
                end
            end
        end
        GameTooltip:AddLine(nextScaleText, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    container:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)  -- Restore border
        HideBreakdownTooltip()
    end)
    
    -- Position centered at top of character model area
    if AscensionPaperDollPanelModel then
        container:SetPoint("TOP", AscensionPaperDollPanelModel, "TOP", 0, -5)
    elseif AscensionPaperDollPanel then
        container:SetPoint("TOP", AscensionPaperDollPanel, "TOP", 0, -35)
    else
        container:SetPoint("TOP", charFrame, "TOP", 0, -75)
    end
    
    container:Show()
    
    -- Standardized padding values
    local PADDING_EDGE = 6           -- Padding from container edges
    local PADDING_ICON_TO_NAME = 4   -- Spacing between icon and name
    local PADDING_NAME_TO_VALUE = 8  -- Spacing between name and value
    
    -- Scale icon (small, left side)
    local iconFrame = CreateFrame("Frame", nil, container)
    iconFrame:SetSize(14, 14)
    iconFrame:SetPoint("LEFT", container, "LEFT", PADDING_EDGE, 0)
    
    local iconTexture = iconFrame:CreateTexture(nil, "OVERLAY")
    iconTexture:SetAllPoints(iconFrame)
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconTexture:Hide()
    
    -- Scale name (small, colored)
    local nameText = container:CreateFontString(nil, "OVERLAY", FONT_SMALL)
    nameText:SetPoint("LEFT", container, "LEFT", PADDING_EDGE, 0)
    nameText:SetJustifyH("LEFT")
    
    -- Score display (right side)
    local scoreText = container:CreateFontString(nil, "OVERLAY", FONT_BODY)
    scoreText:SetPoint("RIGHT", container, "RIGHT", -PADDING_EDGE, 0)
    scoreText:SetJustifyH("RIGHT")
    scoreText:SetText("--")
    
    -- Store references
    CharacterWindowFrame = container
    CharacterWindowIconTexture = iconTexture
    CharacterWindowNameText = nameText
    CharacterWindowScoreText = scoreText
    
    -- Hook OnShow/OnHide of the character frame
    if not charFrame.valuateHooked then
        charFrame.valuateHooked = true
        charFrame:HookScript("OnShow", function()
            if CharacterWindowFrame and ValuateOptions then
                -- Only show if feature is enabled
                if ValuateOptions.showCharacterWindowDisplay ~= false then
                    CharacterWindowFrame:Show()
                    local updateFrame = CreateFrame("Frame")
                    updateFrame:SetScript("OnUpdate", function(self, elapsed)
                        self.elapsed = (self.elapsed or 0) + elapsed
                        if self.elapsed >= 0.1 then
                            UpdateCharacterWindowDisplay()
                            self:SetScript("OnUpdate", nil)
                        end
                    end)
                end
            end
        end)
        charFrame:HookScript("OnHide", function()
            if CharacterWindowFrame then
                CharacterWindowFrame:Hide()
            end
        end)
    end
    
    -- Initial update if already visible and feature enabled
    if ValuateOptions and charFrame:IsVisible() and ValuateOptions.showCharacterWindowDisplay ~= false then
        local initUpdateFrame = CreateFrame("Frame")
        initUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 0.3 then
                UpdateCharacterWindowDisplay()
                self:SetScript("OnUpdate", nil)
            end
        end)
    elseif ValuateOptions and ValuateOptions.showCharacterWindowDisplay == false then
        container:Hide()
    end
end

-- Create event frame for inventory changes (only created once)
local CharacterWindowEventFrame = CreateFrame("Frame")
local updateThrottleFrame = nil
CharacterWindowEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
CharacterWindowEventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_INVENTORY_CHANGED" and unit == "player" then
        local charFrame = GetCharacterFrame()
        if CharacterWindowInitialized and charFrame and charFrame:IsVisible() and CharacterWindowFrame then
            -- Throttle updates - only update after a short delay
            if not updateThrottleFrame then
                updateThrottleFrame = CreateFrame("Frame")
            end
            updateThrottleFrame:SetScript("OnUpdate", function(updateSelf, elapsed)
                updateSelf.elapsed = (updateSelf.elapsed or 0) + elapsed
                if updateSelf.elapsed >= 0.2 then
                    UpdateCharacterWindowDisplay()
                    updateSelf:SetScript("OnUpdate", nil)
                    updateSelf.elapsed = 0
                end
            end)
        end
    end
end)

-- Initialize when character frame becomes available
local function InitializeCharacterWindowUI()
    if CharacterWindowInitialized then
        return
    end
    
    local charFrame = GetCharacterFrame()
    if charFrame then
        CreateCharacterWindowUI()
        -- If character frame is already visible, update immediately
        if charFrame:IsVisible() then
            local updateFrame = CreateFrame("Frame")
            updateFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = (self.elapsed or 0) + elapsed
                if self.elapsed >= 0.3 then
                    if CharacterWindowFrame then
                        UpdateCharacterWindowDisplay()
                    end
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    else
        -- Wait for character UI to load
        local initFrame = CreateFrame("Frame")
        initFrame:RegisterEvent("ADDON_LOADED")
        initFrame:SetScript("OnEvent", function(self, event, addonName)
            -- Check for both Blizzard and Ascension character UI
            if addonName == "Blizzard_CharacterUI" or addonName == "Ascension_CharacterUI" then
                local cFrame = GetCharacterFrame()
                if cFrame and not CharacterWindowInitialized then
                    CreateCharacterWindowUI()
                    if cFrame:IsVisible() and CharacterWindowFrame then
                        UpdateCharacterWindowDisplay()
                    end
                end
                initFrame:UnregisterEvent("ADDON_LOADED")
            end
        end)
        
        -- Also try periodically in case event doesn't fire
        local retryFrame = CreateFrame("Frame")
        retryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = (self.elapsed or 0) + elapsed
            if self.elapsed >= 1 then
                local cFrame = GetCharacterFrame()
                if cFrame and not CharacterWindowInitialized then
                    CreateCharacterWindowUI()
                    if cFrame:IsVisible() and CharacterWindowFrame then
                        UpdateCharacterWindowDisplay()
                    end
                end
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- Create a simple initialization function that can be called from Valuate:Initialize
function Valuate:InitializeCharacterWindowUI()
    if ValuateOptions and ValuateOptions.debug then
        local charFrame = GetCharacterFrame()
        print("|cFF00FF00[Valuate]|r InitializeCharacterWindowUI called, initialized=" .. tostring(CharacterWindowInitialized) .. ", AscensionCharacterFrame=" .. tostring(AscensionCharacterFrame ~= nil) .. ", PaperDollFrame=" .. tostring(PaperDollFrame ~= nil))
    end
    if CharacterWindowInitialized then
        return
    end
    InitializeCharacterWindowUI()
end

-- Try to initialize immediately and also wait for character frame
local function TryInitialize()
    if CharacterWindowInitialized then
        return true
    end
    local charFrame = GetCharacterFrame()
    if charFrame then
        if ValuateOptions and ValuateOptions.debug then
            local frameName = charFrame:GetName() or "unknown"
            print("|cFF00FF00[Valuate]|r Character frame found (" .. frameName .. "), creating character window UI")
        end
        CreateCharacterWindowUI()
        return true
    end
    return false
end

-- Register for PLAYER_ENTERING_WORLD which fires after all frames are created
local charWindowEventFrame = CreateFrame("Frame")
charWindowEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
charWindowEventFrame:SetScript("OnEvent", function(self, event)
    local charFrame = GetCharacterFrame()
    if ValuateOptions and ValuateOptions.debug then
        print("|cFF00FF00[Valuate]|r PLAYER_ENTERING_WORLD fired, AscensionCharacterFrame=" .. tostring(AscensionCharacterFrame ~= nil) .. ", PaperDollFrame=" .. tostring(PaperDollFrame ~= nil))
    end
    if not CharacterWindowInitialized then
        if charFrame then
            CreateCharacterWindowUI()
        elseif ValuateOptions and ValuateOptions.debug then
            print("|cFFFF0000[Valuate]|r Character frame not found after PLAYER_ENTERING_WORLD!")
        end
    end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

-- Also try immediately in case we loaded late (but only if SavedVariables are ready)
local charFrameInit = GetCharacterFrame()
if charFrameInit and ValuateOptions then
    if ValuateOptions.debug then
        local frameName = charFrameInit:GetName() or "unknown"
        print("|cFF00FF00[Valuate]|r Character frame exists on file load (" .. frameName .. "), creating UI immediately")
    end
    TryInitialize()
end

-- ========================================
-- Public API
-- ========================================

function Valuate:ShowUI()
    local success, err = pcall(function()
        if not ValuateUIFrame then
            CreateMainWindow()
            
            -- Create tab system (tabs outside window, panels inside content)
            local tabs = CreateTabSystem(ValuateUIFrame, ValuateUIFrame.contentFrame)
            ValuateUIFrame.tabs = tabs
            
            -- Create scale list
            local scaleList = CreateScaleList(tabs.scalesPanel)
            
            -- Create scale editor
            local scaleEditor = CreateScaleEditor(tabs.scalesPanel)
            
            -- Create instructions panel
            local instructionsPanel = CreateInstructionsPanel(tabs.instructionsPanel)
            ValuateUIFrame.instructionsPanel = instructionsPanel
            
            -- Create about panel
            local aboutPanel = CreateAboutPanel(tabs.aboutPanel)
            ValuateUIFrame.aboutPanel = aboutPanel
            
            -- Create changelog panel
            local changelogPanel = CreateChangelogPanel(tabs.changelogPanel)
            ValuateUIFrame.changelogPanel = changelogPanel
            
            -- Create settings panel
            local settingsPanel = CreateSettingsPanel(tabs.settingsPanel)
            ValuateUIFrame.settingsPanel = settingsPanel
        end
        
        -- Update dynamic lists
        UpdateScaleList()
        
        ValuateUIFrame:Show()
    end)
    
    if not success then
        print("|cFFFF0000Valuate|r: Error opening UI: " .. tostring(err))
        print("|cFFFF0000Valuate|r: Please report this error and try /reload")
    end
end

function Valuate:HideUI()
    if ValuateUIFrame then
        ValuateUIFrame:Hide()
    end
end

function Valuate:ToggleUI()
    if not ValuateUIFrame then
        Valuate:ShowUI()
        return
    end
    
    if ValuateUIFrame:IsShown() then
        Valuate:HideUI()
    else
        Valuate:ShowUI()
    end
end

-- Verify UI loaded


