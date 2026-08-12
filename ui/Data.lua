-- ui/Data.lua
-- Static reference data for the Valuate UI: the icon picker's texture list and the
-- class/spec scale templates.
--
-- Pure immutable data, so consumers re-localise it (`local SCALE_ICON_LIST =
-- ns.SCALE_ICON_LIST`) and every existing reference keeps working. Kept separate
-- because it is ~1,700 lines of content that would otherwise bury the actual UI logic.

local _, ns = ...

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
                    OffHandDps = true, MainHandDps = true, OneHandDps = true,
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
                    OffHandDps = true, TwoHandDps = true,
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
                    OffHandDps = true, TwoHandDps = true, RangedDps = true, RangedAP = true,
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
                    OffHandDps = true, TwoHandDps = true, RangedDps = true, RangedAP = true,
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
                -- Was "SUPPORT", which is not a role anything asks for. The wizard offers
                -- Tank, Healer and Damage, so Retribution could not be matched by role at
                -- all - a plate-and-Strength build asking for a damage scale would be given
                -- Arms or Fury and never the paladin spec it actually resembles.
                role = "DAMAGER",
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
                    OffHandDps = true, MainHandDps = true, OneHandDps = true, RangedDps = true,
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
                    TwoHandDps = true,
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
                    TwoHandDps = true,
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
                    TwoHandDps = true,
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
                    RangedDps = true,
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
                    RangedDps = true,
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
                    RangedDps = true,
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
                    RangedDps = true,
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
                    RangedDps = true,
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
                    RangedDps = true,
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
                    RangedDps = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true
                }
            }
        }
    },
    {
        class = "Death Knight",
        color = "C41F3B",
        description = "Fallen champions raised to serve, wielding runic power, disease and unholy strength.",
        specs = {
            {
                name = "Blood",
                icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
                color = "8B0000",  -- Dark red - the tanking presence
                role = "TANK",
                description = "Plate tank sustained by leeching strikes, converting damage taken into staying power.",
                weights = {
                    Stamina = 1.0, DefenseRating = 0.9, Strength = 0.55, DodgeRating = 0.5,
                    ParryRating = 0.45, ExpertiseRating = 0.4, HitRating = 0.35, Armor = 0.3,
                    Agility = 0.2, AttackPower = 0.2, CritRating = 0.2, ArmorPenetration = 0.1,
                    Health = 0.1, Hp5 = 0.05, HasteRating = 0.15,
                    TwoHandDps = 0.6, OneHandDps = 0.3, MainHandDps = 0.3,
                    IsSigil = 0.3, ResilienceRating = 0.05,
                    Intellect = 0.005, Spirit = 0.005, Mana = 0.005, Mp5 = 0.005,
                    SpellPower = 0.005, FireResist = 0.02, FrostResist = 0.02,
                    ShadowResist = 0.02, NatureResist = 0.02, ArcaneResist = 0.02,
                    AllResist = 0.02
                },
                unusable = {
                    -- Weapons (class cannot use)
                    IsDagger = true, IsFist = true, IsStaff = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Offhands (death knights have no shields)
                    IsFrill = true, IsShield = true,
                    -- Relics (sigils only)
                    IsTotem = true, IsLibram = true, IsIdol = true,
                    -- No ranged slot
                    RangedDps = true, RangedAP = true,
                    -- Feral Stats
                    FeralAP = true,
                    -- Block Stats (can't use shields)
                    BlockRating = true, BlockValue = true,
                    -- Off-school Spell Power
                    FireSpellPower = true, FrostSpellPower = true, ShadowSpellPower = true,
                    NatureSpellPower = true, ArcaneSpellPower = true, HolySpellPower = true
                }
            },
            {
                name = "Frost",
                icon = "Interface\\Icons\\Spell_Deathknight_FrostPresence",
                color = "5599FF",  -- Ice blue - the dual-wield killer
                role = "DAMAGER",
                description = "Dual-wielding or two-handed damage built on frost strikes and relentless hit chance.",
                weights = {
                    Strength = 1.0, HitRating = 0.95, ExpertiseRating = 0.75, CritRating = 0.6,
                    HasteRating = 0.55, ArmorPenetration = 0.5, AttackPower = 0.5,
                    Agility = 0.25, Stamina = 0.15, Armor = 0.05,
                    -- Frost is the one spec that genuinely runs either setup, so both weapon
                    -- configurations carry real weight rather than one being noise.
                    TwoHandDps = 0.7, OneHandDps = 0.55, MainHandDps = 0.55, OffHandDps = 0.45,
                    IsSigil = 0.3, ResilienceRating = 0.05,
                    Intellect = 0.005, Spirit = 0.005, Mana = 0.005, Mp5 = 0.005,
                    Hp5 = 0.005, Health = 0.005, SpellPower = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01
                },
                unusable = {
                    IsDagger = true, IsFist = true, IsStaff = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    IsFrill = true, IsShield = true,
                    IsTotem = true, IsLibram = true, IsIdol = true,
                    RangedDps = true, RangedAP = true,
                    FeralAP = true,
                    BlockRating = true, BlockValue = true,
                    FireSpellPower = true, FrostSpellPower = true, ShadowSpellPower = true,
                    NatureSpellPower = true, ArcaneSpellPower = true, HolySpellPower = true
                }
            },
            {
                name = "Unholy",
                icon = "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
                color = "6BAA3B",  -- Plague green - disease and the ghoul
                role = "DAMAGER",
                description = "Two-handed damage through spreading disease and a permanent risen ghoul.",
                weights = {
                    Strength = 1.0, HitRating = 0.9, HasteRating = 0.7, ExpertiseRating = 0.65,
                    ArmorPenetration = 0.6, CritRating = 0.55, AttackPower = 0.5,
                    Agility = 0.25, Stamina = 0.15, Armor = 0.05,
                    TwoHandDps = 0.75, IsSigil = 0.3, ResilienceRating = 0.05,
                    Intellect = 0.005, Spirit = 0.005, Mana = 0.005, Mp5 = 0.005,
                    Hp5 = 0.005, Health = 0.005, SpellPower = 0.005,
                    DefenseRating = 0.005, DodgeRating = 0.005, ParryRating = 0.005,
                    FireResist = 0.01, FrostResist = 0.01, ShadowResist = 0.01,
                    NatureResist = 0.01, ArcaneResist = 0.01, AllResist = 0.01
                },
                unusable = {
                    IsDagger = true, IsFist = true, IsStaff = true, IsWand = true,
                    IsBow = true, IsCrossbow = true, IsGun = true, IsThrown = true,
                    -- Two-handed spec: one-handers are not what this build wants
                    IsAxe = true, IsMace = true, IsSword = true,
                    IsFrill = true, IsShield = true,
                    IsTotem = true, IsLibram = true, IsIdol = true,
                    OffHandDps = true, MainHandDps = true, OneHandDps = true,
                    RangedDps = true, RangedAP = true,
                    FeralAP = true,
                    BlockRating = true, BlockValue = true,
                    FireSpellPower = true, FrostSpellPower = true, ShadowSpellPower = true,
                    NatureSpellPower = true, ArcaneSpellPower = true, HolySpellPower = true
                }
            }
        }
    }
}


