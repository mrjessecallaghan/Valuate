# Ascension WoW Bronzebeard Development Knowledge

This document accumulates knowledge about developing addons specifically for WoW Ascension Bronzebeard server.

## Client Information

- **Base Client**: Wrath of the Lich King (WotLK) 3.3.5a
- **Interface Version**: 30300
- **Server**: Ascension Bronzebeard

## Custom Features

### Custom Stats

#### PvE Power
- **Tooltip Text Pattern**: `"Equip: Increases PvE Power by %d+."`
- **Regex Pattern**: `"^Equip: Increases PvE Power by (%d+)%.$"`
- **Internal Name**: `PVEpower`
- **Description**: Improves efficiency in PvE content

#### PvP Power
- **Tooltip Text Pattern**: `"Equip: Increases PvP Power by %d+."`
- **Regex Pattern**: `"^Equip: Increases PvP Power by (%d+)%.$"`
- **Internal Name**: `PVPpower`
- **Description**: Improves efficiency in PvP, but gives a performance debuff in PvE content

## API Compatibility

- Standard WotLK 3.3.5a APIs work as expected
- No special client modifications needed beyond parsing custom stat text
- Tooltip parsing using `SetHyperlink()` and tooltip scanning works normally

## Discoveries

[To be updated as we learn more during development]

## Best Practices

[To be documented as we learn]

