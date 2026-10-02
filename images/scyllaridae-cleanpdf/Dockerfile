FROM scyllaridae

WORKDIR /app

ARG \
  # renovate: datasource=repology depName=alpine_3_24/qpdf
  QPDF_VERSION=12.3.2-r0

RUN apk update && \
    apk add --no-cache \
        qpdf=="${QPDF_VERSION}"


COPY --link rootfs /
