FROM scyllaridae

ARG TARGETARCH

EXPOSE 8080

WORKDIR /app

ARG \
    # renovate: datasource=repology depName=alpine_3_24/ffmpeg
    SOFTWARE_VERSION=8.1.2-r0

# Platform specific does require arch specific identifier.
RUN --mount=type=cache,id=homarus-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add ffmpeg=="${SOFTWARE_VERSION}" && \
    cleanup.sh

COPY --link rootfs /
