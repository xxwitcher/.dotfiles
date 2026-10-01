#!/usr/bin/env bash
# Apply or remove the personal dotfiles, module by module. The general
# tweaks (overview, notification bell, borders, keybindings...) live in
# Witcher's Tweaks: https://github.com/xxwitcher/witchers-tweaks
#
#   ./install.sh                     pick modules from a checklist (all preselected)
#   ./install.sh --all               apply every module available on this machine
#   ./install.sh branding fastfetch  apply only the named modules
#   ./install.sh --remove [module...]  take modules back out (asks which, then confirms)
#   ./install.sh --status            show which modules are installed
#   ./install.sh --list              list modules
#
# Files under home/ are symlinked into $HOME; an existing file is moved aside to
# <file>.bak.<timestamp> first, and --remove puts the newest backup back.
# Everything already in place is left alone, so re-running is safe.
#
# Set SUDO=pkexec when running without a terminal for the password prompt.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%s)"
SUDO="${SUDO:-sudo}"

# name | description | items
# Items: home/<path> is symlinked; @<step> is one of the steps below.
modules=(
  "branding|Catboy braille art for fastfetch and the About screen|home/.config/omarchy/branding/about.txt"
  "fastfetch|Purple fastfetch layout with a Mac-aware OS label|home/.config/fastfetch/config.jsonc"
  "background|Drako desktop background|@background"
  "bootscreen|Purple catboy on the disk-unlock and login screens, kept across updates|@bootscreen"
  "capslock|Caps Lock turns on capitals instead of being the compose key|home/.config/hypr/capslock.lua @capslock"
)

field() { cut -d'|' -f"$2" <<<"$1"; }

module_line() {
  local m
  for m in "${modules[@]}"; do
    [[ $(field "$m" 1) == "$1" ]] && { echo "$m"; return 0; }
  done
  return 1
}

available() {
  command -v omarchy >/dev/null || return 1
  [[ $(field "$1" 3) != *@bootscreen* || -d /usr/share/plymouth/themes/omarchy ]]
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
}

home_linked() {
  local rel="${1#home/}"
  [[ -L "$HOME/$rel" && "$(readlink -f "$HOME/$rel")" == "$repo/home/$rel" ]]
}

# The newest <file>.bak.<stamp> that isn't itself a link back into this repo.
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

