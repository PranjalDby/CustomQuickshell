#!/bin/sh
# Writes the active theme colors where dux shell can read them.
QS="$HOME/.config/quickshell"
OUT="$HOME/.config/dux/colors.env"   # TODO: replace with dux's real config path
mkdir -p "$(dirname "$OUT")"
cp "$QS/state/colors.env" "$OUT"
# TODO: reload dux here, e.g. a command that re-reads its config
