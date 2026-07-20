{ lib, username, ... }:
{
  imports = [ ../../../nixos/modules/desktop.nix ]
    ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  assertions = [
    {
      assertion = builtins.pathExists ./hardware-configuration.nix;
      message = "Generate hosts/<name>/nixos/hardware-configuration.nix before rebuilding.";
    }
  ];

  networking.hostName = "replace-me";
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
  };
  users.mutableUsers = true;
  system.stateVersion = "26.05";
}
