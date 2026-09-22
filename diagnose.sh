#!/usr/bin/env bash
set -euo pipefail

VERSION="0.2.0"
CONFIG_DIR="$HOME/.config/fusion180"
CONFIG_FILE="$CONFIG_DIR/config.env"
DEFAULT_PREFIX="$HOME/.fusion180"
PREFIX="$DEFAULT_PREFIX"
STEAM_ROOT=""
PROTON_BIN=""
GPU_PROFILE="opengl"
WINDOW_FIX_SCRIPT=""

ok() { printf "\033[1;32m[✓]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }
fail() { printf "\033[1;31m[✗]\033[0m %s\n" "$1"; exit 1; }
info() { printf "\033[1;36m[>]\033[0m %s\n" "$1"; }

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi

    PREFIX="${PREFIX:-$DEFAULT_PREFIX}"
    STEAM_ROOT="${STEAM_ROOT:-}"
    PROTON_BIN="${PROTON_BIN:-}"
    GPU_PROFILE="${GPU_PROFILE:-opengl}"
    WINDOW_FIX_SCRIPT="${WINDOW_FIX_SCRIPT:-$PREFIX/tools/fusion-window-fix.py}"
}

detect_steam_roots() {
    local roots=()
    [ -d "$HOME/.local/share/Steam" ] && roots+=("$HOME/.local/share/Steam")
    [ -d "$HOME/.var/app/com.valvesoftware.Steam/data/Steam" ] && roots+=("$HOME/.var/app/com.valvesoftware.Steam/data/Steam")
    printf '%s\n' "${roots[@]}"
}

detect_proton_candidates() {
    local root="$1"
    [ -d "$root/compatibilitytools.d" ] || return 0
    find "$root/compatibilitytools.d" -maxdepth 1 -type d -name 'GE-Proton*' | sort -V
}

find_fusion_exe() {
    find "$PREFIX" -name Fusion360.exe 2>/dev/null | head -n1 || true
}

collect_command_output() {
    local label="$1"
    shift
    echo "## $label"
    if "$@" >/tmp/fusion180_cmd.out 2>/tmp/fusion180_cmd.err; then
        cat /tmp/fusion180_cmd.out
    else
        cat /tmp/fusion180_cmd.out
        [ -s /tmp/fusion180_cmd.err ] && { echo "[stderr]"; cat /tmp/fusion180_cmd.err; }
    fi
    echo
}

doctor() {
    local out="${1:-$HOME/fusion180-doctor-$(date +%Y%m%d-%H%M%S).txt}"
    load_config

    local fusion_exe=""
    local roots=()
    local protons=()

    {
        echo "Fusion180 Doctor Report"
        echo "Generated: $(date -Iseconds)"
        echo "Version: $VERSION"
        echo
        echo "## Config"
        echo "PREFIX=$PREFIX"
        echo "STEAM_ROOT=$STEAM_ROOT"
        echo "PROTON_BIN=$PROTON_BIN"
        echo "GPU_PROFILE=$GPU_PROFILE"
        echo "WINDOW_FIX_SCRIPT=$WINDOW_FIX_SCRIPT"
        echo

        collect_command_output "uname -a" uname -a

        if command -v lsb_release >/dev/null 2>&1; then
            collect_command_output "lsb_release -a" lsb_release -a
        fi

        echo "## Session"
        echo "DISPLAY=${DISPLAY:-unset}"
        echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unset}"
        echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
        echo

        echo "## Dependency checks"
        for cmd in steam python3 update-desktop-database; do
            if command -v "$cmd" >/dev/null 2>&1; then
                echo "$cmd: ok ($(command -v "$cmd"))"
            else
                echo "$cmd: missing"
            fi
        done
        if python3 -c 'import Xlib' >/dev/null 2>&1; then
            echo "python-xlib: ok"
        else
            echo "python-xlib: missing"
        fi
        echo

        echo "## Steam roots"
        mapfile -t roots < <(detect_steam_roots)
        if [ "${#roots[@]}" -eq 0 ]; then
            echo "No Steam roots detected"
        else
            for root in "${roots[@]}"; do
                echo "- $root"
                mapfile -t protons < <(detect_proton_candidates "$root")
                if [ "${#protons[@]}" -eq 0 ]; then
                    echo "  GE-Proton: none"
                else
                    printf '  GE-Proton:\n'
                    printf '    - %s\n' "${protons[@]}"
                fi
            done
        fi
        echo

        echo "## Prefix status"
        if [ -d "$PREFIX" ]; then
            echo "Prefix exists: yes"
            fusion_exe="$(find_fusion_exe)"
            echo "Fusion360.exe=${fusion_exe:-not found}"
        else
            echo "Prefix exists: no"
        fi
        echo

        echo "## Recent launch log"
        local latest_log="$PREFIX/logs/latest.log"
        if [ -L "$latest_log" ] || [ -f "$latest_log" ]; then
            tail -n 120 "$latest_log" || true
        else
            echo "No launch log found"
        fi
        echo

        echo "## Known issue hints"
        echo "- Qt plugin error: ensure correct runtime libraries and retry with repair command"
        echo "- Sign-in freeze: use URI handlers and clear caches with repair"
        echo "- Keyboard issues: verify XWayland/IME settings and try relaunch"
    } > "$out"

    ok "Doctor report written: $out"
}

print_help() {
    cat <<EOF
Fusion180 Doctor Standalone

Usage:
  $0 [output-file]
  $0 help

Examples:
  $0
  $0 /tmp/fusion180-doctor.txt
EOF
}

main() {
    local arg="${1:-}"
    if [ -z "$arg" ] || [ "$arg" = "help" ] || [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
        if [ -n "$arg" ] && [ "$arg" != "" ]; then
            print_help
            return 0
        fi
        doctor "$HOME/fusion180-doctor-$(date +%Y%m%d-%H%M%S).txt"
        return 0
    fi

    doctor "$arg"
}

main "$@"
