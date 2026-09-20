# Fusion180

Turn Fusion 180° toward Linux.

Fusion180 is an unofficial, community-driven script set for running **Autodesk Fusion** on Linux with **Steam + GE-Proton**.

---

## Before You Start

This project does **not** redistribute Autodesk Fusion installers.
Download the latest installer from the [official Autodesk website](https://www.autodesk.com/products/fusion-360/overview) and place it in `~/Downloads`.

---

## Features

- Unified CLI: `install / launch / doctor / repair / uninstall / version`
- Interactive setup (prefix path, Steam root, GE-Proton version, installer path, GPU profile)
- Native Steam + Flatpak Steam detection
- Launch log collection under `~/.fusion180/logs`
- Doctor report generation for issue attachments
- Recovery flow for common launch/sign-in issues

---

## Requirements

| Component | Requirement |
|---|---|
| Steam | Native or Flatpak installation |
| Compatibility tool | GE-Proton (installed in Steam compatibilitytools.d) |
| Python | `python3` |
| Python package | `python-xlib` (recommended for window-fix helper) |

### python-xlib install examples

- Arch/CachyOS: `sudo pacman -S python-xlib`
- Fedora: `sudo dnf install python3-xlib`
- Debian/Ubuntu: `sudo apt install python3-xlib`

---

## Installation

```bash
git clone https://github.com/Kotya31415/Fusion180.git
cd Fusion180
chmod +x fusion180.sh installer.sh launch-fusion.sh
./fusion180.sh install
```

Backward-compatible wrappers are still available:

```bash
./installer.sh
./launch-fusion.sh
```

---

## Commands

```bash
./fusion180.sh install            # interactive setup + installer run
./fusion180.sh launch             # launch Fusion 360
./fusion180.sh doctor             # generate diagnostics report
./fusion180.sh doctor /path.txt   # write diagnostics report to custom path
./fusion180.sh repair             # recover from common launch/sign-in issues
./fusion180.sh uninstall          # remove prefix/config/desktop integration
./fusion180.sh version            # print CLI version
```

A convenience launcher is also installed at:

```bash
~/launch-fusion.sh
```

---

## Troubleshooting

| Symptom | Check | Action |
|---|---|---|
| `No Qt platform plugin could be initialized` | `~/.fusion180/logs/latest.log` | Run `./fusion180.sh doctor` then `./fusion180.sh repair`; verify graphics/runtime libs |
| Sign-in completed in browser but app still errors | URI handler registration | Run `./fusion180.sh repair` to refresh handlers and optionally clear caches |
| Freeze or unstable behavior after updates | Latest launch log and Proton version | Re-run `./fusion180.sh install`, choose another GE-Proton version |
| Keyboard/input issues | Session type (`XDG_SESSION_TYPE`) | Try relaunch, verify Wayland/X11 behavior, collect doctor report |

---

## FAQ

### Q. Where are logs?
- Launch logs: `~/.fusion180/logs/`
- Latest log symlink: `~/.fusion180/logs/latest.log`

### Q. How do I create an issue report?
1. Run `./fusion180.sh doctor`
2. Attach generated `fusion180-doctor-*.txt`
3. Include distro, kernel, desktop/session type, and the failing command

### Q. Does Flatpak Steam work?
Yes, it is auto-detected. Native Steam is still generally the safer baseline for compatibility.

---

## Uninstallation

```bash
./fusion180.sh uninstall
```

---

## Disclaimer

This project is an unofficial community guide and is not affiliated with or endorsed by Autodesk.
Fusion is proprietary software and must be downloaded from Autodesk's official website.
