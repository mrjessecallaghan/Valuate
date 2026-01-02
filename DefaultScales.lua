-- DefaultScales.lua
-- Default stat weights for WotLK classes and specs
-- Translated from Pawn addon's Wowhead scales

-- This table contains pre-configured stat weights for all WotLK class specializations
-- (excluding Death Knight). These weights are based on Pawn addon's curated scales
-- and have been translated to Valuate's stat naming conventions.

ValuateDefaultScales = {}

-- Helper function to create a default scale entry
local function CreateDefaultScale(displayName, color, icon, values, unusable)
    return {
        DisplayName = displayName,
        Color = color,
        Icon = icon,
        Values = values,
        Unusable = unusable,
        Visible = true
    }
end

------------------------------------------------------------
-- Warrior
------------------------------------------------------------

ValuateDefaultScales.Warrior = {
    {
        key = "WarriorArms",
        displayName = "Warrior Arms",
        color = "c41f3b",  -- Deep red (mortal strike, bleeding)
        icon = "Interface\\Icons\\Ability_Warrior_SavageBlow",
        values = {
            MeleeDps = 220,
            Strength = 100,
            HitRating = 95,
            ExpertiseRating = 90,
            CritRating = 75,
            ArmorPenetration = 70,
            HasteRating = 45,
            AttackPower = 40,
            Agility = 35,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "WarriorFury",
        displayName = "Warrior Fury",
        color = "ff4400",  -- Orange-red (rage, bloodthirst)
        icon = "Interface\\Icons\\Ability_Warrior_InnerRage",
        values = {
            MeleeDps = 240,
            Strength = 100,
            ExpertiseRating = 95,
            HitRating = 85,
            ArmorPenetration = 75,
            CritRating = 70,
            HasteRating = 50,
            AttackPower = 38,
            Agility = 30,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "WarriorTank",
        displayName = "Warrior Tank",
        color = "8c8c8c",  -- Steel gray (armor, defense)
        icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
        values = {
            Stamina = 100,
            DefenseRating = 90,
            DodgeRating = 85,
            BlockValue = 75,
            ParryRating = 70,
            Agility = 65,
            BlockRating = 50,
            Armor = 45,
            MeleeDps = 40,
            Strength = 40,
            ExpertiseRating = 35,
            HitRating = 30,
            AttackPower = 15,
            CritRating = 10,
            ArmorPenetration = 5,
            HasteRating = 3,
            Health = 10,
            Hp5 = 5,
            Intellect = 1,
            AllResist = 0.15,
            FireResist = 0.08,
            FrostResist = 0.08,
            ShadowResist = 0.08,
            NatureResist = 0.08,
            ArcaneResist = 0.08
        },
        unusable = {
            IsWand = true,
            IsPolearm = true,
            Is2HAxe = true,
            Is2HMace = true,
            Is2HSword = true,
            IsStaff = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Paladin
------------------------------------------------------------

ValuateDefaultScales.Paladin = {
    {
        key = "PaladinHoly",
        displayName = "Paladin Holy",
        color = "ffdd00",  -- Gold (holy light)
        icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
        values = {
            Intellect = 100,
            SpellPower = 90,
            HolySpellPower = 88,
            CritRating = 80,
            HasteRating = 75,
            Mp5 = 70,
            Spirit = 15,
            Stamina = 3,
            Armor = 0.3,
            Health = 0.3,
            Mana = 0.09,
            Hp5 = 0.05,
            AllResist = 0.08,
            FireResist = 0.03,
            FrostResist = 0.03,
            ShadowResist = 0.03,
            NatureResist = 0.03,
            ArcaneResist = 0.03
        },
        unusable = {
            IsDagger = true,
            IsFist = true,
            IsStaff = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsOffHand = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "PaladinRetribution",
        displayName = "Paladin Retribution",
        color = "ff3333",  -- Crimson (righteous fury)
        icon = "Interface\\Icons\\Spell_Holy_AuraOfLight",
        values = {
            MeleeDps = 200,
            Strength = 100,
            HitRating = 90,
            ExpertiseRating = 85,
            CritRating = 70,
            HasteRating = 60,
            ArmorPenetration = 50,
            AttackPower = 42,
            SpellPower = 20,
            HolySpellPower = 18,
            Agility = 25,
            Intellect = 8,
            Mana = 0.04,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsDagger = true,
            IsFist = true,
            IsStaff = true,
            IsShield = true,
            IsAxe = true,
            IsMace = true,
            IsSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsOffHand = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "PaladinTank",
        displayName = "Paladin Tank",
        color = "6699cc",  -- Silver-blue (divine shield)
        icon = "Interface\\Icons\\Ability_Paladin_ShieldofVengeance",
        values = {
            Stamina = 100,
            DefenseRating = 90,
            DodgeRating = 80,
            ParryRating = 75,
            BlockValue = 70,
            Armor = 65,
            BlockRating = 60,
            Agility = 55,
            Strength = 45,
            MeleeDps = 42,
            ExpertiseRating = 40,
            HitRating = 35,
            Intellect = 32,
            SpellPower = 20,
            HolySpellPower = 15,
            AttackPower = 15,
            CritRating = 10,
            HasteRating = 5,
            Health = 10,
            Hp5 = 5,
            Mana = 0.07,
            Mp5 = 3,
            AllResist = 0.15,
            FireResist = 0.08,
            FrostResist = 0.08,
            ShadowResist = 0.08,
            NatureResist = 0.08,
            ArcaneResist = 0.08
        },
        unusable = {
            IsDagger = true,
            IsFist = true,
            IsStaff = true,
            IsPolearm = true,
            Is2HAxe = true,
            Is2HMace = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsOffHand = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Hunter
------------------------------------------------------------

ValuateDefaultScales.Hunter = {
    {
        key = "HunterBeastMastery",
        displayName = "Hunter Beast Mastery",
        color = "a0522d",  -- Brown (beasts, animals)
        icon = "Interface\\Icons\\Ability_Hunter_BeastCall",
        values = {
            RangedDps = 190,
            Agility = 100,
            HitRating = 90,
            RangedAP = 60,
            AttackPower = 55,
            CritRating = 50,
            ArmorPenetration = 45,
            HasteRating = 35,
            Intellect = 30,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Hp5 = 0.01,
            Mp5 = 0.1,
            Mana = 0.03,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsShield = true,
            IsMace = true,
            Is2HMace = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "HunterMarksman",
        displayName = "Hunter Marksman",
        color = "4d7c2a",  -- Camo green (precision, sniper)
        icon = "Interface\\Icons\\Ability_Marksmanship",
        values = {
            RangedDps = 210,
            Agility = 100,
            HitRating = 95,
            ArmorPenetration = 75,
            CritRating = 70,
            RangedAP = 58,
            AttackPower = 50,
            HasteRating = 40,
            Intellect = 30,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Hp5 = 0.01,
            Mp5 = 0.1,
            Mana = 0.03,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsShield = true,
            IsMace = true,
            Is2HMace = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "HunterSurvival",
        displayName = "Hunter Survival",
        color = "cd853f",  -- Sandy brown (survival, traps)
        icon = "Interface\\Icons\\Ability_Hunter_LockAndLoad",
        values = {
            RangedDps = 195,
            Agility = 100,
            HitRating = 90,
            HasteRating = 65,
            RangedAP = 62,
            CritRating = 60,
            ArmorPenetration = 55,
            AttackPower = 55,
            Intellect = 30,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Hp5 = 0.01,
            Mp5 = 0.1,
            Mana = 0.03,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsShield = true,
            IsMace = true,
            Is2HMace = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Rogue
------------------------------------------------------------

ValuateDefaultScales.Rogue = {
    {
        key = "RogueAssassination",
        displayName = "Rogue Assassination",
        color = "9370db",  -- Purple (poison, venom)
        icon = "Interface\\Icons\\Ability_Rogue_DeadlyBrew",
        values = {
            MeleeDps = 210,
            Agility = 100,
            HitRating = 95,
            ExpertiseRating = 90,
            CritRating = 75,
            AttackPower = 70,
            HasteRating = 65,
            ArmorPenetration = 60,
            Strength = 50,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsShield = true,
            IsPolearm = true,
            IsStaff = true,
            Is2HAxe = true,
            Is2HMace = true,
            Is2HSword = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "RogueCombat",
        displayName = "Rogue Combat",
        color = "dc143c",  -- Crimson (bleeding, combat)
        icon = "Interface\\Icons\\Ability_BackStab",
        values = {
            MeleeDps = 230,
            Agility = 100,
            HitRating = 95,
            ExpertiseRating = 92,
            ArmorPenetration = 85,
            CritRating = 70,
            HasteRating = 68,
            AttackPower = 65,
            Strength = 48,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsShield = true,
            IsPolearm = true,
            IsStaff = true,
            Is2HAxe = true,
            Is2HMace = true,
            Is2HSword = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "RogueSubtlety",
        displayName = "Rogue Subtlety",
        color = "4169e1",  -- Royal blue (shadows, stealth)
        icon = "Interface\\Icons\\Ability_Stealth",
        values = {
            MeleeDps = 220,
            Agility = 100,
            HitRating = 92,
            ExpertiseRating = 88,
            CritRating = 78,
            ArmorPenetration = 72,
            HasteRating = 70,
            AttackPower = 68,
            Strength = 50,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsShield = true,
            IsPolearm = true,
            IsStaff = true,
            Is2HAxe = true,
            Is2HMace = true,
            Is2HSword = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Priest
------------------------------------------------------------

ValuateDefaultScales.Priest = {
    {
        key = "PriestDiscipline",
        displayName = "Priest Discipline",
        color = "87ceeb",  -- Sky blue (shields, barriers)
        icon = "Interface\\Icons\\Spell_Holy_PowerWordShield",
        values = {
            Intellect = 100,
            SpellPower = 95,
            HolySpellPower = 90,
            HasteRating = 80,
            CritRating = 75,
            Mp5 = 65,
            Spirit = 30,
            Stamina = 4,
            Armor = 0.4,
            Health = 0.4,
            Mana = 0.08,
            Hp5 = 0.1,
            AllResist = 0.08,
            FireResist = 0.03,
            FrostResist = 0.03,
            ShadowResist = 0.03,
            NatureResist = 0.03,
            ArcaneResist = 0.03
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsPolearm = true,
            IsSword = true,
            Is2HSword = true,
            Is2HMace = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "PriestHoly",
        displayName = "Priest Holy",
        color = "ffd700",  -- Gold (divine light)
        icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit",
        values = {
            Intellect = 100,
            SpellPower = 92,
            HolySpellPower = 88,
            Spirit = 75,
            CritRating = 70,
            HasteRating = 65,
            Mp5 = 60,
            Stamina = 4,
            Armor = 0.4,
            Health = 0.4,
            Mana = 0.08,
            Hp5 = 0.1,
            AllResist = 0.08,
            FireResist = 0.03,
            FrostResist = 0.03,
            ShadowResist = 0.03,
            NatureResist = 0.03,
            ArcaneResist = 0.03
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsPolearm = true,
            IsSword = true,
            Is2HSword = true,
            Is2HMace = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "PriestShadow",
        displayName = "Priest Shadow",
        color = "8b00ff",  -- Violet (shadow magic)
        icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
        values = {
            HitRating = 100,
            SpellPower = 90,
            ShadowSpellPower = 88,
            HasteRating = 75,
            CritRating = 70,
            Spirit = 65,
            Intellect = 60,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Mana = 0.05,
            Mp5 = 0.5,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsPolearm = true,
            IsSword = true,
            Is2HSword = true,
            Is2HMace = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Shaman
------------------------------------------------------------

ValuateDefaultScales.Shaman = {
    {
        key = "ShamanElemental",
        displayName = "Shaman Elemental",
        color = "4169e1",  -- Royal blue (lightning, storms)
        icon = "Interface\\Icons\\Spell_Nature_Lightning",
        values = {
            HitRating = 100,
            SpellPower = 85,
            NatureSpellPower = 35,
            HasteRating = 75,
            CritRating = 70,
            Intellect = 50,
            FireSpellPower = 10,
            Spirit = 10,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Mana = 0.05,
            Mp5 = 0.3,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsPolearm = true,
            IsSword = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsLibram = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "ShamanEnhancement",
        displayName = "Shaman Enhancement",
        color = "ff4500",  -- Orange-red (fire totems, lava)
        icon = "Interface\\Icons\\Spell_Shaman_ImprovedStormstrike",
        values = {
            MeleeDps = 180,
            Agility = 100,
            HitRating = 95,
            ExpertiseRating = 90,
            AttackPower = 75,
            CritRating = 70,
            HasteRating = 65,
            Intellect = 60,
            SpellPower = 55,
            NatureSpellPower = 25,
            Strength = 40,
            ArmorPenetration = 30,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Mp5 = 0.5,
            Mana = 0.05,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsPolearm = true,
            IsSword = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "ShamanRestoration",
        displayName = "Shaman Restoration",
        color = "20b2aa",  -- Teal (water, healing waves)
        icon = "Interface\\Icons\\Spell_Nature_MagicImmunity",
        values = {
            Intellect = 100,
            SpellPower = 90,
            NatureSpellPower = 40,
            Mp5 = 80,
            HasteRating = 75,
            CritRating = 70,
            Spirit = 20,
            Stamina = 4,
            Armor = 0.45,
            Health = 0.4,
            Mana = 0.08,
            Hp5 = 0.1,
            AllResist = 0.08,
            FireResist = 0.03,
            FrostResist = 0.03,
            ShadowResist = 0.03,
            NatureResist = 0.03,
            ArcaneResist = 0.03
        },
        unusable = {
            IsPlate = true,
            IsPolearm = true,
            IsSword = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsLibram = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Mage
------------------------------------------------------------

ValuateDefaultScales.Mage = {
    {
        key = "MageArcane",
        displayName = "Mage Arcane",
        color = "9932cc",  -- Purple (arcane magic)
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        values = {
            HitRating = 100,
            SpellPower = 90,
            ArcaneSpellPower = 88,
            HasteRating = 75,
            CritRating = 65,
            Intellect = 60,
            Spirit = 25,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Mana = 0.06,
            Mp5 = 0.4,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsMace = true,
            Is2HMace = true,
            IsPolearm = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "MageFire",
        displayName = "Mage Fire",
        color = "ff6600",  -- Orange-red (fire)
        icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
        values = {
            HitRating = 100,
            SpellPower = 90,
            FireSpellPower = 88,
            CritRating = 80,
            HasteRating = 75,
            Intellect = 55,
            Spirit = 15,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Mana = 0.06,
            Mp5 = 0.3,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsMace = true,
            Is2HMace = true,
            IsPolearm = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "MageFrost",
        displayName = "Mage Frost",
        color = "00bfff",  -- Deep sky blue (frost, ice)
        icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
        values = {
            HitRating = 100,
            SpellPower = 90,
            FrostSpellPower = 88,
            HasteRating = 75,
            CritRating = 70,
            Intellect = 55,
            Spirit = 20,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Mana = 0.06,
            Mp5 = 0.4,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsMace = true,
            Is2HMace = true,
            IsPolearm = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Warlock
------------------------------------------------------------

ValuateDefaultScales.Warlock = {
    {
        key = "WarlockAffliction",
        displayName = "Warlock Affliction",
        color = "32cd32",  -- Lime green (corruption, poison)
        icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",
        values = {
            HitRating = 100,
            SpellPower = 90,
            ShadowSpellPower = 88,
            HasteRating = 80,
            CritRating = 65,
            Spirit = 60,
            Intellect = 55,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Mana = 0.05,
            Mp5 = 0.4,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsMace = true,
            Is2HMace = true,
            IsPolearm = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "WarlockDemonology",
        displayName = "Warlock Demonology",
        color = "9370db",  -- Purple (fel magic, demons)
        icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
        values = {
            HitRating = 100,
            SpellPower = 90,
            ShadowSpellPower = 35,
            FireSpellPower = 35,
            HasteRating = 75,
            CritRating = 70,
            Spirit = 55,
            Intellect = 52,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Mana = 0.05,
            Mp5 = 0.4,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsMace = true,
            Is2HMace = true,
            IsPolearm = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    },
    {
        key = "WarlockDestruction",
        displayName = "Warlock Destruction",
        color = "ff8c00",  -- Dark orange (fire destruction)
        icon = "Interface\\Icons\\Spell_Shadow_RainOfFire",
        values = {
            HitRating = 100,
            SpellPower = 90,
            FireSpellPower = 88,
            ShadowSpellPower = 30,
            HasteRating = 78,
            CritRating = 75,
            Spirit = 50,
            Intellect = 48,
            Stamina = 0.15,
            Armor = 0.1,
            Health = 0.08,
            Mana = 0.05,
            Mp5 = 0.4,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsLeather = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsFist = true,
            IsMace = true,
            Is2HMace = true,
            IsPolearm = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsLibram = true,
            IsTotem = true,
            IsIdol = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Druid
------------------------------------------------------------

ValuateDefaultScales.Druid = {
    {
        key = "DruidBalance",
        displayName = "Druid Balance",
        color = "6a5acd",  -- Slate blue (moonkin, starfall)
        icon = "Interface\\Icons\\Spell_Nature_StarFall",
        values = {
            HitRating = 100,
            SpellPower = 90,
            NatureSpellPower = 88,
            ArcaneSpellPower = 85,
            HasteRating = 75,
            CritRating = 70,
            Spirit = 55,
            Intellect = 50,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Mana = 0.05,
            Mp5 = 0.5,
            Hp5 = 0.01,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsShield = true,
            Is2HAxe = true,
            Is2HSword = true,
            IsLibram = true,
            IsTotem = true,
            IsSigil = true
        }
    },
    {
        key = "DruidFeralDps",
        displayName = "Druid Feral DPS",
        color = "ffaa00",  -- Amber (cat form, energy)
        icon = "Interface\\Icons\\Ability_Druid_CatForm",
        values = {
            Agility = 100,
            Strength = 85,
            ArmorPenetration = 80,
            HitRating = 75,
            ExpertiseRating = 72,
            CritRating = 68,
            FeralAP = 60,
            HasteRating = 55,
            AttackPower = 45,
            Stamina = 0.15,
            Armor = 0.12,
            Health = 0.08,
            Hp5 = 0.01,
            Intellect = 5,
            Spirit = 1,
            Mana = 0.03,
            AllResist = 0.05,
            FireResist = 0.02,
            FrostResist = 0.02,
            ShadowResist = 0.02,
            NatureResist = 0.02,
            ArcaneResist = 0.02
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsSword = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsSigil = true
        }
    },
    {
        key = "DruidFeralTank",
        displayName = "Druid Feral Tank",
        color = "8b4513",  -- Saddle brown (bear form, earth)
        icon = "Interface\\Icons\\Ability_Racial_BearForm",
        values = {
            Stamina = 100,
            Agility = 95,
            Armor = 80,
            DodgeRating = 75,
            DefenseRating = 60,
            Strength = 50,
            ExpertiseRating = 45,
            HitRating = 40,
            FeralAP = 35,
            AttackPower = 30,
            CritRating = 25,
            HasteRating = 20,
            Health = 12,
            Hp5 = 6,
            Intellect = 5,
            Spirit = 2,
            Mana = 0.07,
            AllResist = 0.15,
            FireResist = 0.08,
            FrostResist = 0.08,
            ShadowResist = 0.08,
            NatureResist = 0.08,
            ArcaneResist = 0.08
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsSword = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsOffHand = true,
            IsLibram = true,
            IsTotem = true,
            IsSigil = true
        }
    },
    {
        key = "DruidRestoration",
        displayName = "Druid Restoration",
        color = "00cc66",  -- Spring green (nature healing)
        icon = "Interface\\Icons\\Spell_Nature_HealingTouch",
        values = {
            Intellect = 100,
            SpellPower = 90,
            NatureSpellPower = 88,
            Spirit = 85,
            HasteRating = 80,
            CritRating = 68,
            Mp5 = 65,
            Stamina = 4,
            Armor = 0.4,
            Health = 0.4,
            Mana = 0.08,
            Hp5 = 0.1,
            AllResist = 0.08,
            FireResist = 0.03,
            FrostResist = 0.03,
            ShadowResist = 0.03,
            NatureResist = 0.03,
            ArcaneResist = 0.03
        },
        unusable = {
            IsPlate = true,
            IsMail = true,
            IsShield = true,
            IsAxe = true,
            Is2HAxe = true,
            IsSword = true,
            Is2HSword = true,
            IsBow = true,
            IsCrossbow = true,
            IsGun = true,
            IsThrown = true,
            IsWand = true,
            IsLibram = true,
            IsTotem = true,
            IsSigil = true
        }
    }
}

------------------------------------------------------------
-- Helper function to get all default scales in a flat list
------------------------------------------------------------

function Valuate:GetAllDefaultScales()
    local allScales = {}
    
    -- Define class order for consistent display
    local classOrder = {
        "Warrior", "Paladin", "Hunter", "Rogue", 
        "Priest", "Shaman", "Mage", "Warlock", "Druid"
    }
    
    for _, className in ipairs(classOrder) do
        local classScales = ValuateDefaultScales[className]
        if classScales then
            for _, scaleData in ipairs(classScales) do
                tinsert(allScales, {
                    className = className,
                    key = scaleData.key,
                    displayName = scaleData.displayName,
                    color = scaleData.color,
                    icon = scaleData.icon,
                    values = scaleData.values,
                    unusable = scaleData.unusable
                })
            end
        end
    end
    
    return allScales
end

