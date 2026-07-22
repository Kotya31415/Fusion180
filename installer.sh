#!/bin/bash

set -e


# =========================
# Colors
# =========================

GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"


ok()
{
    echo -e "${GREEN}[✓]${RESET} $1"
}


fail()
{
    echo -e "${RED}[✗]${RESET} $1"
    exit 1
}


info()
{
    echo -e "${CYAN}[>]${RESET} $1"
}



clear


# =========================
# Logo
# =========================

echo -e "${BLUE}"

cat <<'EOF'

   ______          _              __   ____    _____
  |  ____|        (_)            /_ | /  _  \ /  _  \
  | |__ _   _ ___  _  ___  _ __   | | \ (_) / | | | |
  |  __| | | / __|| |/ _ \| '_ \  | | /  _  \ | | | |
  | |  | |_| \__ \| | (_) | | | | | ||  (_)  || |_| |
  |_|   \__,_|__ /|_|\___/|_| |_| |_| \_ ___/ \_____/

             Fusion 360 Linux Installer

                 GE-Proton Edition

EOF

echo -e "${RESET}"


# =========================
# Variables
# =========================


PREFIX="$HOME/.fusion360-proton2"

STEAM="$HOME/.local/share/Steam"

PROTON="$STEAM/compatibilitytools.d/GE-Proton11-1/proton"

INSTALLER="$HOME/Downloads/Fusion Client Downloader.exe"

APPDIR="$HOME/.local/share/applications"



# =========================
# Check environment
# =========================


info "Checking environment"


if command -v steam >/dev/null; then
    ok "Steam detected"
else
    fail "Steam not found"
fi



if [ -f "$PROTON" ]; then
    ok "GE-Proton11-1 detected"
else
    fail "GE-Proton11-1 not found"
fi



if [ -f "$INSTALLER" ]; then
    ok "Fusion Installer detected"
else
    fail "FusionInstaller.exe missing"
fi



# =========================
# Prefix
# =========================


info "Creating Proton prefix"


mkdir -p "$PREFIX"

ok "Prefix created"


# =========================
# Install Fusion360
# =========================


info "Launching Fusion360 installer"


env \
PROTON_USE_WINED3D=0 \
DXVK_ASYNC=1 \
NO_AT_BRIDGE=1 \
WINEDLLOVERRIDES="bcp47langs=" \
STEAM_COMPAT_DATA_PATH="$PREFIX" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM" \
"$PROTON" run "$INSTALLER"



ok "Fusion360 installation finished"



# =========================
# Launcher
# =========================


info "Installing launcher"


cp "$(dirname "$0")/launch-fusion.sh" \
"$HOME/launch-fusion.sh"


chmod +x "$HOME/launch-fusion.sh"


ok "Launcher installed"



# =========================
# URI handlers
# =========================


info "Registering Autodesk URI handlers"


mkdir -p "$APPDIR"



cat > "$APPDIR/adskidmgr-handler.sh" <<'EOF'
#!/bin/bash

PREFIX="$HOME/.fusion360-proton2"
STEAM="$HOME/.local/share/Steam"

PROTON="$STEAM/compatibilitytools.d/GE-Proton11-1/proton"


IDM=$(find "$PREFIX" \
-name AdskIdentityManager.exe \
2>/dev/null | head -n1)


if [ -z "$IDM" ]; then
    exit 1
fi


env \
PROTON_USE_WINED3D=0 \
DXVK_ASYNC=1 \
NO_AT_BRIDGE=1 \
WINEDLLOVERRIDES="bcp47langs=" \
STEAM_COMPAT_DATA_PATH="$PREFIX" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM" \
"$PROTON" run "$IDM" "$1"

EOF



chmod +x "$APPDIR/adskidmgr-handler.sh"



cat > "$APPDIR/adskidmgr.desktop" <<EOF
[Desktop Entry]
Name=Autodesk Identity Manager
Exec=/bin/bash -c "$APPDIR/adskidmgr-handler.sh %u"
Type=Application
MimeType=x-scheme-handler/adskidmgr;
NoDisplay=true
EOF



cat > "$APPDIR/adsk-fusion360.desktop" <<EOF
[Desktop Entry]
Name=Fusion 360 URI Handler
Exec=/bin/bash -c "$HOME/launch-fusion.sh %u"
Type=Application
MimeType=x-scheme-handler/adsk;
NoDisplay=true
EOF



info "Updating desktop database"

update-desktop-database "$APPDIR"

ok "Desktop database updated"

info "Registering MIME handlers"

mkdir -p "$HOME/.config"

MIMEFILE="$HOME/.config/mimeapps.list"


grep -q "^\[Default Applications\]" "$MIMEFILE" 2>/dev/null || {
    echo "[Default Applications]" >> "$MIMEFILE"
}

sed -i '/^x-scheme-handler\/adsk=/d' "$MIMEFILE"
sed -i '/^x-scheme-handler\/adskidmgr=/d' "$MIMEFILE"

cat >> "$MIMEFILE" <<EOF
x-scheme-handler/adsk=adsk-fusion360.desktop;
x-scheme-handler/adskidmgr=adskidmgr.desktop;
EOF

ok "URI handlers registered"



# =========================
# Finish
# =========================


echo

echo -e "${GREEN}"
cat <<'EOF'

======================================

 Fusion 360 Linux installation complete

 Start Fusion 360:

     ~/launch-fusion.sh


======================================

EOF

echo -e "${RESET}"
