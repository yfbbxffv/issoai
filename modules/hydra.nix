{ config, pkgs, lib, ... }:

{
  # ============================================================
  # HYDRA LAUNCHER - Custom Game Launcher (Rust/Slint)
  # MÓDULO OPCIONAL - enable = false por padrão
  # NOTA: Requer flake com hydra-launcher package
  # Ative com: config.gameos.hydra.enable = true;
  # ============================================================

  options.gameos.hydra = {
    enable = lib.mkEnableOption "Hydra Game Launcher (custom Rust/Slint)";
  };

  config = lib.mkIf config.gameos.hydra.enable {
    # O binário hydra-launcher deve estar disponível via flake
    # Se não estiver, comente esta seção ou adicione ao flake.nix

    systemd.user.services.hydra-launcher = {
      description = "Hydra Game Launcher";
      documentation = "https://github.com/yfbbxffv/issoai";
      after = [ "graphical-session.target" "gamescope-session.service" ];
      wants = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.hydra-launcher}/bin/hydra-launcher";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = "GAMESCOPE=1 WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000";
        StandardOutput = "journal";
        StandardError = "journal";
      };
      wantedBy = [ "graphical-session.target" ];
    };

    # Gamescope session (inicia Wayland compositor + Hydra)
    systemd.user.services.gamescope-session = {
      description = "Gamescope Session for Hydra";
      after = [ "graphical-session-pre.target" ];
      wants = [ "graphical-session-pre.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.gamescope}/bin/gamescope-session-steam-plus";
        Environment = "GAMESCOPE=1 HYDRA=1";
        Restart = "on-failure";
        RestartSec = 3;
        StandardOutput = "journal";
        StandardError = "journal";
      };
      wantedBy = [ "graphical-session.target" ];
    };

    # Target gráfico para user
    systemd.user.graphical-session.target.wantedBy = [ "default.target" ];

    # Auto-start do user session no boot (via user linger)
    systemd.logind.lingerUsers = [ "gamer" ];

    # Variáveis de ambiente para o user session
    environment.variables = {
      WAYLAND_DISPLAY = "wayland-0";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "gamescope";
      XDG_SESSION_DESKTOP = "gamescope";
      QT_QPA_PLATFORM = "wayland;xcb";
      SDL_VIDEODRIVER = "wayland,x11";
      CLUTTER_BACKEND = "wayland";
      ECORE_EVAS_ENGINE = "wayland_egl";
      ELM_DISPLAY = "wl";
      MOZ_ENABLE_WAYLAND = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";

      HYDRA_CONFIG_DIR = "/home/gamer/.config/hydra";
      HYDRA_DATA_DIR = "/home/gamer/.local/share/hydra";
      HYDRA_CACHE_DIR = "/home/gamer/.cache/hydra";

      HYDRA_GAMES_PATH_1 = "/games/1";
      HYDRA_GAMES_PATH_2 = "/games/2";
    };

    # Diretórios do usuário (criados no primeiro login)
    users.users.gamer = {
      extraConfig = ''
        XDG_CONFIG_HOME=/home/gamer/.config
        XDG_DATA_HOME=/home/gamer/.local/share
        XDG_CACHE_HOME=/home/gamer/.cache
        XDG_STATE_HOME=/home/gamer/.local/state
      '';
    };
  };
}