{ pkgs, ... }:
let
  shared = ../../shared/stow;
in
{
  home.username = "anton";
  home.homeDirectory = "/home/anton";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    quickshell
    kitty
    dolphin
    firefox
    libreoffice-fresh
    kate
    okular
    gwenview
    ark
    kcalc
    pavucontrol-qt
    breeze-icons
    qt6ct
    bluez
    brightnessctl
    playerctl
    grim
    slurp
    wl-clipboard
    cliphist
    mako
    swaylock
    swayidle
    xdg-user-dirs
    pixi
    julia
    zed-editor
    neovim
    nodejs_24
    git
    ripgrep
    fd
    lazygit
  ];

  xdg.configFile = {
    "niri/config.kdl".source = "${shared}/niri/.config/niri/config.kdl";
    "quickshell/minimal/shell.qml".source = "${shared}/quickshell/.config/quickshell/minimal/shell.qml";
    "kitty/kitty.conf".source = "${shared}/kitty/.config/kitty/kitty.conf";
    "mako/config".source = "${shared}/mako/.config/mako/config";
    "kdeglobals".source = "${shared}/kde/.config/kdeglobals";
    "qt6ct/qt6ct.conf".source = "${shared}/kde/.config/qt6ct/qt6ct.conf";
    "xdg-desktop-portal/niri-portals.conf".source = "${shared}/portal/.config/xdg-desktop-portal/niri-portals.conf";
    "mimeapps.list".source = "${shared}/mime/.config/mimeapps.list";
    "nvim".source = "${shared}/nvim/.config/nvim";
    "zed".source = "${shared}/zed/.config/zed";
  };

  systemd.user.services.polkit-kde-agent = {
    Unit = {
      Description = "KDE PolicyKit authentication agent";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service.ExecStart = "${pkgs.polkit-kde-agent}/lib/polkit-kde-authentication-agent-1";
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.home-manager.enable = true;
}
