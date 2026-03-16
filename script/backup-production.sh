#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${1:-backups}"
STORAGE_DIR="${2:-storage}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="${BACKUP_ROOT%/}/${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"

backup_db() {
  local source_file="$1"
  local target_name="$2"

  if [[ -f "$source_file" ]]; then
    sqlite3 "$source_file" ".backup '${BACKUP_DIR}/${target_name}'"
  fi
}

backup_db "${STORAGE_DIR}/production.sqlite3" "production.sqlite3"
backup_db "${STORAGE_DIR}/production_cache.sqlite3" "production_cache.sqlite3"
backup_db "${STORAGE_DIR}/production_queue.sqlite3" "production_queue.sqlite3"
backup_db "${STORAGE_DIR}/production_cable.sqlite3" "production_cable.sqlite3"

if [[ -d "$STORAGE_DIR" ]]; then
  tar \
    --exclude='*.sqlite3' \
    --exclude='*.sqlite3-shm' \
    --exclude='*.sqlite3-wal' \
    --exclude='*.sqlite3-journal' \
    -czf "${BACKUP_DIR}/storage_files.tar.gz" \
    -C "$STORAGE_DIR" .
fi

cat > "${BACKUP_DIR}/manifest.txt" <<EOF
timestamp=${TIMESTAMP}
storage_dir=${STORAGE_DIR}
files=$(find "${BACKUP_DIR}" -maxdepth 1 -type f -printf '%f\n' | sort | tr '\n' ',' | sed 's/,$//')
EOF

printf 'Backup written to %s\n' "$BACKUP_DIR"
