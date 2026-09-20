# Configuration reference

Config file: `/etc/pimonitor/pimonitor.conf`
A fully commented example lives at `/etc/pimonitor/pimonitor.conf.example`.

The file is **sourced as Bash**, so normal shell syntax applies and a stray
quote will stop the service. Check it after editing:

```bash
bash -n /etc/pimonitor/pimonitor.conf
sudo systemctl restart pimonitor
```

---

## Cameras

```bash
CAMERAS=(
    "rtsp://admin:pass@192.168.1.10:554/Streaming/Channels/102"
    "rtsp://admin:pass@192.168.1.11:554/Streaming/Channels/102"
)

CAMERA_NAMES=( "Front Door" "Backyard" )   # optional, same order
```

`CAMERA_NAMES` only affects logs and `pimonitor status`, but it makes both far
easier to read.

Generate this block automatically:

```bash
sudo pimonitor-discover --scan 192.168.1.0/24 -u admin -p PASS --config
```

**Use sub streams for any multi camera layout.** See [CAMERAS.md](CAMERAS.md).

---

## Display

```bash
XDISPLAY=":0"

SCREEN_WIDTH="auto"      # auto detect with xrandr
SCREEN_HEIGHT="auto"
```

Setting both to a number makes PiMonitor **force** that mode with xrandr. Use
this when a TV advertises a mode it cannot actually display, or when you want
to drive a 4K panel at 1080p to save CPU:

```bash
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
```

---

## Layout, mode A: grid

The screen is divided evenly.

```bash
GRID_COLS=3
GRID_ROWS=2
WINDOW_GAP=4      # pixels between tiles, 0 for none
```

| Cameras | Cols | Rows | Notes |
|---------|------|------|-------|
| 1 | 1 | 1 | full screen |
| 2 | 2 | 1 | side by side |
| 4 | 2 | 2 | the classic quad |
| 6 | 3 | 2 | fills 16:9 exactly |
| 9 | 3 | 3 | |
| 12 | 4 | 3 | |

Match the grid to your camera count. Six cameras in a 3x3 grid leaves an empty
black row; 3x2 fills the screen and keeps the tiles 16:9.

---

## Layout, mode B: exact positions

Define each slot as `"X Y WIDTH HEIGHT"` in pixels. This **overrides**
`GRID_COLS`, `GRID_ROWS` and `WINDOW_GAP`.

```bash
WINDOW_POSITIONS=(
    "0    0    320 180"    # small, top row
    "320  0    320 180"
    "640  0    320 180"
    "960  0    320 180"
    "960  180  320 270"    # right column
    "960  450  320 270"
    "0    180  960 540"    # the large view
)
```

Cameras fill slots in order, so the 7th entry in `CAMERAS` lands in the 7th
slot. Keep tiles at 16:9 (for example 960x540, 640x360, 320x180) so the
picture is not distorted.

A worked example is in
[examples/focus-plus-thumbnails.conf](../examples/focus-plus-thumbnails.conf).

---

## Page rotation

With more cameras than slots, PiMonitor makes pages and cycles them.

```bash
ROTATION_INTERVAL=30       # seconds per page, 0 disables rotation
ROTATION_ON_START="no"     # "no" resumes the last page, "yes" restarts at 1
```

10 cameras in a 2x2 grid gives 3 pages: 1 to 4, 5 to 8, 9 to 10.

Jump manually:

```bash
pimonitor rotate
```

---

## Player

```bash
HWDEC="auto"                # see the table below
RTSP_TRANSPORT="tcp"        # tcp is reliable, udp is lower latency but lossy
RECONNECT_DELAY=5           # seconds before retrying a dead stream
STARTUP_DELAY=1             # seconds between launching each camera
BUFFER_SIZE="512k"          # stream read ahead
NETWORK_TIMEOUT=30          # seconds to wait for a stream to open
DEMUXER_MAX_BYTES="32MiB"   # per stream memory cap
MPV_EXTRA_OPTS=""           # extra mpv flags, advanced
```

### HWDEC

| Value | When to use |
|-------|-------------|
| `auto` | default. Picks `v4l2m2m-copy` on a Pi and validates it against mpv |
| `v4l2m2m-copy` | Pi 4 and 5. The plain `v4l2m2m` path renders solid blue on X11 |
| `none` | **software decoding.** Use this if you see black tiles, blue tiles or random crashes: the Pi V4L2 decoder is broken on some kernels |
| `vaapi` | Intel or AMD graphics |
| `nvdec` | Nvidia |

A Pi 4 decodes six sub streams in software at about 70 percent of one core, so
`none` is a perfectly good production setting.

### Memory

`DEMUXER_MAX_BYTES` is per stream. On a 1 GB or 2 GB Pi keep it at `32MiB` or
lower. Only raise it on a 4 GB or 8 GB board with high latency cameras.

---

## Watchdog

```bash
HEALTH_INTERVAL=5     # seconds between checks
```

Every interval PiMonitor checks each player process. A dead one is restarted
after `RECONNECT_DELAY`, without touching the other tiles.

---

## Logging

```bash
LOG_LEVEL="info"      # info or debug
LOG_FILE=""           # empty means journald only
```

`debug` prints the exact mpv command for each camera, which is the fastest way
to see what is really being requested:

```bash
sudo systemctl stop pimonitor
sudo -u YOUR_USER PIMONITOR_CONFIG=/etc/pimonitor/pimonitor.conf \
     LOG_LEVEL=debug /usr/local/bin/pimonitor
```

---

## Full example

```bash
CAMERAS=(
    "rtsp://admin:pass@192.168.1.10:554/Streaming/Channels/102"
    "rtsp://admin:pass@192.168.1.11:554/Streaming/Channels/102"
    "rtsp://admin:pass@192.168.1.12:554/Streaming/Channels/102"
    "rtsp://admin:pass@192.168.1.13:554/Streaming/Channels/102"
    "rtsp://admin:pass@192.168.1.14:554/Streaming/Channels/102"
    "rtsp://admin:pass@192.168.1.15:554/Streaming/Channels/102"
)
CAMERA_NAMES=( "Entrance" "Lobby" "Bar" "Corridor" "Terrace" "Car Park" )

SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080

GRID_COLS=3
GRID_ROWS=2
WINDOW_GAP=4

ROTATION_INTERVAL=0
HWDEC="none"
NETWORK_TIMEOUT=45
```

More in [examples/](../examples/).
