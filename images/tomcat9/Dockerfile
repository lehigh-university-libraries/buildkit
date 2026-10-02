FROM java17

ARG TARGETARCH
# renovate: datasource=custom.apache-downloads depName=apache-tomcat9 packageName=tomcat/tomcat-9
ARG SOFTWARE_VERSION=9.0.122
ARG TOMCAT_FILE_SHA256="d8ec7e512e1450d23bceb14e93ac647ad20524ae8457a6eef529c077f8829890"

EXPOSE 8080

WORKDIR /opt/tomcat

RUN --mount=type=cache,id=tomcat-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    TOMCAT_FILE="apache-tomcat-${SOFTWARE_VERSION}.tar.gz" && \
    TOMCAT_URL="https://downloads.apache.org/tomcat/tomcat-9/v${SOFTWARE_VERSION}/bin/${TOMCAT_FILE}" && \
    download.sh --url "${TOMCAT_URL}" --sha256 "${TOMCAT_FILE_SHA256}" "${DOWNLOAD_CACHE_DIRECTORY}" && \
    download.sh \
        --url "${TOMCAT_URL}" \
        --sha256 "${TOMCAT_FILE_SHA256}" \
        --dest "/opt/tomcat" \
        --strip \
        webapps/docs webapps/examples \
    && \
    cleanup.sh

RUN create-service-user.sh \
        --name tomcat \
        --group jwt \
        /data \
    && \
    cleanup.sh

ENV \
    TOMCAT_ADMIN_NAME=admin \
    TOMCAT_ADMIN_PASSWORD= \
    TOMCAT_ADMIN_ROLES=manager-gui \
    TOMCAT_CONNECTION_TIMEOUT=20000 \
    TOMCAT_CATALINA_OPTS= \
    TOMCAT_JAVA_OPTS= \
    TOMCAT_LOG_LEVEL=INFO \
    TOMCAT_MANAGER_REMOTE_ADDRESS_VALVE=^(127[.].*|::1)$

COPY --link rootfs /
