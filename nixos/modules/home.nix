{ pkgs, homeStateVersion, hostName, username, ... }:
let
  shared = ../../shared/stow;
  host = ../../hosts + "/${hostName}/arch/stow";
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = homeStateVersion;

  home.packages = with pkgs; [
    quickshell
    xwayland-satellite
    kitty
    kdePackages.dolphin
    firefox
    libreoffice-fresh
    kdePackages.kate
    kdePackages.okular
    kdePackages.gwenview
    kdePackages.ark
    kdePackages.kcalc
    pavucontrol
    kdePackages.breeze
    kdePackages.breeze-icons
    qt6Packages.qt6ct
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
    uv
    julia
    zed-editor
    neovim
    nodejs_24
    imagemagick
    (python3.withPackages (pythonPackages: with pythonPackages; [
      pynvim
      jupyter-client
      jupytext
    ]))
    git
    ripgrep
    fd
    lazygit
    pyright
    ruff
  ];

  xdg.configFile = {
    "niri/config.kdl".source = "${shared}/niri/.config/niri/config.kdl";
    "niri/host.kdl".source = "${host}/.config/niri/host.kdl";
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
    Service = {
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.home-manager.enable = true;
}
