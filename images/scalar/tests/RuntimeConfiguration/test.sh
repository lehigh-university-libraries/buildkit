#!/command/with-contenv bash
# shellcheck shell=bash
set -euo pipefail
for _ in $(seq 1 60); do
  if curl -fsS http://localhost/status | grep -q pool; then break; fi
  sleep 1
done
cat /probe.php > /opt/scalar/codeigniter.php
response=$(curl -sS -H 'Host: attacker.invalid' -H 'X-Forwarded-Host: attacker.invalid' \
  http://localhost/config-check)
[[ "$response" == runtime-config-ok ]] || { printf '%s\n' "$response" >&2; exit 1; }
for file in database.php config.php local_settings.php; do
  status=$(curl -sS -o /dev/null -w '%{http_code}' "http://localhost/system/application/config/$file")
  test "$status" = 404
done
printf '%s\n' 'PASS: upstream keys, confd secrets, PHP escaping, worker isolation, canonical URL, permissions, and stderr logging'
