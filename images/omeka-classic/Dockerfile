# syntax=docker/dockerfile:1.20.0
ARG PHP_BASE=nginx-php83
FROM ${PHP_BASE}

LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

ARG TARGETARCH
ARG PHP_FPM_SOCKET=/run/php-fpm/php-fpm.sock
ARG PHP_PACKAGE=php83

ARG \
    # renovate: datasource=repology depName=alpine_3_24/imagemagick
    IMAGEMAGICK_VERSION=7.1.2.30-r0 \
    # renovate: datasource=repology depName=alpine_3_24/msmtp
    MSMTP_VERSION=1.8.32-r1 \
    # renovate: datasource=repology depName=alpine_3_24/unzip
    UNZIP_VERSION=6.0-r16 \
    # renovate: datasource=github-releases depName=omeka-classic packageName=omeka/Omeka
    SOFTWARE_VERSION=3.2.1

ARG FILE=omeka-${SOFTWARE_VERSION}.zip
ARG URL=https://github.com/omeka/Omeka/releases/download/v${SOFTWARE_VERSION}/${FILE}
ARG SHA256="2cb4d65511321cc5c009cb61516d9ed97378a800fc4a26eb46450c3c4ca230c2"

EXPOSE 80
WORKDIR /var/www/omeka-classic

RUN --mount=type=cache,id=omeka-classic-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        imagemagick=="${IMAGEMAGICK_VERSION}" \
        msmtp=="${MSMTP_VERSION}" \
        unzip=="${UNZIP_VERSION}" \
        "${PHP_PACKAGE}-exif" \
    && \
    cleanup.sh

RUN --mount=type=cache,id=omeka-classic-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    download.sh \
        --url "${URL}" \
        --sha256 "${SHA256}" \
        --strip \
        --dest /var/www/omeka-classic \
    && \
    mkdir -p /usr/share/licenses/omeka-classic && \
    cp /var/www/omeka-classic/license.txt /usr/share/licenses/omeka-classic/license.txt && \
    chown -R nginx:nginx /var/www/omeka-classic && \
    cleanup.sh

ENV \
    DB_HOST=mariadb \
    DB_PORT=3306 \
    DB_NAME=omeka_classic \
    DB_USER=omeka_classic \
    DB_PASSWORD= \
    OMEKA_CLASSIC_ADMIN_USERNAME=admin \
    OMEKA_CLASSIC_ADMIN_EMAIL=admin@example.com \
    OMEKA_CLASSIC_ADMIN_PASSWORD= \
    OMEKA_CLASSIC_SITE_TITLE="Omeka Classic" \
    OMEKA_CLASSIC_TABLE_PREFIX=omeka_ \
    INGRESS_HOSTNAMES=localhost \
    INGRESS_SCHEME=http \
    LIBOPS_SMTP_HOST=host.docker.internal \
    LIBOPS_SMTP_PORT=25 \
    SMTP_FROM= \
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

HEALTHCHECK CMD test -f /installed && test -f /var/www/omeka-classic/index.php && curl -fsS http://localhost/status | grep -q pool
