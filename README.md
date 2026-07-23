# Niri + Quickshell dotfiles

> Last reviewed: 2026-07-20

Opinionated dotfiles for a minimal Qt-oriented Wayland desktop built around Niri and Quickshell. The repository supports Arch Linux and NixOS, separates shared user configuration from host-specific hardware settings, and can deploy either only the Niri session or the complete desktop environment.

This is a personal configuration intended to be reviewed and adapted before use. It is not a general-purpose operating system installer.

## Supported systems

- Arch Linux with systemd and packages from the official repositories.
- NixOS 26.05 with flakes and Home Manager.
- `x86_64-linux` by default; another Nix system can be set per host in `flake.nix`.

Disk partitioning, encryption, GPU drivers, Secure Boot, Arch bootloader setup, secrets, and interactive shell configuration are outside the repository's scope. The NixOS host modules declare a mutable user but do not set its password; run `passwd <username>` before logging out.

## Repository layout

| Path | Purpose |
| --- | --- |
| `shared/stow/` | Host-independent but opinionated user configuration |
| `hosts/` | Arch display profiles and NixOS host modules |
| `arch/packages/` | Minimal Niri and complete desktop Pacman manifests |
| `nixos/modules/` | Shared NixOS and Home Manager modules |
| `apply.sh` | Arch/NixOS deployment entrypoint |
| `scripts/check.sh` | Static, Stow, Niri, and Nix validation |

## Before you run

1. Review the package manifests, Stow packages, host profile, and scripts before granting `sudo` access.
2. Back up any paths under `$HOME` that this repository will manage. Existing regular files and unmanaged `host.kdl` links are refused, but repository-managed links may be updated.
3. Clone the repository to a permanent location. Stow and `host.kdl` use links into the checkout; moving or deleting it breaks deployed configuration.
4. Use `generic` on Arch until a host-specific display profile has been reviewed. For NixOS, create a host from `_template` instead of using the included `laptop` profile.

Do not manage the same shared `$HOME` with both Arch/Stow and NixOS/Home Manager. In a dual-boot setup, use separate home directories or let only one target own these configuration paths.

Stow refuses to replace existing regular files, but an operation can still be partially applied before a later conflict. Preview the limited Niri deployment with:

```sh
stow --simulate --no-folding \
  --dir="$PWD/shared/stow" \
  --target="$HOME" \
  niri quickshell mako portal systemd
```

This previews only Stow links. It does not create `host.kdl` or enable the user Polkit service.

## Arch quick start

Install Git, clone to a permanent path, then start the guided installer:

```sh
sudo pacman -Syu git
git clone https://github.com/ubercomrade/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./apply.sh
niri validate --config "$HOME/.config/niri/config.kdl"
```

On Arch, the wizard defaults to the full package and dotfile deployment, asks separately before enabling NetworkManager/Bluetooth or Ly, prints the plan, then requires confirmation. Select Niri in an existing display manager, or run `niri-session` from a TTY. Keep the previous desktop available until locking, suspend, notifications, portals, audio, and displays have been tested after a clean login.

Use explicit commands for repeatable or noninteractive deployment:

```sh
./apply.sh full              # packages and all dotfiles
./apply.sh niri              # Niri session beside an existing desktop
./apply.sh config laptop     # refresh all dotfiles for a host
./apply.sh plan full laptop  # inspect without changing the system
```

System services remain separate opt-ins:

```sh
./apply.sh services
./apply.sh ly
```

`services` enables NetworkManager and Bluetooth. `ly` refuses to proceed when a known display manager is active or enabled; when safe, it enables Ly on tty2 and disables `getty@tty2`.

See [`docs/migration-existing-desktop.md`](docs/migration-existing-desktop.md) before applying the repository over an existing desktop configuration.

## NixOS quick start

The public checkout is not a ready-to-switch NixOS configuration: the included `laptop` output requires a machine-generated hardware file. Create a host and replace the example output in `flake.nix` before evaluating the flake:

```sh
cp -R hosts/_template hosts/myhost
nixos-generate-config --show-hardware-config \
  > hosts/myhost/nixos/hardware-configuration.nix
```

Then:

1. Edit `hosts/myhost/nixos/default.nix` for hostname, boot, locale, timezone, user groups, and the original NixOS `system.stateVersion`.
2. Edit `hosts/myhost/arch/stow/.config/niri/host.kdl` for its outputs.
3. Replace the `laptop` entry in `flake.nix` with a `mkHost` entry for `myhost`, including the username, system architecture, and original Home Manager state version.
4. Review the generated hardware file before committing it; it contains machine-specific filesystem and device metadata.
5. Evaluate and build before activation:

```sh
nix flake check "path:$PWD"
./apply.sh build myhost
./apply.sh test myhost
./apply.sh switch myhost
```

The `build` action does not activate the configuration. The optional `test` action activates it until reboot without making it the boot default. Run `switch` only after that test succeeds. The interactive NixOS wizard selects `build` by default.

The `path:$PWD` form includes newly created host files before they are staged. Alternatively, add the host and hardware files to Git before using a plain `.` flake reference.

Keep `system.stateVersion` and `home.stateVersion` at the release used for the original installation rather than automatically raising them during an upgrade.

