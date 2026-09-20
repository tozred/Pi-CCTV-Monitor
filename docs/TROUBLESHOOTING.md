# Troubleshooting

Every problem below was hit on a real deployment.

## First look

```bash
systemctl status pimonitor          # is it running
journalctl -u pimonitor -n 50       # why did it stop
pimonitor status                    # which streams are alive
vcgencmd measure_temp               # is the Pi too hot
vcgencmd get_throttled              # 0x0 is healthy
```

---

## Tiles are solid BLUE

**Cause:** the Pi hardware decoder handing frames to X11. The direct
`v4l2m2m` path cannot map its frames into the X renderer and paints blue.

**Fix:** use the copy variant, or software decoding.

```bash
# /etc/pimonitor/pimonitor.conf
HWDEC="v4l2m2m-copy"     # what "auto" now picks on a Pi
# or, if that still misbehaves:
HWDEC="none"
```

---

## Tiles are BLACK, or the wall dies at random

**Cause:** on some Raspberry Pi kernels (seen on 6.18.x) the
`bcm2835_codec` V4L2 driver is broken. It floods the log with
`__vb2_queue_cancel` warnings, wedges the display, and can take the machine
down with it.

Check:

```bash
dmesg | grep -c "vb2_queue_cancel"      # anything above 0 is bad
dmesg | grep -iE "WARNING.*videobuf2"
```

**Fix:** turn hardware decoding off. A Pi 4 handles six sub streams in
software comfortably.

```bash
HWDEC="none"
```

### A black tile only right after boot

Normal. A camera shows nothing until its first keyframe arrives, which can take
up to a minute on a stream with a long keyframe interval. It fills in by
itself. If it is still black after two minutes, treat it as a dead stream.

---

## One camera never appears

Test its URL directly on the Pi:

```bash
ffprobe -rtsp_transport tcp -i "rtsp://user:pass@192.168.1.10:554/PATH"
```

| Result | Meaning |
|--------|---------|
| resolution printed | the URL is fine, the problem is PiMonitor's config |
| `401 Unauthorized` | wrong username or password |
| `404 Stream Not Found` | wrong path, see [CAMERAS.md](CAMERAS.md) |
| hangs with no reply | wrong path on a camera that ignores bad requests |

Then ask the camera what it actually offers:

```bash
sudo pimonitor-discover 192.168.1.10 -u admin -p PASSWORD
```

### A stream connects but stays frozen or blank

Some cameras accept the TCP connection and then never send data. PiMonitor
already passes a demuxer timeout so mpv gives up and the watchdog reconnects.
If a camera does this constantly, raise the timeout:

```bash
NETWORK_TIMEOUT=45
```

---

## Nothing on screen at all

**1. Is the service running**

```bash
systemctl status pimonitor
journalctl -u pimonitor -n 50
```

**2. Is another display manager holding the screen**

A desktop install will fight PiMonitor for tty1.

```bash
systemctl is-active lightdm gdm3 sddm
sudo systemctl disable --now lightdm
sudo systemctl set-default multi-user.target
```

**3. X permissions**

```bash
cat /etc/X11/Xwrapper.config     # needs: allowed_users = anybody
groups pimonitor-user            # needs video, input, render, tty
```

**4. A stale X lock after a hard crash**

```bash
sudo rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
sudo systemctl restart pimonitor
```

---

## The TV says "no signal"

Usually the TV cannot actually do the mode it advertises. One hotel TV reported
support for 1920x1080 but went dark when driven at it, and only worked at
1280x720.

```bash
export DISPLAY=:0
export XAUTHORITY=$(ls -t /tmp/serverauth.* | head -1)
xrandr --current          # what the screen really offers
```

Pin a mode PiMonitor should force:

```bash
SCREEN_WIDTH=1280
SCREEN_HEIGHT=720
```

### Wrong aspect ratio, or a tiny desktop in a corner

Check for a **ghost output**: an HDMI port that reports "connected" with a
0 byte EDID. X can pick it as primary and set a small mode.

```bash
for c in /sys/class/drm/card*-HDMI*; do
  echo "$c: $(cat $c/status) edid_bytes=$(wc -c < $c/edid)"
done
```

An output that is `connected` with `edid_bytes=0` is a ghost. It is usually
caused by forcing a mode in `cmdline.txt`:

```bash
# remove any line like this from /boot/firmware/cmdline.txt
video=HDMI-A-1:1920x1080@60D
```

Do not force-enable an HDMI port that has nothing plugged into it.

---

## Overheating or throttling

```bash
vcgencmd measure_temp
vcgencmd get_throttled
```

`0x80000` means the soft temperature limit was reached. In order of impact:

1. Move every camera to its **sub stream**. On one wall this took CPU from
   145% to 73% and temperature from 79C to 74C with no visible difference.
2. Fit a heatsink or fan.
3. Show fewer tiles, or rotate pages instead of all cameras at once.
4. Lower `SCREEN_WIDTH` and `SCREEN_HEIGHT`. Driving a 4K panel to show SD
   cameras is wasted work: pin 1920x1080.

---

## Choppy video or high CPU

```bash
ps -o pcpu,rss,comm -C mpv                       # per stream cost
ps -o pcpu --no-headers -C mpv | paste -sd+ | bc # total
```

- Are you on sub streams? This is almost always the answer.
- A Pi 4 handles roughly 6 sub streams, a Pi 3 about 2 to 3.
- Lower `DEMUXER_MAX_BYTES` on a 1 GB or 2 GB Pi.

---

## The service restarts in a loop

```bash
journalctl -u pimonitor -n 100 --no-pager
bash -n /etc/pimonitor/pimonitor.conf     # config syntax check
```

The config is sourced as Bash, so one stray quote stops everything. Check that
`CAMERAS` is a proper array and that the URLs are quoted.

---

## Restarting takes over a minute

X and mpv sometimes ignore the shutdown signal. The bundled unit caps this with
`TimeoutStopSec=10`. If you wrote your own unit, add it.

---

## The splash stays and the cameras never appear

The splash must release the VT before X can claim it. Check the drop-in:

```bash
cat /etc/systemd/system/pimonitor.service.d/10-splash.conf
```

It must contain:

```ini
[Service]
ExecStartPre=-/bin/systemctl stop pimonitor-splash.service
```

---

## Discovery finds nothing

```bash
pimonitor-discover --selftest        # verifies the ONVIF auth crypto
```

If the self test passes but cameras are still not found:

- Is the Pi on the same subnet, and is port 554 open
  (`nc -z -w2 CAMERA_IP 554`)
- ONVIF is often **disabled by default**. The tool reports this explicitly.
  Enable it in the camera web interface.
- Some cameras keep separate accounts for ONVIF and for RTSP.
- Rapid repeated failures can trigger a temporary lockout. Wait a minute.

---

## Reporting a bug

Please include:

```bash
uname -a
cat /etc/os-release | head -2
tr -d '\0' < /sys/firmware/devicetree/base/model 2>/dev/null; echo
mpv --version | head -1
systemctl status pimonitor --no-pager
journalctl -u pimonitor -n 100 --no-pager
sed 's|://[^@]*@|://USER:PASS@|g' /etc/pimonitor/pimonitor.conf
```

That last command strips your camera passwords. Please check the output before
posting it.
