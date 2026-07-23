#!/usr/bin/env bash
# Compatibility entrypoint. Prefer ./apply.sh.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec "$repo_dir/apply.sh" "$@"
