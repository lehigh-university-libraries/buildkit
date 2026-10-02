FROM base

ARG TARGETARCH
# renovate: datasource=github-releases depName=custom-composer packageName=composer/composer
ARG COMPOSER_VERSION=2.10.3
ARG COMPOSER_FILE=composer.phar
ARG COMPOSER_URL=https://getcomposer.org/download/${COMPOSER_VERSION}/${COMPOSER_FILE}
ARG COMPOSER_SHA256="7a2d379d5b8ffdaa028580ef26494c36d2feef4b178d3dd1473a4dbc5e17c8d6"

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
    # renovate: datasource=repology depName=alpine_3_24/php84
    SOFTWARE_VERSION=8.4.26-r0

# Platform specific does require arch specific identifier.
RUN --mount=type=cache,id=php84-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        icu-data-full=="${ICU_VERSION}" \
        php84=="${SOFTWARE_VERSION}" \
        php84-ctype=="${SOFTWARE_VERSION}" \
        php84-curl=="${SOFTWARE_VERSION}" \
        php84-dom=="${SOFTWARE_VERSION}" \
        php84-fileinfo=="${SOFTWARE_VERSION}" \
        php84-fpm=="${SOFTWARE_VERSION}" \
        php84-gd=="${SOFTWARE_VERSION}" \
        php84-iconv=="${SOFTWARE_VERSION}" \
        php84-intl=="${SOFTWARE_VERSION}" \
        php84-ldap=="${SOFTWARE_VERSION}" \
        php84-mbstring=="${SOFTWARE_VERSION}" \
        php84-mysqli=="${SOFTWARE_VERSION}" \
        php84-opcache=="${SOFTWARE_VERSION}" \
        php84-openssl=="${SOFTWARE_VERSION}" \
        php84-pdo=="${SOFTWARE_VERSION}" \
        php84-pdo_mysql=="${SOFTWARE_VERSION}" \
        php84-phar=="${SOFTWARE_VERSION}" \
        php84-session=="${SOFTWARE_VERSION}" \
        php84-simplexml=="${SOFTWARE_VERSION}" \
        php84-sockets=="${SOFTWARE_VERSION}" \
        php84-tokenizer=="${SOFTWARE_VERSION}" \
        php84-xml=="${SOFTWARE_VERSION}" \
        php84-xmlreader=="${SOFTWARE_VERSION}" \
        php84-xmlwriter=="${SOFTWARE_VERSION}" \
        php84-xsl=="${SOFTWARE_VERSION}" \
        php84-zip=="${SOFTWARE_VERSION}" \
    && \
    ln -sf /usr/bin/php84 /usr/bin/php && \
    ln -sf /usr/bin/php84 /usr/local/bin/php && \
    command -v php >/dev/null && \
    php -v >/dev/null && \
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
