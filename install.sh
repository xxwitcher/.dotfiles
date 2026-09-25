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
  "looks|Purple rotating window border gradient, no gaps|home/.config/hypr/looknfeel.lua"
  "keyboard|Swap left Ctrl and left Super, touchpad workspace swipe|home/.config/hypr/input.lua"
  "keybindings|SUPER+B browser, SUPER+A agent, CTRL+Q close window|home/.config/hypr/bindings.lua"
  "topbar|Auto-hide the top bar until the cursor hits the top edge|home/.config/topbar/autohide.sh home/.config/hypr/autostart.lua"
  "branding|Catboy braille art for fastfetch and the About screen|home/.config/omarchy/branding/about.txt"
  "fastfetch|Purple fastfetch layout with a Mac-aware OS label|home/.config/fastfetch/config.jsonc"
  "background|Drako desktop background|@background"
  "touchbar|Touch Bar layout and screenshot key (Omarchy-mac)|system/etc/tiny-dfr"
)

field() { cut -d'|' -f"$2" <<<"$1"; }

available() {
  local item
  for item in $(field "$1" 3); do
    case "$item" in
      system/etc/*)
        local app="${item#system/etc/}"
        command -v "$app" >/dev/null || [[ -d "/usr/share/$app" ]] || return 1
        ;;
      @background)
        command -v omarchy >/dev/null || return 1
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
      mapfile -t picked < <(gum choose --no-limit --height 12 \
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
