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

response="$(mktemp)"
trap 'rm -f -- "$response"' EXIT

curl -fsSL --connect-timeout 5 --max-time 30 \
    -o "$response" http://localhost/admin/users/login
grep -Eq 'action="[^"]*/admin/users/login"' "$response"

for protected_path in \
    /application/config/db.ini \
    /application/controllers/UsersController.php; do
    status="$(curl -sS --connect-timeout 5 --max-time 30 \
        -o /dev/null -w '%{http_code}' "http://localhost${protected_path}")"
    case "$status" in
        403 | 404) ;;
        *)
            echo "Protected Omeka Classic path ${protected_path} returned HTTP ${status}" >&2
            exit 1
            ;;
    esac
done
