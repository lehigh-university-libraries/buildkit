ARG SOFTWARE_VERSION=25.0.5.1_p2-r3-alpine3.24
FROM ghcr.io/libops/java:${SOFTWARE_VERSION}@sha256:8a235e0fa2bf7d3e72378df704ac853888ef294942a4ae2c33ca2c432857c3f8 AS java_packages
FROM base

ARG TARGETARCH

ARG \
  # renovate: datasource=repology depName=alpine_3_24/maven
  MAVEN_VERSION=3.9.16-r0

# Install packages and tools required by all downstream images.
#
# Platform specific does require arch specific identifier.
RUN --mount=type=bind,from=java_packages,source=/packages,target=/packages \
    --mount=type=cache,id=java25-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    /packages/openjdk25 && \
    apk add \
        maven=="${MAVEN_VERSION}" \
    && \
    cleanup.sh

ENV JAVA_HOME=/usr/lib/jvm/default-jvm
