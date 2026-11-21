{ config, pkgs, ... }:

{
  # Usuário único: gamer (UID 1000)
  users.users.gamer = {
    isNormalUser = true;
    uid = 1000;
    description = "Gamer";
    group = "gamer";
    home = "/home/gamer";
    createHome = true;
    useDefaultShell = true;
    shell = pkgs.fish; # ou pkgs.zsh

    # Grupos necessários para gaming/hardware
    extraGroups = [
      "wheel"        # sudo
      "video"        # DRM/KMS, GPU
      "render"       # Render nodes (Vulkan/OpenCL)
      "input"        # Dispositivos de input (gamepads, teclado)
      "audio"        # Áudio
      "kvm"          # Virtualização (se precisar)
      "libvirt"      # Libvirt
      "docker"       # Docker (se usar containers)
      "networkmanager" # Rede (se usar NM)
      "plugdev"      # Dispositivos USB
      "tty"          # TTY access
    ];

    # Senha: defina no primeiro boot com `passwd`
    # Ou use hashedPassword se quiser pré-definir
    # hashedPassword = "$6$...";
  };

  # Grupo gamer
  users.groups.gamer = {
    gid = 1000;
    members = [ "gamer" ];
  };

  # Autologin no TTY1 (sem display manager)
  systemd.services.getty@tty1.override = {
    ServiceConfig = {
      ExecStart = "-/run/current-system/sw/bin/agetty --autologin gamer --noclear %I \$TERM";
      Type = "idle";
    };
  };

  # Sudo sem senha para gamer (single user, owner)
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    configFile = {
      "gamer ALL=(ALL) NOPASSWD: ALL" = "";
    };
  };

  # Polkit: passwordless para gamer
  security.polkit.enable = true;
  security.polkit.rules = [
    "polkit.addRule(function(action, subject) { if (subject.user == \"gamer\") return polkit.Result.YES; });"
  ];

  # Limite de arquivos abertos (para jogos com muitos assets)
  security.login.lockDownUserCommands = false;
  security.login.maxOpenFiles = 1048576;
}