#!/usr/bin/env bash
# ============================================================
# Build and run GameOS VM for testing
# ============================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "Building GameOS VM..."

# Verifica se estamos no NixOS ou tem nix disponível
if ! command -v nix &> /dev/null; then
    echo "ERROR: nix command not found. Install Nix first."
    exit 1
fi

nix build --experimental-features "nix-command flakes" \
    .#nixosConfigurations.mypc.config.system.build.vm \
    -o result-vm

if [[ -f result-vm/bin/run-*-vm ]]; then
    VM_SCRIPT=$(ls result-vm/bin/run-*-vm | head -1)
    echo "VM script: $VM_SCRIPT"
    echo "Starting VM (KVM required)..."

    # Adiciona flags para GPU passthrough se quiser testar NVIDIA
    # -device vfio-pci,host=01:00.0,multifunction=on \
    # -device vfio-pci,host=01:00.1 \

    exec "$VM_SCRIPT" \
        -m 8G \
        -smp 4 \
        -cpu host \
        -enable-kvm \
        -display gtk,gl=on \
        -device virtio-gpu-pci \
        -device virtio-keyboard-pci \
        -device virtio-mouse-pci \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0
else
    echo "ERROR: VM script not found"
    exit 1
fi