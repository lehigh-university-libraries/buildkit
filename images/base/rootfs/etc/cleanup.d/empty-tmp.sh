#!/bin/sh
for path in /tmp/* /tmp/.[!.]* /tmp/..?*; do
    [ -e "${path}" ] || continue
    rm -rf "${path}" 2>/dev/null || true
done
