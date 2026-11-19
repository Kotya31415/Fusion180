#!/bin/bash
# Fusion180 update script

main() {
    set -e

    GREEN="\033[1;32m"; RED="\033[1;31m"; YELLOW="\033[1;33m"; CYAN="\033[1;36m"; RESET="\033[0m"
    ok()   { echo -e "${GREEN}[✓]${RESET} $1"; }
    info() { echo -e "${CYAN}[>]${RESET} $1"; }
    warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
    fail() { echo -e "${RED}[✗]${RESET} $1"; exit 1; }

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    APPDIR="$HOME/.local/share/applications"
    STAMP="$(date +%Y%m%d-%H%M%S)"

    info "Fetching the latest Fusion180"

    [ -d "$SCRIPT_DIR/.git" ] || fail "This folder is not a git clone.
    Re-install with:  git clone <Fusion180 repository URL>"
    command -v git >/dev/null || fail "git not found"

    OLD=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)
    git -C "$SCRIPT_DIR" pull --ff-only \
        || fail "git pull failed. If you edited files in this folder, save or revert them first (git status)."
    NEW=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)

    if [ "$OLD" = "$NEW" ]; then
        ok "Repository already up to date ($NEW)"
    else
        ok "Repository updated: $OLD -> $NEW"
    fi

    deploy() {
        src="$1"; dst="$2"
        [ -f "$src" ] || return 1
        mkdir -p "$(dirname "$dst")"
        if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
            ok "Unchanged: $dst"
            return 0
        fi
        if [ -f "$dst" ]; then
            cp "$dst" "$dst.bak-$STAMP"
            info "Backup: $dst.bak-$STAMP"
        fi
        cp "$src" "$dst"
        ok "Updated:   $dst"
    }

    info "Installing updated files"

    [ -f "$SCRIPT_DIR/launch-fusion.sh" ]     || fail "launch-fusion.sh missing in the repository"
    [ -f "$SCRIPT_DIR/fusion-window-fix.py" ] || fail "fusion-window-fix.py missing in the repository"

    deploy "$SCRIPT_DIR/launch-fusion.sh"     "$HOME/launch-fusion.sh"
    deploy "$SCRIPT_DIR/fusion-window-fix.py" "$HOME/fusion-window-fix.py"
    chmod +x "$HOME/launch-fusion.sh"

    if [ -f "$SCRIPT_DIR/adskidmgr-handler.sh" ]; then
        deploy "$SCRIPT_DIR/adskidmgr-handler.sh" "$APPDIR/adskidmgr-handler.sh"
        chmod +x "$APPDIR/adskidmgr-handler.sh"
    else
        warn "adskidmgr-handler.sh is not in this version of the repository (skipped)"
    fi

    if command -v python3 >/dev/null && python3 -c "import Xlib" >/dev/null 2>&1; then
        ok "python-xlib detected"
    else
        warn "python3 or python-xlib not found (needed by the window-fix helper)
    Fedora : sudo dnf install python3-xlib
    Arch   : sudo pacman -S python-xlib
    Debian : sudo apt install python3-xlib"
    fi

    echo
    ok "Update finished. Restart Fusion 360 with:  ~/launch-fusion.sh"
}

main "$@"; exit $?
