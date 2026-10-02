# syntax=docker/dockerfile:1.20.0
ARG PHP_BASE=nginx-php83
FROM ${PHP_BASE}

LABEL org.opencontainers.image.licenses="GPL-3.0-only"

ARG TARGETARCH
ARG PHP_FPM_SOCKET=/run/php-fpm/php-fpm.sock
ARG PHP_PACKAGE=php83

ARG \
    # renovate: datasource=repology depName=alpine_3_24/antiword
    ANTIWORD_VERSION=0.37-r6 \
    # renovate: datasource=repology depName=alpine_3_24/ghostscript
    GHOSTSCRIPT_VERSION=10.07.1-r0 \
    # renovate: datasource=repology depName=alpine_3_24/npm
    NPM_VERSION=11.12.1-r0 \
    # renovate: datasource=repology depName=alpine_3_24/poppler-utils
    POPPLER_VERSION=25.12.0-r1 \
    # renovate: datasource=custom.ojs depName=ojs
    SOFTWARE_VERSION=3.5.0-5

ARG FILE=ojs-${SOFTWARE_VERSION}.tar.gz
ARG URL=https://pkp.sfu.ca/ojs/download/${FILE}
ARG SHA256="fd59cb1add60ab4e56e40ed843ea43ff84af11f0b64c3940f2e03186ad11445e"

EXPOSE 80
WORKDIR /var/www/ojs

COPY --link patches /opt/ojs-patches

RUN --mount=type=cache,id=ojs-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        antiword=="${ANTIWORD_VERSION}" \
        ghostscript=="${GHOSTSCRIPT_VERSION}" \
        npm=="${NPM_VERSION}" \
        poppler-utils=="${POPPLER_VERSION}" \
        "${PHP_PACKAGE}-bcmath" \
        "${PHP_PACKAGE}-ftp" \
        "${PHP_PACKAGE}-gettext" \
    && \
    cleanup.sh

# Fresh OJS installations normally fetch mutable ROR and IP geolocation datasets
# while creating the database. Defer those network-backed tasks to OJS's scheduler
# so first boot remains bounded and can run without outbound network access. Verify
# the pinned release still contains exactly the two expected actions before changing
# its install descriptor; upgrades use a separate descriptor and are unaffected.
RUN --mount=type=cache,id=ojs-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    download.sh \
        --url "${URL}" \
        --sha256 "${SHA256}" \
        --strip \
        --dest /var/www/ojs \
    && \
    test "$(grep -Fc '<code function="downloadIPGeoDB"/>' dbscripts/xml/install.xml)" -eq 1 && \
    test "$(grep -Fc '<code function="updateRorRegistryDataset"/>' dbscripts/xml/install.xml)" -eq 1 && \
    patch --forward --strip=1 --input=/opt/ojs-patches/install-cli-database-port.patch && \
    sed -i \
        -e '/<code function="downloadIPGeoDB"\/>/d' \
        -e '/<code function="updateRorRegistryDataset"\/>/d' \
        dbscripts/xml/install.xml \
    && \
    mkdir -p /usr/share/licenses/ojs && \
    cp docs/COPYING /usr/share/licenses/ojs/COPYING && \
    rm -rf .github tests docs /opt/ojs-patches && \
    mkdir -p /var/www/files /var/www/ojs/cache /var/www/ojs/public && \
    touch /var/www/ojs/opcache_stat.php && \
    chown -R nginx:nginx /var/www/ojs /var/www/files && \
    cleanup.sh

ENV \
    DB_HOST=mariadb \
    DB_PORT=3306 \
    DB_NAME=ojs \
    DB_USER=ojs \
    DB_PASSWORD= \
    OJS_SALT= \
    OJS_API_KEY_SECRET= \
    OJS_SECRET_KEY= \
    OJS_ADMIN_USERNAME=admin \
    OJS_ADMIN_EMAIL=admin@localhost \
    OJS_ADMIN_PASSWORD= \
    OJS_INSTALLED=Off \
    OJS_LOCALE=en \
    OJS_TIMEZONE=UTC \
    OJS_FILES_DIR=/var/www/files \
    OJS_OAI_REPOSITORY_ID=ojs.localhost \
    OJS_ENABLE_BEACON=1 \
    OJS_SESSION_LIFETIME=30 \
    OJS_X_FORWARDED_FOR=Off \
    OJS_SMTP_SERVER=host.docker.internal \
    OJS_SMTP_PORT=25 \
    OJS_DEFAULT_ENVELOPE_SENDER= \
    INGRESS_HOSTNAMES=localhost \
    INGRESS_SCHEME=http \
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

HEALTHCHECK CMD test -f /installed && test -f /var/www/ojs/index.php && curl -fsS http://localhost/status | grep -q pool
