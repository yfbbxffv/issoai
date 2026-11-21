{ config, pkgs, ... }: {
  system.stateVersion = "26.05";

  imports = [
    ./hardware-configuration.nix
    ../../disko.nix
    ../../modules/boot.nix
    ../../modules/users.nix
    ../../modules/graphics.nix
    ../../modules/storage.nix
  ];

  networking.hostName = "mypc";
  networking.networkmanager.enable = true;

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "pt_BR.UTF-8";
  console.keyMap = "br-abnt2";

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  environment.systemPackages = with pkgs; [
    git curl wget htop btop pciutils smartmontools btrfs-progs
  ];
}