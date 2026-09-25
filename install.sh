#!/usr/bin/env bash
# Symlink everything under home/ into $HOME.
#
# Existing files are moved aside to <file>.bak.<timestamp> before linking, and
# links that already point here are left alone, so this is safe to re-run.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%s)"

cd "$repo/home"
find . -type f -print0 | while IFS= read -r -d '' file; do
  rel="${file#./}"
  src="$repo/home/$rel"
  dest="$HOME/$rel"

  if [[ "$(readlink -f "$dest" 2>/dev/null)" == "$src" ]]; then
    echo "ok       ~/$rel"
    continue
  fi

  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "$dest.bak.$stamp"
    echo "backup   ~/$rel -> ~/$rel.bak.$stamp"
  fi

  ln -s "$src" "$dest"
  echo "linked   ~/$rel"
done

# System files under system/ are copied (not symlinked, so root daemons never
# read from $HOME) to the same path under /. Each system/etc/<app>/ directory is
# only installed when <app> is present, so hardware-specific config (e.g. the
# Mac touch bar's tiny-dfr) is skipped on machines that don't have it.
# Set SUDO=pkexec when running without a terminal for the password prompt.
SUDO="${SUDO:-sudo}"

for appdir in "$repo"/system/etc/*/; do
  [[ -d "$appdir" ]] || continue
  app="$(basename "$appdir")"

  if ! command -v "$app" >/dev/null && [[ ! -d "/usr/share/$app" ]]; then
    echo "skip     /etc/$app ($app not installed)"
    continue
  fi

  # Collect changed files so each app needs a single privileged call.
  pending=()
  while IFS= read -r -d '' src; do
    dest="/${src#"$repo"/system/}"
    if cmp -s "$src" "$dest"; then
      echo "ok       $dest"
    else
      pending+=("$src" "$dest")
    fi
  done < <(find "$appdir" -type f -print0)
  (( ${#pending[@]} )) || continue

  service=""
  systemctl cat "$app.service" >/dev/null 2>&1 && service="$app.service"

  $SUDO bash -c '
    service="$1"; shift
    while (( $# )); do install -D -m 644 "$1" "$2"; shift 2; done
    [[ -z "$service" ]] || systemctl restart "$service"
  ' _ "$service" "${pending[@]}"

  for (( i = 1; i < ${#pending[@]}; i += 2 )); do echo "copied   ${pending[i]}"; done
  [[ -z "$service" ]] || echo "restarted $service"
done

# Apply and validate the Hyprland config when running inside a Hyprland session.
if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
  hyprctl reload >/dev/null
  errors="$(hyprctl configerrors)"
  if [[ -n "${errors//[[:space:]]/}" ]]; then
    echo "Hyprland config errors:" >&2
    echo "$errors" >&2
    exit 1
  fi
  echo "Hyprland reloaded"
fi
