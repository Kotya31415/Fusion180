#!/bin/bash
set -euo pipefail

VERSION="0.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/fusion180.sh"

CONFIG_DIR="$HOME/.config/fusion180"
CONFIG_FILE="$CONFIG_DIR/config.env"
DEFAULT_PREFIX="$HOME/.fusion180"
APPDIR="$HOME/.local/share/applications"

PREFIX="$DEFAULT_PREFIX"
STEAM_ROOT=""
PROTON_BIN=""
INSTALLER_PATH=""
GPU_PROFILE="opengl"
WINDOW_FIX_SCRIPT=""

ok() { printf "\033[1;32m[✓]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[!]\033[0m %s\n" "$1"; }
fail() { printf "\033[1;31m[✗]\033[0m %s\n" "$1"; exit 1; }
info() { printf "\033[1;36m[>]\033[0m %s\n" "$1"; }

save_config() {
    mkdir -p "$CONFIG_DIR"
    {
        printf "PREFIX=%q\n" "$PREFIX"
        printf "STEAM_ROOT=%q\n" "$STEAM_ROOT"
        printf "PROTON_BIN=%q\n" "$PROTON_BIN"
        printf "INSTALLER_PATH=%q\n" "$INSTALLER_PATH"
        printf "GPU_PROFILE=%q\n" "$GPU_PROFILE"
        printf "WINDOW_FIX_SCRIPT=%q\n" "$WINDOW_FIX_SCRIPT"
    } > "$CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi

    PREFIX="${PREFIX:-$DEFAULT_PREFIX}"
    STEAM_ROOT="${STEAM_ROOT:-}"
    PROTON_BIN="${PROTON_BIN:-}"
    INSTALLER_PATH="${INSTALLER_PATH:-}"
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

auto_detect_proton_bin() {
    local root="$1"
    local proton_dir
    proton_dir="$(detect_proton_candidates "$root" | tail -n1 || true)"
    if [ -n "$proton_dir" ] && [ -f "$proton_dir/proton" ]; then
        printf '%s\n' "$proton_dir/proton"
    fi
}

auto_detect_installer() {
    find "$HOME/Downloads" -maxdepth 1 -type f -iname '*Fusion*.exe' | head -n1 || true
}

prompt_default() {
    local label="$1"
    local current="$2"
    local value
    read -r -p "$label [$current]: " value
    if [ -z "$value" ]; then
        printf '%s\n' "$current"
    else
        printf '%s\n' "$value"
    fi
}

choose_index() {
    local prompt="$1"
    local default_index="$2"
    local count="$3"
    local input
    while true; do
        read -r -p "$prompt [$default_index]: " input
        input="${input:-$default_index}"
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "$count" ]; then
            printf '%s\n' "$input"
            return
        fi
        warn "Please enter a number between 1 and $count"
    done
}

apply_runtime_env() {
    export PROTON_USE_WINED3D=0
    export DXVK_ASYNC=1
    export NO_AT_BRIDGE=1
    export WINEDLLOVERRIDES="bcp47langs="
    export PROTON_USE_XALIA=0
    export STEAM_COMPAT_DATA_PATH="$PREFIX"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"

    if [ "$GPU_PROFILE" = "directx11" ]; then
        export VKD3D_DEBUG=none
    fi
}

find_fusion_exe() {
    find "$PREFIX" -name Fusion360.exe 2>/dev/null | head -n1 || true
}

install_window_fix() {
    mkdir -p "$PREFIX/tools"
    cp "$SCRIPT_DIR/fusion-window-fix.py" "$PREFIX/tools/fusion-window-fix.py"
    chmod +x "$PREFIX/tools/fusion-window-fix.py"
    WINDOW_FIX_SCRIPT="$PREFIX/tools/fusion-window-fix.py"
}

install_home_launcher() {
    cat > "$HOME/launch-fusion.sh" <<LAUNCHER
#!/bin/bash
exec "$SCRIPT_PATH" launch "\$@"
LAUNCHER
    chmod +x "$HOME/launch-fusion.sh"
}

