#!/bin/bash

#   ./deps.sh            Checks for python-xlib, GE-Proton, and GPU; if any are missing, verifies them and installs them
#   ./deps.sh --check    Reports the status without making any changes
#   ./deps.sh --yes      Answers “yes” to all questions (Non-interactive)
#   ./deps.sh --update-proton  Get the latest version even if it’s already installed (does not remove older versions)
#
# Environment variables :
#   FUSION180_ASSUME_YES=1     Answer “yes” to all
#   FUSION180_PROTON_DIR=...   Location of GE-Proton (default: ~/.fusion180/protons)
#   FUSION180_PROTON_TAG=...   Specify a specific GE-Proton version to download (e.g., GE-Proton11-11)
#   FUSION180_UPDATE_PROTON=1  Download the latest version even if it’s already installed
#   FUSION180_PROTON_KEEP=3    Number of GE-Proton versions to keep

FUSION180_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fusion180"
PROTON_HOME="${FUSION180_PROTON_DIR:-$HOME/.fusion180/protons}"
PYLIB="${FUSION180_PYLIB:-$HOME/.local/share/fusion180/pylib}"
GE_RELEASES_URL="${GE_PROTON_BASE_URL:-https://github.com/GloriousEggroll/proton-ge-custom/releases}"

type ok   >/dev/null 2>&1 || ok()   { echo -e "\033[1;32m[✓]\033[0m $1"; }
type info >/dev/null 2>&1 || info() { echo -e "\033[1;36m[>]\033[0m $1"; }
type warn >/dev/null 2>&1 || warn() { echo -e "\033[1;33m[!]\033[0m $1"; }
type fail >/dev/null 2>&1 || fail() { echo -e "\033[1;31m[✗]\033[0m $1"; exit 1; }

# --- Distro ---

confirm() {
    if [ "${FUSION180_NO_INSTALL:-0}" = 1 ]; then
        return 1
    fi
    if [ "${FUSION180_ASSUME_YES:-0}" = 1 ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        return 1
    fi
    local ans
    read -r -p "    $1 [y/N] " ans
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

run_priv() {
    echo "    \$ sudo $*"
    if [ "$(id -u)" = 0 ]; then
        "$@"
    else
        command -v sudo >/dev/null || { warn "sudo not found"; return 1; }
        sudo "$@"
    fi
}

detect_distro() {
    local id="" like=""
    if [ -r /etc/os-release ]; then
        id=$(. /etc/os-release; echo "$ID")
        like=$(. /etc/os-release; echo "$ID_LIKE")
    fi
    DISTRO_ID="$id"; DISTRO_LIKE="$like"
    case " $id $like " in
        *" fedora "*|*" rhel "*)   PKG=dnf ;;
        *" arch "*)                PKG=pacman ;;
        *" debian "*|*" ubuntu "*) PKG=apt ;;
        *)                         PKG="" ;;
    esac

    if [ -n "$PKG" ] && [ -e /run/ostree-booted ]; then
        warn "Immutable (ostree) system detected: system packages will not be installed"
        PKG=""
    fi
}


# --- Python-xlib ---

xlib_available() {
    python3 -c "import Xlib" >/dev/null 2>&1 \
        || PYTHONPATH="$PYLIB${PYTHONPATH:+:$PYTHONPATH}" python3 -c "import Xlib" >/dev/null 2>&1
}

