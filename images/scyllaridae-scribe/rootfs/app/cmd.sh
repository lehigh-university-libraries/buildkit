#!/usr/bin/env bash

set -eou pipefail

SOURCE_EXT="${1,,}"
case "$SOURCE_EXT" in
  jpg|jpeg|png|tif|tiff|jp2|webp|gif) ;;
  *) printf 'Unsupported image extension: %s\n' "$SOURCE_EXT" >&2; exit 1 ;;
esac

: "${SCRIBE_API_URL:?SCRIBE_API_URL is required}"
: "${SCRIBE_API_TOKEN:?SCRIBE_API_TOKEN is required}"
: "${SCRIBE_WORKSPACE_ID:?SCRIBE_WORKSPACE_ID is required}"
if [[ ! "$SCRIBE_WORKSPACE_ID" =~ ^[1-9][0-9]*$ ]]; then
  printf 'SCRIBE_WORKSPACE_ID must be a positive integer.\n' >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

INPUT="$TMP_DIR/image.$SOURCE_EXT"
cat > "$INPUT"
SIZE=$(wc -c < "$INPUT" | tr -d ' ')
if (( SIZE == 0 || SIZE > 104857600 )); then
  printf 'Image must be between 1 byte and 100 MiB.\n' >&2
  exit 1
fi

DIGEST=$(sha256sum "$INPUT" | cut -d ' ' -f 1)
FILENAME="image-${DIGEST:0:16}.$SOURCE_EXT"
BATCH_ID=$(cat /proc/sys/kernel/random/uuid)
BASE_URL=${SCRIBE_API_URL%/}
jq -nr \
  --arg token "$SCRIBE_API_TOKEN" \
  --arg workspace "$SCRIBE_WORKSPACE_ID" \
  '"header = " + (("X-Scribe-API-Key: " + $token) | @json), "header = " + (("X-Scribe-Workspace-ID: " + $workspace) | @json)' \
  > "$TMP_DIR/curl.conf"

rpc() {
  local method=$1 request=$2 response=$3 status
  if ! status=$(curl --silent --show-error --output "$response" --write-out '%{http_code}' \
    --connect-timeout 10 --max-time 900 \
    --request POST "$BASE_URL/scribe.v1.$method" \
    --header 'Content-Type: application/json' \
    --header 'Connect-Protocol-Version: 1' \
    --config "$TMP_DIR/curl.conf" \
    --data-binary "@$request"); then
    printf 'Scribe request failed: %s\n' "$method" >&2
    return 1
  fi
  if [[ ! "$status" =~ ^2 ]]; then
    printf 'Scribe request failed: %s returned HTTP %s\n' "$method" "$status" >&2
    return 1
  fi
}

jq -n \
  --arg batch_id "$BATCH_ID" \
  --arg filename "$FILENAME" \
  --arg size "$SIZE" \
  --arg digest "$DIGEST" \
  '{batchId:$batch_id,name:$filename,files:[{filename:$filename,size:$size,contentSha256:$digest}]}' \
  > "$TMP_DIR/start-batch.json"
rpc ItemService/StartUploadBatch "$TMP_DIR/start-batch.json" "$TMP_DIR/start-batch-response.json"

base64 "$INPUT" | tr -d '\n' > "$TMP_DIR/image.base64"
jq -n \
  --arg batch_id "$BATCH_ID" \
  --rawfile image_data "$TMP_DIR/image.base64" \
  '{batchId:$batch_id,sequence:1,imageData:$image_data}' \
  > "$TMP_DIR/upload-image.json"
rpc ItemService/UploadItemImage "$TMP_DIR/upload-image.json" "$TMP_DIR/upload-image-response.json"

JOB_ID=$(jq -er '.transcriptionJobId | select(. != "0" and . != 0)' "$TMP_DIR/upload-image-response.json")
for ((attempt = 0; attempt < 1800; attempt++)); do
  jq -n --arg job_id "$JOB_ID" '{jobId:$job_id}' > "$TMP_DIR/get-job.json"
  rpc TranscriptionService/GetTranscriptionJob "$TMP_DIR/get-job.json" "$TMP_DIR/job.json"
  JOB_STATUS=$(jq -er '.job.status' "$TMP_DIR/job.json")
  case "$JOB_STATUS" in
    TRANSCRIPTION_JOB_STATUS_COMPLETED|3) break ;;
    TRANSCRIPTION_JOB_STATUS_FAILED|TRANSCRIPTION_JOB_STATUS_CANCELED|TRANSCRIPTION_JOB_STATUS_SUPERSEDED|4|5|6)
      printf 'Scribe transcription ended with status %s.\n' "$JOB_STATUS" >&2
      exit 1
      ;;
  esac
  sleep 2
done
if (( attempt == 1800 )); then
  printf 'Scribe transcription timed out.\n' >&2
  exit 1
fi

ITEM_IMAGE_ID=$(jq -er '.image.id' "$TMP_DIR/upload-image-response.json")
jq -n --arg item_image_id "$ITEM_IMAGE_ID" '{itemImageId:$item_image_id}' \
  > "$TMP_DIR/get-page.json"
rpc AnnotationService/GetAnnotationPage "$TMP_DIR/get-page.json" "$TMP_DIR/page.json"
REVISION=$(jq -er '.revision' "$TMP_DIR/page.json")
jq -n \
  --arg item_image_id "$ITEM_IMAGE_ID" \
  --arg revision "$REVISION" \
  '{itemImageId:$item_image_id,expectedRevision:$revision,format:"ANNOTATION_EXPORT_FORMAT_HOCR"}' \
  > "$TMP_DIR/export-hocr.json"
rpc AnnotationService/ExportAnnotationPage "$TMP_DIR/export-hocr.json" "$TMP_DIR/hocr.json"
jq -erj '.content | select(length > 0) | @base64d' "$TMP_DIR/hocr.json"
