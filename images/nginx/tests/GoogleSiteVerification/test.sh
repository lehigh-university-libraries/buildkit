#!/command/with-contenv bash
# shellcheck shell=bash
set -euo pipefail
path=/google204a4e549d4da46a.html
expected=/usr/local/share/nginx/verification/google204a4e549d4da46a.html
for _ in $(seq 1 60); do
  if curl -fsS http://localhost/status | grep -q pool; then break; fi
  sleep 1
done
curl -fsS "http://localhost$path" -o /tmp/google-verification
cmp "$expected" /tmp/google-verification
test "$(curl -s -o /dev/null -w '%{http_code}' http://localhost/not-verification)" = 404

# Application servers replace the base server and add broad HTML/PHP routing.
cat > /etc/nginx/http.d/default.conf <<'NGINX'
server {
    listen 80 default_server;
    root /nonexistent-application-root;
    include /etc/nginx/shared/fpm.conf;
    location ~ \.html$ { return 403; }
    location / { return 418; }
}
NGINX
nginx -t
nginx -s reload
for _ in $(seq 1 60); do
  status=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/application-route)
  if [[ $status == 418 ]]; then break; fi
  sleep 1
done
test "$status" = 418
curl -fsS "http://localhost$path?verification=1" -o /tmp/google-verification
cmp "$expected" /tmp/google-verification
test "$(curl -s -o /dev/null -w '%{http_code}' http://localhost/google-other.html)" = 403
echo 'PASS: Google verification survives application root and routing overrides'
