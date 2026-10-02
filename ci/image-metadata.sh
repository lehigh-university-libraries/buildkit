#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GO="${GO:-}"
if [[ -z "$GO" ]]; then
  if command -v go >/dev/null 2>&1; then
    GO="go"
  elif [[ -x /usr/local/go/bin/go ]]; then
    GO="/usr/local/go/bin/go"
  else
    echo "Go is required to run image metadata commands." >&2
    exit 127
  fi
fi

cd "$ROOT_DIR"
exec "$GO" run ./cmd/buildkit metadata "$@"
