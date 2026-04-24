#!/usr/bin/env bash
# Install the iNiR template Niri config (includes Mod+F9 -> dell-g-controller-launch) into $HOME.
# Niri only reads ~/.config/niri/config.kdl — editing the git repo copy alone does not change the session.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# niri-port/dots/iNiR/nixos-config/scripts -> repo template at niri-port/dots/iNiR/dots/.config/niri/config.kdl
SRC_KDL="${SCRIPT_DIR}/../../dots/.config/niri/config.kdl"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
DEST_KDL="${DEST_DIR}/config.kdl"

if [[ ! -f "$SRC_KDL" ]]; then
  echo "error: source not found: $SRC_KDL" >&2
  echo "  (run this from the nixos-config tree; path is relative to scripts/)" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

# ~/.config/niri/config.kdl is often a symlink into the Nix store (e.g. Home Manager / generation).
# You cannot overwrite a symlink target in the store: cp would fail with "Read-only file system".
# Back up the resolved file, remove the old path, then write a real file in $HOME.
if [[ -e "$DEST_KDL" ]] || [[ -L "$DEST_KDL" ]]; then
  _bak="${DEST_KDL}.bak.$(date +%Y%m%d%H%M%S)"
  if [[ -L "$DEST_KDL" ]]; then
    echo "Note: $DEST_KDL is a symlink (often HM/nix) — replacing with a normal file; backup: $_bak" >&2
  fi
  cp -L -- "$DEST_KDL" "$_bak" 2>/dev/null || cp -a -- "$DEST_KDL" "$_bak" || true
  rm -f -- "$DEST_KDL"
  echo "Backed up previous config to: $_bak"
fi

if ! cp -a "$SRC_KDL" "$DEST_KDL"; then
  echo "error: could not write $DEST_KDL" >&2
  echo "  If ~/.config/niri is on a read-only or HM-only path, manage config.kdl in home-manager" >&2
  echo "  or: rm -f '$DEST_KDL' && cat '$SRC_KDL' > '$DEST_KDL'" >&2
  exit 1
fi
echo "Installed: $SRC_KDL -> $DEST_KDL"

if command -v niri >/dev/null 2>&1; then
  if niri validate -c "$DEST_KDL" 2>/dev/null; then
    niri msg action load-config-file 2>/dev/null && echo "Reloaded Niri config." || echo "Run when logged into Niri:  niri msg action load-config-file" >&2
  else
    echo "Config failed niri validate — check errors above. Restore from ${DEST_KDL}.bak.* if needed." >&2
    exit 1
  fi
else
  echo "niri not on PATH; start Niri, then:  niri msg action load-config-file"
fi
