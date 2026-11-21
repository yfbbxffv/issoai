{
  description = "GameOS - Custom Gaming OS for i3-10100F + GTX 1660 Super";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    cachyos.url = "github:cachyos/cachyos-nixpkgs";
    disko.url = "github:nix-community/disko";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    # Hydra launcher (local)
    hydra-launcher.url = "path:./hydra-launcher";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, cachyos, disko, rust-overlay, flake-utils, hydra-launcher, ... }:
    let
      system = "x86_64-linux";

      # Configuração do host com disko
      mypc = nixpkgs-stable.lib.nixosSystem {
        inherit system;
        modules = [
          # Disko para particionamento
          disko.nixosModules.disko

          # Módulos base
          ./modules/kernel.nix
          ./modules/boot.nix
          ./modules/users.nix
          ./modules/graphics.nix
          ./modules/gaming.nix
          ./modules/hydra.nix
          ./modules/storage.nix
          ./modules/network.nix
          ./modules/performance.nix

          # Host-specific
          ./hosts/mypc/configuration.nix
        ];
      };
    in
    {
      nixosConfigurations = {
        mypc = mypc;
      };

      # Pacotes expostos (inclui hydra-launcher)
      packages = {
        x86_64-linux = {
          hydra-launcher = hydra-launcher.packages.${system}.hydra-launcher;
        };
      };

      # Dev shell para desenvolvimento do Hydra
      devShells = {
        x86_64-linux = {
          default = hydra-launcher.devShells.${system}.default;
          hydra = hydra-launcher.devShells.${system}.default;
        };
      };

      # NixOS modules
      nixosModules.default = { ... }: { };

      # Formatter
      formatter = nixpkgs-stable.legacyPackages.${system}.alejandra;
    };
}