#!/usr/bin/env bash
# Validate syntax and exercise deployment in an isolated temporary home.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
skipped=()
strict=false
[[ ${CI:-} == "1" || ${CI:-} == "true" ]] && strict=true

require_or_skip() {
    local name="$1"
    if $strict; then
        printf 'Required check unavailable: %s\n' "$name" >&2
        exit 1
    fi
    skipped+=("$name")
}

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
    require_or_skip "JSON validation"
fi

if command -v luac >/dev/null; then
    while IFS= read -r -d '' file; do
        luac -p "$file"
    done < <(find "$repo_dir/shared/stow/nvim" -type f -name '*.lua' -print0)
else
    require_or_skip "Lua validation"
fi

if command -v qmllint >/dev/null; then
    if ! qml_output=$(qmllint "$repo_dir"/shared/stow/quickshell/.config/quickshell/minimal/*.qml 2>&1); then
        if [[ -n "$qml_output" ]]; then
            printf '%s\n' "$qml_output" >&2
            exit 1
        fi
        require_or_skip "QML validation: qmllint could not initialize"
    fi
else
    require_or_skip "QML validation"
fi

grep -q 'target: "launcher"' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'target: "shortcuts"' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'target: "settings"' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'target: "monitor"' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'event-stream' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'LayoutOsd' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'PolkitAgent' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'Material Symbols Rounded' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/Theme.qml"
grep -q 'dgop.*meta' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/MetricsService.qml"
grep -q 'Quickshell.Networking' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/Launcher.qml"
grep -q 'Quickshell.Bluetooth' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/Launcher.qml"
grep -q 'skip-at-startup' "$repo_dir/shared/stow/niri/.config/niri/config.kdl"
! grep -q 'Bar {' "$repo_dir/shared/stow/quickshell/.config/quickshell/minimal/shell.qml"
grep -q 'Ctrl+Space.*switch-layout' "$repo_dir/shared/stow/niri/.config/niri/config.kdl"
grep -q 'Mod+Shift+Slash.*shortcuts' "$repo_dir/shared/stow/niri/.config/niri/config.kdl"
grep -q 'Mod+Comma.*settings' "$repo_dir/shared/stow/niri/.config/niri/config.kdl"
grep -q 'Mod+Shift+M.*monitor' "$repo_dir/shared/stow/niri/.config/niri/config.kdl"
grep -q '^dgop$' "$repo_dir/arch/packages/niri.txt"
grep -q '^ttf-material-symbols-variable$' "$repo_dir/arch/packages/niri.txt"
grep -q '^nautilus$' "$repo_dir/arch/packages/niri.txt"
! grep -Eq 'dolphin|kate|okular|gwenview|ark|kcalc|breeze|polkit-kde' "$repo_dir/arch/packages/common.txt" "$repo_dir/arch/packages/niri.txt" "$repo_dir/nixos/modules/home.nix" "$repo_dir/shared/stow/mime/.config/mimeapps.list"
[[ ! -e "$repo_dir/shared/stow/kde" && ! -e "$repo_dir/shared/stow/systemd/.config/systemd/user/polkit-kde-agent.service" ]]

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
        '    if [[ "${MOCK_DISPLAY_MANAGER_STATE:-none}" == "enabled" && "$2" == "sddm.service" ]]; then printf "enabled\\n"; exit 0; fi' \
        '    if [[ "${MOCK_LY_STATE:-existing}" == "existing" && "$2" == "ly@tty1.service" ]]; then printf "enabled\\n"; exit 0; fi' \
        '    if [[ "${MOCK_LY_STATE:-existing}" == "kms" && "$2" == "ly-kmsconvt@tty1.service" ]]; then printf "enabled\\n"; exit 0; fi' \
        '    printf "disabled\\n"; exit 1' \
        'fi' \
        'if [[ "$1" == "is-active" ]]; then printf "inactive\\n"; exit 1; fi' \
        'exit 0' > "$mock_bin/systemctl"
    printf '%s\n' '#!/usr/bin/env bash' 'exec "$@"' > "$mock_bin/sudo"
    chmod +x "$mock_bin/systemctl" "$mock_bin/sudo"

    mkdir -p "$migration_target/.config/other-app" "$migration_target/.config/quickshell/ii"
    touch "$migration_target/.config/other-app/config" "$migration_target/.config/quickshell/ii/shell.qml"
    PATH="$mock_bin:$PATH" HOME="$migration_target" \
        "$repo_dir/arch/install.sh" laptop config
    [[ -f "$migration_target/.config/other-app/config" ]]
    [[ -f "$migration_target/.config/quickshell/ii/shell.qml" ]]
    [[ -L "$migration_target/.config/niri/config.kdl" ]]
    [[ -L "$migration_target/.config/niri/host.kdl" ]]

    if PATH="$mock_bin:$PATH" HOME="$migration_target" \
        "$repo_dir/arch/install.sh" laptop >/dev/null 2>&1; then
        printf 'Arch installer accepted a command without an action.\n' >&2
        exit 1
    fi

    foreign_target="$target/foreign-home"
    mkdir -p "$foreign_target/.config/niri"
    ln -s /tmp/custom-host.kdl "$foreign_target/.config/niri/host.kdl"
    if PATH="$mock_bin:$PATH" HOME="$foreign_target" \
        "$repo_dir/arch/install.sh" laptop config >/dev/null 2>&1; then
        printf 'Arch installer replaced an unmanaged host configuration.\n' >&2
        exit 1
    fi
    [[ ! -e "$foreign_target/.config/niri/config.kdl" ]]

    conflict_target="$target/conflict-home"
    mkdir -p "$conflict_target/.config/mako"
    touch "$conflict_target/.config/mako/config"
    if PATH="$mock_bin:$PATH" HOME="$conflict_target" \
        "$repo_dir/arch/install.sh" laptop config >/dev/null 2>&1; then
        printf 'Arch installer replaced a conflicting configuration without a terminal.\n' >&2
        exit 1
    fi
    [[ -f "$conflict_target/.config/mako/config" ]]

    linked_conflict_target="$target/linked-conflict-home"
    mkdir -p "$linked_conflict_target/.config" "$target/external-mako"
    ln -s "$target/external-mako" "$linked_conflict_target/.config/mako"
    if PATH="$mock_bin:$PATH" HOME="$linked_conflict_target" \
        "$repo_dir/arch/install.sh" laptop config >/dev/null 2>&1; then
        printf 'Arch installer replaced a conflicting configuration directory link without a terminal.\n' >&2
        exit 1
    fi
    [[ -L "$linked_conflict_target/.config/mako" ]]

    if [[ -f /etc/arch-release ]]; then
        service_log="$target/systemctl.log"
        MOCK_SYSTEMCTL_LOG="$service_log" MOCK_LY_STATE=existing PATH="$mock_bin:$PATH" \
            "$repo_dir/arch/install.sh" laptop ly >/dev/null
        if grep -q 'enable ly@tty2.service' "$service_log"; then
            printf 'Arch installer replaced an existing Ly service.\n' >&2
            exit 1
        fi

        : > "$service_log"
        MOCK_SYSTEMCTL_LOG="$service_log" MOCK_LY_STATE=kms PATH="$mock_bin:$PATH" \
            "$repo_dir/arch/install.sh" laptop ly >/dev/null
        if grep -q 'enable ly@tty2.service' "$service_log"; then
            printf 'Arch installer replaced an existing Ly kmsconvt service.\n' >&2
            exit 1
        fi

        : > "$service_log"
        MOCK_SYSTEMCTL_LOG="$service_log" MOCK_LY_STATE=none PATH="$mock_bin:$PATH" \
            "$repo_dir/arch/install.sh" laptop ly >/dev/null
        grep -q 'enable ly@tty2.service' "$service_log"
        grep -q 'disable getty@tty2.service' "$service_log"

        if MOCK_DISPLAY_MANAGER_STATE=enabled PATH="$mock_bin:$PATH" \
            "$repo_dir/arch/install.sh" laptop ly >/dev/null 2>&1; then
            printf 'Arch installer enabled Ly alongside an existing display manager.\n' >&2
            exit 1
        fi
    else
        require_or_skip "Arch service routing"
    fi

    command -v niri >/dev/null || require_or_skip "Niri validation"
else
    require_or_skip "Stow deployment"
    require_or_skip "Niri validation"
fi

if [[ -f /etc/arch-release ]]; then
    "$repo_dir/apply.sh" plan niri | grep -q 'Niri session manifest'
    "$repo_dir/apply.sh" plan full generic | grep -q 'complete package manifests'
    "$repo_dir/apply.sh" plan services | grep -q 'NetworkManager and Bluetooth'
    if "$repo_dir/apply.sh" </dev/null >/dev/null 2>&1; then
        printf 'Installer accepted a no-action noninteractive invocation.\n' >&2
        exit 1
    fi
fi

for manifest in "$repo_dir"/arch/packages/*.txt; do
    duplicate_packages=$(sort "$manifest" | uniq -d)
    if [[ -n "$duplicate_packages" ]]; then
        printf 'Duplicate package entries in %s:\n%s\n' "$manifest" "$duplicate_packages" >&2
        exit 1
    fi
done
if missing_niri_packages=$(comm -23 <(sed '/^#/d;/^$/d' "$repo_dir/arch/packages/niri.txt" | sort) <(sed '/^#/d;/^$/d' "$repo_dir/arch/packages/common.txt" | sort)); then
    if [[ -n "$missing_niri_packages" ]]; then
        printf 'Niri packages missing from common manifest:\n%s\n' "$missing_niri_packages" >&2
        exit 1
    fi
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
        if [[ "$nix_host" == "test" ]]; then
            nix eval --raw \
                "path:$repo_dir#nixosConfigurations.\"$nix_host\".config.system.build.toplevel.drvPath" >/dev/null
            checked_nix_host=true
            continue
        fi
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
    require_or_skip "NixOS: nix is unavailable"
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
