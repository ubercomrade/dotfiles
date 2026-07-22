#!/usr/bin/env bash
# Bootstrap the graphical user environment on an existing Arch installation.
# This script does not partition disks, create users, or alter boot configuration.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install_packages=false
install_niri_packages=false
install_stow=false
install_niri_config=false
enable_services=false
enable_ly=false
host="generic"

usage() {
    cat <<'EOF'
Usage: ./install.sh [--host NAME] [--niri-packages] [--packages] [--niri-config] [--stow] [--enable-services] [--enable-ly]

At least one action flag is required. Existing regular files and unmanaged host links are never overwritten.

  --host NAME        Apply a hardware profile; defaults to generic.
  --niri-packages    Install only packages required by the Niri session.
  --packages         Install common and host-specific package manifests.
  --niri-config      Deploy only the Niri session configuration.
  --stow             Symlink all stow packages into $HOME.
  --enable-services  Enable NetworkManager and Bluetooth.
  --enable-ly        Enable Ly on tty2 when no display manager is active.
  --help             Show this help.

--enable-services changes system services and is intentionally opt-in.
EOF
}

while (($#)); do
    case "$1" in
        --host)
            (($# >= 2)) || { usage >&2; exit 2; }
            host="$2"
            shift
            ;;
        --niri-packages) install_niri_packages=true ;;
        --packages) install_packages=true ;;
        --niri-config) install_niri_config=true ;;
        --stow) install_stow=true ;;
        --enable-services) enable_services=true ;;
        --enable-ly) enable_ly=true ;;
        --help) usage; exit 0 ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if ! $install_niri_packages && ! $install_packages && ! $install_niri_config && ! $install_stow && ! $enable_services && ! $enable_ly; then
    usage >&2
    exit 2
fi

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

if $install_niri_packages || $install_packages || $enable_services || $enable_ly; then
    if [[ ! -f /etc/arch-release ]]; then
        printf 'This bootstrap supports Arch Linux only.\n' >&2
        exit 1
    fi
fi

if $install_packages; then
    install_manifests "$repo_dir/arch/packages/common.txt" "$host_dir/arch/packages.txt"
    command -v jupytext >/dev/null || uv tool install jupytext
elif $install_niri_packages; then
    install_manifests "$repo_dir/arch/packages/niri.txt"
fi

if $install_niri_config || $install_stow; then
    command -v stow >/dev/null || {
        printf 'GNU Stow is not installed. Run with --niri-packages or --packages first.\n' >&2
        exit 1
    }

    stow_dir="$repo_dir/shared/stow"
    if $install_stow; then
        packages=()
        for path in "$stow_dir"/*; do
            [[ -d "$path" ]] && packages+=("$(basename "$path")")
        done
    else
        packages=(niri quickshell mako portal systemd)
    fi

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

    # Detect Stow conflicts before changing the target tree.
    stow --simulate --no-folding --dir="$stow_dir" --target="$HOME" --restow "${packages[@]}"

    # Keep directories real so the host-specific file can coexist with shared links.
    stow --no-folding --dir="$stow_dir" --target="$HOME" --restow "${packages[@]}"
    mkdir -p "$niri_dir"
    ln -sfn "$host_dir/arch/stow/.config/niri/host.kdl" "$host_link"
    systemctl --user enable polkit-kde-agent.service
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
