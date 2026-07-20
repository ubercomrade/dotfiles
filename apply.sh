#!/usr/bin/env bash
# Dispatch configuration deployment to the selected operating system.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
os=""
host="laptop"
args=()

usage() {
    cat <<'EOF'
Usage: ./apply.sh --os {arch|nixos} [--host NAME] [installer options]

Arch passes remaining options to arch/install.sh.
NixOS runs nixos-rebuild switch --flake .#HOST.
EOF
}

while (($#)); do
    case "$1" in
        --os)
            (($# >= 2)) || { usage >&2; exit 2; }
            os="$2"
            shift 2
            ;;
        --host)
            (($# >= 2)) || { usage >&2; exit 2; }
            host="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

case "$os" in
    arch)
        [[ -f /etc/arch-release ]] || {
            printf 'The Arch target requires Arch Linux.\n' >&2
            exit 1
        }
        exec "$repo_dir/arch/install.sh" "${args[@]}"
        ;;
    nixos)
        [[ -e /etc/NIXOS ]] || {
            printf 'The NixOS target requires NixOS.\n' >&2
            exit 1
        }
        [[ ${#args[@]} -eq 0 ]] || {
            printf 'NixOS does not accept imperative installer options.\n' >&2
            exit 2
        }
        flake_dir="$repo_dir/nixos"
        hardware_config="$flake_dir/hosts/$host/hardware-configuration.nix"
        [[ -f "$hardware_config" ]] || {
            printf 'Missing hardware configuration: %s\n' "$hardware_config" >&2
            printf 'Generate it with nixos-generate-config --show-hardware-config.\n' >&2
            exit 1
        }
        sudo nixos-rebuild switch --flake "path:$flake_dir#$host"
        printf 'Set a password for anton before logging out: sudo passwd anton\n'
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
