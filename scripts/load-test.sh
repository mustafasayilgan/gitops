#!/bin/bash
# load generator for hepapi — use while watching grafana.
set -euo pipefail

URL="${1:-${URL:-http://hepapi.test/api/items}}"
CONCURRENCY="${CONCURRENCY:-10}"
DURATION="${DURATION:-60}"
POST_EVERY="${POST_EVERY:-25}" 

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

echo "Target:      ${URL}"
echo "Concurrency: ${CONCURRENCY}"
echo "Duration:    ${DURATION}s (POST every ${POST_EVERY} reqs; 0=GET only)"
echo

worker() {
  local id="$1"
  local end_ts="$2"
  local i=0 ok=0 fail=0

  while [ "$(date +%s)" -lt "${end_ts}" ]; do
    i=$((i + 1))
    if [ "${POST_EVERY}" -gt 0 ] && [ $((i % POST_EVERY)) -eq 0 ]; then
      if curl -sf -m 5 -X POST "${URL}" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"load-w${id}-${i}\",\"source\":\"load-test\"}" >/dev/null; then
        ok=$((ok + 1))
      else
        fail=$((fail + 1))
      fi
    else
      if curl -sf -m 5 "${URL}" >/dev/null; then
        ok=$((ok + 1))
      else
        fail=$((fail + 1))
      fi
    fi
  done

  echo "${ok} ${fail}" >"${tmpdir}/w${id}"
}

end_ts=$(( $(date +%s) + DURATION ))
pids=()
for id in $(seq 1 "${CONCURRENCY}"); do
  worker "${id}" "${end_ts}" &
  pids+=($!)
done

while kill -0 "${pids[0]}" 2>/dev/null; do
  printf "\rrunning... %ss left " "$(( end_ts - $(date +%s) ))"
  sleep 1
done
wait || true
echo

total_ok=0
total_fail=0
for f in "${tmpdir}"/w*; do
  read -r o fcount <"${f}"
  total_ok=$((total_ok + o))
  total_fail=$((total_fail + fcount))
done

elapsed="${DURATION}"
rps=0
if [ "${elapsed}" -gt 0 ]; then
  rps=$((total_ok / elapsed))
fi
echo "ok=${total_ok} fail=${total_fail} total=$((total_ok + total_fail)) ~${rps} req/s"
