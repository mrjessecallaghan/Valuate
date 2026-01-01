-- StatDefinitions.lua
-- Regex patterns for parsing stats from tooltip text
-- These patterns match the text that appears in item tooltips

-- ========================================
-- Stat Categories for UI Organization
-- ========================================

ValuateStatCategories = {
    -- Column 1: Character
    {
        column = 1,
        header = "Primary",
        stats = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
    },
    {
        column = 1,
        header = "Hybrid Ratings",
        stats = { "HitRating", "CritRating", "HasteRating" }
    },
    {
        column = 1,
        header = "Ascension",
        stats = { "PVEPower", "PVPPower" }
    },
    {
        column = 1,
        header = "Item",
        stats = { "ItemLevel" }
    },
    
    -- Column 2: Physical
    {
        column = 2,
        header = "Physical Offense",
        stats = { "AttackPower", "RangedAP", "FeralAP", "ExpertiseRating", "ArmorPenetration" }
    },
    {
        column = 2,
        header = "Weapon DPS",
        stats = { "Dps", "MeleeDps", "RangedDps", "MainHandDps", "OffHandDps", "OneHandDps", "TwoHandDps" }
    },
    {
        column = 2,
        header = "Weapon Speed",
        stats = { "Speed", "MeleeSpeed", "RangedSpeed" }
    },
    
    -- Column 3: Spell
    {
        column = 3,
        header = "Spell",
        stats = { "SpellPower", "Mp5", "SpellPenetration" }
    },
    {
        column = 3,
        header = "School Power",
        stats = { "FireSpellPower", "ShadowSpellPower", "NatureSpellPower", "ArcaneSpellPower", "FrostSpellPower", "HolySpellPower" }
    },
    {
        column = 3,
        header = "Mana",
        stats = { "Mana" }
    },
    
    -- Column 4: Defense
    {
        column = 4,
        header = "Defensive",
        stats = { "Armor", "DefenseRating", "DodgeRating", "ParryRating", "BlockRating", "BlockValue" }
    },
    {
        column = 4,
        header = "Resistances",
        stats = { "ResilienceRating", "AllResist", "FireResist", "ShadowResist", "NatureResist", "ArcaneResist", "FrostResist" }
    },
    {
        column = 4,
        header = "Vitality",
        stats = { "Health", "Hp5" }
    },
}

-- Equipment Types (bottom section)
ValuateEquipmentCategories = {
    {
        column = 1,
        header = "Melee 1H",
        stats = { "IsDagger", "IsFist", "IsAxe", "IsMace", "IsSword" }
    },
    {
        column = 2,
        header = "Melee 2H",
        stats = { "IsStaff", "IsPolearm", "Is2HAxe", "Is2HMace", "Is2HSword" }
    },
    {
        column = 3,
        header = "Ranged",
        stats = { "IsBow", "IsCrossbow", "IsGun", "IsThrown", "IsWand" }
    },
    {
        column = 4,
        header = "Armor",
        stats = { "IsCloth", "IsLeather", "IsMail", "IsPlate", "IsShield" }
    },
}

-- ========================================
-- Tooltip Parsing Patterns
-- ========================================

