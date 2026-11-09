# syntax=docker/dockerfile:1.28.0@sha256:bb22d9815c728170f72750f4e5b0d672e06176142e1d602c7e66c050100b7e5b
# PHP 8.4 is a staging candidate until checked against the deployed installation.
FROM nginx-php84
WORKDIR /opt/scalar
COPY --link rootfs /
HEALTHCHECK CMD curl -fsS http://localhost/status | grep -q pool
