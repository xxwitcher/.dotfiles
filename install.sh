#!/usr/bin/env bash
# Apply the dotfiles, module by module.
#
#   ./install.sh                 pick modules from a checklist (all preselected)
#   ./install.sh --all           apply every module available on this machine
#   ./install.sh looks topbar    apply only the named modules
#   ./install.sh --list          list modules
#
# Files under home/ are symlinked into $HOME; an existing file is moved aside to
# <file>.bak.<timestamp> first. Files under system/ are copied as root (root
# daemons shouldn't read from $HOME). Everything already in place is left alone,
# so re-running is safe. Leaving a module out never removes it if it was
# installed before.
#
# Set SUDO=pkexec when running without a terminal for the password prompt.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%s)"
SUDO="${SUDO:-sudo}"

# name | description | items
# Items: home/<path> is symlinked, system/etc/<app> is copied to /etc/<app> (and
# the module is only offered when <app> is installed), @background sets the
# desktop background.
modules=(
  "looks|Purple rotating border gradient on windows, popups and notifications, no gaps|home/.config/hypr/looknfeel.lua home/.config/omarchy/themed/shell.hyprland.toml.tpl @shell-theme"
  "keyboard|Swap left Ctrl and left Super, touchpad workspace swipe|home/.config/hypr/input.lua"
  "keybindings|SUPER+B browser, SUPER+A agent, CTRL+Q close window|home/.config/hypr/bindings.lua"
  "topbar|Auto-hide the top bar until the cursor hits the top edge|home/.config/topbar/autohide.sh home/.config/hypr/autostart.lua"
  "agentchat|Agent widget with your default agent's real terminal inside it, under compact usage limits|home/.config/omarchy/plugins/witcher.agents/Panel.qml home/.config/omarchy/plugins/witcher.agents/Main.qml home/.config/omarchy/plugins/witcher.agents/Agent.qml home/.config/omarchy/plugins/witcher.agents/manifest.json home/.config/omarchy/plugins/witcher.agents/README.md home/.config/omarchy/plugins/witcher.agents/bin/terminal-colors home/.config/omarchy/plugins/witcher.agents/assets/claude.svg home/.config/omarchy/plugins/witcher.agents/assets/codex.svg home/.config/omarchy/plugins/witcher.agents/assets/codex-light.svg home/.config/omarchy/plugins/witcher.agents/assets/fireworks.svg @agent-terminal @agent-bar"
  "branding|Catboy braille art for fastfetch and the About screen|home/.config/omarchy/branding/about.txt"
  "fastfetch|Purple fastfetch layout with a Mac-aware OS label|home/.config/fastfetch/config.jsonc"
  "background|Drako desktop background|@background"
  "bootscreen|Purple catboy on the disk-unlock and login screens, kept across updates|@bootscreen"
  "smidriver|Silicon Motion SM77x USB display adapter driver (xxwitcher's fix + evdi-dkms and a crash fix)|@smi-driver"
  "touchbar|Touch Bar layout and screenshot key (Omarchy-mac)|system/etc/tiny-dfr"
)

field() { cut -d'|' -f"$2" <<<"$1"; }

