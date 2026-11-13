#!/command/with-contenv bash
# shellcheck shell=bash
set -euo pipefail
# The persistent webroot must point at the bundled code, never a host copy.
grep -Eq "^[0-9]+\.[0-9]+\.[0-9]+$" /usr/share/scalar-version
php -n /ldap-auth.php
php -n /asset-paths.php
php /mcrypt.php
php /rdf-hostname.php
php /rdfa-optional-fields.php
php /arc2-xml.php
php /dashboard-book-id.php
test "$(readlink /opt/scalar/system)" = /usr/local/share/scalar/system
test "$(readlink /opt/scalar/codeigniter.php)" = /usr/local/share/scalar/codeigniter.php
grep -Fq "define('FCPATH', '/opt/scalar/');" /usr/local/share/scalar/codeigniter.php
if s6-setuidgid nginx sh -c 'test -w /usr/local/share/scalar/codeigniter.php'; then
  echo 'Application code must not be writable by PHP-FPM' >&2
  exit 1
fi
s6-setuidgid nginx mkdir /opt/scalar/book
mkdir -p /opt/scalar/.git
printf 'media-ok\n' > /opt/scalar/book/media.txt
printf 'private\n' > /opt/scalar/book/private.sql.gz
printf 'private\n' > /opt/scalar/book/private.patch
printf 'private\n' > /opt/scalar/book/shell.php
printf 'private\n' > /opt/scalar/README.md
printf 'private\n' > /opt/scalar/.git/config
cat > /opt/scalar/codeigniter.php <<'PHP'
<?php
define('BASEPATH', '/usr/local/share/scalar/system/');
require BASEPATH . 'application/config/database.php';
require BASEPATH . 'application/config/local_settings.php';
if (($_SERVER['PATH_INFO'] ?? '') === '/login-header-fixture') {
    for ($i = 0; $i < 3; $i++) {
        header('Set-Cookie: fixture'.$i.'='.str_repeat('x', 3000).'; Path=/; Secure; HttpOnly', false);
    }
}
echo 'route:' . ($_SERVER['PATH_INFO'] ?? '') . ':' . ($_SERVER['HTTPS'] ?? 'off') . ':query:' . ($_SERVER['QUERY_STRING'] ?? '') . ':db:' . $db['default']['hostname'] . ':ldap:' . $config['ldap_email_domain'] . ':' . $config['ldap_object_class'];
PHP
for _ in $(seq 1 60); do
  if curl -fsS http://localhost/status | grep -q pool; then break; fi
  sleep 1
done
curl -fsS http://localhost/book/media.txt | grep -q media-ok
test "$(curl -fsS http://localhost/google204a4e549d4da46a.html)" = 'google-site-verification: google204a4e549d4da46a.html'
curl -fsS -D /tmp/login-headers http://localhost/login-header-fixture | grep -q 'route:/login-header-fixture:on'
test "$(grep -c '^Set-Cookie:' /tmp/login-headers)" = 3
curl -fsS http://localhost/book | grep -q 'route:/book:on'
curl -fsS 'http://localhost/book/story?a=1&b=2' | grep -q 'route:/book/story:on:query:a=1\&b=2:db:staging-db.invalid:ldap:example.edu:person'
curl -fsS http://localhost/maintenance.html >/dev/null
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
