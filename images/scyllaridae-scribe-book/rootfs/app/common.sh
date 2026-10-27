#!/usr/bin/env bash
# Sourced by cmd.sh; request and response files stay private to one operation.

# Permanent request failures are acknowledged so Alpaca does not retry them.
reject() { printf 'Book request rejected (%s).\n' "$1" >&2; printf 'Rejected\n'; exit 0; }

request() {
  local url=$1 config=$2 input=$3 output=$4 method=${5:-POST} operation=${7:-book-request} status
  local args=(--silent --show-error --connect-timeout 30 --max-time 900 --max-filesize "${6:-20971520}" --max-redirs 0 --output "$output" --write-out '%{http_code}' --config "$config" --request "$method")
  if [[ "$method" != GET ]]; then args+=(--data-binary "@$input"); fi
  if ! status=$(curl "${args[@]}" "$url"); then printf 'Book service transport failed (%s).\n' "$operation" >&2; exit 1; fi
  case "$status" in
    200|201|204) ;;
    408|409|429|5??) printf 'Book service temporarily unavailable (%s, HTTP %s).\n' "$operation" "$status" >&2; exit 1 ;;
    *) reject "$status" ;;
  esac
}

rpc() {
  local method=$1 input=$2 output=$3 credential auth_header
  if [[ -n "${SCRIBE_API_JWT_FILE:-}" ]]; then
    credential="Bearer $(cat "$SCRIBE_API_JWT_FILE")"; auth_header=Authorization
  else
    credential=${SCRIBE_API_TOKEN:?Scribe API key required}; auth_header=X-Scribe-API-Key
  fi
  jq -nr --arg key "$credential" --arg header "$auth_header" --arg workspace "$SCRIBE_WORKSPACE_ID" \
    '[$header + ": " + $key, "X-Scribe-Workspace-ID: " + $workspace, "Content-Type: application/json", "Connect-Protocol-Version: 1"][] | "header = " + (. | @json)' > "$TASK_TMP/scribe.conf"
  request "${SCRIBE_API_URL%/}/scribe.v1.$method" "$TASK_TMP/scribe.conf" "$input" "$output" POST 20971520 "scribe:$method"
}

callback() {
  local phase=$1 output=$2 extra=${3:-} timestamp signature
  if [[ -z "$extra" ]]; then printf '{}' > "$TASK_TMP/extra.json"; extra=$TASK_TMP/extra.json; fi
  jq -c --arg phase "$phase" --arg mode "$MODE" --arg op "$OPERATION_ID" --argjson node "$NID" --argjson context "$CONTEXT_ID" --argjson workspace "$SCRIBE_WORKSPACE_ID" \
    '. + {phase:$phase,mode:$mode,operationId:$op,nodeId:$node,contextId:$context,workspaceId:$workspace}' "$extra" > "$TASK_TMP/callback.json"
  timestamp=$(date +%s)
  signature=$({ printf '%s.' "$timestamp"; cat "$TASK_TMP/callback.json"; } | openssl dgst -sha256 -hmac "$ISLANDORA_SCRIBE_CORRELATION_SECRET" -r | cut -d ' ' -f 1)
  jq -nr --arg timestamp "$timestamp" --arg signature "v1=$signature" \
    '["Content-Type: application/json", "X-Scribe-Timestamp: " + $timestamp, "X-Scribe-Signature: " + $signature][] | "header = " + (. | @json)' > "$TASK_TMP/callback.conf"
  request "${ISLANDORA_SCRIBE_CORRELATION_URL%/correlation}/book" "$TASK_TMP/callback.conf" "$TASK_TMP/callback.json" "$output" POST 20971520 "islandora:callback:$phase"
}

read_manifest() {
  : > "$TASK_TMP/anonymous.conf"
  request "$NODE_URL/book-manifest" "$TASK_TMP/anonymous.conf" '' "$TASK_TMP/manifest.json" GET 20971520 islandora:manifest
  jq -e '(.items // .sequences[0].canvases) | type == "array" and length > 0 and length <= 1000' "$TASK_TMP/manifest.json" > /dev/null || reject manifest
  jq -c '.items // .sequences[0].canvases' "$TASK_TMP/manifest.json" > "$TASK_TMP/canvases.json"
  jq -Sc '[.[] | [(.id // .["@id"]), .width, .height, (.items // .images)]]' "$TASK_TMP/canvases.json" > "$TASK_TMP/painting.json"
  # Used by the transcribe and PDF scripts that source this file.
  # shellcheck disable=SC2034
  SIGNATURE=$(sha256sum "$TASK_TMP/painting.json" | cut -d ' ' -f 1)
}
