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

# Diretório do projeto
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

log_info "GameOS Installation Started"
log_info "Project: $PROJECT_DIR"

# ============================================================
# PASSO 0: Valida flake ANTES de qualquer comando destrutivo
# ============================================================
log_info "Validating flake configuration..."

if ! command -v nix &> /dev/null; then
    log_err "nix command not found. Install Nix first."
    exit 1
fi

# git safe directory
git config --global --add safe.directory "$PROJECT_DIR" 2>/dev/null || true

# Check flake syntax
if ! nix --extra-experimental-features "nix-command flakes" flake check --no-build 2>&1; then
    log_err "Flake check failed! Aborting."
    exit 1
fi
log_ok "Flake syntax OK"

# Eval toplevel drvPath to verify config builds
log_info "Evaluating toplevel derivation..."
if ! nix --extra-experimental-features "nix-command flakes" eval --raw .#nixosConfigurations.mypc.config.system.build.toplevel.drvPath 2>&1; then
    log_err "Toplevel evaluation failed! Aborting."
    exit 1
fi
log_ok "Toplevel evaluates successfully"

# ============================================================
# PASSO 1: Verifica hardware
# ============================================================
log_info "Checking hardware..."

CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs || true)
GPU_MODEL=$(lspci | grep -i vga | cut -d: -f3- | xargs || true)
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
# PASSO 2: Detecta o dispositivo do Live ISO (NixOS: /iso)
# ============================================================
log_info "Detecting live ISO device..."

LIVE_ISO_DEVICE=""
# NixOS live ISO monta em /iso
if [[ -d "/iso" ]]; then
    ISO_SOURCE=$(findmnt -n -o SOURCE /iso 2>/dev/null | head -1)
    if [[ -n "$ISO_SOURCE" ]]; then
        LIVE_ISO_DEVICE=$(lsblk -no PKNAME "$ISO_SOURCE" 2>/dev/null | head -1)
        if [[ -n "$LIVE_ISO_DEVICE" ]]; then
            LIVE_ISO_DEVICE="/dev/$LIVE_ISO_DEVICE"
            log_warn "Live ISO detectado em: $LIVE_ISO_DEVICE (será excluído da seleção)"
        fi
    fi
fi

# Fallback: verifica se /boot/efi está no USB
if [[ -z "$LIVE_ISO_DEVICE" ]]; then
    EFI_SOURCE=$(findmnt -n -o SOURCE /boot/efi 2>/dev/null | head -1)
    if [[ -n "$EFI_SOURCE" ]]; then
        LIVE_ISO_DEVICE=$(lsblk -no PKNAME "$EFI_SOURCE" 2>/dev/null | head -1)
        if [[ -n "$LIVE_ISO_DEVICE" ]]; then
            LIVE_ISO_DEVICE="/dev/$LIVE_ISO_DEVICE"
            log_warn "Live ISO (via EFI) detectado em: $LIVE_ISO_DEVICE"
        fi
    fi
fi

if [[ -z "$LIVE_ISO_DEVICE" ]]; then
    log_warn "Não foi possível detectar o dispositivo do Live ISO automaticamente"
    log_warn "Certifique-se de NÃO selecionar o USB de instalação!"
fi

# ============================================================
# PASSO 3: Lista discos disponíveis com validação (bytes)
# ============================================================
log_info "Scanning disks..."

declare -a VALID_DISKS
declare -a DISK_INFO

