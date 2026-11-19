#!/usr/bin/env bash

VERSION="0.3.0"
PREFIX="$HOME/.fusion180"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fusion180"
PROTON_HOME="${FUSION180_PROTON_DIR:-$(cat "$CONF_DIR/proton_dir" 2>/dev/null)}"
[ -n "$PROTON_HOME" ] || PROTON_HOME="$PREFIX/protons"
PYLIB="$HOME/.local/share/fusion180/pylib"
OUT="${1:-$HOME/fusion180-doctor-$(date +%Y%m%d-%H%M%S).txt}"

{
    echo "Fusion180 Doctor Report"
    echo "Generated: $(date -Iseconds)"
    echo "Version: $VERSION"
    echo

    echo "## System"
    uname -a
    [ -r /etc/os-release ] && grep -E '^(NAME|VERSION)=' /etc/os-release
    echo "DISPLAY=${DISPLAY:-unset}"
    echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}"
    echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
    echo

    echo "## Prefix"
    if [ -d "$PREFIX" ]; then
        echo "Prefix: $PREFIX (exists)"
        fusion_exe=$(find "$PREFIX/pfx" -name Fusion360.exe -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n1 | cut -d' ' -f2-)
        echo "Fusion360.exe: ${fusion_exe:-not found}"
        echo "dxvk.conf: $([ -f "$PREFIX/dxvk.conf" ] && echo present || echo 'not present')"
    else
        echo "Prefix: $PREFIX (not found — installer.sh has not been run, or it was removed)"
    fi
    echo

    echo "## GE-Proton"
    echo "Proton home: $PROTON_HOME"
    if [ -d "$PROTON_HOME" ]; then
        versions=$(find "$PROTON_HOME" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' -printf '%f\n' 2>/dev/null | sort -V)
        if [ -n "$versions" ]; then
            echo "Installed versions:"
            echo "$versions" | sed 's/^/  - /'
            echo "Newest (used by default): $(echo "$versions" | tail -n1)"
        else
            echo "Installed versions: none"
        fi
    else
        echo "Installed versions: none (folder does not exist)"
    fi
    pin="${FUSION180_PROTON:-$(cat "$CONF_DIR/proton" 2>/dev/null)}"
    echo "Pinned version: ${pin:-none (newest is used)}"
    echo

    echo "## Launcher and handlers"
    for f in "$HOME/launch-fusion.sh" "$HOME/fusion-window-fix.py" \
             "$HOME/.local/share/applications/adskidmgr-handler.sh" \
             "$HOME/.local/share/applications/adskidmgr.desktop" \
             "$HOME/.local/share/applications/adsk-fusion360.desktop"; do
        echo "$f: $([ -f "$f" ] && echo present || echo MISSING)"
    done
    if [ -f "$HOME/.config/mimeapps.list" ]; then
        grep -E '^x-scheme-handler/(adsk|adskidmgr)=' "$HOME/.config/mimeapps.list" || echo "mimeapps.list: no adsk entries"
    else
        echo "mimeapps.list: not present"
    fi
    echo

    echo "## Python / python-xlib (window-fix helper)"
    if command -v python3 >/dev/null 2>&1; then
        echo "python3: $(command -v python3)"
        if python3 -c 'import Xlib' >/dev/null 2>&1; then
            echo "python-xlib: ok (system)"
        elif PYTHONPATH="$PYLIB" python3 -c 'import Xlib' >/dev/null 2>&1; then
            echo "python-xlib: ok (private pylib: $PYLIB)"
        else
            echo "python-xlib: MISSING (run ./deps.sh)"
        fi
    else
        echo "python3: MISSING"
    fi
    echo

    echo "## GPU / Vulkan"
    for d in "${FUSION180_SYS_DRM:-/sys/class/drm}"/card[0-9]*/device; do
        [ -r "$d/vendor" ] || continue
        vendor=$(cat "$d/vendor")
        drv=$(basename "$(readlink -f "$d/driver" 2>/dev/null)" 2>/dev/null)
        case "$vendor" in
            0x10de) name="NVIDIA" ;;
            0x1002) name="AMD" ;;
            0x8086) name="Intel" ;;
            *)      name="unknown ($vendor)" ;;
        esac
        echo "GPU: $name (kernel driver: ${drv:-none})"
    done
    if command -v vulkaninfo >/dev/null 2>&1; then
        echo "Vulkan devices:"
        vulkaninfo --summary 2>/dev/null | awk -F'= ' '/deviceName/{print "  - " $2}'
    else
        echo "Vulkan devices: could not check (vulkaninfo / vulkan-tools not installed)"
    fi
    echo

    echo "## Notes"
    echo "Steam is not used by this version of Fusion180."
    echo "GE-Proton is downloaded by deps.sh / installer.sh from GitHub into the Proton home above."
} > "$OUT"

echo "Doctor report written: $OUT"
