{
  description = "iNiR: A complete desktop shell for Niri, built on Quickshell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";
  };

  outputs = { self, nixpkgs, systems }:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          awwwCompat = pkgs.symlinkJoin {
            name = "awww-compat";
            paths = [
              (pkgs.writeShellScriptBin "awww" ''
                #!${pkgs.bash}/bin/bash
                set -euo pipefail

                subcmd="${1:-}"
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
          src = self;
          
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
              default = self.packages.${pkgs.system}.default;
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ 
              cfg.package 
              pkgs.go
              pkgs.hyprpicker
              self.packages.${pkgs.system}."awww-compat"
              pkgs.swww
              pkgs.uv
              pkgs.starship
              pkgs.eza
              pkgs.kdePackages.kdialog
              pkgs.kdePackages.kirigami.unwrapped
              pkgs.kdePackages.plasma-integration
              pkgs.kdePackages.syntax-highlighting
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
    };
}
