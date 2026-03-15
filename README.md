# Barrows helper

Bolt plugin for RuneScape Barrows runs.

It highlights the six overworld Barrows dig spots and tracks their state in memory during the current run.

## What it does

- Shows all six Barrows grave markers.
- Uses yellow for untouched graves.
- Uses green for completed graves.
- Uses blue for the grave that contains the tunnel.
- Automatically marks a grave as completed after the dig transition.
- Detects the tunnel grave from the in-game conversation prompt.
- Resets all state when the player returns to the configured reset area.

## Current reset area

The plugin resets when the player is within 10 tiles of:

- chunk `55, 151`
- local tile `32, 30`

If you want a different reset location, change the reset constants in [main.lua](c:/Users/Tadus/Desktop/bolt-barrows/main.lua).

## Installation

Install URL: not published yet.

This plugin is currently local-only, so there is no public Bolt install URL yet.

## Updating

Once this plugin is published, this section should point to the plugin URL only.

## Notes

- State is stored only in memory for the current session.
- Tunnel detection depends on the Barrows prompt being visible on screen.
- Marker colors and grave positions can be adjusted in [main.lua](c:/Users/Tadus/Desktop/bolt-barrows/main.lua).

## Credits

- The bundled `lib/` marker code is based on J3sven's Bolt markers demo: https://github.com/J3sven/bolt-markers-demo
- The bundled `modules/bolt-conversationmodule/` code comes from the Bolt conversation module used by JasperSurmont's Bolt Quest Helper: https://codeberg.org/JasperSurmont/bolt-questhelper

## License notes

- `lib/` comes from a repository published under the MIT license.
- `modules/bolt-conversationmodule/` includes GPL-3.0 licensed code.

If you publish this repository, you should keep those upstream credits visible and make sure your repository license is compatible with the shipped GPL-3.0 module.