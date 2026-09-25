# dotfiles

Personal overrides for Omarchy's Lua-based Hyprland config. Only the user
override files are tracked; Omarchy's defaults still load first and these are
applied on top.

The older `.conf`-based setup (waybar, Asahi system tweaks, etc.) lives on the
`legacy` branch.

## Install

```bash
git clone https://github.com/xxwitcher/.dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` symlinks every file under `home/` into `$HOME`, moving any
existing file aside to `<file>.bak.<timestamp>` first, then reloads Hyprland
and fails loudly if `hyprctl configerrors` reports anything. It is safe to
re-run. Because the configs are symlinks, edits made on the machine land
directly in this repo, so just commit them.

Files under `system/` are copied (as root, via `sudo`) to the same path under
`/` instead of symlinked. Each `system/etc/<app>/` folder is only installed if
`<app>` is on the machine (a `<app>` command or `/usr/share/<app>` exists), so
the same repo works on regular Omarchy and Omarchy-mac. If the app has a
systemd service, it is restarted after its files change. Unchanged files are
skipped, so re-runs don't ask for a password. Without a terminal, run
`SUDO=pkexec ./install.sh`.

Note: `omarchy refresh hyprland` replaces these files with Omarchy's defaults.
Re-run `install.sh` afterwards.

## What's in it

### Look & feel (`home/.config/hypr/looknfeel.lua`)
- No gaps between windows.
- Active border is a light purple → purple → orchid gradient; inactive border
  is a muted purple. Colors are evenly spaced, so a color is repeated to give
  it more of the border.
- The gradient rotates continuously around the active window (one turn every
  ~13 s). Hyprland's built-in `borderangle` `loop` animation stops after one
  turn on 0.56, so a repeating `hl.timer` updates the angle instead. Tune
  `border_spin_seconds` / `border_spin_interval`, or remove the timer block to
  keep a static gradient.
- Scrolling layout column width 0.97.

### Keyboard (`home/.config/hypr/input.lua`)
- Left Ctrl and Left Super are swapped (`ctrl:swap_lwin_lctl`). Right Super
  and Right Ctrl are unchanged. Omarchy's default `compose:caps` and
  `shift:both_capslock_cancel` are kept, since setting `kb_options` replaces
  them.
- 3-finger horizontal swipe switches workspaces.

### Keybindings (`home/.config/hypr/bindings.lua`)
- `SUPER + B` opens the browser (default `SUPER + SHIFT + B` is unbound).
- `SUPER + A` opens the agent (`omarchy-agent`); `SUPER + SHIFT + A` is unbound.
- `CTRL + Q` closes the active window.

### Auto-hiding top bar (`home/.config/topbar/autohide.sh`)
- Hides the Omarchy bar and shows it only while the cursor is at the very top
  of the screen (within 30px once it's open).
- Started at login from `home/.config/hypr/autostart.lua`.

### Branding (`home/.config/omarchy/branding/about.txt`)
- Braille art of a catboy (line art, with the top, shorts, socks and tail
  filled) shown by fastfetch and Omarchy's About screen

### Fastfetch (`home/.config/fastfetch/config.jsonc`)
- Omarchy's stock fastfetch layout with purple (`#8511f2`) logo and key
  colors instead of green.
- The OS line reads "Omarchy Mac" on Apple Silicon (detected from
  `/proc/device-tree/compatible`) and "Omarchy" everywhere else.

### Background (`backgrounds/drako.png`)
- `install.sh` sets it with `omarchy theme bg set`, pointing Omarchy's
  current-background link at the file in this repo. Switching themes picks
  that theme's own background, so re-run `install.sh` (or
  `omarchy theme bg set ~/.dotfiles/backgrounds/drako.png`) to get it back.

### Touch Bar, Omarchy-mac only (`system/etc/tiny-dfr/`)
- tiny-dfr config with the media layer shown by default and a screenshot
  (`Print`) key first, using the custom `screenshot.png` icon.
- Lives in `/etc/tiny-dfr/`, which tiny-dfr merges over the packaged
  `/usr/share/tiny-dfr/config.toml` and checks for icons, so package updates
  don't overwrite it.
