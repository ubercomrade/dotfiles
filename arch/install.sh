#!/usr/bin/env bash
# Bootstrap the graphical user environment on an existing Arch installation.
# This script does not partition disks, create users, or alter boot configuration.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install_packages=false
install_stow=false
enable_services=false
host="generic"

usage() {
    cat <<'EOF'
Usage: ./install.sh [--host NAME] [--packages] [--stow] [--enable-services]

Without arguments, installs official packages and deploys user configuration.

  --host NAME        Apply a hardware profile; defaults to generic.
  --packages         Install common and host-specific package manifests.
  --stow             Symlink all stow packages into $HOME.
  --enable-services  Enable NetworkManager, Bluetooth, and Ly on tty2.
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
        --packages) install_packages=true ;;
        --stow) install_stow=true ;;
        --enable-services) enable_services=true ;;
        --help) usage; exit 0 ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if ! $install_packages && ! $install_stow && ! $enable_services; then
    install_packages=true
    install_stow=true
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

if $install_packages || $enable_services; then
    if [[ ! -f /etc/arch-release ]]; then
        printf 'This bootstrap supports Arch Linux only.\n' >&2
        exit 1
    fi
fi

if $install_packages; then
    install_manifests "$repo_dir/arch/packages/common.txt" "$host_dir/arch/packages.txt"
    uv tool install --upgrade jupytext
fi

if $install_stow; then
    command -v stow >/dev/null || {
        printf 'GNU Stow is not installed. Run ./install.sh --packages first.\n' >&2
        exit 1
    }

    stow_dir="$repo_dir/shared/stow"
    packages=()
    for path in "$stow_dir"/*; do
        [[ -d "$path" ]] && packages+=("$(basename "$path")")
    done

    # Keep directories real so the host-specific file can coexist with shared links.
    stow --no-folding --dir="$stow_dir" --target="$HOME" --restow "${packages[@]}"

    niri_dir="$HOME/.config/niri"
    host_link="$niri_dir/host.kdl"
    mkdir -p "$niri_dir"
    if [[ -e "$host_link" && ! -L "$host_link" ]]; then
        printf 'Refusing to replace non-symlink host configuration: %s\n' "$host_link" >&2
        exit 1
    fi
    ln -sfn "$host_dir/arch/stow/.config/niri/host.kdl" "$host_link"
    systemctl --user enable polkit-kde-agent.service
fi

if $enable_services; then
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service
    sudo systemctl enable ly@tty2.service
    sudo systemctl disable getty@tty2.service
fi
