# syntax=docker/dockerfile:1.29.0@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183
# PHP compatibility with the existing deployment must be verified before cutover.
FROM nginx-php84
ARG TARGETARCH
# Upstream master snapshot; SOFTWARE_VERSION must match scalar-version.php.
ARG SOFTWARE_VERSION=2.6.12
# renovate: datasource=git-refs depName=scalar packageName=https://github.com/anvc/scalar.git branch=master
ARG COMMIT=daf68e2cca8e89d5c39d52ac606dd129e880bf0d
ARG URL=https://github.com/anvc/scalar/archive/${COMMIT}.tar.gz
ARG SHA256="057ba09b2c7e84865c53b70852d830a7b067434b0f4453ed83f7bd23d6a23ef7"
WORKDIR /usr/local/share/scalar
COPY patches /tmp/scalar-patches
RUN --mount=type=cache,id=scalar-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    download.sh --url "${URL}" --sha256 "${SHA256}" --strip --dest /usr/local/share/scalar && \
    test "$(tail -n 1 system/application/views/scalar-version.php)" = "${SOFTWARE_VERSION}" && \
    dos2unix system/application/models/user_model.php system/application/config/local_settings.php \
      system/application/helpers/MY_html_helper.php system/application/libraries/RDF_Store.php \
      system/application/views/arbors/html5_RDFa/wrapper.php system/core/Common.php system/core/Exceptions.php \
      system/application/controllers/system.php system/application/models/book_model.php \
      system/application/views/modules/dashboard/tabs.js && \
    for patch_file in /tmp/scalar-patches/*.patch; do patch --batch --forward --fuzz=0 -p1 < "$patch_file" || exit 1; done && \
    rm -rf /tmp/scalar-patches && \
    grep -F "define('FCPATH', str_replace(SELF, '', __FILE__));" codeigniter.php && \
    sed -i "s@str_replace(SELF, '', __FILE__)@'/opt/scalar/'@" codeigniter.php && \
    mkdir -p /opt/scalar /usr/share/licenses/scalar && \
    chown -R root:root /usr/local/share/scalar && \
    chmod -R go-w /usr/local/share/scalar && \
    cp license.txt /usr/share/licenses/scalar/license.txt && \
    printf '%s\n' "${SOFTWARE_VERSION}" > /usr/share/scalar-version && \
    printf '%s\n' "${COMMIT}" > /usr/share/scalar-revision && \
    cleanup.sh
COPY --link rootfs /
HEALTHCHECK CMD curl -fsS http://localhost/status | grep -q pool