ValuateStatPatterns = {
    -- ======== PRIMARY STATS ========
    {"^%+?(%d+) Strength%.?$", "Strength"},
    {"^%+?(%d+) Agility%.?$", "Agility"},
    {"^%+?(%d+) Stamina%.?$", "Stamina"},
    {"^%+?(%d+) Intellect%.?$", "Intellect"},
    {"^%+?(%d+) Spirit%.?$", "Spirit"},
    
    -- ======== HYBRID RATINGS ========
    {"^Equip: Increases your hit rating by (%d+)%.?$", "HitRating"},
    {"^Equip: Improves your hit rating by (%d+)%.?$", "HitRating"},
    {"^Equip: Increases your critical strike rating by (%d+)%.?$", "CritRating"},
    {"^Equip: Improves your critical strike rating by (%d+)%.?$", "CritRating"},
    {"^Equip: Increases your crit rating by (%d+)%.?$", "CritRating"},
    {"^Equip: Improves your crit rating by (%d+)%.?$", "CritRating"},
    {"^Equip: Increases your haste rating by (%d+)%.?$", "HasteRating"},
    {"^Equip: Improves your haste rating by (%d+)%.?$", "HasteRating"},
    
    -- ======== ASCENSION STATS ========
    {"^Equip: Increases PvE Power by (%d+)%.?$", "PVEPower"},
    {"^Equip: Increases PvP Power by (%d+)%.?$", "PVPPower"},
    
    -- ======== ITEM LEVEL ========
    -- Item level is parsed specially, not from a pattern
    
    -- ======== PHYSICAL OFFENSE ========
    {"^Equip: Increases attack power by (%d+)%.?$", "AttackPower"},
    {"^Equip: %+(%d+) Attack Power%.?$", "AttackPower"},
    {"^Equip: Increases ranged attack power by (%d+)%.?$", "RangedAP"},
    {"^Equip: %+(%d+) Ranged Attack Power%.?$", "RangedAP"},
    -- Feral AP is calculated from weapon DPS for druids (handled in code)
    {"^Equip: Increases your expertise rating by (%d+)%.?$", "ExpertiseRating"},
    {"^Equip: Improves your expertise rating by (%d+)%.?$", "ExpertiseRating"},
    {"^Equip: Increases your armor penetration rating by (%d+)%.?$", "ArmorPenetration"},
    {"^Equip: Improves your armor penetration rating by (%d+)%.?$", "ArmorPenetration"},
    
    -- ======== WEAPON DPS & SPEED ========
    -- Base DPS pattern (will be assigned to type-specific stats based on weapon slot)
    {"^(%d+%.?%d*) [Dd]amage [Pp]er [Ss]econd$", "Dps"},
    -- Speed pattern
    {"^Speed ([%d%.]+)$", "Speed"},
    
    -- ======== SPELL STATS ========
    {"^Equip: Increases spell power by (%d+)%.?$", "SpellPower"},
    {"^Equip: Restores (%d+) mana per 5 sec%.?$", "Mp5"},
    {"^Equip: Increases your spell penetration by (%d+)%.?$", "SpellPenetration"},
    
    -- ======== SCHOOL-SPECIFIC SPELL POWER ========
    {"^Equip: Increases damage done by Fire spells and effects by up to (%d+)%.?$", "FireSpellPower"},
    {"^Equip: Increases damage done by Shadow spells and effects by up to (%d+)%.?$", "ShadowSpellPower"},
    {"^Equip: Increases damage done by Nature spells and effects by up to (%d+)%.?$", "NatureSpellPower"},
    {"^Equip: Increases damage done by Arcane spells and effects by up to (%d+)%.?$", "ArcaneSpellPower"},
    {"^Equip: Increases damage done by Frost spells and effects by up to (%d+)%.?$", "FrostSpellPower"},
    {"^Equip: Increases damage done by Holy spells and effects by up to (%d+)%.?$", "HolySpellPower"},
    
    -- ======== MANA ========
    {"^Equip: Increases maximum mana by (%d+)%.?$", "Mana"},
    {"^%+(%d+) Mana$", "Mana"},
    
    -- ======== DEFENSIVE STATS ========
    {"^(%d+) Armor$", "Armor"},
    {"^Equip: Increases your defense rating by (%d+)%.?$", "DefenseRating"},
    {"^Equip: Improves your defense rating by (%d+)%.?$", "DefenseRating"},
    {"^Equip: Increases your dodge rating by (%d+)%.?$", "DodgeRating"},
    {"^Equip: Improves your dodge rating by (%d+)%.?$", "DodgeRating"},
    {"^Equip: Increases your parry rating by (%d+)%.?$", "ParryRating"},
    {"^Equip: Improves your parry rating by (%d+)%.?$", "ParryRating"},
    {"^Equip: Increases your block rating by (%d+)%.?$", "BlockRating"},
    {"^Equip: Improves your block rating by (%d+)%.?$", "BlockRating"},
    {"^Equip: Increases the block value of your shield by (%d+)%.?$", "BlockValue"},
    
    -- ======== RESISTANCES ========
    {"^Equip: Increases your resilience rating by (%d+)%.?$", "ResilienceRating"},
    {"^Equip: Improves your resilience rating by (%d+)%.?$", "ResilienceRating"},
    {"^%+(%d+) All Resistances$", "AllResist"},
    {"^%+(%d+) Fire Resistance$", "FireResist"},
    {"^%+(%d+) Shadow Resistance$", "ShadowResist"},
    {"^%+(%d+) Nature Resistance$", "NatureResist"},
    {"^%+(%d+) Arcane Resistance$", "ArcaneResist"},
    {"^%+(%d+) Frost Resistance$", "FrostResist"},
    
    -- ======== VITALITY ========
    {"^Equip: Increases maximum health by (%d+)%.?$", "Health"},
    {"^%+(%d+) Health$", "Health"},
    {"^Equip: Restores (%d+) health per 5 sec%.?$", "Hp5"},
}

