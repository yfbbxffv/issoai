#!/usr/bin/env bash
# ============================================================
# GameOS Installation Script
# i3-10100F + GTX 1660 Super
# ============================================================
set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[ERR]${NC} $*"; }
log_disk() { echo -e "${CYAN}[DISK]${NC} $*"; }

# Verifica se é root
if [[ $EUID -ne 0 ]]; then
    log_err "Este script deve rodar como root (sudo)"
    exit 1
fi

# Diretório do projeto (usa caminho relativo, não nome da pasta)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

log_info "GameOS Installation Started"
log_info "Project: $PROJECT_DIR"

# ============================================================
# PASSO 1: Verifica hardware
# ============================================================
log_info "Checking hardware..."

CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
GPU_MODEL=$(lspci | grep -i vga | cut -d: -f3- | xargs)
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')

log_info "CPU: $CPU_MODEL"
log_info "GPU: $GPU_MODEL"
log_info "RAM: ${RAM_GB}GB"

if [[ ! "$CPU_MODEL" =~ "i3-10100F" ]]; then
    log_warn "CPU não é i3-10100F. Configuração pode precisar ajustes."
fi

if [[ ! "$GPU_MODEL" =~ "1660" ]]; then
    log_warn "GPU não é GTX 1660 Super. Verifique driver NVIDIA."
fi

# ============================================================
# PASSO 2: Detecta o dispositivo do Live ISO (para excluir)
# ============================================================
log_info "Detecting live ISO device..."

