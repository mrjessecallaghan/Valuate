# Valuate Scale Import/Export Test Cases

This file contains test scale tags for verifying the import/export functionality.

## Test Case 1: Basic Scale (Minimal Properties)
```
{Valuate:v1:Test Basic{Color=00FF00,Visible=1,Strength=1.5,Agility=2.0,Stamina=1.0}}
```

**Expected Result:**
- Scale name: "Test Basic"
- Color: Green (00FF00)
- Visible: true
- Strength = 1.5
- Agility = 2.0
- Stamina = 1.0

## Test Case 2: Warrior DPS with Icon
```
{Valuate:v1:Warrior DPS{Color=C79C6E,Icon=Interface\Icons\Ability_Warrior_SavageBlow,Visible=1,Strength=2.5,AttackPower=1.0,CritRating=2.0,HitRating=2.5,ExpertiseRating=1.5}}
```

**Expected Result:**
- Scale name: "Warrior DPS"
- Color: Warrior class color (C79C6E)
- Icon: Ability_Warrior_SavageBlow
- Visible: true
- Multiple physical stats

## Test Case 3: Priest Healer with Unusable Stats
```
{Valuate:v1:Priest Healer{Color=FFFFFF,Icon=Interface\Icons\Spell_Holy_PowerWordShield,Visible=1,Intellect=2.0,Spirit=1.8,SpellPower=1.5,CritRating=1.0,HasteRating=1.5,Unusable.Strength=1,Unusable.AttackPower=1,Unusable.Agility=1}}
```

**Expected Result:**
- Scale name: "Priest Healer"
- Color: White (FFFFFF)
- Icon: Spell_Holy_PowerWordShield
- Visible: true
- Caster stats
- Unusable: Strength, AttackPower, Agility should be marked as unusable

## Test Case 4: Tank Scale with Defense Stats
```
{Valuate:v1:Protection Tank{Color=FF0000,Visible=1,Stamina=2.5,Armor=0.5,DefenseRating=2.0,DodgeRating=1.5,ParryRating=1.5,BlockRating=1.0,BlockValue=0.5}}
```

**Expected Result:**
- Scale name: "Protection Tank"
- Color: Red (FF0000)
- Visible: true
- Tank-focused stats

## Test Case 5: Complex Scale with Many Stats
```
{Valuate:v1:Hybrid Shaman{Color=0070DE,Icon=Interface\Icons\Spell_Nature_Lightning,Visible=1,Agility=1.5,AttackPower=1.2,CritRating=1.8,HitRating=2.0,Intellect=1.5,SpellPower=1.3,HasteRating=1.5,Stamina=1.0}}
```

**Expected Result:**
- Scale name: "Hybrid Shaman"
- Color: Shaman class color (0070DE)
- Icon: Spell_Nature_Lightning
- Mix of physical and spell stats

## Test Case 6: Scale with Decimal Values
```
{Valuate:v1:Precise Rogue{Color=FFF569,Visible=1,Agility=2.75,AttackPower=1.125,CritRating=2.5,HitRating=2.875,ExpertiseRating=1.625,HasteRating=1.375}}
```

**Expected Result:**
- Scale name: "Precise Rogue"
- Decimal stat values preserved

## Test Case 7: Scale with Spaces in Name
```
{Valuate:v1:My Custom Scale Name{Color=FF00FF,Visible=1,Strength=1.0,Stamina=1.0}}
```

**Expected Result:**
- Scale name: "My Custom Scale Name" (with spaces)
- Color: Magenta

## Test Case 8: Hidden Scale (Visible=0)
```
{Valuate:v1:Hidden Test{Color=888888,Visible=0,Strength=1.0}}
```

**Expected Result:**
- Scale name: "Hidden Test"
- Visible: false (scale should import but not show in tooltip by default)

## Test Case 9: Multiple Scales at Once
```
{Valuate:v1:Tank{Color=FF0000,Visible=1,Stamina=2.0,DefenseRating=1.5}}  {Valuate:v1:DPS{Color=00FF00,Visible=1,AttackPower=1.5,CritRating=1.0}}  {Valuate:v1:Healer{Color=0000FF,Visible=1,Intellect=2.0,SpellPower=1.5}}
```

**Expected Result:**
- Should import three separate scales
- Tank (Red), DPS (Green), Healer (Blue)

## Test Case 10: Scale with Negative Values (Edge Case)
```
{Valuate:v1:Negative Test{Color=FFFF00,Visible=1,Strength=1.5,Intellect=-1.0}}
```

**Expected Result:**
- Should handle negative stat weights (penalties)
- Intellect = -1.0

## Invalid Test Cases (Should Fail Gracefully)

### Invalid Format 1: Missing Outer Braces
```
Valuate:v1:Invalid{Color=FF0000,Strength=1.0}
```
**Expected:** TAG_ERROR

### Invalid Format 2: Wrong Version Format
```
{Valuate:vX:Invalid{Color=FF0000,Strength=1.0}}
```
**Expected:** TAG_ERROR

### Invalid Format 3: Missing Inner Braces
```
{Valuate:v1:Invalid}
```
**Expected:** TAG_ERROR

### Invalid Format 4: Future Version (v999)
```
{Valuate:v999:Future Scale{Color=FF0000,Strength=1.0}}
```
**Expected:** VERSION_ERROR

## Testing Checklist

- [ ] Test Case 1: Basic scale import/export
- [ ] Test Case 2: Scale with icon import/export
- [ ] Test Case 3: Scale with unusable stats import/export
- [ ] Test Case 4: Tank scale import/export
- [ ] Test Case 5: Complex hybrid scale import/export
- [ ] Test Case 6: Decimal values preserved
- [ ] Test Case 7: Scale name with spaces
- [ ] Test Case 8: Hidden scale (Visible=0)
- [ ] Test Case 9: Multiple scales import at once
- [ ] Test Case 10: Negative stat values
- [ ] Invalid format 1: Missing outer braces
- [ ] Invalid format 2: Wrong version format
- [ ] Invalid format 3: Missing inner braces
- [ ] Invalid format 4: Future version error
- [ ] Export then re-import preserves all properties
- [ ] UI buttons enable/disable correctly
- [ ] Slash commands work (/valuate import, /valuate export)
- [ ] Dialog copy/paste functionality works
- [ ] Overwrite existing scale confirmation works
- [ ] Long scale tags (900+ characters) work

## Manual Testing Steps

1. **Export Test:**
   - Create a scale in Valuate UI with various stats
   - Click Export button
   - Verify scale tag appears in dialog
   - Copy the scale tag

2. **Import Test:**
   - Click Import button
   - Paste a test scale tag
   - Click OK
   - Verify scale appears in scale list
   - Verify all properties match (color, icon, stats, unusable)

3. **Slash Command Test:**
   - `/valuate export [scalename]` - Verify scale tag prints to chat
   - `/valuate import` - Verify import dialog opens

4. **Overwrite Test:**
   - Import a scale that already exists
   - Verify it overwrites with new values

5. **UI Validation:**
   - Verify Import button is always enabled
   - Verify Export button is disabled when no scale selected
   - Verify Export button enables when scale is selected
   - Verify Reset Values button moved to the right

