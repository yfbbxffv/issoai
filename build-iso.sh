#!/usr/bin/env bash
# ============================================================
# Build GameOS ISO for testing (VM or USB)
# ============================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "Building GameOS ISO..."

# Requer nixpkgs com nixos-generators
nix build --experimental-features "nix-command flakes" \
    .#nixosConfigurations.mypc.config.system.build.isoImage \
    -o result-iso

if [[ -f result-iso/iso/*.iso ]]; then
    ISO_PATH=$(ls result-iso/iso/*.iso | head -1)
    echo "ISO built: $ISO_PATH"
    echo "Size: $(du -h "$ISO_PATH" | cut -f1)"

    # Copia para local acessível
    cp "$ISO_PATH" ./gameos-$(date +%Y%m%d).iso
    echo "Copied to: ./gameos-$(date +%Y%m%d).iso"
else
    echo "ERROR: ISO not found in result-iso"
    exit 1
fi