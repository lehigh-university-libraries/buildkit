# syntax=docker/dockerfile:1.20.0@sha256:26147acbda4f14c5add9946e2fd2ed543fc402884fd75146bd342a7f6271dc1d
ARG DRUPAL_BASE=drupal@sha256:7a6958c7f2c886da5e3825220fea02fec28c19bd71bea918b925f2fdb4763310
FROM ${DRUPAL_BASE}

ARG \
    # renovate: datasource=repology depName=alpine_3_24/ffmpeg
    FFMPEG_VERSION=8.1.2-r0 \
    # renovate: datasource=repology depName=alpine_3_24/imagemagick
    IMAGEMAGICK_VERSION=7.1.2.30-r0 \
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
  CROSSWALK_VERSION=0.3.9 \
  CROSSWALK_BASE_URL="https://github.com/lehigh-university-libraries/crosswalk/releases/download/v${CROSSWALK_VERSION}" \
  CROSSWALK_AMD64=crosswalk_Linux_x86_64.tar.gz   \
  CROSSWALK_AMD64_SHA256="77b29f8f34c030d6b52194b7d9dcb41b087810a984be43f8c9615316658ef2fe" \
  CROSSWALK_ARM64=crosswalk_Linux_arm64.tar.gz \
  CROSSWALK_ARM64_SHA256="b4ed72b250ce1f774d54f39171b783b8745b4eb2b313ea221da75f5aa7967ab5"

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
