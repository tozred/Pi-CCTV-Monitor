# Changelog

## 2.0

Rebuilt around lessons from two production hotel deployments.

### Added
- **`pimonitor-discover`**: finds cameras and their real RTSP URLs via ONVIF
  (`GetProfiles` / `GetStreamUri`), verifies each stream decodes, prefers the
  sub stream, and prints a ready to paste config. Pure Bash, includes
  `--selftest` for the WS-Security crypto.
- **`install.sh --harden`**: kiosk hardening. Masks sleep targets, stops idle
  and power key handling, disables screen blanking and wifi power saving,
  makes the journal persistent.
- **`install.sh --splash IMAGE`**: branded boot screen. Silences the rainbow
  splash, kernel text, logos and cursor, and shows your image from early boot
  until the cameras appear.
- `docs/CAMERAS.md`: RTSP URL reference per vendor, failure decoding, and the
  "camera that answers every path" trap.
- `docs/KIOSK.md`: always on setup, boot splash, recovery testing, thermals.
- `examples/`: five ready made layout configurations.
- `pimonitor rotate` and `pimonitor repair` now actually work, via signals to
  the running daemon.

### Fixed
- **Startup crash.** `${#ARRAY[@]:-0}` is invalid in Bash 5.2 and aborted the
  daemon immediately. Replaced with a `declare -p` guard.
- **Invalid mpv flag.** `--no-osd-level` is not a real option and made every
  player exit at once.
- **Solid blue tiles.** The direct `v4l2m2m` decode path cannot map frames into
  the X11 renderer. `auto` now selects `v4l2m2m-copy` on a Pi.
- **Zombie black windows.** Removed `--loop`: on a stream error mpv must exit so
  the watchdog sees a dead process and reconnects.
- **Stalled streams held forever.** Added a demuxer level timeout so a camera
  that accepts the connection then sends nothing is dropped and retried.
- **Blocking watchdog.** A dead camera no longer stalls the whole loop for
  `RECONNECT_DELAY`; retries are scheduled per slot.
- **`pimonitor status`** looked for pid files that were never written.
- **Slow restarts.** Added `TimeoutStopSec=10`; X and mpv can ignore SIGTERM
  and used to hold the restart for 90 seconds.
- **tty contention.** The unit now declares `Conflicts=getty@tty1.service`.
- **Boot ordering.** `network-online.target` was listed under `After` without
  `Wants`, so it did nothing and streams could start before the network.
- Config file is installed mode `600`; it contains camera passwords.
- Installer defaults to the uid 1000 user instead of assuming `pi`.

### Changed
- Lower resource use: `--no-audio`, no OSC or scripts, `--vd-lavc-fast`,
  frame dropping, smaller read ahead and back buffer. On a 6 camera wall this
  took CPU from 145% to 73% and temperature from 79C to 74C.
- `DEMUXER_MAX_BYTES` (default `32MiB`) and `MPV_EXTRA_OPTS` are configurable.
- An explicit `SCREEN_WIDTH` / `SCREEN_HEIGHT` now forces that mode with
  xrandr, for TVs that advertise modes they cannot display.
- `uninstall.sh` reverts hardening and restores the boot files from backups.

## 1.0

Initial release. Pure Bash and mpv replacement for displaycameras and
camplayer, with grid and custom layouts, page rotation, and a stream watchdog.
