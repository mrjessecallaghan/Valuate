# SavedVariables Persistence Fix

## Problem
Scales and settings were not saving between reloads because:
- The `.toc` file declares `ValuateDB` as the SavedVariable
- The code was using `ValuateOptions` and `ValuateScales` directly as global variables
- **Only variables declared in the .toc SavedVariables line are persisted by WoW**

## Solution
The code now properly uses `ValuateDB` as a container for all saved data:

```lua
ValuateDB = {
    Options = { ... },  -- All addon settings
    Scales = { ... }    -- All stat weight scales
}
```

The addon creates convenience references:
```lua
ValuateOptions = ValuateDB.Options
ValuateScales = ValuateDB.Scales
```

These are **references**, not copies. Any modifications to `ValuateOptions` or `ValuateScales` automatically modify the saved `ValuateDB` tables.

## Files Changed

### 1. `Valuate.lua`
- `Initialize()` function now creates `ValuateDB` container
- Creates `ValuateDB.Options` and `ValuateDB.Scales` subtables
- Sets up global references for backward compatibility
- Added `status` command to verify saves are working

### 2. `MinimapButton.lua`
- Removed code that created empty `ValuateOptions` table
- Now relies on `Valuate.lua` to initialize the saved variables

## Testing

1. **Load the addon**: `/reload`
2. **Check status**: `/valuate status`
   - Should show "ValuateDB exists: Yes"
   - Should show "References working: Yes"

3. **Create/modify a scale**:
   - Open UI with `/valuate`
   - Add or modify a scale
   - Note the name

4. **Reload**: `/reload`

5. **Verify persistence**: `/valuate scales`
   - Your scale should still be there!

## Debug Commands

- `/valuate status` - Shows SavedVariables status
- `/valuate scales` - Lists all saved scales
- `/valuate debug` - Toggles debug mode

## Technical Details

### Why This Works
- WoW saves all variables listed in `## SavedVariables:` to `WTF/Account/.../SavedVariables/Valuate.lua`
- By storing everything inside `ValuateDB`, all data persists
- Using Lua references (not copies) ensures changes are saved
- The rest of the codebase continues to work unchanged

### Data Structure
```lua
ValuateDB = {
    Options = {
        debug = false,
        decimalPlaces = 1,
        rightAlign = false,
        showScaleValue = true,
        comparisonMode = "number",
        minimapButtonHidden = false,
        minimapButtonAngle = 200,
        -- ... other options
    },
    Scales = {
        ["ScaleName"] = {
            DisplayName = "My Scale",
            Color = "FF0000",
            Visible = true,
            Icon = "Interface\\Icons\\...",
            Values = {
                Strength = 100,
                Agility = 50,
                -- ... stat weights
            },
            Unusable = {
                IsWand = true,
                -- ... banned stats
            }
        },
        -- ... more scales
    }
}
```

## Migration
Existing users will automatically migrate because:
1. First load after update: `ValuateDB` doesn't exist yet
2. Code creates new `ValuateDB` with fresh defaults
3. User configures their scales
4. Next reload: `ValuateDB` exists, loads their data

**Note**: Any scales/settings from before this fix will be lost on the first load. Users will need to reconfigure or re-import their scales.

## Version
This fix was implemented in version 0.5.0+ (after the SavedVariables issue was discovered).