# Takes the link out and puts back what it replaced, if anything.
unlink_home() {
  local rel="${1#home/}"
  local dest="$HOME/$rel" backup

  if ! home_linked "$1"; then
    echo "ok       ~/$rel (not linked to the dotfiles)"
    return 0
  fi
  rm "$dest"
  if backup=$(newest_backup "$dest"); then
    mv "$backup" "$dest"
    echo "restored ~/$rel from ~/${backup#"$HOME"/}"
  else
    echo "removed  ~/$rel"
  fi
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

# ---------------------------------------------------------------- caps lock

# capslock.lua is loaded by a marked block at the end of the user's
# hyprland.lua, after Omarchy's defaults have set the keyboard options.
hyprland_config="$HOME/.config/hypr/hyprland.lua"
capslock_begin="-- >>> dotfiles capslock (managed by the .dotfiles install.sh)"
capslock_end="-- <<< dotfiles capslock"

# fcitx5 keeps the keymap it started with, so after Hyprland reloads it has to
# restart too, or Caps Lock keeps acting as the compose key until it does.
reload_keymap() {
  hyprctl reload >/dev/null 2>&1 || true
  omarchy restart xcompose >/dev/null 2>&1 || true
}

capslock_loaded() {
  grep -qsxF -e "$capslock_begin" "$hyprland_config"
}

set_capslock() {
  if capslock_loaded; then
    echo "ok       ~/.config/hypr/hyprland.lua loads capslock.lua"
    return
  fi
  printf '\n%s\nrequire("hypr.capslock")\n%s\n' "$capslock_begin" "$capslock_end" >>"$hyprland_config"
  echo "set      ~/.config/hypr/hyprland.lua loads capslock.lua"
  reload_keymap
}

remove_capslock() {
  if ! capslock_loaded; then
    echo "ok       ~/.config/hypr/hyprland.lua (doesn't load capslock.lua)"
    return 0
  fi
  local tmp="$hyprland_config.tmp.$stamp"
  awk -v begin="$capslock_begin" -v end="$capslock_end" '
    $0 == begin { skip = 1; next }
    skip && $0 == end { skip = 0; next }
    !skip { print }' "$hyprland_config" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' >"$tmp"
  mv "$tmp" "$hyprland_config"
  echo "removed  the capslock block from ~/.config/hypr/hyprland.lua"
  reload_keymap
}

# ---------------------------------------------------------------- steps

step() {
  local action="$1" item="$2"
  case "$action:$item" in
    apply:home/*) link_home "$item" ;;
    remove:home/*) unlink_home "$item" ;;
    check:home/*) home_linked "$item" ;;

    apply:@background) set_background ;;
    remove:@background) unset_background ;;
    check:@background) background_set ;;

    apply:@bootscreen) set_bootscreen ;;
    remove:@bootscreen) remove_bootscreen ;;
    check:@bootscreen) bootscreen_installed ;;

    apply:@capslock) set_capslock ;;
    remove:@capslock) remove_capslock ;;
    check:@capslock) capslock_loaded ;;

    *) echo "unknown step: $action $item" >&2; return 1 ;;
  esac
}

module_installed() {
  local m item
  m=$(module_line "$1") || return 1
  for item in $(field "$m" 3); do
    step check "$item" || return 1
  done
}

run_modules() {
  local action="$1" m name item
  shift
  for m in "${modules[@]}"; do
    name="$(field "$m" 1)"
    [[ " $* " == *" $name "* ]] || continue
    echo "== $([[ $action == remove ]] && echo "removing ")$name"
    for item in $(field "$m" 3); do step "$action" "$item"; done
  done
}

# ---------------------------------------------------------------- main

names=() labels=()
for m in "${modules[@]}"; do
  available "$m" || continue
  names+=("$(field "$m" 1)")
  labels+=("$(printf '%-12s %s' "$(field "$m" 1)" "$(field "$m" 2)")")
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

# Checklist of the given modules; prints the chosen names.
pick() {
  local header="$1" preselect="$2"
  shift 2
  local list=("$@") shown=() name i
  for name in "${list[@]}"; do
    for i in "${!names[@]}"; do [[ ${names[i]} == "$name" ]] && shown+=("${labels[i]}"); done
  done
  if command -v gum >/dev/null; then
    local args=(--no-limit --header "$header")
    [[ $preselect == all ]] && args+=(--selected '*')
    gum choose "${args[@]}" "${shown[@]}" | while IFS= read -r label; do echo "${label%% *}"; done
  else
    local answer default=n
    [[ $preselect == all ]] && default=y
    for i in "${!list[@]}"; do
      read -rp "${shown[i]}? [$([[ $default == y ]] && echo Y/n || echo y/N)] " answer </dev/tty
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

action=apply
selected=()
case "${1:-}" in
  --list)
    printf '%s\n' "${labels[@]}"
    exit 0
    ;;
  --status)
    for name in "${names[@]}"; do
      printf '%-12s %s\n' "$name" "$(module_installed "$name" && echo installed || echo -)"
    done
    exit 0
    ;;
  --all)
    selected=("${names[@]}")
    ;;
  --remove)
    shift
    action=remove
    if (( $# )); then
      check_names "$@"
      selected=("$@")
    else
      [[ -t 0 ]] || { echo "No terminal to ask in; pass module names (see --list)." >&2; exit 1; }
      installed=()
      for name in "${names[@]}"; do module_installed "$name" && installed+=("$name"); done
      (( ${#installed[@]} )) || { echo "No modules are installed."; exit 0; }
      mapfile -t selected < <(pick "Remove which? Space toggles, enter applies" none "${installed[@]}")
      if (( ${#selected[@]} )) && ! confirm "Remove ${selected[*]}? Replaced files go back to how they were."; then
        echo "Nothing removed."
        exit 0
      fi
    fi
    ;;
  "")
    [[ -t 0 ]] || { echo "No terminal to ask in; pass --all or module names (see --list)." >&2; exit 1; }
    mapfile -t selected < <(pick "Space toggles, enter applies" all "${names[@]}")
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
  exit 0
fi

run_modules "$action" "${selected[@]}"

if [[ $action == apply && ! -d $HOME/witchers-tweaks ]]; then
  echo
  echo "For the general tweaks (overview, notification bell, borders, keybindings...):"
  echo "  git clone https://github.com/xxwitcher/witchers-tweaks.git ~/witchers-tweaks && ~/witchers-tweaks/install.sh"
fi
