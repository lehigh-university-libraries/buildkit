FROM ghcr.io/libops/python:3.13.18-r4-alpine3.24@sha256:719445ea3555664c4313849d444d2e4634f6486d441c7018a686d86cd47f7f15 AS python_packages
FROM base

WORKDIR /app

RUN --mount=type=bind,from=python_packages,source=/packages,target=/packages \
    /packages/python313 && \
    python3 -c 'import bz2, ctypes, dbm.gnu, lzma, readline, sqlite3, ssl, uuid; assert __import__("sys").version_info[:2] == (3, 13)' && \
    create-service-user.sh --name pyapp /app && \
    python3 -m pip install --no-cache-dir --break-system-packages uv && \
    uv --version && cleanup.sh

ENV PIP_BREAK_SYSTEM_PACKAGES=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FLASK_APP="application.app:app" \
    WORKERS=4 \
    SCRIPT_NAME= \
    PORT=8080

EXPOSE 8080
COPY --link rootfs /
HEALTHCHECK CMD curl -fsS "http://localhost:${PORT}${SCRIPT_NAME%/}/healthcheck"
