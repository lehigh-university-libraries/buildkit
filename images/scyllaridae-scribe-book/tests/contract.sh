#!/usr/bin/env bash
set -euo pipefail
TASK_TEST=$(mktemp -d)
trap 'rm -rf "$TASK_TEST"' EXIT
export SCRIBE_API_URL=https://scribe.example SCRIBE_API_TOKEN=test-only SCRIBE_WORKSPACE_ID=42
export ISLANDORA_SCRIBE_CORRELATION_URL=https://islandora.example/islandora-scribe/correlation
export ISLANDORA_SCRIBE_CORRELATION_SECRET=01234567890123456789012345678901
export SCYLLARIDAE_AUTH='Bearer islandora-only'
export BOOK_TEST_DIR=$TASK_TEST
OPERATION=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
COMMAND=${SCRIBE_BOOK_COMMAND:-/app/cmd.sh}
printf '[{"id":"https://islandora.example/node/100/canvas/300","width":1000,"height":2000,"items":[]}]\n' > "$TASK_TEST/canvases.json"
jq -Sc '[.[] | [.id,.width,.height,.items]]' "$TASK_TEST/canvases.json" > "$TASK_TEST/painting.json"
export BOOK_SIGNATURE
BOOK_SIGNATURE=$(sha256sum "$TASK_TEST/painting.json" | cut -d ' ' -f 1)
cat > "$TASK_TEST/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
output= input= config= method= url=
while (($#)); do
  case "$1" in
    --output) output=$2; shift 2 ;;
    --data-binary) input=${2#@}; shift 2 ;;
    --config) config=$2; shift 2 ;;
    --request) method=$2; shift 2 ;;
    https://*) url=$1; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "$url" >> "$BOOK_TEST_DIR/requests"
status=200
case "$url" in
  */book-manifest)
    [[ ! -s "$config" ]]
    jq '{items:.}' "$BOOK_TEST_DIR/canvases.json" > "$output"
    status=${BOOK_MANIFEST_STATUS:-200} ;;
  */islandora-scribe/book)
    timestamp=$(sed -n 's/^header = "X-Scribe-Timestamp: \([0-9]*\)"$/\1/p' "$config")
    signature=$(sed -n 's/^header = "X-Scribe-Signature: v1=\([a-f0-9]*\)"$/\1/p' "$config")
    expected=$({ printf '%s.' "$timestamp"; cat "$input"; } | openssl dgst -sha256 -hmac "$ISLANDORA_SCRIBE_CORRELATION_SECRET" -r | cut -d ' ' -f 1)
    [[ "$signature" == "$expected" ]]
    jq -e '.nodeId == 100 and .workspaceId == 42 and (.operationId|length) == 32' "$input" > /dev/null
    case $(jq -r .phase "$input") in
      plan)
        item=; signature=; active=
        if [[ ${BOOK_REUSE:-0} == 1 || $(jq -r .contextId "$input") == 0 ]]; then item=book-item; signature=$BOOK_SIGNATURE; fi
        jq -n --arg item "$item" --arg signature "$signature" --arg active "$active" \
          '{name:"Book",externalReferenceId:"book-uuid",itemId:$item,sourceSignature:$signature,operationId:$active,uploadUrl:"https://islandora.example/node/100/media/document/5",fileUri:"private://derivatives/2026/10/pc/100.pdf"}' > "$output" ;;
      correlate)
        jq -e '.itemId == "book-item" and .images[0].id == 7' "$input" > /dev/null
        jq '{reprocess:[.images[]|{id,revision}]}' "$input" > "$output"
        if [[ ${BOOK_REJECT_CORRELATION:-0} == 1 ]]; then status=503; fi ;;
      reconcile)
        jq -e '.pages == [{id:7,revision:3}]' "$input" > /dev/null
        printf '{}' > "$output" ;;
      *) exit 1 ;;
    esac ;;
  https://scribe.example/*)
    grep -q 'X-Scribe-API-Key: test-only' "$config"
    grep -q 'X-Scribe-Workspace-ID: 42' "$config"
    case "$url" in
      */ImportManifest)
        jq -e '.ignoreExistingOcr and .contextId == "55" and .externalReferenceId == "book-uuid" and .manifestUrl == "https://islandora.example/node/100/book-manifest" and .idempotencyKey == "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$input" > /dev/null ;;
      */ReprocessItemImage)
        jq -e '.itemImageId == "7" and .expectedRevision == "3" and .contextId == "55"' "$input" > /dev/null
        printf '{}' > "$output"; printf 200; exit ;;
      */ListTranscriptionJobs) printf '{"jobs":[{"status":"TRANSCRIPTION_JOB_STATUS_COMPLETED"}]}' > "$output"; printf 200; exit ;;
      */GetAnnotationPage) printf '{"revision":"3"}' > "$output"; printf 200; exit ;;
      */PrepareItemExport)
        jq -e '.expectedRevisions == [{itemImageId:"7",revision:"3"}] and .format == "ANNOTATION_EXPORT_FORMAT_PDF"' "$input" > /dev/null
        printf '{"downloadUrl":"/v1/item-exports/token"}' > "$output"; printf 200; exit ;;
      */v1/item-exports/token) [[ "$method" == GET ]]; printf '%%PDF-fixture' > "$output"; printf 200; exit ;;
      */GetItem) ;;
      *) exit 1 ;;
    esac
    printf '{"item":{"id":"book-item","externalReferenceId":"book-uuid","images":[{"id":"7","canvasUri":"https://islandora.example/node/100/canvas/300"}]},"annotationRevisions":[{"itemImageId":"7","revision":"3"}]}' > "$output" ;;
  https://islandora.example/node/100/media/document/5)
    [[ "$method" == PUT && $(cat "$input") == '%PDF-fixture' ]]
    grep -q 'Authorization: Bearer islandora-only' "$config"
    if grep -q 'test-only' "$config"; then exit 1; fi
    printf '{}' > "$output" ;;
  *) exit 1 ;;
esac
printf '%s' "$status"
MOCK
chmod +x "$TASK_TEST/curl"
export PATH="$TASK_TEST:$PATH"
for _ in 1 2; do
  bash "$COMMAND" https://islandora.example/node/100 transcribe "$OPERATION" 55 | grep -qx OK
  BOOK_REUSE=1 bash "$COMMAND" https://islandora.example/node/100 transcribe "$OPERATION" 55 | grep -qx OK
done
bash "$COMMAND" https://islandora.example/node/100 pdf "$OPERATION" 0 | grep -qx OK
BOOK_MANIFEST_STATUS=403 bash "$COMMAND" https://islandora.example/node/100 transcribe "$OPERATION" 55 | grep -qx Rejected
if BOOK_MANIFEST_STATUS=503 bash "$COMMAND" https://islandora.example/node/100 transcribe "$OPERATION" 55; then exit 1; fi
if BOOK_REJECT_CORRELATION=1 bash "$COMMAND" https://islandora.example/node/100 transcribe "$OPERATION" 55; then exit 1; fi
if bash "$COMMAND" https://foreign.example/node/100 pdf "$OPERATION" 0; then exit 1; fi
printf 'Book import, replay, PDF upload, signed callbacks, credential isolation and retry dispositions passed.\n'
