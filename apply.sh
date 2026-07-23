#!/usr/bin/env bash
# Deploy this repository through a small interactive wizard or explicit preset.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

usage() {
    cat <<'EOF'
Usage:
  ./apply.sh
  ./apply.sh [plan] {full|niri|config|services|ly} [HOST]
  ./apply.sh [plan] {build|test|switch} HOST

Without arguments on a terminal, starts a conservative guided installer.

Arch presets:
  full       Install all packages and deploy all dotfiles.
  niri       Install the Niri session and its required configuration.
  config     Deploy all dotfiles without installing packages.
  services   Enable NetworkManager and Bluetooth.
  ly         Enable Ly on tty2 when no display manager is active.

NixOS presets:
  build      Build a host without activation.
  test       Activate a host until reboot.
  switch     Activate a host permanently.

Prefix any command with 'plan' to print its effects without changing the system.
EOF
}

die() {
    printf '%s\n' "$1" >&2
    exit "${2:-1}"
}

validate_host() {
    [[ "$1" =~ ^[a-zA-Z0-9._-]+$ && "$1" != "." && "$1" != ".." ]] || die "Invalid host profile name: $1" 2
}

detect_os() {
    if [[ -e /etc/NIXOS ]]; then
        printf 'nixos\n'
    elif [[ -f /etc/arch-release ]]; then
        printf 'arch\n'
    else
        die 'Unsupported system: expected Arch Linux or NixOS.'
    fi
}

