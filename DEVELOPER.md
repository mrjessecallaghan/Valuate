# Developer Documentation

## Development Workflow

### Safety Checkpoints

**Rule: After every working code feature update, push a safety checkpoint to GitHub.**

This ensures we can easily revert to a working state if we break something. The workflow is:

1. Implement a feature
2. Test that it works in-game
3. Commit the changes with a descriptive message
4. **Push to GitHub** (creates a checkpoint)
5. Move on to the next feature

### Git Workflow

- Always commit working code before starting experimental changes
- Use descriptive commit messages (e.g., "Add stat parsing system", "Fix tooltip display bug")
- Push to GitHub after each working feature is complete
- If something breaks, we can revert using GitHub Desktop or `git reset --hard [commit-hash]`

### Branch Strategy (Optional)

For experimental features, consider creating a branch:
```bash
git checkout -b experimental-feature
# Make changes
git commit -m "Experimental: trying new approach"
# If it works: git checkout master; git merge experimental-feature
# If it doesn't: git checkout master (discard branch)
```

## Architecture Overview

[To be documented as development progresses]

## Code Structure

### Files

- `Valuate.toc` - Addon metadata and file loading order
- `Valuate.lua` - Core addon functionality
- `StatDefinitions.lua` - Stat regex patterns for tooltip parsing (to be created)
- `ValuateUI.lua` - User interface code (to be created)

### Current Modules

#### Stat Parsing System
- **Location**: `Valuate.lua` and `StatDefinitions.lua`
- **Purpose**: Parse item stats from tooltips using regex patterns
- **Functions**: `ParseStatsFromTooltip()`, `GetStatsForItemLink()`, `GetStatsFromDisplayedTooltip()`

#### Scale System
- **Location**: `Valuate.lua`
- **Purpose**: Calculate item scores based on stat weights
- **Functions**: `CalculateItemScore()`, `GetActiveScales()`, `CreateDefaultScale()`

## Performance Considerations

- Tooltip parsing is done on-demand when hovering items
- Always read configuration values directly (don't cache in local variables that can become stale)

## Testing Guidelines

- Test incrementally as features are added
- Use `/valuate test [itemlink]` to verify stat parsing
- Test with standard WotLK items
- Test with Ascension-specific items containing PvE/PvP Power
- Monitor performance during tooltip updates

## Code Style

- Use descriptive function names (e.g., `GetStatsForItemLink`)
- Use camelCase for function names
- Use local variables for internal functions/data
- Always handle nil cases (use `or` defaults where appropriate)
- Comment complex logic

## Contribution Guidelines

[To be defined]
