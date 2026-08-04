
    _______          _              __   _____   _____
	|  ____|        (_)            /_ | /  _  \ /  _  \
	| |__ _   _ ___  _  ___  _ __   | | \ (_) / | | | |
	|  __| | | / __|| |/ _ \| '_ \  | | /  _  \ | | | |
	| |  | |_| \__ \| | (_) | | | | | ||  (_)  || |_| |
	|_|   \__,_|__ /|_|\___/|_| |_| |_| \_____/ \_____/

						 Turn Fusion 180° toward Linux.


Fusion180 is an unofficial, community-driven guide and script set for running **Autodesk Fusion** natively on Linux, using **Steam + GE-Proton** instead of a plain Wine/DXVK prefix.

---

## Before You Start

This project does **not** include the Autodesk Fusion installer.

Due to Autodesk's license terms, you must download the latest installer yourself from the [official Autodesk website](https://www.autodesk.com/products/fusion-360/overview).

Place the installer in your `~/Downloads` directory (or point the installer script at its path).

```
~/Downloads/Fusion Client Downloader.exe
```

---

## Prerequisites

### Tested Environment

| Component        | Requirement                          |
|-------------------|---------------------------------------|
| Distro            | Arch, CachyOS, Fedora, Debian        |
| Desktop           | KDE Plasma 6                         |
| Display server    | Wayland                              |
| Steam             | Native package (**Flatpak not supported**) |
| Compatibility tool | GE-Proton 11-1                      |

### Hardware Tested On

| Component | Model                         |
|-----------|--------------------------------|
| CPU / iGPU | Intel i7-12700H / Iris Xe    |
| dGPU       | NVIDIA RTX 4050 (hybrid graphics) |

### Required Drivers

| GPU              | Packages                                              |
|-------------------|--------------------------------------------------------|
| Intel        | `mesa`, `vulkan-intel`                                |
| NVIDIA    | `nvidia-open-dkms` (or `nvidia-dkms`), `nvidia-utils`, `vulkan-icd-loader` |

### Required Packages

| Package                        | Notes                          |
|----------------------------------|---------------------------------|
| Steam (native version)           | Flatpak build is **not supported** |
| protonup-qt                      | Used to install/manage GE-Proton |
| Fusion Installer (from Autodesk) | Not redistributed — download it yourself |

---

## Installation

**1. Install GE-Proton 11-1 and Steam**

Open `protonup-qt` and install GE-Proton 11-1 (or newer). This is a GUI step, no command needed.
Open Steam and login.

**2. Get the Fusion180 scripts**

```bash
git clone https://github.com/Kotya31415/Fusion180.git
cd Fusion180
chmod +x installer.sh launch-fusion.sh
```

**3. Download the Fusion installer**

Download the installer from the [official Autodesk website](https://www.autodesk.com/products/fusion-360/overview) and place it in `~/Downloads`:

```
~/Downloads/Fusion Client Downloader.exe
```

**4. Run the installer script**

```bash
./installer.sh
```

**5. Launch Fusion**

```bash
~/launch-fusion.sh
```

---

## Known Issues

| # | Symptom | Status / Workaround |
|---|----------|----------------------|
| 1 | A login screen appears during Fusion installation. | This is expected — **do not log in here.** Continue the install normally. |
| 2 | After signing in through the browser, Fusion shows a login error on its interface. | This is normal. Click **OK** to continue; you should be signed in correctly afterward. |
| 3 | Clicking **New Design** turns the whole screen gray. Mouse input stops working, but keyboard navigation (arrow keys, Enter) and **Esc** to exit still work. | Don't use the mouse here — navigate the dialog with the arrow keys, confirm with Enter, and press Esc if you need to back out.  |


If you run into something not listed here, please open an issue with your distro, kernel version, and full console output.

---

## Disclaimer

> This project is an unofficial community guide and is not affiliated with or endorsed by Autodesk.
> Fusion is proprietary software and must be downloaded from Autodesk's official website.
