#!/usr/bin/env bash
set -euo pipefail

# Like mergepdf, the request identifies a node; source bytes are not used.
NODE_URL=${1:-}
MODE=${2:-}
OPERATION_ID=${3:-}
CONTEXT_ID=${4:-0}
: "${SCRIBE_API_URL:?Scribe API origin required}"
: "${SCRIBE_WORKSPACE_ID:?Scribe workspace required}"
: "${ISLANDORA_SCRIBE_CORRELATION_URL:?Islandora correlation URL required}"
: "${ISLANDORA_SCRIBE_CORRELATION_SECRET:?Separate signing secret required}"
: "${SCYLLARIDAE_AUTH:?Islandora JWT required}"
if [[ ! "$ISLANDORA_SCRIBE_CORRELATION_URL" =~ ^https://[^/?#@]+/islandora-scribe/correlation$ || ! "$SCRIBE_API_URL" =~ ^https://[^/?#@]+/?$ || ! "$SCRIBE_WORKSPACE_ID" =~ ^[1-9][0-9]{0,18}$ || ! "$CONTEXT_ID" =~ ^(0|[1-9][0-9]{0,18})$ || ! "$OPERATION_ID" =~ ^[a-f0-9]{32}$ || ( "$MODE" != transcribe && "$MODE" != pdf ) ]]; then
  printf 'Invalid book request or service configuration.\n' >&2
  exit 1
fi
if (( ${#ISLANDORA_SCRIBE_CORRELATION_SECRET} < 32 || ${#ISLANDORA_SCRIBE_CORRELATION_SECRET} > 1024 )); then exit 1; fi
ISLANDORA_ORIGIN=${ISLANDORA_SCRIBE_CORRELATION_URL%/islandora-scribe/correlation}
NID=${NODE_URL#"$ISLANDORA_ORIGIN/node/"}
if [[ ! "$NID" =~ ^[1-9][0-9]{0,18}$ || "$NODE_URL" != "$ISLANDORA_ORIGIN/node/$NID" || ( "$MODE" == transcribe && "$CONTEXT_ID" == 0 ) ]]; then
  printf 'Book node must belong to the configured Islandora origin.\n' >&2
  exit 1
fi
umask 077
TASK_TMP=$(mktemp -d)
trap 'rm -rf "$TASK_TMP"' EXIT
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=images/scyllaridae-scribe-book/rootfs/app/common.sh
source "$SCRIPT_DIR/common.sh"
callback plan "$TASK_TMP/plan.json"
if [[ "$MODE" == transcribe ]]; then
  # shellcheck source=images/scyllaridae-scribe-book/rootfs/app/transcribe.sh
  source "$SCRIPT_DIR/transcribe.sh"
else
  # shellcheck source=images/scyllaridae-scribe-book/rootfs/app/pdf.sh
  source "$SCRIPT_DIR/pdf.sh"
fi
printf 'OK\n'
