#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${1:?Usage: script/restore-production.sh BACKUP_DIR [STORAGE_DIR]}"
STORAGE_DIR="${2:-storage}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$STORAGE_DIR"

restore_db() {
  local backup_file="$1"
  local target_file="$2"

  if [[ -f "$backup_file" ]]; then
    if [[ -f "$target_file" ]]; then
      cp "$target_file" "${target_file}.pre_restore.${TIMESTAMP}"
    fi
    cp "$backup_file" "$target_file"
  fi
}

restore_db "${BACKUP_DIR}/production.sqlite3" "${STORAGE_DIR}/production.sqlite3"
restore_db "${BACKUP_DIR}/production_cache.sqlite3" "${STORAGE_DIR}/production_cache.sqlite3"
restore_db "${BACKUP_DIR}/production_queue.sqlite3" "${STORAGE_DIR}/production_queue.sqlite3"
restore_db "${BACKUP_DIR}/production_cable.sqlite3" "${STORAGE_DIR}/production_cable.sqlite3"

if [[ -f "${BACKUP_DIR}/storage_files.tar.gz" ]]; then
  tar -xzf "${BACKUP_DIR}/storage_files.tar.gz" -C "$STORAGE_DIR"
fi

printf 'Restore completed from %s into %s\n' "$BACKUP_DIR" "$STORAGE_DIR"
