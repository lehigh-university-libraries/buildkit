#!/command/with-contenv bash
# shellcheck shell=bash

set -euo pipefail

on_terminate() {
    exit 0
}
trap 'on_terminate' SIGTERM

for _ in $(seq 1 150); do
    if [ -f /installed ]; then
        break
    fi
    sleep 2
done
test -f /installed

curl -fsSL --connect-timeout 5 --max-time 30 \
    -o /dev/null http://localhost/index.php/index/login

for protected_path in \
    /config.inc.php \
    /tools/install.php \
    /classes/core/Application.php; do
    status="$(curl -sS --connect-timeout 5 --max-time 30 \
        -o /dev/null -w '%{http_code}' "http://localhost${protected_path}")"
    if [ "$status" != 404 ]; then
        echo "Protected OJS path ${protected_path} returned HTTP ${status}" >&2
        exit 1
    fi
done
