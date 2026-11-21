#!/usr/bin/env bash
# ============================================================
# Update GameOS (flake inputs + rebuild)
# ============================================================
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Updating GameOS..."

# Atualiza flake inputs (nixpkgs, cachyos, etc)
echo "Updating flake inputs..."
nix flake update

# Rebuild do sistema
echo "Rebuilding system..."
sudo nixos-rebuild switch --flake .#mypc

# Limpa gerações antigas (> 30 dias)
echo "Cleaning old generations..."
sudo nix-collect-garbage --delete-older-than 30d

# Otimiza store
echo "Optimizing store..."
sudo nix store optimise

echo "Update complete!"
echo "Run 'nixos-rebuild list-generations' to see available rollbacks."