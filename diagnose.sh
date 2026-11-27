#!/usr/bin/env bash

VERSION="0.3.2"
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

    echo "## Display"
    echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset}"
    echo "Scale env: GDK_SCALE=${GDK_SCALE:-unset} GDK_DPI_SCALING=${GDK_DPI_SCALING:-unset} QT_SCALE_FACTOR=${QT_SCALE_FACTOR:-unset}"
    if [ -n "${DISPLAY:-}" ] && command -v xrandr >/dev/null 2>&1; then
        echo "Monitors (xrandr: connected outputs and current modes):"
        xrandr --query 2>/dev/null | grep -E ' connected|\*' | head -20 | sed 's/^/  /'
    else
        echo "Monitors: could not check (no DISPLAY or xrandr not installed)"
    fi
    if [ -n "${DISPLAY:-}" ] && command -v xrdb >/dev/null 2>&1; then
        xft=$(xrdb -query 2>/dev/null | awk -F'\t' '$1 == "Xft.dpi:" {print $2}')
        echo "Xft.dpi: ${xft:-not set}"
    fi
    if [ -f "$PREFIX/pfx/user.reg" ]; then
        lp=$(grep -m1 '"LogPixels"=dword:' "$PREFIX/pfx/user.reg" 2>/dev/null | sed 's/.*dword://')
        if [ -n "$lp" ]; then
            echo "Wine LogPixels: $((16#$lp)) dpi (as set in the prefix)"
        else
            echo "Wine LogPixels: not set (Wine default 96 dpi)"
        fi
    fi
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

    echo "## WebView2 (sign-in window)"
    if [ -d "$PREFIX/pfx" ]; then
        wv2_exe=$(find "$PREFIX/pfx" -iname "msedgewebview2.exe" -print -quit 2>/dev/null)
        echo "msedgewebview2.exe: ${wv2_exe:-NOT FOUND (sign-in cannot work — re-run installer.sh or install the WebView2 runtime)}"
        idm_exe=$(find "$PREFIX/pfx" -name "AdskIdentityManager.exe" -print -quit 2>/dev/null)
        echo "AdskIdentityManager.exe: ${idm_exe:-not found}"
        if [ -f "$PREFIX/pfx/system.reg" ]; then
            if grep -F 'F3017226-FE2A-4295-8BDF-00C3A9A7E4C5' "$PREFIX/pfx/system.reg" >/dev/null 2>&1; then
                echo "WebView2 runtime registration (EdgeUpdate): present"
            else
                echo "WebView2 runtime registration (EdgeUpdate): NOT FOUND"
            fi
        else
            echo "WebView2 runtime registration (EdgeUpdate): could not check (no system.reg)"
        fi
        if [ -f "$PREFIX/pfx/user.reg" ]; then
            wv2_ver=$(grep -A2 -F 'AppDefaults\\msedgewebview2.exe' "$PREFIX/pfx/user.reg" 2>/dev/null | grep -F '"Version"' | head -n1)
            echo "msedgewebview2.exe AppDefaults: ${wv2_ver:-not set (the launcher sets Version=win8 at launch)}"
        fi
    else
        echo "Skipped (no prefix)"
    fi
    if [ -f "$HOME/launch-fusion.sh" ]; then
        if grep -F 'PROTON_NO_SECCOMP' "$HOME/launch-fusion.sh" >/dev/null 2>&1; then
            echo "Launcher WebView2 workarounds: present"
        else
            echo "Launcher WebView2 workarounds: NOT present (old launcher — re-run installer.sh to update it)"
        fi
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
             "$HOME/.local/share/applications/adsk-fusion360.desktop" \
             "$HOME/.local/share/applications/fusion180.desktop"; do
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
