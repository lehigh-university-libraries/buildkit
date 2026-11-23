ARG SOFTWARE_VERSION=21.0.13.1_p2-r3-alpine3.24
FROM ghcr.io/libops/java:${SOFTWARE_VERSION}@sha256:3981449712a51f5bcffe83d5a1dc376f5a80e33b0024cee26662732928869629 AS java_packages
FROM base

ARG TARGETARCH

ARG \
  # renovate: datasource=repology depName=alpine_3_24/maven
  MAVEN_VERSION=3.9.16-r0

# Install packages and tools required by all downstream images.
#
# Platform specific does require arch specific identifier.
RUN --mount=type=bind,from=java_packages,source=/packages,target=/packages \
    --mount=type=cache,id=java21-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    /packages/openjdk21 && \
    apk add \
        maven=="${MAVEN_VERSION}" \
    && \
    cleanup.sh

ENV JAVA_HOME=/usr/lib/jvm/default-jvm
