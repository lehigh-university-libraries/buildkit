FROM leptonica
FROM scyllaridae

WORKDIR /app

ARG \
  # renovate: datasource=repology depName=alpine_3_24/tesseract-ocr
  TESSERACT_VERSION=5.5.2-r0 \
  # renovate: datasource=repology depName=alpine_3_24/jq
  JQ_VERSION=1.8.2-r0 \
  # renovate: datasource=repology depName=alpine_3_24/ghostscript
  GHOSTSCRIPT_VERSION=10.07.1-r0 \
  # renovate: datasource=repology depName=alpine_3_24/poppler-utils
  POPPLER_VERSION=25.12.0-r1

RUN apk add --no-cache imagemagick imagemagick-jpeg imagemagick-pdf imagemagick-tiff imagemagick-jp2

RUN --mount=type=bind,from=leptonica,source=/packages,target=/packages \
    --mount=type=bind,from=leptonica,source=/etc/apk/keys,target=/etc/apk/keys \
  apk update && \
  apk add --no-cache \
  /packages/leptonica-*.apk \
    ghostscript=="${GHOSTSCRIPT_VERSION}" \
    jq=="${JQ_VERSION}" \
    tesseract-ocr=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-eng=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-fra=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-spa=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-ita=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-por=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-hin=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-deu=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-jpn=="${TESSERACT_VERSION}" \
    tesseract-ocr-data-rus=="${TESSERACT_VERSION}" \
    poppler-utils=="${POPPLER_VERSION}"


COPY --link rootfs /
