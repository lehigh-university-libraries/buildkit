FROM base

# Backup runtime only; the MariaDB client version is pinned by base.
ARG \
    # renovate: datasource=repology depName=alpine_3_24/mariadb-connector-c
    MARIADB_CONNECTOR_C_VERSION=3.4.6-r0
RUN apk add --no-cache mariadb-connector-c=="${MARIADB_CONNECTOR_C_VERSION}" && cleanup.sh

ENV BACKUP_CRON="0 2 * * *" BACKUP_DIR=/db
COPY --link rootfs /
