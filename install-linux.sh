#!/usr/bin/env bash
#
# Installs an already-built NokaGram binary for the current user, so the
# desktop treats it as a normal installed app: app-menu entry with its own
# icon, tg:// link handling, launchable by typing `NokaGram`. No root, no
# distro package - everything goes under the XDG user dirs (~/.local), which
# every Linux desktop (GNOME, KDE, ...) reads regardless of distro.
#
# This does NOT build anything - run build-linux.sh first. Re-run this
# script any time after rebuilding to refresh the installed copy.
#
# Usage:
#   ./install-linux.sh [path-to-NokaGram-binary]
#
# Without an argument, picks the first binary found among:
#   out-docker/Release, out-docker/Debug, out/Release, out/Debug
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_SRC="${1:-}"
if [ -z "$BIN_SRC" ]; then
    for candidate in \
        "$ROOT/out-docker/Release/NokaGram" \
        "$ROOT/out-docker/Debug/NokaGram" \
        "$ROOT/out/Release/NokaGram" \
        "$ROOT/out/Debug/NokaGram"
    do
        if [ -f "$candidate" ]; then BIN_SRC="$candidate"; break; fi
    done
fi
if [ -z "$BIN_SRC" ] || [ ! -f "$BIN_SRC" ]; then
    echo "[ERROR] No built NokaGram binary found under out-docker/ or out/." >&2
    echo "        Build first (./build-linux.sh), or pass the binary path explicitly." >&2
    exit 1
fi

ART_DIR="$ROOT/Telegram/Resources/NokaGram/art"
XDG_DIR="$ROOT/lib/xdg"
BIN_DST="$HOME/.local/bin/NokaGram"

echo "Installing $BIN_SRC -> $BIN_DST"
mkdir -p "$HOME/.local/bin"
install -m 755 "$BIN_SRC" "$BIN_DST"

echo "Installing icons"
for size in 16 32 48 64 128 256 512; do
    dir="$HOME/.local/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$dir"
    install -m 644 "$ART_DIR/icon${size}.png" "$dir/org.nokagram.desktop.png"
done

echo "Installing desktop entry"
mkdir -p "$HOME/.local/share/applications"
# Exec/TryExec ship as bare "NokaGram", relying on ~/.local/bin being on
# $PATH - true on most modern distros but not guaranteed everywhere, and the
# desktop environment resolves Exec= itself rather than through a login
# shell's PATH. Pin it to the absolute path so the launcher works regardless.
# Only touch Exec=/TryExec= lines - "Name=NokaGram" must stay as-is.
#
# Also drop DBusActivatable=true: it makes launchers try D-Bus activation
# first, which needs the session dbus-daemon to see this user's
# ~/.local/share/dbus-1/services (via $XDG_DATA_DIRS/$XDG_DATA_HOME) - not
# reliable on every session setup, and when it isn't found the launcher
# fails outright with "The name is not activatable" instead of falling back
# to Exec=. A plain Exec= launch always works, so prefer that unconditionally.
sed -E \
    -e "s#^(Exec|TryExec)=NokaGram#\1=$BIN_DST#" \
    -e '/^DBusActivatable=/d' \
    "$XDG_DIR/org.nokagram.desktop.desktop" \
    > "$HOME/.local/share/applications/org.nokagram.desktop.desktop"
chmod 644 "$HOME/.local/share/applications/org.nokagram.desktop.desktop"

echo "Installing D-Bus service (tg:// activation)"
mkdir -p "$HOME/.local/share/dbus-1/services"
sed "s#@CMAKE_INSTALL_FULL_BINDIR@#$HOME/.local/bin#" \
    "$XDG_DIR/org.nokagram.desktop.service" \
    > "$HOME/.local/share/dbus-1/services/org.nokagram.desktop.service"

if [ -f "$XDG_DIR/org.nokagram.desktop.metainfo.xml" ]; then
    mkdir -p "$HOME/.local/share/metainfo"
    install -m 644 "$XDG_DIR/org.nokagram.desktop.metainfo.xml" "$HOME/.local/share/metainfo/"
fi

command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$HOME/.local/share/applications" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 || true
command -v kbuildsycoca5 >/dev/null 2>&1 && kbuildsycoca5 || true

echo ""
echo "Installed. Run 'NokaGram', or find it in your application menu"
echo "(you may need to log out/in once for the menu to pick it up)."
