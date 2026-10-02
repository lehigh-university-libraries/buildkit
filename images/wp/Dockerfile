# syntax=docker/dockerfile:1.20.0
ARG PHP_BASE=nginx-php83
FROM ${PHP_BASE}

LABEL org.opencontainers.image.licenses="GPL-2.0-or-later"

ARG TARGETARCH
ARG PHP_FPM_SOCKET=/run/php-fpm/php-fpm.sock

ARG \
    # renovate: datasource=repology depName=alpine_3_24/msmtp
    MSMTP_VERSION=1.8.32-r1

EXPOSE 80
WORKDIR /var/www/bedrock

RUN --mount=type=cache,id=wp-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        msmtp=="${MSMTP_VERSION}" \
    && \
    mkdir -p /var/www/bedrock/config /var/www/bedrock/web/app/uploads && \
    chown -R nginx:nginx /var/www/bedrock && \
    cleanup.sh

COPY --link config /var/www/bedrock/config
COPY --link web /var/www/bedrock/web

ENV \
    DB_HOST=mariadb \
    DB_PORT=3306 \
    DB_NAME=wordpress \
    DB_USER=wordpress \
    DB_PASSWORD= \
    INGRESS_HOSTNAMES=localhost \
    INGRESS_SCHEME=http \
    WORDPRESS_SITE_TITLE=WordPress \
    WORDPRESS_ADMIN_USERNAME=admin \
    WORDPRESS_ADMIN_EMAIL=admin@example.com \
    WORDPRESS_ADMIN_PASSWORD= \
    WORDPRESS_LOCALE=en_US \
    WORDPRESS_TABLE_PREFIX=wp_ \
    WORDPRESS_BLOG_PUBLIC=0 \
    WORDPRESS_AUTH_KEY= \
    WORDPRESS_SECURE_AUTH_KEY= \
    WORDPRESS_LOGGED_IN_KEY= \
    WORDPRESS_NONCE_KEY= \
    WORDPRESS_AUTH_SALT= \
    WORDPRESS_SECURE_AUTH_SALT= \
    WORDPRESS_LOGGED_IN_SALT= \
    WORDPRESS_NONCE_SALT= \
    LIBOPS_SMTP_HOST=host.docker.internal \
    LIBOPS_SMTP_PORT=25 \
    SMTP_FROM= \
    WP_ENV=production \
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
    PHP_MEMORY_LIMIT=256M

COPY --link rootfs /

HEALTHCHECK CMD test -f /installed && curl -fsS http://localhost/status | grep -q pool
