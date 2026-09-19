# send-shot

> **Fork.** This is `maibachmusik/send-shot`, forked from
> [`ConsultingFuture4200/send-shot`](https://github.com/ConsultingFuture4200/send-shot).
> What this fork adds: **macOS support** — stock `screencapture` + `pbcopy`
> alongside the upstream Wayland `grim`/`slurp`/`wl-copy` path. Upstream is
> Wayland-only, so clone *this* repo if either end is a Mac.

Take a screenshot on one Wayland machine, land it on another over ssh, and get
the remote path on your clipboard.

The use case it was built for: you're working on a laptop, but Claude Code is
running on a desktop across the room. Hit a key, drag a box around the thing you
want to show it, then paste the path into the prompt — Claude Code reads the
image off its own local disk.

    SUPER+SHIFT+P  ->  drag a region  ->  clipboard now holds
                                          /home/you/screenshots/shot-20260915-142233.png

## Requirements

Local machine (the one you screenshot on) is either **Wayland** or **macOS**.

Wayland:

    grim  slurp  wl-clipboard  openssh

On Arch: `sudo pacman -S grim slurp wl-clipboard openssh`

macOS: nothing to install — it uses stock `screencapture` and `pbcopy`. The
first run prompts for **Screen Recording** permission for whatever launched it
(your terminal, or your hotkey daemon); until that is granted, capture fails
with `could not create image from display`. That also means it cannot be driven
over ssh — a remote shell has no window server session to capture.

You also need key-based ssh to the remote box, so the script never blocks on a
password prompt. If `ssh your-remote` logs you in without typing anything,
you're set.

## Install

    git clone https://github.com/maibachmusik/send-shot.git
    cd send-shot
    ./install.sh

That copies `send-shot.sh` to `~/.local/bin/` and writes a starter config to
`~/.config/send-shot/config` if you don't have one yet.

## Configure

Edit `~/.config/send-shot/config`:

    SHOT_REMOTE=desktop            # ssh alias, or user@host, or user@192.168.1.10
    SHOT_DEST=/home/you/screenshots

`SHOT_REMOTE` is required. `SHOT_DEST` is optional and defaults to a
`screenshots` directory in the remote user's home, created on first use.

Giving `SHOT_DEST` as an **absolute path** is slightly faster — the script can
skip the round-trip it otherwise makes to expand the path and create the
directory.

Anything in the config can be overridden per-invocation:

    SHOT_REMOTE=otherbox send-shot.sh full

## Usage

    send-shot.sh           # select a region (default)
    send-shot.sh region    # same thing
    send-shot.sh full      # entire screen

On success it copies the remote path to your clipboard, fires a desktop
notification, and prints the path to stdout.

## Bind it to a key

### Hyprland (vanilla)

In `~/.config/hypr/hyprland.conf`:

    bind = SUPER SHIFT, P, exec, ~/.local/bin/send-shot.sh region

Then `hyprctl reload`.

### Omarchy

Omarchy configures Hyprland in Lua, not `.conf`. Put this in
`~/.config/hypr/bindings.lua` — note the absolute path, and that SUPER+SHIFT+P
ships bound to the Google Photos webapp, so it has to be unbound first:

    hl.unbind("SUPER + SHIFT + P")
    o.bind("SUPER + SHIFT + P", "Send screenshot", "/home/YOU/.local/bin/send-shot.sh region")

Then `hyprctl reload && hyprctl configerrors`.

### Sway

    bindsym $mod+Shift+p exec ~/.local/bin/send-shot.sh region

### macOS

There is no stock way to bind a shell command to a key, so use a hotkey daemon
(`brew install koekeishiya/formulae/skhd`, then in `~/.skhdrc`):

    cmd + ctrl - p : /Users/YOU/.local/bin/send-shot.sh region

or wrap it in a Shortcuts.app "Run Shell Script" action and assign the key
there. Either way, grant that app Screen Recording once.

## Exit codes

| Code | Meaning |
|-----:|---------|
| 0 | Sent |
| 1 | Capture was empty |
| 2 | Bad usage, or no remote configured |
| 3 | Missing a local dependency |

A cancelled region selection exits non-zero via `slurp` and sends nothing.

## Notes

- X11 isn't supported — `grim`/`slurp` are Wayland-only. The X11 equivalents
  would be `maim`/`slop` and `xclip`.
- On macOS a cancelled region selection leaves an empty file rather than a
  non-zero exit, so it comes back as exit 1 (empty capture) instead of slurp's
  cancel status.
- The local temp file is removed on exit, including on failure.
- Nothing is cleaned up on the remote side; the screenshots directory grows
  until you prune it.
