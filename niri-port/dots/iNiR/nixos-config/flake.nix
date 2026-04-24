{
  description = "NixOS system configuration (use this directory as /etc/nixos)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    inir.url = "path:..";
    inir.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, inir, ... }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inirFlake = inir; };
        modules = [ ./configuration.nix ];
      };
    };
}
