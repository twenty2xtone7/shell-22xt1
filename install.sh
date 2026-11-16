#!/bin/sh
# Installer for the fully rebuilt Caelestia fork.
#
#   ./install.sh                 install from this checkout
#   ./install.sh --repo URL      clone URL, then install
#   ./install.sh --uninstall     remove the deployed shell
#
# What it does, and nothing else:
#   1. builds the C++ plugin from this tree
#   2. installs the plugin's QML modules into <config>/quickshell/caelestia/Caelestia
#      (Quickshell adds the config dir to the QML import path, so no root install
#      and no QML_IMPORT_PATH are needed)
#   3. copies the QML tree next to them
#
# It never touches ~/.config/hypr, never installs packages, never calls sudo.
set -eu

REPO=""
SRC=""
UNINSTALL=0
JOBS="${JOBS:-3}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CONF/quickshell/caelestia"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/fork"

while [ $# -gt 0 ]; do
    case "$1" in
        --repo) REPO="$2"; shift 2 ;;
        --src) SRC="$2"; shift 2 ;;
        --jobs) JOBS="$2"; shift 2 ;;
        --uninstall) UNINSTALL=1; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [ "$UNINSTALL" = 1 ]; then
    rm -rf "$DEST" "$SHARE"
    echo "removed $DEST"
    echo "quickshell now falls back to /etc/xdg/quickshell/caelestia if present"
    echo "restart the shell with: qs kill -c caelestia 2>/dev/null; caelestia shell -d"
    exit 0
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }
need git
need cmake
need ninja
need qs

# Resolve the source tree: next to this script, or cloned from --repo
if [ -z "$SRC" ]; then
    HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd || echo "")
    if [ -n "$HERE" ] && [ -f "$HERE/shell.qml" ] && [ -f "$HERE/manifest.toml" ]; then
        SRC="$HERE"
    elif [ -n "$REPO" ]; then
        if [ -d "$SHARE/.git" ]; then
            git -C "$SHARE" fetch --depth 1 origin && git -C "$SHARE" reset --hard origin/HEAD
        else
            mkdir -p "$(dirname "$SHARE")"
            git clone --depth 1 "$REPO" "$SHARE"
        fi
        SRC="$SHARE"
    else
        echo "run this from the fork checkout, or pass --repo <git-url>" >&2
        exit 1
    fi
fi

echo "==> building C++ plugin in $SRC"
cmake -S "$SRC" -B "$SRC/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DINSTALL_QMLDIR=. >/dev/null
ninja -j "$JOBS" -C "$SRC/build" | tail -3

echo "==> deploying to $DEST"
mkdir -p "$DEST"
cmake --install "$SRC/build" --prefix "$DEST" >/dev/null
# cmake also drops a copy of the QML tree under ./etc; the deploy below owns that
rm -rf "$DEST/etc"

for d in assets components daemons modules services utils; do
    [ -d "$SRC/$d" ] || continue
    mkdir -p "$DEST/$d"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$SRC/$d/" "$DEST/$d/"
    else
        rm -rf "$DEST/$d" && cp -r "$SRC/$d" "$DEST/$d"
    fi
done
cp "$SRC/shell.qml" "$DEST/shell.qml"
if [ -f "$SRC/manifest.toml" ]; then
    cp "$SRC/manifest.toml" "$DEST/manifest.toml"
fi

echo "==> deployed $(find "$DEST" -type f | wc -l) files"
echo "    plugin modules: $DEST/Caelestia"
echo
echo "run it:     caelestia shell -k 2>/dev/null; caelestia shell -d"
echo "uninstall:  $0 --uninstall"
