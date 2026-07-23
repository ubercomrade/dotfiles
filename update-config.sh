#!/usr/bin/env bash
# Refresh only Stow-managed user configuration for an Arch host profile.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if (($# > 1)); then
    printf 'Usage: ./update-config.sh [HOST]\n' >&2
    exit 2
fi

exec "$repo_dir/apply.sh" config "${1:-generic}"