ensure_python_xlib() {
    command -v python3 >/dev/null || fail "python3 not found (required for the window-fix helper)"

    if xlib_available; then
        ok "python-xlib detected"
        return 0
    fi

    info "python-xlib is missing"
    detect_distro

    local pkgcmd=()
    case "$PKG" in
        dnf)    pkgcmd=(dnf install -y python3-xlib) ;;
        pacman) pkgcmd=(pacman -S --needed --noconfirm python-xlib) ;;
        apt)    pkgcmd=(apt-get install -y python3-xlib) ;;
    esac

    if [ ${#pkgcmd[@]} -gt 0 ] && confirm "Install python-xlib with $PKG? (needs sudo)"; then
        if run_priv "${pkgcmd[@]}" && xlib_available; then
            ok "python-xlib installed"
            return 0
        fi
        warn "Package installation did not work"
    fi

    if confirm "Install python-xlib privately with pip into $PYLIB? (no sudo)"; then
        mkdir -p "$PYLIB"
        if python3 -m pip install --quiet --target "$PYLIB" python-xlib && xlib_available; then
            ok "python-xlib installed to $PYLIB"
            warn "launch-fusion.sh must export PYTHONPATH=$PYLIB (see the README)"
            return 0
        fi
        warn "pip installation did not work (is python3-pip installed?)"
    fi

    fail "python-xlib not found. Install it with one of:
    Fedora       : sudo dnf install python3-xlib
    Arch/CachyOS : sudo pacman -S python-xlib
    Debian/Ubuntu: sudo apt install python3-xlib
    Any distro   : python3 -m pip install --target $PYLIB python-xlib"
}


# --- Proton dependencies ---

check_proton_libs() {
    local cur g f out required optional dl_req dl_warn cache soname
    cur=$(ge_find_installed)
    [ -n "$cur" ] || return 0
    g="$cur/files"
    [ -d "$g/lib/wine/x86_64-unix" ] || return 0


    if [ -d "$g/lib/wine/i386-unix" ] && [ ! -e "${FUSION180_LD32:-/lib/ld-linux.so.2}" ]; then
        warn "32-bit loader not found (/lib/ld-linux.so.2): Proton's 32-bit Wine components cannot start"
        detect_distro
        case "$PKG" in
            apt)    echo "      Fix:  sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install -y libc6:i386 libstdc++6:i386" ;;
            dnf)    echo "      Fix:  sudo dnf install -y glibc.i686 libstdc++.i686" ;;
            pacman) echo "      Fix:  sudo pacman -S lib32-glibc lib32-gcc-libs" ;;
            *)      echo "      Install your distribution's 32-bit glibc (i386/i686) package." ;;
        esac
    fi

    command -v ldd >/dev/null 2>&1 || { warn "ldd not found; skipping the library check"; return 0; }

    out=$(for f in "$g/bin/wineserver" "$g"/lib/wine/x86_64-unix/* "$g"/lib/wine/i386-unix/*; do
            [ -f "$f" ] || continue
            LD_LIBRARY_PATH="$g/lib:$g/lib64:$g/lib/wine/x86_64-unix:$g/lib/wine/i386-unix" ldd "$f" 2>/dev/null \
                | awk -v f="$(basename "$f")" '/not found/{print $1 "|" f}'
          done | sort -u)

    dl_req=""; dl_warn=""
    if command -v ldconfig >/dev/null 2>&1; then
        cache=$(ldconfig -p 2>/dev/null)
        for soname in libfreetype.so.6 libfontconfig.so.1; do
            echo "$cache" | grep -F "$soname " | grep "x86-64" >/dev/null 2>&1 || dl_req="$dl_req $soname(64-bit)"
            echo "$cache" | grep -F "$soname " | grep -v "x86-64" >/dev/null 2>&1 || dl_req="$dl_req $soname(32-bit)"
        done
        for soname in libgnutls.so.30 libvulkan.so.1; do
            echo "$cache" | grep -F "$soname " | grep "x86-64" >/dev/null 2>&1 || dl_warn="$dl_warn $soname(64-bit)"
            echo "$cache" | grep -F "$soname " | grep -v "x86-64" >/dev/null 2>&1 || dl_warn="$dl_warn $soname(32-bit)"
        done
    fi

    if [ -z "$out" ] && [ -z "$dl_req" ] && [ -z "$dl_warn" ]; then
        ok "Proton host libraries: nothing missing"
        return 0
    fi

    required=$(echo "$out" | grep -Ev '^(libav|libsw|libopenxr|libpcap|libpiper|libxkbregistry)' || true)
    optional=$(echo "$out" | grep -E  '^(libav|libsw|libopenxr|libpcap|libpiper|libxkbregistry)' || true)

    if [ -n "$required" ]; then
        warn "Libraries Proton needs are missing:"
        echo "$required" | awk -F'|' '!seen[$1]++ {print "      " $1 "  (for example needed by " $2 ")"}'
        detect_distro
        case "$PKG" in
            dnf)    echo "      Find the package:  dnf provides '*/<library name>'" ;;
            apt)    echo "      Find the package:  apt-file search <library name>" ;;
            pacman) echo "      Find the package:  pacman -F <library name>" ;;
        esac
    fi
    if [ -n "$dl_req" ]; then
        warn "Runtime-loaded (dlopen) libraries are missing:$dl_req"
        echo "      Without FreeType/Fontconfig, Wine renders no text in the installer."
        detect_distro
        case "$PKG" in
            apt)    echo "      Fix:  sudo apt install -y libfreetype6 libfreetype6:i386 libfontconfig1 libfontconfig1:i386" ;;
            dnf)    echo "      Fix:  sudo dnf install -y freetype freetype.i686 fontconfig fontconfig.i686" ;;
            pacman) echo "      Fix:  sudo pacman -S freetype2 lib32-freetype2 fontconfig lib32-fontconfig" ;;
        esac
    fi
    if [ -z "$required" ] && [ -z "$dl_req" ]; then
        ok "Proton host libraries: nothing essential is missing"
    fi
    if [ -n "$optional" ]; then
        info "Optional features unavailable (media decoding, VR, packet capture, TTS, Wayland driver): $(echo "$optional" | cut -d'|' -f1 | tr '\n' ' ')"
    fi
    if [ -n "$dl_warn" ]; then
        info "Runtime-loaded libraries missing (sign-in HTTPS / Vulkan loader may fail):$dl_warn"
    fi
}


