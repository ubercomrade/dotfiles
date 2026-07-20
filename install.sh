#!/usr/bin/env bash
# Backward-compatible Arch entrypoint. Prefer ./apply.sh --os arch.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$repo_dir/apply.sh" --os arch "$@"
