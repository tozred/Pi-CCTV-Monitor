# Troubleshooting

## Quick diagnostics

```bash
# Is it running?
sudo systemctl status pimonitor

# Live log
sudo journalctl -u pimonitor -f

# Debug — shows exact mpv commands
sudo PIMONITOR_CONFIG=/etc/pimonitor/pimonitor.conf LOG_LEVEL=debug pimonitor

# Test a stream manually
DISPLAY=:0 mpv "rtsp://admin:password@192.168.1.10/stream2"
```

---

## Black screen / no cameras

**Check 1 — Service status**

```bash
sudo systemctl status pimonitor
```

If failed, read the full error:

```bash
sudo journalctl -u pimonitor --no-pager -n 50
```

**Check 2 — X11 permissions**

```bash
cat /etc/X11/Xwrapper.config
```

Must contain:
```
allowed_users = anybody
needs_root_rights = no
```

If not, re-run the installer: `sudo bash install.sh`

**Check 3 — Group membership**

```bash
groups pi
```

Must include `video input render`. If not:

```bash
sudo usermod -aG video,input,render pi
sudo reboot
```

**Check 4 — Stale X11 lock file**

If the service crashed and left a lock file:

```bash
sudo rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
sudo systemctl restart pimonitor
```

---

## Streams not playing / black camera windows

**Test the URL directly:**

```bash
DISPLAY=:0 mpv "rtsp://admin:password@192.168.1.10/stream2"
```

If this doesn't work, the issue is the URL, credentials, or network — not PiMonitor.

**Wrong URL format?** Encode special characters in passwords:
- `@` → `%40`
- `#` → `%23`
- `$` → `%24`

**Network issue?** Try TCP transport in config:
```bash
RTSP_TRANSPORT="tcp"
```

**Stream times out?** Increase network timeout:
```bash
NETWORK_TIMEOUT=60
```

---

## High CPU / choppy playback

**Hardware decode not working.**

Check in debug mode — you should see `--hwdec=v4l2m2m` in the mpv command.

If hardware decode is falling back to software:

```bash
# Check V4L2 devices
ls /dev/video*
# Should show /dev/video0 /dev/video10 /dev/video11 etc.
```

If `/dev/video10` is missing:

```bash
sudo modprobe v4l2-mem2mem
sudo modprobe bcm2835-codec   # Pi 4
```

To load on every boot:

```bash
echo -e "v4l2-mem2mem\nbcm2835-codec" | sudo tee -a /etc/modules
```

**Using main streams?** Switch to sub-streams:

```bash
# Instead of /stream1 (1080p), use /stream2 (480p)
CAMERAS=(
    "rtsp://admin:pass@192.168.1.10/stream2"
)
```

**Too many streams?** Pi 4 can typically handle 4–6 sub-streams at once. Pi 5 can handle more.

---

## Wrong resolution / misaligned windows

**Check what xrandr detects:**

```bash
DISPLAY=:0 xrandr --current
```

**Override resolution in config:**

```bash
SCREEN_WIDTH=1920
SCREEN_HEIGHT=1080
```

**Overscan / black borders?** Disable in `/boot/firmware/config.txt`:

```ini
disable_overscan=1
```

**Force HDMI resolution** in `/boot/firmware/config.txt`:

```ini
# 1080p60
hdmi_group=1
hdmi_mode=16
```

---

## Screen goes blank after a while

Disable power management. Run at startup (add to xinitrc or a startup script):

```bash
xset s off
xset -dpms
xset s noblank
```

PiMonitor already calls these on startup. If the display still blanks, check your monitor's own sleep settings.

---

## Service restarts in a loop

Usually means the config has errors or the display isn't ready.

```bash
# Run manually to see exact error
sudo -u pi DISPLAY=:0 PIMONITOR_CONFIG=/etc/pimonitor/pimonitor.conf pimonitor
```

**Config error?** Check for syntax issues:

```bash
bash -n /etc/pimonitor/pimonitor.conf && echo "Syntax OK"
```

---

## GPU memory warning (Pi 4 / Pi 3)

If the log says GPU memory is low:

```bash
sudo nano /boot/firmware/config.txt
```

Add:

```ini
gpu_mem=128
```

Reboot. Pi 5 does not need this.

---

## Getting help

Collect this info before opening an issue:

```bash
# System info
uname -a
cat /etc/os-release
tr -d '\0' < /sys/firmware/devicetree/base/model 2>/dev/null
vcgencmd get_mem gpu 2>/dev/null

# Hardware
ls /dev/video*

# Logs (last 100 lines)
sudo journalctl -u pimonitor --no-pager -n 100
```

Open an issue at https://github.com/benberlin85/PiMonitor with the above output and your config (replace passwords with `***`).
