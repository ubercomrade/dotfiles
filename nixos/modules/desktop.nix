{ pkgs, ... }:
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  programs.niri.enable = true;
  programs.niri.useNautilus = false;
  services.displayManager.ly.enable = true;

  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  services.upower.enable = true;

  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };
  environment.systemPackages = [ pkgs.kdePackages.polkit-kde-agent-1 ];
}
