#!/usr/bin/env bash
# pve-pulse installer.
# Installs to ~/.local/bin (default) or /usr/local/bin with --system,
# and drops a starter config in ~/.config/pve-pulse/ if there isn't one.
set -eu

PREFIX="${HOME}/.local/bin"
if [ "${1:-}" = "--system" ]; then
    PREFIX="/usr/local/bin"
    [ "$(id -u)" -eq 0 ] || { echo "re-run with sudo for --system install" >&2; exit 1; }
elif [ -n "${1:-}" ]; then
    echo "Usage: install.sh [--system]" >&2; exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$PREFIX/pve-pulse"
APPDIR="${DEST}.d"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pve-pulse"

mkdir -p "$PREFIX" "$APPDIR" "$CONFIG_DIR"
cp "$SRC/pve-pulse.sh" "$APPDIR/"
cp -r "$SRC/lib" "$SRC/demo" "$APPDIR/"
chmod +x "$APPDIR/pve-pulse.sh"

# tiny launcher so `pve-pulse` works from anywhere
printf '#!/bin/sh\nexec "%s/pve-pulse.sh" "$@"\n' "$APPDIR" > "$DEST"
chmod +x "$DEST"

if [ ! -f "$CONFIG_DIR/config" ]; then
    cp "$SRC/config.example" "$CONFIG_DIR/config"
    echo "created $CONFIG_DIR/config (edit it to set your backend)"
else
    echo "config already exists, leaving it alone"
fi

echo "installed: $DEST"
echo "try it:    pve-pulse --demo"
case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *) echo "note: $PREFIX is not in your PATH yet" ;;
esac
