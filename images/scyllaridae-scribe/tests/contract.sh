#!/usr/bin/env bash
set -euo pipefail
TASK_TMP=$(mktemp -d)
trap 'rm -rf "$TASK_TMP"' EXIT
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIBE_COMMAND=${SCRIBE_COMMAND:-$SCRIPT_DIR/rootfs/app/cmd.sh}
export SCRIBE_API_URL=https://scribe.example SCRIBE_API_TOKEN=test-only SCRIBE_WORKSPACE_ID=42
export ISLANDORA_SCRIBE_CORRELATION_URL=https://islandora.example/islandora-scribe/correlation
export ISLANDORA_SCRIBE_CORRELATION_SECRET=01234567890123456789012345678901
export TEST_OPERATION=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa TEST_REFERENCE=12345678-1234-1234-1234-123456789abc
cat > "$TASK_TMP/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
output= request= url= timestamp= signature=
while (($#)); do
  case "$1" in
    --output) output=$2; shift 2 ;;
    --data-binary) request=${2#@}; shift 2 ;;
    --header)
      case "$2" in
        'X-Scribe-Timestamp: '*) timestamp=${2#*: } ;;
        'X-Scribe-Signature: '*) signature=${2#*: } ;;
      esac
      shift 2 ;;
    https://*) url=$1; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */StartUploadBatch)
    jq -e --arg op "$TEST_OPERATION" --arg ref "$TEST_REFERENCE" '.batchId == $op and .externalReferenceId == $ref and (.files[0].contentSha256 | length) == 64' "$request" >/dev/null
    if [[ ${TEST_CONTEXT:-0} == 0 ]]; then
      jq -e 'has("contextId") | not' "$request" >/dev/null
    else
      jq -e --arg context "$TEST_CONTEXT" '.contextId == $context' "$request" >/dev/null
    fi
    printf '{"item":{"id":"item-1"}}' > "$output" ;;
  */UploadItemImage) printf '{"image":{"id":"7"},"transcriptionJobId":"9"}' > "$output" ;;
  */GetTranscriptionJob) printf '{"job":{"status":"TRANSCRIPTION_JOB_STATUS_COMPLETED"}}' > "$output" ;;
  */GetAnnotationPage) printf '{"revision":"3"}' > "$output" ;;
  */ExportAnnotationPage)
    jq -e '.itemImageId == "7" and .expectedRevision == "3" and .format == "ANNOTATION_EXPORT_FORMAT_HOCR"' "$request" >/dev/null
    printf '{"content":"PGh0bWw+cHVibGlzaGVkPC9odG1sPg=="}' > "$output" ;;
  */correlation)
    jq -e --arg op "$TEST_OPERATION" --arg ref "$TEST_REFERENCE" '.operationId == $op and .externalReferenceId == $ref and .workspaceId == 42 and .itemId == "item-1" and .itemImageId == 7' "$request" >/dev/null
    jq -e --arg context "${TEST_CONTEXT:-0}" '.contextId == $context' "$request" >/dev/null
    expected=$({ printf '%s.' "$timestamp"; cat "$request"; } | openssl dgst -sha256 -hmac "$ISLANDORA_SCRIBE_CORRELATION_SECRET" -r | cut -d ' ' -f 1)
    [[ "$signature" == "v1=$expected" ]]
    : > "$output"
    if [[ ${TEST_REJECT_CALLBACK:-0} == 1 ]]; then printf 503; exit; fi ;;
  *) exit 1 ;;
esac
printf 200
MOCK
chmod +x "$TASK_TMP/curl"
export PATH="$TASK_TMP:$PATH"
for _ in 1 2; do
  printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" > "$TASK_TMP/hocr"
  [[ $(cat "$TASK_TMP/hocr") == '<html>published</html>' ]]
done
export TEST_CONTEXT=55
for _ in 1 2; do
  printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" "$TEST_CONTEXT" > "$TASK_TMP/hocr"
  [[ $(cat "$TASK_TMP/hocr") == '<html>published</html>' ]]
done
for context in -1 abc 1.5 '55;echo'; do
  if printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" "$context" > "$TASK_TMP/hocr" 2>/dev/null; then
    printf 'Invalid context accepted.\n' >&2
    exit 1
  fi
  [[ ! -s "$TASK_TMP/hocr" ]]
done
unset TEST_CONTEXT
export TEST_REJECT_CALLBACK=1
if printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" > "$TASK_TMP/hocr" 2>/dev/null; then
  printf 'Failed correlation callback was accepted.\n' >&2
  exit 1
fi
[[ ! -s "$TASK_TMP/hocr" ]]
printf 'Scribe command contract passed (contexts, replay, correlation signature, failure).\n'
