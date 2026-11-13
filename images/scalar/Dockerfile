# syntax=docker/dockerfile:1.28.0@sha256:bb22d9815c728170f72750f4e5b0d672e06176142e1d602c7e66c050100b7e5b
# PHP compatibility with the existing deployment must be verified before cutover.
FROM nginx-php84
ARG TARGETARCH
# renovate: datasource=github-releases depName=scalar packageName=anvc/scalar
ARG SOFTWARE_VERSION=2.6.10
ARG URL=https://github.com/anvc/scalar/archive/refs/tags/v${SOFTWARE_VERSION}.tar.gz
ARG SHA256="cd6b5bf4b95d05cfd112879c3e72c71f7483d91d2f0e7db214b4e74d0d5e359b"
WORKDIR /usr/local/share/scalar
# Backport anvc/scalar#272 and its upstream LDAPS prerequisites to 2.6.10.
COPY patches/272-ldap.patch /tmp/scalar-ldap.patch
COPY patches/asset-paths.patch /tmp/scalar-asset-paths.patch
COPY patches/mcrypt-properties.patch /tmp/scalar-mcrypt-properties.patch
COPY patches/rdf-hostname.patch /tmp/scalar-rdf-hostname.patch
RUN --mount=type=cache,id=scalar-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    download.sh --url "${URL}" --sha256 "${SHA256}" --strip --dest /usr/local/share/scalar && \
    dos2unix system/application/models/user_model.php system/application/config/local_settings.php system/application/helpers/MY_html_helper.php system/application/libraries/RDF_Store.php && \
    patch --batch --forward -p1 < /tmp/scalar-ldap.patch && \
    patch --batch --forward -p1 < /tmp/scalar-asset-paths.patch && \
    patch --batch --forward -p1 < /tmp/scalar-mcrypt-properties.patch && \
    patch --batch --forward -p1 < /tmp/scalar-rdf-hostname.patch && \
    rm /tmp/scalar-ldap.patch /tmp/scalar-asset-paths.patch /tmp/scalar-mcrypt-properties.patch /tmp/scalar-rdf-hostname.patch && \
    grep -F "define('FCPATH', str_replace(SELF, '', __FILE__));" codeigniter.php && \
    sed -i "s@str_replace(SELF, '', __FILE__)@'/opt/scalar/'@" codeigniter.php && \
    mkdir -p /opt/scalar /usr/share/licenses/scalar && \
    chown -R root:root /usr/local/share/scalar && \
    chmod -R go-w /usr/local/share/scalar && \
    cp license.txt /usr/share/licenses/scalar/license.txt && \
    printf '%s\n' "${SOFTWARE_VERSION}" > /usr/share/scalar-version && \
    cleanup.sh
COPY --link rootfs /
HEALTHCHECK CMD curl -fsS http://localhost/status | grep -q pool
