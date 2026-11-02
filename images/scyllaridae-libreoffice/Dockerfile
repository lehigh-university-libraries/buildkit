FROM scyllaridae

WORKDIR /app

ARG \
  # renovate: datasource=repology depName=alpine_3_24/openjdk17-jre
  OPENJDK_VERSION=17.0.21.0.3_p1-r0 \
  # renovate: datasource=repology depName=alpine_3_24/libreoffice
  LIBREOFFICE_VERSION=25.8.7.3-r0 \
  # renovate: datasource=repology depName=alpine_3_24/font-dejavu
  TTF_DEJAVU_VERSION=2.37-r6

RUN apk update && \
  apk add --no-cache \
    openjdk17-jre=="${OPENJDK_VERSION}" \
    libreoffice=="${LIBREOFFICE_VERSION}" \
    font-dejavu=="${TTF_DEJAVU_VERSION}"


COPY --link rootfs /
