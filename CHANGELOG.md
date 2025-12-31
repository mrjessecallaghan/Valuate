# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.2.0] - [Current Date]

### Added
- Item cache system (LRU - Least Recently Used)
- Cache management functions (CacheItem, GetCachedItem, ClearCache)
- Cache statistics command (/valuate cache)
- Clear cache command (/valuate clearcache)
- Configurable cache size (default: 150 items)
- Cache disabled in debug mode

### Changed
- Improved slash command help menu

## [0.1.0] - [Initial Release]

### Added
- Initial addon structure
- Basic loading and initialization
- Slash command handler (/valuate, /val)
- Version info command
- Documentation structure (README, CHANGELOG, DEVELOPER, ASCENSION_DEV)

### Notes
- Addon loads successfully
- Cache system provides performance foundation for future features

