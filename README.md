# shrimp cam

A webcam on a desk, watchable from a GitHub Page. The video never touches a
server: two browsers find each other through a public signalling broker and
then stream directly to one another over WebRTC.

    index.html      the whole site - viewer and camera in one file
    shrimp-cam.ps1  keeps the camera online on Windows
    shrimp-cam.sh   keeps the camera online on Raspberry Pi OS / Debian
    key.txt         generated on first run, gitignored, never commit it

Nothing to build, nothing to install, no packages. The page pulls one script
(PeerJS, pinned and SRI-checked) from a CDN.

## The key

The camera registers itself under `SHA-256(key)`, so the key *is* the address.
Without it you cannot find the camera, and you cannot register in its place.
The key rides in the URL fragment, which browsers never put on the wire, and
the video itself is encrypted end to end (DTLS-SRTP).

Both scripts generate one on first run (128 bits, from the OS random source),
write it to `key.txt` next to the script and reuse it forever, so the link you
share keeps working across restarts. Delete `key.txt` to roll the key - every
old link dies with it.

Pass a key explicitly only if you want to choose it. It must be 16+ characters,
and both scripts refuse anything still carrying shell punctuation, because
`cmd.exe` does not expand PowerShell expressions and will happily hand over
`$([guid]::NewGuid())` as a literal "secret".

## Publish the page

Settings → Pages → deploy from a branch, root folder. Whatever branch you pick
there is the one the page has to land on. That is the whole deploy.

## Run the camera - Windows

```powershell
.\shrimp-cam.ps1
```

## Run the camera - Raspberry Pi OS / Debian

```bash
sudo apt install -y chromium-browser
./shrimp-cam.sh
```

Both print the link to share, open a small window that holds the camera, and
relaunch the browser forever if it ever dies. Ctrl+C stops them.

| flag | |
|---|---|
| `--key` / `-Key` | choose the key yourself instead of using `key.txt` |
| `--url` / `-Url` | your Pages URL |
| `--camera` / `-Camera` | part of a camera's name, e.g. `Insta360`, when the default device is wrong |
| `--size`, `--fps` | capture resolution and frame rate (Pi script only; the page defaults to 1280x720 at 30) |
| `--profile-dir` / `-ProfileDir` | where the throwaway browser profile lives |
| `--key-file` / `-KeyFile` | where the key is kept |

### Pi 3 is the bottleneck, not the camera

A Pi 3 has no WebRTC encoder Chromium can reach, so every frame is encoded on
four 1.2 GHz cores. 720p30 will not keep up. `shrimp-cam.sh` therefore defaults
to **640x480 at 15fps**, which is what the hardware actually sustains. Raise it
with `--size 1280x720 --fps 30` if you want to see where it falls over.

A Pi 4 or Pi 5 does considerably better; the script is unchanged on those.

### Starting it at boot

The script needs a graphical session to draw into. On Pi OS with Desktop and
autologin, drop this in `~/.config/autostart/shrimp-cam.desktop`:

```
[Desktop Entry]
Type=Application
Name=shrimp cam
Exec=/home/pi/shrimp-cam/shrimp-cam.sh
```

On Pi OS Lite there is no X server. Install `xvfb` and the script will detect
the missing display and run Chromium under it automatically.

On Windows, point Task Scheduler ("At log on") at:

```
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\path\to\shrimp-cam.ps1
```

## Watch

Open the link the script printed, or open the page bare and paste the key in.
Click the video for fullscreen. Six viewers at a time (`MAX_VIEWERS`).

## Insta360 Link on Linux

**No driver needed.** The Link is a standard UVC device, handled by the
in-kernel `uvcvideo` driver. Insta360's own compatibility page says a Linux
device works "if your Linux device supports UVC/UAC protocol". It shows up as
`/dev/video0` and Chromium sees it like any other webcam, which is all this
project needs.

**The Link Controller app is Windows/macOS only.** Gimbal aim, AI subject
tracking and gesture control are configured through that app, so on Linux you
get a fixed camera pointing wherever it was last aimed. Standard V4L2 controls
(brightness, contrast, zoom, pan/tilt where exposed) still work via `v4l2-ctl`.
Community projects drive the proprietary features over UVC extension units if
you want tracking back - see [caioquirino/insta360_linux](https://github.com/caioquirino/insta360_linux),
[vrwallace/Insta360-Link-1-and-2-Controller-for-Linux](https://github.com/vrwallace/Insta360-Link-1-and-2-Controller-for-Linux)
and [jfwoods/insta360link-controller](https://github.com/jfwoods/insta360link-controller).
None are affiliated with Insta360.

**Stop it disconnecting in a loop.** The Link (gen 1, USB `2e1a:4c01`) does not
handle USB autosuspend, and power-cycles until the LED blinks between blue and
off. The kernel has a `UVC_QUIRK_DISABLE_AUTOSUSPEND` entry for it, but if your
kernel predates that, pin it yourself:

```
# /etc/udev/rules.d/99-insta360-link.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="2e1a", ATTR{idProduct}=="4c01", TEST=="power/control", ATTR{power/control}="on"
```

**Feed it enough power.** Insta360 specs the Link at 5V 1A, and it has a motor.
A Pi 3's USB ports share one budget with everything else on the board, so use a
powered USB hub, or expect brownouts and dropouts. The Pi 3 is also USB 2.0
only, which caps what the camera can deliver - not a problem at the resolutions
a Pi 3 can encode anyway.

## Notes

- Chrome shows a yellow "unsupported command-line flag" bar on the camera
  window. That is `--use-fake-ui-for-media-stream`, which is what grants the
  webcam without a prompt. It is cosmetic - dismiss it, or minimise the window.
- Signalling is the free PeerJS broker. It sees a hashed id and relays the
  connection setup; the video does not go through it.
- A public TURN relay is listed in `ICE` as a fallback for networks that block
  direct peer connections. Swap in your own if you would rather not lean on it -
  a relay only forwards the encrypted stream, it cannot read it.
