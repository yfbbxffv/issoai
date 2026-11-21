{ config, pkgs, ... }:

{
  # ============================================================
  # HOST CONFIGURATION - mypc (i3-10100F + GTX 1660 Super)
  # ============================================================

  # State version para upgrades seguros
  system.stateVersion = "26.05";

  imports = [
    ./hardware-configuration.nix
    ../../disko.nix
    ../../modules/kernel.nix
    ../../modules/boot.nix
    ../../modules/users.nix
    ../../modules/graphics.nix
    ../../modules/gaming.nix
    ../../modules/hydra.nix
    ../../modules/storage.nix
    ../../modules/network.nix
    ../../modules/performance.nix
  ];

  # ============================================================
  # HARDWARE ESPECÍFICO
  # ============================================================
  hardware = {
    # CPU Intel i3-10100F
    cpu = {
      intel = {
        updateMicrocode = true;
      };
    };

    # GPU NVIDIA GTX 1660 Super - configuração mínima
    nvidia = {
      modesetting.enable = true;
      powerManagement = true;
      persistenceMode = true;
      open = false;
    };

    # Bluetooth (se tiver)
    bluetooth.enable = false;

    # USB
    usb.ids = true;

    # Sensors
    sensors = {
      enable = true;
      pollInterval = 5;
    };
  };

  # ============================================================
  # SERVIÇOS DO SISTEMA
  # ============================================================
  services = {
    # Systemd
    systemd = {
      logind = {
        lidSwitch = "ignore";
        handleLidSwitch = "ignore";
        handleLidSwitchDocked = "ignore";
      };
      resolved = {
        enable = true;
      };
    };

    # D-Bus
    dbus.enable = true;

    # PipeWire (áudio) - substitui PulseAudio
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = false;
      sessionManager = "wireplumber";
    };

    # WirePlumber
    wireplumber.enable = true;

    # UDisks2 (montagem automática USB)
    udisks2.enable = true;

    # Logind
    logind = {
      enable = true;
      killUserProcesses = false;
      removeIPC = false;
    };
  };

  # ============================================================
  # LOCALE / TECLADO / TIMEZONE
  # ============================================================
  i18n = {
    defaultLocale = "pt_BR.UTF-8";
    supportedLocales = [ "pt_BR.UTF-8" "en_US.UTF-8" ];
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "br-abnt2";
    useXkbConfig = true;
  };

  time.timeZone = "America/Sao_Paulo";

  # ============================================================
  # FIRMWARE
  # ============================================================
  hardware.enableAllFirmware = true;
  hardware.firmware = [
    pkgs.linux-firmware
    pkgs.intel-microcode
  ];

  # ============================================================
  # ALLOW UNFREE (NVIDIA, Steam, etc)
  # ============================================================
  nixpkgs.config.allowUnfree = true;

  # ============================================================
  # PACOTES EXTRAS DO SISTEMA
  # ============================================================
  environment.systemPackages = with pkgs; [
    # Essentials
    fish
    git
    curl
    wget
    aria2
    unzip
    p7zip
    htop
    btop
    neofetch
    tree
    fd
    ripgrep
    fzf
    bat
    eza
    zoxide
    starship
    tealdeer
    man-pages
    man-pages-posix

    # Sistema
    nvtop
    intel-gpu-tools
    nvidia-smi
    lm_sensors
    smartmontools
    hdparm
    nvme-cli
    btrfs-progs
    snapper
    disko
  ];

  # ============================================================
  # DOCUMENTAÇÃO
  # ============================================================
  documentation = {
    enable = true;
    doc.enable = false; # Não instala docs pesadas
    man.enable = true;
    info.enable = false;
  };

  # ============================================================
  # GARBAGE COLLECTION
  # ============================================================
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    optimize.automatic = true;
  };
}