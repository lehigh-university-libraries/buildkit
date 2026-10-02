
FROM scyllaridae

WORKDIR /app


RUN apk add --no-cache imagemagick imagemagick-jpeg imagemagick-pdf imagemagick-tiff imagemagick-jp2 \
    zip \
    ttf-liberation && \
  apk add --no-cache tree


COPY --link rootfs /
