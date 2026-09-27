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
./install.sh --monitors       # just the monitor setup
SUSPEND_MINUTES=10 ./install.sh suspend   # suspend module without the question
```

After an interactive install, the installer offers a monitor setup (default
no). It shows a number in the top-left corner of every screen (a Quickshell
overlay, `monitors/identify.qml`, that never takes keyboard focus), then lets
you change each monitor's
resolution and refresh rate, scale, rotation, position (left/right/above/below
another screen), mirroring, and turn it on or off. Changes apply live and
must be confirmed within 15 seconds or they revert on their own, so a change
that leaves a screen unusable undoes itself; "Save
and exit" writes them to a managed block at the end of
`~/.config/hypr/monitors.lua`, matching monitors by model (so a monitor keeps
its settings whichever port it's on), and "Quit without saving" puts everything
back. The script is `monitors/monitor-setup`; `monitors.lua` itself stays out
of the repo since it's specific to each machine.

| Module | What it does |
|---|---|
| `looks` | Purple rotating border gradient on windows, popups and notifications, no gaps, sliding fade between workspaces |
| `keyboard` | Swap left Ctrl and left Super, macOS-like 3-finger workspace swipe |
| `keybindings` | SUPER+B browser, SUPER+A agent, CTRL+Q close window |
| `topbar` | Auto-hide the top bar until the cursor hits the top edge |
| `clock` | Clock in the middle of the top bar |
| `battery` | Battery percentage next to the battery icon (machines with a battery only) |
| `notifypanel` | Bell in the top bar that opens recent notifications, each dismissable, with Dismiss all |
| `notifytimeout` | Every notification leaves the screen after 5 seconds, critical ones too |
| `suspend` | No screensaver; suspend after a chosen idle time (1, 5, 10, 15, 30 or 60 min) |
| `agentchat` | Agent widget with your default agent's real terminal inside it, under compact usage limits |
| `branding` | Catboy braille art for fastfetch and the About screen |
| `fastfetch` | Purple fastfetch layout with a Mac-aware OS label |
| `background` | Drako desktop background |
| `bootscreen` | Purple catboy on the disk-unlock and login screens, kept across updates |
| `smidriver` | Silicon Motion SM77x USB display adapter driver (xxwitcher's fix + evdi-dkms and a crash fix) |
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
- Switching workspaces (swipe or keys) slides the new one in with a fade
  (`slidefade 20%`, 0.4 s, easeOutQuint); Omarchy switches instantly.

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
- 3-finger horizontal swipe switches workspaces, tuned to feel like macOS: a
  full swipe is 150px (default 300), it commits after 15% of that (default
  50%), a quick flick switches even when short, and one swipe can carry on
  past the next workspace or make a new one at the end.

### Keybindings (`home/.config/hypr/bindings.lua`)
- `SUPER + B` opens the browser (default `SUPER + SHIFT + B` is unbound).
- `SUPER + A` opens the agent (`omarchy-agent`); `SUPER + SHIFT + A` is unbound.
- `CTRL + Q` closes the active window.

### Auto-hiding top bar (`home/.config/topbar/autohide.sh`)
- Hides the Omarchy bar and shows it only while the cursor is at the very top
  of the screen (within 30px once it's open).
- Started at login from `home/.config/hypr/autostart.lua`.

### Bar layout (`clock`, `battery`)
- `~/.config/omarchy/shell.json` (the bar layout) stays out of the repo since
  it's specific to each machine; these modules edit it in place with `jq`, and
  the shell hot-reloads it.
- `clock` moves `omarchy.clock` to the front of the bar's center section,
  keeping its formats.
- `battery` sets `showPercentage` on the stock `omarchy.power` widget (the
  same setting right-clicking the battery icon toggles).

### Notifications panel (`home/.config/omarchy/plugins/witcher.notifications/`)
- A bell in the bar (filled while there's something to read) that opens every
  recent notification: the ones still on screen, plus the ones that already
  left it. Cards are Omarchy's own `NotificationCard`, so they look like the
  popups: hover one and click its ✕ to dismiss it, or use "Dismiss all".
  Clicking a card runs its action, like clicking the popup would.
- Omarchy only keeps the last 10 notifications, so `bin/notification-store`
  copies each one (and its images) into `~/.local/state/witcher/notifications/`
  as it lands in Omarchy's history, keeping the newest 100, and remembers
  dismissed ones so they don't come back.
- Placed before Bluetooth on the right of the bar.

### Notification timeout (`home/.config/omarchy/plugins/witcher.notify-timeout/`)
- Omarchy keeps normal notifications up for 8 s (longer if the app asks) and
  critical ones until they're clicked. This service takes every one off the
  screen 5 s after it appears, through the stock service's own expire path,
  so it still lands in history (and the notifications panel). Unlike the stock
  timer it doesn't pause while the pointer is over a toast.
- It sits next to `omarchy.notifications` rather than replacing it, so Do Not
  Disturb and everything else keep working.

### Suspend when idle (`home/.config/omarchy/plugins/witcher.idle-suspend/`)
- Turns Omarchy's screensaver off (`omarchy-toggle screensaver-off on`) and
  suspends after the chosen number of idle minutes, picked from a list when
  the module runs (`SUSPEND_MINUTES` skips the question; re-run
  `./install.sh suspend` to change it). The value is the `minutes` key on the
  plugin's entry in `shell.json`.
- Suspends like Omarchy's menu does (`systemctl suspend`), which locks the
  screen first. Idle inhibitors (a playing video) and Omarchy's "stay awake"
  toggle hold it off. The normal idle lock (5 min) still applies when it
  comes first.

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
- Installs the SM77x USB-to-HDMI adapter driver, vendored in
  `smidriver/driver/` from
  [xxwitcher/SiliconMotion-Driver-Fix](https://github.com/xxwitcher/SiliconMotion-Driver-Fix)
  (see `SOURCE.md` there): SiliconMotion's installer with its bundled EVDI
  build removed, since that fails on current kernels, so it uses the system
  `evdi-dkms` instead. Nothing is downloaded from that repo.
- First installs `dkms`, the headers for the running kernel (the package that
  owns `/usr/lib/modules/$(uname -r)` plus `-headers`, e.g.
  `linux-asahi-headers` on Omarchy-mac), and `evdi-dkms` from the AUR. Then it
  runs `smidriver/driver/install.sh` as root from that folder.
- Also installs a small fix: `SMIUSBDisplayManager` calls
  `evdi_open_attached_to(NULL)` to grab any free EVDI device, which crashes in
  upstream libevdi (it runs `strlen` on the argument; SiliconMotion's bundled
  EVDI, skipped above, tolerated it). `smidriver/evdi-nullfix.c` is built into
  `/usr/local/lib/libevdi-nullfix.so` and preloaded by the drop-in
  `/etc/systemd/system/smiusbdisplay.service.d/nullfix.conf`, routing the call
  to the NULL-safe `evdi_open_attached_to_fixed`. Nothing in the driver or
  `evdi-dkms` is modified, and the drop-in survives driver reinstalls.
- If the adapter is plugged in during the install, the driver service is
  started right away, so its monitors come up without a reboot or replug.
- If a package step fails (usually a stale package database), it says to run
  `omarchy update` and re-run `./install.sh smidriver`, and the rest of the
  install carries on.
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
