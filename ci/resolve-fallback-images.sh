#!/usr/bin/env bash
# Use current-run tags and earlier branch tags only when they actually exist.
set -euo pipefail
current=${1:?current image plan required}
cumulative=${2:?cumulative image plan required}
branch=${3:?branch tag required}
repository=${4:?registry repository required}
metadata=${METADATA_TOOL:-$(dirname "$0")/image-metadata.sh}
docker_command=${DOCKER:-docker}

jq -e 'type == "array" and all(.[]; type == "string")' <<<"$current" >/dev/null
jq -e 'type == "array" and all(.[]; type == "string")' <<<"$cumulative" >/dev/null
available=$current
error_file=$(mktemp)
trap 'rm -f "$error_file"' EXIT
while IFS= read -r image; do
  if jq -e --arg image "$image" 'index($image) != null' <<<"$current" >/dev/null; then
    continue
  fi
  name=$("$metadata" published-image "$image")
  tag=$("$metadata" first-tag "$image" fallback "$branch")
  ref="$repository/$name:$tag"
  if "$docker_command" manifest inspect "$ref" >/dev/null 2>"$error_file"; then
    available=$(jq -c --arg image "$image" '. + [$image]' <<<"$available")
  elif grep -Eiq 'no such manifest|manifest unknown|manifest not found' "$error_file"; then
    echo "No published branch tag for $ref; using the published version." >&2
  else
    echo "Unable to check $ref:" >&2
    cat "$error_file" >&2
    exit 1
  fi
done < <(jq -r '.[]' <<<"$cumulative")
jq -c 'unique' <<<"$available"
