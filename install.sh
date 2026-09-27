#!/usr/bin/env bash
# Apply, remove and configure the dotfiles, module by module.
#
#   ./install.sh                     pick modules from a checklist (all preselected)
#   ./install.sh --all               apply every module available on this machine
#   ./install.sh looks topbar        apply only the named modules
#   ./install.sh --add [module...]   add modules (asks which, from those not installed)
#   ./install.sh --remove [module...]  remove modules (asks which, then confirms)
#   ./install.sh --configure [module]  change a module's settings
#   ./install.sh --status            show which modules are installed
#   ./install.sh --list              list modules
#   ./install.sh --monitors          only run the interactive monitor setup
#   ./install.sh --remove-menu       take "Witcher's Tweaks" out of the Omarchy menu
#
# Files under home/ are symlinked into $HOME; an existing file is moved aside to
# <file>.bak.<timestamp> first. Files under system/ are copied as root (root
# daemons shouldn't read from $HOME), keeping the first original as .bak too.
# Everything already in place is left alone, so re-running is safe. Leaving a
# module out never removes it if it was installed before; --remove does.
#
# Removing a module undoes each of its steps in reverse: a linked file goes back
# to the backup it replaced (or Omarchy's default copy, or nothing), settings
# written to shell.json are taken back out, and system changes are reverted.
#
# Every run also adds Setup > Witcher's Tweaks to the Omarchy menu, with Add,
# Remove and Configure entries that open this script in a terminal.
#
# Set SUDO=pkexec when running without a terminal for the password prompt.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%s)"
SUDO="${SUDO:-sudo}"
OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"

# name | description | items
# Items: home/<path> is symlinked, system/etc/<app> is copied to /etc/<app> (and
# the module is only offered when <app> is installed), @<step> is one of the
# steps below (each has an apply, a remove and a check).
modules=(
  "looks|Rotating gradient border (purple, or your own colors) on windows, popups and notifications, no gaps, sliding fade between workspaces|home/.config/hypr/looknfeel.lua home/.config/omarchy/plugins/witcher.border-colors/Picker.qml home/.config/omarchy/plugins/witcher.border-colors/manifest.json home/.config/omarchy/plugins/witcher.border-colors/bin/border-colors @border-shell @border-picker @border-spin"
  "keyboard|Swap left Ctrl and left Super, macOS-like 3-finger swipes (workspaces, overview)|home/.config/hypr/input.lua"
  "keybindings|SUPER+B browser, SUPER+A agent, CTRL+Q close window|home/.config/hypr/bindings.lua"
  "topbar|Auto-hide the top bar until the cursor hits the top edge|home/.config/topbar/autohide.sh home/.config/hypr/autostart.lua @autohide"
  "clock|Clock in the middle of the top bar|@clock-center"
  "battery|Battery percentage next to the battery icon in the top bar|@battery-percent"
  "notifypanel|Bell in the top bar that opens recent notifications, each dismissable, with Dismiss all|home/.config/omarchy/plugins/witcher.notifications/Panel.qml home/.config/omarchy/plugins/witcher.notifications/manifest.json home/.config/omarchy/plugins/witcher.notifications/bin/notification-store @notify-panel"
  "notifytimeout|Every notification leaves the screen after a few seconds (5 by default), critical ones too|home/.config/omarchy/plugins/witcher.notify-timeout/Service.qml home/.config/omarchy/plugins/witcher.notify-timeout/manifest.json @notify-timeout"
  "overview|Swipe up with 3 fingers for a Mission Control-style overview of workspaces and windows (gesture is in keyboard)|home/.config/omarchy/plugins/witcher.overview/Overview.qml home/.config/omarchy/plugins/witcher.overview/manifest.json home/.config/omarchy/plugins/witcher.overview/bin/focus-window @overview"
  "suspend|No screensaver; suspend after a chosen idle time (1-60 min)|home/.config/omarchy/plugins/witcher.idle-suspend/Service.qml home/.config/omarchy/plugins/witcher.idle-suspend/manifest.json @idle-suspend"
  "agentchat|Agent widget with your default agent's real terminal inside it, under compact usage limits|home/.config/omarchy/plugins/witcher.agents/Panel.qml home/.config/omarchy/plugins/witcher.agents/Main.qml home/.config/omarchy/plugins/witcher.agents/Agent.qml home/.config/omarchy/plugins/witcher.agents/manifest.json home/.config/omarchy/plugins/witcher.agents/README.md home/.config/omarchy/plugins/witcher.agents/bin/terminal-colors home/.config/omarchy/plugins/witcher.agents/assets/claude.svg home/.config/omarchy/plugins/witcher.agents/assets/codex.svg home/.config/omarchy/plugins/witcher.agents/assets/codex-light.svg home/.config/omarchy/plugins/witcher.agents/assets/fireworks.svg @agent-terminal @agent-bar"
  "branding|Catboy braille art for fastfetch and the About screen|home/.config/omarchy/branding/about.txt"
  "fastfetch|Purple fastfetch layout with a Mac-aware OS label|home/.config/fastfetch/config.jsonc"
  "background|Drako desktop background|@background"
  "bootscreen|Purple catboy on the disk-unlock and login screens, kept across updates|@bootscreen"
  "smidriver|Silicon Motion SM77x USB display adapter driver (xxwitcher's fix + evdi-dkms and a crash fix)|@smi-driver"
  "touchbar|Touch Bar layout and screenshot key (Omarchy-mac)|system/etc/tiny-dfr"
)

