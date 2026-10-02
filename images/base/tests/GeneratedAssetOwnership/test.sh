#!/command/with-contenv bash
# shellcheck shell=bash

set -euo pipefail

workdir="$(mktemp -d)"
mkdir -p "${workdir}/secrets" "${workdir}/certs"
chown 1234:1235 "${workdir}/secrets" "${workdir}/certs"
cat >"${workdir}/compose.yaml" <<'YAML'
secrets:
  TEST_SECRET:
    file: ./secrets/TEST_SECRET
YAML

(
    cd "${workdir}"
    generate-compose-secrets.sh
    generate-certs.sh
)

test "$(stat -c %u "${workdir}/secrets/TEST_SECRET")" = 1234
test "$(stat -c %g "${workdir}/secrets/TEST_SECRET")" = 1235
test "$(stat -c %a "${workdir}/secrets/TEST_SECRET")" = 600
test "$(stat -c %u "${workdir}/certs/privkey.pem")" = 1234
test "$(stat -c %g "${workdir}/certs/privkey.pem")" = 1235
test "$(stat -c %a "${workdir}/certs/privkey.pem")" = 600
