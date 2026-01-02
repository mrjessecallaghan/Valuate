# Default Class/Spec Scales Feature

## Overview
This feature allows users to create new scales pre-populated with default stat weights for WotLK class specializations. The stat weights are based on the Pawn addon's curated scales and have been translated to Valuate's stat naming conventions.

## What Was Added

### 1. New File: `DefaultScales.lua`
- Contains 28 pre-configured class/spec scales (all WotLK classes except Death Knight)
- Organized by class: Warrior (3), Paladin (3), Hunter (3), Rogue (3), Priest (3), Shaman (3), Mage (3), Warlock (3), Druid (4)
- Each scale includes:
  - Display name (e.g., "Warrior Arms", "Mage Fire")
  - Class color
  - Class icon
  - Stat weight values
  - Unusable item types (converted from Pawn's negative weights)
- Helper function `Valuate:GetAllDefaultScales()` for retrieving all scales

### 2. Updated: `Valuate.toc`
- Added `DefaultScales.lua` to the load order (before ValuateUI.lua)

### 3. Updated: `ValuateUI.lua`

#### UI Changes:
- **Renamed "New Scale" button to "New Blank Scale"**
  - Makes it clear this creates an empty scale
  
- **Added "+" button next to "New Blank Scale"**
  - Square button (24x24 px) positioned at the right end
  - Tooltip: "New Scale from Template"
  - Opens the Default Scale Picker dialog

#### New Dialog: Default Scale Picker
- Modal dialog (400x500 px) with scrollable list
- Shows all 28 class/spec combinations organized by class
- Each class has a colored header with specs listed below
- Each spec entry shows:
  - Class icon
  - Full spec name (e.g., "Warrior Arms")
- Click any spec to create a new scale with those default weights
- Draggable, closeable with X button or Escape key

#### New Function: `ValuateUI_ShowDefaultScalePicker()`
- Opens the Default Scale Picker dialog
- Called when user clicks the "+" button

#### New Function: `ValuateUI_NewScaleFromDefault(scaleData)`
- Creates a new scale from a default template
- Handles name uniqueness (adds counter if name exists)
- Copies stat values and unusable item types
- Auto-selects the newly created scale
- Shows success message in chat

## Stat Name Translation

Pawn uses different stat names than Valuate. The translation map:

| Pawn Stat Name | Valuate Stat Name |
|----------------|-------------------|
| `Ap` | `AttackPower` |
| `ShadowSpellDamage` | `ShadowSpellPower` |
| `FireSpellDamage` | `FireSpellPower` |
| `FrostSpellDamage` | `FrostSpellPower` |
| `ArcaneSpellDamage` | `ArcaneSpellPower` |
| All others | Same name |

## Negative Weight Handling

Pawn uses large negative values (-1000000) to mark unusable item types (e.g., cloth armor for warriors). In Valuate:
- Any stat with a negative value in Pawn is extracted
- Added to the scale's `Unusable` table with value `true`
- Not included in the `Values` table
- This makes Valuate skip showing scores for items with those properties

Example: Warrior scales mark `IsWand = true` in Unusable, so wands won't show a score for warrior scales.

## User Flow

1. User clicks the "+" button next to "New Blank Scale"
2. Default Scale Picker dialog appears
3. User browses through class categories (Warrior, Paladin, Hunter, etc.)
4. User clicks desired spec (e.g., "Fury" under Warrior)
5. New scale "Warrior Fury" is created with pre-filled weights
6. Dialog closes automatically
7. Scale is selected and ready for viewing/editing
8. User can modify the weights as needed

## Available Scales

### Warrior (3)
- Warrior Arms
- Warrior Fury
- Warrior Tank

### Paladin (3)
- Paladin Holy
- Paladin Retribution
- Paladin Tank

### Hunter (3)
- Hunter Beast Mastery
- Hunter Marksman
- Hunter Survival

### Rogue (3)
- Rogue Assassination
- Rogue Combat
- Rogue Subtlety

### Priest (3)
- Priest Discipline
- Priest Holy
- Priest Shadow

### Shaman (3)
- Shaman Elemental
- Shaman Enhancement
- Shaman Restoration

### Mage (3)
- Mage Arcane
- Mage Fire
- Mage Frost

### Warlock (3)
- Warlock Affliction
- Warlock Demonology
- Warlock Destruction

### Druid (4)
- Druid Balance
- Druid Feral DPS
- Druid Feral Tank
- Druid Restoration

## Technical Notes

- All scales use class-appropriate colors from Pawn
- Icons use WoW's built-in class icons
- Stat weights are normalized (highest stat = 100 in most cases)
- Stamina is typically weighted at 0.1 (low priority for DPS/Healer specs)
- The feature is fully integrated with existing scale management (edit, delete, import/export, etc.)
- No changes to saved variables structure - works with existing ValuateScales table

## Testing Checklist

- [x] DefaultScales.lua loads without errors
- [x] "New Blank Scale" button renamed correctly
- [x] "+" button appears and has tooltip
- [x] Default Scale Picker opens when clicking "+"
- [x] All 28 class/spec scales appear in the picker
- [x] Class headers are colored correctly
- [x] Clicking a spec creates a new scale
- [x] New scale has correct values and unusable items
- [x] New scale is auto-selected after creation
- [x] Scale can be edited normally after creation
- [x] No linter errors in any modified files