# Settings --configure offers: name | description | function | module. With a
# module (the name itself when left out) it shows only while that module is
# installed; monitors isn't a module and always shows. These are all per-machine settings (monitors.lua, shell.json); values
# written into the repo's own files (border colors, swipe tuning) stay out,
# since changing them would change the repo.
configurable=(
  "monitors|Resolution, scale, rotation and position of each screen|configure_monitors"
  "borders|Colors of the window, popup and notification borders (color picker)|configure_borders|looks"
  "suspend|How long idle before suspending|configure_idle_suspend"
  "notifytimeout|How long notifications stay on screen|configure_notify_timeout"
)

field() { cut -d'|' -f"$2" <<<"$1"; }

module_line() {
  local m
  for m in "${modules[@]}"; do
    [[ $(field "$m" 1) == "$1" ]] && { echo "$m"; return 0; }
  done
  return 1
}

# True when a Silicon Motion USB device is plugged in (used to start the
# driver right away after installing it).
smi_adapter_present() {
  grep -qsx 090c /sys/bus/usb/devices/*/idVendor
}

has_battery() {
  grep -qsx Battery /sys/class/power_supply/*/type
}

available() {
  local item
  for item in $(field "$1" 3); do
    case "$item" in
      system/etc/*)
        local app="${item#system/etc/}"
        command -v "$app" >/dev/null || [[ -d "/usr/share/$app" ]] || return 1
        ;;
      @background|@border-shell|@border-picker|@border-spin|@agent-bar|@agent-terminal|@clock-center|@notify-panel|@notify-timeout|@idle-suspend|@overview|@autohide)
        command -v omarchy >/dev/null || return 1
        ;;
      @battery-percent)
        command -v omarchy >/dev/null && has_battery || return 1
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

# ---------------------------------------------------------------- home files

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
  [[ $rel == .config/hypr/* ]] && reload_hypr=true
  return 0
}

home_linked() {
  local rel="${1#home/}"
  [[ -L "$HOME/$rel" && "$(readlink -f "$HOME/$rel")" == "$repo/home/$rel" ]]
}

# The newest <file>.bak.<stamp> that isn't itself a link back into this repo
# (an old install), i.e. what the file was before the dotfiles last took it.
newest_backup() {
  local dest="$1" best="" best_stamp=0 candidate suffix
  for candidate in "$dest".bak.*; do
    [[ -e $candidate || -L $candidate ]] || continue
    suffix="${candidate##*.bak.}"
    [[ $suffix =~ ^[0-9]+$ ]] || continue
    [[ -L $candidate && "$(readlink -f "$candidate")" == "$repo"/* ]] && continue
    if (( suffix > best_stamp )); then best="$candidate"; best_stamp=$suffix; fi
  done
  [[ -n $best ]] && echo "$best"
}

# Takes the link out and puts back what it replaced: the newest backup, else
# Omarchy's default for that file (the Hyprland overrides need one), else
# nothing. Anything that isn't our link is left alone.
unlink_home() {
  local rel="${1#home/}"
  local dest="$HOME/$rel"

  if ! home_linked "$1"; then
    echo "ok       ~/$rel (not linked to the dotfiles)"
    return 0
  fi
  rm "$dest"

  local backup default="$OMARCHY_PATH/config/${rel#.config/}"
  if backup=$(newest_backup "$dest"); then
    mv "$backup" "$dest"
    echo "restored ~/$rel from ~/${backup#"$HOME"/}"
  elif [[ $rel == .config/* && -f $default ]]; then
    cp "$default" "$dest"
    echo "restored ~/$rel (Omarchy default)"
  else
    echo "removed  ~/$rel"
  fi

  if [[ $rel == .config/omarchy/plugins/* ]]; then
    # Drop the plugin's folders once they're empty.
    local dir
    dir=$(dirname "$dest")
    while [[ $dir == "$HOME/.config/omarchy/plugins/"* ]] && rmdir "$dir" 2>/dev/null; do
      dir=$(dirname "$dir")
    done
    restart_shell=true
  fi
  [[ $rel == .config/hypr/* ]] && reload_hypr=true
  return 0
}

# ---------------------------------------------------------------- system files

system_files() {
  find "$repo/$1" -type f -print0
}

system_installed() {
  local src dest
  while IFS= read -r -d '' src; do
    dest="/${src#"$repo"/system/}"
    cmp -s "$src" "$dest" || return 1
  done < <(system_files "$1")
}

copy_system() {
  local app="${1#system/etc/}"

  # Collect changed files so each app needs a single privileged call.
  local pending=() src dest
  while IFS= read -r -d '' src; do
    dest="/${src#"$repo"/system/}"
    if cmp -s "$src" "$dest"; then
      echo "ok       $dest"
    else
      pending+=("$src" "$dest")
    fi
  done < <(system_files "$1")
  (( ${#pending[@]} )) || return 0

  local service=""
  systemctl cat "$app.service" >/dev/null 2>&1 && service="$app.service"

  # A file that was there before the first install is kept as .bak so --remove
  # can put it back. Later updates don't back up our own earlier copy.
  $SUDO bash -c '
    stamp="$1" service="$2"; shift 2
    while (( $# )); do
      if [[ -e $2 ]] && ! compgen -G "$2.bak.*" >/dev/null; then cp -p "$2" "$2.bak.$stamp"; fi
      install -D -m 644 "$1" "$2"
      shift 2
    done
    [[ -z "$service" ]] || systemctl restart "$service"
  ' _ "$stamp" "$service" "${pending[@]}"

  local i
  for (( i = 1; i < ${#pending[@]}; i += 2 )); do echo "copied   ${pending[i]}"; done
  [[ -z "$service" ]] || echo "restarted $service"
}

# Puts back what each file replaced (its oldest .bak, the original) or deletes
# it, then restarts the app's service.
remove_system() {
  local app="${1#system/etc/}"
  local targets=() src dest
  while IFS= read -r -d '' src; do
    dest="/${src#"$repo"/system/}"
    [[ -e $dest ]] && targets+=("$dest")
  done < <(system_files "$1")
  if (( ${#targets[@]} == 0 )); then
    echo "ok       /etc/$app (nothing to remove)"
    return 0
  fi

  local service=""
  systemctl cat "$app.service" >/dev/null 2>&1 && service="$app.service"

  $SUDO bash -c '
    service="$1"; shift
    for dest in "$@"; do
      backup=$(ls -1d "$dest".bak.* 2>/dev/null | sort -V | head -1)
      if [[ -n $backup ]]; then mv -f "$backup" "$dest"; echo "restored $dest"
      else rm -f "$dest"; echo "removed  $dest"; fi
    done
    [[ -z "$service" ]] || systemctl restart "$service"
  ' _ "$service" "${targets[@]}"
  [[ -z "$service" ]] || echo "restarted $service"
}

# ---------------------------------------------------------------- background

background="$repo/backgrounds/drako.png"
background_link="$HOME/.local/state/omarchy/current/background"

background_set() {
  [[ "$(readlink -f "$background_link" 2>/dev/null)" == "$background" ]]
}

# Omarchy's current-background link points at the file in this repo, so it
# survives reboots. A theme change picks the theme's own background again;
# re-run this module to restore it.
set_background() {
  if background_set; then
    echo "ok       background"
  else
    omarchy theme bg set "$background"
    echo "set      background -> backgrounds/$(basename "$background")"
  fi
}

# Our background isn't one of the theme's, so "next" lands on the theme's first.
unset_background() {
  if background_set; then
    omarchy theme bg next
    echo "set      background -> the theme's own"
  else
    echo "ok       background (already the theme's)"
  fi
}

# ---------------------------------------------------------------- borders

# The gradient's colors live in ~/.config/witcher-tweaks/border.conf (per
# machine, default purple): hypr/looknfeel.lua reads them, and the
# witcher.border-colors plugin's bin/border-colors writes the matching Omarchy
# shell template (so popups, notifications and the lock screen share the
# gradient) and rebuilds the theme when it changes. Its Picker.qml is the
# color picker behind Configure > Borders.
border_colors="$HOME/.config/omarchy/plugins/witcher.border-colors/bin/border-colors"
border_template="$HOME/.config/omarchy/themed/shell.hyprland.toml.tpl"

border_template_ours() {
  grep -qsF "# witcher-tweaks: generated by border-colors" "$border_template"
}

# looknfeel.lua's spinning gradient runs on a timer inside Hyprland, which
# outlives the file; removal stops it (the reload afterwards applies whatever
# looknfeel.lua is back in place). Adding needs nothing: the file starts it.
stop_border_spin() {
  if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
    hyprctl eval 'if _G.witcher_border_timer then _G.witcher_border_timer:set_enabled(false); _G.witcher_border_timer = nil end; _G.witcher_border_tick = nil' >/dev/null
    echo "stopped  spinning border"
    reload_hypr=true
  fi
}

configure_borders() {
  if ! pgrep -f "quickshell -n -p .*omarchy/shell" >/dev/null; then
    echo "The border picker runs in the Omarchy shell, which isn't running." >&2
    return 1
  fi
  omarchy-shell shell summon witcher.border-colors '{}' >/dev/null
  echo "Pick the colors in the window that just opened (Enter saves, Esc cancels)."
}

# ---------------------------------------------------------------- boot screen

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

bootscreen_installed() {
  [[ -e /etc/pacman.d/hooks/95-dotfiles-bootscreen.hook || -e /usr/local/bin/dotfiles-bootscreen ]]
}

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

# Takes the hook and script out first so nothing re-applies the catboy, then
# lets Omarchy put its stock Plymouth and SDDM themes back (that rebuilds the
# initramfs).
remove_bootscreen() {
  if ! bootscreen_installed && ! grep -qs "dotfiles: center" /usr/share/plymouth/themes/omarchy/omarchy.script; then
    echo "ok       boot screen (already Omarchy's)"
    return 0
  fi
  $SUDO rm -rf /etc/pacman.d/hooks/95-dotfiles-bootscreen.hook /usr/local/bin/dotfiles-bootscreen /usr/local/share/dotfiles-bootscreen
  echo "removed  boot screen hook and script"
  omarchy plymouth reset
  echo "restored Omarchy's boot and login screens"
}

# ---------------------------------------------------------------- agent widget

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

# qmltermwidget itself stays: it's an ordinary package something else may use.
remove_agent_terminal() {
  if [[ -L $agent_terminal_scheme ]]; then
    $SUDO rm -f "$agent_terminal_scheme"
    echo "removed  $agent_terminal_scheme"
  else
    echo "ok       $agent_terminal_scheme (not there)"
  fi
  echo "note     qmltermwidget stays installed (omarchy pkg remove qmltermwidget to drop it)"
}

# Point the bar's agents slot at the chat widget (a clone of omarchy.agents).
use_agent_chat_widget() {
  if grep -qs '"witcher.agents"' "$shell_config"; then
    echo "ok       bar uses witcher.agents"
  elif grep -qs '"omarchy.agents"' "$shell_config"; then
    sed -i 's/"omarchy\.agents"/"witcher.agents"/' "$shell_config"
    echo "switched bar omarchy.agents -> witcher.agents"
    restart_shell=true
  else
    omarchy plugin enable witcher.agents >/dev/null && echo "enabled  witcher.agents"
    restart_shell=true
  fi
}

restore_agent_widget() {
  edit_shell_config "bar uses omarchy.agents again" '
    .bar.layout |= with_entries(.value |= map(if .id == "witcher.agents" then .id = "omarchy.agents" else . end))'
}

# ---------------------------------------------------------------- shell.json

# ~/.config/omarchy/shell.json is the user's own (machine-specific) bar layout,
# so it isn't linked from the repo; the modules below edit it in place with a
# jq filter. The shell hot-reloads it. Prints "ok" when the filter changes
# nothing, otherwise writes it (starting from Omarchy's defaults if there's no
# file yet) and prints the message.
shell_config="$HOME/.config/omarchy/shell.json"

edit_shell_config() {
  local message="$1" filter="$2"
  shift 2
  if [[ ! -f $shell_config ]]; then
    mkdir -p "$(dirname "$shell_config")"
    cp "$OMARCHY_PATH/config/omarchy/shell.json" "$shell_config"
  fi
  local current next
  current=$(jq . "$shell_config")
  next=$(jq "$@" "$filter" <<<"$current")
  if [[ $next == "$current" ]]; then
    echo "ok       $message"
  else
    printf '%s\n' "$next" >"$shell_config.tmp.$stamp"
    mv "$shell_config.tmp.$stamp" "$shell_config"
    echo "set      $message"
  fi
}

# True when the jq expression holds for shell.json.
shell_config_has() {
  [[ -f $shell_config ]] && jq -e "$@" "$shell_config" >/dev/null 2>&1
}

# Moves a bar widget to the front of the center section, keeping its settings.
center_clock() {
  edit_shell_config "clock in the middle of the bar" '
    if any(.bar.layout.center[]?; .id == "omarchy.clock") then . else
      (first(.bar.layout[]?[]? | select(.id == "omarchy.clock")) // {id: "omarchy.clock"}) as $clock
      | .bar.layout |= with_entries(.value |= map(select(.id != "omarchy.clock")))
      | .bar.layout.center = [$clock] + (.bar.layout.center // [])
    end'
}

# Back where Omarchy has it: on the right, before the keyboard layout.
uncenter_clock() {
  edit_shell_config "clock back on the right of the bar" '
    if any(.bar.layout.center[]?; .id == "omarchy.clock") | not then . else
      first(.bar.layout.center[] | select(.id == "omarchy.clock")) as $clock
      | .bar.layout.center |= map(select(.id != "omarchy.clock"))
      | (.bar.layout.right // []) as $right
      | ([$right | to_entries[] | select(.value.id == "omarchy.keyboard-layout") | .key] | first // ($right | length)) as $at
      | .bar.layout.right = $right[:$at] + [$clock] + $right[$at:]
    end'
}

# The stock power widget has the percentage built in (right-click toggles it);
# this just turns it on.
show_battery_percent() {
  if ! shell_config_has 'any(.bar.layout[]?[]?; .id == "omarchy.power")'; then
    echo "skip     battery percentage (omarchy.power isn't on the bar)"
    return 0
  fi
  edit_shell_config "battery percentage" '
    .bar.layout |= with_entries(.value |= map(if .id == "omarchy.power" then .showPercentage = true else . end))'
}

hide_battery_percent() {
  edit_shell_config "no battery percentage" '
    .bar.layout |= with_entries(.value |= map(if .id == "omarchy.power" then del(.showPercentage) else . end))'
}

# The bell goes on the right, before Bluetooth (or at the end without it).
use_notification_panel() {
  edit_shell_config "notifications bell on the bar" '
    if any(.bar.layout[]?[]?; .id == "witcher.notifications") then . else
      (.bar.layout.right // []) as $right
      | ([$right | to_entries[] | select(.value.id == "omarchy.bluetooth") | .key] | first // ($right | length)) as $at
      | .bar.layout.right = $right[:$at] + [{id: "witcher.notifications"}] + $right[$at:]
    end'
}

# Also drops the panel's own copy of past notifications (Omarchy's history
# is untouched).
remove_notification_panel() {
  edit_shell_config "no notifications bell on the bar" '
    .bar.layout |= with_entries(.value |= map(select(.id != "witcher.notifications")))'
  local store="${XDG_STATE_HOME:-$HOME/.local/state}/witcher/notifications"
  if [[ -d $store ]]; then
    rm -rf "$store"
    rmdir "$(dirname "$store")" 2>/dev/null || true
    echo "removed  the panel's saved notifications"
  fi
}

# Services and overlays are switched on by an entry in plugins[]; extra keys
# on the entry are their settings.
enable_service() {
  local id="$1" settings="$2" message="$3"
  edit_shell_config "$message" '
    .plugins = (.plugins // [])
    | if any(.plugins[]; .id == $id)
      then .plugins |= map(if .id == $id then . + $settings else . end)
      else .plugins += [{id: $id} + $settings]
      end' --arg id "$id" --argjson settings "$settings"
}

disable_service() {
  local id="$1" message="$2"
  edit_shell_config "$message" '.plugins = ((.plugins // []) | map(select(.id != $id)))' --arg id "$id"
}

service_enabled() {
  shell_config_has --arg id "$1" 'any(.plugins[]?; .id == $id)'
}

service_setting() {
  local id="$1" key="$2" fallback="$3"
  jq -r --arg id "$id" --arg key "$key" --arg fallback "$fallback" \
    'first(.plugins[]? | select(.id == $id) | .[$key]) // $fallback' "$shell_config" 2>/dev/null || echo "$fallback"
}

# ---------------------------------------------------------------- choices

# Asks for one of a fixed set of values: gum when there is one, else a
# prompt. Without a terminal it keeps the current value. Prints the choice.
#   pick_value <question> <unit> <current> <values...>
pick_value() {
  local question="$1" unit="$2" current="$3"
  shift 3
  local choices=("$@") choice
  [[ " ${choices[*]} " == *" $current "* ]] || current="${choices[0]}"

  if [[ ! -t 0 ]]; then
    echo "$current"
  elif command -v gum >/dev/null; then
    local labels=()
    for choice in "${choices[@]}"; do labels+=("$choice$unit"); done
    choice=$(gum choose --header "$question" --selected "$current$unit" "${labels[@]}")
    [[ -n $choice ]] || choice="$current$unit"
    echo "${choice%"$unit"}"
  else
    read -rp "$question (${choices[*]}) [$current] " choice </dev/tty
    choice=${choice%"$unit"}
    [[ " ${choices[*]} " == *" $choice "* ]] || choice=$current
    echo "$choice"
  fi
}

# An environment override (SUSPEND_MINUTES, NOTIFY_SECONDS) skips the question.
env_choice() {
  local name="$1" value="$2"
  shift 2
  if [[ " $* " != *" $value "* ]]; then
    echo "$name must be one of: $*" >&2
    return 1
  fi
  echo "$value"
}

# ---------------------------------------------------------------- suspend

suspend_choices=(1 5 10 15 30 60)

pick_suspend_minutes() {
  if [[ -n ${SUSPEND_MINUTES:-} ]]; then
    env_choice SUSPEND_MINUTES "$SUSPEND_MINUTES" "${suspend_choices[@]}"
  else
    pick_value "Suspend after how long idle?" m "$(service_setting witcher.idle-suspend minutes 5)" "${suspend_choices[@]}"
  fi
}

# Suspend replaces the screensaver: Omarchy's own toggle turns that off, and
# witcher.idle-suspend does the suspending (the lock still comes first, via
# Omarchy's sleep-lock).
setup_idle_suspend() {
  local minutes
  minutes=$(pick_suspend_minutes)
  enable_service witcher.idle-suspend "{\"minutes\":$minutes}" "suspend after ${minutes}m idle"
  if omarchy-toggle-enabled screensaver-off; then
    echo "ok       screensaver off"
  else
    omarchy-toggle screensaver-off on
    echo "set      screensaver off"
  fi
}

remove_idle_suspend() {
  disable_service witcher.idle-suspend "no suspend when idle"
  if omarchy-toggle-enabled screensaver-off; then
    omarchy-toggle screensaver-off off
    echo "set      screensaver back on"
  else
    echo "ok       screensaver on"
  fi
}

configure_idle_suspend() {
  local minutes
  minutes=$(pick_suspend_minutes)
  enable_service witcher.idle-suspend "{\"minutes\":$minutes}" "suspend after ${minutes}m idle"
}

# ---------------------------------------------------------------- notifications

notify_choices=(3 5 8 10 15)

pick_notify_seconds() {
  if [[ -n ${NOTIFY_SECONDS:-} ]]; then
    env_choice NOTIFY_SECONDS "$NOTIFY_SECONDS" "${notify_choices[@]}"
  else
    pick_value "Notifications leave the screen after?" s "$(service_setting witcher.notify-timeout seconds 5)" "${notify_choices[@]}"
  fi
}

# Installs with the current setting (5 seconds the first time) without asking;
# --configure changes it.
setup_notify_timeout() {
  local seconds
  seconds=$(service_setting witcher.notify-timeout seconds 5)
  [[ -n ${NOTIFY_SECONDS:-} ]] && seconds=$(pick_notify_seconds)
  enable_service witcher.notify-timeout "{\"seconds\":$seconds}" "notifications leave after ${seconds}s"
}

configure_notify_timeout() {
  local seconds
  seconds=$(pick_notify_seconds)
  enable_service witcher.notify-timeout "{\"seconds\":$seconds}" "notifications leave after ${seconds}s"
}

# ---------------------------------------------------------------- monitors

configure_monitors() {
  if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    echo "The monitor setup needs a running Hyprland session." >&2
    return 1
  fi
  "$monitor_setup"
}

# ---------------------------------------------------------------- auto-hide

autohide_script="$HOME/.config/topbar/autohide.sh"

autohide_running() {
  pgrep -f "\.config/topbar/autohide\.sh" >/dev/null
}

# autostart.lua starts it at login; this starts it now too.
start_autohide() {
  if autohide_running; then
    echo "ok       top bar auto-hide running"
  elif [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -x $autohide_script ]]; then
    setsid -f "$autohide_script" >/dev/null 2>&1 </dev/null
    echo "started  top bar auto-hide"
  else
    echo "note     top bar auto-hide starts at the next login"
  fi
}

# Runs before the files are unlinked: stop the loop and show the bar.
stop_autohide() {
  if autohide_running; then
    pkill -f "\.config/topbar/autohide\.sh" || true
    echo "stopped  top bar auto-hide"
  else
    echo "ok       top bar auto-hide not running"
  fi
  if command -v omarchy-toggle-bar >/dev/null && omarchy-toggle-enabled bar-off; then
    omarchy-toggle-bar off
    echo "set      top bar shown"
  fi
}

# ---------------------------------------------------------------- SMI driver

# Silicon Motion SM77x USB display driver, vendored in smidriver/driver/ from
# github.com/xxwitcher/SiliconMotion-Driver-Fix: SiliconMotion's installer with
# its bundled EVDI build removed (it fails on current kernels), so it runs on
# the system evdi-dkms instead. That needs dkms, evdi-dkms (AUR) and the
# headers for the running kernel first.
smi_driver_dir="$repo/smidriver/driver"

smi_installed() {
  [[ -x /opt/siliconmotion/SMIUSBDisplayManager || -e $smi_nullfix_lib ]]
}

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

# SiliconMotion's own uninstaller removes the driver; the null-fix shim and
# its drop-in go too. The dkms, evdi-dkms and kernel header packages stay.
remove_smi_driver() {
  if ! smi_installed; then
    echo "ok       SiliconMotion driver (not installed)"
    return 0
  fi
  if [[ -x /opt/siliconmotion/SMIUSBDisplayManager ]] && command -v smi-installer >/dev/null; then
    $SUDO smi-installer uninstall
    echo "removed  SiliconMotion driver"
  fi
  $SUDO bash -c '
    rm -f "$1" "$2"
    rmdir "$(dirname "$2")" 2>/dev/null || true
    systemctl daemon-reload
  ' _ "$smi_nullfix_lib" "$smi_nullfix_dropin"
  echo "removed  evdi null fix"
  echo "note     dkms, evdi-dkms and the kernel headers stay installed (omarchy pkg remove evdi-dkms to drop it); reboot to finish"
}

# ---------------------------------------------------------------- steps

# apply | remove | check for one item. check succeeds when the item is in
# place, fails when it isn't, and returns 2 for items that don't tell (so they
# don't count either way).
step() {
  local action="$1" item="$2"
  case "$action:$item" in
    apply:home/*) link_home "$item" ;;
    remove:home/*) unlink_home "$item" ;;
    check:home/*) home_linked "$item" ;;

    apply:system/*) copy_system "$item" ;;
    remove:system/*) remove_system "$item" ;;
    check:system/*) system_installed "$item" ;;

    apply:@background) set_background ;;
    remove:@background) unset_background ;;
    check:@background) background_set ;;

    apply:@border-shell) "$border_colors" shell-apply ;;
    remove:@border-shell) "$border_colors" shell-remove ;;
    check:@border-shell) border_template_ours ;;

    apply:@border-picker) enable_service witcher.border-colors '{}' "border color picker" ;;
    remove:@border-picker) disable_service witcher.border-colors "no border color picker" ;;
    check:@border-picker) service_enabled witcher.border-colors ;;

    apply:@border-spin) echo "ok       spinning border (looknfeel.lua runs it)" ;;
    remove:@border-spin) stop_border_spin ;;
    check:@border-spin) return 2 ;;

    apply:@bootscreen) set_bootscreen ;;
    remove:@bootscreen) remove_bootscreen ;;
    check:@bootscreen) bootscreen_installed ;;

    apply:@agent-terminal) setup_agent_terminal ;;
    remove:@agent-terminal) remove_agent_terminal ;;
    check:@agent-terminal) [[ -L $agent_terminal_scheme ]] ;;

    apply:@agent-bar) use_agent_chat_widget ;;
    remove:@agent-bar) restore_agent_widget ;;
    check:@agent-bar) shell_config_has 'any(.bar.layout[]?[]?; .id == "witcher.agents")' ;;

    apply:@smi-driver) install_smi_driver ;;
    remove:@smi-driver) remove_smi_driver ;;
    check:@smi-driver) smi_installed ;;

    apply:@clock-center) center_clock ;;
    remove:@clock-center) uncenter_clock ;;
    check:@clock-center) shell_config_has 'any(.bar.layout.center[]?; .id == "omarchy.clock")' ;;

    apply:@battery-percent) show_battery_percent ;;
    remove:@battery-percent) hide_battery_percent ;;
    check:@battery-percent) shell_config_has 'any(.bar.layout[]?[]?; .id == "omarchy.power" and .showPercentage == true)' ;;

    apply:@notify-panel) use_notification_panel ;;
    remove:@notify-panel) remove_notification_panel ;;
    check:@notify-panel) shell_config_has 'any(.bar.layout[]?[]?; .id == "witcher.notifications")' ;;

    apply:@notify-timeout) setup_notify_timeout ;;
    remove:@notify-timeout) disable_service witcher.notify-timeout "notifications keep Omarchy's timing" ;;
    check:@notify-timeout) service_enabled witcher.notify-timeout ;;

    apply:@idle-suspend) setup_idle_suspend ;;
    remove:@idle-suspend) remove_idle_suspend ;;
    check:@idle-suspend) service_enabled witcher.idle-suspend ;;

    apply:@overview) enable_service witcher.overview '{}' "window overview" ;;
    remove:@overview) disable_service witcher.overview "no window overview" ;;
    check:@overview) service_enabled witcher.overview ;;

    apply:@autohide) start_autohide ;;
    remove:@autohide) stop_autohide ;;
    check:@autohide) return 2 ;;

    *) echo "unknown step: $action $item" >&2; return 1 ;;
  esac
}

# full, partial or none.
module_state() {
  local m item on=0 off=0 status
  m=$(module_line "$1") || { echo none; return; }
  for item in $(field "$m" 3); do
    status=0
    step check "$item" || status=$?
    case $status in
      0) on=$((on + 1)) ;;
      2) ;;
      *) off=$((off + 1)) ;;
    esac
  done
  if (( on > 0 && off == 0 )); then echo full
  elif (( on > 0 )); then echo partial
  else echo none
  fi
}

apply_modules() {
  local m name item
  for m in "${modules[@]}"; do
    name="$(field "$m" 1)"
    [[ " $* " == *" $name "* ]] || continue
    echo "== $name"
    for item in $(field "$m" 3); do step apply "$item"; done
  done
}

# Each module's steps in reverse, so its settings leave shell.json before its
# plugin files go, and background loops stop before their scripts do.
remove_modules() {
  local m name items i
  for m in "${modules[@]}"; do
    name="$(field "$m" 1)"
    [[ " $* " == *" $name "* ]] || continue
    echo "== removing $name"
    read -ra items <<<"$(field "$m" 3)"
    for (( i = ${#items[@]} - 1; i >= 0; i-- )); do step remove "${items[i]}"; done
  done
}

# ---------------------------------------------------------------- menu

menu_file="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
menu_begin="// >>> witcher-tweaks (managed by the dotfiles install.sh; --remove-menu takes it out)"
menu_end="// <<< witcher-tweaks"

menu_block() {
  local run
  run() { printf 'omarchy-launch-floating-terminal-with-presentation %q' "$(printf '%q %s' "$repo/install.sh" "$1")"; }
  jq -n -r --arg add "$(run --add)" --arg remove "$(run --remove)" --arg configure "$(run --configure)" --arg title "Witcher's Tweaks" '
    {
      "setup.witcher": {icon: "\udb80\udd1b", label: $title, aliases: ["witcher"], description: "Add, remove or configure the dotfiles tweaks"},
      "setup.witcher.add": {icon: "\uf067", label: "Add", description: "Install tweaks that are not on this machine yet", action: $add},
      "setup.witcher.remove": {icon: "\uf1f8", label: "Remove", description: "Safely take tweaks back out", action: $remove},
      "setup.witcher.configure": {icon: "\uf1de", label: "Configure", description: "Change the settings of installed tweaks", action: $configure}
    }
    | to_entries[] | "\(.key | tojson): \(.value | tojson),"'
  setup_rows_after_config
}

# The menu lists Omarchy's own rows first, in their file order, and appends
# new ids from the extension file after them, so Witcher's Tweaks would land at
# the bottom of Setup. To sit right under Config, the Setup rows Omarchy puts
# after Config (Direct Boot, Reset Computer) are hidden and re-added below it
# as copies, rebuilt from Omarchy's own menu on every run so they keep up with
# updates. Only plain action rows move; a submenu would leave its children
# behind, so one of those stays where it is.
setup_rows_after_config() {
  local defaults="$OMARCHY_PATH/default/omarchy/omarchy-menu.jsonc"
  [[ -f $defaults ]] || return 0
  # The same JSONC clean-up the menu does: drop comment lines, then trailing commas.
  sed '/^[[:space:]]*\/\//d' "$defaults" | perl -0pe 's/,(\s*[}\]])/$1/g' | jq -r '
    [to_entries[] | select(.key | test("^setup\\.[^.]+$"))] as $rows
    | ([$rows[].key] | index("setup.config")) as $at
    | if $at == null then empty else
        $rows[$at + 1:][]
        | select(.value.action != null and .value.action != "")
        | .key as $id
        | "\($id | tojson): {\"when\":\"false\",\"aliases\":[]},",
          "\(("setup.witcher-then-" + ($id | ltrimstr("setup."))) | tojson): \(.value | tojson),"
      end' 2>/dev/null || true
}

# The Setup > Witcher's Tweaks entries live between two marker comments in the
# user's menu extension file, which is otherwise theirs. Rewritten in place
# when they change, so the paths follow the repo.
ensure_menu() {
  command -v omarchy >/dev/null || return 0
  if [[ ! -f $menu_file ]]; then
    mkdir -p "$(dirname "$menu_file")"
    if [[ -f $OMARCHY_PATH/config/omarchy/extensions/omarchy-menu.jsonc ]]; then
      cp "$OMARCHY_PATH/config/omarchy/extensions/omarchy-menu.jsonc" "$menu_file"
    else
      printf '{\n}\n' >"$menu_file"
    fi
  fi

  local block current
  block="$menu_begin"$'\n'"$(menu_block)"$'\n'"$menu_end"
  current=$(sed -n "\|^  $menu_begin\$|,\|^  $menu_end\$|p" "$menu_file" | sed 's/^  //')
  if [[ $current == "$block" ]]; then
    echo "ok       Setup > Witcher's Tweaks in the Omarchy menu"
    return 0
  fi

  local tmp="$menu_file.tmp.$stamp"
  # Drop an old block, then put the new one in before the closing brace.
  # The block goes through the environment: awk -v would eat its backslashes.
  sed "\|^  $menu_begin\$|,\|^  $menu_end\$|d" "$menu_file" | BLOCK="$block" awk '
    { lines[NR] = $0 }
    END {
      last = 0
      for (i = NR; i > 0; i--) if (lines[i] ~ /^[[:space:]]*}[[:space:]]*$/) { last = i; break }
      for (i = 1; i <= NR; i++) {
        if (i == last) { n = split(ENVIRON["BLOCK"], b, "\n"); for (j = 1; j <= n; j++) print "  " b[j] }
        print lines[i]
      }
    }' >"$tmp"
  mv "$tmp" "$menu_file"
  echo "set      Setup > Witcher's Tweaks in the Omarchy menu"
}

remove_menu() {
  if [[ -f $menu_file ]] && grep -qF "$menu_begin" "$menu_file"; then
    sed -i "\|^  $menu_begin\$|,\|^  $menu_end\$|d" "$menu_file"
    echo "removed  Setup > Witcher's Tweaks from the Omarchy menu"
  else
    echo "ok       Setup > Witcher's Tweaks not in the menu"
  fi
}

# ---------------------------------------------------------------- pickers

# Picks modules from a list; prints the chosen names. Nothing preselected
# unless the second argument is "all".
pick_modules() {
  local header="$1" preselect="$2"
  shift 2
  local list=("$@") labels=() name state label
  for name in "${list[@]}"; do
    state=$(module_state "$name")
    label=$(printf '%-14s %s' "$name" "$(field "$(module_line "$name")" 2)")
    [[ $state == partial ]] && label+=" (partly installed)"
    labels+=("$label")
  done

  if command -v gum >/dev/null; then
    local args=(--no-limit --height 20 --header "$header")
    [[ $preselect == all ]] && args+=(--selected '*')
    gum choose "${args[@]}" "${labels[@]}" | while IFS= read -r label; do echo "${label%% *}"; done
  else
    local i answer default=n
    [[ $preselect == all ]] && default=y
    for i in "${!list[@]}"; do
      read -rp "${labels[i]}? [$([[ $default == y ]] && echo Y/n || echo y/N)] " answer </dev/tty
      answer=${answer:-$default}
      [[ $answer =~ ^[Yy] ]] && echo "${list[i]}"
    done
  fi
}

confirm() {
  if command -v gum >/dev/null; then
    gum confirm --default=false "$1"
  else
    local answer
    read -rp "$1 [y/N] " answer </dev/tty
    [[ $answer =~ ^[Yy] ]]
  fi
}

# ---------------------------------------------------------------- main

# Modules this machine can use, in menu order.
names=() labels=()
for m in "${modules[@]}"; do
  available "$m" || continue
  names+=("$(field "$m" 1)")
  labels+=("$(printf '%-14s %s' "$(field "$m" 1)" "$(field "$m" 2)")")
done

check_names() {
  local want
  for want in "$@"; do
    if [[ " ${names[*]} " != *" $want "* ]]; then
      echo "Unknown or unavailable module: $want (see --list)" >&2
      exit 1
    fi
  done
}

need_terminal() {
  if [[ ! -t 0 ]]; then
    echo "No terminal to ask in; pass module names (see --list)." >&2
    exit 1
  fi
}

monitor_setup="$repo/monitors/monitor-setup"
mode=add
selected=()
reload_hypr=false
# The shell runs without a file watcher, so new or changed plugins only load
# after a restart. Set by the steps above when they change something.
restart_shell=false

case "${1:-}" in
  --monitors)
    exec "$monitor_setup"
    ;;
  --list)
    printf '%s\n' "${labels[@]}"
    exit 0
    ;;
  --status)
    for name in "${names[@]}"; do
      printf '%-14s %s\n' "$name" "$(module_state "$name" | sed 's/full/installed/; s/none/-/; s/partial/partly installed/')"
    done
    exit 0
    ;;
  --remove-menu)
    remove_menu
    exit 0
    ;;
  --all)
    selected=("${names[@]}")
    ;;
  "")
    need_terminal
    mapfile -t selected < <(pick_modules "Space toggles, enter applies" all "${names[@]}")
    ;;
  --add)
    shift
    if (( $# )); then
      check_names "$@"
      selected=("$@")
    else
      need_terminal
      candidates=()
      for name in "${names[@]}"; do
        [[ $(module_state "$name") == full ]] || candidates+=("$name")
      done
      if (( ${#candidates[@]} == 0 )); then
        echo "Every tweak is already installed."
        ensure_menu
        exit 0
      fi
      mapfile -t selected < <(pick_modules "Add which tweaks? Space toggles, enter applies" none "${candidates[@]}")
    fi
    ;;
  --remove)
    shift
    mode=remove
    if (( $# )); then
      check_names "$@"
      selected=("$@")
    else
      need_terminal
      candidates=()
      for name in "${names[@]}"; do
        [[ $(module_state "$name") == none ]] || candidates+=("$name")
      done
      if (( ${#candidates[@]} == 0 )); then
        echo "No tweaks are installed."
        exit 0
      fi
      mapfile -t selected < <(pick_modules "Remove which tweaks? Space toggles, enter applies" none "${candidates[@]}")
      if (( ${#selected[@]} )) && ! confirm "Remove ${selected[*]}? Replaced files go back to how they were."; then
        echo "Nothing removed."
        exit 0
      fi
    fi
    ;;
  --configure)
    shift
    mode=configure
    options=()
    for entry in "${configurable[@]}"; do
      owner=$(field "$entry" 4)
      owner=${owner:-$(field "$entry" 1)}
      if module_line "$owner" >/dev/null; then
        [[ $(module_state "$owner") == none ]] || options+=("$entry")
      else
        options+=("$entry")
      fi
    done
    if (( $# )); then
      for entry in "${options[@]}"; do
        [[ $(field "$entry" 1) == "$1" ]] && selected=("$1")
      done
      (( ${#selected[@]} )) || { echo "Nothing to configure for $1 (not installed, or no settings)" >&2; exit 1; }
    else
      need_terminal
      if (( ${#options[@]} == 0 )); then
        echo "Nothing to configure."
        exit 0
      fi
      option_labels=()
      for entry in "${options[@]}"; do
        option_labels+=("$(printf '%-14s %s' "$(field "$entry" 1)" "$(field "$entry" 2)")")
      done
      if command -v gum >/dev/null; then
        choice=$(gum choose --header "Configure which tweak?" "${option_labels[@]}") || true
      else
        select choice in "${option_labels[@]}"; do break; done
      fi
      [[ -n ${choice:-} ]] && selected=("${choice%% *}")
    fi
    ;;
  -*)
    echo "Unknown option: $1 (see the top of install.sh)" >&2
    exit 1
    ;;
  *)
    check_names "$@"
    selected=("$@")
    ;;
esac

if (( ${#selected[@]} == 0 )); then
  echo "Nothing selected."
  ensure_menu
  exit 0
fi

case $mode in
  add) apply_modules "${selected[@]}" ;;
  remove) remove_modules "${selected[@]}" ;;
  configure)
    for entry in "${configurable[@]}"; do
      [[ $(field "$entry" 1) == "${selected[0]}" ]] && "$(field "$entry" 3)"
    done
    ;;
esac

echo "== menu"
ensure_menu

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
# The shell watches the plugins folder and reloads on its own 150 ms after a
# file comes or goes; restarting while that reload is still building plugin
# objects crashes the old process on its way out (a Quickshell teardown race),
# so give it time to settle first.
if $restart_shell && pgrep -f "quickshell -n -p .*omarchy/shell" >/dev/null; then
  sleep 3
  omarchy restart shell >/dev/null
  echo "restarted Omarchy shell"
fi

# Offer the monitor setup at the end of an interactive install, so screens can
# be arranged, rotated and scaled before closing the installer.
if [[ $mode == add && -t 0 && -z ${1:-} && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  if command -v gum >/dev/null; then
    gum confirm --default=false "Set up monitors now? (resolution, scale, rotation, position)" && "$monitor_setup" || true
  else
    read -rp "Set up monitors now? (resolution, scale, rotation, position) [y/N] " answer
    [[ $answer =~ ^[Yy] ]] && "$monitor_setup" || true
  fi
fi
