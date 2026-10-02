# syntax=docker/dockerfile:1.20.0
ARG PHP_BASE=php83
FROM ${PHP_BASE}

ARG TARGETARCH
ARG PHP_FPM_SOCKET=/run/php-fpm/php-fpm.sock

ARG \
    # renovate: datasource=repology depName=alpine_3_24/nginx
    NGINX_VERSION=1.30.4-r1

EXPOSE 80

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN --mount=type=cache,id=nginx-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add nginx=="${NGINX_VERSION}" && \
    mkdir -p /etc/nginx/shared && \
    if ! id -nG nginx | tr ' ' '\n' | grep -qx jwt; then addgroup nginx jwt; fi && \
    cleanup.sh

ENV \
    NGINX_CLIENT_BODY_TIMEOUT=60s \
    NGINX_CLIENT_MAX_BODY_SIZE=0 \
    NGINX_ERROR_LOG_LEVEL=warn \
    NGINX_FASTCGI_CONNECT_TIMEOUT=300s \
    NGINX_FASTCGI_READ_TIMEOUT=300s \
    NGINX_FASTCGI_SEND_TIMEOUT=300s \
    NGINX_KEEPALIVE_TIMEOUT=75s \
    NGINX_LINGERING_TIMEOUT=5s \
    NGINX_PROXY_CONNECT_TIMEOUT=60s \
    NGINX_PROXY_READ_TIMEOUT=60s \
    NGINX_PROXY_SEND_TIMEOUT=60s \
    NGINX_REAL_IP_HEADER=X-Forwarded-For \
    NGINX_REAL_IP_RECURSIVE=off \
    NGINX_SEND_TIMEOUT=60s \
    NGINX_SET_REAL_IP_FROM=172.0.0.0/8 \
    NGINX_SET_REAL_IP_FROM2=172.0.0.0/8 \
    NGINX_SET_REAL_IP_FROM3=172.0.0.0/8 \
    NGINX_WORKER_CONNECTIONS=1024 \
    NGINX_WORKER_PROCESSES=auto \
    PHP_FPM_SOCKET=${PHP_FPM_SOCKET}

COPY --link rootfs /

HEALTHCHECK CMD curl -fsS http://localhost/status | grep -q pool
