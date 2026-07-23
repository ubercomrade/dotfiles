#!/usr/bin/env bash
# Internal Arch deployment backend. Invoke through ../apply.sh.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install_full=false
install_niri=false
install_config=false
enable_services=false
enable_ly=false
host=""
stow_packages=()
stow_conflicts=()
declare -A stow_conflict_seen=()

usage() {
    cat <<'EOF'
Usage: ./arch/install.sh HOST {full|niri|config|services|ly}...

Existing regular files and unmanaged host links are never overwritten.

  full       Install complete manifests and stow all dotfiles.
  niri       Install Niri session packages and its limited configuration.
  config     Stow all dotfiles without installing packages.
  services   Enable NetworkManager and Bluetooth.
  ly         Enable Ly on tty2 when no display manager is active.
EOF
}

[[ $# -ge 2 ]] || {
    usage >&2
    exit 2
}
host="$1"
shift

for action in "$@"; do
    case "$action" in
        full) install_full=true ;;
        niri) install_niri=true ;;
        config) install_config=true ;;
        services) enable_services=true ;;
        ly) enable_ly=true ;;
        *)
            printf 'Unknown action: %s\n' "$action" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ "$host" =~ ^[a-zA-Z0-9._-]+$ && "$host" != "." && "$host" != ".." ]] || {
    printf 'Invalid host profile name: %s\n' "$host" >&2
    exit 2
}

host_dir="$repo_dir/hosts/$host"
[[ -d "$host_dir/arch/stow" ]] || {
    printf 'Unknown or incomplete Arch host profile: %s\n' "$host" >&2
    exit 1
}

