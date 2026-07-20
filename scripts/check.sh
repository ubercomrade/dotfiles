#!/usr/bin/env bash
# Validate syntax and exercise deployment in an isolated temporary home.
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

    migration_target="$target/existing-home"
    mock_bin="$target/mock-bin"
    mkdir -p "$mock_bin"
    printf '%s\n' '#!/usr/bin/env bash' '[[ -z "${MOCK_SYSTEMCTL_LOG:-}" ]] || printf "%s\\n" "$*" >> "$MOCK_SYSTEMCTL_LOG"' \
        'if [[ "$1" == "is-enabled" ]]; then' \
        '    if [[ "${MOCK_LY_STATE:-existing}" == "existing" && "$2" == "ly@tty1.service" ]]; then printf "enabled\\n"; exit 0; fi' \
        '    if [[ "${MOCK_LY_STATE:-existing}" == "kms" && "$2" == "ly-kmsconvt@tty1.service" ]]; then printf "enabled\\n"; exit 0; fi' \
        '    printf "disabled\\n"; exit 1' \
        'fi' \
        'if [[ "$1" == "is-active" ]]; then printf "inactive\\n"; exit 1; fi' \
        'exit 0' > "$mock_bin/systemctl"
    printf '%s\n' '#!/usr/bin/env bash' 'exec "$@"' > "$mock_bin/sudo"
    chmod +x "$mock_bin/systemctl" "$mock_bin/sudo"

    mkdir -p "$migration_target/.config/nvim" "$migration_target/.config/quickshell/ii"
    touch "$migration_target/.config/nvim/init.lua" "$migration_target/.config/quickshell/ii/shell.qml"
    PATH="$mock_bin:$PATH" HOME="$migration_target" \
        "$repo_dir/arch/install.sh" --host laptop --niri-config
    [[ -f "$migration_target/.config/nvim/init.lua" ]]
    [[ -f "$migration_target/.config/quickshell/ii/shell.qml" ]]
    [[ -L "$migration_target/.config/niri/config.kdl" ]]
    [[ -L "$migration_target/.config/niri/host.kdl" ]]

    if PATH="$mock_bin:$PATH" HOME="$migration_target" \
        "$repo_dir/arch/install.sh" --host laptop >/dev/null 2>&1; then
        printf 'Arch installer accepted a command without an action.\n' >&2
        exit 1
    fi

    foreign_target="$target/foreign-home"
    mkdir -p "$foreign_target/.config/niri"
    ln -s /tmp/custom-host.kdl "$foreign_target/.config/niri/host.kdl"
    if PATH="$mock_bin:$PATH" HOME="$foreign_target" \
        "$repo_dir/arch/install.sh" --host laptop --niri-config >/dev/null 2>&1; then
        printf 'Arch installer replaced an unmanaged host configuration.\n' >&2
        exit 1
    fi
    [[ ! -e "$foreign_target/.config/niri/config.kdl" ]]

    if [[ -f /etc/arch-release ]]; then
        service_log="$target/systemctl.log"
        MOCK_SYSTEMCTL_LOG="$service_log" MOCK_LY_STATE=existing PATH="$mock_bin:$PATH" \
            "$repo_dir/arch/install.sh" --host laptop --enable-services >/dev/null
        if grep -q 'enable ly@tty2.service' "$service_log"; then
            printf 'Arch installer replaced an existing Ly service.\n' >&2
            exit 1
        fi

        : > "$service_log"
        MOCK_SYSTEMCTL_LOG="$service_log" MOCK_LY_STATE=kms PATH="$mock_bin:$PATH" \
            "$repo_dir/arch/install.sh" --host laptop --enable-services >/dev/null
        if grep -q 'enable ly@tty2.service' "$service_log"; then
            printf 'Arch installer replaced an existing Ly kmsconvt service.\n' >&2
            exit 1
        fi

        : > "$service_log"
        MOCK_SYSTEMCTL_LOG="$service_log" MOCK_LY_STATE=none PATH="$mock_bin:$PATH" \
            "$repo_dir/arch/install.sh" --host laptop --enable-services >/dev/null
        grep -q 'enable ly@tty2.service' "$service_log"
        grep -q 'disable getty@tty2.service' "$service_log"
    else
        skipped+=("Arch service routing")
    fi

    command -v niri >/dev/null || skipped+=("Niri validation")
else
    skipped+=("Stow deployment")
    skipped+=("Niri validation")
fi

if command -v nix >/dev/null; then
    nix_host_output=$(nix eval --raw "path:$repo_dir#nixosConfigurations" \
        --apply 'configs: builtins.concatStringsSep "\n" (builtins.attrNames configs)')
    nix_hosts=()
    if [[ -n "$nix_host_output" ]]; then
        mapfile -t nix_hosts <<< "$nix_host_output"
    fi
    checked_nix_host=false
    missing_nix_hardware=false
    for nix_host in "${nix_hosts[@]}"; do
        [[ -n "$nix_host" ]] || continue
        hardware_config="$repo_dir/hosts/$nix_host/nixos/hardware-configuration.nix"
        if [[ ! -f "$hardware_config" ]]; then
            skipped+=("NixOS $nix_host: missing $hardware_config")
            missing_nix_hardware=true
            continue
        fi
        if git -C "$repo_dir" check-ignore --quiet "hosts/$nix_host/nixos/hardware-configuration.nix"; then
            printf 'NixOS check failed: hardware configuration is ignored by Git: %s\n' "$hardware_config" >&2
            exit 1
        fi
        nix eval --raw \
            "path:$repo_dir#nixosConfigurations.\"$nix_host\".config.system.build.toplevel.drvPath" >/dev/null
        checked_nix_host=true
    done
    if ((${#nix_hosts[@]} == 0)); then
        skipped+=("NixOS: no configurations")
    elif ! $missing_nix_hardware; then
        nix flake check "path:$repo_dir"
    elif ! $checked_nix_host; then
        skipped+=("NixOS: no evaluable configurations")
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
