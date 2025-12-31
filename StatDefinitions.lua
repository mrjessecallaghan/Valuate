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
    {"^Equip: (?:Increases|Improves) your hit rating by (%d+)%.?$", "HitRating"},
    {"^Equip: (?:Increases|Improves) your crit rating by (%d+)%.?$", "CritRating"},
    {"^Equip: (?:Increases|Improves) your haste rating by (%d+)%.?$", "HasteRating"},
    {"^Equip: (?:Increases|Improves) your expertise rating by (%d+)%.?$", "ExpertiseRating"},
    {"^Equip: (?:Increases|Improves) your defense rating by (%d+)%.?$", "DefenseRating"},
    {"^Equip: (?:Increases|Improves) your dodge rating by (%d+)%.?$", "DodgeRating"},
    {"^Equip: (?:Increases|Improves) your parry rating by (%d+)%.?$", "ParryRating"},
    {"^Equip: (?:Increases|Improves) your block rating by (%d+)%.?$", "BlockRating"},
    {"^Equip: (?:Increases|Improves) your resilience rating by (%d+)%.?$", "ResilienceRating"},
    
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

