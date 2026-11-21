{ config, pkgs, lib, ... }:

{
  # ============================================================
  # GRÁFICOS - NVIDIA GTX 1660 SUPER (Turing, sem GSP)
  # Driver proprietário estável: nvidiaPackages.stable
  # open = false, modesetting.enable = true
  # ============================================================

  options.gameos.graphics = {
    enableGamescope = lib.mkEnableOption "Gamescope compositor (Steam Deck UI)";
  };

  # Hardware OpenGL/Vulkan base
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  hardware.vulkan = {
    enable = true;
    drivers = [ "nvidia" ]; # Apenas NVIDIA ICD
  };

  # Driver NVIDIA estável/produção - CLOSED source
  # 1660 Super NÃO tem GSP -> usa driver legacy/closed (propriedade)
  # Usa config.boot.kernelPackages.nvidiaPackages.stable (sem overlay)
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;        # KMS/DRM obrigatório para gamescope/Wayland
    powerManagement = true;           # Power management (suspend/resume)
    powerManagementFinegrained = true;
    dynamicPowerManagement = true;
    persistenceMode = true;           # Mantém GPU ativa
    open = false;                     # FECHADO - 1660 Super não suporta GSP/open kernel module
    nvidiaSettings = true;
    nvidiaPersistent = true;

    # Configurações do kernel module
    kernelModuleOptions = "NVreg_EnableGpuFirmware=0 NVreg_EnableResizableBar=1 NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/tmp";

    # X11 config (fallback se precisar)
    x11 = {
      enable = true;
      # Configuração será gerada automaticamente
    };
  };

  # Prime: DESABILITADO (sem iGPU)
  hardware.nvidia.prime = {
    enable = false;
    offload = false;
    sync.enable = false;
  };

  # Gamescope (compositor Wayland do Steam Deck) - OPCIONAL
  config = lib.mkIf config.gameos.graphics.enableGamescope {
    environment.systemPackages = with pkgs; [
      gamescope
      gamescope-session-steam
      gamescope-session-steam-plus
    ];

    # Variáveis de ambiente globais para NVIDIA + Wayland + Gamescope
    environment.variables = {
      # NVIDIA Wayland
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      __GL_GSYNC_ALLOWED = "1";
      __GL_VRR_ALLOWED = "1";
      __GL_THREADED_OPTIMIZATIONS = "1";
      __GL_SYNC_TO_VBLANK = "0"; # Gamescope controla vsync

      # Vulkan
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:${pkgs.vulkan-loader}/share/vulkan/icd.d/nvidia_icd.json";
      VK_LAYER_PATH = "${pkgs.vulkan-tools}/share/vulkan/explicit_layer.d";

      # Gamescope - DRM device será detectado dinamicamente no boot
      # Use /dev/dri/by-path/pci-XXXX:XX:XX.X-card
      GAMESCOPE_DRM_DEVICE = "/dev/dri/by-path/pci-0000:01:00.0-card";
      GAMESCOPE_PREFER_VK = "1";

      # Shader cache
      __GL_SHADER_DISK_CACHE = "1";
      __GL_SHADER_DISK_CACHE_PATH = "/home/gamer/.cache/nvidia";
      NVIDIA_SHADER_CACHE_PATH = "/home/gamer/.cache/nvidia";

      # Wine/Proton
      DXVK_ASYNC = "1";
      DXVK_HUD = "";
      VKD3D_CONFIG = "dxr11,multi_queue";

      # Mesa (não usado, mas evita warnings)
      MESA_LOADER_DRIVER_OVERRIDE = "";
      AMD_VULKAN_ICD = "";
      RADV_PERFTEST = "";
    };

    # XWayland para apps legados (Steam, etc)
    services.xserver = {
      enable = true;
      displayManager.enable = false; # Sem DM - boot direto
      xkb = {
        layout = "br";
        variant = "abnt2";
      };
    };

    # Seatd para gerenciamento de assentos (gamescope precisa)
    services.seatd.enable = true;
  };

  # ============================================================
  # FALLBACK SESSION - Sway (Wayland) - APENAS MANUAL
  # Não inicia automaticamente. Use Ctrl+Alt+F2 -> login -> sway
  # ============================================================
  environment.systemPackages = with pkgs; [
    sway
    swaybg
    swaylock
    swayidle
    waybar
    foot
    wofi
    polkit-gnome
    gnome-keyring
  ];

  # Sway config para uso manual
  environment.etc."sway/config".source = pkgs.writeText "sway-config" ''
    # Sway fallback config for GameOS
    # Use: sway --config /etc/sway/config (após login no TTY)
    # NÃO inicia como serviço - apenas manualmente

    # Input
    input type:keyboard {
      xkb_layout br
      xkb_variant abnt2
    }

    input type:pointer {
      accel_profile flat
      sensitivity 0
    }

    # Output
    output * {
      bg /usr/share/backgrounds/gameos-bg.png fill
    }

    # Autostart (quando rodar manualmente)
    exec waybar
    exec swaybg -i /usr/share/backgrounds/gameos-bg.png -m fill
    exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
    exec gnome-keyring-daemon --start --components=secrets,pkcs11,ssh

    # Keybindings
    set $mod Mod4
    bindsym $mod+Return exec foot
    bindsym $mod+d exec wofi --show drun
    bindsym $mod+Shift+q kill
    bindsym $mod+Shift+r reload
    bindsym $mod+Shift+e exec swaynag -t warning -m "Sair do Sway?" -B "Sim" "swaymsg exit"

    # Workspaces
    bindsym $mod+1 workspace 1
    bindsym $mod+2 workspace 2
    bindsym $mod+3 workspace 3
    bindsym $mod+4 workspace 4
    bindsym $mod+5 workspace 5

    # Resize mode
    mode "resize" {
      bindsym h resize shrink width 10px
      bindsym j resize grow height 10px
      bindsym k resize shrink height 10px
      bindsym l resize grow width 10px
      bindsym Return mode "default"
      bindsym Escape mode "default"
    }
    bindsym $mod+r mode "resize"

    # Gaps
    gaps inner 5
    gaps outer 2
  '';

  # REMOVIDO: systemd.user.services.sway-fallback
  # O Sway NÃO inicia automaticamente. Para usar:
  # 1. Ctrl+Alt+F2 (TTY2)
  # 2. Login como gamer
  # 3. Rode: sway --config /etc/sway/config

  # udev rules para input/gamepads
  services.udev.extraRules = ''
    # Gamepads / Controllers
    KERNEL=="uinput", GROUP="input", MODE="0660"
    KERNEL=="event*", ATTRS{idVendor}=="054c", GROUP="input", MODE="0660"  # Sony
    KERNEL=="event*", ATTRS{idVendor}=="045e", GROUP="input", MODE="0660"  # Microsoft
    KERNEL=="event*", ATTRS{idVendor}=="046d", GROUP="input", MODE="0660"  # Logitech
    KERNEL=="event*", ATTRS{idVendor}=="057e", GROUP="input", MODE="0660"  # Nintendo
    KERNEL=="event*", ATTRS{idVendor}=="2c22", GROUP="input", MODE="0660"  # 8BitDo
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", GROUP="input", MODE="0660"
    KERNEL=="hidraw*", ATTRS{idVendor}=="045e", GROUP="input", MODE="0660"
    KERNEL=="hidraw*", ATTRS{idVendor}=="046d", GROUP="input", MODE="0660"
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", GROUP="input", MODE="0660"
    KERNEL=="hidraw*", ATTRS{idVendor}=="2c22", GROUP="input", MODE="0660"
  '';
}