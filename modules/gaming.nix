{ config, pkgs, ... }:

{
  # ============================================================
  # GAMING - Módulos opcionais (enable = false por padrão)
  # Ative o que precisar em configuration.nix:
  #   config.gameos.gaming.enableSteam = true;
  #   config.gameos.gaming.enableLutris = true;
  #   etc.
  # ============================================================

  options.gameos.gaming = {
    enableSteam = lib.mkEnableOption "Steam + Proton";
    enableLutris = lib.mkEnableOption "Lutris + Wine-GE";
    enableHeroic = lib.mkEnableOption "Heroic Games Launcher";
    enableEmulators = lib.mkEnableOption "Emuladores (RetroArch, Dolphin, etc)";
    enableSwitchEmulators = lib.mkEnableOption "Emuladores Switch (ryujinx-mirror, suzu via flatpak)";
    enableGamepadTools = lib.mkEnableOption "Gamepad/input daemons";
  };

  # Configurações padrão - tudo desligado
  config = lib.mkIf config.gameos.gaming.enableSteam {
    # ============================================================
    # STEAM + PROTON
    # ============================================================
    programs.steam = {
      enable = true;
      steamRuntime = true;
      protonVersions = [
        pkgs.proton-ge
        pkgs.proton-9-0
        pkgs.proton-experimental
        pkgs.proton-hotfix
      ];
    };

    environment.systemPackages = with pkgs; [
      steamcmd
    ];
  };

  config = lib.mkIf config.gameos.gaming.enableLutris {
    # ============================================================
    # LUTRIS + WINE-GE
    # ============================================================
    programs.lutris = {
      enable = true;
      wineVersions = [ pkgs.wine-ge pkgs.wine-staging pkgs.wine ];
    };

    environment.systemPackages = with pkgs; [
      wine-ge
      (pkgs.wine-staging.override { enable32Bit = true; })
      pkgs.vkd3d
      pkgs.vkd3d-32bit
      pkgs.dxvk
      pkgs.dxvk-32bit
      pkgs.gstreamer
      pkgs.gst-plugins-good
      pkgs.gst-plugins-bad
      pkgs.gst-plugins-ugly
      pkgs.gst-libav
      pkgs.freetype
      pkgs.freetype-32bit
      pkgs.gnutls
      pkgs.gnutls-32bit
      pkgs.libva
      pkgs.libva-32bit
      pkgs.v4l-utils
    ];
  };

  config = lib.mkIf config.gameos.gaming.enableHeroic {
    # ============================================================
    # HEROIC GAMES LAUNCHER (Epic, GOG, Amazon, EA)
    # ============================================================
    environment.systemPackages = with pkgs; [
      heroic-games-launcher
      heroic-games-launcher-bin
    ];
  };

  config = lib.mkIf config.gameos.gaming.enableEmulators {
    # ============================================================
    # EMULADORES - Pacotes padrão do nixpkgs (sem overlays custom)
    # ============================================================
    environment.systemPackages = with pkgs; [
      # Nintendo 3DS
      citra

      # Nintendo Wii / GameCube
      dolphin-emu

      # Nintendo DS
      melonds

      # Nintendo 64
      mupen64plus
      mupen64plus-qt

      # Game Boy / GBA / Color
      mgba

      # RetroArch + cores (pacotes padrão nixpkgs)
      retroarch
      retroarch-assets
      retroarch-assets-xmb
      retroarch-assets-ozone

      # Libretro cores
      libretro-beetle-psx       # PS1
      libretro-beetle-saturn
      libretro-mgba             # GBA
      libretro-gambatte         # GB/GBC
      libretro-mesen            # NES
      libretro-mesen-s          # SNES
      libretro-parallel-n64     # N64
      libretro-ppsspp           # PSP
      libretro-snes9x           # SNES
      libretro-nestopia         # NES
      libretro-genesis-plus-gx  # Genesis
      libretro-pcsx2            # PS2
      libretro-flycast          # Dreamcast
    ];
  };

  config = lib.mkIf config.gameos.gaming.enableSwitchEmulators {
    # ============================================================
    # EMULADORES NINTENDO SWITCH - Apenas comentado
    # Ryujinx original: descontinuado out/2024
    # Yuzu original: encerrado mar/2024
    # Use forks via Flatpak/AppImage:
    #   flatpak install flathub org.ryujinx.Ryujinx  # ryujinx-mirror
    #   flatpak install flathub org.suzu_emu.Suzu    # suzu (quando disponível)
    # ============================================================
    # environment.systemPackages = with pkgs; [
    #   # ryujinx-mirror (flatpak recomendado)
    #   # suzu (flatpak recomendado)
    # ];
  };

  config = lib.mkIf config.gameos.gaming.enableGamepadTools {
    # ============================================================
    # GAMEPAD / INPUT DAEMONS
    # ============================================================
    services.steam-hardware = {
      enable = true;
      udevRules = true;
    };

    environment.variables = {
      SDL_GAMECONTROLLERCONFIG = "/etc/gamecontrollerdb.txt";
      SDL_JOYSTICK_HIDAPI = "1";
      SDL_JOYSTICK_HIDAPI_PS4 = "1";
      SDL_JOYSTICK_HIDAPI_PS5 = "1";
      SDL_JOYSTICK_HIDAPI_SWITCH = "1";
      SDL_JOYSTICK_HIDAPI_XBOX = "1";
      SDL_JOYSTICK_HIDAPI_STEAM = "1";
    };

    environment.etc."gamecontrollerdb.txt".source = pkgs.writeText "gamecontrollerdb.txt" ''
      # GameControllerDB - https://github.com/gabomdq/SDL_GameControllerDB
      # Adicione seus mapeamentos customizados aqui
    '';
  };

  # ============================================================
  # FLATPAK (desabilitado - usamos nixpkgs)
  # ============================================================
  services.flatpak.enable = false;

  # ============================================================
  # FUSE (AppImage, etc)
  # ============================================================
  programs.fuse3.enable = true;
}