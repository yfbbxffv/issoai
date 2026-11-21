{
  description = "GameOS - Custom Gaming OS for i3-10100F + GTX 1660 Super";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      system = "x86_64-linux";

      mypc = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./hosts/mypc/configuration.nix
        ];
      };
    in
    {
      nixosConfigurations = {
        mypc = mypc;
      };

      nixosModules.default = { ... }: { };
    };
}