{ config, pkgs, ... }:

{
  # ============================================================
  # DISKO - Particionamento declarativo
  # NVMe: EFI (1GB) + Btrfs (~236GB) com subvolumes
  # HDD1: Btrfs /games/1 (465GB)
  # HDD2: Btrfs /games/2 (465GB)
  #
  # IMPORTANTE: Use /dev/disk/by-id/ para identificação estável!
  # O install.sh substitui os placeholders abaixo automaticamente.
  # ============================================================

  disko.devices = {
    disk = {
      # NVMe principal (~237 GB) - SUBSTITUÍDO PELO INSTALL.SH
      nvme0 = {
        device = "/dev/disk/by-id/nvme-SUBSTITUA_PELO_SEU_ID_AQUI";
        type = "gpt";
        wipe = true;
        partitions = {
          efi = {
            size = "1G";
            type = "efi";
            format = {
              fsType = "vfat";
              label = "EFI";
            };
            mountpoint = "/boot/efi";
          };
          root = {
            size = "-"; # Resto do disco
            type = "8300"; # Linux filesystem
            format = {
              fsType = "btrfs";
              label = "NIXOS";
              extraArgs = [ "-f" ]; # Force
            };
            mountpoint = "/";
            mountOptions = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" ];
          };
        };
      };

      # HDD 1 (465 GB) - /games/1 - SUBSTITUÍDO PELO INSTALL.SH
      hdd1 = {
        device = "/dev/disk/by-id/ata-SUBSTITUA_PELO_SEU_ID_AQUI";
        type = "gpt";
        wipe = true;
        partitions = {
          games1 = {
            size = "-";
            type = "8300";
            format = {
              fsType = "btrfs";
              label = "GAMES1";
              extraArgs = [ "-f" ];
            };
            mountpoint = "/games/1";
            mountOptions = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "autodefrag" ];
          };
        };
      };

      # HDD 2 (465 GB) - /games/2 - SUBSTITUÍDO PELO INSTALL.SH
      hdd2 = {
        device = "/dev/disk/by-id/ata-SUBSTITUA_PELO_SEU_ID_AQUI";
        type = "gpt";
        wipe = true;
        partitions = {
          games2 = {
            size = "-";
            type = "8300";
            format = {
              fsType = "btrfs";
              label = "GAMES2";
              extraArgs = [ "-f" ];
            };
            mountpoint = "/games/2";
            mountOptions = [ "rw" "noatime" "compress=zstd:3" "space_cache=v2" "autodefrag" ];
          };
        };
      };
    };
  };

  # ============================================================
  # SUBVOLUMES BTRFS (criados automaticamente pelo disko)
  # ============================================================
  disko.postPartitionCommands = [
    # Subvolumes no root (NVMe)
    "btrfs subvolume create /mnt/@"
    "btrfs subvolume create /mnt/@home"
    "btrfs subvolume create /mnt/@nix"
    "btrfs subvolume create /mnt/@log"
    "btrfs subvolume create /mnt/@tmp"
    "btrfs subvolume create /mnt/@snapshots"
    "btrfs subvolume create /mnt/@cache"

    # Mounts dos subvolumes
    "mount -o subvol=@,compress=zstd:3,noatime,space_cache=v2,discard=async /dev/disk/by-label/NIXOS /mnt"
    "mkdir -p /mnt/{home,nix,var/log,tmp,.snapshots,home/gamer/.cache}"
    "mount -o subvol=@home,compress=zstd:3,noatime,space_cache=v2,discard=async /dev/disk/by-label/NIXOS /mnt/home"
    "mount -o subvol=@nix,compress=zstd:3,noatime,space_cache=v2,discard=async /dev/disk/by-label/NIXOS /mnt/nix"
    "mount -o subvol=@log,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/var/log"
    "mount -o subvol=@tmp,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/tmp"
    "mount -o subvol=@snapshots,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/.snapshots"
    "mount -o subvol=@cache,compress=zstd:3,noatime,space_cache=v2 /dev/disk/by-label/NIXOS /mnt/home/gamer/.cache"
  ];
}