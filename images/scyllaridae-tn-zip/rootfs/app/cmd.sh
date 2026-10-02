#!/usr/bin/env bash

set -eou pipefail

TMP_DIR=$(mktemp -d)
INPUT_FILE="$TMP_DIR/input.zip"
OUTPUT_FILE="$TMP_DIR/output.png"
TREE_FILE="$TMP_DIR/tree.txt"

trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$INPUT_FILE"
unzip -Z1 "$INPUT_FILE" | tree --fromfile | sed 's/^/    /' > "$TREE_FILE"

magick -background white -fill black -font "Liberation-Mono" -pointsize 12 \
       -size 800x600 caption:@"$TREE_FILE" \
       -resize 750x750 "$OUTPUT_FILE"

# make sure we have a valid image
EXIT_CODE=0
timeout 5 identify -verbose "$OUTPUT_FILE" > /dev/null 2>&1 || EXIT_CODE=$?
if [ $EXIT_CODE != 1 ]; then
  cat "$OUTPUT_FILE"
  exit 0
fi

exit "$EXIT_CODE"
