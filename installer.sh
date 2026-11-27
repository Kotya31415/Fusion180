#!/bin/bash

set -e

# =========================
# Colors
# =========================

GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"


ok()
{
    echo -e "${GREEN}[✓]${RESET} $1"
}


warn()
{
    echo -e "${YELLOW}[!]${RESET} $1"
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

   ______          _              __   _____   _____
  |  ____|        (_)            /_ | /  _  \ /  _  \
  | |__ _   _ ___  _  ___  _ __   | | \ (_) / | | | |
  |  __| | | / __|| |/ _ \| '_ \  | | /  _  \ | | | |
  | |  | |_| \__ \| | (_) | | | | | ||  (_)  || |_| |
  |_|   \__,_|__ /|_|\___/|_| |_| |_| \_____/ \_____/

             Fusion 360 Linux Installer

                 GE-Proton Edition

EOF

echo -e "${RESET}"


# ===========================
# Variables
# ===========================

PREFIX="$HOME/.fusion180"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/deps.sh"

INSTALLER=$(find "$HOME/Downloads" \
    -maxdepth 1 \
    -iname "*Fusion*.exe" \
    | head -n1)


APPDIR="$HOME/.local/share/applications"


# ===========================
# Check environment
# ===========================

info "Checking environment"

ensure_python_xlib
ensure_ge_proton

PROTON_DIR=$(ge_find_installed)
[ -n "$PROTON_DIR" ] || fail "GE-Proton not found"
PROTON="$PROTON_DIR/proton"
ok "Using $(basename "$PROTON_DIR")"

check_proton_libs
check_graphics


if [ -z "$INSTALLER" ]; then
    info "Fusion installer not in ~/Downloads; downloading it from Autodesk"
    mkdir -p "$HOME/Downloads"
    if command -v curl >/dev/null \
        && curl -fL --progress-bar -o "$HOME/Downloads/Fusion Client Downloader.exe" \
            "https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Client%20Downloader.exe" \
        && [ "$(head -c 2 "$HOME/Downloads/Fusion Client Downloader.exe" 2>/dev/null)" = "MZ" ]; then
        INSTALLER="$HOME/Downloads/Fusion Client Downloader.exe"
        ok "Fusion installer downloaded"
    else
        rm -f "$HOME/Downloads/Fusion Client Downloader.exe"
        fail "Fusion installer download failed. Download it manually from https://www.autodesk.com/products/fusion-360/overview and place it in ~/Downloads"
    fi
fi

ok "Fusion Installer detected: $(basename "$INSTALLER")"


# ===========================
# Prefix
# ===========================

info "Creating Proton prefix"

mkdir -p "$PREFIX"

ok "Prefix created"


# ===========================
# Install Fusion360
# ===========================

info "Launching Fusion360 installer"

env \
PROTON_USE_WINED3D=0 \
DXVK_ASYNC=1 \
NO_AT_BRIDGE=1 \
WINEDLLOVERRIDES="bcp47langs=" \
PROTON_USE_XALIA=0 \
STEAM_COMPAT_DATA_PATH="$PREFIX" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$PREFIX" \
"$PROTON" run "$INSTALLER"

ok "Fusion360 installation finished"


# ===========================
# WebView2 runtime
# ===========================

info "Checking the WebView2 runtime (needed by the sign-in window)"

wv2_present()
{
    [ -n "$(find "$PREFIX/pfx" -iname "msedgewebview2.exe" -print -quit 2>/dev/null)" ]
}

if wv2_present; then
    ok "WebView2 runtime found in the prefix"
else
    warn "WebView2 runtime not found in the prefix; the sign-in window cannot work without it"

    WV2_EXE="$HOME/Downloads/MicrosoftEdgeWebView2RuntimeInstallerX64.exe"

    if [ ! -f "$WV2_EXE" ]; then
        info "Downloading the WebView2 standalone installer from Microsoft (about 300 MB)"
        if command -v curl >/dev/null \
            && curl -fL --progress-bar -o "$WV2_EXE" \
                "https://go.microsoft.com/fwlink/p/?LinkId=2124701" \
            && [ "$(head -c 2 "$WV2_EXE" 2>/dev/null)" = "MZ" ]; then
            ok "WebView2 installer downloaded"
        else
            rm -f "$WV2_EXE"
            WV2_EXE=""
            warn "WebView2 download failed"
        fi
    fi

    if [ -n "$WV2_EXE" ] && [ -f "$WV2_EXE" ]; then
        info "Installing the WebView2 runtime to the prefix"

        env \
        PROTON_USE_WINED3D=0 \
        DXVK_ASYNC=1 \
        NO_AT_BRIDGE=1 \
        WINEDLLOVERRIDES="bcp47langs=" \
        PROTON_USE_XALIA=0 \
        STEAM_COMPAT_DATA_PATH="$PREFIX" \
        STEAM_COMPAT_CLIENT_INSTALL_PATH="$PREFIX" \
        "$PROTON" run "$WV2_EXE" /silent /install \
            || warn "The WebView2 installer returned an error"

        if wv2_present; then
            ok "WebView2 runtime installed"
        else
            warn "WebView2 runtime still not detected; sign-in may fail (see the README troubleshooting section)"
        fi
    fi
fi

if [ -d "$PREFIX/pfx/drive_c" ]; then
    "$PROTON" run reg add 'HKCU\Software\Wine\AppDefaults\msedgewebview2.exe' /v Version /t REG_SZ /d win8 /f >/dev/null 2>&1 \
        || warn "Could not set the WebView2 Windows version (continuing)"
fi


# ===========================
# Launcher
# ===========================

info "Installing launcher"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$(dirname "$0")/launch-fusion.sh" \
"$HOME/launch-fusion.sh"
cp "$SCRIPT_DIR/fusion-window-fix.py" \
"$HOME/fusion-window-fix.py"

chmod +x "$HOME/launch-fusion.sh"

ok "Launcher installed"
ok "Fusion window fix installed"


# ===========================
# URI handlers
# ===========================

info "Registering Autodesk URI handlers"


mkdir -p "$APPDIR"


cp "$SCRIPT_DIR/adskidmgr-handler.sh" "$APPDIR/adskidmgr-handler.sh"
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

if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$APPDIR" || warn "update-desktop-database failed (continuing)"
    ok "Desktop database updated"
else
    warn "update-desktop-database not found (skipping)"
fi

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


info "Registering launcher (application menu)"

install_launcher_entry


# ===========================
# Folders fixes
# ===========================

info "Preparing Wine Required folders (needed for Fusion updates)"

if [ -d "$PREFIX/pfx/drive_c" ]; then
    QL="$PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Internet Explorer/Quick Launch"
    mkdir -p "$QL/User Pinned/ImplicitAppShortcuts" "$QL/User Pinned/TaskBar" \
        || info "Could not create known folders (Fusion updates may fail)"
fi

ok "Required folders prepared"


# ===========================
# Finish
# ===========================

echo

if [ -n "${DEPS_BLOCKERS:-}" ]; then
    echo -e "${YELLOW}"
    cat <<EOF

=======================================

Fusion 360 installation complete!

Note: some system libraries are still missing:
  - libgnutls.so.30   (sign-in over HTTPS may fail)
  - libfreetype.so.6  (text may not render)

Please run ./deps.sh and install them.

Then start Fusion :

    ~/launch-fusion.sh

=======================================

EOF
    echo -e "${RESET}"
else
    echo -e "${GREEN}"
    cat <<'EOF'

=======================================

 Fusion 360 installation complete!

 Start Fusion :

     ~/launch-fusion.sh

=======================================

EOF
    echo -e "${RESET}"
fi
