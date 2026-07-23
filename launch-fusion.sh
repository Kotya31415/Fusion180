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


export PROTON_USE_WINED3D=0
export DXVK_ASYNC=1
export NO_AT_BRIDGE=1
export WINEDLLOVERRIDES="bcp47langs="

export STEAM_COMPAT_DATA_PATH="$PREFIX"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"



FUSION=$(find "$PREFIX" \
-name Fusion360.exe \
2>/dev/null | head -n1)



if [ -z "$FUSION" ]; then
    echo "Fusion360.exe not found"
    exit 1
fi



"$PROTON" run "$FUSION" "$1"
