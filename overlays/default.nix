{ nixpkgs }:

final: prev: {
  # Sem overlays customizados.
  # Kernel: usa o padrão do NixOS (pkgs.linuxPackages)
  # NVIDIA: usa config.boot.kernelPackages.nvidiaPackages.stable
  # Proton-GE/Wine-GE: usa pacotes padrão do nixpkgs-stable
  # Emuladores: usam pacotes padrão do nixpkgs
}