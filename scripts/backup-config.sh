#!/usr/bin/env bash
# ============================================================
# Backup GameOS configuration to git
# ============================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "Backing up GameOS configuration..."

# Hardware config (se mudou)
if [[ -f /etc/nixos/hardware-configuration.nix ]]; then
    cp /etc/nixos/hardware-configuration.nix ./hosts/mypc/hardware-configuration.nix
    echo "Copied hardware-configuration.nix"
fi

# Sistema de arquivos Btrfs - snapshot
echo "Creating Btrfs snapshots..."
sudo btrfs subvolume snapshot -r / /.snapshots/backup-$(date +%Y%m%d-%H%M%S)
sudo btrfs subvolume snapshot -r /home /home/.snapshots/backup-$(date +%Y%m%d-%H%M%S)

# Git commit
if git diff --quiet && git diff --cached --quiet; then
    echo "No changes to commit"
else
    git add -A
    git commit -m "chore: backup config $(date +%Y-%m-%d_%H:%M)"
    echo "Committed changes"
fi

echo "Backup complete!"