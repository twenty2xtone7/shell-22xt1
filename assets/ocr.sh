#!/usr/bin/env bash

region=$(slurp)
[ -z "$region" ] && exit 0

# Prefer English, fall back to any installed language so a missing eng pack does not fail silently
lang=$(tesseract --list-langs 2>/dev/null | awk 'NR>1 && $0!="osd"{print; exit}')
[ -z "$lang" ] && lang=$(tesseract --list-langs 2>/dev/null | sed -n '2p')
tesseract --list-langs 2>/dev/null | grep -qx eng && lang=eng

text=$(grim -g "$region" - | tesseract stdin stdout -l "$lang" 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')

if [ -n "$text" ]; then
    printf '%s' "$text" | wl-copy
    notify-send -a caelestia-shell "OCR" "Text copied to clipboard"
else
    notify-send -a caelestia-shell -u low "OCR" "No text detected"
fi
