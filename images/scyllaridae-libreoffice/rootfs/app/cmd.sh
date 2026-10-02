#!/usr/bin/env bash
set -eou pipefail
TMP_DIR=$(mktemp -d /tmp/libreoffice-XXXXXX)
TMP_FILE="$TMP_DIR/input"
PDF="$TMP_DIR/input.pdf"
PROFILE_DIR="$TMP_DIR/profile"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$TMP_FILE"

libreoffice \
  --headless \
  --convert-to pdf \
  "$TMP_FILE" \
  --outdir "$TMP_DIR" \
  -env:UserInstallation=file://"$PROFILE_DIR"

if ! file "$PDF" | grep -q PDF; then
  echo "Failed to create PDF" >&2
  exit 1
fi

cat "$PDF"