-- Weapon slot type patterns (for assigning type-specific DPS/Speed)
ValuateWeaponSlotPatterns = {
    {"^Main Hand$", "IsMainHand"},
    {"^Off Hand$", "IsOffHand"},
    {"^One%-Hand$", "IsOneHand"},
    {"^Two%-Hand$", "IsTwoHand"},
    {"^Ranged$", "IsRanged"},
    {"^Thrown$", "IsRanged"},  -- Thrown counts as ranged
}

-- Weapon type patterns
ValuateWeaponTypePatterns = {
    {"^Dagger$", "IsDagger"},
    {"^Fist Weapon$", "IsFist"},
    {"^Axe$", "IsAxe"},
    {"^Mace$", "IsMace"},
    {"^Sword$", "IsSword"},
    {"^Staff$", "IsStaff"},
    {"^Polearm$", "IsPolearm"},
    {"^Bow$", "IsBow"},
    {"^Crossbow$", "IsCrossbow"},
    {"^Gun$", "IsGun"},
    {"^Thrown$", "IsThrown"},
    {"^Wand$", "IsWand"},
}

-- Armor type patterns
ValuateArmorTypePatterns = {
    {"^Cloth$", "IsCloth"},
    {"^Leather$", "IsLeather"},
    {"^Mail$", "IsMail"},
    {"^Plate$", "IsPlate"},
    {"^Shield$", "IsShield"},
}

-- ========================================
-- Stat Display Names (for UI)
-- ========================================

ValuateStatNames = {
    -- Column 1: Character
    Strength = "Strength",
    Agility = "Agility",
    Stamina = "Stamina",
    Intellect = "Intellect",
    Spirit = "Spirit",
    HitRating = "Hit Rating",
    CritRating = "Crit Rating",
    HasteRating = "Haste Rating",
    PVEPower = "PvE Power",
    PVPPower = "PvP Power",
    ItemLevel = "Item Level",
    
    -- Column 2: Physical
    AttackPower = "Attack Power",
    RangedAP = "Ranged AP",
    FeralAP = "Feral AP",
    ExpertiseRating = "Expertise",
    ArmorPenetration = "Armor Pen",
    Dps = "DPS",
    MeleeDps = "Melee DPS",
    RangedDps = "Ranged DPS",
    MainHandDps = "MH DPS",
    OffHandDps = "OH DPS",
    OneHandDps = "1H DPS",
    TwoHandDps = "2H DPS",
    Speed = "Speed",
    MeleeSpeed = "Melee Speed",
    RangedSpeed = "Ranged Speed",
    
    -- Column 3: Spell
    SpellPower = "Spell Power",
    Mp5 = "Mp5",
    SpellPenetration = "Spell Pen",
    FireSpellPower = "Fire SP",
    ShadowSpellPower = "Shadow SP",
    NatureSpellPower = "Nature SP",
    ArcaneSpellPower = "Arcane SP",
    FrostSpellPower = "Frost SP",
    HolySpellPower = "Holy SP",
    Mana = "Mana",
    
    -- Column 4: Defense
    Armor = "Armor",
    DefenseRating = "Defense",
    DodgeRating = "Dodge",
    ParryRating = "Parry",
    BlockRating = "Block Rating",
    BlockValue = "Block Value",
    ResilienceRating = "Resilience",
    AllResist = "All Resist",
    FireResist = "Fire Resist",
    ShadowResist = "Shadow Resist",
    NatureResist = "Nature Resist",
    ArcaneResist = "Arcane Resist",
    FrostResist = "Frost Resist",
    Health = "Health",
    Hp5 = "Hp5",
    
    -- Equipment Types - Melee 1H
    IsDagger = "Dagger",
    IsFist = "Fist",
    IsAxe = "Axe 1H",
    IsMace = "Mace 1H",
    IsSword = "Sword 1H",
    
    -- Equipment Types - Melee 2H
    IsStaff = "Staff",
    IsPolearm = "Polearm",
    Is2HAxe = "Axe 2H",
    Is2HMace = "Mace 2H",
    Is2HSword = "Sword 2H",
    
    -- Equipment Types - Ranged
    IsBow = "Bow",
    IsCrossbow = "Crossbow",
    IsGun = "Gun",
    IsThrown = "Thrown",
    IsWand = "Wand",
    
    -- Equipment Types - Armor
    IsCloth = "Cloth",
    IsLeather = "Leather",
    IsMail = "Mail",
    IsPlate = "Plate",
    IsShield = "Shield",
}
