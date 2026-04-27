{
  description = "Unified NixOS + iNiR + optional Home Manager (single entrypoint for this repo)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri-flake.url = "github:sodiboo/niri-flake";
  };

  outputs = { self, nixpkgs, home-manager, systems, niri-flake, ... }@inputs:
    let
      eachSystem = nixpkgs.lib.genAttrs (import systems);
      pkgsx = nixpkgs.legacyPackages."x86_64-linux";
      inirQuickshellPython = pkgsx.callPackage ./niri-port/inir-quickshell-python.nix { };
      inir = import ./niri-port/dots/iNiR/inir-outputs.nix { inherit nixpkgs systems; };
    in
    {
      # Exposed for `getFlake <repo>`.lib.inir (e.g. configuration.nix without specialArgs)
      lib = nixpkgs.lib // { inherit inir; };

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inirFlake = inir; };
        modules = [
          ./niri-port/dots/iNiR/nixos-config/configuration.nix
          { nixpkgs.hostPlatform = "x86_64-linux"; }
        ];
      };

      # Optional: `home-manager switch --flake <this-repo>#akashbiswas`
      homeConfigurations.akashbiswas = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsx;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          niri-flake.homeModules.niri
          inir.homeModules.default
          (
            { config, lib, pkgs, ... }:
            {
              home.username = "akashbiswas";
              home.homeDirectory = "/home/akashbiswas";
              home.stateVersion = "23.11";
              # If activation fails on “would be clobbered”, run once:
              #   home-manager switch -b backup --flake "<this-repo>#akashbiswas"
              # (This HM revision has no home.backupFileExtension; use -b backup when needed.)
              # NixOS setuid binaries (sudo, etc.) live in /run/wrappers/bin and must come first.
              # Apply shell path ordering globally (fish/bash/zsh) without taking ownership of fish config.
              home.sessionPath = [
                "/run/wrappers/bin"
                "${config.home.homeDirectory}/.nix-profile/bin"
                "/run/current-system/sw/bin"
                "/etc/profiles/per-user/${config.home.username}/bin"
              ];
              home.packages = with pkgsx; [
                jq
                fish
                ntfs3g
                neovim
                lazygit
                nodejs
                gdu
                bottom
                cargo
                lua51Packages.luarocks
                luajit
                ruby
                php
                phpPackages.composer
                jdk
                julia
                fd
                sqlite
                ghostscript
                tectonic
                mermaid-cli
                gcc
                gnumake
                unzip
                tree-sitter
                micromamba
                (python3.withPackages (ps: with ps; [ pynvim jupyter-client ipykernel nbformat pyperclip plotly cairosvg pnglatex kaleido pip setuptools ]))
                imagemagick
                grim
                cliphist
                fuzzel
                playerctl
                ddcutil
                brightnessctl
                wlsunset
                kdePackages.kconfig
                # Conda-compatible env manager (use instead of the Anaconda .sh installer on NixOS)
                micromamba
              ];
              # niri-portals.conf is already installed by programs.inir (home.file from dots/.config).
              # Do not manage ~/.local/state/quickshell/.venv here: iNiR ./setup uses `uv` and creates a real
              # directory; HM would try to replace it with a single symlink (cmp fails, activation aborts).
              #
              # These often differ after matugen / KDE apps run locally; allow HM to replace with dots.
              home.file.".config/kdeglobals".force = true;
              home.file.".config/matugen/config.toml".force = true;
              home.file.".config/matugen/templates.json".force = true;
              home.file.".config/matugen/templates/terminals/foot.ini".force = true;

              # Link AstroNvim configuration from dotfiles
              home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Desktop/control/nixos-config-end4/AstroNvim";

              # ~/.local/bin/inir is the raw script (no Nix PATH); systemd then fails with "qs not found".
              # Use the HM-installed wrapped binary (same as `inir` from programs.inir).
              home.file.".config/systemd/user/inir.service.d/60-nixos-wrapped-inir.conf".text = ''
                [Service]
                Environment=PATH=/run/wrappers/bin:/run/current-system/sw/bin:%h/.nix-profile/bin:/etc/profiles/per-user/%u/bin
                ExecStart=
                ExecStart=%h/.nix-profile/bin/inir run --session
                ExecStopPost=
                ExecStopPost=-%h/.nix-profile/bin/inir cleanup-orphans
              '';
              # Some terminals (notably IDE-integrated ones) set no_new_privs=1 on child processes.
              # Explicitly disable this for the user service so privileged helpers can still function.
              home.file.".config/systemd/user/inir.service.d/61-no-new-privileges.conf".text = ''
                [Service]
                NoNewPrivileges=false
              '';

              programs.inir = {
                enable = true;
                # Replace plain files with store symlinks (not only when content differs).
                homeFileForce = true;
              };
              programs.niri = {
                enable = true;
                package = niri-flake.packages.x86_64-linux.niri-unstable;
              };

              # reloadSystemd restarts inir and can leave start-limit-hit / failed; recover when in a session.
              home.activation.fixInirAfterSystemd = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
                _ctl="${pkgs.systemd}/bin/systemctl"
                if [[ -x "$_ctl" ]]; then
                  $DRY_RUN_CMD "$_ctl" --user reset-failed inir.service 2>/dev/null || true
                  if "$_ctl" --user is-active graphical-session.target &>/dev/null \
                     || "$_ctl" --user is-active niri.service &>/dev/null; then
                    $DRY_RUN_CMD "$_ctl" --user start inir.service 2>/dev/null || true
                  fi
                fi
              '';
            }
          )
        ];
      };

      packages = eachSystem (system:
        let
          p = nixpkgs.legacyPackages.${system};
        in
        (inir.packages.${system} or { }) // {
          inir-quickshell-python = p.callPackage ./niri-port/inir-quickshell-python.nix { };
        }
      );

      devShells = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # NixOS: /run/current-system/sw/bin/sudo is a non-setuid store symlink; the setuid binary is
          # /run/wrappers/bin/sudo. If PATH has sw/bin before wrappers, `sudo` fails. Prepend wrappers.
          default = pkgs.mkShell {
            packages = [
              pkgs.home-manager
              pkgs.gcc
              pkgs.gnumake
              pkgs.sqlite
              pkgs.micromamba
              (pkgs.callPackage ./niri-port/inir-quickshell-python.nix { })
            ];
            shellHook = ''
              if [ -d /run/wrappers/bin ]; then
                export PATH="/run/wrappers/bin''${PATH:+:}$PATH"
              fi
            '';
          };
          # Micromamba + tools to sanity-check from a terminal. Brightness / game mode / night light
          # are still driven by Niri + iNiR (Quickshell) in your graphical session — not by this hook.
          conda = pkgs.mkShell {
            name = "micromamba-conda";
            packages = [
              pkgs.micromamba
              (inir.packages.${system}.default)
              pkgs.brightnessctl
              pkgs.wlsunset
            ];
            shellHook = ''
              if [ -d /run/wrappers/bin ]; then
                export PATH="/run/wrappers/bin''${PATH:+:}$PATH"
              fi
              export MAMBA_ROOT_PREFIX="''${MAMBA_ROOT_PREFIX:-$HOME/micromamba}"
              echo "Micromamba: MAMBA_ROOT_PREFIX=$MAMBA_ROOT_PREFIX"
              echo "iNiR desktop features (OSD, gamemode, night light) need Niri + inir run; this is only a dev shell."
            '';
          };
        }
      );
    };
}
