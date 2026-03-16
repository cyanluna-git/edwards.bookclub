#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

check_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf 'Missing required path: %s\n' "$path" >&2
    exit 1
  fi
}

check_file "ops/runbook.md"
check_file "script/backup-production.sh"
check_file "script/restore-production.sh"
check_file "script/dev-env.sh"

source script/dev-env.sh

bundle exec bin/rails test
bundle exec bin/rake bookclub:reconcile

printf 'Cutover dry run completed successfully.\n'
