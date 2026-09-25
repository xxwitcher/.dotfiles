# dotfiles (quattro)

Personal overrides for Omarchy's Lua-based Hyprland config. Only the user
override files are tracked; Omarchy's defaults still load first and these are
applied on top.

The older `.conf`-based setup (waybar, Asahi system tweaks, etc.) lives on the
`main` branch.

## Install

```bash
git clone -b quattro https://github.com/xxwitcher/.dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` symlinks every file under `home/` into `$HOME`, moving any
existing file aside to `<file>.bak.<timestamp>` first, then reloads Hyprland
and fails loudly if `hyprctl configerrors` reports anything. It is safe to
re-run. Because the configs are symlinks, edits made on the machine land
directly in this repo, so just commit them.

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
