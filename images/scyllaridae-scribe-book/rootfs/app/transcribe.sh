#!/usr/bin/env bash
# Sourced by cmd.sh. Public manifests are fetched without either credential.
read_manifest
ITEM_ID=$(jq -er '.itemId // ""' "$TASK_TMP/plan.json")
PREVIOUS_SIGNATURE=$(jq -r .sourceSignature "$TASK_TMP/plan.json")
ACTIVE_OPERATION=$(jq -r .operationId "$TASK_TMP/plan.json")
if [[ "$ACTIVE_OPERATION" == "$OPERATION_ID" && "$PREVIOUS_SIGNATURE" != "$SIGNATURE" ]]; then reject changed-book; fi
REUSE=false
if [[ -n "$ITEM_ID" && "$PREVIOUS_SIGNATURE" == "$SIGNATURE" ]]; then
  REUSE=true
  jq -n --arg id "$ITEM_ID" '{itemId:$id}' > "$TASK_TMP/request.json"
  rpc ItemService/GetItem "$TASK_TMP/request.json" "$TASK_TMP/item.json"
else
  jq -n --slurpfile plan "$TASK_TMP/plan.json" --arg manifest "$NODE_URL/book-manifest" --arg context "$CONTEXT_ID" --arg operation "$OPERATION_ID" --arg node "$NID" \
    '{manifestUrl:$manifest,name:$node,externalReferenceId:$plan[0].externalReferenceId,contextId:$context,idempotencyKey:$operation,ignoreExistingOcr:true}' > "$TASK_TMP/request.json"
  rpc ItemService/ImportManifest "$TASK_TMP/request.json" "$TASK_TMP/item.json"
fi
jq -e --slurpfile plan "$TASK_TMP/plan.json" --slurpfile canvases "$TASK_TMP/canvases.json" \
  '.item.externalReferenceId == $plan[0].externalReferenceId and (.item.id | type == "string" and length > 0) and ([.item.images[].canvasUri] == [$canvases[0][] | .id // .["@id"]])' "$TASK_TMP/item.json" > /dev/null || reject canvas-mismatch
jq -c --arg signature "$SIGNATURE" --argjson reuse "$REUSE" \
  '{itemId:.item.id,externalReferenceId:.item.externalReferenceId,sourceSignature:$signature,images:[.item.images[] as $image | {id:($image.id | tonumber),canvasUri:$image.canvasUri,revision:(if $reuse then ([.annotationRevisions[]? | select(.itemImageId == $image.id) | .revision | tonumber][0] // -1) else 0 end)}]}' \
  "$TASK_TMP/item.json" > "$TASK_TMP/correlation.json"
jq -e 'all(.images[]; .id > 0 and .id <= 9007199254740991 and .revision >= 0)' "$TASK_TMP/correlation.json" > /dev/null || reject incomplete-book
# Persist every base revision before requesting any reprocessing. Retries use
# those exact bases even if the current canonical pages have since advanced.
callback correlate "$TASK_TMP/correlated.json" "$TASK_TMP/correlation.json"
jq -e '.reprocess | type == "array" and all(.[]; .id > 0 and .revision >= 0)' "$TASK_TMP/correlated.json" > /dev/null
while IFS= read -r page; do
  jq -n --argjson page "$page" --arg context "$CONTEXT_ID" \
    '{itemImageId:($page.id|tostring),expectedRevision:($page.revision|tostring),contextId:$context}' > "$TASK_TMP/request.json"
  rpc ImageProcessingService/ReprocessItemImage "$TASK_TMP/request.json" "$TASK_TMP/reprocessed.json"
done < <(jq -c '.reprocess[] | select(.revision > 0)' "$TASK_TMP/correlated.json")
# Recover completions that raced ahead of the initial correlation callback.
# Later completions arrive through the existing signed Scribe webhook.
printf '{"pages":[]}' > "$TASK_TMP/completed.json"
while IFS= read -r image; do
  jq -n --argjson image "$image" '{itemImageId:($image.id|tostring),pageSize:1}' > "$TASK_TMP/request.json"
  rpc TranscriptionService/ListTranscriptionJobs "$TASK_TMP/request.json" "$TASK_TMP/jobs.json"
  if jq -e '.jobs[0].status == "TRANSCRIPTION_JOB_STATUS_COMPLETED" or .jobs[0].status == 3' "$TASK_TMP/jobs.json" > /dev/null; then
    jq -n --argjson image "$image" '{itemImageId:($image.id|tostring)}' > "$TASK_TMP/request.json"
    rpc AnnotationService/GetAnnotationPage "$TASK_TMP/request.json" "$TASK_TMP/page.json"
    jq -c --argjson image "$image" --slurpfile page "$TASK_TMP/page.json" '.pages += [{id:($image.id|tonumber),revision:($page[0].revision|tonumber)}]' \
      "$TASK_TMP/completed.json" > "$TASK_TMP/next.json"
    mv "$TASK_TMP/next.json" "$TASK_TMP/completed.json"
  fi
done < <(jq -c '.item.images[]' "$TASK_TMP/item.json")
callback reconcile "$TASK_TMP/reconciled.json" "$TASK_TMP/completed.json"