while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    size_bytes=$(echo "$line" | awk '{print $2}')
    rota=$(echo "$line" | awk '{print $3}')
    rm_flag=$(echo "$line" | awk '{print $4}')
    model=$(echo "$line" | cut -d' ' -f5- | sed 's/^ *//')

    # Pula loop, rom, etc
    if [[ "$name" =~ ^loop|^rom|^sr ]]; then
        continue
    fi

    device="/dev/$name"

    # Pula o dispositivo do Live ISO
    if [[ -n "$LIVE_ISO_DEVICE" && "$device" == "$LIVE_ISO_DEVICE" ]]; then
        log_disk "IGNORADO (Live ISO): $device ($size_bytes bytes) - $model"
        continue
    fi

    # Pula removíveis (RM=1)
    if [[ "$rm_flag" == "1" ]]; then
        log_disk "IGNORADO (Removível): $device ($size_bytes bytes) - $model"
        continue
    fi

    # Pega serial
    serial=$(udevadm info --query=property --name="$device" 2>/dev/null | grep 'ID_SERIAL=' | cut -d= -f2)

    # Pega by-id paths
    by_id_paths=$(ls -la /dev/disk/by-id/ 2>/dev/null | grep -E " -> \.\./$name$" | grep -v part | awk '{print $9}' | tr '\n' ' ')

    VALID_DISKS+=("$device")
    DISK_INFO+=("$device|$size_bytes|$model|$serial|$by_id_paths|$rota")

    log_disk "Disco: $device"
    log_disk "  Tamanho: $size_bytes bytes"
    log_disk "  Modelo:  $model"
    log_disk "  Serial:  ${serial:-N/A}"
    log_disk "  By-ID:   ${by_id_paths:-N/A}"
    log_disk "  Rotacional: $rota"
    echo

done < <(lsblk -b -d -n -o NAME,SIZE,ROTA,RM,MODEL 2>/dev/null)

