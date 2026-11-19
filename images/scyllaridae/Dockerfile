FROM go1-26 AS builder

WORKDIR /build

# renovate: datasource=github-releases depName=scyllaridae packageName=islandora/scyllaridae
ARG SOFTWARE_VERSION=5.3.10
ARG SCYLLARIDAE_URL="https://github.com/islandora/scyllaridae/archive/refs/tags/${SOFTWARE_VERSION}.tar.gz"
ARG SCYLLARIDAE_SHA256="0590214eb21f36e43ba8ae52470192c5beba14035c3322de27a9de77887e8550"
RUN download.sh \
      --url "${SCYLLARIDAE_URL}" \
      --sha256 "${SCYLLARIDAE_SHA256}" \
      --dest .

WORKDIR /build/scyllaridae-${SOFTWARE_VERSION}

RUN CGO_ENABLED=0 go build -o ../scyllaridae -ldflags="-s -w" .

FROM base

ARG TARGETARCH

COPY --from=builder /build/scyllaridae /app/scyllaridae

ARG \
  # renovate: datasource=repology depName=alpine_3_24/mailcap
  MAILCAP_VERSION=2.1.54-r0

RUN --mount=type=cache,id=scyllaridae-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add mailcap=="${MAILCAP_VERSION}" && \
    create-service-user.sh --name scyllaridae /app && \
    cleanup.sh

ENV \
  SCYLLARIDAE_ALLOW_INSECURE_ARGS="false" \
  SCYLLARIDAE_LOG_LEVEL=INFO \
  SCYLLARIDAE_PORT=8080 \
  SCYLLARIDAE_YML_PATH="/app/scyllaridae.yml"

COPY --link rootfs /
