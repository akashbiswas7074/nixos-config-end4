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
            { config, ... }:
            {
              home.username = "akashbiswas";
              home.homeDirectory = "/home/akashbiswas";
              home.stateVersion = "23.11";
              home.packages = with pkgsx; [
                jq
                fish
                imagemagick
                grim
                cliphist
                fuzzel
                playerctl
                ddcutil
                kdePackages.kconfig
              ];
              home.file.".local/state/quickshell/.venv".source = inirQuickshellPython;
              programs.inir.enable = true;
              programs.niri = {
                enable = true;
                package = niri-flake.packages.x86_64-linux.niri-unstable;
              };
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
          default = pkgs.mkShell {
            packages = [
              pkgs.home-manager
              (pkgs.callPackage ./niri-port/inir-quickshell-python.nix { })
            ];
          };
        }
      );
    };
}
