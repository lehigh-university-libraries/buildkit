FROM base

ARG TARGETARCH

ARG \
  # renovate: datasource=repology depName=alpine_3_24/openjdk17
  SOFTWARE_VERSION=17.0.20_p8-r0 \
  # renovate: datasource=repology depName=alpine_3_24/maven
  MAVEN_VERSION=3.9.16-r0

# Install packages and tools required by all downstream images.
#
# Platform specific does require arch specific identifier.
RUN --mount=type=cache,id=java17-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        openjdk17=="${SOFTWARE_VERSION}" \
        maven=="${MAVEN_VERSION}" \
    && \
    cleanup.sh

ENV JAVA_HOME=/usr/lib/jvm/default-jvm
