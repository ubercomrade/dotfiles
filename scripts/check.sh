#!/usr/bin/env bash
# Validate repository structure without installing packages or touching $HOME.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

bash -n "$repo_dir/apply.sh"
bash -n "$repo_dir/install.sh"
bash -n "$repo_dir/arch/install.sh"

if command -v stow >/dev/null; then
    target=$(mktemp -d)
    trap 'rm -rf "$target"' EXIT
    packages=()
    for path in "$repo_dir/shared/stow"/*; do
        [[ -d "$path" ]] && packages+=("$(basename "$path")")
    done
    stow --simulate --dir="$repo_dir/shared/stow" --target="$target" --restow "${packages[@]}"
    for host_dir in "$repo_dir"/hosts/*/arch/stow; do
        [[ -d "$host_dir" ]] || continue
        host_target=$(mktemp -d)
        stow --simulate --dir="$repo_dir/shared/stow" --target="$host_target" --restow "${packages[@]}"
        stow --simulate --dir="${host_dir%/stow}" --target="$host_target" --restow stow
        rm -rf "$host_target"
    done
fi

if command -v nix >/dev/null; then
    hardware_config="$repo_dir/hosts/laptop/nixos/hardware-configuration.nix"
    if [[ -f "$hardware_config" ]]; then
        if git -C "$repo_dir" check-ignore --quiet "hosts/laptop/nixos/hardware-configuration.nix"; then
            printf 'NixOS check failed: hardware configuration is ignored by Git.\n' >&2
            exit 1
        fi
        nix flake check "path:$repo_dir"
        nix eval --raw "path:$repo_dir#nixosConfigurations.laptop.config.system.build.toplevel.drvPath" >/dev/null
    else
        printf 'NixOS check skipped: missing %s\n' "$hardware_config" >&2
    fi
fi

printf 'Repository checks passed.\n'
