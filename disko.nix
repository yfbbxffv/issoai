{ config, pkgs, ... }:

{
  # ============================================================
  # DISKO - Particionamento declarativo (schema disko)
  # NVMe: ESP (1G) + Btrfs (resto) com subvolumes @, @home, @nix
  # HDD1: ext4 /games/1
  # HDD2: ext4 /games/2
  #
  # IMPORTANTE: Use /dev/disk/by-id/ para identificação estável!
  # O install.sh substitui os placeholders abaixo automaticamente.
  # ============================================================

  disko.devices.disk = {
    nvme = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SUBSTITUA_PELO_SEU_ID_AQUI";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-L" "NIXOS" ];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
              };
            };
          };
        };
      };
    };

    games1 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-SUBSTITUA_PELO_SEU_ID_AQUI";
      content = {
        type = "gpt";
        partitions = {
          games = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/games/1";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };

    games2 = {
      type = "disk";
      device = "/dev/disk/by-id/ata-SUBSTITUA_PELO_SEU_ID_AQUI";
      content = {
        type = "gpt";
        partitions = {
          games = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/games/2";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };

  # boot.loader é configurado em modules/boot.nix
}