{ lib, ... }:
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
  system.stateVersion = "26.05";
}
