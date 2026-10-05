#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /usr/local/share/isle/utilities.sh
wait_20x http://localhost:8080/healthcheck

TASK_TMP=$(mktemp -d)
trap 'rm -rf "$TASK_TMP"' EXIT

request() {
  curl --silent --show-error --output "$TASK_TMP/hocr" --write-out '%{http_code}' \
    --max-time 30 \
    --header 'Accept: application/hocr+xml' \
    --header 'Apix-Ldp-Resource: http://mock:8000/image.png' \
    --header 'X-Islandora-Args: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 12345678-1234-1234-1234-123456789abc 55' \
    http://localhost:8080/
}

# Repeat the same operation through the running service.
for _ in 1 2; do
  [[ $(request) == 200 ]]
  [[ $(cat "$TASK_TMP/hocr") == '<html><body><div class="ocr_page">published</div></body></html>' ]]
done
[[ $(curl --fail --silent http://mock:8000/callbacks | jq -r .count) == 2 ]]

curl --fail --silent --request POST http://mock:8000/reject >/dev/null
STATUS=$(request)
[[ $STATUS =~ ^[45] ]]
if grep -q 'ocr_page' "$TASK_TMP/hocr"; then
  printf 'Failed callback returned hOCR.\n' >&2
  exit 1
fi
[[ $(curl --fail --silent http://mock:8000/callbacks | jq -r .count) == 3 ]]
printf 'Scribe HTTP integration passed (startup, args, replay, hOCR, callback failure).\n'
