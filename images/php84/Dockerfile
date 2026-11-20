# syntax=docker/dockerfile:1.20.0@sha256:26147acbda4f14c5add9946e2fd2ed543fc402884fd75146bd342a7f6271dc1d
# Keep PHP independent of runtime ARGs and rootfs so their changes reuse this stage.
FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS php-build

RUN apk add --no-cache alpine-sdk sudo && \
    adduser -D -G abuild builder && \
    echo 'builder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/builder
COPY --chown=builder:abuild build /home/builder/aports/php84
USER builder
WORKDIR /home/builder/aports/php84
RUN abuild-keygen -ain && abuild-apk update && abuild -r && \
    mkdir /home/builder/apks && \
    find /home/builder/packages -name '*.apk' -exec cp {} /home/builder/apks/ \; && \
    rm /home/builder/.abuild/*.rsa

FROM base

ARG TARGETARCH
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
    ICU_VERSION=78.1-r0 \
    # PHP is built from the vendored aport; ci/update-php.sh updates this pin.
    SOFTWARE_VERSION=8.4.28-r0

# Platform specific does require arch specific identifier.
RUN --mount=type=bind,from=php-build,source=/home/builder/apks,target=/packages \
    --mount=type=bind,from=php-build,source=/etc/apk/keys,target=/etc/apk/keys \
    --mount=type=cache,id=php84-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        icu-data-full=="${ICU_VERSION}" \
        /packages/php84-common-${SOFTWARE_VERSION}.apk \
        /packages/php84-mysqlnd-${SOFTWARE_VERSION}.apk \
        /packages/php84-${SOFTWARE_VERSION}.apk \
        /packages/php84-bcmath-${SOFTWARE_VERSION}.apk \
        /packages/php84-exif-${SOFTWARE_VERSION}.apk \
        /packages/php84-ftp-${SOFTWARE_VERSION}.apk \
        /packages/php84-gettext-${SOFTWARE_VERSION}.apk \
        /packages/php84-ctype-${SOFTWARE_VERSION}.apk \
        /packages/php84-curl-${SOFTWARE_VERSION}.apk \
        /packages/php84-dom-${SOFTWARE_VERSION}.apk \
        /packages/php84-fileinfo-${SOFTWARE_VERSION}.apk \
        /packages/php84-fpm-${SOFTWARE_VERSION}.apk \
        /packages/php84-gd-${SOFTWARE_VERSION}.apk \
        /packages/php84-iconv-${SOFTWARE_VERSION}.apk \
        /packages/php84-intl-${SOFTWARE_VERSION}.apk \
        /packages/php84-ldap-${SOFTWARE_VERSION}.apk \
        /packages/php84-mbstring-${SOFTWARE_VERSION}.apk \
        /packages/php84-mysqli-${SOFTWARE_VERSION}.apk \
        /packages/php84-opcache-${SOFTWARE_VERSION}.apk \
        /packages/php84-openssl-${SOFTWARE_VERSION}.apk \
        /packages/php84-pdo-${SOFTWARE_VERSION}.apk \
        /packages/php84-pdo_mysql-${SOFTWARE_VERSION}.apk \
        /packages/php84-phar-${SOFTWARE_VERSION}.apk \
        /packages/php84-session-${SOFTWARE_VERSION}.apk \
        /packages/php84-simplexml-${SOFTWARE_VERSION}.apk \
        /packages/php84-sockets-${SOFTWARE_VERSION}.apk \
        /packages/php84-tokenizer-${SOFTWARE_VERSION}.apk \
        /packages/php84-xml-${SOFTWARE_VERSION}.apk \
        /packages/php84-xmlreader-${SOFTWARE_VERSION}.apk \
        /packages/php84-xmlwriter-${SOFTWARE_VERSION}.apk \
        /packages/php84-xsl-${SOFTWARE_VERSION}.apk \
        /packages/php84-zip-${SOFTWARE_VERSION}.apk \
    && \
    ln -sf /usr/bin/php84 /usr/bin/php && \
    ln -sf /usr/bin/php84 /usr/local/bin/php && \
    command -v php >/dev/null && \
    php -r 'exit(PHP_VERSION === $argv[1] ? 0 : 1);' "${SOFTWARE_VERSION%-r*}" && \
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
