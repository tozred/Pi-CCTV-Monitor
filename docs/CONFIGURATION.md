# Configuration Reference

Config file: `/etc/pimonitor/pimonitor.conf`
A fully-commented example is always at `/etc/pimonitor/pimonitor.conf.example`.

Restart after changes:

```bash
sudo systemctl restart pimonitor
```

---

## CAMERAS

```bash
CAMERAS=(
    "rtsp://admin:pass@192.168.1.10/stream2"
    "rtsp://admin:pass@192.168.1.11/stream2"
)

CAMERA_NAMES=("Front Door" "Backyard")   # optional, same order as CAMERAS
```

**Tips:**

- Use the camera's **sub-stream** (lower resolution) for multi-camera displays.
  Most cameras have two streams: main (1080p) and sub (480p). Sub-stream URLs often end with `/stream2` or have `subtype=1`.
- Special characters in passwords must be URL-encoded: `@` → `%40`, `#` → `%23`
- `CAMERA_NAMES` is optional but makes logs much more readable

**Common sub-stream URL patterns:**

| Brand | Sub-stream URL pattern |
|-------|----------------------|
| Hikvision | `rtsp://user:pass@ip/Streaming/Channels/102` |
| Dahua | `rtsp://user:pass@ip/cam/realmonitor?channel=1&subtype=1` |
| Reolink | `rtsp://user:pass@ip//h264Preview_01_sub` |
| Amcrest | `rtsp://user:pass@ip/cam/realmonitor?channel=1&subtype=1` |
| Generic | `rtsp://user:pass@ip/stream2` or `/substream` |

---

## LAYOUT — Mode A: Auto Grid

Fills the screen with an even grid. Simplest option.

```bash
GRID_COLS=2
GRID_ROWS=2
WINDOW_GAP=4    # pixels between windows (0 = no gap)
```

**Common presets:**

| Cameras | GRID_COLS | GRID_ROWS | Layout |
|---------|-----------|-----------|--------|
| 1 | 1 | 1 | Full screen |
| 2 | 2 | 1 | Side by side |
| 2 | 1 | 2 | Stacked |
| 4 | 2 | 2 | 2×2 |
| 6 | 3 | 2 | 3×2 |
| 9 | 3 | 3 | 3×3 |
| 12 | 4 | 3 | 4×3 |
| 16 | 4 | 4 | 4×4 |

---

## LAYOUT — Mode B: Custom Positions

Full pixel-level control. Uncomment `WINDOW_POSITIONS` and **comment out** (or remove) `GRID_COLS`/`GRID_ROWS`.

Format: `"X  Y  WIDTH  HEIGHT"` — all in pixels from the top-left corner of the screen.

```bash
WINDOW_POSITIONS=(
    "0    0    960  540"    # top-left
    "960  0    960  540"    # top-right
    "0    540  960  540"    # bottom-left
    "960  540  960  540"    # bottom-right
)
```

**Example: 1 large + 2 small (1920×1080)**

```
┌──────────────────┬──────────┐
│                  │  Cam 2   │
│      Cam 1       ├──────────┤
│   (big view)     │  Cam 3   │
└──────────────────┴──────────┘
```

```bash
WINDOW_POSITIONS=(
    "0    0    1280 1080"    # Cam 1: big left (1280×1080)
    "1280 0    640  540"     # Cam 2: top-right
    "1280 540  640  540"     # Cam 3: bottom-right
)
```

**Example: Wide panoramic at the bottom (1920×1080)**

```
┌──────────┬──────────┬──────────┐
│  Cam 1   │  Cam 2   │  Cam 3   │
├──────────┴──────────┴──────────┤
│         Cam 4 (wide)           │
└────────────────────────────────┘
```

```bash
WINDOW_POSITIONS=(
    "0    0    640  480"     # Cam 1
    "640  0    640  480"     # Cam 2
    "1280 0    640  480"     # Cam 3
    "0    480  1920 600"     # Cam 4 — full width panoramic
)
```

**Example: Unequal 5-camera layout (1920×1080)**

```bash
WINDOW_POSITIONS=(
    "0    0    960  540"     # top-left
    "960  0    960  540"     # top-right
    "0    540  640  540"     # bottom-left (narrow)
    "640  540  640  540"     # bottom-center
    "1280 540  640  540"     # bottom-right (narrow)
)
```

> **Tip**: Use `SCREEN_WIDTH` and `SCREEN_HEIGHT` in your calculations:
> ```bash
> SCREEN_WIDTH=1920; SCREEN_HEIGHT=1080
> # Then your positions reference exact pixel counts
> ```

---

## PAGE ROTATION

When you have more cameras than layout slots, PiMonitor creates multiple pages and cycles through them.

```bash
ROTATION_INTERVAL=30    # seconds between pages (0 = disabled)
ROTATION_ON_START="no"  # "no" = resume last page | "yes" = always start from page 1
```

**Example**: 10 cameras, 2×2 grid (4 slots) → 3 pages:
- Page 1: cameras 1–4
- Page 2: cameras 5–8
- Page 3: cameras 9–10

---

## DISPLAY

```bash
XDISPLAY=":0"           # X11 display number

SCREEN_WIDTH="auto"     # auto-detect via xrandr (recommended)
SCREEN_HEIGHT="auto"
# SCREEN_WIDTH=1920     # override if auto-detect is wrong
# SCREEN_HEIGHT=1080
```

---

## PLAYER

```bash
HWDEC="auto"            # hardware decode method (see below)
RTSP_TRANSPORT="tcp"    # tcp (reliable) | udp (lower latency)
RECONNECT_DELAY=5       # seconds before reconnecting a dead stream
STARTUP_DELAY=1         # seconds between launching each camera
BUFFER_SIZE="512k"      # stream read-ahead buffer
NETWORK_TIMEOUT=30      # seconds to wait for stream to open
```

### HWDEC values

| Value | Use |
|-------|-----|
| `auto` | PiMonitor picks the best method (default) |
| `v4l2m2m` | Pi 4, Pi 5 — V4L2 stateless hardware decode |
| `mmal` | Pi 3 and older — legacy VideoCore (deprecated) |
| `vaapi` | Intel / AMD graphics on x86 |
| `nvdec` | Nvidia GPU |
| `none` | Software decode — works everywhere, uses more CPU |

---

## WATCHDOG

```bash
HEALTH_INTERVAL=5    # seconds between watchdog checks
```

Lower values = faster stream recovery. Higher values = slightly less CPU overhead.

---

## LOGGING

```bash
LOG_LEVEL="info"      # info | debug
LOG_FILE=""           # empty = journald only | "/var/log/pimonitor.log"
```

Use `debug` when troubleshooting — it prints the full mpv command for each camera.

```bash
# Run manually in debug mode
sudo PIMONITOR_CONFIG=/etc/pimonitor/pimonitor.conf LOG_LEVEL=debug pimonitor
```
