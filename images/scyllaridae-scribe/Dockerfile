FROM scyllaridae

WORKDIR /app

ARG \
    # renovate: datasource=repology depName=alpine_3_24/vips
    SOFTWARE_VERSION=8.18.2-r0

RUN apk add --no-cache \
      vips=="${SOFTWARE_VERSION}" \
      vips-tools=="${SOFTWARE_VERSION}" && \
    cleanup.sh

COPY --link rootfs /
