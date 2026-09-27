# dotfiles

My personal Omarchy touches: catboy art, a purple fastfetch, the Drako
background and a catboy boot screen.

The general tweaks that used to live here (window overview, notification bell
and timeout, gradient border with a color picker, macOS-like swipes,
keybindings, bar tweaks, suspend on idle, the agent terminal widget, the
monitor setup, the SMI display driver and Touch Bar setups) are now their own
tool, **[Witcher's Tweaks](https://github.com/xxwitcher/witchers-tweaks)**,
where each one can be added, configured and removed on its own:

```bash
git clone https://github.com/xxwitcher/witchers-tweaks.git ~/witchers-tweaks
~/witchers-tweaks/install.sh
```

The older `.conf`-based setup (waybar, Asahi system tweaks, etc.) lives on the
`legacy` branch.

## Install

```bash
git clone https://github.com/xxwitcher/.dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` shows a checklist of modules (all preselected; space toggles,
enter applies) and applies only the ones you keep. It uses `gum`, which ships
with Omarchy, and falls back to y/n prompts without it.

```bash
./install.sh                     # pick from the checklist
./install.sh --all               # everything, no questions
./install.sh branding fastfetch  # just these modules
./install.sh --remove [module]   # take modules back out
./install.sh --status            # which modules are installed
./install.sh --list              # show the modules
```

| Module | What it does |
|---|---|
| `branding` | Catboy braille art for fastfetch and the About screen |
| `fastfetch` | Purple fastfetch layout with a Mac-aware OS label |
| `background` | Drako desktop background |
| `bootscreen` | Purple catboy on the disk-unlock and login screens, kept across updates |

Files under `home/` are symlinked into `$HOME`, moving any existing file aside
to `<file>.bak.<timestamp>` first; `--remove` puts the newest backup back.
Because they're symlinks, edits made on the machine land directly in this
repo, so just commit them. Re-running is safe: anything already in place is
left alone.

## What's in it

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
- To undo: `./install.sh --remove bootscreen` (removes those three files and
  runs `omarchy plymouth reset`, which rebuilds the initramfs).