register_uri_handlers() {
    mkdir -p "$APPDIR"

    cat > "$APPDIR/adskidmgr-handler.sh" <<'ADSK'
#!/bin/bash
set -euo pipefail
CONFIG_FILE="$HOME/.config/fusion180/config.env"
[ -f "$CONFIG_FILE" ] || exit 1
# shellcheck disable=SC1090
source "$CONFIG_FILE"

IDM=$(find "$PREFIX" -name AdskIdentityManager.exe 2>/dev/null | head -n1)
[ -n "$IDM" ] || exit 1

export PROTON_USE_WINED3D=0
export DXVK_ASYNC=1
export NO_AT_BRIDGE=1
export WINEDLLOVERRIDES="bcp47langs="
export PROTON_USE_XALIA=0
export STEAM_COMPAT_DATA_PATH="$PREFIX"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"

"$PROTON_BIN" run "$IDM" "$1"
ADSK
    chmod +x "$APPDIR/adskidmgr-handler.sh"

    cat > "$APPDIR/adskidmgr.desktop" <<EOF_DESK
[Desktop Entry]
Name=Autodesk Identity Manager
Exec=/bin/bash -c "$APPDIR/adskidmgr-handler.sh %u"
Type=Application
MimeType=x-scheme-handler/adskidmgr;
NoDisplay=true
EOF_DESK

    cat > "$APPDIR/adsk-fusion360.desktop" <<EOF_DESK
[Desktop Entry]
Name=Fusion 360 URI Handler
Exec=/bin/bash -c "$SCRIPT_PATH launch %u"
Type=Application
MimeType=x-scheme-handler/adsk;
NoDisplay=true
EOF_DESK

    mkdir -p "$HOME/.config"
    local mimefile="$HOME/.config/mimeapps.list"
    grep -q '^\[Default Applications\]' "$mimefile" 2>/dev/null || echo "[Default Applications]" >> "$mimefile"
    sed -i '/^x-scheme-handler\/adsk=/d' "$mimefile"
    sed -i '/^x-scheme-handler\/adskidmgr=/d' "$mimefile"
    {
        echo "x-scheme-handler/adsk=adsk-fusion360.desktop;"
        echo "x-scheme-handler/adskidmgr=adskidmgr.desktop;"
    } >> "$mimefile"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APPDIR" >/dev/null 2>&1 || true
    fi
}

show_steam_note() {
    if [ "$STEAM_ROOT" = "$HOME/.var/app/com.valvesoftware.Steam/data/Steam" ]; then
        warn "Flatpak Steam detected. Some integrations can be less reliable than native Steam."
    fi
}

