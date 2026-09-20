# Contributing

Thanks for looking. This project stays deliberately small: **Bash and mpv, no
runtime dependencies**. Please keep additions in that spirit.

## The most useful contribution

**RTSP URL patterns for cameras not yet listed.** Finding the right URL is the
hardest part of this project for most people. If you worked out the paths for a
camera that is not in [docs/CAMERAS.md](docs/CAMERAS.md), please open a PR or
an issue with:

- make and model
- main stream path
- sub stream path
- anything unusual (separate ONVIF account, non standard port, ignores the path)

`pimonitor-discover --scan ... ` output with credentials removed is ideal.

## Reporting bugs

Include the diagnostics listed at the end of
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md). Please strip camera
passwords before posting, the last command there does it for you.

## Code

- Target **Bash 5** and keep `set -uo pipefail` behaviour intact
- Run `bash -n` on anything you change, and `shellcheck` if you have it
- No Python, Node or other runtimes
- Match the existing style: lowercase function names prefixed `_`, aligned
  comment blocks, no clever one liners that need a second read
- Comments explain **why**, not what. The tricky parts of this codebase are
  tricky for non obvious reasons, for example:

```bash
# No --loop here: on stream error mpv must EXIT so the watchdog sees a dead
# pid and reconnects; --loop leaves a black zombie window forever.
```

That comment exists because someone will otherwise "fix" it.

## Testing

There is no CI. Before opening a PR, please confirm on real hardware:

```bash
bash -n pimonitor install.sh uninstall.sh pimonitor-discover
pimonitor-discover --selftest

sudo bash install.sh
sudo systemctl start pimonitor      # cameras appear
sudo pkill -f "pimonitor:CAM"       # watchdog brings it back
sudo reboot                          # comes back by itself
```

The reboot test matters most. This software runs unattended on walls that
nobody logs into for months.

## Scope

Good fits: camera compatibility, layout and display handling, reliability,
documentation, packaging.

Out of scope: recording, motion detection, a web UI, cloud anything. Use
Frigate, Shinobi or Blue Iris for those. PiMonitor displays live streams on a
screen, and tries to do only that well.
