{ config, pkgs, lib, ... }:

{
  options.gameos.graphics = {
    enableGamescope = lib.mkEnableOption "Gamescope compositor (Steam Deck UI)";
  };

  config = lib.mkMerge [
    {
      # ============================================================
      # BASE GRAPHICS - SEMPRE ATIVO
      # ============================================================
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      # Driver NVIDIA - configuração mínima
      hardware.nvidia = {
        modesetting.enable = true;
        open = false;
        nvidiaSettings = false;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };

      services.xserver = {
        videoDrivers = [ "nvidia" ];
      };

      # Seatd para gerenciamento de assentos (gamescope precisa se habilitado)
      services.seatd.enable = true;

      # ============================================================
      # SWAY FALLBACK - APENAS MANUAL
      # Pacotes mínimos: sway + foot
      # Use: Ctrl+Alt+F2 -> login -> sway --unsupported-gpu
      # ============================================================
      environment.systemPackages = with pkgs; [
        sway
        foot
      ];

      # Sway config mínima para uso manual
      environment.etc."sway/config".source = pkgs.writeText "sway-config" ''
        # Sway fallback config for GameOS
        # Use: sway --unsupported-gpu --config /etc/sway/config
        # NÃO inicia como serviço - apenas manualmente

        input type:keyboard {
          xkb_layout br
          xkb_variant abnt2
        }

        input type:pointer {
          accel_profile flat
          sensitivity 0
        }

        # Keybindings
        set $mod Mod4
        bindsym $mod+Return exec foot
        bindsym $mod+d exec swaymsg -t get_tree | jq -r '.. | select(.name?) | .name' | wofi --dmenu 2>/dev/null | xargs -r swaymsg exec
        bindsym $mod+Shift+q kill
        bindsym $mod+Shift+r reload
        bindsym $mod+Shift+e exec swaynag -t warning -m "Sair do Sway?" -B "Sim" "swaymsg exit"

        # Workspaces
        bindsym $mod+1 workspace 1
        bindsym $mod+2 workspace 2
        bindsym $mod+3 workspace 3
        bindsym $mod+4 workspace 4
        bindsym $mod+5 workspace 5
      '';
    }
    # ============================================================
    # GAMESCOPE - OPCIONAL (enable = false por padrão)
    # ============================================================
    (lib.mkIf config.gameos.graphics.enableGamescope {
      environment.systemPackages = with pkgs; [
        gamescope
        gamescope-session-steam
        gamescope-session-steam-plus
      ];

      environment.variables = {
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __GL_GSYNC_ALLOWED = "1";
        __GL_VRR_ALLOWED = "1";
        __GL_THREADED_OPTIMIZATIONS = "1";
        __GL_SYNC_TO_VBLANK = "0";
        VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:${pkgs.vulkan-loader}/share/vulkan/icd.d/nvidia_icd.json";
        VK_LAYER_PATH = "${pkgs.vulkan-tools}/share/vulkan/explicit_layer.d";
        GAMESCOPE_DRM_DEVICE = "/dev/dri/by-path/pci-0000:01:00.0-card";
        GAMESCOPE_PREFER_VK = "1";
        __GL_SHADER_DISK_CACHE = "1";
        __GL_SHADER_DISK_CACHE_PATH = "/home/gamer/.cache/nvidia";
        NVIDIA_SHADER_CACHE_PATH = "/home/gamer/.cache/nvidia";
        DXVK_ASYNC = "1";
        DXVK_HUD = "";
        VKD3D_CONFIG = "dxr11,multi_queue";
        MESA_LOADER_DRIVER_OVERRIDE = "";
        AMD_VULKAN_ICD = "";
        RADV_PERFTEST = "";
      };

      services.xserver = {
        videoDrivers = [ "nvidia" ];
      };

      services.seatd.enable = true;
    })
  ];
}