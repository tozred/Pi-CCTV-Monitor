# Cameras and RTSP URLs

Finding the correct stream URL is the hardest part of building a camera wall.
This page is the reference, and `pimonitor-discover` automates most of it.

---

## Always use the sub stream

Nearly every IP camera publishes at least two streams:

| Stream | Typical | Use it for |
|--------|---------|------------|
| **Main** | 1080p to 4K, 15 to 25 fps | one camera filling the whole screen |
| **Sub** | 640x360 to 704x576 | **every multi camera layout** |

A tile in a 3x2 grid on a 1080p screen is about 640x360. Feeding it a 1080p
stream makes the Pi decode four times the pixels and then throw them away.

Real numbers from a 6 camera wall on a Pi 4:

| Streams | CPU (of 400%) | Temperature |
|---------|---------------|-------------|
| Mixed main and sub | 145% | 79C, thermally throttled |
| All sub streams | **73%** | **74C** |

Same picture on screen. Half the work.

---

## Let the tool find them

```bash
# scan a whole subnet
sudo pimonitor-discover --scan 192.168.1.0/24 -u admin -p PASSWORD --config

# or specific cameras
sudo pimonitor-discover 192.168.1.10 192.168.1.11 -u admin -p PASSWORD --config

# prefer the high resolution stream instead
sudo pimonitor-discover 192.168.1.10 -u admin -p PASSWORD --main
```

It queries **ONVIF** (`GetProfiles` then `GetStreamUri`), which is the camera
telling you its real URLs rather than you guessing. Each candidate is then
actually decoded to confirm it works, and the smallest H.264 profile wins.

Verify the ONVIF crypto on a new system:

```bash
pimonitor-discover --selftest
```

---

## URL patterns by vendor

`USER:PASS@IP` is omitted below for readability. The full form is:

```
rtsp://username:password@192.168.1.10:554/PATH
```

| Vendor | Main stream | Sub stream |
|--------|-------------|------------|
| **Hikvision** and clones | `/Streaming/Channels/101` | `/Streaming/Channels/102` |
| **ABUS** (TVT based) | `/Streaming/Channels/101` | `/Streaming/Channels/102` |
| **Dahua**, Amcrest | `/cam/realmonitor?channel=1&subtype=0` | `/cam/realmonitor?channel=1&subtype=1` |
| **Hanwha**, Samsung Wisenet | `/0/onvif/profile1/media.smp` | `/0/onvif/profile2/media.smp` |
| **Bosch** | `/rtsp_tunnel?h26x=4&line=1&inst=1` | `/rtsp_tunnel?h26x=4&line=1&inst=2` |
| **Reolink** | `/h264Preview_01_main` | `/h264Preview_01_sub` |
| **Axis** | `/axis-media/media.amp` | `/axis-media/media.amp?resolution=640x360` |
| **Generic ONVIF / OEM** | `/ONVIF/channel1` | `/ONVIF/channel2` |
| **HiSilicon OEM** | `/live/ch00_0` | `/live/ch01_0` |

Hanwha note: their `profile1` is often **MJPEG**, which is very heavy. Prefer
an H.264 profile. On the cameras we deployed, `profile10` was a 640x360 H.264
stream and the best choice for a tile.

---

## Reading the failures

The error tells you which problem you have:

| Symptom | Meaning | Fix |
|---------|---------|-----|
| `401 Unauthorized` | path is fine, credentials are wrong | fix user or password |
| `404 Stream Not Found` | credentials fine, **path** wrong | try another path from the table |
| connection hangs, no reply | wrong path on a camera that ignores bad requests | use ONVIF discovery |
| **every** path returns video | camera ignores the path entirely | see below |

### The camera that answers every path

Some cameras (several ABUS and generic OEM models) return the **main stream**
for any URL you ask for, including deliberate nonsense. Guessing paths on such
a camera always appears to succeed while always giving you 1080p.

`pimonitor-discover` detects this by probing a deliberately invalid path.

If it reports this, the camera's sub stream is switched **off inside the
camera**. Fix it in the camera's own web interface:

1. Open `http://CAMERA_IP` and sign in
2. Configuration, then Video/Audio
3. Set Stream Type to **Sub Stream** and enable it, around 640x360, H.264
4. If there is an ONVIF or "Integration Protocol" page, enable ONVIF too
5. Re-run `pimonitor-discover`

### ONVIF users are not always RTSP users

Some cameras keep a **separate account list** for ONVIF. An account that works
for ONVIF may return `401` on the actual RTSP stream, and the other way round.

If ONVIF discovery gives a URL that will not play, try the camera's normal
system account in the URL while keeping the ONVIF account for discovery.

---

## Credentials

Common defaults worth trying: `admin:admin`, `admin:` (empty), `admin:12345`,
`admin:123456`, `root:root`. Many installers also create a dedicated
`installer` or `service` account.

URL encode special characters in passwords:

| Character | Encoded |
|-----------|---------|
| `@` | `%40` |
| `#` | `%23` |
| `$` | `%24` |
| `/` | `%2F` |
| `:` | `%3A` |

Cameras often **lock out** an account after several rapid failed logins. If
everything starts returning `401` during testing, wait a minute before
continuing.

---

## Testing one URL by hand

```bash
# does it decode, and at what resolution
ffprobe -rtsp_transport tcp -i "rtsp://admin:pass@192.168.1.10:554/Streaming/Channels/102"

# watch it
mpv --rtsp-transport=tcp "rtsp://admin:pass@192.168.1.10:554/Streaming/Channels/102"
```

If this fails, the problem is the camera, the URL or the network, not PiMonitor.

---

## Security

`/etc/pimonitor/pimonitor.conf` contains camera passwords in plain text. The
installer sets it to mode `600`, owned by the display user. Keep it that way,
and keep cameras on a network segment that is not reachable from the internet.
