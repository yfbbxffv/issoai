{ ... }: {
  users.users.gamer = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "video" "render" "input" "audio" "networkmanager" ];
  };
  security.sudo.wheelNeedsPassword = false;
  services.getty.autologinUser = "gamer";
}