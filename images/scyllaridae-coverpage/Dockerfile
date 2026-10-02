FROM scyllaridae AS service
FROM pandoc/latex:3.9-ubuntu@sha256:601777bf5e7b9642ce7acdd46eef1daa69b4efdc47a539254d8fc0942d6a7cfd AS pandoc

ARG \
  # renovate: datasource=repology depName=ubuntu_24_04/curl
  CURL_VERSION="8.5.0-2ubuntu10.15" \
  # renovate: datasource=repology depName=ubuntu_24_04/bash
  BASH_VERSION="5.2.21-2ubuntu4" \
  # renovate: datasource=repology depName=ubuntu_24_04/ghostscript
  GHOSTSCRIPT_VERSION="10.02.1~dfsg1-0ubuntu7.9" \
  # renovate: datasource=repology depName=ubuntu_24_04/gosu
  GOSU_VERSION="1.17-1ubuntu0.24.04.3" \
  # renovate: datasource=repology depName=ubuntu_24_04/jq
  JQ_VERSION="1.7.1-3ubuntu0.24.04.2"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl="${CURL_VERSION}" \
        bash="${BASH_VERSION}" \
        ghostscript="${GHOSTSCRIPT_VERSION}" \
        gosu="${GOSU_VERSION}" \
        jq="${JQ_VERSION}" \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=service /app/scyllaridae /app/scyllaridae

ENV \
  SCYLLARIDAE_ALLOW_INSECURE_ARGS="false" \
  SCYLLARIDAE_LOG_LEVEL=INFO \
  SCYLLARIDAE_PORT=8080 \
  SCYLLARIDAE_YML_PATH="/app/scyllaridae.yml"

COPY --link rootfs /

RUN groupadd -r nobody && \
    useradd -r -g nobody scyllaridae

ENTRYPOINT ["/bin/bash"]
CMD ["/app/docker-entrypoint.sh"]
