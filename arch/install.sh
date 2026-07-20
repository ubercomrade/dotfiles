#!/usr/bin/env bash
# Bootstrap the graphical user environment on an existing Arch installation.
# This script does not partition disks, create users, or alter boot configuration.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
install_packages=false
install_stow=false
enable_services=false

usage() {
    cat <<'EOF'
Usage: ./install.sh [--packages] [--stow] [--enable-services]

Without arguments, installs official packages and deploys user configuration.

  --packages         Install packages listed in arch/packages/pacman.txt.
  --stow             Symlink all stow packages into $HOME.
  --enable-services  Enable NetworkManager, Bluetooth, and Ly on tty2.
  --help             Show this help.

--enable-services changes system services and is intentionally opt-in.
EOF
}

if (($# == 0)); then
    install_packages=true
    install_stow=true
fi

while (($#)); do
    case "$1" in
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

if $install_packages; then
    if [[ ! -f /etc/arch-release ]]; then
        printf 'This bootstrap supports Arch Linux only.\n' >&2
        exit 1
    fi

    packages=()
    while IFS= read -r package || [[ -n "$package" ]]; do
        [[ -z "$package" || "$package" == \#* ]] && continue
        packages+=("$package")
    done < "$repo_dir/arch/packages/pacman.txt"

    sudo pacman -Syu --needed "${packages[@]}"
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

    # --restow updates existing links but refuses to overwrite real files.
    stow --dir="$stow_dir" --target="$HOME" --restow "${packages[@]}"
fi

if $enable_services; then
    sudo systemctl enable NetworkManager.service
    sudo systemctl enable bluetooth.service
    sudo systemctl disable getty@tty2.service
    sudo systemctl enable ly@tty2.service
fi
