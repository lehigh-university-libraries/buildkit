FROM ghcr.io/libops/python:3.14.10-r4-alpine3.24@sha256:8fc608fa528275487fc14a2e6eaa5b9e26dcf2078631f2a151b57e87846fcb08 AS python_packages
FROM base

WORKDIR /app

RUN --mount=type=bind,from=python_packages,source=/packages,target=/packages \
    /packages/python314 && \
    python3 -c 'import bz2, ctypes, dbm.gnu, lzma, readline, sqlite3, ssl, uuid; assert __import__("sys").version_info[:2] == (3, 14)' && \
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
