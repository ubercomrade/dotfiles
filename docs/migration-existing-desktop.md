# Migrating an existing Arch desktop

> Last reviewed: 2026-07-23

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
```

At minimum, review existing Niri, Quickshell, Mako, GTK, and portal paths. The installer refuses conflicting regular files and unmanaged `host.kdl` links, but Stow may create some links before encountering a later conflict.

Preview the limited deployment:

```sh
./apply.sh plan niri generic
```

This prints package, Stow, and service effects without changing the system.

## Install beside the current desktop

Use `generic` until a host-specific output file has been checked:

```sh
./apply.sh niri generic
niri validate --config "$HOME/.config/niri/config.kdl"
```

The package action performs a full Arch system upgrade with `pacman -Syu`, then installs missing Niri runtime packages. The config action does not manage Hyprland, Sway, Kitty, Neovim, MIME, or other application configuration outside the limited Niri profile.

The limited deployment adds `~/.config/quickshell/niri-hub` beside other Quickshell profiles. It does not remove them. On first launch, Niri Hub imports compatible appearance and monitor settings from the old `minimal-shell` runtime state when its own state file does not exist.

## Test the session

Use the display manager's Niri entry or run `niri-session` from a TTY. Do not remove the previous compositor or its session entry yet.

Check at least:

- internal and external outputs;
- `Ctrl+Space` keyboard-layout switching and configured bindings;
- `Super+D` Niri Hub application search and system pages;
- `Super+V` clipboard history, refresh, copy, and delete, with `cliphist.service` active;
- Wi-Fi and Bluetooth discovery, connection, and pairing prompts;
- `Super+Shift+M` desktop system monitor;
- `Super+Shift+/` shortcut overlay and Escape dismissal;
- `Super+L` locking and unlock recovery;
- suspend and lid handling;
- Quickshell and Mako startup;
- audio, brightness, screenshots, and clipboard;
- file chooser and screencast portals;
- X11 applications through Xwayland Satellite.

Portal and notification tests are most reliable after logging out of every other graphical session. Two compositors under the same user can share a systemd user manager and leave the previous portal backend or notification service running.

## Display managers

`services` manages only NetworkManager and Bluetooth. Enable Ly separately with `ly`; it refuses to proceed while `display-manager.service`, SDDM, GDM, LightDM, or greetd is active or enabled. When no display manager or Ly instance exists, it enables `ly@tty2` and disables `getty@tty2`.

Ly can remember the last selected session when its `save` setting is enabled. This is display-manager configuration, not shell startup; Fish, Zsh, and Bash files do not need to launch Niri.

## Adopt more configuration

After the Niri-only setup is stable, preview the remaining Stow packages before using the complete deployment:

```sh
stow --simulate --no-folding \
  --dir="$PWD/shared/stow" \
  --target="$HOME" \
  gtk kitty mako mime niri nvim portal quickshell systemd
```

Then explicitly opt in:

```sh
./apply.sh full generic
```

Move or merge conflicting application files manually. Do not delete an existing configuration merely to make Stow succeed unless its backup has been verified.

## Roll back

Select the previous compositor in the display manager. To remove only the limited Niri deployment:

```sh
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
backup=$(cat "$state_dir/migration-backup")
host_link="$HOME/.config/niri/host.kdl"
host_target=$(readlink "$host_link" 2>/dev/null || true)
case "$host_target" in
  "$PWD"/hosts/*/arch/stow/.config/niri/host.kdl) rm -f "$host_link" ;;
esac
stow --delete --no-folding \
  --dir="$PWD/shared/stow" \
  --target="$HOME" \
   niri quickshell mako gtk portal systemd
```

Restore conflicting files from the backup as needed. After verifying the rollback, remove `$state_dir/migration-backup`. Pacman packages and tools installed outside Stow remain installed and should be reviewed separately before removal.

Shell consolidation is intentionally a separate task. First inventory PATH entries, language managers, aliases, and secrets, then migrate them to the selected shell without coupling that change to the compositor rollback path.
