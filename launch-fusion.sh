#!/bin/bash
# Fusion180 launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$HOME/.fusion180"

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fusion180"
PROTON_HOME="${FUSION180_PROTON_DIR:-$(cat "$CONF_DIR/proton_dir" 2>/dev/null)}"
[ -n "$PROTON_HOME" ] || PROTON_HOME="$PREFIX/protons"
PIN="${FUSION180_PROTON:-$(cat "$CONF_DIR/proton" 2>/dev/null)}"
find_protons() {
    find ${PROTON_HOME:+"$PROTON_HOME"} \
        -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' 2>/dev/null
}

PROTON_DIR=""
if [ -n "$PIN" ]; then
    PROTON_DIR=$(find_protons | awk -F/ -v p="$PIN" '$NF==p{print}' | tail -n1)
    [ -n "$PROTON_DIR" ] || echo "Pinned GE-Proton '$PIN' not found; using the newest installed" >&2
fi
if [ -z "$PROTON_DIR" ]; then
    PROTON_DIR=$(find_protons | awk -F/ '{print $NF "\t" $0}' | sort -s -V -k1,1 | tail -n1 | cut -f2-)
fi
if [ ! -x "$PROTON_DIR/proton" ]; then
    echo "GE-Proton not found (looked in: ${PROTON_HOME:-<not set>})." >&2
    echo "Run ./deps.sh in the Fusion180 folder first." >&2
    exit 1
fi
PROTON="$PROTON_DIR/proton"

PYLIB="$HOME/.local/share/fusion180/pylib"
if [ -d "$PYLIB" ]; then
    export PYTHONPATH="$PYLIB${PYTHONPATH:+:$PYTHONPATH}"
fi
python3 -u "$SCRIPT_DIR/fusion-window-fix.py" &
FIX_PID=$!

trap 'kill "$FIX_PID" 2>/dev/null' EXIT

export PROTON_USE_WINED3D=0
export DXVK_ASYNC=1
export NO_AT_BRIDGE=1
export WINEDLLOVERRIDES="bcp47langs="
export PROTON_USE_XALIA=0

export STEAM_COMPAT_DATA_PATH="$PREFIX"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$PREFIX"

if [ "$1" = "--dpi" ]; then
    FUSION180_DPI="$2"
    shift 2
fi
if [ -n "$FUSION180_DPI" ]; then
    case "$FUSION180_DPI" in
        ''|*[!0-9]*) echo "Invalid DPI: $FUSION180_DPI (use a number such as 120, 144, 192)"; exit 1 ;;
    esac
    if [ -d "$PREFIX/pfx/drive_c" ]; then
        "$PROTON" run reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$FUSION180_DPI" /f >/dev/null 2>&1
    fi
fi

for v in "${FUSION180_SYS_DRM:-/sys/class/drm}"/card[0-9]*/device/vendor; do
    [ -r "$v" ] || continue
    if [ "$(cat "$v" 2>/dev/null)" = "0x1002" ]; then
        export AMD_VULKAN_ICD="${AMD_VULKAN_ICD:-RADV}"
        break
    fi
done

# fcitx5 / ibus
if [ -z "$XMODIFIERS" ]; then
    if pgrep -x fcitx5 >/dev/null; then
        export XMODIFIERS="@im=fcitx"
    elif pgrep -x ibus-daemon >/dev/null; then
        export XMODIFIERS="@im=ibus"
    fi
fi

if [ -d "$PREFIX/pfx/drive_c" ]; then
    QL="$PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Internet Explorer/Quick Launch"
    mkdir -p "$QL/User Pinned/ImplicitAppShortcuts" "$QL/User Pinned/TaskBar"
fi

FUSION=$(find "$PREFIX/pfx" -name Fusion360.exe -printf '%T@ %p\n' 2>/dev/null \
    | sort -n | tail -n1 | cut -d' ' -f2-)

if [ -z "$FUSION" ]; then
    echo "Fusion360.exe not found"
    exit 1
fi

if [ $# -gt 0 ]; then
    "$PROTON" run "$FUSION" "$@"
else
    "$PROTON" run "$FUSION"
fi
