# Migrating an existing Arch desktop

> Last reviewed: 2026-07-20

This runbook adds Niri beside an existing compositor without adopting every application configuration in the repository. Keep the current desktop installed and working until Niri has passed a clean-session test.

## Before migration

Clone the repository to a permanent path and back up existing configuration:

```sh
backup="$HOME/config-backup-$(date +%Y%m%d-%H%M%S)"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
mkdir -p "$backup"
mkdir -p "$state_dir"
printf '%s\n' "$backup" > "$state_dir/migration-backup"
cp -a "$HOME/.config" "$backup/"
systemctl --user is-enabled polkit-kde-agent.service \
  > "$backup/polkit-kde-agent.state" 2>&1 || true
```

At minimum, review existing Niri, Quickshell, Mako, portal, and user systemd paths. The installer refuses conflicting regular files and unmanaged `host.kdl` links, but Stow may create some links before encountering a later conflict.

Preview the limited deployment:

```sh
stow --simulate --no-folding \
  --dir="$PWD/shared/stow" \
  --target="$HOME" \
  niri quickshell mako portal systemd
```

This previews only Stow links. The installer separately manages `host.kdl` and enables the user Polkit service.

## Install beside the current desktop

Use `generic` until a host-specific output file has been checked:

```sh
./apply.sh --os arch --host generic --niri-packages
./apply.sh --os arch --host generic --niri-config
niri validate --config "$HOME/.config/niri/config.kdl"
```

The package action performs a full Arch system upgrade with `pacman -Syu`, then installs missing Niri runtime packages. The config action does not manage Hyprland, Sway, KDE, GNOME, Kitty, Neovim, Zed, MIME, or other application configuration.

The limited deployment adds `~/.config/quickshell/minimal` beside other Quickshell profiles. It does not remove them.

## Test the session

Use the display manager's Niri entry or run `niri-session` from a TTY. Do not remove the previous compositor or its session entry yet.

Check at least:

- internal and external outputs;
- keyboard layout and configured bindings;
- `Super+L` locking and unlock recovery;
- suspend and lid handling;
- Quickshell and Mako startup;
- audio, brightness, screenshots, and clipboard;
- file chooser and screencast portals;
- X11 applications through Xwayland Satellite.

Portal and notification tests are most reliable after logging out of every other graphical session. Two compositors under the same user can share a systemd user manager and leave the previous portal backend or notification service running.

## Display managers

`--enable-services` manages only NetworkManager and Bluetooth. Enable Ly separately with `--enable-ly`; it refuses to proceed while `display-manager.service`, SDDM, GDM, LightDM, or greetd is active or enabled. When no display manager or Ly instance exists, it enables `ly@tty2` and disables `getty@tty2`.

Ly can remember the last selected session when its `save` setting is enabled. This is display-manager configuration, not shell startup; Fish, Zsh, and Bash files do not need to launch Niri.

## Adopt more configuration

After the Niri-only setup is stable, preview the remaining Stow packages before using the complete deployment:

```sh
stow --simulate --no-folding \
  --dir="$PWD/shared/stow" \
  --target="$HOME" \
  kde kitty mako mime niri nvim portal quickshell systemd zed
```

Then explicitly opt in:

```sh
./apply.sh --os arch --host generic --packages --stow
```

Move or merge conflicting application files manually. Do not delete an existing configuration merely to make Stow succeed unless its backup has been verified.

## Roll back

Select the previous compositor in the display manager. To remove only the limited Niri deployment:

```sh
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
backup=$(cat "$state_dir/migration-backup")
polkit_state=$(cat "$backup/polkit-kde-agent.state")
case "$polkit_state" in
  enabled|enabled-runtime|linked|linked-runtime) ;;
  *) systemctl --user disable polkit-kde-agent.service ;;
esac
host_link="$HOME/.config/niri/host.kdl"
host_target=$(readlink "$host_link" 2>/dev/null || true)
case "$host_target" in
  "$PWD"/hosts/*/arch/stow/.config/niri/host.kdl) rm -f "$host_link" ;;
esac
stow --delete --no-folding \
  --dir="$PWD/shared/stow" \
  --target="$HOME" \
  niri quickshell mako portal systemd
systemctl --user daemon-reload
```

Restore conflicting files from the backup as needed. After verifying the rollback, remove `$state_dir/migration-backup`. Pacman packages and tools installed outside Stow remain installed and should be reviewed separately before removal.

Shell consolidation is intentionally a separate task. First inventory PATH entries, language managers, aliases, and secrets, then migrate them to the selected shell without coupling that change to the compositor rollback path.