confirm() {
    local prompt="$1"
    local answer
    read -r -p "$prompt [y/N] " answer || return 1
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

choose_arch_host() {
    local answer
    read -r -p 'Host profile [generic]: ' answer || return 1
    printf '%s\n' "${answer:-generic}"
}

choose_nixos_host() {
    local hosts=()
    local path
    for path in "$repo_dir"/hosts/*/nixos/hardware-configuration.nix; do
        [[ -f "$path" ]] || continue
        host=$(basename "$(dirname "$(dirname "$path")")")
        [[ "$host" == "test" || "$host" == "_template" ]] || hosts+=("$host")
    done

    if ((${#hosts[@]})); then
        printf 'Available NixOS hosts: %s\n' "${hosts[*]}" >&2
    else
        printf 'No NixOS host with hardware-configuration.nix was found.\n' >&2
    fi
    local answer
    read -r -p 'NixOS host: ' answer || return 1
    [[ -n "$answer" ]] || return 1
    printf '%s\n' "$answer"
}

print_arch_plan() {
    local host="$1"
    shift
    local changes_packages=false
    local action
    for action in "$@"; do
        [[ "$action" == "full" || "$action" == "niri" ]] && changes_packages=true
    done
    printf 'Plan for Arch host %s:\n' "$host"
    for action in "$@"; do
        case "$action" in
            full) printf '%s\n' '  - Full Pacman upgrade and complete package manifests' '  - Install Jupytext through uv when absent' '  - Stow every dotfile package; Quickshell provides the Polkit agent' ;;
            niri) printf '%s\n' '  - Full Pacman upgrade and Niri session manifest' '  - Stow Niri, Quickshell, Mako, GTK, and portal configuration' ;;
            config) printf '%s\n' '  - Stow every dotfile package; Quickshell provides the Polkit agent' ;;
            services) printf '%s\n' '  - Enable NetworkManager and Bluetooth system services' ;;
            ly) printf '%s\n' '  - Check display-manager conflicts, then enable Ly on tty2 and disable getty@tty2' ;;
        esac
    done
    $changes_packages && printf '%s\n' '  - Package installation and Jupytext access the network.'
    printf '%s\n' '  - Stow and service phases can complete independently if a later phase fails.'
}

print_nixos_plan() {
    local action="$1" host="$2"
    printf 'Plan for NixOS host %s:\n' "$host"
    case "$action" in
        build) printf '%s\n' '  - Build the NixOS configuration without activation.' ;;
        test) printf '%s\n' '  - Activate the configuration until the next reboot.' ;;
        switch) printf '%s\n' '  - Activate the configuration permanently and update the boot generation.' ;;
    esac
    printf '  - Command: sudo nixos-rebuild %s --flake path:%s#%s\n' "$action" "$repo_dir" "$host"
}

run_arch() {
    local host="$1"
    shift
    exec "$repo_dir/arch/install.sh" "$host" "$@"
}

run_nixos() {
    local action="$1" host="$2"
    validate_host "$host"
    [[ -f "$repo_dir/hosts/$host/nixos/hardware-configuration.nix" ]] || die "Missing hardware configuration: $repo_dir/hosts/$host/nixos/hardware-configuration.nix"
    sudo nixos-rebuild "$action" --flake "path:$repo_dir#$host"
    [[ "$action" == "switch" ]] && printf 'Set a password for the configured user before logging out.\n'
}

interactive_arch() {
    local host deployment services=false ly=false choice
    host=$(choose_arch_host) || die 'Installer cancelled.' 2
    validate_host "$host"
    [[ -d "$repo_dir/hosts/$host/arch/stow" ]] || die "Unknown or incomplete Arch host profile: $host"

    printf '%s\n' 'Choose deployment:' '  1) Full dots and packages (default)' '  2) Niri beside an existing desktop' '  3) Update dotfiles only'
    read -r -p 'Selection [1]: ' choice || die 'Installer cancelled.' 2
    case "${choice:-1}" in
        1) deployment=full ;;
        2) deployment=niri ;;
        3) deployment=config ;;
        *) die 'Invalid selection.' 2 ;;
    esac
    confirm 'Enable NetworkManager and Bluetooth?' && services=true || true
    confirm 'Enable Ly on tty2? This changes the login console.' && ly=true || true

    actions=("$deployment")
    $services && actions+=(services)
    $ly && actions+=(ly)
    print_arch_plan "$host" "${actions[@]}"
    confirm 'Apply this plan?' || { printf 'No changes made.\n'; exit 0; }
    run_arch "$host" "${actions[@]}"
}

interactive_nixos() {
    local host action choice
    host=$(choose_nixos_host) || die 'Installer cancelled.' 2
    validate_host "$host"
    printf '%s\n' 'Choose NixOS action:' '  1) Build only (default)' '  2) Test until reboot' '  3) Switch permanently'
    read -r -p 'Selection [1]: ' choice || die 'Installer cancelled.' 2
    case "${choice:-1}" in
        1) action=build ;;
        2) action=test ;;
        3) action=switch ;;
        *) die 'Invalid selection.' 2 ;;
    esac
    print_nixos_plan "$action" "$host"
    confirm 'Apply this plan?' || { printf 'No changes made.\n'; exit 0; }
    run_nixos "$action" "$host"
}

os=$(detect_os)
if (($# == 0)); then
    [[ -t 0 && -t 1 ]] || { usage >&2; exit 2; }
    if [[ "$os" == "arch" ]]; then
        interactive_arch
    else
        interactive_nixos
    fi
fi

plan=false
if [[ "${1:-}" == "plan" ]]; then
    plan=true
    shift
fi

action="${1:-}"
[[ -n "$action" ]] || { usage >&2; exit 2; }
shift

case "$action" in
    help|-h|--help) usage; exit 0 ;;
    full|niri|config|services|ly)
        [[ "$os" == "arch" ]] || die "'$action' is available only on Arch Linux." 2
        host="${1:-generic}"
        (($# <= 1)) || { usage >&2; exit 2; }
        validate_host "$host"
        [[ -d "$repo_dir/hosts/$host/arch/stow" ]] || die "Unknown or incomplete Arch host profile: $host"
        print_arch_plan "$host" "$action"
        $plan && exit 0
        run_arch "$host" "$action"
        ;;
    build|test|switch)
        [[ "$os" == "nixos" ]] || die "'$action' is available only on NixOS." 2
        host="${1:-}"
        [[ -n "$host" && $# -eq 1 ]] || { usage >&2; exit 2; }
        validate_host "$host"
        print_nixos_plan "$action" "$host"
        $plan && exit 0
        run_nixos "$action" "$host"
        ;;
    *)
        printf 'Unknown command: %s\n' "$action" >&2
        usage >&2
        exit 2
        ;;
esac
