# Wallpaper → ASUS Keyboard RGB (DMS + Matugen)

This integration uses DankMaterialShell's existing wallpaper-change → Matugen flow.
It does **not** run a second wallpaper watcher and does not change the wallpaper manager.

## Requirements

- DankMaterialShell (DMS) with Matugen integration enabled
- Matugen 4.x
- `asusctl` with working Aura support
- ASUS keyboard RGB already tested with:
  `asusctl aura effect static -c 9900ff`

## Install

Extract the archive, then run:

```bash
cd wallpaper-keyboard-rgb
chmod +x install.sh uninstall.sh
./install.sh
```

The installer:
- copies a Matugen template to `~/.config/matugen/templates/keyboard-rgb.txt`
- installs an apply script to `~/.local/bin/`
- backs up your existing `~/.config/matugen/config.toml`
- appends a `[templates.keyboard_rgb]` entry with a Matugen `post_hook`

It will not overwrite an existing `[templates.keyboard_rgb]` section.

## How it works

1. DMS detects a wallpaper change and invokes Matugen.
2. Matugen renders `colors.primary.default.hex` into
   `~/.cache/wallpaper-keyboard-rgb/color`.
3. Matugen's template `post_hook` runs the apply script.
4. The script validates the six-digit HEX value and calls:
   `asusctl aura effect static -c RRGGBB`
5. Repeated identical colors are skipped.

## Enable DMS dynamic theming

Make sure Matugen/dynamic theming is enabled in DMS settings. DMS documents that it runs Matugen on wallpaper changes and supports custom Matugen templates in `~/.config/matugen/config.toml`.

## Test

Change the wallpaper using DMS. Then inspect:

```bash
cat ~/.cache/wallpaper-keyboard-rgb/color
cat ~/.cache/wallpaper-keyboard-rgb/last-applied
tail -n 30 ~/.cache/wallpaper-keyboard-rgb/sync.log
```

You can also test the hardware apply script directly after a Matugen run:

```bash
~/.local/bin/wallpaper-keyboard-rgb-apply
```

## Troubleshooting

- If no color file is generated, check that DMS Matugen integration is enabled and inspect Matugen/DMS logs.
- If the template is not processed, verify that the custom template section exists in `~/.config/matugen/config.toml`.
- If Aura fails, run `asusctl aura effect static -c 9900ff` manually and check `asusd.service`.
- The script log is `~/.cache/wallpaper-keyboard-rgb/sync.log`.

## Uninstall

From the extracted package directory:

```bash
./uninstall.sh
```

The uninstall script removes only the marked config block and files installed by this package. It leaves config backups untouched.
