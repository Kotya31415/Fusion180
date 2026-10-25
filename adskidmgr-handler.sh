#!/bin/bash

PREFIX="$HOME/.fusion180"
STEAM="$HOME/.local/share/Steam"

PROTON=$(find "$STEAM/compatibilitytools.d" \
    -maxdepth 1 \
    -type d \
    -name "GE-Proton*" \
    | sort -V \
    | tail -n1)

PROTON="$PROTON/proton"

IDM=$(find "$PREFIX" -name AdskIdentityManager.exe -printf '%T@ %p\n' 2>/dev/null \
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
STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM" \
"$PROTON" run "$IDM" "$1"
