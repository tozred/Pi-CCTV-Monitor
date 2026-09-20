# PiMonitor

**A reliable RTSP camera wall for Raspberry Pi.** Point it at your IP cameras,
hang a TV on the wall, and forget about it.

Pure Bash and mpv. No Python, no Node, no database, no web stack.

```
+-------------+-------------+-------------+
|  Entrance   |    Lobby    |     Bar     |
+-------------+-------------+-------------+
|  Corridor   |   Terrace   |  Car Park   |
+-------------+-------------+-------------+
```

[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%20%7C%20Linux-C51A4A?logo=raspberrypi&logoColor=white)](https://www.raspberrypi.com/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## Why this exists

`displaycameras` and `camplayer` were built on `omxplayer`, which no longer
exists on current Raspberry Pi OS. PiMonitor does the same job with **mpv**,
works on Pi OS Bookworm and Trixie, and is built to survive unattended
operation: dead streams reconnect, a crashed display restarts, and the whole
wall comes back by itself after a power cut.

It is running on production camera walls in hotels, which is where most of the
awkward details in this repo come from.

| | displaycameras | camplayer | **PiMonitor** |
|--|--|--|--|
| Player | omxplayer (gone) | omxplayer (gone) | **mpv** |
| Current Pi OS | no | no | **yes** |
| Pi 5 | no | no | **yes** |
| Finds your camera URLs | no | no | **yes** |
| Auto recovery | partial | partial | **stream + service + boot** |
| Layout control | fixed grids | fixed grids | **grids or exact pixels** |
| Branded boot screen | no | no | **yes** |

---

## Quick start

```bash
git clone https://github.com/tozred/Pi-CCTV-Monitor.git
cd Pi-CCTV-Monitor
sudo bash install.sh --all
```

Then find your cameras and their stream URLs:

```bash
sudo pimonitor-discover --scan 192.168.1.0/24 -u admin -p PASSWORD --config
```

Paste the output into `/etc/pimonitor/pimonitor.conf`, then:

```bash
sudo systemctl start pimonitor
```

That is the whole setup. The wall now starts on every boot.

---

## The camera discovery tool

Finding the right RTSP URL is the genuinely hard part of building a camera
wall. Vendors disagree, sub stream paths are undocumented, and some cameras
answer *every* URL with the main stream, which makes a wrong guess look
correct until your Pi melts under six 1080p streams.

`pimonitor-discover` handles it:

```bash
$ sudo pimonitor-discover --scan 10.0.0.0/24 -u admin -p secret --config

  > scanning 10.0.0.1-254 for open RTSP (port 554)...
  + found 3 host(s) with RTSP open

=== 10.0.0.21 ===
  + ONVIF on port 80/onvif/device_service
    profile Profile_1: H264 1920x1080 @25fps
    profile Profile_2: H264 640x360 @25fps
  + USING (sub, via onvif): 640x360
    rtsp://admin:secret@10.0.0.21:554/Streaming/Channels/102

=== 10.0.0.22 ===
  ! this camera answers EVERY path with the same stream
  ! its sub stream is switched off in the camera itself
```

It asks the camera over **ONVIF** what streams it really has, verifies each
one actually decodes, prefers the low resolution sub stream, and prints a
ready to paste config block. When ONVIF is unavailable it falls back to
probing the known RTSP paths of the common vendors.

See [docs/CAMERAS.md](docs/CAMERAS.md) for the per vendor URL reference.

---

## Features

- **Stream watchdog.** A dead camera is reconnected without disturbing the others.
- **Service recovery.** If X or the player dies, systemd restarts the wall.
- **Starts on boot**, waits for the network first.
- **Any layout.** Even grids, or exact pixel rectangles for asymmetric walls.
- **Page rotation** when you have more cameras than tiles.
- **Kiosk hardening** (`--harden`): never sleeps, never blanks, no wifi power saving.
- **Branded boot splash** (`--splash`): your logo instead of kernel text.
- **Low overhead.** Six sub streams on a Pi 4 sit around 70 percent of one core.

---

## Requirements

- Raspberry Pi 4 or 5 (a Pi 3 manages 2 to 3 streams), or any Linux box
- Raspberry Pi OS **Lite** (Bookworm or Trixie), Debian, or Ubuntu
- A screen connected at boot
- Cameras that speak RTSP (almost all of them do)

A desktop environment is not needed and not wanted. PiMonitor runs its own
minimal X session.

---

## Commands

```bash
pimonitor status      # what is playing right now
pimonitor rotate      # jump to the next page
pimonitor repair      # force a watchdog pass
pimonitor-discover    # find cameras and stream URLs

sudo systemctl restart pimonitor
journalctl -u pimonitor -f
```

---

## Documentation

| Guide | What is in it |
|-------|---------------|
| [Installation](docs/INSTALL.md) | full install, options, updating, removal |
| [Configuration](docs/CONFIGURATION.md) | every setting, layouts, rotation |
| [Cameras](docs/CAMERAS.md) | RTSP URLs per vendor, discovery, sub streams |
| [Kiosk setup](docs/KIOSK.md) | always on, boot splash, silent boot |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | black tiles, blue tiles, no signal, heat |
| [Examples](examples/) | ready made layout configs |

---

## Contributing

Bug reports and pull requests are welcome, especially RTSP URL patterns for
cameras not yet in [docs/CAMERAS.md](docs/CAMERAS.md). See
[CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT. See [LICENSE](LICENSE).
