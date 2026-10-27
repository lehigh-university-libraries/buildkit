#!/usr/bin/env bash
# Sourced by cmd.sh. Like mergepdf, upload to the node's Original File slot.
read_manifest
if [[ $(jq -r .sourceSignature "$TASK_TMP/plan.json") != "$SIGNATURE" ]]; then reject changed-book; fi
ITEM_ID=$(jq -er '.itemId | select(length > 0)' "$TASK_TMP/plan.json") || reject untranscribed-book
jq -n --arg item "$ITEM_ID" '{itemId:$item}' > "$TASK_TMP/request.json"
rpc ItemService/GetItem "$TASK_TMP/request.json" "$TASK_TMP/item.json"
jq -e '.annotationRevisions | length > 0' "$TASK_TMP/item.json" > /dev/null || reject incomplete-book
jq -e '(.annotationRevisions|length) == (.item.images|length)' "$TASK_TMP/item.json" > /dev/null || reject incomplete-book
jq -c '{itemId:.item.id,format:"ANNOTATION_EXPORT_FORMAT_PDF",expectedRevisions:.annotationRevisions}' "$TASK_TMP/item.json" > "$TASK_TMP/request.json"
rpc ItemService/PrepareItemExport "$TASK_TMP/request.json" "$TASK_TMP/prepared.json"
DOWNLOAD=$(jq -er .downloadUrl "$TASK_TMP/prepared.json")
if [[ "$DOWNLOAD" == /v1/item-exports/* ]]; then DOWNLOAD="${SCRIBE_API_URL%/}$DOWNLOAD"; fi
TOKEN=${DOWNLOAD#"${SCRIBE_API_URL%/}/v1/item-exports/"}
if [[ ! "$TOKEN" =~ ^[A-Za-z0-9_-]+$ || "$DOWNLOAD" != "${SCRIBE_API_URL%/}/v1/item-exports/$TOKEN" ]]; then reject export-url; fi
request "$DOWNLOAD" "$TASK_TMP/scribe.conf" '' "$TASK_TMP/book.pdf" GET 67108864 scribe:download-pdf
if [[ $(head -c 5 "$TASK_TMP/book.pdf") != '%PDF-' ]]; then reject invalid-pdf; fi
callback plan "$TASK_TMP/current-plan.json"
UPLOAD=$(jq -er .uploadUrl "$TASK_TMP/plan.json")
TERM_ID=${UPLOAD#"$NODE_URL/media/document/"}
FILE_URI=$(jq -er .fileUri "$TASK_TMP/plan.json")
if [[ ! "$TERM_ID" =~ ^[1-9][0-9]*$ || "$UPLOAD" != "$NODE_URL/media/document/$TERM_ID" || ! "$FILE_URI" =~ ^private://derivatives/[0-9]{4}/[0-9]{2}/pc/$NID\.pdf$ ]]; then reject destination; fi
jq -nr --arg auth "$SCYLLARIDAE_AUTH" --arg uri "$FILE_URI" \
  '["Authorization: " + $auth,"Content-Type: application/pdf","Content-Location: " + $uri][] | "header = " + (. | @json)' > "$TASK_TMP/islandora.conf"
request "$UPLOAD" "$TASK_TMP/islandora.conf" "$TASK_TMP/book.pdf" "$TASK_TMP/upload.json" PUT 20971520 islandora:upload-pdf