-- ============================================================================
-- Conquest of Azeroth templates
-- ============================================================================
-- CoA is Ascension's class-based realm: 21 original classes and 69 specialisations that
-- share nothing with WotLK's. Kept in a SEPARATE table from CLASS_SPEC_TEMPLATES rather
-- than merged, because a classless player must never be offered "Stormbringer Lightning"
-- and a CoA player must never be offered "Arms Warrior" - neither class exists on the
-- other's realm.
--
-- Every priority below is transcribed from the per-class pages at
-- conquestofazerothwiki.wiki. Nothing here is invented; docs/coa-research.md records the
-- source for each and the contradictions found along the way.
--
-- THE CONVERSION. The source publishes ORDERED LISTS ("Strength > Attack Power > Hit >
-- Crit"), and Valuate scores with numbers. One uniform ladder is applied everywhere:
--
--     1st  1.00     3rd  0.55     unlisted-but-plausible  0.05
--     2nd  0.75     4th  0.40
--
-- A uniform rule is reproducible and honest about its own precision. Hand-tuning each spec
-- would invent detail the source does not contain, which is the failure this whole exercise
-- is trying to avoid.
--
-- DUAL PRIMARIES. Several specs publish two ("Strength/Agility", "Intellect or Agility").
-- Both are weighted 1.0. That scores a character carrying either one correctly, and only
-- over-values the rare character carrying both - whereas picking one would simply be wrong
-- for half the people playing that spec, and splitting into two templates would hand the
-- wizard two near-identical candidates that are always each other's runner-up.
local COA_CLASS_SPEC_TEMPLATES = {
    {
        class = "Son of Arugal",
        color = "6B4423",
        description = "Bearers of Arugal's curse, shifting between worgen fury and blood magic.",
        -- ALSO KNOWN AS "Bloodmage". The two names refer to one class, which is what made
        -- "Blood Mage" look like a 22nd class in the earlier source survey.
        --
        -- THE ONLY CLASS WITH NO PUBLISHED STAT PRIORITY. Its page 404s on the wiki that
        -- carries the other twenty, and no source found gives one. Every weight below is
        -- INFERRED from the published spec descriptions and the stated leather armour -
        -- Ferocity shreds in worgen form, Blood spends health on siphons, Packleader fights
        -- alongside summons, Fleshweaver heals through blood ritual.
        --
        -- Each spec is marked inferred = true, and tools/speccoverage.js reports the count,
        -- so this stays visible rather than ageing into something that looks transcribed.
        -- Correct it the moment a real priority turns up.
        specs = {
            {
                name = "Ferocity", icon = "Interface\\Icons\\Ability_Druid_Ferociousbite",
                color = "8B5A33", role = "DAMAGER", inferred = true,
                description = "Builds rage in human form, then shifts to worgen to shred. Priority INFERRED.",
                weights = { Agility = 1.0, Strength = 0.75, AttackPower = 0.55,
                    CritRating = 0.55, HasteRating = 0.40, HitRating = 0.40 },
            },
            {
                name = "Blood", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
                color = "8B0000", role = "DAMAGER", inferred = true,
                description = "San'layn blood magic paid for with its own health. Priority INFERRED.",
                weights = { Intellect = 1.0, SpellPower = 0.75, Stamina = 0.55,
                    HasteRating = 0.55, CritRating = 0.40, ShadowSpellPower = 0.05 },
            },
            {
                name = "Packleader", icon = "Interface\\Icons\\Ability_Hunter_BeastCall",
                color = "6B4423", role = "DAMAGER", inferred = true,
                description = "Permanently worgen, fighting with a summoned shadow pack. Priority INFERRED.",
                weights = { Agility = 1.0, AttackPower = 0.75, CritRating = 0.55,
                    HasteRating = 0.40, Strength = 0.40, HitRating = 0.05 },
            },
            {
                name = "Fleshweaver", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain",
                color = "A34A4A", role = "HEALER", inferred = true,
                description = "Heals through blood ritual, spending vitality. Priority INFERRED.",
                weights = { Intellect = 1.0, SpellPower = 0.75, Spirit = 0.55,
                    Stamina = 0.55, HasteRating = 0.40, Mp5 = 0.40 },
            },
        },
    },
    {
        class = "Tinker",
        color = "9FB4C7",
        description = "Engineers whose gadgets do the fighting for them.",
        specs = {
            {
                name = "Demolition", icon = "Interface\\Icons\\Spell_Fire_SelfDestruct",
                color = "9FB4C7", role = "DAMAGER",
                description = "Explosives at range. Intellect first, agility behind it.",
                weights = { Intellect = 1.0, Agility = 0.75, HasteRating = 0.55, CritRating = 0.40, SpellPower = 0.40 },
            },
            {
                name = "Mechanics", icon = "Interface\\Icons\\INV_Misc_Gear_01",
                color = "8FA4B7", role = "DAMAGER",
                description = "Turrets and constructs on the same Intellect and agility footing.",
                weights = { Intellect = 1.0, Agility = 0.75, HasteRating = 0.55, CritRating = 0.40, SpellPower = 0.40 },
            },
            {
                name = "Invention", icon = "Interface\\Icons\\INV_Gizmo_02",
                color = "BFD4E7", role = "HEALER",
                -- Published as Healer/Support; filed as HEALER since healing is the primary duty.
                description = "Healing and support through invention, still Intellect-led.",
                weights = { Intellect = 1.0, Agility = 0.75, Mp5 = 0.55, SpellPower = 0.55, HasteRating = 0.40 },
            },
        },
    },
    {
        class = "Barbarian",
        color = "A0522D",
        description = "Ragers who answer everything with an axe.",
        specs = {
            {
                name = "Brutality", icon = "Interface\\Icons\\Ability_Warrior_Rampage",
                color = "A0522D", role = "DAMAGER",
                -- Published as stars: Str and Crit both 5-star, Versatility 4.
                description = "Melee damage wanting Strength and critical strike equally.",
                weights = { Strength = 1.0, CritRating = 1.0, VersatilityRating = 0.75, AttackPower = 0.55, HasteRating = 0.40 },
            },
            {
                name = "Head Hunting", icon = "Interface\\Icons\\Ability_Throw",
                color = "8B4513", role = "DAMAGER",
                description = "Thrown damage led by critical strike rather than a primary stat.",
                weights = { CritRating = 1.0, HasteRating = 0.75, VersatilityRating = 0.75, Agility = 0.55, RangedAP = 0.40, Strength = 0.40 },
            },
            {
                name = "Ancestry", icon = "Interface\\Icons\\Spell_Shadow_SpiritLink",
                color = "C4703D", role = "SUPPORT",
                description = "Ancestral buffs alongside damage, on Strength and critical strike.",
                weights = { Strength = 1.0, CritRating = 1.0, HasteRating = 0.75, AttackPower = 0.55, Stamina = 0.40 },
            },
        },
    },
    {
        class = "Felsworn",
        color = "8B3A9E",
        description = "Those who took the fel bargain and kept fighting.",
        specs = {
            {
                name = "Infernal", icon = "Interface\\Icons\\Spell_Fire_FelFireNova",
                color = "8B3A9E", role = "DAMAGER",
                -- Felsworn breaks the one-class-stat pattern: Infernal is Intellect, the other two Agility.
                description = "Ranged fel damage scaling on Intellect.",
                weights = { Intellect = 1.0, SpellPower = 0.55, HasteRating = 0.55, CritRating = 0.40, FireSpellPower = 0.05 },
            },
            {
                name = "Slayer", icon = "Interface\\Icons\\Ability_Warrior_Charge",
                color = "9B4AAE", role = "DAMAGER",
                description = "High-mobility melee combos scaling on Agility.",
                weights = { Agility = 1.0, AttackPower = 0.55, CritRating = 0.55, HasteRating = 0.40, HitRating = 0.05 },
            },
            {
                name = "Tyrant", icon = "Interface\\Icons\\Ability_Rogue_Evasion",
                color = "6B2A7E", role = "TANK",
                description = "Evasion tank: mitigation through avoidance rather than armour.",
                weights = { Agility = 1.0, DodgeRating = 0.75, ParryRating = 0.55, Stamina = 0.55, Armor = 0.40, DefenseRating = 0.05 },
            },
        },
    },
    {
        class = "Witch Doctor",
        color = "4E9A57",
        description = "Vol'jin's own: hexes, brews and risen beasts.",
        specs = {
            {
                name = "Voodoo", icon = "Interface\\Icons\\Spell_Shadow_Haunting",
                color = "4E9A57", role = "DAMAGER",
                description = "Damage over time and hexes, scaling on Intellect.",
                weights = { Intellect = 1.0, SpellPower = 0.55, HasteRating = 0.55, CritRating = 0.40, ShadowSpellPower = 0.05 },
            },
            {
                name = "Brewing", icon = "Interface\\Icons\\INV_Drink_05",
                color = "6EBA77", role = "HEALER",
                description = "Potions and wards. Intellect-led healing.",
                weights = { Intellect = 1.0, SpellPower = 0.55, Mp5 = 0.55, HasteRating = 0.40, Spirit = 0.40 },
            },
            {
                name = "Shadowhunting", icon = "Interface\\Icons\\Ability_Hunter_Pet_Raptor",
                color = "3E8A47", role = "DAMAGER",
                -- Published as Intellect OR Agility - both weighted, per the dual-primary rule above.
                description = "Dinosaur summons and shadow tools, taking Intellect or Agility.",
                weights = { Intellect = 1.0, Agility = 1.0, AttackPower = 0.55, SpellPower = 0.55, CritRating = 0.40 },
            },
        },
    },
    {
        class = "Chronomancer",
        color = "B39DDB",
        description = "Time-benders who slow, rewind and hasten.",
        specs = {
            {
                name = "Displacement", icon = "Interface\\Icons\\Spell_Arcane_PortalDalaran",
                color = "B39DDB", role = "HEALER",
                description = "Healing through rewinding damage. Intellect then haste.",
                weights = { Intellect = 1.0, HasteRating = 0.75, SpellPower = 0.55, Mp5 = 0.40, CritRating = 0.40 },
            },
            {
                name = "Duality", icon = "Interface\\Icons\\Spell_Arcane_Arcane04",
                color = "9575CD", role = "DAMAGER",
                description = "Ranged damage on Intellect and critical strike.",
                weights = { Intellect = 1.0, CritRating = 0.75, SpellPower = 0.55, HasteRating = 0.40, ArcaneSpellPower = 0.05 },
            },
            {
                name = "Artificer", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
                color = "D1C4E9", role = "DAMAGER",
                -- SPIRIT as a primary. A regen afterthought in 3.3.5, a lead stat here - not a typo.
                description = "Ranged hybrid, and the only CoA spec led by Spirit.",
                weights = { Spirit = 1.0, HitRating = 0.75, Intellect = 0.55, SpellPower = 0.55, HasteRating = 0.40 },
            },
        },
    },
    {
        class = "Templar",
        color = "E6C88C",
        description = "Holy martial artists who fight with fists and faith.",
        specs = {
            {
                name = "Oathkeeper", icon = "Interface\\Icons\\Spell_Holy_SealOfProtection",
                color = "E6C88C", role = "TANK",
                description = "Tank built on stamina and dodging rather than blocking.",
                weights = { Stamina = 1.0, Agility = 0.75, DodgeRating = 0.75, ParryRating = 0.55, Armor = 0.40, DefenseRating = 0.05 },
            },
            {
                name = "Zealot", icon = "Interface\\Icons\\Ability_Monk_TigerPalm",
                color = "D6B87C", role = "DAMAGER",
                description = "Fast melee on Agility, haste and critical strike.",
                weights = { Agility = 1.0, HasteRating = 0.75, CritRating = 0.55, AttackPower = 0.40, HitRating = 0.05 },
            },
            {
                name = "Crusader", icon = "Interface\\Icons\\Spell_Holy_Crusade",
                color = "F6D89C", role = "DAMAGER",
                description = "Heavier melee taking Strength or Agility, then attack power.",
                weights = { Strength = 1.0, Agility = 1.0, AttackPower = 0.75, ArmorPenetration = 0.55, CritRating = 0.40 },
            },
        },
    },
    {
        class = "Knight of Xoroth",
        color = "8B0000",
        description = "Dread knights bound to a burning world.",
        specs = {
            {
                name = "War", icon = "Interface\\Icons\\Ability_Warrior_BloodFrenzy",
                color = "8B0000", role = "DAMAGER",
                description = "Physical damage and bleeds, on Strength.",
                weights = { Strength = 1.0, AttackPower = 0.55, CritRating = 0.55, ExpertiseRating = 0.40, HitRating = 0.40 },
            },
            {
                name = "Hellfire", icon = "Interface\\Icons\\Spell_Fire_Fireball02",
                color = "AB2020", role = "DAMAGER",
                description = "Melee and fire together, taking Intellect or Strength.",
                weights = { Intellect = 1.0, Strength = 1.0, SpellPower = 0.55, AttackPower = 0.55, CritRating = 0.40, FireSpellPower = 0.05 },
            },
            {
                name = "Defiance", icon = "Interface\\Icons\\Spell_Shadow_DeathPact",
                color = "6B0000", role = "TANK",
                description = "Tank using shields and summons, on Strength or Intellect.",
                weights = { Strength = 1.0, Intellect = 1.0, Stamina = 0.75, Armor = 0.55, ParryRating = 0.40, BlockValue = 0.40 },
            },
        },
    },
    {
        class = "Reaper",
        color = "4A4A5A",
        description = "Soul-harvesters in savage plate.",
        specs = {
            {
                name = "Harvest", icon = "Interface\\Icons\\Spell_Shadow_LifeDrain02",
                color = "4A4A5A", role = "DAMAGER",
                description = "Melee bruiser draining life, on Strength.",
                weights = { Strength = 1.0, AttackPower = 0.55, CritRating = 0.55, HasteRating = 0.40, ExpertiseRating = 0.40 },
            },
            {
                name = "Soul", icon = "Interface\\Icons\\Spell_Shadow_SoulLeech_3",
                color = "6A6A7A", role = "DAMAGER",
                description = "Melee shadow caster scaling on Intellect instead.",
                weights = { Intellect = 1.0, SpellPower = 0.55, ShadowSpellPower = 0.55, HasteRating = 0.40, CritRating = 0.40 },
            },
            {
                name = "Domination", icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
                color = "3A3A4A", role = "TANK",
                description = "Savage plate tanking, threat and defence both scaling on Strength.",
                weights = { Strength = 1.0, Stamina = 0.75, Armor = 0.55, ParryRating = 0.40, DefenseRating = 0.40, DodgeRating = 0.05 },
            },
        },
    },
    {
        class = "Witch Hunter",
        color = "C0C0C0",
        description = "Zealots who hunt what others fear, in mail.",
        specs = {
            {
                name = "Boltslinger", icon = "Interface\\Icons\\Ability_Hunter_Snipershot",
                color = "C0C0C0", role = "DAMAGER",
                description = "Mobile ranged damage; crit resets its own procs.",
                weights = { Agility = 1.0, CritRating = 0.75, RangedAP = 0.55, HasteRating = 0.40, HitRating = 0.40 },
            },
            {
                name = "Darkness", icon = "Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
                color = "808090", role = "DAMAGER",
                description = "Shadow hounds and burst damage, on Agility.",
                weights = { Agility = 1.0, AttackPower = 0.55, CritRating = 0.55, HasteRating = 0.40, ShadowSpellPower = 0.05 },
            },
            {
                name = "Inquisitor", icon = "Interface\\Icons\\Spell_Holy_HolySmite",
                color = "E0E0E0", role = "DAMAGER",
                description = "Melee zealot; haste drives resource generation.",
                weights = { Agility = 1.0, HasteRating = 0.75, AttackPower = 0.55, CritRating = 0.40, HitRating = 0.40 },
            },
            {
                name = "Black Knight", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
                color = "505060", role = "TANK",
                -- An AGILITY-scaling tank in MAIL. Neither is possible under 3.3.5 rules.
                description = "Mail tank using shadow brands for threat and self-healing.",
                weights = { Agility = 1.0, ParryRating = 0.75, ShadowResist = 0.55, Armor = 0.55, Stamina = 0.55, LeechRating = 0.40 },
            },
        },
    },
    {
        class = "Venomancer",
        color = "5FA855",
        description = "Plague-shapers who fight through venom, rot and shifting forms.",
        specs = {
            {
                name = "Fortitude", icon = "Interface\\Icons\\Ability_Creature_Poison_06",
                color = "4F8A47", role = "TANK",
                description = "Toxin-hardened tank. Armour first, then health, intellect and agility.",
                weights = { Armor = 1.0, Health = 0.75, Intellect = 0.55, Agility = 0.40,
                    Stamina = 0.05, DodgeRating = 0.05 },
            },
            {
                name = "Stalking", icon = "Interface\\Icons\\Ability_Rogue_Sprint",
                color = "6FBF5F", role = "DAMAGER",
                -- Published as "Leech, melee uptime, survivability". Only the first is a gear
                -- stat; uptime is read as haste and survivability as stamina, and that is a
                -- judgement rather than a transcription.
                description = "Melee damage sustained by leech rather than burst.",
                weights = { LeechRating = 1.0, HasteRating = 0.75, Stamina = 0.55,
                    Agility = 0.55, AttackPower = 0.40, Armor = 0.05 },
            },
            {
                name = "Rot Weaver", icon = "Interface\\Icons\\Spell_Shadow_CreepingPlague",
                color = "8FCF6F", role = "DAMAGER",
                description = "Caster damage on haste, then critical strike and spell power.",
                weights = { HasteRating = 1.0, CritRating = 0.75, SpellPower = 0.55,
                    Intellect = 0.40, NatureSpellPower = 0.05, HitRating = 0.05 },
            },
            {
                name = "Vizir", icon = "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
                color = "AFDF9F", role = "HEALER",
                -- "Haste, mana support, healing throughput" - throughput read as spell power.
                description = "Healer built on haste and sustaining mana.",
                weights = { HasteRating = 1.0, Mana = 0.75, Mp5 = 0.75, SpellPower = 0.55,
                    Intellect = 0.40, Spirit = 0.05 },
            },
        },
    },
    {
        class = "Necromancer",
        color = "6E4B8E",
        description = "Dark casters commanding the risen and draining the living.",
        specs = {
            {
                name = "Death", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",
                color = "6E4B8E", role = "DAMAGER",
                -- The page gives ONE priority for all three specs; that is the source's own
                -- choice, so all three share it rather than inventing differences.
                description = "Shadow damage scaling on Intellect and spell power together.",
                weights = { Intellect = 1.0, SpellPower = 1.0, HasteRating = 0.55,
                    CritRating = 0.40, ShadowSpellPower = 0.05, HitRating = 0.05 },
            },
            {
                name = "Animation", icon = "Interface\\Icons\\Spell_Shadow_RaiseDead",
                color = "7E5B9E", role = "DAMAGER",
                description = "Minion-driven damage on the same Intellect and spell power base.",
                weights = { Intellect = 1.0, SpellPower = 1.0, HasteRating = 0.55,
                    CritRating = 0.40, ShadowSpellPower = 0.05, HitRating = 0.05 },
            },
            {
                name = "Rime", icon = "Interface\\Icons\\Spell_Frost_ChillingBlast",
                color = "8E7BBE", role = "DAMAGER",
                description = "Frost-tinted necromancy on the same Intellect and spell power base.",
                weights = { Intellect = 1.0, SpellPower = 1.0, HasteRating = 0.55,
                    CritRating = 0.40, FrostSpellPower = 0.05, HitRating = 0.05 },
            },
        },
    },
    {
        class = "Pyromancer",
        color = "E25822",
        description = "Fire-wielders whose crits feed the next cast.",
        specs = {
            {
                name = "Flame Weaver", icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
                color = "F07830", role = "HEALER",
                -- Crit leads for every Pyromancer spec, deliberately: a crit shortens the next
                -- cast, so it is the rotational engine rather than a throughput stat.
                description = "Healer whose critical strikes accelerate the next cast.",
                weights = { CritRating = 1.0, Intellect = 0.75, HasteRating = 0.55,
                    VersatilityRating = 0.40, SpellPower = 0.40, Mp5 = 0.05 },
            },
            {
                name = "Incineration", icon = "Interface\\Icons\\Spell_Fire_Incinerate",
                color = "E25822", role = "DAMAGER",
                description = "Ranged fire damage on the same crit-led footing.",
                weights = { CritRating = 1.0, Intellect = 0.75, HasteRating = 0.55,
                    VersatilityRating = 0.40, SpellPower = 0.40, FireSpellPower = 0.05 },
            },
            {
                name = "Draconic", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
                color = "C43C10", role = "DAMAGER",
                description = "Dragon-form damage fought at melee range, still crit-led.",
                weights = { CritRating = 1.0, Intellect = 0.75, HasteRating = 0.55,
                    VersatilityRating = 0.40, SpellPower = 0.40, FireSpellPower = 0.05 },
            },
        },
    },
    {
        class = "Guardian",
        color = "C8B273",
        description = "Shield-bearers who hold the line and lift the band.",
        specs = {
            {
                name = "Vanguard", icon = "Interface\\Icons\\Ability_Warrior_ShieldWall",
                color = "C8B273", role = "TANK",
                description = "Shield-and-taunt tank wanting Strength and Stamina equally.",
                weights = { Strength = 1.0, Stamina = 1.0, DefenseRating = 0.75,
                    ParryRating = 0.55, DodgeRating = 0.55, BlockValue = 0.40,
                    BlockRating = 0.40, Armor = 0.05 },
            },
            {
                name = "Gladiator", icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance",
                color = "B89A5B", role = "DAMAGER",
                description = "Physical damage taking Strength or Agility, then critical strike.",
                weights = { Strength = 1.0, Agility = 1.0, CritRating = 0.75,
                    HasteRating = 0.55, ArmorPenetration = 0.55, HitRating = 0.40,
                    AttackPower = 0.40 },
            },
            {
                name = "Inspiration", icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
                color = "E0CE9B", role = "SUPPORT", inferred = true,
                -- NOT PUBLISHED. The page gives this spec no stat priority at all - it is
                -- "Banners & Songs" group buffs. These weights are inferred from the class's
                -- other two specs and flagged here so they can be corrected rather than
                -- mistaken for transcription.
                description = "Group buffs through banners and songs. Stat priority not published.",
                weights = { Strength = 1.0, Stamina = 0.75, CritRating = 0.55,
                    HasteRating = 0.55, Armor = 0.40, Agility = 0.40 },
            },
        },
    },
    {
        class = "Cultist",
        color = "7B4A9E",
        description = "Old God fanatics who trade sanity for power.",
        specs = {
            {
                name = "Heretic", icon = "Interface\\Icons\\Spell_Shadow_MindTwisting",
                color = "9B6ABE", role = "HEALER",
                description = "Healer scaling on Intellect and Strength together.",
                weights = { Intellect = 1.0, Strength = 1.0, SpellPower = 0.55,
                    HasteRating = 0.40, Mp5 = 0.05, CritRating = 0.05 },
            },
            {
                name = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
                color = "7B4A9E", role = "DAMAGER",
                description = "Ranged shadow damage on Intellect, then haste to build Insanity.",
                weights = { Intellect = 1.0, HasteRating = 0.75, SpellPower = 0.55,
                    CritRating = 0.40, ShadowSpellPower = 0.05, HitRating = 0.05 },
            },
            {
                name = "God Blade", icon = "Interface\\Icons\\Ability_Warrior_BloodBath",
                color = "5B3A7E", role = "DAMAGER",
                description = "Melee damage on Strength, with crit triggering void procs.",
                weights = { Strength = 1.0, CritRating = 0.75, AttackPower = 0.55,
                    HasteRating = 0.40, ExpertiseRating = 0.05, HitRating = 0.05 },
            },
            {
                name = "Dreadnought", icon = "Interface\\Icons\\Spell_Shadow_ShadowWard",
                color = "4B2A6E", role = "TANK",
                description = "Tank wanting Stamina and armour in equal measure.",
                weights = { Stamina = 1.0, Armor = 1.0, DefenseRating = 0.55,
                    DodgeRating = 0.40, ParryRating = 0.40, Health = 0.05 },
            },
        },
    },
    {
        class = "Starcaller",
        color = "8AA6E8",
        description = "Moon-sworn casters who fight, guard and mend by Intellect alike.",
        specs = {
            {
                name = "Warden", icon = "Interface\\Icons\\Spell_Nature_MoonGlow",
                color = "6A86C8", role = "TANK",
                -- Intellect leads all four Starcaller specs, tank and melee included. That
                -- inverts 3.3.5 and is exactly why this table cannot be derived from role.
                description = "Tank scaling on Intellect before Stamina and armour.",
                weights = { Intellect = 1.0, Stamina = 0.75, Armor = 0.55, BlockValue = 0.55,
                    HasteRating = 0.40, DefenseRating = 0.05 },
            },
            {
                name = "Sentinel", icon = "Interface\\Icons\\Spell_Arcane_StarFire",
                color = "8AA6E8", role = "DAMAGER",
                description = "Ranged damage: Intellect, spell power, critical strike, haste.",
                weights = { Intellect = 1.0, SpellPower = 0.75, CritRating = 0.55,
                    HasteRating = 0.40, ArcaneSpellPower = 0.05, HitRating = 0.05 },
            },
            {
                name = "Moon Priest", icon = "Interface\\Icons\\Spell_Holy_ElunesGrace",
                color = "C8D6FF", role = "HEALER",
                description = "Healer: Intellect, spirit, spell power, critical strike.",
                weights = { Intellect = 1.0, Spirit = 0.75, SpellPower = 0.55,
                    CritRating = 0.40, Mp5 = 0.05, HasteRating = 0.05 },
            },
            {
                name = "Moon Guard", icon = "Interface\\Icons\\Ability_Druid_Maul",
                color = "5A76B8", role = "DAMAGER",
                description = "Melee damage that still scales on Intellect before attack power.",
                weights = { Intellect = 1.0, AttackPower = 0.75, HasteRating = 0.55,
                    CritRating = 0.40, Agility = 0.05, HitRating = 0.05 },
            },
        },
    },
    {
        class = "Primalist",
        color = "8B7355",
        description = "Elemental shapers drawing on stone, storm and life itself.",
        specs = {
            {
                name = "Mountain King", icon = "Interface\\Icons\\Spell_Nature_EarthQuake",
                color = "9C6B3F", role = "TANK",
                description = "Stone-clad tank. Armor first, then Stamina, Defense and Strength.",
                weights = { Armor = 1.0, Stamina = 0.75, DefenseRating = 0.55, Strength = 0.40,
                    DodgeRating = 0.05, ParryRating = 0.05, Health = 0.05 },
            },
            {
                name = "Life", icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
                color = "5FBF5F", role = "HEALER",
                description = "Restorative healer scaling on raw spell power before Intellect.",
                weights = { SpellPower = 1.0, Intellect = 0.75, CritRating = 0.55, HasteRating = 0.40,
                    Mp5 = 0.05, Spirit = 0.05 },
            },
            {
                name = "Wildwalker", icon = "Interface\\Icons\\Ability_Druid_CatForm",
                color = "C77B3F", role = "DAMAGER",
                description = "Melee damage built on Strength and reaching the hit cap.",
                weights = { Strength = 1.0, AttackPower = 0.75, HitRating = 0.55, CritRating = 0.40,
                    Agility = 0.05, ExpertiseRating = 0.05, HasteRating = 0.05 },
            },
            {
                name = "Geomancy", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem",
                color = "7F6A4F", role = "DAMAGER",
                description = "Caster damage led by spell power, with haste ahead of Intellect.",
                weights = { SpellPower = 1.0, HasteRating = 0.75, Intellect = 0.55, CritRating = 0.40,
                    HitRating = 0.05, SpellPenetration = 0.05 },
            },
        },
    },
    {
        class = "Sun Cleric",
        color = "F5DF6E",
        description = "Champions of the sun, mending and burning in equal measure.",
        specs = {
            {
                name = "Piety", icon = "Interface\\Icons\\Spell_Holy_SearingLight",
                color = "F5C24E", role = "DAMAGER",
                description = "Caster damage: Intellect, then haste, then spell critical.",
                weights = { Intellect = 1.0, HasteRating = 0.75, CritRating = 0.55,
                    SpellPower = 0.40, HolySpellPower = 0.05, HitRating = 0.05 },
            },
            {
                name = "Valkyrie", icon = "Interface\\Icons\\Spell_Holy_CrusaderStrike",
                color = "E8B24A", role = "DAMAGER",
                description = "Melee damage: Strength, melee critical, then haste.",
                weights = { Strength = 1.0, CritRating = 0.75, HasteRating = 0.55,
                    AttackPower = 0.40, ExpertiseRating = 0.05, HitRating = 0.05 },
            },
            {
                name = "Seraphim", icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
                color = "D9A441", role = "TANK",
                description = "Plate tank scaling on Strength, then armour and stamina.",
                weights = { Strength = 1.0, Armor = 0.75, Stamina = 0.75,
                    ParryRating = 0.55, DodgeRating = 0.55, DefenseRating = 0.40 },
            },
            {
                name = "Blessings", icon = "Interface\\Icons\\Spell_Holy_HolyBolt",
                color = "FFE9A8", role = "HEALER",
                description = "Healer: Intellect, then spell power, then mana regeneration.",
                weights = { Intellect = 1.0, SpellPower = 0.75, Mp5 = 0.55, Spirit = 0.55,
                    CritRating = 0.05, HasteRating = 0.05 },
            },
        },
    },
    {
        class = "Ranger",
        color = "6BBF59",
        description = "Marksmen and skirmishers who never miss twice.",
        specs = {
            {
                name = "Archer", icon = "Interface\\Icons\\Ability_Hunter_FocusedAim",
                color = "6BBF59", role = "DAMAGER",
                description = "Pure ranged damage. Agility above everything.",
                weights = { Agility = 1.0, RangedAP = 0.55, AttackPower = 0.55,
                    CritRating = 0.40, HitRating = 0.40, RangedDps = 0.40, HasteRating = 0.05 },
            },
            {
                name = "Brigand", icon = "Interface\\Icons\\Ability_Rogue_Ambush",
                color = "4F9E43", role = "DAMAGER",
                description = "Melee duellist. Agility above everything.",
                weights = { Agility = 1.0, AttackPower = 0.55, CritRating = 0.40,
                    HitRating = 0.40, ExpertiseRating = 0.40, HasteRating = 0.05 },
            },
            {
                name = "Farstrider", icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman",
                color = "8FD47E", role = "SUPPORT",
                description = "Utility and group support, still scaling on Agility.",
                weights = { Agility = 1.0, AttackPower = 0.55, CritRating = 0.40,
                    HasteRating = 0.40, HitRating = 0.05, Stamina = 0.05 },
            },
        },
    },
    {
        class = "Runemaster",
        color = "7F9FD4",
        description = "Rune-carvers who bend the battlefield with inscribed power.",
        specs = {
            {
                name = "Engravement", icon = "Interface\\Icons\\Spell_Shadow_Rune",
                color = "7F9FD4", role = "DAMAGER",
                description = "Sustained damage and control. Agility-scaling.",
                weights = { Agility = 1.0, AttackPower = 0.55, CritRating = 0.40,
                    HasteRating = 0.40, HitRating = 0.05, ExpertiseRating = 0.05 },
            },
            {
                name = "Glyph", icon = "Interface\\Icons\\Spell_Shadow_DemonicRune",
                color = "6F8FC4", role = "DAMAGER",
                description = "Area damage and battlefield control. Agility-scaling.",
                weights = { Agility = 1.0, AttackPower = 0.55, CritRating = 0.40,
                    HasteRating = 0.40, HitRating = 0.05 },
            },
            {
                name = "Rift Blade", icon = "Interface\\Icons\\Ability_Warrior_Riposte",
                color = "9FBFE4", role = "DAMAGER",
                description = "Burst assassination and escape. Agility-scaling.",
                weights = { Agility = 1.0, AttackPower = 0.55, CritRating = 0.55,
                    HasteRating = 0.40, HitRating = 0.05 },
            },
        },
    },
    {
        class = "Stormbringer",
        color = "4FC3F7",
        description = "Storm-callers who trade static for lightning.",
        specs = {
            {
                name = "Lightning", icon = "Interface\\Icons\\Spell_Nature_Lightning",
                color = "4FC3F7", role = "DAMAGER",
                description = "Damage on haste and mastery, with critical strike behind them.",
                weights = { HasteRating = 1.0, MasteryRating = 1.0, CritRating = 0.55,
                    Intellect = 0.40, SpellPower = 0.40, NatureSpellPower = 0.05 },
            },
            {
                name = "Maelstrom", icon = "Interface\\Icons\\Spell_Frost_FrostShock",
                color = "6FD3FF", role = "DAMAGER",
                description = "Frost-storm hybrid on the same haste and mastery footing.",
                weights = { HasteRating = 1.0, MasteryRating = 1.0, CritRating = 0.55,
                    Intellect = 0.40, SpellPower = 0.40, FrostSpellPower = 0.05 },
            },
            {
                name = "Wind", icon = "Interface\\Icons\\Spell_Nature_Cyclone",
                color = "A8E6FF", role = "SUPPORT",
                description = "Support build using versatility for group damage reduction.",
                weights = { HasteRating = 1.0, VersatilityRating = 0.75, Intellect = 0.55,
                    SpellPower = 0.40, MasteryRating = 0.40, Stamina = 0.05 },
            },
        },
    },
}

ns.SCALE_ICON_LIST = SCALE_ICON_LIST
ns.CLASS_SPEC_TEMPLATES = CLASS_SPEC_TEMPLATES
ns.COA_CLASS_SPEC_TEMPLATES = COA_CLASS_SPEC_TEMPLATES

-- Which template set applies to this character, and a word naming which it picked.
--
-- Detected from the player's CLASS, not the realm name. Realm names change and new ones get
-- added - Conquest of Azeroth launched on Vol'jin, and a hardcoded check for that string
-- would quietly stop working the day a second CoA realm opens. A Necromancer is a
-- Necromancer wherever they log in, and no classic character is ever one.
--
-- Falls back to the classic set whenever the answer is not clearly CoA: an unrecognised
-- class, a missing UnitClass, or the classless realms where the class is a WotLK one. That
-- is the safe direction - the classic set has been the only set for this addon's whole life,
-- so falling back to it is the behaviour everyone already has.
function Valuate:GetTemplateSet()
    local coa = ns.COA_CLASS_SPEC_TEMPLATES
    if coa and type(UnitClass) == "function" then
        local className = UnitClass("player")
        if type(className) == "string" and className ~= "" then
            for _, entry in ipairs(coa) do
                if entry.class == className then
                    return coa, "coa"
                end
            end
        end
    end
    return ns.CLASS_SPEC_TEMPLATES, "classic"
end
