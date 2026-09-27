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
./install.sh --add            # pick from the modules not installed yet
./install.sh --remove         # pick installed modules to take back out (asks to confirm)
./install.sh --remove clock   # take this one out, no questions
./install.sh --configure      # change settings: monitors, border colors, suspend time, notification timeout
./install.sh --status         # which modules are installed
./install.sh --list           # show the modules
./install.sh --monitors       # just the monitor setup
./install.sh --remove-menu    # take Witcher's Tweaks out of the Omarchy menu
SUSPEND_MINUTES=10 ./install.sh suspend   # suspend module without the question
NOTIFY_SECONDS=8 ./install.sh --configure notifytimeout
```

### Witcher's Tweaks menu

Every run adds **Setup > Witcher's Tweaks** to the Omarchy menu (also reachable
as `omarchy menu summon witcher`), with **Add**, **Remove** and **Configure**,
each opening `install.sh --add`, `--remove` or `--configure` in a floating
terminal. The entries sit between two marker comments in
`~/.config/omarchy/extensions/omarchy-menu.jsonc`; the rest of that file is
left alone, and `--remove-menu` takes the block out. **Configure** offers the
monitor setup (always), the border colors (with `looks`), the suspend time
(with `suspend`) and how long notifications stay up (with `notifytimeout`).
Settings baked into the repo's own files, like the swipe tuning, aren't in
it: changing them means editing the repo. The menu always lists
Omarchy's own rows before added ones, so to put Witcher's Tweaks right under
Config the block also hides the Setup rows Omarchy has after Config (Direct
Boot, Reset Computer) and re-adds copies of them below it. The copies are
rebuilt from Omarchy's menu on every run, and `--remove-menu` puts the
originals back.

### Removing

`--remove` undoes a module's steps in reverse:

- A linked file goes back to what it replaced: its newest `.bak.<timestamp>`
  backup, else Omarchy's default copy (the Hyprland overrides), else nothing.
  A file that isn't linked to the repo any more is left alone.
- Settings written to `~/.config/omarchy/shell.json` are taken back out (the
  clock returns to the right of the bar, the bell and battery percentage go,
  plugin entries are dropped), and plugin folders are deleted once empty.
- `topbar` stops the auto-hide loop and shows the bar; `suspend` turns the
  screensaver back on; `looks` rebuilds the theme without the purple shell
  borders; `background` switches to the theme's own background;
  `notifypanel` also deletes its saved notifications.
- `bootscreen` removes the pacman hook and script, then runs
  `omarchy plymouth reset` (stock boot and login screens, initramfs rebuilt).
  `smidriver` runs SiliconMotion's uninstaller and removes the null-fix shim;
  `touchbar` puts back the original `/etc/tiny-dfr` files (or deletes the
  copies). These ask for your password. Packages the modules pulled in
  (qmltermwidget, dkms, evdi-dkms, kernel headers) stay installed.
- `overview`'s swipe gestures live in `keyboard`'s `input.lua`; without the
  overview they do nothing, and removing `keyboard` takes them out too.

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
| `looks` | Rotating gradient border (purple, or colors you pick) on windows, popups and notifications, no gaps, sliding fade between workspaces |
| `keyboard` | Swap left Ctrl and left Super, macOS-like 3-finger swipes (workspaces, overview) |
| `keybindings` | SUPER+B browser, SUPER+A agent, CTRL+Q close window |
| `topbar` | Auto-hide the top bar until the cursor hits the top edge |
| `clock` | Clock in the middle of the top bar |
| `battery` | Battery percentage next to the battery icon (machines with a battery only) |
| `notifypanel` | Bell in the top bar that opens recent notifications, each dismissable, with Dismiss all |
| `notifytimeout` | Every notification leaves the screen after a few seconds (5 by default; 3, 8, 10 or 15 via Configure), critical ones too |
| `overview` | Swipe up with 3 fingers for a Mission Control-style overview: workspaces along the top, the hovered one's windows below; click to go there (the gesture is in `keyboard`) |
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
module doesn't remove it if it was installed before; `--remove` does.

Note: `omarchy refresh hyprland` replaces these files with Omarchy's defaults.
Re-run `install.sh` afterwards.

## What's in it

### Look & feel (`home/.config/hypr/looknfeel.lua`)
- No gaps between windows.
- Active border is a three-color gradient, light purple → purple → orchid
  unless you pick your own (see Border colors below); inactive border is a
  muted purple. Colors are evenly spaced, so each is repeated (3/3/2) to give
  it more of the border.
- The gradient rotates continuously around the active window (one turn every
  ~13 s). Hyprland's built-in `borderangle` `loop` animation stops after one
  turn on 0.56, so a repeating `hl.timer` updates the angle instead. The one
  timer calls a tick function that every reload redefines, so edits apply
  without restarting Hyprland. Tune `border_spin_seconds` /
  `border_spin_interval`, or remove the timer block to keep a static gradient.
- Scrolling layout column width 0.97.
- Switching workspaces (swipe or keys) slides the new one in with a fade
  (`slidefade 20%`, 0.4 s, easeOutQuint); Omarchy switches instantly.

### Border colors (`home/.config/omarchy/plugins/witcher.border-colors/`)
- Setup > Witcher's Tweaks > Configure > Borders opens a color picker for the
  gradient's three colors (light, main, accent) and the inactive border: a
  saturation/brightness square and hue strip, a hex field, an eyedropper
  (`hyprpicker`) and presets. Every change previews live on the real windows;
  Save (Enter) keeps it, Cancel (Esc) goes back.
- The colors are per machine, in `~/.config/witcher-tweaks/border.conf`
  (`active=<3 hex>`, `inactive=<hex>`), so the repo keeps its defaults.
  `looknfeel.lua` reads them; `bin/border-colors` (the picker's backend, also
  usable directly: `get`, `set`, `reset`, `preview`, `revert`) writes
  `~/.config/omarchy/themed/shell.hyprland.toml.tpl` from them, which Omarchy
  merges over every theme's shell colors, so bar popups, notifications, the
  lock screen and password prompts get the same gradient (static there; only
  window borders rotate), and runs `omarchy theme refresh` when it changes.
- Removing `looks` takes the template and saved colors out, rebuilds the
  theme, stops the spinning border and restores `looknfeel.lua`.

### Keyboard (`home/.config/hypr/input.lua`)
- Left Ctrl and Left Super are swapped (`ctrl:swap_lwin_lctl`). Right Super
  and Right Ctrl are unchanged. Omarchy's default `compose:caps` and
  `shift:both_capslock_cancel` are kept, since setting `kb_options` replaces
  them.
- 3-finger horizontal swipe switches workspaces, tuned to feel like macOS: a
  full swipe is 150px (default 300), it commits after 15% of that (default
  50%), a quick flick switches even when short, and one swipe can carry on
  past the next workspace or make a new one at the end.
- 3-finger swipe up opens the window overview (the `overview` module), swipe
  down closes it. Without that module the swipe does nothing.

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
  screen 5 s after it appears (change it with `--configure notifytimeout`),
  through the stock service's own expire path,
  so it still lands in history (and the notifications panel). Unlike the stock
  timer it doesn't pause while the pointer is over a toast.
- It sits next to `omarchy.notifications` rather than replacing it, so Do Not
  Disturb and everything else keep working.

### Window overview (`home/.config/omarchy/plugins/witcher.overview/`)
- Like macOS Mission Control. Along the top, every workspace as a miniature
  of the screen with its windows where they sit (live previews, including
  hidden workspaces); the strip scrolls sideways when there are more than
  fit (touchpad, or the mouse wheel). The workspace you're on has a dot.
- Below it, the windows of the workspace you last hovered in the strip (the
  current one to start with), laid out as big as they fit. The pick stays
  when the pointer moves down, so you can reach them.
- Click a workspace to go to it, or a window to go to that window.
  `bin/focus-window` then moves the cursor onto the focused window so
  Omarchy's focus-follows-mouse doesn't hand focus to whatever was under it.
- Keys: Left/Right pick a workspace, Tab/Shift+Tab a window, Enter goes to
  it (or to the workspace when it's empty), Esc closes; so does a click on
  the backdrop.
- Opened by the 3-finger swipe up (in `hypr/input.lua`), or
  `omarchy-shell shell summon witcher.overview '{}'` from a keybinding.
  Scratchpad windows stay out.

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
