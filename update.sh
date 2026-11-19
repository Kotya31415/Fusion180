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

    if command -v python3 >/dev/null && { python3 -c "import Xlib" >/dev/null 2>&1 || PYTHONPATH="$HOME/.local/share/fusion180/pylib" python3 -c "import Xlib" >/dev/null 2>&1; }; then
        ok "python-xlib detected"
    else
        warn "python3 or python-xlib not found (needed by the window-fix helper). Run ./deps.sh to set it up."
    fi

    info "Checking for a new GE-Proton"

    if [ -f "$SCRIPT_DIR/deps.sh" ]; then
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/deps.sh"

        BEFORE="$(basename "$(ge_find_installed)" 2>/dev/null)"

        if FUSION180_UPDATE_PROTON=1 ensure_ge_proton; then
            AFTER="$(basename "$(ge_find_installed)" 2>/dev/null)"
            if [ -n "$BEFORE" ] && [ "$BEFORE" != "$AFTER" ]; then
                ok "GE-Proton updated: $BEFORE -> $AFTER (previous version kept as fallback)"
            fi

            prune_ge_protons

            local versions=()
            mapfile -t versions < <(find "$PROTON_HOME" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' -printf '%f\n' 2>/dev/null | sort -V)
            if [ "${#versions[@]}" -ge 1 ]; then
                info "GE-Proton in use:    ${versions[-1]}"
            fi
            if [ "${#versions[@]}" -ge 2 ]; then
                info "GE-Proton fallback:  ${versions[-2]}"
            fi
        else
            warn "GE-Proton update check failed; keeping the current version and skipping cleanup"
        fi
    else
        warn "deps.sh is not in this version of the repository; GE-Proton update skipped"
    fi

    echo
    ok "Update finished. Restart Fusion 360 with:  ~/launch-fusion.sh"
}

main "$@"; exit $?
