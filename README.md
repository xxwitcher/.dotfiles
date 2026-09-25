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

`install.sh` shows a checklist of modules (all preselected; space toggles,
enter applies) and applies only the ones you keep. Modules that don't apply to
the machine, like `touchbar` without tiny-dfr, aren't offered. It uses `gum`,
which ships with Omarchy, and falls back to y/n prompts without it.

```bash
./install.sh                  # pick from the checklist
./install.sh --all            # everything available, no questions
./install.sh looks topbar     # just these modules
./install.sh --list           # show the modules
```

| Module | What it does |
|---|---|
| `looks` | Purple rotating border gradient on windows, popups and notifications, no gaps |
| `keyboard` | Swap left Ctrl and left Super, touchpad workspace swipe |
| `keybindings` | SUPER+B browser, SUPER+A agent, CTRL+Q close window |
| `topbar` | Auto-hide the top bar until the cursor hits the top edge |
| `agentchat` | Agent widget with your default agent's real terminal inside it, under compact usage limits |
| `branding` | Catboy braille art for fastfetch and the About screen |
| `fastfetch` | Purple fastfetch layout with a Mac-aware OS label |
| `background` | Drako desktop background |
| `bootscreen` | Purple catboy on the disk-unlock and login screens, kept across updates |
| `smidriver` | Silicon Motion SM77x USB display driver with the system evdi-dkms (needs a reboot) |
| `touchbar` | Touch Bar layout and screenshot key (Omarchy-mac only) |

Files under `home/` are symlinked into `$HOME`, moving any existing file aside
to `<file>.bak.<timestamp>` first. Because they're symlinks, edits made on the
machine land directly in this repo, so just commit them. Files under `system/`
are copied as root (via `sudo`, one password prompt per app) instead, and the
app's service is restarted if its files changed. Without a terminal, run
`SUDO=pkexec ./install.sh --all`. When Hyprland files change, Hyprland is
reloaded and the script fails loudly if `hyprctl configerrors` reports
anything.

Re-running is safe: anything already in place is left alone. Deselecting a
module doesn't remove it if it was installed before.

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

### Shell borders (`home/.config/omarchy/themed/shell.hyprland.toml.tpl`)
- Gives bar popups (battery, network, etc.), notifications, the lock screen and
  password prompts the same purple gradient as the window border, for every
  theme. Omarchy merges this template over the `[hyprland]` section of each
  theme's generated `shell.toml`. The gradient is static there; only window
  borders rotate.
- Part of the `looks` module, which runs `omarchy theme refresh` (keeps the
  background) when the generated theme doesn't have it yet. Keep its colors in
  sync with `border_colors` in `looknfeel.lua`.

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

### Agent terminal widget (`home/.config/omarchy/plugins/witcher.agents/`)
- A clone of Omarchy's `omarchy.agents` bar widget: a compact header (agent,
  plan, session and weekly limits side by side) over a real terminal running
  the default agent the same way the agent console does
  (`omarchy-agent --inline`), so every agent and every command works.
- The `agentchat` module installs `qmltermwidget` if needed, links the plugin,
  links a theme-generated terminal color scheme into
  `/usr/lib/qt6/qml/QMLTermWidget/color-schemes/` (one sudo prompt), and
  points the bar's agents slot at `witcher.agents`. When any of that changes,
  the installer restarts the Omarchy shell so the bar picks it up.
- `Main.qml` / `Agent.qml` are copies of the stock files, so Omarchy updates to
  the stock usage code don't reach it. See the plugin's README for details.

### Branding (`home/.config/omarchy/branding/about.txt`)
- Braille art of a catboy (line art, with the top, shorts, socks and tail
  filled) with "Witcher" written at 45° along the thigh, shown by fastfetch
  and Omarchy's About screen

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

### Boot screen (`bootscreen/`)
- The catboy art (with "Witcher") as purple dots on the Plymouth disk-unlock
  screen and the SDDM login screen, with a Catppuccin background (`#1e1e2e`),
  a light purple (`#c4b5fd`) password box and lock icon, and the logo and
  password box vertically centered as one group (stock centers the logo alone).
- `dotfiles-bootscreen` (installed to `/usr/local/bin`) rebuilds Omarchy's
  theme from its stock files with those changes, then rebuilds the initramfs.
  It mirrors `omarchy plymouth set`, which can't run as root.
- Those theme files belong to the `omarchy-settings` package, so
  `95-dotfiles-bootscreen.hook` (installed to `/etc/pacman.d/hooks`) re-runs
  the script after any update that rewrites them. The logo is installed to
  `/usr/local/share/dotfiles-bootscreen/`.
- To undo: remove those three files and run `omarchy refresh plymouth`.

### Silicon Motion USB display driver (`smidriver` module)
- Installs the SM77x USB-to-HDMI adapter driver from
  [xxwitcher/SiliconMotion-Driver-Fix](https://github.com/xxwitcher/SiliconMotion-Driver-Fix):
  SiliconMotion's installer with its bundled EVDI build removed, since that
  fails on current kernels, so it uses the system `evdi-dkms` instead.
- First installs `dkms`, the headers for the running kernel (the package that
  owns `/usr/lib/modules/$(uname -r)` plus `-headers`, e.g.
  `linux-asahi-headers` on Omarchy-mac), and `evdi-dkms` from the AUR. Then it
  clones the repo to `~/.local/share/dotfiles/SiliconMotion-Driver-Fix` and
  runs its `install.sh` as root from that folder.
- Skipped when `/opt/siliconmotion` is already installed. To reinstall:
  `sudo smi-installer uninstall`, reboot, re-run the module.
- Reboot afterwards. The catch-all monitor rule turns the external screen on,
  but at the laptop's scale 2; add a rule for it in `hypr/monitors.lua`
  (name from `hyprctl monitors all`), e.g.
  `hl.monitor({ output = "DVI-I-1", mode = "1920x1080@60", position = "auto", scale = 1 })`.

### Touch Bar, Omarchy-mac only (`system/etc/tiny-dfr/`)
- tiny-dfr config with the media layer shown by default and a screenshot
  (`Print`) key first, using the custom `screenshot.png` icon.
- Lives in `/etc/tiny-dfr/`, which tiny-dfr merges over the packaged
  `/usr/share/tiny-dfr/config.toml` and checks for icons, so package updates
  don't overwrite it.
