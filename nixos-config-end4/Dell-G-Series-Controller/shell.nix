# Nix-native Python + PySide6 (avoids pip wheels + LD_LIBRARY_PATH clashes that segfault on NixOS).
{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  packages = [
    (pkgs.python313.withPackages (ps: with ps; [
      pyside6
      pyusb
      pexpect
    ]))
  ];

  shellHook = ''
    export PATH="/run/wrappers/bin:$PATH"
    if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
      export QT_QPA_PLATFORM="wayland"
    else
      export QT_QPA_PLATFORM="xcb"
    fi
    export QT_STYLE_OVERRIDE="Fusion"
  '';
}