# --- GE-Proton ---

ge_find_installed() {
    find "$PROTON_HOME" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' 2>/dev/null \
        | awk -F/ '{print $NF "\t" $0}' | sort -s -V -k1,1 | tail -n1 | cut -f2-
}

ge_have_tag() {
    if [ -e "$PROTON_HOME/$1" ] || [ -e "$PROTON_HOME/$1-x86_64" ]; then
        return 0
    fi
    return 1
}

ge_resolve_tag() {
    if [ -n "${FUSION180_PROTON_TAG:-}" ]; then
        echo "$FUSION180_PROTON_TAG"
        return 0
    fi
    local loc
    loc=$(curl -fsS -m 30 -I "$GE_RELEASES_URL/latest" 2>/dev/null \
        | tr -d '\r' | awk 'tolower($1)=="location:"{print $2}' | tail -n1)
    [ -n "$loc" ] || return 1
    echo "${loc##*/}"
}

ge_install_tag() {
    local tag="$1" asset="" name url work top free_kb

    mkdir -p "$PROTON_HOME"

    free_kb=$(df -Pk "$PROTON_HOME" | awk 'NR==2{print $4}')
    if [ "${free_kb:-0}" -lt 3145728 ]; then
        fail "Not enough free space in $PROTON_HOME (need about 3 GiB)"
    fi

    for name in "$tag-x86_64" "$tag"; do
        if curl -fsSIL -m 30 "$GE_RELEASES_URL/download/$tag/$name.tar.gz" -o /dev/null 2>/dev/null; then
            asset="$name"
            break
        fi
    done
    [ -n "$asset" ] || fail "Could not find the GE-Proton archive for $tag"

    work=$(mktemp -d "$PROTON_HOME/.fusion180-dl.XXXXXX")

    info "Downloading $asset.tar.gz (this is about 600MB)"
    if ! curl -fL --retry 3 --retry-delay 2 --progress-bar \
            -o "$work/$asset.tar.gz" "$GE_RELEASES_URL/download/$tag/$asset.tar.gz"; then
        rm -rf "$work"; fail "Download failed"
    fi

    command -v sha512sum >/dev/null || { rm -rf "$work"; fail "sha512sum not found (install coreutils)"; }
    if ! curl -fsSL --retry 3 -o "$work/$asset.sha512sum" "$GE_RELEASES_URL/download/$tag/$asset.sha512sum"; then
        rm -rf "$work"; fail "Checksum file could not be downloaded; refusing to install"
    fi
    if ! (cd "$work" && sha512sum -c --status "$asset.sha512sum"); then
        rm -rf "$work"; fail "Checksum mismatch; the download is corrupt or has been altered"
    fi
    ok "Checksum verified"

    info "Extracting"
    mkdir -p "$work/x"
    if ! tar --no-same-owner -xzf "$work/$asset.tar.gz" -C "$work/x"; then
        rm -rf "$work"; fail "Extraction failed"
    fi

    top=$(find "$work/x" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -n1)
    if [ -z "$top" ] || [ ! -f "$work/x/$top/proton" ]; then
        rm -rf "$work"; fail "Unexpected archive layout (no proton script found)"
    fi

    if [ -e "$PROTON_HOME/$top" ]; then
        rm -rf "$work"
        ok "$top is already installed"
        return 0
    fi
    mv "$work/x/$top" "$PROTON_HOME/$top"
    rm -rf "$work"
    ok "Installed $top"
}

