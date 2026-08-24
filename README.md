# shrimp cam

A webcam on a Windows desk, watchable from a GitHub Page. The video never
touches a server: two browsers find each other through a public signalling
broker and then stream directly to one another over WebRTC.

    index.html      the whole site - viewer and camera in one file
    shrimp-cam.ps1  keeps the camera online on the Windows box
    key.txt         generated on first run, gitignored, never commit it

Nothing to build, nothing to install, no packages. The page pulls one script
(PeerJS, pinned and SRI-checked) from a CDN.

## The key

The camera registers itself under `SHA-256(key)`, so the key *is* the address.
Without it you cannot find the camera, and you cannot register in its place.
The key rides in the URL fragment, which browsers never put on the wire, and
the video itself is encrypted end to end (DTLS-SRTP).

The script generates one on first run (128 bits, from the OS random source),
writes it to `key.txt` next to the script and reuses it forever, so the link
you share keeps working across restarts. Delete `key.txt` to roll the key -
every old link dies with it.

Pass `-Key` only if you want to choose it yourself. It must be 16+ characters,
and the script refuses anything still carrying shell punctuation, because
`cmd.exe` does not expand PowerShell expressions and will happily hand over
`$([guid]::NewGuid())` as a literal "secret".

## Publish the page

Settings → Pages → deploy from a branch, root folder. Whatever branch you pick
there is the one the new page has to land on. That is the whole deploy.

## Run the camera

```powershell
.\shrimp-cam.ps1
```

It prints the link to share, opens a small window that holds the camera, and
relaunches the browser forever if it ever dies. Ctrl+C stops it.

| flag | |
|---|---|
| `-Key` | choose the key yourself instead of using `key.txt` |
| `-Url` | your Pages URL (default `https://seanyweany.github.io/shrimp-cam/`) |
| `-Camera` | part of a camera's name, e.g. `-Camera Insta360`, when the default device is the wrong one |
| `-ProfileDir` | where the throwaway browser profile lives |
| `-KeyFile` | where the key is kept |

To bring it up at logon, point Task Scheduler ("At log on") at:

```
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\path\to\shrimp-cam.ps1
```

## Watch

Open the link the script printed, or open the page bare and paste the key in.
Click the video for fullscreen. Six viewers at a time (`MAX_VIEWERS`).

## Notes

- Chrome shows a yellow "unsupported command-line flag" bar on the camera
  window. That is `--use-fake-ui-for-media-stream`, which is what grants the
  webcam without a prompt. It is cosmetic - dismiss it, or minimise the window.
- Signalling is the free PeerJS broker. It sees a hashed id and relays the
  connection setup; the video does not go through it.
- A public TURN relay is listed in `ICE` as a fallback for networks that block
  direct peer connections. Swap in your own if you would rather not lean on it -
  a relay only forwards the encrypted stream, it cannot read it.
