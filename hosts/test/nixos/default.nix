{ hostName, username, ... }:
{
  imports = [ ../../../nixos/modules/desktop.nix ];

  networking.hostName = hostName;
  boot.loader.systemd-boot.enable = false;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
  };
  users.mutableUsers = true;

  system.stateVersion = "26.05";
}
