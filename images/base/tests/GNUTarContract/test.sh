#!/command/with-contenv bash
# shellcheck shell=bash

set -euo pipefail

workspace=$(mktemp -d)
cleanup() {
    rm -rf "${workspace}"
}
trap cleanup EXIT

mkdir -p "${workspace}/source/directory" "${workspace}/restored"
printf '%s\n' backup-contract >"${workspace}/source/directory/file"
ln "${workspace}/source/directory/file" "${workspace}/source/directory/hard-link"

tar --version | grep -Fq 'GNU tar'
tar \
    --hard-dereference \
    --create \
    --file "${workspace}/archive.tar" \
    --directory "${workspace}/source" \
    .
tar \
    --delay-directory-restore \
    --extract \
    --file "${workspace}/archive.tar" \
    --directory "${workspace}/restored"

test "$(cat "${workspace}/restored/directory/file")" = backup-contract
test "$(cat "${workspace}/restored/directory/hard-link")" = backup-contract
