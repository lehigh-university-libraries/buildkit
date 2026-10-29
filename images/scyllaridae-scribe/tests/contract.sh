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
    jq -e '.metadata | fromjson | .external_identifier == "1234"' "$request" > /dev/null
    if [[ -n ${TEST_TITLE:-} ]]; then jq -e --arg title "$TEST_TITLE" '.metadata | fromjson | .title == $title' "$request" > /dev/null; fi
    jq -e --arg op "$TEST_OPERATION" --arg ref "$TEST_REFERENCE" '.batchId == $op and .externalReferenceId == $ref and .name == "1234" and (.files[0].contentSha256 | length) == 64' "$request" >/dev/null
    if [[ ${TEST_EXPECT_JPEG:-0} == 1 ]]; then
      jq -e '.files[0].filename | endswith(".jpg")' "$request" >/dev/null
    fi
    if [[ ${TEST_CONTEXT:-0} == 0 ]]; then
      jq -e 'has("contextId") | not' "$request" >/dev/null
    else
      jq -e --arg context "$TEST_CONTEXT" '.contextId == $context' "$request" >/dev/null
    fi
    printf '{"item":{"id":"item-1"}}' > "$output" ;;
  */UploadItemImage)
    if [[ ${TEST_EXPECT_JPEG:-0} == 1 ]]; then
      jq -er .imageData "$request" | base64 -d | head -c 3 | od -An -tx1 | tr -d ' \n' | grep -qx ffd8ff
    fi
    printf '{"image":{"id":"7"},"transcriptionJobId":"9"}' > "$output" ;;
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
  printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" 0 1234 > "$TASK_TMP/hocr"
  [[ $(cat "$TASK_TMP/hocr") == '<html>published</html>' ]]
done
export TEST_TITLE='Codex "Nicholas"; $(do-not-run)'
metadata=$(jq -cn --arg title "$TEST_TITLE" '{external_identifier:"1234",title:$title}' | base64 | tr -d '\n')
printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" 0 1234 "$metadata" > "$TASK_TMP/hocr"
unset TEST_TITLE
for metadata in invalid 'eyJleHRlcm5hbF9pZGVudGlmaWVyIjoiOTk5IiwidGl0bGUiOiJ0aXRsZSJ9'; do
  if printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" 0 1234 "$metadata" > /dev/null 2>&1; then exit 1; fi
done
export TEST_CONTEXT=55
for _ in 1 2; do
  printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" "$TEST_CONTEXT" 1234 > "$TASK_TMP/hocr"
  [[ $(cat "$TASK_TMP/hocr") == '<html>published</html>' ]]
done
for context in -1 abc 1.5 '55;echo'; do
  if printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" "$context" 1234 > "$TASK_TMP/hocr" 2>/dev/null; then
    printf 'Invalid context accepted.\n' >&2
    exit 1
  fi
  [[ ! -s "$TASK_TMP/hocr" ]]
done
for node in '' 0 -1 abc '12;echo'; do
  if printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" 0 "$node" > "$TASK_TMP/hocr" 2>/dev/null; then
    printf 'Invalid node ID accepted.\n' >&2
    exit 1
  fi
  [[ ! -s "$TASK_TMP/hocr" ]]
done
unset TEST_CONTEXT
# Houdini service files are JPEG-compressed tiled pyramids; they must reach
# Scribe as JPEG.
if command -v vips >/dev/null; then
  vips black "$TASK_TMP/black.v" 64 64 --bands 3
  vips tiffsave "$TASK_TMP/black.v" "$TASK_TMP/service.tiff" --tile --pyramid --compression jpeg --tile-width 16 --tile-height 16
  export TEST_EXPECT_JPEG=1
  bash "$SCRIBE_COMMAND" tiff "$TEST_OPERATION" "$TEST_REFERENCE" 0 1234 < "$TASK_TMP/service.tiff" > "$TASK_TMP/hocr"
  [[ $(cat "$TASK_TMP/hocr") == '<html>published</html>' ]]
  if printf image | bash "$SCRIBE_COMMAND" tiff "$TEST_OPERATION" "$TEST_REFERENCE" 0 1234 > "$TASK_TMP/hocr" 2>/dev/null; then
    printf 'Undecodable TIFF was accepted.\n' >&2
    exit 1
  fi
  [[ ! -s "$TASK_TMP/hocr" ]]
  unset TEST_EXPECT_JPEG
else
  printf 'vips not found; skipping TIFF conversion checks.\n' >&2
fi
export TEST_REJECT_CALLBACK=1
if printf image | bash "$SCRIBE_COMMAND" png "$TEST_OPERATION" "$TEST_REFERENCE" 0 1234 > "$TASK_TMP/hocr" 2>/dev/null; then
  printf 'Failed correlation callback was accepted.\n' >&2
  exit 1
fi
[[ ! -s "$TASK_TMP/hocr" ]]
printf 'Scribe command contract passed (contexts, replay, TIFF conversion, correlation signature, failure).\n'
