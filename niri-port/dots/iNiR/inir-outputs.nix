# iNiR packages and NixOS / Home-Manager modules (imported from the repo root flake; no per-directory flake).
{ nixpkgs, systems }:
let
  inherit (nixpkgs) lib;
  inirSource = ./.;
  eachSystem = lib.genAttrs (import systems);
in
rec {
  packages = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          awwwCompat = pkgs.symlinkJoin {
            name = "awww-compat";
            paths = [
              (pkgs.writeShellScriptBin "awww" ''
                #!${pkgs.bash}/bin/bash
                set -euo pipefail

                subcmd="''${1:-}"
                shift || true

                case "$subcmd" in
                  img)
                    exec ${pkgs.swww}/bin/swww img "$@"
                    ;;
                  kill)
                    exec ${pkgs.swww}/bin/swww kill "$@"
                    ;;
                  query)
                    exec ${pkgs.swww}/bin/swww query "$@"
                    ;;
                  daemon|"")
                    exec ${pkgs.swww}/bin/swww-daemon "$@"
                    ;;
                  *)
                    echo "awww compatibility wrapper: unsupported subcommand '$subcmd'" >&2
                    echo "Supported: img, kill, query, daemon" >&2
                    exit 1
                    ;;
                esac
              '')
              (pkgs.writeShellScriptBin "awww-daemon" ''
                #!${pkgs.bash}/bin/bash
                set -euo pipefail
                exec ${pkgs.swww}/bin/swww-daemon "$@"
              '')
            ];
          };
        in
        {
          "awww-compat" = awwwCompat;

          default = pkgs.stdenv.mkDerivation {
            pname = "inir-shell";
            version = lib.trim (builtins.readFile ./VERSION);

            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            # runtime dependencies
            buildInputs = [
              pkgs.bash
              pkgs.fish
              pkgs.python3
              pkgs.go
            ];

            dontPatchShebangs = true;

            installPhase = ''
              mkdir -p $out/share/quickshell/inir
              cp -r . $out/share/quickshell/inir/
              # nixos-config/result (and ./result) are local nix-build outputs; do not copy into the store
              # or fixup complains: dangling symlinks to GC'd /nix/store/... paths
              rm -f $out/share/quickshell/inir/result
              rm -f $out/share/quickshell/inir/nixos-config/result

              mkdir -p $out/bin
              makeWrapper $out/share/quickshell/inir/scripts/inir $out/bin/inir \
                --set INIR_SYSTEM_RUNTIME_DIR "$out/share/quickshell/inir" \
                --prefix PATH : ${lib.makeBinPath [
                  pkgs.quickshell
                  pkgs.kdePackages.qttools
                  pkgs.fish
                  pkgs.bc
                  pkgs.coreutils
                  pkgs.cliphist
                  pkgs.curl
                  pkgs.wget
                  pkgs.ripgrep
                  pkgs.jq
                  pkgs.python3
                  pkgs.xdg-user-dirs
                  pkgs.xdg-utils
                  pkgs.rsync
                  pkgs.git
                  pkgs.wl-clipboard
                  pkgs.libnotify
                  pkgs.wlsunset
                  pkgs.networkmanager
                  pkgs.gnome-keyring
                  pkgs.nautilus
                  pkgs.kitty
                  pkgs.foot
                  pkgs.gum
                  pkgs.playerctl
                  pkgs.pavucontrol
                  pkgs.mpv
                  pkgs.yt-dlp
                  pkgs.socat
                  pkgs.cava
                  pkgs.easyeffects
                  pkgs.grim
                  pkgs.slurp
                  pkgs.swappy
                  pkgs.tesseract
                  pkgs.wf-recorder
                  pkgs.imagemagick
                  pkgs.ffmpeg
                  pkgs.upower
                  pkgs.wtype
                  pkgs.ydotool
                  pkgs.brightnessctl
                  pkgs.ddcutil
                  pkgs.geoclue2
                  pkgs.swayidle
                  pkgs.swaylock-effects
                  pkgs.blueman
                  pkgs.fprintd
                  pkgs.libqalculate
                  pkgs.fuzzel
                  pkgs.translate-shell
                  pkgs.hyprpicker
                  awwwCompat
                  pkgs.go
                  pkgs.bash
                ]} \
                --prefix QT_PLUGIN_PATH : "${pkgs.kdePackages.plasma-integration}/lib/qt-6/plugins:${pkgs.kdePackages.qtwayland}/lib/qt-6/plugins:${pkgs.darkly}/lib/qt-6/plugins" \
                --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" [
                  pkgs.kdePackages.kirigami.unwrapped
                  pkgs.kdePackages.syntax-highlighting
                  pkgs.kdePackages.qqc2-desktop-style
                  pkgs.kdePackages.qtwayland
                  pkgs.kdePackages.qtquicktimeline
                  pkgs.kdePackages.qtsensors
                  pkgs.kdePackages.qt5compat
                  pkgs.kdePackages.qtmultimedia
                ]}" \
                --prefix LD_LIBRARY_PATH : "${pkgs.gcc-unwrapped.lib}/lib"
            '';

            meta = with lib; {
              description = "A complete desktop shell for Niri, built on Quickshell";
              homepage = "https://github.com/snowarch/iNiR";
              license = licenses.mit;
              platforms = platforms.linux;
            };
          };
        });

  homeModules.default = { config, lib, pkgs, ... }:
    let
      cfg = config.programs.inir;
      src = inirSource;
          
          # Helper function to recursively find files and create a mapping
          # relative to the 'dots' directory.
          mkLinks = dir: 
            let
              fullPath = "${src}/dots/${dir}";
              files = lib.filesystem.listFilesRecursive fullPath;
              # Remove the prefix up to 'dots/'
              relPath = f: builtins.unsafeDiscardStringContext (lib.removePrefix "${src}/dots/" (toString f));
            in
              lib.listToAttrs (map (f: {
                name = relPath f;
                value = { source = f; };
              }) files);

          configLinks = mkLinks ".config";
          localLinks = mkLinks ".local";
        in
        {
          options.programs.inir = {
            enable = lib.mkEnableOption "iNiR shell";
            package = lib.mkOption {
              type = lib.types.package;
              default = packages.${pkgs.system}.default;
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ 
              cfg.package 
              pkgs.go
              pkgs.hyprpicker
              packages.${pkgs.system}."awww-compat"
              pkgs.uv
              pkgs.starship
              pkgs.eza
              pkgs.quickshell
              pkgs.kdePackages.kdialog
              pkgs.kdePackages.kirigami.unwrapped
              pkgs.kdePackages.plasma-integration
              pkgs.kdePackages.syntax-highlighting
              pkgs.kdePackages.qt5compat
              pkgs.kdePackages.qtmultimedia
              pkgs.polkit_gnome
              pkgs.jetbrains-mono
              pkgs.nerd-fonts.jetbrains-mono
              pkgs.roboto-flex
              pkgs.geist-font
              pkgs.material-symbols
              pkgs.darkly
            ];
            
            fonts.fontconfig.enable = true;
            
            home.file = configLinks // localLinks;
          };
        };

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.inir;
        in
        {
          options.programs.inir = {
            enable = lib.mkEnableOption "system-wide iNiR integration";

            package = lib.mkOption {
              type = lib.types.package;
              default = packages.${pkgs.system}.default;
              description = "iNiR package to install system-wide.";
            };

            enableNiri = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable Niri compositor service.";
            };

            enablePolkit = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable polkit and install a GUI polkit agent.";
            };

            enableBluetooth = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable Bluetooth stack and Blueman integration.";
            };

            dellGSeries = {
              enable = lib.mkEnableOption "Dell G Series controller system requirements";
              usbVendorId = lib.mkOption {
                type = lib.types.str;
                default = "187c";
                description = "USB vendor ID for Dell G controller udev rule.";
              };
              usbProductId = lib.mkOption {
                type = lib.types.str;
                default = "0550";
                description = "USB product ID for Dell G controller udev rule.";
              };
            };
          };

          config = lib.mkIf cfg.enable (lib.mkMerge [
            {
              environment.systemPackages = with pkgs; [
                cfg.package
                go
                hyprpicker
                uv
                starship
                eza
                kdePackages.kdialog
                kdePackages.kirigami.unwrapped
                kdePackages.plasma-integration
                kdePackages.syntax-highlighting
                kdePackages.qtmultimedia
                polkit_gnome
                bluez
                blueman
                zstd
                python313
                python313Packages.pyusb
                python313Packages.pexpect
              ];

              programs.nix-ld.enable = true;
              programs.nix-ld.libraries = with pkgs; [
                stdenv.cc.cc
                zlib
                zstd
              ];
            }

            (lib.mkIf cfg.enableNiri {
              programs.niri.enable = true;
            })

            (lib.mkIf cfg.enablePolkit {
              security.polkit.enable = true;
              # GUI pkexec needs an auth agent (DBus + Wayland). Tie to the graphical session
              # when it exists; also want default.target so Niri/minimal seat setups still pull it in.
              systemd.user.services.polkit-gnome-authentication-agent-1 = {
                description = "Polkit authentication agent (GNOME)";
                partOf = [ "graphical-session.target" ];
                after = [ "graphical-session-pre.target" ];
                wantedBy = [ "graphical-session.target" "default.target" ];
                serviceConfig = {
                  Type = "simple";
                  ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
                  Restart = "on-failure";
                  RestartSec = 3;
                };
              };
            })

            (lib.mkIf cfg.enableBluetooth {
              hardware.bluetooth.enable = true;
              services.blueman.enable = true;
            })

            (lib.mkIf cfg.dellGSeries.enable {
              services.udev.extraRules = ''
                SUBSYSTEM=="usb", ATTRS{idVendor}=="${cfg.dellGSeries.usbVendorId}", ATTRS{idProduct}=="${cfg.dellGSeries.usbProductId}", MODE="0660", TAG+="uaccess", SYMLINK+="awelc"
              '';

              boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];
              boot.kernelModules = [ "acpi_call" ];
            })
          ]);
        };
}
