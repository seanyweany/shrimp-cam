#!/usr/bin/env bash
#
# Keeps the desk camera online, forever. Raspberry Pi OS / Debian.
#
# Chromium is what actually holds the webcam and speaks WebRTC; this script
# only launches it in host mode and relaunches it whenever it dies.
#
#   ./shrimp-cam.sh                     # generates a key once, then reuses it
#   ./shrimp-cam.sh --key your-own-key
#   ./shrimp-cam.sh --size 1280x720 --fps 30 --camera Insta360
#
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

key=''
url='https://seanyweany.github.io/shrimp-cam/'
camera=''
profile_dir="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/shrimp-cam"
key_file="$here/key.txt"
# A Pi 3 has no WebRTC encoder in hardware, so Chromium encodes on four
# 1.2 GHz cores. 720p30 will not keep up; this is what actually holds.
size='640x480'
fps='15'

while [ $# -gt 0 ]; do
  case $1 in
    --key)         key=${2:?--key needs a value};         shift 2 ;;
    --url)         url=${2:?--url needs a value};         shift 2 ;;
    --camera)      camera=${2:?--camera needs a value};   shift 2 ;;
    --profile-dir) profile_dir=${2:?needs a value};       shift 2 ;;
    --key-file)    key_file=${2:?needs a value};          shift 2 ;;
    --size)        size=${2:?--size needs a value};       shift 2 ;;
    --fps)         fps=${2:?--fps needs a value};         shift 2 ;;
    -h|--help)     sed -n '3,10p' "$0" | cut -c3-; exit 0 ;;
    *)             echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# No key given? Keep one on disk, so the share link survives a restart.
if [ -z "$key" ]; then
  if [ ! -f "$key_file" ]; then
    (umask 077; od -An -tx1 -N16 /dev/urandom | tr -d ' \n' > "$key_file")
    echo "new key -> $key_file"
  fi
  key=$(tr -d '[:space:]' < "$key_file")
fi

# A key still carrying shell punctuation is an unexpanded command, not a secret.
if [[ $key == *'$'* || $key == *'('* || $key == *')'* || $key == *'['* || $key == *']'* ]]; then
  echo "--key is an unexpanded expression, not a key: $key" >&2
  echo "Drop --key and let this script generate one." >&2
  exit 1
fi
if [ ${#key} -lt 16 ]; then
  echo "--key is short enough to guess. Use 16+ characters, or drop it." >&2
  exit 1
fi

urlencode() {
  local s=$1 i c out=''
  for (( i = 0; i < ${#s}; i++ )); do
    c=${s:i:1}
    case $c in
      [A-Za-z0-9._~-]) out+=$c ;;
      *)               out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

chromium=${CHROMIUM:-}
if [ -z "$chromium" ]; then
  for c in chromium-browser chromium chromium-bin google-chrome-stable; do
    if command -v "$c" >/dev/null 2>&1; then chromium=$(command -v "$c"); break; fi
  done
fi
if [ -z "$chromium" ]; then
  echo "Chromium not found. sudo apt install -y chromium-browser" >&2
  exit 1
fi

# Chromium needs somewhere to draw, even though nobody watches this window.
launcher=()
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  if command -v xvfb-run >/dev/null 2>&1; then
    launcher=(xvfb-run -a)
    echo "no display -> running under xvfb"
  else
    echo "No graphical session. Run this from the Pi desktop, or:" >&2
    echo "  sudo apt install -y xvfb" >&2
    exit 1
  fi
fi

if ! compgen -G '/dev/video*' >/dev/null; then
  echo "warning: no /dev/video* found - is the camera plugged in?" >&2
fi
if ! id -nG | tr ' ' '\n' | grep -qx video; then
  me=$(id -un 2>/dev/null || echo "$LOGNAME")
  echo "warning: $me is not in the 'video' group" >&2
  echo "         sudo usermod -aG video $me   (then log out and back in)" >&2
fi

watch_link="$url#key=$(urlencode "$key")"
host_link="$watch_link&host=1&size=$size&fps=$fps"
if [ -n "$camera" ]; then
  host_link="$host_link&cam=$(urlencode "$camera")"
fi

echo "browser : $chromium"
echo "capture : $size @ ${fps}fps"
echo "share   : $watch_link"
echo

args=(
  --user-data-dir="$profile_dir"
  --use-fake-ui-for-media-stream          # grant the real camera, no prompt
  --autoplay-policy=no-user-gesture-required
  --disable-background-timer-throttling   # keep streaming when unfocused
  --disable-backgrounding-occluded-windows
  --disable-renderer-backgrounding
  --password-store=basic                  # never reach for gnome-keyring
  --no-first-run
  --no-default-browser-check
  --window-size=480,320
  --app="$host_link"
)

child=''
cleanup() {
  if [ -n "$child" ]; then kill "$child" 2>/dev/null || true; fi
  echo
  echo 'stopped'
  exit 0
}
trap cleanup INT TERM

while true; do
  printf '%s  live\n' "$(date +%H:%M:%S)"
  "${launcher[@]}" "$chromium" "${args[@]}" >/dev/null 2>&1 &
  child=$!
  wait "$child" || true
  child=''
  printf '%s  browser closed, restarting in 5s\n' "$(date +%H:%M:%S)"
  sleep 5
done
