# Laptop example profile

> Last reviewed: 2026-07-20

This personal example is not a universal default. It assumes:

- hostname `laptop` and user selected by the `flake.nix` host entry;
- `x86_64-linux` with UEFI and systemd-boot;
- timezone `Asia/Novosibirsk`, locale `en_US.UTF-8`, and US console keymap;
- internal `eDP-1` at `2520x1680@90` with scale `1.5`;
- external `HDMI-A-1` at `1920x1080@60`.

The repository contains only `nixos/hardware-configuration.nix.example`. Generate the real `hardware-configuration.nix` on the target NixOS machine before evaluating or switching this host:

```sh
nixos-generate-config --show-hardware-config \
  > hosts/laptop/nixos/hardware-configuration.nix
```

Review generated filesystem UUIDs, labels, and device metadata before committing the file. Regenerate it only after storage or other kernel-relevant hardware changes.

Stage the generated file before using a plain `.` flake reference, or evaluate with `path:$PWD` so Nix includes untracked host files.

Update `arch/stow/.config/niri/host.kdl` after changing display hardware. Use `niri msg outputs` to obtain current output names and modes.
