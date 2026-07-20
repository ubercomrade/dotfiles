#!/usr/bin/env bash
# Validate repository structure without installing packages or touching $HOME.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
skipped=()

bash -n "$repo_dir/apply.sh"
bash -n "$repo_dir/install.sh"
bash -n "$repo_dir/arch/install.sh"

[[ -f "$repo_dir/flake.lock" ]]
[[ -f "$repo_dir/shared/stow/nvim/.config/nvim/lazy-lock.json" ]]

if command -v jq >/dev/null; then
    while IFS= read -r -d '' file; do
        jq empty "$file"
    done < <(find "$repo_dir/shared/stow/zed" "$repo_dir/shared/stow/nvim" -type f -name '*.json' -print0)
else
    skipped+=("JSON validation")
fi

if command -v luac >/dev/null; then
    while IFS= read -r -d '' file; do
        luac -p "$file"
    done < <(find "$repo_dir/shared/stow/nvim" -type f -name '*.lua' -print0)
else
    skipped+=("Lua validation")
fi

if command -v qmllint >/dev/null; then
    if ! qml_output=$(qmllint "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml" 2>&1); then
        if [[ -n "$qml_output" ]]; then
            printf '%s\n' "$qml_output" >&2
            exit 1
        fi
        skipped+=("QML validation: qmllint could not initialize")
    fi
else
    skipped+=("QML validation")
fi

if command -v stow >/dev/null; then
    target=$(mktemp -d)
    trap 'rm -rf "$target"' EXIT
    packages=()
    for path in "$repo_dir/shared/stow"/*; do
        [[ -d "$path" ]] && packages+=("$(basename "$path")")
    done
    for host_dir in "$repo_dir"/hosts/*/arch/stow; do
        [[ -d "$host_dir" ]] || continue
        host_name=$(basename "$(dirname "$(dirname "$host_dir")")")
        host_target="$target/$host_name"
        mkdir -p "$host_target"
        stow --no-folding --dir="$repo_dir/shared/stow" --target="$host_target" --restow "${packages[@]}"
        mkdir -p "$host_target/.config/niri"
        ln -s "$host_dir/.config/niri/host.kdl" "$host_target/.config/niri/host.kdl"
        [[ -L "$host_target/.config/niri/config.kdl" && -L "$host_target/.config/niri/host.kdl" ]]
        if command -v niri >/dev/null; then
            niri validate --config "$host_target/.config/niri/config.kdl"
        fi
    done
    command -v niri >/dev/null || skipped+=("Niri validation")
else
    skipped+=("Stow deployment")
    skipped+=("Niri validation")
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
        skipped+=("NixOS: missing $hardware_config")
    fi
else
    skipped+=("NixOS: nix is unavailable")
fi

if ((${#skipped[@]})); then
    printf 'Available repository checks passed. Skipped: %s' "${skipped[0]}"
    for check in "${skipped[@]:1}"; do
        printf ', %s' "$check"
    done
    printf '\n'
else
    printf 'Repository checks passed.\n'
fi
