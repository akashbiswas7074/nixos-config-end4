#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
VENV_PY="$REPO_DIR/.venv/bin/python"
MODE="${1:-run}"

if [[ ! -x "$VENV_PY" ]]; then
  echo "Missing venv at $VENV_PY"
  echo "Creating venv and installing dependencies..."
  nix shell nixpkgs#python3 --extra-experimental-features "nix-command flakes" --command python3 -m venv "$REPO_DIR/.venv"
  "$VENV_PY" -m pip install --upgrade pip
  "$VENV_PY" -m pip install PySide6 pyusb pexpect
fi

nix shell nixpkgs#gcc nixpkgs#zstd --extra-experimental-features "nix-command flakes" --command bash -lc "
  set -euo pipefail
  cd \"$REPO_DIR\"
  export PATH=\"/run/wrappers/bin:\$PATH\"
  GCC_LIB_DIR=\"\$(dirname \"\$(gcc -print-file-name=libstdc++.so.6)\")\"
  ZSTD_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#zstd.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  ZSTD_LIB_DIR=\"\$ZSTD_OUT_DIR/lib\"
  GLIB_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#glib.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  GLIB_LIB_DIR=\"\$GLIB_OUT_DIR/lib\"
  LIBGL_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libGL --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBGL_LIB_DIR=\"\$LIBGL_OUT_DIR/lib\"
  WAYLAND_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#wayland.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  WAYLAND_LIB_DIR=\"\$WAYLAND_OUT_DIR/lib\"
  LIBXKB_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxkbcommon --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXKB_LIB_DIR=\"\$LIBXKB_OUT_DIR/lib\"
  LIBXCB_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxcb --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCB_LIB_DIR=\"\$LIBXCB_OUT_DIR/lib\"
  LIBX11_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#xorg.libX11.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBX11_LIB_DIR=\"\$LIBX11_OUT_DIR/lib\"
  LIBXEXT_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#xorg.libXext.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXEXT_LIB_DIR=\"\$LIBXEXT_OUT_DIR/lib\"
  LIBXRENDER_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#xorg.libXrender.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXRENDER_LIB_DIR=\"\$LIBXRENDER_OUT_DIR/lib\"
  LIBXCURSOR_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxcursor.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCURSOR_LIB_DIR=\"\$LIBXCURSOR_OUT_DIR/lib\"
  LIBXCB_CURSOR_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#xcb-util-cursor --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCB_CURSOR_LIB_DIR=\"\$LIBXCB_CURSOR_OUT_DIR/lib\"
  LIBXCB_UTIL_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxcb-util --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCB_UTIL_LIB_DIR=\"\$LIBXCB_UTIL_OUT_DIR/lib\"
  LIBXCB_IMAGE_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxcb-image --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCB_IMAGE_LIB_DIR=\"\$LIBXCB_IMAGE_OUT_DIR/lib\"
  LIBXCB_KEYSYMS_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxcb-keysyms --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCB_KEYSYMS_LIB_DIR=\"\$LIBXCB_KEYSYMS_OUT_DIR/lib\"
  LIBXCB_RENDERUTIL_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxcb-render-util --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCB_RENDERUTIL_LIB_DIR=\"\$LIBXCB_RENDERUTIL_OUT_DIR/lib\"
  LIBXCB_WM_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#libxcb-wm --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  LIBXCB_WM_LIB_DIR=\"\$LIBXCB_WM_OUT_DIR/lib\"
  FONTCONFIG_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#fontconfig.lib --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  FONTCONFIG_LIB_DIR=\"\$FONTCONFIG_OUT_DIR/lib\"
  FREETYPE_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#freetype.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  FREETYPE_LIB_DIR=\"\$FREETYPE_OUT_DIR/lib\"
  EXPAT_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#expat.out --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  EXPAT_LIB_DIR=\"\$EXPAT_OUT_DIR/lib\"
  DBUS_OUT_DIR=\"\$(nix build --no-link --print-out-paths nixpkgs#dbus.lib --extra-experimental-features 'nix-command flakes' 2>/dev/null | tail -n 1)\"
  DBUS_LIB_DIR=\"\$DBUS_OUT_DIR/lib\"
  BASE_LIBS=\"\${NIX_LD_LIBRARY_PATH:-}\"
  if [[ -d /run/current-system/sw/lib ]]; then
    BASE_LIBS=\"\${BASE_LIBS:+\$BASE_LIBS:}/run/current-system/sw/lib\"
  fi
  export LD_LIBRARY_PATH=\"\$GCC_LIB_DIR:\$ZSTD_LIB_DIR:\$GLIB_LIB_DIR:\$LIBGL_LIB_DIR:\$WAYLAND_LIB_DIR:\$LIBXKB_LIB_DIR:\$LIBXCB_LIB_DIR:\$LIBX11_LIB_DIR:\$LIBXEXT_LIB_DIR:\$LIBXRENDER_LIB_DIR:\$LIBXCURSOR_LIB_DIR:\$LIBXCB_CURSOR_LIB_DIR:\$LIBXCB_UTIL_LIB_DIR:\$LIBXCB_IMAGE_LIB_DIR:\$LIBXCB_KEYSYMS_LIB_DIR:\$LIBXCB_RENDERUTIL_LIB_DIR:\$LIBXCB_WM_LIB_DIR:\$FONTCONFIG_LIB_DIR:\$FREETYPE_LIB_DIR:\$EXPAT_LIB_DIR:\$DBUS_LIB_DIR\${BASE_LIBS:+:\$BASE_LIBS}\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\"
  if [[ -n \"\${WAYLAND_DISPLAY:-}\" ]]; then
    export QT_QPA_PLATFORM=\"wayland\"
  else
    export QT_QPA_PLATFORM=\"xcb\"
  fi
  export QT_STYLE_OVERRIDE=\"Fusion\"
  if [[ \"$MODE\" == \"check\" ]]; then
    \"$VENV_PY\" -c 'import PySide6, usb, pexpect; print(\"Dell controller runtime OK\")'
  elif [[ \"$MODE\" == \"debug-ldd\" ]]; then
    ldd \"$REPO_DIR/.venv/lib/python3.13/site-packages/PySide6/Qt/plugins/platforms/libqxcb.so\" | awk '/not found/'
  else
    \"$VENV_PY\" main.py
  fi
"
