# Wallswap

An [Omarchy](https://omarchy.org) shell plugin that keeps your background fresh.
It picks up an image from one of a few good sources on a timer. It's the one
feature of Variety most people want, with none of the rest.

| Source | What you get |
|---|---|
| `apod` | NASA Astronomy Picture of the Day, random from the 30-year archive |
| `bing` | Bing image of the day (last ~2 weeks), in 4K |
| `wikimedia` | Wikimedia Commons picture of the day, random from the last 3 years |
| `wallhaven` | Top SFW wallpapers of the year on wallhaven.cc, optionally filtered by a search |
| `local` | A folder of your own images (default `~/Pictures/Wallpapers`) |

The first four sources are on by default, and the plugin swaps every 60 minutes. Images that are too small or
portrait are skipped, repeats are avoided, and when you are offline it
rotates through the ~40 images it has already cached.

## Install

```bash
omarchy plugin add https://github.com/petrzpav/omarchy-wallswap.git --enable
```

An icon appears in the right side of the bar:

- **Click** – next background now
- **Right-click** – open the current image's source page
- **Middle-click** – keep it: copies the image to
  `~/.config/omarchy/backgrounds/<theme>/`, so it stays in the theme's
  own rotation (`omarchy theme bg next`)
- **Hover** – title, credit and time to the next swap

Settings (sources, interval, minimum width, Wallhaven search, local folder, NASA
API key) are in the bar settings panel, or inline in `~/.config/omarchy/shell.json`:

```json
{ "id": "petrzpav.wallswap", "sources": ["apod", "bing"], "interval": 30 }
```

Changing the theme sets the theme's own background. Wallswap takes over again at
the next swap.

## Command line

The widget only drives `bin/wallswap`, which you can also use directly:

```bash
W=~/.config/omarchy/plugins/petrzpav.wallswap/bin/wallswap
$W next                         # new background now
$W next --sources apod          # ...from a specific source
$W info                         # current image as JSON
$W open | keep | sources | help
```

Keybinding example (`~/.config/hypr/bindings.lua`):

```lua
o.bind("SUPER + ALT + B", "Next background", "~/.config/omarchy/plugins/petrzpav.wallswap/bin/wallswap next")
```

Files: images are cached in `~/.cache/wallswap/` and state is kept in `~/.local/state/wallswap/`.

Requires `curl`, `jq` and ImageMagick (all present on Omarchy).

## License

MIT
