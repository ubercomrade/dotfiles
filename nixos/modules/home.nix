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
    nautilus
    firefox
    libreoffice-fresh
    gnome-text-editor
    papers
    loupe
    file-roller
    gnome-calculator
    pavucontrol
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
    adwaita-icon-theme
    adwaita-fonts
    dgop
    pixi
    uv
    julia
    neovim
    nodejs_24
    imagemagick
    (python3.withPackages (pythonPackages: with pythonPackages; [
      pynvim
      jupyter-client
      jupytext
      ipykernel
    ]))
    git
    ripgrep
    fd
    lazygit
    pyright
    ruff
    unzip
    tree-sitter
    gcc
    jq
    lua
    qt6Packages.qtdeclarative
    qt6Packages.qt5compat
    qt6Packages.qtsvg
  ];

  systemd.user.services = {
    quickshell = {
      Unit = {
        Description = "Quickshell desktop shell";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        Requisite = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/qs -c niri-hub";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    cliphist = {
      Unit = {
        Description = "Wayland clipboard history";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        Requisite = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  xdg.configFile = {
    "niri/config.kdl".source = "${shared}/niri/.config/niri/config.kdl";
    "niri/host.kdl".source = "${host}/.config/niri/host.kdl";
    "quickshell/niri-hub".source = "${shared}/quickshell/.config/quickshell/niri-hub";
    "kitty/kitty.conf".source = "${shared}/kitty/.config/kitty/kitty.conf";
    "mako/config".source = "${shared}/mako/.config/mako/config";
    "environment.d/desktop.conf".source = "${shared}/environment/.config/environment.d/desktop.conf";
    "gtk-3.0/settings.ini".source = "${shared}/gtk/.config/gtk-3.0/settings.ini";
    "gtk-4.0/settings.ini".source = "${shared}/gtk/.config/gtk-4.0/settings.ini";
    "xdg-desktop-portal/niri-portals.conf".source = "${shared}/portal/.config/xdg-desktop-portal/niri-portals.conf";
    "mimeapps.list".source = "${shared}/mime/.config/mimeapps.list";
    "nvim".source = "${shared}/nvim/.config/nvim";
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    font-name = "Cantarell 11";
    icon-theme = "Adwaita";
    cursor-theme = "Adwaita";
    cursor-size = 24;
  };

  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "gtk3";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    XCURSOR_PATH = "/usr/share/icons:/usr/local/share/icons:/home/${username}/.icons:/home/${username}/.local/share/icons";
  };

  programs.home-manager.enable = true;
}
