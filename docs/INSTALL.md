# Installation Guide

## What you need

- Raspberry Pi 4B or Pi 5
- Raspberry Pi OS **Bookworm Lite** (64-bit) — [download here](https://www.raspberrypi.com/software/)
- HDMI display connected **before** powering on
- Internet connection (for apt packages)

> **Use Lite, not Full.** The desktop environment wastes RAM and CPU that should go to your camera streams. PiMonitor starts its own minimal X session.

---

## 1 — Flash your Pi

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) to flash Pi OS Bookworm Lite.

In Imager's Advanced Options (gear icon):
- Set hostname (e.g. `pimonitor`)
- Enable SSH
- Set username/password
- Set your Wi-Fi (or use ethernet)

---

## 2 — First boot

SSH in and update:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 3 — GPU memory (Pi 4 / Pi 3 only)

> **Pi 5 users: skip this step** — Pi 5 has a dedicated GPU memory pool.

For H.264 hardware decode on Pi 4, allocate GPU memory:

```bash
sudo nano /boot/firmware/config.txt
```

Add:

```ini
gpu_mem=128
```

Save and reboot:

```bash
sudo reboot
```

---

## 4 — Install PiMonitor

```bash
git clone https://github.com/benberlin85/PiMonitor.git
cd PiMonitor
sudo bash install.sh
```

The installer:
1. Installs `mpv`, `xserver-xorg-core`, `xinit`, `xrandr` via apt
2. Configures X11 for rootless operation
3. Copies files to `/opt/pimonitor/`
4. Installs config template to `/etc/pimonitor/pimonitor.conf`
5. Installs and enables a systemd service

**Install as a different user:**

```bash
sudo bash install.sh --user myuser
```

**Install without enabling the service:**

```bash
sudo bash install.sh --no-enable
```

---

## 5 — Configure

```bash
sudo nano /etc/pimonitor/pimonitor.conf
```

At minimum, update the `CAMERAS` array with your stream URLs:

```bash
CAMERAS=(
    "rtsp://admin:password@192.168.1.10/stream2"
    "rtsp://admin:password@192.168.1.11/stream2"
)
CAMERA_NAMES=("Front Door" "Backyard")

GRID_COLS=2
GRID_ROWS=1
```

See the full [Configuration Reference](CONFIGURATION.md) for all options.

---

## 6 — Start

```bash
sudo systemctl start pimonitor
```

Watch the logs to confirm everything is working:

```bash
sudo journalctl -u pimonitor -f
```

Expected output:

```
[INFO ] PiMonitor starting
[INFO ] Config  : /etc/pimonitor/pimonitor.conf
[INFO ] Cameras : 4
[INFO ] Hardware decode: v4l2m2m
[INFO ] Display: 1920x1080 (auto-detected)
[INFO ] Layout: 2x2 grid | cell 958x538 | gap 4px
[INFO ] Pages: 1 (4 slot(s) per page)
[INFO ] Page 1/1: cameras 1–4 of 4
[INFO ]   Slot 0 → 'Front Door' at 958x538+0+0
[INFO ]   Slot 1 → 'Backyard' at 958x538+962+0
[INFO ]   Slot 2 → 'Garage' at 958x538+0+542
[INFO ]   Slot 3 → 'Driveway' at 958x538+962+542
```

---

## 7 — Autostart on boot

The service is enabled by default. Reboot to verify autostart:

```bash
sudo reboot
```

PiMonitor should appear on the display within 10–15 seconds of boot.

---

## Updating

```bash
cd PiMonitor
git pull
sudo bash install.sh
sudo systemctl restart pimonitor
```

The installer preserves your existing `/etc/pimonitor/pimonitor.conf`.

---

## Uninstalling

```bash
sudo bash /opt/pimonitor/uninstall.sh   # or from the repo: sudo bash uninstall.sh
```

Config at `/etc/pimonitor/` is kept. Remove it manually if you want a clean sweep:

```bash
sudo rm -rf /etc/pimonitor
```
