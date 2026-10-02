# syntax=docker/dockerfile:1.20.0
ARG PHP_BASE=nginx-php83
FROM ${PHP_BASE}

LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"

ARG PHP_FPM_SOCKET=/run/php-fpm/php-fpm.sock

EXPOSE 80
WORKDIR /var/www/drupal

RUN mkdir -p /etc/drupal /var/www/drupal/config/sync /var/www/drupal/web/sites/default/files /var/www/drupal/private/php && \
    chown -R nginx:nginx /var/www/drupal && \
    cleanup.sh && \
    if ! command -v php >/dev/null 2>&1; then \
        php_binary="$(find /usr/bin -maxdepth 1 -type f -name 'php[0-9][0-9]' | sort | tail -n 1)" && \
        if [ -z "${php_binary}" ]; then \
            echo "Drupal base requires a PHP binary in PATH" >&2; \
            exit 127; \
        fi && \
        ln -sf "${php_binary}" /usr/bin/php && \
        ln -sf "${php_binary}" /usr/local/bin/php; \
    fi && \
    command -v php >/dev/null && \
    php -v >/dev/null && \
    composer --version >/dev/null

ENV \
    DB_HOST=mariadb \
    DB_PORT=3306 \
    DB_NAME=drupal \
    DB_USER=drupal \
    DB_PASSWORD= \
    DRUPAL_DEFAULT_ACCOUNT_EMAIL=webmaster@localhost.com \
    DRUPAL_DEFAULT_ACCOUNT_NAME=admin \
    DRUPAL_DEFAULT_ACCOUNT_PASSWORD= \
    DRUPAL_DEFAULT_CONFIGDIR=/var/www/drupal/config/sync \
    DRUPAL_DEFAULT_INSTALL_EXISTING_CONFIG=false \
    DRUPAL_DEFAULT_EMAIL=webmaster@localhost.com \
    DRUPAL_DEFAULT_LOCALE=en \
    DRUPAL_DEFAULT_NAME=Drupal \
    DRUPAL_DEFAULT_PROFILE=standard \
    DRUPAL_DEFAULT_SALT= \
    DRUPAL_DEFAULT_SOLR_CORE=default \
    DRUPAL_DEFAULT_SOLR_HOST=solr \
    DRUPAL_DEFAULT_SOLR_PORT=8983 \
    DRUPAL_DEFAULT_SUBDIR=default \
    INGRESS_HOSTNAMES=localhost \
    INGRESS_SCHEME=http \
    LIBOPS_SMTP_HOST=host.docker.internal \
    LIBOPS_SMTP_PORT=25 \
    NGINX_CLIENT_BODY_TIMEOUT=60s \
    NGINX_CLIENT_MAX_BODY_SIZE=0 \
    NGINX_ERROR_LOG_LEVEL=warn \
    NGINX_FASTCGI_CONNECT_TIMEOUT=300s \
    NGINX_FASTCGI_READ_TIMEOUT=300s \
    NGINX_FASTCGI_SEND_TIMEOUT=300s \
    NGINX_KEEPALIVE_TIMEOUT=75s \
    NGINX_LINGERING_TIMEOUT=5s \
    NGINX_PROXY_CONNECT_TIMEOUT=60s \
    NGINX_PROXY_READ_TIMEOUT=60s \
    NGINX_PROXY_SEND_TIMEOUT=60s \
    NGINX_REAL_IP_HEADER=X-Forwarded-For \
    NGINX_REAL_IP_RECURSIVE=off \
    NGINX_SEND_TIMEOUT=60s \
    NGINX_SET_REAL_IP_FROM=172.0.0.0/8 \
    NGINX_SET_REAL_IP_FROM2=172.0.0.0/8 \
    NGINX_SET_REAL_IP_FROM3=172.0.0.0/8 \
    NGINX_WORKER_CONNECTIONS=1024 \
    NGINX_WORKER_PROCESSES=auto \
    PHP_FPM_SOCKET=${PHP_FPM_SOCKET} \
    PHP_MAX_EXECUTION_TIME=300 \
    PHP_MAX_INPUT_TIME=300 \
    PHP_DEFAULT_SOCKET_TIMEOUT=300 \
    PHP_REQUEST_TERMINATE_TIMEOUT=300 \
    PHP_MEMORY_LIMIT=256M \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=600000

COPY --link rootfs /

RUN chown -R nginx:nginx /var/www/drupal

HEALTHCHECK CMD { [ ! -f /var/www/drupal/web/core/lib/Drupal.php ] || [ -f /installed ]; } && curl -fsS http://localhost/status | grep -q pool
