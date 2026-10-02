FROM base

ARG TARGETARCH

# renovate: datasource=github-tags depName=golang packageName=golang/go versioning=go-mod-directive
ARG SOFTWARE_VERSION=go1.26.6
ARG \
  GO_BASE_URL="https://go.dev/dl/${SOFTWARE_VERSION}" \
  GO_AMD64=linux-amd64.tar.gz \
  GO_AMD64_SHA256="708effb774be8237570d0add163225abbdfaf4fca28b2611df167beba4feef89" \
  GO_ARM64=linux-arm64.tar.gz \
  GO_ARM64_SHA256="d0507e9e9d7fe012aae570108cbd76c15de879e17130ab8cb90d4d7445cb1f2e"

RUN if [ "${TARGETARCH}" = "amd64" ]; \
    then \
        download.sh \
            --url "${GO_BASE_URL}.${GO_AMD64}" \
            --sha256 "${GO_AMD64_SHA256}" \
            --dest /usr/local ; \
    else \
        download.sh \
            --url "${GO_BASE_URL}.${GO_ARM64}" \
            --sha256 "${GO_ARM64_SHA256}" \
            --dest /usr/local ; \
    fi && \
    cleanup.sh

ENV PATH=/usr/local/go/bin:$PATH
