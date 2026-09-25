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
