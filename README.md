# GameOS

Custom lightweight gaming OS for **i3-10100F + GTX 1660 Super** (6GB).

## Features

- **Base**: NixOS 26.05 (reproducible, atomic, rollbackable)
- **Kernel**: CachyOS (BORE/EEVDF sched-ext, gaming optimized)
- **Graphics**: NVIDIA stable driver (proprietary, modeset=on, no GSP)
- **Compositor**: Gamescope (Steam Deck compositor, Wayland) + Sway fallback (manual)
- **Launcher**: Hydra (custom Rust/Slint, gamepad-first UI) - **opcional**
- **Gaming**: Steam + Proton-GE, Lutris + Wine-GE, Heroic (EGS/GOG) - **opcional**
- **Emulation**: Dolphin, Citra, RetroArch, melonDS, mGBA, Mupen64Plus - **opcional**
  - **Nintendo Switch**: Ryujinx/Yuzu originais descontinuados. Use forks via Flatpak.
- **Storage**: Btrfs (zstd:3, snapshots), zram swap, separate game disks
- **Boot**: systemd-boot + UKI, 2-3s to gamescope

## Hardware

| Component | Spec |
|-----------|------|
| CPU | Intel Core i3-10100F (4C/8T, no iGPU) |
| GPU | NVIDIA GTX 1660 Super 6GB (Turing, no GSP) |
| RAM | 16 GB DDR4 |
| OS Disk | NVMe ~237 GB |
| Games Disk 1 | SATA HDD 465 GB (/games/1) |
| Games Disk 2 | SATA HDD 465 GB (/games/2) |

## Quick Start

### 1. Prepare Install Media

```bash
# Baixe NixOS minimal ISO (https://nixos.org/download.html)
# Grave no USB (Ventoy, Rufus, dd)
```

### 2. Boot Live ISO

```bash
# UEFI only (disable CSM/Secure Boot no BIOS)
# Conecte internet (cabo ethernet recomendado)
```

### 3. Obtenha os arquivos do GameOS

**Opção A: Clone do repositório (recomendado)**
```bash
git clone https://github.com/yfbbxffv/issoai.git
cd issoai
```

**Opção B: Download ZIP**
```bash
wget https://github.com/yfbbxffv/issoai/archive/refs/heads/main.zip
unzip main.zip
cd issoai-main
```

**Opção C: Build local (se já tem NixOS)**
```bash
nix build .#nixosConfigurations.mypc.config.system.build.isoImage
```

### 4. Instale

```bash
sudo ./install.sh
```

O script `install.sh`:
1. Detecta hardware (CPU/GPU/RAM)
2. Lista discos com modelo, tamanho e serial
3. **Exclui automaticamente o USB do Live ISO**
4. Pergunta qual disco é NVMe, HDD1, HDD2 (por número)
5. Converte para `/dev/disk/by-id/` (estável)
6. **Mostra o disko.nix final com IDs já substituídos** para conferência
7. Confirmação destrutiva dupla
8. Particiona e formata (disko)
9. Monta filesystems
10. Gera `hardware-configuration.nix`
11. Instala NixOS via flake
12. Define senha do usuário `gamer`

### 5. Reboot

```bash
reboot
```

## First Boot

1. **Auto-login** como `gamer` no TTY1
2. **Gamescope** inicia automaticamente
3. **Steam** abre em tela cheia (Big Picture)
4. Configure:
   - Steam: login na primeira execução
   - ROMs: coloque em `/games/1/` ou `/games/2/`

### Fallback (se Gamescope falhar)

Pressione `Ctrl+Alt+F2` para TTY2, login como `gamer`, rode:
```bash
sway --config /etc/sway/config
```
O Sway **NÃO inicia automaticamente** - apenas manualmente via TTY.

## Ativando Módulos Opcionais

Edite `hosts/mypc/configuration.nix` e adicione:

```nix
{ config, pkgs, ... }: {
  imports = [ ... ];
  
  # Ative o que precisar:
  config.gameos.gaming.enableSteam = true;        # Steam + Proton
  config.gameos.gaming.enableLutris = true;       # Lutris + Wine-GE
  config.gameos.gaming.enableHeroic = true;       # Heroic Games Launcher
  config.gameos.gaming.enableEmulators = true;    # RetroArch, Dolphin, etc
  config.gameos.gaming.enableSwitchEmulators = true; # Info sobre Switch (flatpak)
  config.gameos.gaming.enableGamepadTools = true; # Gamepad daemons
  config.gameos.hydra.enable = true;              # Hydra Launcher custom
  
  # Hardware, etc...
}
```

Depois reconstrua:
```bash
sudo nixos-rebuild switch --flake .#mypc
```

## Development

### Hydra Launcher

```bash
cd hydra-launcher
nix develop  # ou: nix shell .#hydra-launcher
cargo run
```

### NixOS Config

```bash
# Testar em VM (requer KVM)
./build-vm.sh

# Ou manualmente:
nixos-rebuild build-vm --flake .#mypc
./result/bin/run-*-vm

# Aplicar mudanças no host
sudo nixos-rebuild switch --flake .#mypc

# Rollback
sudo nixos-rebuild switch --rollback
```

