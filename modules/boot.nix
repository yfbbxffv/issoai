{ ... }: {
  boot.loader.systemd-boot = {
    enable = true;
    editor = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.timeout = 5;
}