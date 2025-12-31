# Developer Documentation

## Architecture Overview

[To be documented as development progresses]

## Code Structure

### Files

- `Valuate.toc` - Addon metadata and file loading order
- `Valuate.lua` - Core addon functionality
- `StatDefinitions.lua` - Stat regex patterns for tooltip parsing (to be created)
- `ValuateUI.lua` - User interface code (to be created)

## Performance Considerations

- Item caching will be implemented to minimize tooltip parsing overhead
- Lazy evaluation of item scores
- Efficient data structures and minimal string operations

## Testing Guidelines

- Test incrementally as features are added
- Test with standard WotLK items
- Test with Ascension-specific items containing PvE/PvP Power
- Monitor performance during tooltip updates

## Code Style

[To be defined]

## Contribution Guidelines

[To be defined]