install_manifests() {
    local packages=()
    local manifest
    local package

    for manifest in "$@"; do
        [[ -f "$manifest" ]] || continue
        while IFS= read -r package || [[ -n "$package" ]]; do
            package="${package#"${package%%[![:space:]]*}"}"
            package="${package%"${package##*[![:space:]]}"}"
            [[ -z "$package" || "$package" == \#* ]] && continue
            [[ "$package" != -* ]] || {
                printf 'Invalid package name in %s: %s\n' "$manifest" "$package" >&2
                return 1
            }
            packages+=("$package")
        done < "$manifest"
    done

    if ((${#packages[@]})); then
        sudo pacman -Syu --needed -- "${packages[@]}"
    fi
}

add_stow_conflict() {
    local target="$1"
    [[ -n "${stow_conflict_seen[$target]:-}" ]] && return
    stow_conflict_seen["$target"]=true
    stow_conflicts+=("$target")
}

find_conflicting_targets() {
    local stow_dir="$1"
    shift
    local package source relative target parent resolved

    # Inspect every file Stow would link before it changes the target tree.
    for package in "$@"; do
        while IFS= read -r -d '' source; do
            relative="${source#"$stow_dir/$package/"}"
            target="$HOME/$relative"

            parent=$(dirname -- "$target")
            while [[ "$parent" != "$HOME" ]]; do
                if [[ -L "$parent" ]]; then
                    resolved=$(readlink -f -- "$parent" 2>/dev/null || true)
                    [[ "$resolved" == "$stow_dir/"* ]] || add_stow_conflict "$parent"
                    break
                fi
                parent=$(dirname -- "$parent")
            done
            [[ -e "$target" || -L "$target" ]] || continue

            if [[ -L "$target" ]]; then
                resolved=$(readlink -f -- "$target" 2>/dev/null || true)
                [[ "$resolved" == "$stow_dir/"* ]] && continue
            fi
            add_stow_conflict "$target"
        done < <(find "$stow_dir/$package" \( -type f -o -type l \) -print0)
    done
}

confirm_conflicting_targets() {
    local target answer
    ((${#stow_conflicts[@]})) || return 0

    printf 'Existing configuration conflicts were found:\n' >&2
    printf '  %s\n' "${stow_conflicts[@]}" >&2
    if [[ ! -t 0 || ! -t 1 ]]; then
        printf 'Refusing to remove configuration without an interactive terminal. Move the files aside, then run the command again.\n' >&2
        return 1
    fi

    for target in "${stow_conflicts[@]}"; do
        read -r -p "Replace $target with the repository version? [y/N] " answer || return 1
        [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]] || {
            printf 'Deployment cancelled; no conflicting files were removed.\n' >&2
            return 1
        }
    done

}

remove_conflicting_targets() {
    local target
    for target in "${stow_conflicts[@]}"; do
        rm -f -- "$target"
    done
}

stow_dir="$repo_dir/shared/stow"
if $install_full || $install_config; then
    for path in "$stow_dir"/*; do
        [[ -d "$path" ]] && stow_packages+=("$(basename "$path")")
    done
elif $install_niri; then
    stow_packages=(niri quickshell mako gtk portal systemd)
fi
if ((${#stow_packages[@]})); then
    find_conflicting_targets "$stow_dir" "${stow_packages[@]}"
    confirm_conflicting_targets
fi

if $install_full || $install_niri || $enable_services || $enable_ly; then
    if [[ ! -f /etc/arch-release ]]; then
        printf 'This bootstrap supports Arch Linux only.\n' >&2
        exit 1
    fi
    command -v sudo >/dev/null || {
        printf 'sudo is required for Arch package and system service changes.\n' >&2
        exit 1
    }
fi

if $install_full; then
    install_manifests "$repo_dir/arch/packages/common.txt" "$host_dir/arch/packages.txt"
    command -v jupytext >/dev/null || uv tool install jupytext
elif $install_niri; then
    install_manifests "$repo_dir/arch/packages/niri.txt"
fi

if $install_full || $install_niri || $install_config; then
    command -v stow >/dev/null || {
        printf 'GNU Stow is not installed. Run the niri or full preset first.\n' >&2
        exit 1
    }

    packages=("${stow_packages[@]}")

    niri_dir="$HOME/.config/niri"
    host_link="$niri_dir/host.kdl"
    if [[ -L "$host_link" ]]; then
        current_host_target=$(readlink "$host_link")
        if [[ "$current_host_target" != "$repo_dir/hosts/"*/arch/stow/.config/niri/host.kdl ]]; then
            printf 'Refusing to replace unmanaged host configuration: %s\n' "$host_link" >&2
            exit 1
        fi
    elif [[ -e "$host_link" ]]; then
        printf 'Refusing to replace existing host configuration: %s\n' "$host_link" >&2
        exit 1
    fi

    systemctl --user show-environment >/dev/null || {
        printf 'The systemd user manager is unavailable; configuration was not deployed.\n' >&2
        exit 1
    }

    legacy_polkit_unit="$HOME/.config/systemd/user/polkit-kde-agent.service"
    if [[ -L "$legacy_polkit_unit" ]]; then
        legacy_polkit_target=$(readlink "$legacy_polkit_unit")
        case "$legacy_polkit_target" in
            "$repo_dir"/shared/stow/systemd/*|*/shared/stow/systemd/*)
                systemctl --user disable --now polkit-kde-agent.service >/dev/null 2>&1 || true
                rm -f -- "$legacy_polkit_unit"
                systemctl --user daemon-reload
                ;;
        esac
    fi

    remove_conflicting_targets

    # Detect Stow conflicts before changing the target tree without noisy success output.
    if ! stow_output=$(stow --simulate --no-folding --dir="$stow_dir" --target="$HOME" --restow "${packages[@]}" 2>&1); then
        printf '%s\n' "$stow_output" >&2
        exit 1
    fi

    # Keep directories real so the host-specific file can coexist with shared links.
    stow --no-folding --dir="$stow_dir" --target="$HOME" --restow "${packages[@]}"
    mkdir -p "$niri_dir"
    ln -sfn "$host_dir/arch/stow/.config/niri/host.kdl" "$host_link"

    user_services=(quickshell.service)
    if systemctl --user cat cliphist.service >/dev/null 2>&1; then
        user_services+=(cliphist.service)
    fi

    systemctl --user daemon-reload
    systemctl --user enable "${user_services[@]}"
    if systemctl --user is-active --quiet graphical-session.target; then
        if command -v qs >/dev/null; then
            systemctl --user restart quickshell.service
        fi
        if ((${#user_services[@]} > 1)) && command -v wl-paste >/dev/null && command -v cliphist >/dev/null; then
            systemctl --user start cliphist.service
        fi
    fi
fi

if $enable_services; then
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service
fi

if $enable_ly; then
    for display_manager in display-manager.service sddm.service gdm.service lightdm.service greetd.service; do
        display_manager_state=$(systemctl is-enabled "$display_manager" 2>/dev/null || true)
        display_manager_active=$(systemctl is-active "$display_manager" 2>/dev/null || true)
        case "$display_manager_state:$display_manager_active" in
            enabled:*|enabled-runtime:*|linked:*|linked-runtime:*|*:active|*:activating|*:reloading)
                printf 'Refusing to enable Ly while %s is enabled or active. Disable the existing display manager first.\n' "$display_manager" >&2
                exit 1
                ;;
        esac
    done

    existing_ly_unit=""
    for ly_template in ly ly-kmsconvt; do
        for tty in {1..12}; do
            ly_unit="${ly_template}@tty${tty}.service"
            ly_state=$(systemctl is-enabled "$ly_unit" 2>/dev/null || true)
            case "$ly_state" in
                enabled|enabled-runtime|linked|linked-runtime)
                    existing_ly_unit="$ly_unit"
                    break
                    ;;
                disabled|indirect|static|not-found|masked|masked-runtime|generated|transient)
                    ly_active_state=$(systemctl is-active "$ly_unit" 2>/dev/null || true)
                    case "$ly_active_state" in
                        active|activating|reloading)
                            existing_ly_unit="$ly_unit"
                            break
                            ;;
                        inactive|failed|unknown|deactivating) ;;
                        *)
                            printf 'Unable to determine active state for %s.\n' "$ly_unit" >&2
                            exit 1
                            ;;
                    esac
                    ;;
                *)
                    printf 'Unable to determine service state for %s.\n' "$ly_unit" >&2
                    exit 1
                    ;;
            esac
        done
        [[ -z "$existing_ly_unit" ]] || break
    done

    if [[ -n "$existing_ly_unit" ]]; then
        printf 'Keeping existing Ly service: %s\n' "$existing_ly_unit"
    else
        sudo systemctl enable ly@tty2.service
        sudo systemctl disable getty@tty2.service
    fi
fi
