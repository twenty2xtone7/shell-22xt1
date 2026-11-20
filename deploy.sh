#!/bin/bash
# Deploy this fork to the user config dir so `caelestia shell` (qs -c caelestia)
# runs it, and refresh the built C++ plugin modules it imports.
#
# Rootless and reversible: nothing outside $HOME is touched.
#   rollback: rm -rf ~/.config/quickshell/caelestia
#             (qs then falls back to /etc/xdg/quickshell/caelestia)
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
QMLOUT="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/qml"

# Dirty by default: ninja only rebuilds what changed. Pass --clean for a full rebuild (e.g. after
# touching CMakeLists or when the build tree looks stale).
for arg in "$@"; do
    case "$arg" in
    -c | --clean) rm -rf "$SRC/build" ;;
    -h | --help)
        sed -n '2,10p' "$0"
        exit 0
        ;;
    *)
        echo "unknown argument: $arg (try --clean)" >&2
        exit 2
        ;;
    esac
done

# 1. Build the C++ plugin (incremental; no-op when unchanged)
cmake -S "$SRC" -B "$SRC/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DINSTALL_QMLDIR=.
ninja -j "${JOBS:-3}" -C "$SRC/build"

# 2. Install the plugin's QML modules where shell.qml's pragma will point.
#    cmake --install (not a plain copy) rewrites the rpath to $ORIGIN/lib, which
#    is what makes the modules movable out of the build tree.
rm -rf "$QMLOUT"
cmake --install "$SRC/build" --prefix "$QMLOUT" >/dev/null
rm -rf "$QMLOUT/etc" "$QMLOUT/lib"

# 3. Deploy the QML tree
mkdir -p "$DEST"
for d in assets components daemons modules services utils; do
    rsync -a --delete "$SRC/$d/" "$DEST/$d/"
done
cp "$SRC/shell.qml" "$SRC/manifest.toml" "$DEST/"

# 4. Bake the plugin path into the deployed shell.qml
sed -i "s|__CAELESTIA_QML_IMPORT__|$QMLOUT|g" "$DEST/shell.qml"

echo "deployed $(find "$DEST" -type f | wc -l) files to $DEST"
echo "plugin modules: $QMLOUT/Caelestia"
echo "reload the running shell with: caelestia shell -k; caelestia shell -d"
