#!/bin/bash
# Railway start script for Thumbor.
# - checks the signing key, prepares the volume, starts Thumbor on $PORT
# - prunes the on-disk cache so the volume never fills up
# - exits non-zero if Thumbor stops unexpectedly, so Railway's ON_FAILURE
#   restart policy brings it back (Free/Trial plans can't use ALWAYS)
set -u

PORT="${PORT:-8080}"
DATA="${THUMBOR_DATA_DIR:-/data}"
export THUMBOR_DATA_DIR="$DATA"

key="${THUMBOR_SECURITY_KEY:-}"
if [ "${#key}" -lt 16 ] || [ "$key" = "MY_SECURE_KEY" ]; then
  echo "start-thumbor: THUMBOR_SECURITY_KEY must be set to a random value of at least 16 characters" >&2
  exit 1
fi

mkdir -p "$DATA/storage" "$DATA/result_storage" || exit 1
rm -r "$DATA/lost+found" 2>/dev/null
for d in "$DATA" "$DATA/storage" "$DATA/result_storage"; do
  [ "$(stat -c %u "$d")" = "1000" ] || chown -R 1000:1000 "$d" || exit 1
done

# Cache limit: THUMBOR_CACHE_MAX_MB, or 80% of the volume size.
limit_mb="${THUMBOR_CACHE_MAX_MB:-}"
if [ -z "$limit_mb" ]; then
  total_kb=$(df -Pk "$DATA" | awk 'NR==2 {print $2}')
  limit_mb=$(( total_kb * 8 / 10 / 1024 ))
fi
storage_days=$(( ${THUMBOR_STORAGE_EXPIRATION_SECONDS:-2592000} / 86400 + 1 ))
result_days=$(( ${THUMBOR_RESULT_STORAGE_EXPIRATION_SECONDS:-604800} / 86400 + 1 ))
echo "start-thumbor: Thumbor 7.8.0 on port $PORT, cache in $DATA (limit ${limit_mb} MB)"

prune() {
  # Expired files are never served again; delete them.
  find "$DATA/storage" -type f -mtime +"$storage_days" -delete 2>/dev/null
  find "$DATA/result_storage" -type f -mtime +"$result_days" -delete 2>/dev/null
  # Then delete the oldest files until the cache is under its limit.
  local used_mb
  used_mb=$(du -sm "$DATA/storage" "$DATA/result_storage" 2>/dev/null | awk '{s+=$1} END {print s+0}')
  if [ "$used_mb" -gt "$limit_mb" ]; then
    echo "start-thumbor: cache ${used_mb} MB > ${limit_mb} MB, deleting oldest files"
    find "$DATA/storage" "$DATA/result_storage" -type f -printf '%T@ %s %p\n' 2>/dev/null \
      | sort -n \
      | awk -v over=$(( (used_mb - limit_mb * 9 / 10) * 1048576 )) '{ if (freed >= over) exit; freed += $2; sub(/^[^ ]+ [^ ]+ /, ""); print }' \
      | tr '\n' '\0' | xargs -0 -r rm --
    find "$DATA/storage" "$DATA/result_storage" -mindepth 1 -type d -empty -delete 2>/dev/null
  fi
}

prune
(
  while sleep "${THUMBOR_PRUNE_INTERVAL_SECONDS:-600}"; do prune; done
) &
pruner=$!

stopping=0
trap 'stopping=1; kill -TERM "$thumbor" 2>/dev/null' TERM INT

setpriv --reuid=1000 --regid=1000 --init-groups -- \
  thumbor --conf=/etc/thumbor/thumbor.conf --ip=0.0.0.0 --port="$PORT" \
          --log-level="${THUMBOR_LOG_LEVEL:-info}" &
thumbor=$!

wait "$thumbor"
code=$?
# "wait" returns early when a trapped signal arrives; wait for the real exit.
while kill -0 "$thumbor" 2>/dev/null; do wait "$thumbor"; code=$?; done
kill "$pruner" 2>/dev/null

if [ "$stopping" = 1 ]; then
  exit 0
fi
echo "start-thumbor: thumbor exited unexpectedly (code $code)" >&2
[ "$code" -eq 0 ] && code=1
exit "$code"
