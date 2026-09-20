# Installation

## Requirements

- Raspberry Pi 4 or 5 recommended (a Pi 3 manages 2 to 3 streams), or any Linux PC
- Raspberry Pi OS **Lite** (Bookworm or Trixie), Debian 12+, or Ubuntu 22.04+
- A screen connected **before** boot
- Network access to your cameras

A desktop environment is neither needed nor wanted. PiMonitor runs its own
minimal X session. If you already have a desktop installed, see
[KIOSK.md](KIOSK.md) for how to strip it.

---

## Install

```bash
git clone https://github.com/tozred/Pi-CCTV-Monitor.git
cd Pi-CCTV-Monitor
sudo bash install.sh --all
```

`--all` is the recommended setup for a wall mounted screen. It applies kiosk
hardening and a boot splash on top of the base install.

### Options

| Option | What it does |
|--------|--------------|
| *(none)* | install, enable on boot |
| `--harden` | never sleep or blank, no wifi power saving, persistent logs |
| `--splash IMAGE` | show IMAGE during boot and silence the boot text |
| `--all` | `--harden` plus the bundled example splash |
| `--user USER` | run the display as USER (default: the uid 1000 user) |
| `--no-enable` | do not start on boot |
| `-h`, `--help` | usage |

Examples:

```bash
sudo bash install.sh                              # plain install
sudo bash install.sh --harden                     # always on, no splash
sudo bash install.sh --splash ~/logo.png          # branded boot
sudo bash install.sh --all --user kiosk           # everything, specific user
```

Re-running the installer is safe. Your `/etc/pimonitor/pimonitor.conf` is never
overwritten.

### What gets installed

| Path | Purpose |
|------|---------|
| `/opt/pimonitor/` | program files and the splash image |
| `/usr/local/bin/pimonitor` | the display daemon |
| `/usr/local/bin/pimonitor-discover` | the camera discovery tool |
| `/etc/pimonitor/pimonitor.conf` | your configuration (mode 600) |
| `/etc/systemd/system/pimonitor.service` | the service |
| `/etc/systemd/system/pimonitor-splash.service` | the boot splash (with `--splash`) |

Packages installed: `mpv`, `xserver-xorg`, `xinit`, `x11-utils`,
`x11-xserver-utils`, plus `ffmpeg` for stream probing and `fbi` for the splash.

---

## Configure

### 1. Find your cameras

```bash
sudo pimonitor-discover --scan 192.168.1.0/24 -u admin -p PASSWORD --config
```

This scans for cameras, asks each one over ONVIF what streams it has, verifies
they decode, and prints a ready to paste block. See [CAMERAS.md](CAMERAS.md)
if a camera does not cooperate.

### 2. Edit the config

```bash
sudo nano /etc/pimonitor/pimonitor.conf
```

Paste the `CAMERAS` and `CAMERA_NAMES` block, then set the grid:

```bash
GRID_COLS=3
GRID_ROWS=2
```

Or copy a ready made layout from [examples/](../examples/):

```bash
sudo cp examples/6-cameras-3x2.conf /etc/pimonitor/pimonitor.conf
sudo chmod 600 /etc/pimonitor/pimonitor.conf
```

Full reference: [CONFIGURATION.md](CONFIGURATION.md).

### 3. Start

```bash
sudo systemctl start pimonitor
journalctl -u pimonitor -f
```

### 4. Reboot to confirm

```bash
sudo reboot
```

The wall should come back on its own. This is the test that matters for an
unattended screen.

---

## Updating

```bash
cd Pi-CCTV-Monitor
git pull
sudo bash install.sh --all
sudo systemctl restart pimonitor
```

Your configuration is preserved.

---

## Removal

```bash
sudo bash uninstall.sh            # keep the config
sudo bash uninstall.sh --purge    # remove everything
```

This also unmasks the sleep targets and restores the original `cmdline.txt` and
`config.txt` from the backups the installer made. Reboot afterwards to get the
normal boot screen back.

---

## Installing without the script

```bash
sudo apt-get install -y --no-install-recommends \
    mpv xserver-xorg-core xserver-xorg xinit x11-utils x11-xserver-utils ffmpeg

sudo install -d /opt/pimonitor /etc/pimonitor
sudo install -m 755 pimonitor pimonitor-discover /opt/pimonitor/
sudo ln -sf /opt/pimonitor/pimonitor /usr/local/bin/pimonitor
sudo ln -sf /opt/pimonitor/pimonitor-discover /usr/local/bin/pimonitor-discover
sudo install -m 600 pimonitor.conf.example /etc/pimonitor/pimonitor.conf

printf 'allowed_users = anybody\nneeds_root_rights = no\n' \
  | sudo tee /etc/X11/Xwrapper.config
sudo usermod -aG video,input,render,tty "$USER"

sed -e "s|__RUN_USER__|$USER|g" -e "s|__INSTALL_DIR__|/opt/pimonitor|g" \
    -e "s|__CONFIG_DIR__|/etc/pimonitor|g" systemd/pimonitor.service \
  | sudo tee /etc/systemd/system/pimonitor.service >/dev/null
sudo systemctl daemon-reload && sudo systemctl enable --now pimonitor
```

---

## Running it without systemd

Useful for testing on a desktop Linux machine:

```bash
PIMONITOR_CONFIG=./my.conf LOG_LEVEL=debug ./pimonitor
```

It will use the X display given by `XDISPLAY` (default `:0`), so it can run
inside an existing desktop session.
