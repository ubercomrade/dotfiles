{ lib, ... }:
{
  imports = [ ../../modules/desktop.nix ]
    ++ lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  assertions = [
    {
      assertion = builtins.pathExists ./hardware-configuration.nix;
      message = "Generate nixos/hosts/laptop/hardware-configuration.nix with nixos-generate-config before rebuilding.";
    }
  ];

  networking.hostName = "laptop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Asia/Novosibirsk";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.anton = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];
  };
  users.mutableUsers = true;

  system.stateVersion = "26.05";
}
