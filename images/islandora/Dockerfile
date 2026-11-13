# syntax=docker/dockerfile:1.29.0@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183
ARG DRUPAL_BASE=drupal@sha256:0e3f1001a265ccc3629a81b5889a2ecf61a0908152fbc0c772722965b7a81dae
FROM ${DRUPAL_BASE}

ARG \
    # renovate: datasource=repology depName=alpine_3_24/ffmpeg
    FFMPEG_VERSION=8.1.3-r0 \
    # renovate: datasource=repology depName=alpine_3_24/imagemagick
    IMAGEMAGICK_VERSION=7.1.2.35-r0 \
    # renovate: datasource=repology depName=alpine_3_24/vips
    VIPS_VERSION=8.18.2-r0

RUN PHP_PACKAGE="php$(php -r 'echo PHP_MAJOR_VERSION . PHP_MINOR_VERSION;')" && \
    apk update && \
    apk add --no-cache \
      "${PHP_PACKAGE}-pdo_sqlite" \
      "${PHP_PACKAGE}-pecl-uploadprogress" \
      "${PHP_PACKAGE}-pecl-memcache" \
      "${PHP_PACKAGE}-pecl-xhprof" \
      ffmpeg=="${FFMPEG_VERSION}" \
      imagemagick=="${IMAGEMAGICK_VERSION}" \
      vips=="${VIPS_VERSION}" && \
    cleanup.sh

ARG \
  TARGETARCH \
  # renovate: datasource=github-releases depName=crosswalk packageName=lehigh-university-libraries/crosswalk
  CROSSWALK_VERSION=0.6.0 \
  CROSSWALK_BASE_URL="https://github.com/lehigh-university-libraries/crosswalk/releases/download/v${CROSSWALK_VERSION}" \
  CROSSWALK_AMD64=crosswalk_Linux_x86_64.tar.gz   \
  CROSSWALK_AMD64_SHA256="3c6e3707189d65b06e07a6f70602c1711b7a9016a90c04fc49e2963e7f5e4c1e" \
  CROSSWALK_ARM64=crosswalk_Linux_arm64.tar.gz \
  CROSSWALK_ARM64_SHA256="d2b6bee8eb72513b85c7816b1f169de1e6ad64e665f06a1f444435c25a337096"

RUN --mount=type=cache,id=crosswalk-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    if [ "${TARGETARCH}" = "amd64" ]; \
    then \
        download.sh \
            --url "${CROSSWALK_BASE_URL}/${CROSSWALK_AMD64}" \
            --sha256 "${CROSSWALK_AMD64_SHA256}" \
            --dest /usr/local/bin ; \
    else \
        download.sh \
            --url "${CROSSWALK_BASE_URL}/${CROSSWALK_ARM64}" \
            --sha256 "${CROSSWALK_ARM64_SHA256}" \
            --dest /usr/local/bin ; \
    fi

WORKDIR /var/www/drupal

ENV \
    DB_NAME=drupal_default \
    DB_USER=drupal_default \
    DRUPAL_DEFAULT_INSTALL=true \
    DRUPAL_DEFAULT_NAME=Islandora \
    DRUPAL_DEFAULT_PROFILE=standard \
    INGRESS_HOSTNAMES=localhost,drupal.internal \
    INGRESS_SCHEME=https

COPY --link rootfs /

RUN mkdir -p /var/www/drupal && \
    chown -R nginx:nginx /var/www/drupal

HEALTHCHECK CMD { [ ! -f /var/www/drupal/web/core/lib/Drupal.php ] || [ -f /installed ]; } && curl -fsS http://localhost/status | grep -q pool
