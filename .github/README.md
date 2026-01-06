# Valuate
Stat weight item scoring for World of Warcraft: Ascension Bronzebeard (WotLK 3.3.5a).

<p align="center">
  <img src=".github/assets/screenshots/IMG_4234.png" width="900" alt="Valuate banner">
</p>

## What it does
Valuate calculates an item score from your stat weights and shows it in tooltips and UI so you can quickly judge upgrades for your character and playstyle.

## Highlights
- Custom stat weight scales for your build
- Clear item scoring in tooltips
- Import and export scales to share setups
- Per-character profiles (v0.7.0+) so each character keeps independent settings and scales
- Lightweight and built for fast decisions while looting and comparing gear

## Screenshots
<p align="center">
  <img src=".github/assets/screenshots/IMG_4235.png" width="430" alt="Valuate UI">
  <img src=".github/assets/screenshots/IMG_4236.png" width="430" alt="Valuate tooltip scoring">
</p>

<p align="center">
  <img src=".github/assets/screenshots/IMG_4237.png" width="430" alt="Valuate options and settings">
  <img src=".github/assets/screenshots/IMG_4238.png" width="430" alt="Valuate scales and profiles">
</p>

<p align="center">
  <img src=".github/assets/screenshots/IMG_4239.png" width="430" alt="Example scoring and display">
  <img src=".github/assets/screenshots/IMG_4240.png" width="430" alt="Example tooltip display">
</p>

<p align="center">
  <img src=".github/assets/screenshots/IMG_4241.png" width="430" alt="Example UI display">
  <img src=".github/assets/screenshots/IMG_4242.png" width="430" alt="Example tooltip display">
</p>

## Install
1. Download the latest release:
   - https://github.com/mrjessecallaghan/Valuate/releases
2. Extract the folder into your AddOns directory.
   - For most WotLK clients: `World of Warcraft/Interface/AddOns/`
3. Confirm the final path looks like:
   - `.../Interface/AddOns/Valuate/Valuate.toc`
4. Launch the game and enable **Valuate** in the AddOns list.

## Quick start
- Open Valuate: `/valuate`
- Create or edit a scale in the UI
- Hover an item to see the score in the tooltip

### Import and export
- Export a scale:
  - `/valuate export ScaleName`
- Import a scale:
  - `/valuate import`
  - Paste the scale tag you were given

## Profiles (v0.7.0+)
Valuate uses per-character saved variables so each character has their own scales and settings.

What this means:
- Changes on one character do not affect your other characters
- UI position and preferences are saved per character
- Use Import/Export if you want to share a scale between characters

### Upgrade note for existing users
If you upgraded to v0.7.0 or later and want to clean up old account-wide data, you can delete the old file after confirming everything works:
- Old account-wide:
  - `WTF-Account/[account]/SavedVariables/Valuate.lua`
- New per-character:
  - `WTF-Account/[account]/[realm]/[character]/SavedVariables/Valuate.lua`

## How scoring works
- Valuate takes each stat on the item and multiplies it by your weight for that stat.
- The sum becomes the item score.
- A score is only as good as your weights.
  - If your weights are wrong, your upgrade decisions will be wrong.

## Troubleshooting
- Scores not showing:
  - Confirm the addon is enabled at character select.
  - Confirm the folder is `Valuate` and contains `Valuate.toc`.
  - Disable other tooltip addons temporarily to check for conflicts.
- Import not working:
  - Make sure you copied the full scale tag.
  - Try pasting into a plain text editor first to remove formatting.

## Roadmap
- Better defaults and example scales
- More tooltip display options and clarity
- Continued polish and performance improvements

## Report a bug or request a feature
Open an issue here:
- https://github.com/mrjessecallaghan/Valuate/issues

Include:
- What you expected vs what happened
- A screenshot if relevant
- Your scale export string if the issue is scoring related
- The exact item link and where it dropped or was viewed

## Development
Docs and notes live in the repo:
- `ASCENSION_DEV.md`
- `DEVELOPER.md`
- `CHANGELOG.md`

## License
Add a LICENSE file if you want formal licensing.
Until then, treat this repository as All Rights Reserved by default.