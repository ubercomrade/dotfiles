# Minimal niri + Quickshell desktop

One repository for a minimal Qt-oriented Wayland desktop on Arch Linux or NixOS. It uses niri, Quickshell, Kitty, Dolphin, Firefox, LibreOffice, and KDE utilities. Pixi, Julia, Zed, Neovim, and Node.js LTS are installed on both systems.

## Layout

- `shared/stow/` is the only source of user configuration files.
- `arch/` contains the Pacman manifest and the Stow-based installer.
- `nixos/` contains a NixOS 26.05 flake and the Home Manager configuration.
- `apply.sh` selects the deployment target.

Do not manage the same `$HOME` with both targets. In dual boot, use separate home directories or deploy only one target to a shared home.

## Prerequisites

Both targets assume a 64-bit UEFI laptop, an active internet connection, and a partitioned, mounted target filesystem. Disk partitioning, encryption, GPU driver selection, and secure boot enrollment are intentionally outside this repository.

### Arch Linux

Install Arch base with systemd first. Create the regular user that will own the dotfiles, grant it `sudo` access through the `wheel` group, and connect to the network. The Arch installer configures the graphical stack, NetworkManager, Bluetooth, and Ly; it does not create users or configure a bootloader.

### NixOS

The NixOS host in this repository assumes UEFI, `Asia/Novosibirsk`, `en_US.UTF-8`, US console keymap, host name `laptop`, and user `anton`. From the NixOS installation ISO, mount the target root at `/mnt`, mount the EFI system partition, then prepare and install the flake:

```sh
nixos-generate-config --root /mnt
git clone https://github.com/ubercomrade/dotfiles.git /mnt/etc/nixos/dotfiles
cp /mnt/etc/nixos/hardware-configuration.nix \
  /mnt/etc/nixos/dotfiles/nixos/hosts/laptop/hardware-configuration.nix
nixos-install --flake /mnt/etc/nixos/dotfiles/nixos#laptop
nixos-enter --root /mnt -c 'passwd anton'
```

Set the root password when `nixos-install` prompts for it. The generated hardware configuration belongs in version control because it is required to reproduce the machine and contains no credentials.

## Installer choices

- **Arch:** use the official ISO and `archinstall`. Select UEFI/GPT, NetworkManager, your CPU microcode, a sudo-enabled user, and **No desktop**. Use LUKS on a laptop; select `systemd-boot` for a single-boot UEFI installation. The repository installs niri and all desktop packages later.
- **NixOS:** use the graphical ISO for the first installation and select **No desktop**. It is the simplest way to set up disks, LUKS, Wi-Fi, timezone, and the `anton` user. Use the minimal ISO only when you want to configure partitioning and mounting manually.

## Arch Linux

On a console-only Arch installation, install Git once, clone the repository, then apply the Arch target:

```sh
sudo pacman -Syu git
git clone https://github.com/ubercomrade/dotfiles.git
cd dotfiles
./apply.sh --os arch --packages --stow --enable-services
```

The optional `--enable-services` step enables NetworkManager, Bluetooth, and Ly on tty2. It disables `getty@tty2`, as required by Ly.

To update only user config:

```sh
./apply.sh --os arch --stow
```

## NixOS

Install NixOS 26.05 normally, clone this repository, and generate hardware configuration on the target machine:

```sh
git clone https://github.com/ubercomrade/dotfiles.git
cd dotfiles
nixos-generate-config --show-hardware-config > nixos/hosts/laptop/hardware-configuration.nix
git add nixos/hosts/laptop/hardware-configuration.nix
nix flake lock path:./nixos
./apply.sh --os nixos --host laptop
sudo passwd anton
```

The NixOS target declaratively enables niri, Ly, NetworkManager, Bluetooth, PipeWire/WirePlumber, portals, polkit, and the user environment managed by Home Manager.

The host name, user name, locale, disk layout, and hardware settings remain deliberately host-specific. Change `nixos/hosts/laptop/configuration.nix` before the first rebuild if `laptop` or `anton` are not correct. The laptop host assumes UEFI, `Asia/Novosibirsk`, `en_US.UTF-8`, and an US console keymap. Generate and commit `hardware-configuration.nix`; it contains no secrets and is necessary to reproduce the host.

## Main bindings

| Binding | Action |
| --- | --- |
| `Super+D` | Open the application launcher |
| `Super+Return` | Open Kitty |
| `Super+E` | Open Dolphin |
| `Super+W` | Open Firefox |
| `Super+Q` | Close focused window |
| `Super+1` to `Super+9` | Focus workspace |
| `Super+Shift+1` to `Super+Shift+9` | Move focused window to workspace |
| `Super+L` | Lock session |
| `Print` | Interactive screenshot |
| `Ctrl+Space` | Toggle US/RU keyboard layout |

## Displays and Portals

The shared niri configuration contains the current laptop outputs: `eDP-1` and `HDMI-A-1`. Adjust their names, modes, scales, and positions for another machine with `niri msg outputs`.

niri disables the laptop panel when the lid closes while an external monitor remains active. The GTK and GNOME portal backends are technical dependencies: GTK is the fallback portal and GNOME supplies screencasting. The configuration routes file chooser requests through GTK, so Nautilus is not required.

## Validate

```sh
./scripts/check.sh
```

The script validates shell syntax and simulates an Arch Stow deployment in a temporary directory when Stow is available. On NixOS, additionally run:

```sh
nix flake check ./nixos
nixos-rebuild build --flake ./nixos#laptop
```
