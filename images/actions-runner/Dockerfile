FROM ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7

ARG TARGETARCH
# renovate: datasource=github-releases depName=gha-runner packageName=actions/runner
ARG SOFTWARE_VERSION=2.338.0
ARG RUNNER_AMD64_SHA256="af4b794c1bc41d73d40535e3fe092a39f9679cd8d965954c2aca25a05ca41d32"
ARG RUNNER_ARM64_SHA256="628b4a7258487b80c1d3c221095a7ded349f5ae0175fd3dfab708d07428f041b"

WORKDIR /app

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    sudo \
    yq \
    libicu-dev \
    docker-buildx \
    docker-compose-v2 \
    docker.io \
    gnupg2 \
    libmagic-dev \
    lsb-release \
    php \
    php-curl \
    php-fpm \
    php-gd \
    php-intl \
    php-mbstring \
    php-mysql \
    php-xml \
    php-zip \
    python3-pip \
    python3-setuptools \
    python3-build \
    python3-urllib3 \
    python3-magic \
    zip \
    unzip

# install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && \
    chmod 644 /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl && \
    kubectl version --client

# install GitHub actions runner
RUN case "${TARGETARCH}" in \
      amd64) platform=linux-x64; checksum="${RUNNER_AMD64_SHA256}" ;; \
      arm64) platform=linux-arm64; checksum="${RUNNER_ARM64_SHA256}" ;; \
      *) echo "Unsupported runner architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
  curl -fsSL -o actions-runner.tar.gz "https://github.com/actions/runner/releases/download/v${SOFTWARE_VERSION}/actions-runner-${platform}-${SOFTWARE_VERSION}.tar.gz" && \
  echo "$checksum  actions-runner.tar.gz" | sha256sum -c && \
  tar xzf ./actions-runner.tar.gz && \
  rm ./actions-runner.tar.gz && \
  bash ./bin/installdependencies.sh && \
  useradd -m -s /bin/bash runner && \
  echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner && \
  usermod -aG docker runner && \
  rm -rf /var/lib/apt/lists/*

# install composer
# renovate: datasource=github-releases depName=custom-composer packageName=composer/composer
ARG COMPOSER_VERSION=2.10.3
ARG COMPOSER_FILE=composer.phar
ARG COMPOSER_URL=https://getcomposer.org/download/${COMPOSER_VERSION}/${COMPOSER_FILE}
ARG COMPOSER_SHA256="7a2d379d5b8ffdaa028580ef26494c36d2feef4b178d3dd1473a4dbc5e17c8d6"
RUN curl -fsSLo "${COMPOSER_FILE}" "${COMPOSER_URL}" && \
    echo "${COMPOSER_SHA256}  ${COMPOSER_FILE}" | sha256sum -c && \
    mv "${COMPOSER_FILE}" /usr/bin/composer && \
    chmod a+x /usr/bin/composer

# install islandora workbench python dependencies
# renovate: datasource=git-refs depName=islandora-workbench packageName=https://github.com/lehigh-university-libraries/islandora_workbench.git branch=simple-field-json
ARG COMMIT=92e3f8bb1b3ffeb470ea2e595fcd48f7b4feaae9
ARG WORKBENCH_SHA256=07b9a611480acb3fb8171dfbac0e1203fb56287e78e0de37876cee14528810a6
WORKDIR /workbench
RUN curl -fsSL -o workbench.tar.gz "https://github.com/lehigh-university-libraries/islandora_workbench/archive/${COMMIT}.tar.gz" && \
  echo "${WORKBENCH_SHA256}  workbench.tar.gz" | sha256sum -c && \
  tar xzf workbench.tar.gz --strip-components=1 && \
  rm workbench.tar.gz && \
  python3 -m pip install \
      --upgrade \
      --ignore-installed \
      pip setuptools build \
      --break-system-packages && \
  python3 -m pip install \
      --no-cache-dir \
      --ignore-installed \
      "urllib3>=1.21.1" \
      libmagic \
      --break-system-packages && \
  python3 -m build && \
  python3 -m pip install \
      --ignore-installed \
      dist/*.whl \
      --break-system-packages && \
  rm -rf /workbench

RUN mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && curl -L -o $out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& apt update \
	&& apt install gh -y

WORKDIR /app

COPY --link rootfs /
RUN chmod +x /app/docker-entrypoint.sh

ENTRYPOINT [ "/app/docker-entrypoint.sh" ]
