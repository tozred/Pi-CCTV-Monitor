# Example configurations

Copy the one closest to your setup over `/etc/pimonitor/pimonitor.conf`
and replace the camera URLs with your own.

| File | Layout | Good for |
|------|--------|----------|
| `4-cameras-2x2.conf` | 2x2 grid | the classic quad view |
| `6-cameras-3x2.conf` | 3x2 grid | 6 cameras filling a 16:9 screen |
| `7-cameras-rotating.conf` | 2x2, 2 pages | more cameras than fit at once |
| `focus-plus-thumbnails.conf` | 1 big + 6 small | one important view, others small |
| `single-camera.conf` | full screen | one camera, one screen |

Find your camera URLs first:

```bash
sudo pimonitor-discover --scan 192.168.1.0/24 -u admin -p PASSWORD --config
```
