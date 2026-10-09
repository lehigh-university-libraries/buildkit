FROM python:3.14-alpine3.24@sha256:f6a589d43c42b9e7f7dc67a12d37132491f362859a5d750607710cc56da3bc72 AS python
FROM base

WORKDIR /app

COPY --from=python /usr/local/ /usr/local/
RUN apk add --no-cache libbz2 libffi gdbm xz-libs ncurses-libs readline sqlite-libs libuuid && \
    python3 -c 'import bz2, ctypes, dbm.gnu, lzma, readline, sqlite3, ssl, uuid; assert __import__("sys").version_info[:2] == (3, 14)' && \
    create-service-user.sh --name pyapp /app && \
    pip install --no-cache-dir uv && \
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
