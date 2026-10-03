FROM alpine@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6

ARG TARGETARCH
ARG SOFTWARE_VERSION=1.84.1

RUN --mount=type=cache,id=abuild-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    apk add \
        alpine-sdk \
        bash \
        sudo \
    && \
    adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder && \
    echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ENV PACKAGER="Nigel Banks <nigel.g.banks@gmail.com>"

USER builder

SHELL ["/bin/bash", "-c"]

ARG TARGETARCH

WORKDIR /build

# Platform specific does require arch specific identifier.
RUN --mount=type=bind,readwrite=true,source=build,target=/build \
    --mount=type=cache,id=leptonica-apk-${TARGETARCH},sharing=locked,target=/var/cache/apk \
    export PACKAGES=(\
        autoconf \
        automake \
        giflib-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libtool \
        libwebp-dev \
        openjpeg-dev \
        tiff-dev \
        zlib-dev \
    ) && \
    sudo apk add "${PACKAGES[@]}" && \
    sudo mkdir -p /packages && \
    sudo chown -R builder /build && \
    sed -i "s/^pkgver=.*/pkgver=${SOFTWARE_VERSION}/" /build/APKBUILD && \
    abuild-keygen -ain && \
    abuild-apk update && \
    abuild && \
    sudo apk del "${PACKAGES[@]}" && \
    sudo mv $(find /home/builder/packages/* -type f) /packages