if [[ ${#VALID_DISKS[@]} -eq 0 ]]; then
    log_err "Nenhum disco válido encontrado!"
    exit 1
fi

# ============================================================
# PASSO 4: Seleção interativa com validação de tipo
# ============================================================
select_disk() {
    local prompt="$1"
    local var_name="$2"
    local require_rota="$3"  # 1=HDD rotacional, 0=NVMe
    local size_min_bytes="$4"       # bytes mínimo
    local size_max_bytes="$5"       # bytes máximo

    echo
    log_warn "$prompt"
    echo "Discos disponíveis:"
    for i in "${!VALID_DISKS[@]}"; do
        IFS='|' read -r dev size_bytes model serial by_id rota <<< "${DISK_INFO[$i]}"
        size_gb=$((size_bytes / 1024 / 1024 / 1024))

        # Validações
        local ok="✓"
        local reasons=()
        if [[ "$require_rota" == "1" && "$rota" != "1" ]]; then
            ok="✗"
            reasons+=("não é HDD rotacional")
        fi
        if [[ "$require_rota" == "0" && "$rota" == "1" ]]; then
            ok="✗"
            reasons+=("não é NVMe/SSD")
        fi
        if [[ -n "$size_min_bytes" && $size_bytes -lt $size_min_bytes ]]; then
            ok="✗"
            reasons+=("menor que $((size_min_bytes / 1024 / 1024 / 1024))GB")
        fi
        if [[ -n "$size_max_bytes" && $size_bytes -gt $size_max_bytes ]]; then
            ok="✗"
            reasons+=("maior que $((size_max_bytes / 1024 / 1024 / 1024))GB")
        fi

        echo "  [$i] $ok $dev ($size_gb GB) - $model [ROTA=$rota RM=0]"
        if [[ ${#reasons[@]} -gt 0 ]]; then
            echo "      Aviso: $(IFS=,; echo "${reasons[*]}")"
        fi
    done
    echo

    while true; do
        read -p "Escolha o número do disco: " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 0 ]] && [[ "$choice" -lt ${#VALID_DISKS[@]} ]]; then
            IFS='|' read -r dev size_bytes model serial by_id rota <<< "${DISK_INFO[$choice]}"
            size_gb=$((size_bytes / 1024 / 1024 / 1024))

            # Re-valida na seleção
            if [[ "$require_rota" == "1" && "$rota" != "1" ]]; then
                log_err "Disco deve ser HDD rotacional (ROTA=1)"
                continue
            fi
            if [[ "$require_rota" == "0" && "$rota" == "1" ]]; then
                log_err "Disco deve ser NVMe/SSD (ROTA=0)"
                continue
            fi
            if [[ -n "$size_min_bytes" && $size_bytes -lt $size_min_bytes ]]; then
                log_err "Disco deve ter pelo menos $((size_min_bytes / 1024 / 1024 / 1024))GB"
                continue
            fi
            if [[ -n "$size_max_bytes" && $size_bytes -gt $size_max_bytes ]]; then
                log_err "Disco deve ter no máximo $((size_max_bytes / 1024 / 1024 / 1024))GB"
                continue
            fi

            eval "$var_name=\"$dev\""
            log_ok "Selecionado: $dev ($size_gb GB) - $model"
            break
        else
            log_err "Opção inválida. Digite um número entre 0 e $((${#VALID_DISKS[@]} - 1))"
        fi
    done
}

# NVMe: não rotacional, ~237GB (aceita 200-300GB)
NVME_MIN=$((200 * 1024 * 1024 * 1024))
NVME_MAX=$((300 * 1024 * 1024 * 1024))
select_disk "Selecione o NVMe (sistema ~237GB):" NVME_DISK 0 "$NVME_MIN" "$NVME_MAX"

# HDD1: rotacional, 400-500GB
HDD_MIN=$((400 * 1024 * 1024 * 1024))
HDD_MAX=$((500 * 1024 * 1024 * 1024))
select_disk "Selecione o HDD 1 (jogos ~465GB):" HDD1_DISK 1 "$HDD_MIN" "$HDD_MAX"

# HDD2: rotacional, 400-500GB
select_disk "Selecione o HDD 2 (jogos ~465GB):" HDD2_DISK 1 "$HDD_MIN" "$HDD_MAX"

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
    ls -la /dev/disk/by-id/ 2>/dev/null | grep -E " -> \.\./$base$" | grep -v part | head -1 | awk '{print $9}'
}

NVME_BY_ID="/dev/disk/by-id/$(get_by_id "$NVME_DISK")"
HDD1_BY_ID="/dev/disk/by-id/$(get_by_id "$HDD1_DISK")"
HDD2_BY_ID="/dev/disk/by-id/$(get_by_id "$HDD2_DISK")"

if [[ -z "$(get_by_id "$NVME_DISK")" ]] || [[ -z "$(get_by_id "$HDD1_DISK")" ]] || [[ -z "$(get_by_id "$HDD2_DISK")" ]]; then
    log_err "Falha ao obter /dev/disk/by-id/ para algum disco"
    log_err "Verifique: ls -la /dev/disk/by-id/"
    exit 1
fi

log_ok "NVMe by-id: $NVME_BY_ID"
log_ok "HDD1 by-id: $HDD1_BY_ID"
log_ok "HDD2 by-id: $HDD2_BY_ID"

# ============================================================
# PASSO 6: Atualiza disko.nix e MOSTRA o resultado final
# ============================================================
log_info "Updating disko.nix with device IDs..."

cp ./disko.nix ./disko.nix.backup

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
# PASSO 8: Gera hardware-configuration.nix ANTES das confirmações destrutivas
# ============================================================
log_info "Generating hardware-configuration.nix..."
nixos-generate-config --no-filesystems --show-hardware-config > ./hosts/mypc/hardware-configuration.nix
log_ok "hardware-configuration.nix generated"

# ============================================================
# PASSO 9: git add ANTES do nixos-install
# ============================================================
log_info "Staging generated files..."
git add -A

# ============================================================
# PASSO 10: Re-eval toplevel.drvPath APÓS hardware-configuration.nix
# ============================================================
log_info "Re-evaluating toplevel derivation after hardware config..."
if ! nix --extra-experimental-features "nix-command flakes" eval --raw .#nixosConfigurations.mypc.config.system.build.toplevel.drvPath 2>&1; then
    log_err "Toplevel evaluation failed after hardware config! Aborting."
    mv ./disko.nix.backup ./disko.nix
    exit 1
fi
log_ok "Toplevel evaluates successfully with hardware config"

# ============================================================
# PASSO 11: Build diskoScript do flake ANTES das confirmações
# ============================================================
log_info "Building diskoScript from flake..."
DISKO_SCRIPT=$(nix --extra-experimental-features "nix-command flakes" \
    build .#nixosConfigurations.mypc.config.system.build.diskoScript \
    --no-link --print-out-paths 2>&1)
log_ok "diskoScript built: $DISKO_SCRIPT"

# ============================================================
# PASSO 12: Confirmação final DESTRUTIVA
# ============================================================
echo
log_warn "⚠️  ATENÇÃO: ESTE PROCESSO APAGA TODOS OS DADOS NOS DISCOS:"
echo "  - $NVME_BY_ID (sistema - NVMe ~237GB)"
echo "  - $HDD1_BY_ID (jogos 1 - HDD ~465GB)"
echo "  - $HDD2_BY_ID (jogos 2 - HDD ~465GB)"
echo
read -p "Digite 'SIM' em maiúsculas para CONFIRMAR A EXCLUSÃO DE DADOS: " CONFIRM
if [[ "$CONFIRM" != "SIM" ]]; then
    log_info "Instalação cancelada."
    mv ./disko.nix.backup ./disko.nix
    exit 0
fi

# ============================================================
# PASSO 13: Particiona, formata e monta com disko (--mode destroy,format,mount)
# ============================================================
log_info "Running disko (destroy, format, mount)..."
"$DISKO_SCRIPT" --mode destroy,format,mount ./disko.nix

log_ok "Disks partitioned, formatted and mounted by disko"

# ============================================================
# PASSO 14: Instala NixOS (flake)
# ============================================================
log_info "Installing NixOS from flake..."
nixos-install --flake .#mypc --no-root-passwd

log_ok "NixOS installed!"

# ============================================================
# PASSO 15: Define senha do usuário gamer
# ============================================================
log_info "Setting password for user 'gamer'..."
echo "Enter password for gamer user:"
nixos-enter --root /mnt -c "passwd gamer"

# ============================================================
# PASSO 16: Copia repositório para o sistema novo
# ============================================================
log_info "Copying repository to new system..."
mkdir -p /mnt/home/gamer
cp -a "$PROJECT_DIR" /mnt/home/gamer/issoai
nixos-enter --root /mnt -c "chown -R gamer: /home/gamer"
log_ok "Repository copied to /home/gamer/issoai"

# ============================================================
# PASSO 17: Finalização
# ============================================================
log_ok "=========================================="
log_ok "  GameOS Installation Complete!"
log_ok "=========================================="
echo
log_info "Next steps:"
echo "  1. Reboot: reboot"
echo "  2. Login as 'gamer' no TTY1 (auto-login)"
echo "  3. PRIMEIRO BOOT: TTY com login - SEM gamescope"
echo "  4. Para Sway fallback: Ctrl+Alt+F2 -> login -> sway --unsupported-gpu --config /etc/sway/config"
echo "  5. Ative módulos depois do primeiro boot em configuration.nix:"
echo "     config.gameos.graphics.enableGamescope = true;"
echo "     config.gameos.gaming.enableSteam = true;"
echo "     config.gameos.gaming.enableLutris = true;"
echo "     config.gameos.gaming.enableHeroic = true;"
echo "     config.gameos.gaming.enableEmulators = true;"
echo "     config.gameos.hydra.enable = true;"
echo "     cd ~/issoai && sudo nixos-rebuild switch --flake .#mypc"
echo
log_warn "Se Secure Boot estiver ativo na BIOS, desative antes do primeiro boot!"
echo

read -p "Reboot now? (y/N): " REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    reboot
fi