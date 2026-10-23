#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$HOME/.fusion180"
STEAM="$HOME/.local/share/Steam"

PROTON=$(find "$STEAM/compatibilitytools.d" \
    -maxdepth 1 \
    -type d \
    -name "GE-Proton*" \
    | sort -V \
    | tail -n1)

PROTON="$PROTON/proton"

python3 "$SCRIPT_DIR/fusion-window-fix.py" &
FIX_PID=$!

trap 'kill "$FIX_PID" 2>/dev/null' EXIT

export PROTON_USE_WINED3D=0
export DXVK_ASYNC=1
export NO_AT_BRIDGE=1
export WINEDLLOVERRIDES="bcp47langs="
export PROTON_USE_XALIA=0

export STEAM_COMPAT_DATA_PATH="$PREFIX"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"

if [ -d "$PREFIX/pfx/drive_c" ]; then
    QL="$PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Internet Explorer/Quick Launch"
    mkdir -p "$QL/User Pinned/ImplicitAppShortcuts" "$QL/User Pinned/TaskBar"
fi

FUSION=$(find "$PREFIX" -name Fusion360.exe -printf '%T@ %p\n' 2>/dev/null \
    | sort -n | tail -n1 | cut -d' ' -f2-)

if [ -z "$FUSION" ]; then
    echo "Fusion360.exe not found"
    exit 1
fi



"$PROTON" run "$FUSION" "$1"
