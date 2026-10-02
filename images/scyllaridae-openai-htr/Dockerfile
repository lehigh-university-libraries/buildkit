FROM scyllaridae

WORKDIR /app

ARG \
  # renovate: datasource=repology depName=alpine_3_24/jq
  JQ_VERSION=1.8.2-r0


RUN apk add --no-cache imagemagick imagemagick-jpeg imagemagick-pdf imagemagick-tiff imagemagick-jp2 \
      jq=="${JQ_VERSION}"

RUN magick -list format | grep "JPEG-2000"

ENV OPENAI_MODEL=gpt-4o-mini \
    PROMPT="Transcribe this image that contains handwritten text. Include all text you see in the image. In your response, say absolutely nothing except the text from the image." \
    MAX_TOKENS=300


COPY --link rootfs /
