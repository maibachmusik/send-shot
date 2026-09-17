#!/usr/bin/env bash
# Grab a screenshot on this machine and drop it on another box over ssh,
# leaving the remote path on your clipboard.
#
# The point: paste that path straight into a Claude Code prompt running on the
# remote machine and it attaches the image.
#
# Usage:
#   send-shot.sh            # select a region (default)
#   send-shot.sh region
#   send-shot.sh full       # whole screen
#
# Config, in order of precedence:
#   1. environment:  SHOT_REMOTE=user@host SHOT_DEST=/abs/path send-shot.sh
#   2. config file:  ~/.config/send-shot/config   (plain KEY=value lines)
#
# Minimum viable config is SHOT_REMOTE. SHOT_DEST defaults to "screenshots"
# in the remote user's home directory.
#
# Requires (local), by platform:
#   Wayland: grim, slurp, wl-clipboard, openssh
#   macOS:   screencapture, pbcopy (both stock), openssh
# X11 is still unsupported.
set -euo pipefail

CONFIG="${SHOT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/send-shot/config}"
# shellcheck source=/dev/null
[ -r "$CONFIG" ] && . "$CONFIG"

# REMOTE/DEST without the prefix are still honored so older configs keep working.
REMOTE="${SHOT_REMOTE:-${REMOTE:-}}"
DEST="${SHOT_DEST:-${DEST:-screenshots}}"

if [ -z "$REMOTE" ]; then
  cat >&2 <<MSG
send-shot: no remote configured.

Set one in $CONFIG:

    SHOT_REMOTE=user@host        # or an ssh_config alias
    SHOT_DEST=/home/user/screenshots

or pass it inline:  SHOT_REMOTE=user@host send-shot.sh
MSG
  exit 2
fi

# One platform check, used for deps, capture, clipboard and notification.
case "$(uname -s)" in
  Darwin) PLATFORM=macos ;;
  *)      PLATFORM=wayland ;;
esac

case "$PLATFORM" in
  macos)   deps="screencapture pbcopy scp ssh" ;;
  wayland) deps="grim slurp wl-copy scp ssh" ;;
esac
for dep in $deps; do
  command -v "$dep" >/dev/null || { echo "send-shot: missing dependency: $dep" >&2; exit 3; }
done

name="shot-$(date +%Y%m%d-%H%M%S).png"
tmp="$(mktemp -t "send-shot-XXXXXX.png")"
trap 'rm -f "$tmp"' EXIT

mode="${1:-region}"
case "$mode" in
  region|full) ;;
  *) echo "send-shot: unknown mode '$mode' (expected: region, full)" >&2; exit 2 ;;
esac

if [ "$PLATFORM" = macos ]; then
  # -x silences the shutter sound. A cancelled selection leaves $tmp empty (and
  # may or may not exit non-zero depending on the macOS build), so swallow the
  # status here and let the emptiness check below own that case.
  case "$mode" in
    full)   screencapture -x "$tmp" || true ;;
    region) screencapture -i -x "$tmp" || true ;;
  esac
else
  case "$mode" in
    full)   grim "$tmp" ;;
    region) grim -g "$(slurp)" "$tmp" ;;
  esac
fi

# slurp exits non-zero when you cancel a selection; set -e already stopped us.
[ -s "$tmp" ] || { echo "send-shot: empty capture" >&2; exit 1; }

# An absolute DEST is taken at face value (fast path: one scp, no extra ssh).
# Anything else is resolved remote-side, which also creates the directory.
case "$DEST" in
  /*) abs_dest="$DEST" ;;
  *)  abs_dest="$(ssh "$REMOTE" "mkdir -p -- \"$DEST\" && cd -- \"$DEST\" && pwd")" ;;
esac

scp -q "$tmp" "$REMOTE:$abs_dest/$name"
if [ "$PLATFORM" = macos ]; then
  printf '%s' "$abs_dest/$name" | pbcopy
  osascript -e "display notification \"$name\" with title \"Screenshot -> $REMOTE\"" \
    >/dev/null 2>&1 || true
else
  printf '%s' "$abs_dest/$name" | wl-copy
  notify-send "Screenshot -> $REMOTE" "$name" 2>/dev/null || true
fi
echo "$abs_dest/$name"
