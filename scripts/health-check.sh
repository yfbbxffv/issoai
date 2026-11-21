#!/usr/bin/env bash
# ============================================================
# GameOS Health Check
# Run periodically or on boot
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

check_cmd() {
    if command -v "$1" &>/dev/null; then
        ok "$1 found"
        return 0
    else
        err "$1 NOT FOUND"
        return 1
    fi
}

check_service() {
    if systemctl is-active --quiet "$1"; then
        ok "Service $1 active"
        return 0
    else
        err "Service $1 INACTIVE"
        return 1
    fi
}

check_user_service() {
    if systemctl --user is-active --quiet "$1"; then
        ok "User service $1 active"
        return 0
    else
        err "User service $1 INACTIVE"
        return 1
    fi
}

echo "=========================================="
echo "  GameOS Health Check"
echo "=========================================="
echo

# Sistema
info "=== System ==="
check_cmd nixos-rebuild
check_cmd nix
check_cmd git

# Kernel
info "=== Kernel ==="
KERNEL=$(uname -r)
echo "Kernel: $KERNEL"
if [[ "$KERNEL" =~ "cachyos" ]] || [[ "$KERNEL" =~ "zen" ]]; then
    ok "Gaming kernel detected"
else
    warn "Not using cachyos/zen kernel"
fi

# NVIDIA
info "=== NVIDIA GPU ==="
check_cmd nvidia-smi
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader
fi
check_service nvidia-persistenced

# Gamescope
info "=== Gamescope ==="
check_user_service gamescope-session

# Hydra
info "=== Hydra Launcher ==="
check_user_service hydra-launcher

# Audio
info "=== Audio ==="
check_service pipewire
check_service wireplumber

# Network
info "=== Network ==="
check_service systemd-networkd
check_service systemd-resolved
ip -brief addr show

# Storage
info "=== Storage ==="
df -h / /home /nix /games/1 /games/2 2>/dev/null | grep -v tmpfs
echo
echo "ZRAM:"
zramctl 2>/dev/null || warn "zram not configured"

# Btrfs
info "=== Btrfs ==="
btrfs filesystem usage / 2>/dev/null | head -20
btrfs filesystem usage /games/1 2>/dev/null | head -10
btrfs filesystem usage /games/2 2>/dev/null | head -10

# Gaming apps
info "=== Gaming Apps ==="
check_cmd steam
check_cmd lutris
check_cmd heroic
check_cmd ryujinx
check_cmd yuzu
check_cmd retroarch
check_cmd gamescope

# Emulators
info "=== Emulators ==="
for emu in dolphin-emu pcsx2 rpcs3 ppsspp citra mupen64plus mgba; do
    check_cmd "$emu"
done

# Cores RetroArch
info "=== RetroArch Cores ==="
ls /run/current-system/sw/lib/libretro/ 2>/dev/null | head -20 || warn "No cores found"

# Systemd
info "=== Failed Units ==="
systemctl --failed --no-legend
systemctl --user --failed --no-legend

echo
echo "=========================================="
echo "  Health Check Complete"
echo "=========================================="