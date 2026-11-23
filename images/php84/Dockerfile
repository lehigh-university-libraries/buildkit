# syntax=docker/dockerfile:1.20.0
ARG SOFTWARE_VERSION=8.4.28-r6-alpine3.24
FROM ghcr.io/libops/php:${SOFTWARE_VERSION}@sha256:9018341576b59c8938fd26c268ff3eb1e0d00ec0a24ba08365584c7330b90ebd AS php_packages
FROM base

ARG TARGETARCH
ARG SOFTWARE_VERSION
# renovate: datasource=github-releases depName=custom-composer packageName=composer/composer
ARG COMPOSER_VERSION=2.11.2
ARG COMPOSER_FILE=composer.phar
ARG COMPOSER_URL=https://getcomposer.org/download/${COMPOSER_VERSION}/${COMPOSER_FILE}
ARG COMPOSER_SHA256="dd158c0afd41d15fac89e1b4e47b5d42911fe316c3687cd5edac98319b25d028"

WORKDIR /var/www

# https://getcomposer.org/download/
# Platform agnostic does not require arch specific identifier.
RUN --mount=type=cache,id=php84-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    download.sh \
        --url "${COMPOSER_URL}" \
        --sha256 "${COMPOSER_SHA256}" \
    && \
    cp "${DOWNLOAD_CACHE_DIRECTORY}/${COMPOSER_FILE}" /usr/bin/composer && \
    chmod a+x /usr/bin/composer && \
    cleanup.sh

ARG \
    # renovate: datasource=repology depName=alpine_3_24/icu-data-full
    ICU_VERSION=78.1-r0

# Platform specific does require arch specific identifier.
RUN --mount=type=bind,from=php_packages,source=/packages,target=/packages \
    --mount=type=cache,id=php84-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    /packages/php84 && \
    apk add icu-data-full=="${ICU_VERSION}" && \
    /packages/php84-bcmath && \
    /packages/php84-exif && \
    /packages/php84-ftp && \
    /packages/php84-gettext && \
    /packages/php84-ctype && \
    /packages/php84-curl && \
    /packages/php84-dom && \
    /packages/php84-fileinfo && \
    /packages/php84-gd && \
    /packages/php84-iconv && \
    /packages/php84-intl && \
    /packages/php84-ldap && \
    /packages/php84-mbstring && \
    /packages/php84-mysqli && \
    /packages/php84-openssl && \
    /packages/php84-pdo && \
    /packages/php84-pdo_mysql && \
    /packages/php84-phar && \
    /packages/php84-session && \
    /packages/php84-simplexml && \
    /packages/php84-sockets && \
    /packages/php84-tokenizer && \
    /packages/php84-xml && \
    /packages/php84-xmlreader && \
    /packages/php84-xmlwriter && \
    /packages/php84-xsl && \
    /packages/php84-zip && \
    ln -sf /usr/bin/php84 /usr/bin/php && \
    ln -sf /usr/bin/php84 /usr/local/bin/php && \
    command -v php >/dev/null && \
    php -r 'exit(PHP_VERSION === $argv[1] ? 0 : 1);' "${SOFTWARE_VERSION%%-r*}" && \
    if ! getent group nginx >/dev/null; then addgroup -S nginx; fi && \
    if ! id -u nginx >/dev/null 2>&1; then adduser -S -D -H -h /var/lib/nginx -s /sbin/nologin -G nginx -g nginx nginx; fi && \
    addgroup nginx jwt && \
    cleanup.sh

ENV \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1 \
    PHP_DEFAULT_SOCKET_TIMEOUT=60 \
    PHP_LOG_LEVEL=notice \
    PHP_LOG_LIMIT=16384 \
    PHP_MAX_EXECUTION_TIME=30 \
    PHP_MAX_FILE_UPLOADS=20 \
    PHP_MAX_INPUT_TIME=60 \
    PHP_MAX_INPUT_VARS=3000 \
    PHP_MEMORY_LIMIT=256M \
    PHP_PM=dynamic \
    PHP_PM_MAX_CHILDREN=5 \
    PHP_PM_START_SERVERS=2 \
    PHP_PM_MIN_SPARE_SERVERS=1 \
    PHP_PM_MAX_SPARE_SERVERS=3 \
    PHP_PM_IDLE_TIMEOUT=10s \
    PHP_PM_MAX_REQUESTS=0 \
    PHP_POST_MAX_SIZE=128M \
    PHP_PROCESS_CONTROL_TIMEOUT=60 \
    PHP_REQUEST_TERMINATE_TIMEOUT=60 \
    PHP_UPLOAD_MAX_FILESIZE=128M \
    SOLR_HOCR_PLUGIN_PATH=/opt/solr/server/solr/contrib/ocrhighlighting/lib

COPY --link rootfs /

RUN command -v php >/dev/null && \
    composer --version

HEALTHCHECK CMD s6-svstat -u /run/service/fpm
