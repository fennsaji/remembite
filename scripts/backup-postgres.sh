#!/usr/bin/env bash
#
# Postgres → Cloudflare R2 backup.
#
# Runs pg_dump in custom format (-Fc, compressed), writes it to a dated local
# file, uploads it to R2 with the AWS CLI (R2 is S3-compatible), then prunes
# local files and remote objects older than the retention window.
#
# Reuses the R2_* env vars the backend already uses for image storage
# (see backend/src/config.rs) — no new credentials to provision.
#
# Restore steps: docs/Deployment.md § Database Backups.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
PGHOST="${PGHOST:-postgres}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-remembite}"
PGDATABASE="${PGDATABASE:-remembite}"

BACKUP_DIR="${BACKUP_DIR:-/backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
BACKUP_PREFIX="${BACKUP_PREFIX:-postgres}"   # key prefix inside the bucket

R2_BACKUP_BUCKET="${R2_BACKUP_BUCKET:-${R2_BUCKET:-}}"

log() { printf '%s [backup] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

for var in POSTGRES_PASSWORD R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BACKUP_BUCKET; do
  [ -n "${!var:-}" ] || die "missing required env var: $var"
done

[[ "$BACKUP_RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "BACKUP_RETENTION_DAYS must be an integer (got: $BACKUP_RETENTION_DAYS)"

# pg_dump reads the password from PGPASSWORD; AWS CLI reads the R2 token from
# the standard AWS_* names. Export them here so the rest of the script is clean.
export PGPASSWORD="$POSTGRES_PASSWORD"
export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
# R2 does not implement the streaming trailer checksums newer AWS CLIs send by
# default; force the legacy behaviour so uploads don't 501.
export AWS_REQUEST_CHECKSUM_CALCULATION="${AWS_REQUEST_CHECKSUM_CALCULATION:-when_required}"
export AWS_RESPONSE_CHECKSUM_VALIDATION="${AWS_RESPONSE_CHECKSUM_VALIDATION:-when_required}"

R2_ENDPOINT="${R2_ENDPOINT:-https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com}"

aws_s3() { aws s3 --endpoint-url "$R2_ENDPOINT" "$@"; }

# ── Dump ──────────────────────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"

STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
FINAL_NAME="${PGDATABASE}-${STAMP}.dump"
FINAL_PATH="${BACKUP_DIR}/${FINAL_NAME}"
# Dump to a .partial name first: only a pg_dump that exited 0 is ever renamed
# to the final name, so a truncated dump can never be uploaded or kept.
TMP_PATH="${FINAL_PATH}.partial"

cleanup() { [ -e "$TMP_PATH" ] && rm -f "$TMP_PATH"; }
trap cleanup EXIT

log "dumping ${PGUSER}@${PGHOST}:${PGPORT}/${PGDATABASE} -> ${TMP_PATH}"
pg_dump \
  --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" --dbname="$PGDATABASE" \
  --format=custom --compress=9 --no-owner --no-privileges \
  --file="$TMP_PATH"

[ -s "$TMP_PATH" ] || die "pg_dump produced an empty file"

mv "$TMP_PATH" "$FINAL_PATH"
SIZE="$(du -h "$FINAL_PATH" | cut -f1)"
log "dump ok: ${FINAL_PATH} (${SIZE})"

# ── Upload ────────────────────────────────────────────────────────────────────
REMOTE_KEY="${BACKUP_PREFIX}/${FINAL_NAME}"
log "uploading -> s3://${R2_BACKUP_BUCKET}/${REMOTE_KEY}"
aws_s3 cp "$FINAL_PATH" "s3://${R2_BACKUP_BUCKET}/${REMOTE_KEY}"
log "upload ok"

# ── Prune local ───────────────────────────────────────────────────────────────
log "pruning local dumps older than ${BACKUP_RETENTION_DAYS}d in ${BACKUP_DIR}"
PRUNED_LOCAL=0
while IFS= read -r -d '' old; do
  rm -f "$old"
  log "  removed local $(basename "$old")"
  PRUNED_LOCAL=$((PRUNED_LOCAL + 1))
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.dump' -mtime "+${BACKUP_RETENTION_DAYS}" -print0)
# Stale .partial files from a crashed earlier run.
find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.dump.partial' -mtime +1 -delete

# ── Prune remote ──────────────────────────────────────────────────────────────
# Age is decided from the UTC stamp embedded in the object name, not from
# LastModified — the names sort lexicographically, so a plain string compare
# against the cut-off stamp is exact and needs no date parsing per object.
CUTOFF_STAMP="$(date -u -d "${BACKUP_RETENTION_DAYS} days ago" '+%Y%m%dT%H%M%SZ')"
log "pruning R2 objects under ${BACKUP_PREFIX}/ with stamp < ${CUTOFF_STAMP}"
PRUNED_REMOTE=0
while read -r _d _t _size key; do
  [ -n "${key:-}" ] || continue
  case "$key" in *.dump) ;; *) continue ;; esac
  stamp="${key##*-}"; stamp="${stamp%.dump}"
  if [[ ! "$stamp" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
    log "  WARN: unrecognised name ${key}, keeping it"
    continue
  fi
  if [[ "$stamp" < "$CUTOFF_STAMP" ]]; then
    aws_s3 rm "s3://${R2_BACKUP_BUCKET}/${BACKUP_PREFIX}/${key}"
    log "  removed remote ${key}"
    PRUNED_REMOTE=$((PRUNED_REMOTE + 1))
  fi
done < <(aws_s3 ls "s3://${R2_BACKUP_BUCKET}/${BACKUP_PREFIX}/")

log "done: uploaded ${FINAL_NAME}, pruned ${PRUNED_LOCAL} local / ${PRUNED_REMOTE} remote"
