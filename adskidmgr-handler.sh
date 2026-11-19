#!/bin/bash
# Autodesk Identity Manager (adskidmgr://) handler for Fusion180

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
fi
if [ -z "$PROTON_DIR" ]; then
    PROTON_DIR=$(find_protons | awk -F/ '{print $NF "\t" $0}' | sort -s -V -k1,1 | tail -n1 | cut -f2-)
fi
[ -x "$PROTON_DIR/proton" ] || exit 1
PROTON="$PROTON_DIR/proton"

IDM=$(find "$PREFIX/pfx" -name AdskIdentityManager.exe -printf '%T@ %p\n' 2>/dev/null \
    | sort -n | tail -n1 | cut -d' ' -f2-)

if [ -z "$IDM" ]; then
    exit 1
fi

env \
PROTON_USE_WINED3D=0 \
DXVK_ASYNC=1 \
NO_AT_BRIDGE=1 \
WINEDLLOVERRIDES="bcp47langs=" \
PROTON_USE_XALIA=0 \
STEAM_COMPAT_DATA_PATH="$PREFIX" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$PREFIX" \
"$PROTON" run "$IDM" "$1"
