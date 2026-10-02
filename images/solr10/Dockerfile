FROM java25

ARG TARGETARCH
# renovate: datasource=custom.apache-downloads depName=apache-solr10 packageName=solr/solr
ARG SOFTWARE_VERSION=10.0.0
ARG SOLR_FILE=solr-${SOFTWARE_VERSION}.tgz
ARG SOLR_URL=https://downloads.apache.org/solr/solr/${SOFTWARE_VERSION}/solr-${SOFTWARE_VERSION}.tgz
ARG SOLR_FILE_SHA256="07c180970f60d13776be13ccb60c707d041e5e1a8b914d197d1358ac25f804b5"
# renovate: datasource=github-releases depName=solr-ocrhighlighting packageName=dbmdz/solr-ocrhighlighting
ARG OCRHIGHLIGHT_VERSION=0.10.1
ARG OCRHIGHLIGHT_FILE=solr-ocrhighlighting-${OCRHIGHLIGHT_VERSION}.jar
ARG OCRHIGHLIGHT_URL=https://github.com/dbmdz/solr-ocrhighlighting/releases/download/${OCRHIGHLIGHT_VERSION}/solr-ocrhighlighting-${OCRHIGHLIGHT_VERSION}.jar
ARG OCRHIGHLIGHT_FILE_SHA256="d10b86684004ebeec3d938a64608135e80c1cef58a176dacb9a556f0b5a78823"
ARG OCRHIGHLIGHT_DEST=/opt/solr/lib

EXPOSE 8983

WORKDIR /opt/solr

# Platform agnostic does not require arch specific identifier.
RUN --mount=type=cache,id=solr10-downloads-${TARGETARCH},sharing=locked,target=/opt/downloads \
    download.sh \
        --url "${SOLR_URL}" \
        --sha256 "${SOLR_FILE_SHA256}" \
        --strip \
        --dest "/opt/solr" \
        docs \
        example \
        server/solr/configsets \
    && \
    cleanup.sh

RUN --mount=type=cache,id=solr10-ocrhighlight-downloads,sharing=locked,target=/opt/downloads \
    download.sh \
        --url "${OCRHIGHLIGHT_URL}" \
        --sha256 "${OCRHIGHLIGHT_FILE_SHA256}" \
        --dest ${OCRHIGHLIGHT_DEST} \
    && \
    mkdir -p /opt/solr/server/solr/contrib/ocrhighlighting/lib && \
    # v9 support to avoid breaking <lib> directives in solr XML
    ln -s "${OCRHIGHLIGHT_DEST}/solr-ocrhighlighting-${OCRHIGHLIGHT_VERSION}.jar" /opt/solr/server/solr/contrib/ocrhighlighting/lib/ocrhighlighting.jar && \
    cleanup.sh

RUN create-service-user.sh --name solr /data && \
    cleanup.sh

# Defaults environment variables to be overloaded.
ENV \
    SOLR_JAVA_OPTS= \
    SOLR_JETTY_OPTS="-Dsolr.jetty.host=0.0.0.0" \
    SOLR_LOG_LEVEL=INFO \
    SOLR_MEMORY=512m \
    SOLR_MODULES=analysis-extras,extraction,langid,ltr

COPY --link rootfs /

HEALTHCHECK CMD curl -fsS http://localhost:8983/solr/admin/info/system?wt=json | jq -r .responseHeader.status | grep -q 0
