{
  description = "Functional Niri-centric Dotfiles Flake using iNiR";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    niri-flake.url = "github:sodiboo/niri-flake";
    inir.url = "path:./dots/iNiR";
    systems.url = "github:nix-systems/default-linux";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, systems, home-manager, inir, niri-flake, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs (import systems);
      pkgsLinux = nixpkgs.legacyPackages."x86_64-linux";
      inirQuickshellPython = pkgsLinux.callPackage ./inir-quickshell-python.nix { };
    in
    {
      packages."x86_64-linux".inir-quickshell-python = inirQuickshellPython;

      homeConfigurations = {
        akashbiswas = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            niri-flake.homeModules.niri
            inir.homeModules.default
            {
              home.username = "akashbiswas";
              home.homeDirectory = "/home/akashbiswas";
              home.stateVersion = "23.11";
              home.packages = with nixpkgs.legacyPackages."x86_64-linux"; [
                jq
                fish
                imagemagick
                grim
                cliphist
                fuzzel
                playerctl
                ddcutil
                kdePackages.kconfig
                # plasma-integration, qtmultimedia, quickshell, qt5compat: via programs.inir
              ];

              # Declarative Python env for Quickshell / iNiR (sdata/uv/requirements.txt → nixpkgs)
              home.file.".local/state/quickshell/.venv".source = inirQuickshellPython;

              programs.inir = {
                enable = true;
              };

              programs.niri = {
                enable = true;
                package = inputs.niri-flake.packages.x86_64-linux.niri-unstable;
              };
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };
      };

      devShells = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.home-manager
              (pkgs.callPackage ./inir-quickshell-python.nix { })
            ];
          };
        });
    };
}