_ensure_ge_proton() {
    command -v curl >/dev/null || fail "curl not found"

    local current tag
    current=$(ge_find_installed)

    if [ -n "$current" ] && [ "${FUSION180_UPDATE_PROTON:-0}" != 1 ]; then
        ok "GE-Proton detected: $(basename "$current")"
        return 0
    fi

    if [ -z "$current" ]; then
        info "GE-Proton is not installed"
    else
        info "Checking for a newer GE-Proton (installed: $(basename "$current"))"
    fi

    tag=$(ge_resolve_tag) || fail "Could not determine the latest GE-Proton version (network problem?)"

    if ge_have_tag "$tag"; then
        ok "GE-Proton is up to date ($tag)"
        return 0
    fi

    confirm "Download $tag from GitHub to $PROTON_HOME?" \
        || fail "GE-Proton is required. Run ./deps.sh to download it, or place it manually in $PROTON_HOME."

    ge_install_tag "$tag"
}

save_proton_dir() {
    mkdir -p "$FUSION180_CONFIG_DIR" 2>/dev/null || return 0
    if [ "$(cat "$FUSION180_CONFIG_DIR/proton_dir" 2>/dev/null)" != "$PROTON_HOME" ]; then
        printf '%s\n' "$PROTON_HOME" > "$FUSION180_CONFIG_DIR/proton_dir"
        info "Saved the GE-Proton location: $FUSION180_CONFIG_DIR/proton_dir"
    fi
}

ensure_ge_proton() {
    _ensure_ge_proton || return $?
    if [ -d "$PROTON_HOME" ]; then
        save_proton_dir
    fi
    return 0
}


prune_ge_protons() {
    local keep="${FUSION180_PROTON_KEEP:-3}"
    case "$keep" in
        ''|*[!0-9]*|0) warn "Invalid FUSION180_PROTON_KEEP ($keep); skipping GE-Proton cleanup"; return 0 ;;
    esac
    [ -d "$PROTON_HOME" ] || return 0

    local pin="${FUSION180_PROTON:-$(cat "$FUSION180_CONFIG_DIR/proton" 2>/dev/null)}"

    local dirs=()
    mapfile -t dirs < <(find "$PROTON_HOME" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' 2>/dev/null \
        | awk -F/ '{print $NF "\t" $0}' | sort -s -V -k1,1 | cut -f2-)
    local total=${#dirs[@]}
    if [ "$total" -le "$keep" ]; then
        info "GE-Proton generations: $total (keep up to $keep; nothing to remove)"
        return 0
    fi

    local excess=$((total - keep)) removed=0 d
    for d in "${dirs[@]}"; do
        [ "$removed" -lt "$excess" ] || break
        case "$d" in
            "$PROTON_HOME"/GE-Proton*) ;;
            *) warn "Skipping unexpected path during cleanup: $d"; continue ;;
        esac
        if [ -n "$pin" ] && [ "$(basename "$d")" = "$pin" ]; then
            info "Keeping pinned GE-Proton: $pin"
            continue
        fi
        info "Removing old GE-Proton: $(basename "$d")"
        rm -rf -- "$d" && removed=$((removed + 1))
    done
    info "GE-Proton cleanup done: removed $removed"
}


# --- GPU / Vulkan ---

GPU_NVIDIA=0; GPU_AMD=0; GPU_INTEL=0
GPU_NVIDIA_VULKAN_OK=0; GPU_AMD_VULKAN_OK=0

