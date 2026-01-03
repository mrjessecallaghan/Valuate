# Class/Spec Template Feature

## Overview
Added a template system for quickly creating pre-configured scales for each WotLK class and spec (excluding Death Knight).

## User Interface

### New Button
- **"+" button** added next to "New Scale" button (30% width)
- Opens the template picker window
- Tooltip: "Create from Template - Select a class/spec template"

### Template Picker Window
- **Size**: 650×620px (no scrolling needed)
- **Layout**: Two columns showing all classes and specs
- **Left Column**: Warrior, Paladin, Hunter, Rogue, Priest
- **Right Column**: Shaman, Mage, Warlock, Druid

### Features
- **Class headers** with proper class colors
- **Spec buttons** with icons and names
- **Normal click**: Creates scale and closes window
- **Shift-click**: Creates scale and keeps window open for multiple selections
- **Overwrite protection**: Prompts before overwriting existing scales
- **ESC key**: Closes the window
- **Draggable**: Can be moved around the screen

## Templates Included

Each spec has its own unique, thematically appropriate color for easy identification.

### Warrior (3 specs)
- **Arms Warrior** - Physical DPS (Red - aggressive)
- **Fury Warrior** - Physical DPS (Orange - berserker fury)
- **Protection Warrior** - Tank (Blue - defensive steel)

### Paladin (3 specs)
- **Holy Paladin** - Healer (Gold - holy light)
- **Protection Paladin** - Tank (Silver - protective shield)
- **Retribution Paladin** - Physical DPS (Crimson - righteous vengeance)

### Hunter (3 specs)
- **Beast Mastery Hunter** - Physical DPS (Green - beast nature)
- **Marksmanship Hunter** - Physical DPS (Blue - precision aim)
- **Survival Hunter** - Physical DPS (Brown - wilderness survival)

### Rogue (3 specs)
- **Assassination Rogue** - Physical DPS (Bright Green - poison/venom)
- **Combat Rogue** - Physical DPS (Red - bloodthirsty combat)
- **Subtlety Rogue** - Physical DPS (Purple - shadowy stealth)

### Priest (3 specs)
- **Discipline Priest** - Healer (Light Gray - discipline/balance)
- **Holy Priest** - Healer (Bright Yellow - holy radiance)
- **Shadow Priest** - Spell DPS (Purple - shadow magic)

### Shaman (3 specs)
- **Elemental Shaman** - Spell DPS (Bright Blue - lightning storm)
- **Enhancement Shaman** - Physical DPS (Orange - fiery enhancement)
- **Restoration Shaman** - Healer (Teal Green - healing waters)

### Mage (3 specs)
- **Arcane Mage** - Spell DPS (Purple - arcane magic)
- **Fire Mage** - Spell DPS (Red-Orange - burning flames)
- **Frost Mage** - Spell DPS (Cyan - ice cold)

### Warlock (3 specs)
- **Affliction Warlock** - Spell DPS (Green - disease/decay)
- **Demonology Warlock** - Spell DPS (Purple - demonic power)
- **Destruction Warlock** - Spell DPS (Red - destructive fire)

### Druid (4 specs)
- **Balance Druid** - Spell DPS (Blue - celestial balance)
- **Feral DPS Druid** - Physical DPS (Orange - cat ferocity)
- **Feral Tank Druid** - Tank (Brown - bear strength)
- **Restoration Druid** - Healer (Green - nature's healing)

## Template Stat Weights

Each template includes reasonable default stat weights appropriate for the spec:

### Physical DPS
- Primary stat (Str/Agi): 1.0
- Attack Power: 0.5-0.6
- Hit Rating: 1.0
- Crit Rating: 0.7-0.9
- Haste Rating: 0.5-0.8
- Expertise Rating: 0.9
- Armor Penetration: 0.7-0.9

### Spell DPS
- Intellect: 1.0
- Spell Power: 1.0
- Hit Rating: 1.0
- Crit Rating: 0.7-0.9
- Haste Rating: 0.8-0.9
- Spirit: 0.3-0.6

### Tank
- Stamina: 1.0
- Armor: 0.5-0.7
- Defense Rating: 0.3-0.8
- Dodge Rating: 0.7-0.8
- Parry Rating: 0.7
- Block Rating: 0.6
- Threat stats: 0.4-0.6

### Healer
- Intellect: 1.0
- Spell Power: 0.9
- Spirit: 0.5-0.7
- MP5: 0.7-0.8
- Crit Rating: 0.6-0.7
- Haste Rating: 0.6-0.8

## Technical Implementation

### Files Modified
- **ValuateUI.lua**: All changes in one file

### Key Components
1. **CLASS_SPEC_TEMPLATES**: Data structure with all class/spec definitions
2. **CreateTemplatePickerFrame()**: Builds the picker window
3. **ValuateUI_ShowTemplatePicker()**: Shows the picker and sets up handlers
4. **ValuateUI_CreateScaleFromTemplate()**: Creates scale from template data
5. **StaticPopupDialogs["VALUATE_TEMPLATE_OVERWRITE"]**: Overwrite confirmation dialog

### Design Consistency
- Uses existing color palette and styling
- Follows standardized spacing (PADDING, ELEMENT_SPACING, INNER_SPACING)
- Matches button heights and fonts
- Consistent with other addon dialogs

## Usage

1. Click the **"+"** button next to "New Scale"
2. Browse the template picker window
3. Click any spec to create a scale with that template
4. Hold **Shift** while clicking to create multiple scales
5. If a scale name exists, you'll be prompted to overwrite
6. The new scale is automatically selected for editing

## Benefits

- **Fast setup**: Pre-configured stat weights for each spec
- **Beginner friendly**: Good starting points for new users
- **Customizable**: Templates can be edited after creation
- **Safe**: Overwrite protection prevents accidental data loss
- **Efficient**: Shift-click for bulk creation

