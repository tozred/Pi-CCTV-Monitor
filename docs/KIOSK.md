# Kiosk setup

A wall mounted screen has to survive on its own: no sleeping, no screensaver,
no login prompt, no kernel text, and it must come back by itself after a power
cut. This page covers everything the installer does with `--harden` and
`--splash`, and how to do it by hand.

```bash
sudo bash install.sh --all
```

---

## Always on (`--harden`)

| What | Why |
|------|-----|
| `sleep.target` and friends masked | nothing can suspend the machine |
| logind ignores power keys and idle | a stray keypress will not put it to sleep |
| screen blanking disabled | the picture never goes black on its own |
| wifi power saving off | power saving causes stream stalls and dropouts |
| persistent journal | crash evidence survives the reboot |
| bluetooth and avahi disabled | not needed on a camera wall |

By hand:

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

sudo tee /etc/systemd/logind.conf.d/10-no-sleep.conf >/dev/null <<'CONF'
[Login]
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
IdleAction=ignore
CONF
sudo systemctl restart systemd-logind

# Raspberry Pi OS
sudo raspi-config nonint do_blanking 1

# stops wifi power saving stalling streams
printf '[connection]\nwifi.powersave = 2\n' \
  | sudo tee /etc/NetworkManager/conf.d/10-no-powersave.conf
```

PiMonitor additionally calls `xset s off`, `xset -dpms` and `xset s noblank`
inside its own X session on every start.

---

## Boot splash (`--splash`)

Instead of the rainbow square, kernel text and a login prompt, the screen
shows your image from early boot until the cameras appear.

```bash
sudo bash install.sh --splash /path/to/your-logo.png
```

Use a PNG at your screen resolution, for example 1920x1080. The image is
scaled to fit and centred on black, so an approximately 16:9 image looks best.

What this changes:

| Change | Effect |
|--------|--------|
| `disable_splash=1` in `config.txt` | no rainbow square |
| `console=tty1` becomes `console=tty3` | boot text goes to a hidden console |
| `quiet loglevel=0` | kernel messages silenced |
| `logo.nologo` | no raspberry logos |
| `vt.global_cursor_default=0` | no blinking cursor |
| `pimonitor-splash.service` | paints your image on the framebuffer |

Your original `cmdline.txt` and `config.txt` are saved next to the originals as
`*.pimonitor.bak`, and `uninstall.sh` puts them back.

### How the handoff works

The splash is drawn by `fbi` on tty1. PiMonitor starts X on the same VT, so the
splash has to let go first. `pimonitor.service` gets a drop-in:

```ini
[Service]
ExecStartPre=-/bin/systemctl stop pimonitor-splash.service
```

systemd runs drop-in `ExecStartPre` lines after the unit's own, so the splash
stays up through PiMonitor's startup delay and is stopped immediately before
`startx` claims the VT. Skipping this can leave X unable to acquire tty1.

### Custom splash by hand

```bash
sudo cp your-logo.png /opt/pimonitor/boot-splash.png
sudo systemctl restart pimonitor
```

---

## Boot sequence

With both options applied:

```
power on
   |
   +-- black, silent (firmware and kernel, a few seconds)
   |
   +-- your splash image
   |
   +-- camera wall
```

---

## Recovery layers

| Failure | Handled by | Recovery |
|---------|-----------|----------|
| One camera drops | PiMonitor watchdog | that tile reconnects, others untouched |
| Player or X crashes | `Restart=always` | whole wall restarts after 10s |
| Power cut | `systemctl enable pimonitor` | wall is back about a minute after power |
| Network not up yet | `NetworkManager-wait-online` | streams wait rather than fail |

Test it:

```bash
# kill one stream, it should come back within ~10 seconds
sudo pkill -f "pimonitor:CAM-01"

# kill the display, systemd should restart it
sudo pkill -9 Xorg

# the real test
sudo reboot
```

---

## Thermals

Software decoding several streams keeps a Pi 4 warm. A 6 stream wall runs
around 74C, and a Pi throttles at 80C.

```bash
vcgencmd measure_temp
vcgencmd get_throttled     # 0x0 is healthy
```

`0x80000` means it has hit the soft temperature limit. If you see that:

1. Switch every camera to its **sub stream** (the single biggest win)
2. Fit a heatsink or a fan, most bare Pi cases are not enough
3. Reduce the number of tiles, or rotate pages instead of showing all at once

---

## A dedicated machine

Use Raspberry Pi OS **Lite**. If you already imaged a desktop version, strip it:

```bash
sudo systemctl set-default multi-user.target
sudo systemctl disable --now lightdm
sudo apt-get purge -y chromium* firefox* libreoffice* vlc* cups* \
    lightdm labwc wayfire lxde* pcmanfm realvnc* bluez
sudo apt-get autoremove --purge -y
```

On one deployment this removed about 125 packages and 2.9 GB, and cut idle
memory from 598 MB to 219 MB.
