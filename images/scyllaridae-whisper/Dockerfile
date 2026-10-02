FROM scyllaridae AS service

# Pinned to the last main-cuda build before ggml-org/whisper.cpp#3371 (2025-08-13)
# bumped CUDA to 13.0 and dropped compute_50 support. This build's default
# CMAKE_CUDA_ARCHITECTURES includes "50-virtual" (PTX-only), which the NVIDIA
# driver JITs for any GPU with compute capability >= 5.0 - covering Tesla M60
# (5.2). Every main-cuda tag built after that commit fails on M60 with
# "no kernel image is available for execution on the device". DO NOT let
# renovate bump this digest - newer main-cuda builds break Maxwell/M60.
# renovate: enabled=false
FROM ghcr.io/ggml-org/whisper.cpp@sha256:b6c7f057ddb2260c93737e077bf6c9de60b510cab77c0cfd3f18fcfb5da4dcf2

ARG \
  # renovate: datasource=repology depName=ubuntu_22_04/gosu
  GOSU_VERSION="1.14-1ubuntu0.1"

RUN bash ./models/download-ggml-model.sh medium.en

WORKDIR /app

COPY --from=service /app/scyllaridae /app/scyllaridae

COPY --link rootfs /

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    gosu="${GOSU_VERSION}" \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd -r nobody \
  && useradd -r -g nobody scyllaridae \
  && chmod +x /app/docker-entrypoint.sh /app/cmd.sh \
  && chown scyllaridae /app/models


ENV \
  SCYLLARIDAE_ALLOW_INSECURE_ARGS="false" \
  SCYLLARIDAE_LOG_LEVEL=INFO \
  SCYLLARIDAE_PORT=8080 \
  SCYLLARIDAE_YML_PATH="/app/scyllaridae.yml" \
  WHISPER_PROCESSORS=1 \
  WHISPER_THREADS=4

ENTRYPOINT ["/app/docker-entrypoint.sh"]
