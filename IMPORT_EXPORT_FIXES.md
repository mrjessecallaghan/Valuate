# Import/Export Improvements - v0.5.0

## Issues Fixed

### 1. ✅ Multiple Scale Import (Test Case 9)
**Problem:** Only the first scale was imported when pasting multiple scale tags.

**Solution:** 
- Added `Valuate:ParseMultipleScaleTags(text)` function to extract all scale tags from input
- Added `Valuate:ImportMultipleScales(text, overwrite)` function for batch importing
- Import dialog now detects and handles multiple scales automatically
- Shows summary: "Imported X scale(s), failed Y scale(s)"

**Example:**
```lua
{Valuate:v1:Tank{Color=FF0000,Stamina=2.0}}  {Valuate:v1:DPS{Color=00FF00,AttackPower=1.5}}  {Valuate:v1:Healer{Color=0000FF,Intellect=2.0}}
```
All three scales will now import successfully.

### 2. ✅ Ctrl+C Capture in Export Dialog
**Problem:** Pressing Ctrl+C in the export dialog opened the character window instead of copying text.

**Solution:**
- Added `OnKeyDown` script handler to the EditBox
- Intercepts Ctrl+C and Ctrl+A key combinations
- Ctrl+C now highlights all text for easy copying
- Ctrl+A selects all text
- Dialog has higher frame strata (`FULLSCREEN_DIALOG`) to stay on top

### 3. ✅ Overwrite Confirmation
**Problem:** Importing a scale with an existing name would silently overwrite without warning.

**Solution:**
- Import now checks for existing scales first (with `overwrite=false`)
- Shows confirmation dialog: "A scale named 'X' already exists. Overwrite it?"
- User can choose "Overwrite" or "Cancel"
- For multiple scales: shows list of conflicts and asks once for all

**Single Scale Confirmation:**
```
A scale named "Warrior DPS" already exists.

Overwrite it?
[Overwrite] [Cancel]
```

**Multiple Scales Confirmation:**
```
The following scales already exist:
Tank, DPS, Healer

Overwrite them?
[Overwrite] [Skip]
```

### 4. ✅ Descriptive Error Messages
**Problem:** Import errors just said "Invalid format" without explaining why.

**Solution:**
- Enhanced `ParseScaleTag()` to return specific error messages
- All error paths now provide user-friendly descriptions
- Errors are displayed in chat with red text

**Error Messages:**
- ❌ "Invalid input: scale tag must be a non-empty string"
- ❌ "Invalid format: scale tag must be in format {Valuate:v1:Name{props}}"
- ❌ "Invalid version number in scale tag"
- ❌ "Scale name cannot be empty"
- ❌ "This scale tag is from a newer version of Valuate (vX). Please update the addon."
- ❌ "No valid stat values found in scale tag"

## Technical Changes

### ImportExport.lua
1. **Enhanced ParseScaleTag():**
   - Returns: `scaleName, scaleData, errorMessage, versionMessage`
   - Provides specific error for each failure point
   - Better version compatibility messaging

2. **New ParseMultipleScaleTags():**
   - Extracts all `{Valuate:...}` patterns from text
   - Returns array of parsed scales and array of errors
   - Uses `string.gmatch()` for pattern matching

3. **New ImportMultipleScales():**
   - Imports multiple scales in one operation
   - Tracks success/fail counts
   - Returns list of existing scales for confirmation
   - Refreshes UI once at the end (efficient)

4. **Enhanced ImportScale():**
   - Now returns: `status, scaleName, errorMessage`
   - Checks for existing scales when `overwrite=false`
   - Provides detailed error messages

### ValuateUI.lua
1. **Enhanced Import Dialog:**
   - Detects single vs multiple scale imports
   - Shows appropriate confirmation dialogs
   - Handles batch import with summary messages
   - Updated prompt: "supports multiple scales"

2. **EditBox Keyboard Handling:**
   - Added `OnKeyDown` script
   - Ctrl+C highlights all text
   - Ctrl+A selects all text
   - Prevents character window from opening

3. **Confirmation Dialogs:**
   - `VALUATE_IMPORT_OVERWRITE_SINGLE` - For single scale conflicts
   - `VALUATE_IMPORT_OVERWRITE` - For multiple scale conflicts
   - Both use StaticPopupDialogs for consistent UI

4. **Frame Strata:**
   - Changed from `"DIALOG"` to `"FULLSCREEN_DIALOG"`
   - Added `SetFrameLevel(100)`
   - Ensures dialog appears above Valuate UI

## User Experience Improvements

### Before:
- ❌ Only first scale imported from multiple
- ❌ Ctrl+C opened character window
- ❌ Silent overwrite of existing scales
- ❌ Generic "invalid format" errors

### After:
- ✅ All scales import from multiple tags
- ✅ Ctrl+C copies text in dialog
- ✅ Confirmation before overwriting
- ✅ Specific error messages explaining issues

## Testing Checklist

- [x] Single scale import
- [x] Multiple scale import (Test Case 9)
- [x] Ctrl+C in export dialog
- [x] Ctrl+A in export/import dialog
- [x] Overwrite confirmation (single scale)
- [x] Overwrite confirmation (multiple scales)
- [x] Error message: empty input
- [x] Error message: invalid format
- [x] Error message: future version
- [x] Error message: no stat values
- [x] Dialog appears above Valuate UI
- [x] No linter errors

## Examples

### Multiple Scale Import
**Input:**
```
{Valuate:v1:Tank{Color=FF0000,Stamina=2.0,DefenseRating=1.5}}  {Valuate:v1:DPS{Color=00FF00,AttackPower=1.5,CritRating=1.0}}
```

**Output:**
```
Valuate: Imported 2 scale(s)
```

### Overwrite Confirmation
**Scenario:** Importing "Warrior DPS" when it already exists

**Dialog:**
```
A scale named "Warrior DPS" already exists.

Overwrite it?
[Overwrite] [Cancel]
```

### Error Messages
**Invalid Format:**
```
Valuate: Import failed: Invalid format: scale tag must be in format {Valuate:v1:Name{props}}
```

**Future Version:**
```
Valuate: Import failed: This scale tag is from a newer version of Valuate (v2). Please update the addon.
```

## Version History
- **v0.5.0** - Initial import/export implementation
  - Added all fixes and improvements listed above
  - JSON-like format with curly braces
  - Full icon and unusable stats support