# True when a Silicon Motion USB device is plugged in (used to start the
# driver right away after installing it).
smi_adapter_present() {
  grep -qsx 090c /sys/bus/usb/devices/*/idVendor
}

available() {
  local item
  for item in $(field "$1" 3); do
    case "$item" in
      system/etc/*)
        local app="${item#system/etc/}"
        command -v "$app" >/dev/null || [[ -d "/usr/share/$app" ]] || return 1
        ;;
      @background|@shell-theme|@agent-bar|@agent-terminal)
        command -v omarchy >/dev/null || return 1
        ;;
      @smi-driver)
        command -v pacman >/dev/null && command -v omarchy >/dev/null || return 1
        ;;
      @bootscreen)
        command -v omarchy >/dev/null && [[ -d /usr/share/plymouth/themes/omarchy ]] || return 1
        ;;
    esac
  done
}

link_home() {
  local rel="${1#home/}"
  local src="$repo/home/$rel" dest="$HOME/$rel"

  if [[ "$(readlink -f "$dest" 2>/dev/null)" == "$src" ]]; then
    echo "ok       ~/$rel"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "$dest.bak.$stamp"
    echo "backup   ~/$rel -> ~/$rel.bak.$stamp"
  fi
  ln -s "$src" "$dest"
  echo "linked   ~/$rel"
  [[ $rel == .config/omarchy/plugins/* ]] && restart_shell=true
  return 0
}

copy_system() {
  local appdir="$repo/$1" app="${1#system/etc/}"

  # Collect changed files so each app needs a single privileged call.
  local pending=() src dest
  while IFS= read -r -d '' src; do
    dest="/${src#"$repo"/system/}"
    if cmp -s "$src" "$dest"; then
      echo "ok       $dest"
    else
      pending+=("$src" "$dest")
    fi
  done < <(find "$appdir" -type f -print0)
  (( ${#pending[@]} )) || return 0

  local service=""
  systemctl cat "$app.service" >/dev/null 2>&1 && service="$app.service"

  $SUDO bash -c '
    service="$1"; shift
    while (( $# )); do install -D -m 644 "$1" "$2"; shift 2; done
    [[ -z "$service" ]] || systemctl restart "$service"
  ' _ "$service" "${pending[@]}"

  local i
  for (( i = 1; i < ${#pending[@]}; i += 2 )); do echo "copied   ${pending[i]}"; done
  [[ -z "$service" ]] || echo "restarted $service"
}

# Omarchy's current-background link points at the file in this repo, so it
# survives reboots. A theme change picks the theme's own background again;
# re-run this module to restore it.
set_background() {
  local background="$repo/backgrounds/drako.png"
  if [[ "$(readlink -f "$HOME/.local/state/omarchy/current/background")" == "$background" ]]; then
    echo "ok       background"
  else
    omarchy theme bg set "$background"
    echo "set      background -> backgrounds/$(basename "$background")"
  fi
}

# The shell (bar popups, notifications, lock screen) reads its border from the
# generated theme, so rebuild the theme when the override isn't in it yet.
# `omarchy theme refresh` keeps the current background.
refresh_shell_theme() {
  local generated="$HOME/.local/state/omarchy/current/theme/shell.toml"
  if grep -qs "Keep it in sync with border_colors" "$generated"; then
    echo "ok       shell theme"
  else
    omarchy theme refresh
    echo "refreshed shell theme"
  fi
}

# Boot screen: bootscreen/dotfiles-bootscreen rebuilds Omarchy's Plymouth
# (disk unlock) and SDDM (login) theme from stock with the catboy logo, purple
# colors and the logo + password box centered as a group, then rebuilds the
# initramfs. Those theme files belong to omarchy-settings, so a pacman hook
# re-runs it after every update that rewrites them.
bootscreen_files=(
  "bootscreen/dotfiles-bootscreen:/usr/local/bin/dotfiles-bootscreen:755"
  "bootscreen/catboy-logo.png:/usr/local/share/dotfiles-bootscreen/catboy-logo.png:644"
  "bootscreen/95-dotfiles-bootscreen.hook:/etc/pacman.d/hooks/95-dotfiles-bootscreen.hook:644"
)

set_bootscreen() {
  local entry src dest mode pending=()
  for entry in "${bootscreen_files[@]}"; do
    IFS=: read -r src dest mode <<<"$entry"
    if cmp -s "$repo/$src" "$dest"; then
      echo "ok       $dest"
    else
      pending+=("$repo/$src" "$dest" "$mode")
    fi
  done

  local applied=true
  cmp -s "$repo/bootscreen/catboy-logo.png" /usr/share/plymouth/themes/omarchy/logo.png || applied=false
  grep -qs "dotfiles: center" /usr/share/plymouth/themes/omarchy/omarchy.script || applied=false

  if (( ${#pending[@]} == 0 )) && $applied; then
    echo "ok       boot screen"
    return
  fi

  $SUDO bash -c '
    while (( $# )); do install -D -m "$3" "$1" "$2"; shift 3; done
    /usr/local/bin/dotfiles-bootscreen
  ' _ "${pending[@]}"

  local i
  for (( i = 1; i < ${#pending[@]}; i += 3 )); do echo "installed ${pending[i]}"; done
  echo "applied  boot screen"
}

# The widget embeds a terminal from the qmltermwidget package. It only reads
# color schemes from its own folder, so link a scheme there that
# bin/terminal-colors regenerates from the current Omarchy theme.
agent_terminal_scheme=/usr/lib/qt6/qml/QMLTermWidget/color-schemes/Omarchy.colorscheme

setup_agent_terminal() {
  if pacman -Q qmltermwidget >/dev/null 2>&1; then
    echo "ok       qmltermwidget"
  else
    omarchy pkg add qmltermwidget
    echo "installed qmltermwidget"
    restart_shell=true
  fi

  local scheme
  scheme=$("$HOME/.config/omarchy/plugins/witcher.agents/bin/terminal-colors")
  if [[ "$(readlink "$agent_terminal_scheme")" == "$scheme" ]]; then
    echo "ok       $agent_terminal_scheme"
  else
    $SUDO ln -sfn "$scheme" "$agent_terminal_scheme"
    echo "linked   $agent_terminal_scheme"
    restart_shell=true
  fi
}

# Point the bar's agents slot at the chat widget (a clone of omarchy.agents).
use_agent_chat_widget() {
  local config="$HOME/.config/omarchy/shell.json"
  if grep -qs '"witcher.agents"' "$config"; then
    echo "ok       bar uses witcher.agents"
  elif grep -qs '"omarchy.agents"' "$config"; then
    sed -i 's/"omarchy\.agents"/"witcher.agents"/' "$config"
    echo "switched bar omarchy.agents -> witcher.agents"
    restart_shell=true
  else
    omarchy plugin enable witcher.agents >/dev/null && echo "enabled  witcher.agents"
    restart_shell=true
  fi
}

# Silicon Motion SM77x USB display driver, vendored in smidriver/driver/ from
# github.com/xxwitcher/SiliconMotion-Driver-Fix: SiliconMotion's installer with
# its bundled EVDI build removed (it fails on current kernels), so it runs on
# the system evdi-dkms instead. That needs dkms, evdi-dkms (AUR) and the
# headers for the running kernel first.
smi_driver_dir="$repo/smidriver/driver"

install_smi_driver() {
  local kernel_pkg
  kernel_pkg=$(pacman -Qqo "/usr/lib/modules/$(uname -r)" 2>/dev/null | head -1)
  if [[ -z $kernel_pkg ]]; then
    echo "skip     smi driver (can't tell which package owns the running kernel)" >&2
    return 0
  fi

  local needed=() pkg
  for pkg in dkms "$kernel_pkg-headers"; do
    pacman -Q "$pkg" >/dev/null 2>&1 || needed+=("$pkg")
  done
  # A stale package database makes these 404; Omarchy wants system updates to
  # go through `omarchy update`, so point there instead of syncing here.
  local stale="run \`omarchy update\` and re-run: ./install.sh smidriver"
  if (( ${#needed[@]} )); then
    if ! omarchy pkg add "${needed[@]}"; then
      echo "failed   installing ${needed[*]} — $stale" >&2
      return 0
    fi
    echo "installed ${needed[*]}"
  else
    echo "ok       dkms $kernel_pkg-headers"
  fi

  if pacman -Q evdi-dkms >/dev/null 2>&1; then
    echo "ok       evdi-dkms"
  else
    if ! omarchy pkg aur add evdi-dkms; then
      echo "failed   installing evdi-dkms — $stale" >&2
      return 0
    fi
    echo "installed evdi-dkms"
  fi

  if [[ -x /opt/siliconmotion/SMIUSBDisplayManager ]]; then
    echo "ok       SiliconMotion driver (reinstall: sudo smi-installer uninstall, reboot, re-run)"
  # The driver installer copies its files by relative path, so it has to run
  # from its own folder.
  elif $SUDO bash -c 'cd "$1" && ./install.sh install' _ "$smi_driver_dir"; then
    echo "installed SiliconMotion driver"
  else
    echo "failed   SiliconMotion driver (see its output above; if it asks for a reboot, reboot and re-run)" >&2
    return 0
  fi

  install_smi_nullfix
}

# SMIUSBDisplayManager calls evdi_open_attached_to(NULL), which crashes in
# upstream libevdi (strlen on NULL); SiliconMotion's bundled EVDI, which the
# fix above skips, tolerated it. Preload a shim routing that call to the
# NULL-safe evdi_open_attached_to_fixed. See smidriver/evdi-nullfix.c.
smi_nullfix_lib=/usr/local/lib/libevdi-nullfix.so
smi_nullfix_dropin=/etc/systemd/system/smiusbdisplay.service.d/nullfix.conf

install_smi_nullfix() {
  local build
  build=$(mktemp -d)
  gcc -shared -fPIC -O2 -o "$build/libevdi-nullfix.so" "$repo/smidriver/evdi-nullfix.c" -levdi

  if cmp -s "$build/libevdi-nullfix.so" "$smi_nullfix_lib" && cmp -s "$repo/smidriver/nullfix.conf" "$smi_nullfix_dropin"; then
    echo "ok       evdi null fix"
  else
    $SUDO bash -c '
      install -D -m 755 "$1" "$2"
      install -D -m 644 "$3" "$4"
      systemctl daemon-reload
    ' _ "$build/libevdi-nullfix.so" "$smi_nullfix_lib" "$repo/smidriver/nullfix.conf" "$smi_nullfix_dropin"
    echo "installed evdi null fix ($smi_nullfix_lib + service drop-in)"
  fi
  rm -rf "$build"

  # The driver's udev rule starts the service when the adapter is plugged in.
  # If it already is, (re)start it now so the monitors come up without a
  # reboot or replug, clearing any earlier crash-loop state.
  if smi_adapter_present; then
    if systemctl is-active -q smiusbdisplay && [[ $(systemctl show -p NRestarts --value smiusbdisplay) == 0 ]] \
      && [[ $(systemctl show -p ActiveEnterTimestampMonotonic --value smiusbdisplay) -gt 0 ]] \
      && systemctl show -p Environment --value smiusbdisplay | grep -q libevdi-nullfix; then
      echo "ok       smiusbdisplay running"
    else
      $SUDO bash -c 'systemctl reset-failed smiusbdisplay 2>/dev/null; systemctl restart smiusbdisplay'
      echo "started  smiusbdisplay (adapter is plugged in)"
    fi
  else
    echo "note     plug the adapter in to start the driver (reboot if its monitors don't come up)"
  fi
}

# Modules this machine can use, in menu order.
names=() labels=()
for m in "${modules[@]}"; do
  available "$m" || continue
  names+=("$(field "$m" 1)")
  labels+=("$(printf '%-12s %s' "$(field "$m" 1)" "$(field "$m" 2)")")
done

selected=()
case "${1:-}" in
  --list)
    printf '%s\n' "${labels[@]}"
    exit 0
    ;;
  --all)
    selected=("${names[@]}")
    ;;
  "")
    if [[ ! -t 0 ]]; then
      echo "No terminal to ask in; pass --all or module names (see --list)." >&2
      exit 1
    fi
    if command -v gum >/dev/null; then
      mapfile -t picked < <(gum choose --no-limit --height 14 \
        --header "Space toggles, enter applies" \
        --selected '*' "${labels[@]}")
      for label in "${picked[@]}"; do selected+=("${label%% *}"); done
    else
      for i in "${!names[@]}"; do
        read -rp "Apply ${labels[i]}? [Y/n] " answer
        [[ "$answer" =~ ^[Nn] ]] || selected+=("${names[i]}")
      done
    fi
    ;;
  *)
    for want in "$@"; do
      if [[ " ${names[*]} " != *" $want "* ]]; then
        echo "Unknown or unavailable module: $want (see --list)" >&2
        exit 1
      fi
    done
    selected=("$@")
    ;;
esac

if (( ${#selected[@]} == 0 )); then
  echo "Nothing selected."
  exit 0
fi

reload_hypr=false
# The shell runs without a file watcher, so new or changed plugins only load
# after a restart. Set by the steps above when they change something.
restart_shell=false
for m in "${modules[@]}"; do
  name="$(field "$m" 1)"
  [[ " ${selected[*]} " == *" $name "* ]] || continue
  echo "== $name"
  for item in $(field "$m" 3); do
    case "$item" in
      home/*)
        link_home "$item"
        [[ "$item" == home/.config/hypr/* ]] && reload_hypr=true
        ;;
      system/*) copy_system "$item" ;;
      @background) set_background ;;
      @shell-theme) refresh_shell_theme ;;
      @bootscreen) set_bootscreen ;;
      @agent-terminal) setup_agent_terminal ;;
      @smi-driver) install_smi_driver ;;
      @agent-bar) use_agent_chat_widget ;;
    esac
  done
done

# Apply and validate the Hyprland config when running inside a Hyprland session.
if $reload_hypr && command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
  hyprctl reload >/dev/null
  errors="$(hyprctl configerrors)"
  if [[ -n "${errors//[[:space:]]/}" ]]; then
    echo "Hyprland config errors:" >&2
    echo "$errors" >&2
    exit 1
  fi
  echo "Hyprland reloaded"
fi

# Restart the Omarchy shell (bar) when a plugin changed and it's running.
if $restart_shell && pgrep -f "quickshell -n -p .*omarchy/shell" >/dev/null; then
  omarchy restart shell >/dev/null
  echo "restarted Omarchy shell"
fi
