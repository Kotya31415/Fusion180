#!/bin/bash

set -e

STEAM="$HOME/.local/share/Steam"

PROTON_DIR=$(find "$STEAM/compatibilitytools.d" \
    -maxdepth 1 \
    -type d \
    -name "GE-Proton*" \
    | sort -V \
    | tail -n1)

if [ -z "$PROTON_DIR" ]; then
    echo "GE-Proton not found" >&2
    exit 1
fi

VERSION=$(basename "$PROTON_DIR")
echo "GE-Proton version: $VERSION"
