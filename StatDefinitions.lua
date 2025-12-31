-- StatDefinitions.lua
-- Regex patterns for parsing stats from tooltip text
-- These patterns match the text that appears in item tooltips

ValuateStatPatterns = {
    -- Primary Stats
    {"^%+?(%d+) Strength%.?$", "Strength"},
    {"^%+?(%d+) Agility%.?$", "Agility"},
    {"^%+?(%d+) Stamina%.?$", "Stamina"},
    {"^%+?(%d+) Intellect%.?$", "Intellect"},
    {"^%+?(%d+) Spirit%.?$", "Spirit"},
    
    -- Attack Power
    {"^Equip: Increases attack power by (%d+)%.?$", "AttackPower"},
    
    -- Ratings (these can appear as "Equip: Increases/Improves your X rating by Y")
    -- Lua patterns don't support alternation, so we need separate patterns for "Increases" and "Improves"
    {"^Equip: Increases your hit rating by (%d+)%.?$", "HitRating"},
    {"^Equip: Improves your hit rating by (%d+)%.?$", "HitRating"},
    {"^Equip: Increases your crit rating by (%d+)%.?$", "CritRating"},
    {"^Equip: Improves your crit rating by (%d+)%.?$", "CritRating"},
    {"^Equip: Increases your haste rating by (%d+)%.?$", "HasteRating"},
    {"^Equip: Improves your haste rating by (%d+)%.?$", "HasteRating"},
    {"^Equip: Increases your expertise rating by (%d+)%.?$", "ExpertiseRating"},
    {"^Equip: Improves your expertise rating by (%d+)%.?$", "ExpertiseRating"},
    {"^Equip: Increases your defense rating by (%d+)%.?$", "DefenseRating"},
    {"^Equip: Improves your defense rating by (%d+)%.?$", "DefenseRating"},
    {"^Equip: Increases your dodge rating by (%d+)%.?$", "DodgeRating"},
    {"^Equip: Improves your dodge rating by (%d+)%.?$", "DodgeRating"},
    {"^Equip: Increases your parry rating by (%d+)%.?$", "ParryRating"},
    {"^Equip: Improves your parry rating by (%d+)%.?$", "ParryRating"},
    {"^Equip: Increases your block rating by (%d+)%.?$", "BlockRating"},
    {"^Equip: Improves your block rating by (%d+)%.?$", "BlockRating"},
    {"^Equip: Increases your resilience rating by (%d+)%.?$", "ResilienceRating"},
    {"^Equip: Improves your resilience rating by (%d+)%.?$", "ResilienceRating"},
    
    -- Spell Power
    {"^Equip: Increases spell power by (%d+)%.?$", "SpellPower"},
    
    -- Armor
    {"^(%d+) Armor$", "Armor"},
    
    -- Weapon DPS
    {"^(%d+%.%d+) Damage Per Second$", "DPS"},
    
    -- Block Value
    {"^Equip: Increases the block value of your shield by (%d+)%.?$", "BlockValue"},
    
    -- Ascension Custom Stats (Critical!)
    {"^Equip: Increases PvE Power by (%d+)%.?$", "PVEPower"},
    {"^Equip: Increases PvP Power by (%d+)%.?$", "PVPPower"},
}

-- Stat display names (for UI purposes)
ValuateStatNames = {
    Strength = "Strength",
    Agility = "Agility",
    Stamina = "Stamina",
    Intellect = "Intellect",
    Spirit = "Spirit",
    AttackPower = "Attack Power",
    HitRating = "Hit Rating",
    CritRating = "Crit Rating",
    HasteRating = "Haste Rating",
    ExpertiseRating = "Expertise Rating",
    DefenseRating = "Defense Rating",
    DodgeRating = "Dodge Rating",
    ParryRating = "Parry Rating",
    BlockRating = "Block Rating",
    ResilienceRating = "Resilience Rating",
    SpellPower = "Spell Power",
    Armor = "Armor",
    DPS = "DPS",
    BlockValue = "Block Value",
    PVEPower = "PvE Power",
    PVPPower = "PvP Power",
}

