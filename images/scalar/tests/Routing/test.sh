#!/command/with-contenv bash
set -euo pipefail
mkdir -p /opt/scalar/book /opt/scalar/system/application/config /opt/scalar/.git
printf 'media-ok\n' > /opt/scalar/book/media.txt
printf 'private\n' > /opt/scalar/book/private.sql.gz
printf 'private\n' > /opt/scalar/book/private.patch
printf 'private\n' > /opt/scalar/book/shell.php
printf 'public\n' > /opt/scalar/maintenance.html
printf 'private\n' > /opt/scalar/README.md
printf 'private\n' > /opt/scalar/system/application/config/database.php
printf 'private\n' > /opt/scalar/.git/config
cat > /opt/scalar/codeigniter.php <<'PHP'
<?php echo 'route:' . ($_SERVER['PATH_INFO'] ?? '') . ':' . ($_SERVER['HTTPS'] ?? 'off') . ':query:' . ($_SERVER['QUERY_STRING'] ?? '');
PHP
for _ in $(seq 1 60); do
  if curl -fsS http://localhost/status | grep -q pool; then break; fi
  sleep 1
done
curl -fsS http://localhost/book/media.txt | grep -q media-ok
curl -fsS http://localhost/book | grep -q 'route:/book:on'
curl -fsS 'http://localhost/book/story?a=1&b=2' | grep -q 'route:/book/story:on:query:a=1\&b=2'
curl -fsS http://localhost/maintenance.html | grep -q public
test "$(php -r 'echo ini_get("short_open_tag");')" = 1
php -m | grep -qx ldap
php -m | grep -qx mysqli
for path in /README.md /book/private.sql.gz /book/private.patch /book/shell.php /system/application/config/database.php /.git/config /%2egit/config; do
  status=$(curl --path-as-is -sS -o /dev/null -w '%{http_code}' "http://localhost$path")
  [ "$status" = 404 ] || { echo "$path returned $status"; exit 1; }
done
for agent in SemrushBot DotBot YandexBot; do
  status=$(curl -sS -A "$agent" -o /dev/null -w '%{http_code}' http://localhost/book/media.txt)
  [ "$status" = 403 ] || { echo "$agent returned $status"; exit 1; }
done

echo "PASS: routes, PHP-FPM, forwarded HTTPS, denied files and bot rules"
