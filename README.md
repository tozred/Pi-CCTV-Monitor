# PiMonitor

Lightweight RTSP camera display for Raspberry Pi 4/5 and modern Linux.
**Pure Bash + mpv** — no Python, no Node, no runtime overhead.

```
┌─────────────┬─────────────┐
│ Front Door  │   Backyard  │
├─────────────┼─────────────┤
│   Garage    │  Driveway   │
└─────────────┴─────────────┘
```

> Inspired by [displaycameras](https://github.com/Anonymousdog/displaycameras) — rebuilt for **Raspberry Pi OS Bookworm** using **mpv** instead of the long-deprecated omxplayer.

---

## Why PiMonitor

| | displaycameras | camplayer | **PiMonitor** |
|--|--|--|--|
| Player | omxplayer ❌ | omxplayer ❌ | **mpv** ✅ |
| Pi OS Bookworm | No | No | **Yes** |
| Pi 5 support | No | No | **Yes** |
| Language | Bash | Python | **Bash** |
| Hardware decode | VideoCore (gone) | VideoCore (gone) | **V4L2 M2M** |
| Layout control | Fixed grids | Fixed grids | **Auto grid + custom positions** |
| Install | Manual | Manual | **One command** |

---

## Quick Start

```bash
git clone https://github.com/benberlin85/PiMonitor.git
cd PiMonitor
sudo bash install.sh
sudo nano /etc/pimonitor/pimonitor.conf   # add your camera URLs
sudo systemctl start pimonitor
```

---

## Features

- **Zero runtime dependencies** — just Bash and mpv
- **Hardware decode on Pi 4/5** — V4L2 M2M (H.264, auto-detected)
- **Two layout modes**: auto even grid OR custom pixel-perfect positions
- **Page rotation** — display more cameras than fit in the grid
- **Watchdog** — dead streams restart automatically
- **One-command installer** with systemd service
- Boots straight into cameras in ~10 seconds

---

## Layout Control

### Auto grid (simple)

```bash
GRID_COLS=2
GRID_ROWS=2
WINDOW_GAP=4
```

### Custom positions (full control)

Define exact pixel rectangles — asymmetric layouts, mixed sizes, anything:

```bash
# 1 big camera left + 2 small right (1920×1080)
WINDOW_POSITIONS=(
    "0    0    1280 1080"   # big left
    "1280 0    640  540"    # small top-right
    "1280 540  640  540"    # small bottom-right
)
```

---

## Rotation

With 8 cameras and a 2×2 grid, PiMonitor creates 2 pages and rotates every N seconds:

```bash
ROTATION_INTERVAL=30   # seconds (0 = disabled)
```

---

## Useful Commands

```bash
# Live logs
sudo journalctl -u pimonitor -f

# Restart after config change
sudo systemctl restart pimonitor

# Status
sudo systemctl status pimonitor

# Debug mode (shows mpv commands)
sudo PIMONITOR_CONFIG=/etc/pimonitor/pimonitor.conf LOG_LEVEL=debug pimonitor
```

---

## Requirements

- Raspberry Pi 4B or Pi 5 (Pi 3 works with 2–3 streams)
- Raspberry Pi OS Bookworm Lite (recommended) or Ubuntu 22.04+
- HDMI monitor connected before boot
- `mpv` (installed by the installer)

---

## Docs

- [Installation Guide](docs/INSTALL.md)
- [Configuration Reference](docs/CONFIGURATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

## License

MIT