check_graphics() {
    local d vendor drv name
    local sys_drm="${FUSION180_SYS_DRM:-/sys/class/drm}"

    GPU_NVIDIA=0; GPU_AMD=0; GPU_INTEL=0; GPU_NVIDIA_VULKAN_OK=0; GPU_AMD_VULKAN_OK=0
    for d in "$sys_drm"/card[0-9]*/device; do
        [ -r "$d/vendor" ] || continue
        vendor=$(cat "$d/vendor")
        drv=$(basename "$(readlink -f "$d/driver" 2>/dev/null)" 2>/dev/null)
        case "$vendor" in
            0x10de) GPU_NVIDIA=1; name="NVIDIA" ;;
            0x1002) GPU_AMD=1;    name="AMD" ;;
            0x8086) GPU_INTEL=1;  name="Intel" ;;
            *)      name="unknown ($vendor)" ;;
        esac
        info "GPU: $name (kernel driver: ${drv:-none})"
        if [ "$name" = "NVIDIA" ] && [ "$drv" = "nouveau" ]; then
            warn "The open-source 'nouveau' driver is in use. Fusion needs the proprietary NVIDIA driver for Vulkan."
        fi
        if [ "$name" = "AMD" ] && [ "$drv" = "radeon" ]; then
            warn "The legacy 'radeon' kernel driver is in use. RADV (Vulkan) needs the 'amdgpu' driver."
            warn "For GCN 1/2 cards (HD 7000-Rx 300 era), boot with:  radeon.si_support=0 radeon.cik_support=0 amdgpu.si_support=1 amdgpu.cik_support=1"
        fi
    done

    if [ $((GPU_NVIDIA + GPU_AMD + GPU_INTEL)) -eq 0 ]; then
        warn "No GPU found via $sys_drm (skipping the graphics check)"
        return 0
    fi

    # Hibrid GPU
    if [ "$GPU_NVIDIA" = 1 ] && [ $((GPU_INTEL + GPU_AMD)) -ge 1 ]; then
        info "Hybrid graphics detected (iGPU + NVIDIA dGPU). Which GPU Fusion uses depends on the Vulkan device it picks."
        info "To force the NVIDIA GPU, launch with:  __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia ~/launch-fusion.sh"
    fi

    # Vulkan
    local devices=""
    if command -v vulkaninfo >/dev/null; then
        devices=$(vulkaninfo --summary 2>/dev/null | awk -F'= ' '/deviceName/{print $2}')
    fi

    if [ -n "$devices" ]; then
        if [ -z "$(echo "$devices" | grep -vi llvmpipe)" ]; then
            warn "Vulkan only offers a software renderer (llvmpipe): no usable GPU driver"
            graphics_advice
            return 0
        fi
        ok "Vulkan devices:"
        echo "$devices" | sed 's/^/      /'
        if [ "$GPU_NVIDIA" = 1 ]; then
            if echo "$devices" | grep -qiE 'nvidia|geforce|rtx|gtx|quadro'; then
                GPU_NVIDIA_VULKAN_OK=1
            else
                warn "An NVIDIA GPU is present, but Vulkan cannot see it (only the iGPU is visible). The NVIDIA driver or its Vulkan ICD is missing/broken; installing Mesa packages will not fix this."
                graphics_advice
            fi
        fi
        if [ "$GPU_AMD" = 1 ]; then
            if echo "$devices" | grep -qiE 'radeon|radv|amd'; then
                GPU_AMD_VULKAN_OK=1
                if ls "${FUSION180_VULKAN_ICD_DIR:-/usr/share/vulkan/icd.d}"/amd_icd*.json >/dev/null 2>&1; then
                    info "AMDVLK is also installed alongside RADV. RADV is recommended for Fusion; launch-fusion.sh sets AMD_VULKAN_ICD=RADV to prefer it."
                fi
            else
                warn "An AMD GPU is present, but Vulkan cannot see it. The Mesa RADV driver is likely missing (or the kernel is using the legacy 'radeon' driver instead of 'amdgpu')."
                graphics_advice
            fi
        fi
    elif ls /usr/share/vulkan/icd.d/*.json /etc/vulkan/icd.d/*.json >/dev/null 2>&1; then
        warn "Vulkan driver files found, but vulkaninfo is not available, so which GPU Vulkan can use could not be verified (install vulkan-tools to verify)"
    else
        warn "No Vulkan driver found"
        graphics_advice
    fi
}

graphics_advice() {
    detect_distro

    local nvidia_side=0
    if [ "$GPU_NVIDIA" = 1 ] && [ "$GPU_NVIDIA_VULKAN_OK" != 1 ] && [ -n "$(vulkaninfo --summary 2>/dev/null)" ]; then
        nvidia_side=1
    fi
    if [ "$nvidia_side" = 1 ]; then
        info "Skipping the Mesa package offer: the problem is the NVIDIA side, not Mesa (see the NVIDIA guidance below)."
    elif [ "$GPU_AMD" = 1 ] || [ "$GPU_INTEL" = 1 ]; then
        local pkgs=()
        case "$PKG" in
            dnf)    pkgs=(mesa-vulkan-drivers mesa-vulkan-drivers.i686 vulkan-loader vulkan-tools) ;;
            pacman) pkgs=(vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools)
                    [ "$GPU_AMD" = 1 ]   && pkgs+=(vulkan-radeon lib32-vulkan-radeon)
                    [ "$GPU_INTEL" = 1 ] && pkgs+=(vulkan-intel lib32-vulkan-intel) ;;
            apt)    pkgs=(mesa-vulkan-drivers libvulkan1 vulkan-tools) ;;
        esac
        if [ ${#pkgs[@]} -gt 0 ]; then
            local cmd=()
            case "$PKG" in
                dnf)    cmd=(dnf install -y "${pkgs[@]}") ;;
                pacman) cmd=(pacman -S --needed --noconfirm "${pkgs[@]}") ;;
                apt)    cmd=(apt-get install -y "${pkgs[@]}") ;;
            esac
            if confirm "Install the Vulkan driver packages (${pkgs[*]})? (needs sudo)"; then
                run_priv "${cmd[@]}" || warn "Installation failed"
            fi
        else
            warn "Install the Mesa Vulkan drivers (RADV for AMD, ANV for Intel) with your package manager."
        fi
    fi

    if [ "$PKG" = apt ] && [ "$nvidia_side" != 1 ] && { [ "$GPU_AMD" = 1 ] || [ "$GPU_INTEL" = 1 ]; }; then
        info "32-bit Vulkan (needed by some Wine/Proton parts):  sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install mesa-vulkan-drivers:i386 libvulkan1:i386"
    fi

    if [ "$GPU_NVIDIA" = 1 ]; then
        warn "The NVIDIA proprietary driver is NOT installed automatically (kernel module, reboot, Secure Boot)."
        case "$PKG" in
            dnf)    echo "      Fedora : enable RPM Fusion, then  sudo dnf install akmod-nvidia  and reboot
               https://rpmfusion.org/Howto/NVIDIA   (Secure Boot needs a key enrollment)" ;;
            pacman) echo "      Arch   : sudo pacman -S nvidia-open nvidia-utils lib32-nvidia-utils   (nvidia-open-dkms for custom kernels), then reboot" ;;
            apt)    echo "      Ubuntu : sudo ubuntu-drivers install   (Debian: the non-free 'nvidia-driver' package), then reboot" ;;
            *)      echo "      Install the proprietary NVIDIA driver for your distribution, then reboot." ;;
        esac
    fi
}


# --- Launcher (application menu) ---
install_launcher_entry() {
    local data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local appdir="$data_home/applications"
    local src_dir icon_name="applications-engineering"
    src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    mkdir -p "$appdir" || return 0
    if [ -f "$src_dir/fusion180.png" ]; then
        mkdir -p "$data_home/icons/hicolor/256x256/apps"
        if cp "$src_dir/fusion180.png" "$data_home/icons/hicolor/256x256/apps/fusion180.png" 2>/dev/null; then
            icon_name="fusion180"
        fi
    fi
    cat > "$appdir/fusion180.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Fusion 360
Comment=Autodesk Fusion 360 (GE-Proton)
Exec=$HOME/launch-fusion.sh
Icon=$icon_name
Terminal=false
StartupWMClass=fusion360.exe
Categories=Graphics;3DGraphics;Engineering;
EOF
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$appdir" >/dev/null 2>&1 || true
    fi
    ok "Launcher registered in the application menu (Fusion 360)"
}

deps_report() {
    local cur
    if xlib_available; then ok "python-xlib detected"; else warn "python-xlib not found"; fi
    cur=$(ge_find_installed)
    if [ -n "$cur" ]; then
        ok "GE-Proton (newest installed): $(basename "$cur")"
        check_proton_libs
        info "Installed GE-Proton versions: $(find "$PROTON_HOME" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' -printf '%f ' 2>/dev/null)"
        info "Download location for new versions: $PROTON_HOME"
    else
        warn "GE-Proton not installed"
    fi
    FUSION180_NO_INSTALL=1 check_graphics
}


fusion180_deps_main() {
    local check=0
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes)         export FUSION180_ASSUME_YES=1 ;;
            --check)          check=1 ;;
            --update-proton)  export FUSION180_UPDATE_PROTON=1 ;;
            -h|--help)        echo "Usage: ./deps.sh [--check] [--yes] [--update-proton]"; return 0 ;;
            *) echo "deps.sh: unknown option '$1'" >&2; return 2 ;;
        esac
        shift
    done

    if [ "$check" = 1 ]; then
        deps_report
        return 0
    fi

    ensure_python_xlib
    ensure_ge_proton
    check_proton_libs
    check_graphics
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    fusion180_deps_main "$@"
    exit $?
fi
