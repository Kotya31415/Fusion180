
    _______          _              __   ____    _____
	|  ____|        (_)            /_ | /  _  \ /  _  \
	| |__ _   _ ___  _  ___  _ __   | | \ (_) / | | | |
	|  __| | | / __|| |/ _ \| '_ \  | | /  _  \ | | | |
	| |  | |_| \__ \| | (_) | | | | | ||  (_)  || |_| |
	|_|   \__,_|__ /|_|\___/|_| |_| |_| \_ ___/ \_____/

						 Turn Fusion 180° toward Linux.


## Before You Start

This project does **not** include Autodesk Fusion Installer.

Due to Autodesk's license, you must download the latest Fusion installer yourself from Autodesk's official website.

Place the installer in your `~/Downloads` directory (or specify its path when running the installer script).

Example:

~/Downloads/Fusion Client Downloader.exe

## Prerequisites

### Tested Environment

- Arch , CachyOS , Fedora , Debian
- KDE Plasma 6
- Wayland
- Steam(Native Version) ← Flatpak is currently not supported
- GE-Proton 11-1 

### Tested Environment

- i7 12700H + Iris Xe + RTX4050 laptop

### Required Drivers

#### Intel GPU

- mesa
- vulkan-intel

#### NVIDIA GPU (Hybrid Graphics)

- nvidia-open-dkms (or nvidia-dkms)
- nvidia-utils
- vulkan-icd-loader

### Required Packages

- Steam(Native Version) ← Flatpak is currently not supported
- protonup-qt
- Fusion Installer from Autodesk

### Important Notes
- A login screen may appear during the installation of Fusion; please do not log in at this time.
- After logging into Fusion via your browser, you may see a login error message on the Fusion interface, but this is normal.    Click the “OK” button to continue, and you should be able to log in.
- After clicking the “New Design” button, the entire screen will turn gray and you will be unable to use the mouse, but you can navigate using the arrow keys and the Enter key. You can also exit by pressing the Esc key.

> **Disclaimer**
>
> This project is an unofficial community guide and is not affiliated with or endorsed by Autodesk.
> Fusion 360 is proprietary software and must be downloaded from Autodesk's official website.
