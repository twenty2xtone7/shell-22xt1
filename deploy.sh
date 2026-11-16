#!/bin/bash
# Deploy this fork to the user config dir so `caelestia shell` (qs -c caelestia)
# runs it, and refresh the built C++ plugin modules it imports.
#
# Rootless and reversible: nothing outside $HOME is touched.
#   rollback: rm -rf ~/.config/quickshell/caelestia
#             (qs then falls back to /etc/xdg/quickshell/caelestia)
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config/quickshell/caelestia"
QMLOUT="$HOME/.local/share/caelestia/qml"

# 1. Build the C++ plugin (incremental; no-op when unchanged)
cmake -S "$SRC" -B "$SRC/build" -G Ninja -DCMAKE_BUILD_TYPE=Release
ninja -j 3 -C "$SRC/build"

# 2. Publish the QML modules where shell.qml's QML_IMPORT_PATH points
rm -rf "$QMLOUT"
mkdir -p "$(dirname "$QMLOUT")"
cp -r "$SRC/build/qml" "$QMLOUT"

# 3. Deploy the QML tree
mkdir -p "$DEST"
for d in assets components daemons modules services utils; do
    rsync -a --delete "$SRC/$d/" "$DEST/$d/"
done
cp "$SRC/shell.qml" "$SRC/manifest.toml" "$DEST/"

echo "deployed $(find "$DEST" -type f | wc -l) files to $DEST"
echo "plugin modules: $QMLOUT"
echo "reload the running shell with: caelestia shell -k && caelestia shell -d"