cmd_install() {
    load_config

    local roots=()
    mapfile -t roots < <(detect_steam_roots)
    [ "${#roots[@]}" -gt 0 ] || fail "Steam installation not found (native or Flatpak)."

    info "Interactive setup"

    PREFIX="$(prompt_default 'Prefix path' "$PREFIX")"

    echo "Steam roots:"
    local i
    for i in "${!roots[@]}"; do
        printf '  %d) %s\n' "$((i+1))" "${roots[$i]}"
    done
    local steam_idx
    steam_idx="$(choose_index 'Select Steam root' 1 "${#roots[@]}")"
    STEAM_ROOT="${roots[$((steam_idx-1))]}"

    local proton_dirs=()
    mapfile -t proton_dirs < <(detect_proton_candidates "$STEAM_ROOT")
    [ "${#proton_dirs[@]}" -gt 0 ] || fail "No GE-Proton found in $STEAM_ROOT/compatibilitytools.d"

    echo "GE-Proton versions:"
    for i in "${!proton_dirs[@]}"; do
        printf '  %d) %s\n' "$((i+1))" "${proton_dirs[$i]}"
    done
    local proton_default="${#proton_dirs[@]}"
    local proton_idx
    proton_idx="$(choose_index 'Select GE-Proton' "$proton_default" "${#proton_dirs[@]}")"
    PROTON_BIN="${proton_dirs[$((proton_idx-1))]}/proton"
    [ -f "$PROTON_BIN" ] || fail "Proton binary not found: $PROTON_BIN"

    local detected_installer
    detected_installer="$(auto_detect_installer)"
    [ -n "$detected_installer" ] || detected_installer="$HOME/Downloads/Fusion Client Downloader.exe"
    INSTALLER_PATH="$(prompt_default 'Fusion installer path' "$detected_installer")"
    [ -f "$INSTALLER_PATH" ] || fail "Fusion installer not found: $INSTALLER_PATH"

    echo "GPU profile:"
    echo "  1) OpenGL (recommended default)"
    echo "  2) DirectX11"
    local gpu_idx
    gpu_idx="$(choose_index 'Select GPU profile' 1 2)"
    if [ "$gpu_idx" = "2" ]; then
        GPU_PROFILE="directx11"
    else
        GPU_PROFILE="opengl"
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        fail "python3 is required"
    fi
    if ! python3 -c 'import Xlib' >/dev/null 2>&1; then
        warn "python-xlib is missing; window-fix helper will be unavailable until installed"
    fi

    mkdir -p "$PREFIX"
    install_window_fix

    info "Running Fusion installer"
    apply_runtime_env
    "$PROTON_BIN" run "$INSTALLER_PATH"

    install_home_launcher
    register_uri_handlers
    save_config
    show_steam_note

    ok "Installation complete"
    echo "Start Fusion with: $SCRIPT_PATH launch"
}

cmd_launch() {
    load_config

    if [ -z "$STEAM_ROOT" ]; then
        local roots
        mapfile -t roots < <(detect_steam_roots)
        [ "${#roots[@]}" -gt 0 ] && STEAM_ROOT="${roots[0]}"
    fi
    if [ -z "$PROTON_BIN" ] || [ ! -f "$PROTON_BIN" ]; then
        [ -n "$STEAM_ROOT" ] || fail "Steam root is not configured"
        PROTON_BIN="$(auto_detect_proton_bin "$STEAM_ROOT")"
    fi
    [ -f "$PROTON_BIN" ] || fail "GE-Proton not found"

    local fusion_exe
    fusion_exe="$(find_fusion_exe)"
    [ -n "$fusion_exe" ] || fail "Fusion360.exe not found in $PREFIX"

    mkdir -p "$PREFIX/logs"
    local ts log latest
    ts="$(date +%Y%m%d-%H%M%S)"
    log="$PREFIX/logs/launch-$ts.log"
    latest="$PREFIX/logs/latest.log"

    info "Writing launch log: $log"

    local fix_pid=""
    if [ -n "${DISPLAY:-}" ] && [ -f "$WINDOW_FIX_SCRIPT" ] && python3 -c 'import Xlib' >/dev/null 2>&1; then
        python3 "$WINDOW_FIX_SCRIPT" >>"$log" 2>&1 &
        fix_pid=$!
    fi

    trap 'if [ -n "${fix_pid:-}" ]; then kill "$fix_pid" 2>/dev/null || true; fi' EXIT

    apply_runtime_env
    set +e
    ( "$PROTON_BIN" run "$fusion_exe" "$@" ) 2>&1 | tee -a "$log"
    local status=${PIPESTATUS[0]}
    set -e

    ln -sfn "$(basename "$log")" "$latest"

    exit "$status"
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

cmd_doctor() {
    load_config

    local out="${1:-$HOME/fusion180-doctor-$(date +%Y%m%d-%H%M%S).txt}"
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
        echo "INSTALLER_PATH=$INSTALLER_PATH"
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

reset_safe_caches() {
    local targets=(
        "$PREFIX/pfx/drive_c/users/steamuser/AppData/Local/Autodesk"
        "$PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/Autodesk"
    )

    local removed=0
    local base
    for base in "${targets[@]}"; do
        [ -d "$base" ] || continue
        while IFS= read -r cache_dir; do
            rm -rf "$cache_dir"
            echo "Removed: $cache_dir"
            removed=1
        done < <(find "$base" -type d \( -name 'Cache' -o -name 'GPUCache' -o -name 'Code Cache' -o -name 'QtWebEngine' \) 2>/dev/null)
    done

    if [ "$removed" -eq 0 ]; then
        echo "No known cache directories were found"
    fi
}

cmd_repair() {
    load_config
    [ -d "$PREFIX" ] || fail "Prefix not found: $PREFIX"

    info "Analyzing latest launch log"
    local latest="$PREFIX/logs/latest.log"
    if [ -L "$latest" ] || [ -f "$latest" ]; then
        if grep -qi 'Qt platform plugin' "$latest"; then
            warn "Detected Qt platform plugin error pattern"
            echo "Suggested: run doctor report, verify distro graphics libs, and retry launch"
        fi
        if grep -qiE 'sign|login|identity|auth' "$latest"; then
            warn "Detected authentication-related log lines"
            echo "Suggested: ensure browser login opened and URI handlers are registered"
        fi
        if grep -qiE 'keyboard|input' "$latest"; then
            warn "Detected possible keyboard/input issue pattern"
            echo "Suggested: verify IME settings and session type (Wayland/X11)"
        fi
    else
        warn "No launch log found yet"
    fi

    register_uri_handlers
    ok "URI handlers refreshed"

    local answer
    read -r -p "Clear Autodesk cache directories for safe recovery? [y/N]: " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        reset_safe_caches
        ok "Safe cache reset completed"
    else
        info "Cache reset skipped"
    fi
}

cmd_uninstall() {
    load_config

    echo "This will remove:"
    echo "- Prefix: $PREFIX"
    echo "- Config: $CONFIG_FILE"
    echo "- Home launcher: $HOME/launch-fusion.sh"
    echo "- URI desktop entries"

    local answer
    read -r -p "Continue? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { info "Canceled"; return; }

    rm -rf "$PREFIX"
    rm -f "$CONFIG_FILE"
    rm -f "$HOME/launch-fusion.sh"
    rm -f "$APPDIR/adskidmgr-handler.sh" "$APPDIR/adskidmgr.desktop" "$APPDIR/adsk-fusion360.desktop"
    ok "Fusion180 files removed"
}

print_help() {
    cat <<EOF
Fusion180 CLI v$VERSION

Usage:
  $0 install            Interactive setup + installer run
  $0 launch [args...]   Launch Fusion 360
  $0 doctor [output]    Generate diagnostic report
  $0 repair             Apply recovery steps for common issues
  $0 uninstall          Remove installed prefix and local integration files
  $0 version            Print version
  $0 help               Show this help
EOF
}

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        install) cmd_install "$@" ;;
        launch) cmd_launch "$@" ;;
        doctor) cmd_doctor "$@" ;;
        repair) cmd_repair "$@" ;;
        uninstall) cmd_uninstall "$@" ;;
        version) echo "$VERSION" ;;
        help|-h|--help) print_help ;;
        *) fail "Unknown command: $cmd" ;;
    esac
}

main "$@"