LIVE_ISO_DEVICE=""
# Tenta encontrar o dispositivo de onde o boot foi feito
if [[ -f /proc/cmdline ]]; then
    # Procura por boot=live ou similar
    if grep -q "boot=live" /proc/cmdline; then
        LIVE_ISO_DEVICE=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/\[.*//' | xargs lsblk -no PKNAME 2>/dev/null | head -1)
    fi
fi

# Fallback: verifica /dev/disk/by-label para labels de live ISO
if [[ -z "$LIVE_ISO_DEVICE" ]]; then
    for label in NIXOS_INSTALL NIXOS_LIVE USB_INSTALL; do
        if [[ -b "/dev/disk/by-label/$label" ]]; then
            LIVE_ISO_DEVICE=$(lsblk -no PKNAME "/dev/disk/by-label/$label" 2>/dev/null | head -1)
            break
        fi
    done
fi

if [[ -n "$LIVE_ISO_DEVICE" ]]; then
    LIVE_ISO_DEVICE="/dev/$LIVE_ISO_DEVICE"
    log_warn "Live ISO detectado em: $LIVE_ISO_DEVICE (será excluído da seleção)"
else
    log_warn "Não foi possível detectar o dispositivo do Live ISO automaticamente"
    log_warn "Certifique-se de NÃO selecionar o USB de instalação!"
fi

# ============================================================
# PASSO 3: Lista discos disponíveis com detalhes
# ============================================================
log_info "Available disks:"

# Array para guardar discos válidos
declare -a VALID_DISKS
declare -a DISK_INFO

# Usa lsblk para listar discos (não partições)
while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    model=$(echo "$line" | cut -d' ' -f3- | sed 's/^ *//')

    # Pula loop devices, rom, etc
    if [[ "$name" =~ ^loop|^rom|^sr ]]; then
        continue
    fi

    device="/dev/$name"

    # Pula o dispositivo do Live ISO
    if [[ -n "$LIVE_ISO_DEVICE" && "$device" == "$LIVE_ISO_DEVICE" ]]; then
        log_disk "IGNORADO (Live ISO): $device ($size) - $model"
        continue
    fi

    # Pega serial
    serial=$(udevadm info --query=property --name="$device" 2>/dev/null | grep 'ID_SERIAL=' | cut -d= -f2)

    # Pega by-id paths
    by_id_paths=$(ls -la /dev/disk/by-id/ 2>/dev/null | grep -E " -> \.\./$name$" | awk '{print $9}' | tr '\n' ' ')

    VALID_DISKS+=("$device")
    DISK_INFO+=("$device|$size|$model|$serial|$by_id_paths")

    log_disk "Disco: $device"
    log_disk "  Tamanho: $size"
    log_disk "  Modelo:  $model"
    log_disk "  Serial:  ${serial:-N/A}"
    log_disk "  By-ID:   ${by_id_paths:-N/A}"
    echo

done < <(lsblk -d -n -o NAME,SIZE,MODEL 2>/dev/null)

if [[ ${#VALID_DISKS[@]} -eq 0 ]]; then
    log_err "Nenhum disco disponível encontrado!"
    exit 1
fi

# ============================================================
# PASSO 4: Seleção interativa dos discos
# ============================================================
select_disk() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"

    echo
    log_warn "$prompt"
    echo "Discos disponíveis:"
    for i in "${!VALID_DISKS[@]}"; do
        IFS='|' read -r dev size model serial by_id <<< "${DISK_INFO[$i]}"
        echo "  [$i] $dev ($size) - $model"
    done
    echo

    while true; do
        if [[ -n "$default" ]]; then
            read -p "Escolha o número do disco [$default]: " choice
            choice="${choice:-$default}"
        else
            read -p "Escolha o número do disco: " choice
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 ]] && [[ "$choice" -lt ${#VALID_DISKS[@]} ]]; then
            eval "$var_name=\"${VALID_DISKS[$choice]}\""
            log_ok "Selecionado: ${VALID_DISKS[$choice]}"
            break
        else
            log_err "Opção inválida. Digite um número entre 0 e $((${#VALID_DISKS[@]} - 1))"
        fi
    done
}

select_disk "Selecione o NVMe (sistema ~237GB):" NVME_DISK
select_disk "Selecione o HDD 1 (jogos ~465GB):" HDD1_DISK
select_disk "Selecione o HDD 2 (jogos ~465GB):" HDD2_DISK

# Verifica se são discos diferentes
if [[ "$NVME_DISK" == "$HDD1_DISK" ]] || [[ "$NVME_DISK" == "$HDD2_DISK" ]] || [[ "$HDD1_DISK" == "$HDD2_DISK" ]]; then
    log_err "Os discos devem ser diferentes!"
    exit 1
fi

# ============================================================
# PASSO 5: Converte para /dev/disk/by-id/
# ============================================================
log_info "Converting to /dev/disk/by-id/ paths..."

get_by_id() {
    local device="$1"
    local base=$(basename "$device")
    # Procura o link by-id que aponta para este dispositivo
    ls -la /dev/disk/by-id/ 2>/dev/null | grep -E " -> \.\./$base$" | grep -v part | head -1 | awk '{print $9}'
}

NVME_BY_ID="/dev/disk/by-id/$(get_by_id "$NVME_DISK")"
HDD1_BY_ID="/dev/disk/by-id/$(get_by_id "$HDD1_DISK")"
HDD2_BY_ID="/dev/disk/by-id/$(get_by_id "$HDD2_DISK")"

if [[ -z "$(get_by_id "$NVME_DISK")" ]] || [[ -z "$(get_by_id "$HDD1_DISK")" ]] || [[ -z "$(get_by_id "$HDD2_DISK")" ]]; then
    log_err "Falha ao obter /dev/disk/by-id/ para algum disco"
    log_err "Verifique se os discos têm IDs estáveis: ls -la /dev/disk/by-id/"
    exit 1
fi

log_ok "NVMe by-id: $NVME_BY_ID"
log_ok "HDD1 by-id: $HDD1_BY_ID"
log_ok "HDD2 by-id: $HDD2_BY_ID"

# ============================================================
# PASSO 6: Atualiza disko.nix e MOSTRA o resultado final
# ============================================================
log_info "Updating disko.nix with device IDs..."

# Cria backup
cp ./disko.nix ./disko.nix.backup

# Substitui os device IDs no disko.nix
sed -i "s|/dev/disk/by-id/nvme-SUBSTITUA_PELO_SEU_ID_AQUI|$NVME_BY_ID|g" ./disko.nix
sed -i "0,/ata-SUBSTITUA_PELO_SEU_ID_AQUI/s|/dev/disk/by-id/ata-SUBSTITUA_PELO_SEU_ID_AQUI|$HDD1_BY_ID|" ./disko.nix
sed -i "s|/dev/disk/by-id/ata-SUBSTITUA_PELO_SEU_ID_AQUI|$HDD2_BY_ID|" ./disko.nix

# ============================================================
# PASSO 7: MOSTRA o disko.nix FINAL com IDs já substituídos
# ============================================================
echo
log_warn "=========================================="
log_warn "  disko.nix FINAL (confira antes de continuar)"
log_warn "=========================================="
echo
cat ./disko.nix
echo
log_warn "=========================================="
echo

read -p "O disko.nix acima está correto? Digite 'SIM' para continuar: " CONFIRM_DISKO
if [[ "$CONFIRM_DISKO" != "SIM" ]]; then
    log_info "Instalação cancelada. Backup em disko.nix.backup"
    mv ./disko.nix.backup ./disko.nix
    exit 0
fi

# ============================================================
# PASSO 8: Confirmação final DESTRUTIVA
# ============================================================
echo
log_warn "⚠️  ATENÇÃO: ESTE PROCESSO APAGA TODOS OS DADOS NOS DISCOS:"
echo "  - $NVME_BY_ID (sistema - NVMe)"
echo "  - $HDD1_BY_ID (jogos 1 - HDD)"
echo "  - $HDD2_BY_ID (jogos 2 - HDD)"
echo
read -p "Digite 'SIM' em maiúsculas para CONFIRMAR A EXCLUSÃO DE DADOS: " CONFIRM
if [[ "$CONFIRM" != "SIM" ]]; then
    log_info "Instalação cancelada."
    mv ./disko.nix.backup ./disko.nix
    exit 0
fi

# ============================================================
# PASSO 9: Particiona e formata com disko
# ============================================================
log_info "Running disko (partitioning + formatting)..."

nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
    --mode disko \
    ./disko.nix

log_ok "Disks partitioned and formatted"

# ============================================================
# PASSO 10: Monta sistemas de arquivos
# ============================================================
log_info "Mounting filesystems..."

# Root (subvol @)
mount -o subvol=@,compress=zstd:3,noatime,space_cache=v2,discard=async /dev/disk/by-label/NIXOS /mnt

# Subvolumes
mkdir -p /mnt/{home,nix,var/log,tmp,.snapshots,home/gamer/.cache,boot/efi,games/1,games/2}

mount -o subvol=@home,compress=zstd:3,noatime,space_cache=v2,discard=async /dev/disk/by-label/NIXOS /mnt/home
mount -o subvol=@nix,compress=zstd:3,noatime,space_cache=v2,discard=async /dev/disk/by-label/NIXOS /mnt/nix
mount -o subvol=@log,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/var/log
mount -o subvol=@tmp,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/tmp
mount -o subvol=@snapshots,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/.snapshots
mount -o subvol=@cache,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/home/gamer/.cache

# EFI
mount /dev/disk/by-label/EFI /mnt/boot/efi

# Games HDDs
mount -o compress=zstd:3,noatime,space_cache=v2,autodefrag /dev/disk/by-label/GAMES1 /mnt/games/1
mount -o compress=zstd:3,noatime,space_cache=v2,autodefrag /dev/disk/by-label/GAMES2 /mnt/games/2

log_ok "Filesystems mounted"

# ============================================================
# PASSO 11: Gera hardware-configuration.nix
# ============================================================
log_info "Generating hardware-configuration.nix..."

nixos-generate-config --root /mnt --dir /mnt/etc/nixos/hosts/mypc

# O arquivo gerado será em /mnt/etc/nixos/hosts/mypc/hardware-configuration.nix
# Copia para o repo se quiser versionar
cp /mnt/etc/nixos/hosts/mypc/hardware-configuration.nix ./hosts/mypc/hardware-configuration.nix

log_ok "hardware-configuration.nix generated"

# ============================================================
# PASSO 12: Instala NixOS (flake)
# ============================================================
log_info "Installing NixOS from flake..."

nixos-install --flake .#mypc --no-root-passwd

log_ok "NixOS installed!"

# ============================================================
# PASSO 13: Define senha do usuário gamer
# ============================================================
log_info "Setting password for user 'gamer'..."
echo "Enter password for gamer user:"
nixos-enter --root /mnt -c "passwd gamer"

# ============================================================
# PASSO 14: Finalização
# ============================================================
log_ok "=========================================="
log_ok "  GameOS Installation Complete!"
log_ok "=========================================="
echo
log_info "Next steps:"
echo "  1. Reboot: reboot"
echo "  2. Login as 'gamer' (auto-login no TTY1)"
echo "  3. Gamescope + Steam iniciam automaticamente"
echo "  4. Para Sway fallback: Ctrl+Alt+F2 -> login -> sway --config /etc/sway/config"
echo "  5. Ative módulos extras em configuration.nix:"
echo "     config.gameos.gaming.enableSteam = true;"
echo "     config.gameos.gaming.enableLutris = true;"
echo "     config.gameos.gaming.enableHeroic = true;"
echo "     config.gameos.gaming.enableEmulators = true;"
echo "     config.gameos.hydra.enable = true;"
echo
log_warn "Se Secure Boot estiver ativo na BIOS, desative antes do primeiro boot!"
echo
read -p "Reboot now? (y/N): " REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    reboot
fi