### Update Flake Inputs

```bash
nix flake update
sudo nixos-rebuild switch --flake .#mypc
```

### Gerar ISO de instalação customizada

```bash
nix build .#nixosConfigurations.mypc.config.system.build.isoImage -o result-iso
sudo dd if=result-iso/iso/*.iso of=/dev/sdX bs=4M status=progress && sync
```

## Directory Structure

```
issoai/
├── flake.nix              # Flake entry point (nixosVersion = "26.05")
├── disko.nix              # Disk partitioning (placeholders para by-id)
├── install.sh             # Installation script (interativo, mostra disko.nix final)
├── build-vm.sh            # Build & run VM for testing
├── build-iso.sh           # Build custom ISO
├── update.sh              # Update flake inputs
├── overlays/
│   └── default.nix        # Overlays mínimos (cachyos kernel, proton-ge, wine-ge)
├── modules/
│   ├── kernel.nix         # CachyOS kernel, cmdline, modules
│   ├── boot.nix           # systemd-boot, UKI
│   ├── users.nix          # gamer user, autologin, sudo
│   ├── graphics.nix       # NVIDIA stable, gamescope, Vulkan, Sway manual
│   ├── gaming.nix         # Módulos opcionais (enable = false)
│   ├── hydra.nix          # Hydra launcher (opcional)
│   ├── storage.nix        # Btrfs, zram, mount options
│   ├── network.nix        # systemd-networkd, gaming tweaks
│   └── performance.nix    # cpupower, tuned, earlyoom
├── hosts/mypc/
│   ├── configuration.nix  # Host config (system.stateVersion = "26.05")
│   └── hardware-configuration.nix  # Generated
├── scripts/
│   ├── generate-hashes.sh # (legacy) Generate SHA256 for git sources
│   ├── backup-config.sh   # Backup configs
│   ├── health-check.sh    # System health check
│   └── setup-roms.sh      # Setup ROM directories
└── hydra-launcher/        # Rust/Slint launcher (opcional)
    ├── Cargo.toml
    ├── flake.nix
    ├── src/
    │   ├── main.rs
    │   ├── app.rs
    │   ├── sources/       # Steam, Ryujinx, yuzu, Lutris, Heroic, Manual
    │   ├── ui/            # Slint UI
    │   ├── database/      # SQLite (sqlx)
    │   └── install/       # Install pipeline
    └── assets/
```

## Customization

### NixOS Version

Edite `flake.nix`:
```nix
nixosVersion = "26.05";  # Troque para "26.11" quando sair
```

### Kernel Parameters

Edit `modules/kernel.nix`:
```nix
boot.kernelParams = [ "mitigations=off" "preempt=full" ... ];
```

### NVIDIA Settings

Edit `modules/graphics.nix`:
```nix
hardware.nvidia = {
  package = config.boot.kernelPackages.nvidiaPackages.stable;
  modesetting.enable = true;
  open = false;
  kernelModuleOptions = "NVreg_EnableResizableBar=1 ...";
};
```

### Game Paths

Edit `modules/hydra.nix`:
```nix
HYDRA_GAMES_PATH_1 = "/games/1";
HYDRA_GAMES_PATH_2 = "/games/2";
```

### Hydra Launcher UI

Edit `hydra-launcher/src/ui/main_window.slint`

## Troubleshooting

### NVIDIA não carrega no boot
```bash
lsinitrd /boot/initrd-*.img | grep nvidia
# Adiciona em kernel.nix: boot.initrd.kernelModules
```

### Gamescope não inicia
```bash
ls -la /dev/dri/by-path/
# Ajusta GAMESCOPE_DRM_DEVICE em graphics.nix
# Fallback: Ctrl+Alt+F2 -> sway --config /etc/sway/config
```

### Hydra não encontra jogos
```bash
journalctl --user -u hydra-launcher -f
```

### Rollback quebrado
```bash
nixos-rebuild list-generations
# Boota geração anterior no systemd-boot menu
```

### Disco não monta no boot
```bash
lsblk -f
# Verifica labels: NIXOS, GAMES1, GAMES2, EFI
```

## Emuladores Nintendo Switch - Notas Importantes (2025)

| Emulador | Status | Recomendação |
|----------|--------|--------------|
| **Ryujinx (original)** | Descontinuado (out/2024) | Use fork `ryujinx-mirror` via Flatpak |
| **Yuzu (original)** | Encerrado (mar/2024) | Use fork `suzu` via Flatpak |
| **ryujinx-mirror** | Ativo (comunidade) | `flatpak install flathub org.ryujinx.Ryujinx` |
| **suzu** | Ativo (fork yuzu) | `flatpak install flathub org.suzu_emu.Suzu` (quando diponível) |

Para uso imediato, instale via Flatpak após ativar `enableSwitchEmulators` e `services.flatpak.enable = true`.

## License

MIT - Use freely for personal gaming OS.

## Credits

- NixOS, CachyOS, Gamescope, Steam, Lutris, Heroic
- Dolphin, Citra, RetroArch, melonDS, mGBA, Mupen64Plus teams
- Ryujinx-mirror, Suzu communities
- Slint, Rust, Nix communities