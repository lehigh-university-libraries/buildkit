FROM base

ARG TARGETARCH

EXPOSE 3306

ARG \
  # renovate: datasource=repology depName=alpine_3_24/mariadb
  SOFTWARE_VERSION=11.8.8-r0

# Platform specific does require arch specific identifier.
RUN --mount=type=cache,id=mariadb11-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        mariadb=="${SOFTWARE_VERSION}" \
        mariadb-server-utils=="${SOFTWARE_VERSION}" \
    && \
    mkdir -p \
        /var/lib/mysql \
        /var/lib/mysql-files \
    && \
    chown -R mysql:mysql \
        /var/lib/mysql \
        /var/lib/mysql-files \
    && \
    cleanup.sh

# Installation sometimes needs more than the default 30 seconds defined in the
# base image. Set to 10 minutes just incase it ran on very old or overallocated
# hardware.
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=600000

ENV \
    # Default Mariadb value of 16 MB (bytes)
    MYSQL_MAX_ALLOWED_PACKET=16777216 \
    MYSQL_TRANSACTION_ISOLATION=READ-COMMITTED

COPY --link rootfs /

HEALTHCHECK CMD mariadb-admin ping --socket=/var/run/mysqld/mysqld.sock | grep -q alive
