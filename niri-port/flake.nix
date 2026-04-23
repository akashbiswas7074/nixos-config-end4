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
    in
    {
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

              programs.inir = {
                enable = true;
              };

              programs.niri = {
                enable = true;
              };
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };
      };

      devShells = eachSystem (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          buildInputs = [
            nixpkgs.legacyPackages.${system}.home-manager
          ];
        };
      });
    };
}