## Deployment commands

| Command | Effects |
| --- | --- |
| `./apply.sh` | Starts the interactive installer on a TTY |
| `full [HOST]` | Runs `pacman -Syu --needed` for complete manifests, installs Jupytext through `uv` when needed, and stows every package |
| `niri [HOST]` | Runs `pacman -Syu --needed` for the Niri manifest and deploys the Niri session configuration |
| `config [HOST]` | Stows every package without installing packages |
| `services` | Enables NetworkManager and Bluetooth |
| `ly` | Enables Ly on tty2 only when no display manager or Ly instance is active |
| `build HOST` | Builds a NixOS host without activation |
| `test HOST` | Activates a NixOS host until reboot |
| `switch HOST` | Activates a NixOS host permanently |
| `plan COMMAND ...` | Prints the effects of a command without changing the system |

Running `./apply.sh` without a terminal prints usage and changes nothing. Explicit commands never ask interactive questions. Pacman and Nix commands access the network; the first Neovim start can also download plugins pinned by `lazy-lock.json`.

Before Stow changes `$HOME`, the Arch installer checks every file it will manage. Repository-managed links are updated normally; for an existing unrelated file or link, an interactive run asks whether to replace it. Declining any replacement cancels the deployment without deleting conflicts. A noninteractive run refuses conflicts and leaves them untouched.

## Managed configuration

The complete Stow deployment manages these packages:

| Package | Main target |
| --- | --- |
| `niri` | `~/.config/niri/config.kdl` |
| `quickshell` | `~/.config/quickshell/minimal/` |
| `mako` | `~/.config/mako/config` |
| `portal` | `~/.config/xdg-desktop-portal/niri-portals.conf` |
| `systemd` | User Polkit service |
| `kitty` | Kitty configuration |
| `kde` | KDE and qt6ct appearance |
| `mime` | Default application associations |
| `nvim` | Neovim and LazyVim configuration |
| `zed` | Zed settings, keymap, and snippets |

The `niri` preset deploys only the Niri session packages: Niri, Quickshell, Mako, portal, and the user Polkit service. Shared settings include a GNOME-like Quickshell panel on every output, a focused-output launcher on `Super+D`, a shortcut overlay on `Super+Shift+/`, US/RU layouts switched with `Ctrl+Space`, natural touchpad scrolling, Noto fonts, Kitty-oriented notebook rendering, and Python-focused editor defaults. The launcher provides application search, shell commands, and clipboard history through `cliphist`.

## Host customization

- `hosts/generic` has no output rules and is the safe Arch starting point.
- `hosts/_template` is the starting point for a new Arch or NixOS host.
- `hosts/laptop` is a personal example and must not be applied unchanged to another machine.

Keep host profiles in version control, but do not put passwords, Wi-Fi credentials, API keys, private keys, or other secrets in them.

## Validation

Run the available repository checks with:

```sh
./scripts/check.sh
```

The script reports tools and checks that were skipped. `Available repository checks passed` means only the checks available on that machine succeeded; it does not imply that NixOS, Niri, QML, JSON, Lua, and Stow were all evaluated.

Use `CI=1 ./scripts/check.sh` when all required tools are installed to reject skipped validation. The flake also exposes a synthetic `test` configuration for evaluating shared NixOS and Home Manager modules without personal hardware data.

Before a NixOS switch, also build the selected host explicitly as shown in the NixOS quick start.

## Recovery and removal

For a limited Arch deployment, remove managed Stow links from the same checkout path:

```sh
unit_link="$HOME/.config/systemd/user/polkit-kde-agent.service"
unit_target=$(readlink -f -- "$unit_link" 2>/dev/null || true)
case "$unit_target" in
  "$PWD"/shared/stow/systemd/*) systemctl --user disable polkit-kde-agent.service ;;
esac
host_link="$HOME/.config/niri/host.kdl"
host_target=$(readlink -f -- "$host_link" 2>/dev/null || true)
case "$host_target" in
  "$PWD"/hosts/*/arch/stow/.config/niri/host.kdl) rm -f "$host_link" ;;
esac
stow --delete --no-folding \
  --dir="$PWD/shared/stow" \
  --target="$HOME" \
  niri quickshell mako portal systemd
systemctl --user daemon-reload
```

Unmanaged Polkit and `host.kdl` links are left untouched. The Stow command removes all links for the selected packages from this checkout, including links created by an earlier deployment. Stow removal does not uninstall Pacman packages or remove tools installed by `uv`.

If this repository created Ly on tty2, restore the console with:

```sh
sudo systemctl disable ly@tty2.service
sudo systemctl enable getty@tty2.service
```

Do not run those commands when Ly was already managed on another tty. NetworkManager and Bluetooth are not disabled automatically during removal.

For NixOS, select an older generation in the boot menu or use the system rollback mechanism before changing the flake again.

## Additional documentation

- [`docs/migration-existing-desktop.md`](docs/migration-existing-desktop.md): conservative migration from another compositor or desktop.
- [`hosts/laptop/README.md`](hosts/laptop/README.md): assumptions specific to the included laptop example.

## License

[MIT](LICENSE)
