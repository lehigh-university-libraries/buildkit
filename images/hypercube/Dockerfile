FROM leptonica
FROM scyllaridae AS hypercube

ARG TARGETARCH

EXPOSE 8080

WORKDIR /app

ARG \
    # renovate: datasource=repology depName=alpine_3_24/poppler-utils
    POPPLER_VERSION=25.12.0-r1 \
    # renovate: datasource=repology depName=alpine_3_24/tesseract-ocr
    SOFTWARE_VERSION=5.5.2-r0

# Platform specific does require arch specific identifier.
# Though platform information is included via the FROM leptonica.
RUN --mount=type=cache,id=hypercube-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    --mount=type=bind,from=leptonica,source=/packages,target=/packages \
    --mount=type=bind,from=leptonica,source=/etc/apk/keys,target=/etc/apk/keys \
    apk add \
        /packages/leptonica-*.apk \
        poppler-utils=="${POPPLER_VERSION}" \
        tesseract-ocr=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-eng=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-fra=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-spa=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-ita=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-por=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-hin=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-deu=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-jpn=="${SOFTWARE_VERSION}" \
        tesseract-ocr-data-rus=="${SOFTWARE_VERSION}" \
    && cleanup.sh

COPY --link rootfs /
