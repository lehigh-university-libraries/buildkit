FROM scyllaridae

WORKDIR /app

ARG \
  # renovate: datasource=repology depName=alpine_3_24/ffmpeg
  FFMPEG_VERSION=8.1.2-r0 \
  # renovate: datasource=repology depName=alpine_3_24/jq
  JQ_VERSION=1.8.2-r0

RUN apk update && \
    apk add --no-cache \
      ffmpeg=="${FFMPEG_VERSION}" \
      jq=="${JQ_VERSION}"


COPY --link rootfs /
