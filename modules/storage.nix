{ config, pkgs, ... }:

{
  # ============================================================
  # STORAGE - Btrfs + zram
  # NVMe: EFI (1GB) + Btrfs (resto) com subvolumes
  # HDD1: /games/1 (Btrfs)
  # HDD2: /games/2 (Btrfs)
  # Swap: zram apenas
  # ============================================================

  # ============================================================
  # ZRAM (swap comprimido em RAM)
  # ============================================================
  systemd.zramDevices = {
    zram0 = {
      algorithm = "zstd";
      size = "8G"; # 50% da RAM (16GB)
      memoryLimit = "12G"; # Limite máximo de RAM não comprimida
    };
  };

  # Swap no zram
  swapDevices = [
    { device = "/dev/zram0"; priority = 100; }
  ];

  # ============================================================
  # BTRFS MOUNT OPTIONS
  # ============================================================
  # Opções padrão para todos os btrfs mounts
  fileSystems."/".options = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" ];
  fileSystems."/home".options = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" ];
  fileSystems."/nix".options = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" "subvol=@nix" ];
  fileSystems."/var/log".options = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "subvol=@log" ];
  fileSystems."/tmp".options = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "subvol=@tmp" ];

  # ============================================================
  # GAMES DISKS (HDD SATA) - Montagem separada
  # ============================================================
  # HDD 1: /games/1
  fileSystems."/games/1" = {
    device = "/dev/disk/by-label/GAMES1";
    fsType = "btrfs";
    options = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "autodefrag" ];
    neededForBoot = false;
    createMountPoint = true;
  };

  # HDD 2: /games/2
  fileSystems."/games/2" = {
    device = "/dev/disk/by-label/GAMES2";
    fsType = "btrfs";
    options = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "autodefrag" ];
    neededForBoot = false;
    createMountPoint = true;
  };

  # ============================================================
  # TMPFS para cache de shaders, downloads temporários
  # ============================================================
  fileSystems."/tmp" = {
    fsType = "tmpfs";
    options = [ "rw" "nosuid" "nodev" "size=8G" "mode=1777" ];
  };

  fileSystems."/home/gamer/.cache" = {
    fsType = "tmpfs";
    options = [ "rw" "nosuid" "nodev" "size=4G" "uid=1000" "gid=1000" ];
    neededForBoot = false;
  };

  # Shader cache NVIDIA em tmpfs (rápido, persiste via sync)
  fileSystems."/home/gamer/.cache/nvidia" = {
    fsType = "tmpfs";
    options = [ "rw" "nosuid" "nodev" "size=2G" "uid=1000" "gid=1000" ];
    neededForBoot = false;
  };

  # ============================================================
  # BTRFS MAINTENANCE (scrub, balance, snapshots)
  # ============================================================
  systemd.services.btrfs-scrub-monthly = {
    description = "Monthly Btrfs Scrub";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs scrub start -B /";
    };
  };

  systemd.timers.btrfs-scrub-monthly = {
    description = "Monthly Btrfs Scrub Timer";
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    wantedBy = [ "timers.target" ];
  };

  # Snapper para snapshots do sistema (root)
  services.snapper = {
    enable = true;
    configs = {
      root = {
        path = "/";
        timeline = {
          create = true;
          cleanup = true;
          limit = 10;
        };
      };
      home = {
        path = "/home";
        timeline = {
          create = true;
          cleanup = true;
          limit = 5;
        };
      };
    };
  };

  # Grub-btrfs (não usado - systemd-boot)
  # Mas snapshots aparecem no systemd-boot automaticamente via boot.loader.generationsDir
}