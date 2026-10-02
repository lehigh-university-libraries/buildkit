FROM scyllaridae

ARG TARGETARCH

EXPOSE 8080

WORKDIR /app

ARG \
    # renovate: datasource=repology depName=alpine_3_24/openjpeg-tools
    OPENJPEG_TOOLS_VERSION=2.5.4-r1 \
    # renovate: datasource=repology depName=alpine_3_24/vips
    SOFTWARE_VERSION=8.18.2-r0

RUN apk add --no-cache \
      openjpeg-tools=="${OPENJPEG_TOOLS_VERSION}" \
      vips=="${SOFTWARE_VERSION}" \
      vips-poppler=="${SOFTWARE_VERSION}" \
      vips-tools=="${SOFTWARE_VERSION}" && \
    cleanup.sh

COPY --link rootfs /
