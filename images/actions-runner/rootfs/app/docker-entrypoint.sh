#!/usr/bin/env bash

set -eou pipefail

chown -R runner /app

# make sure the host GID gets remaped to this container's docker GID
if [ -S /var/run/docker.sock ]; then
  DOCKER_GID=$(stat -c %g /var/run/docker.sock)
  groupmod -g "${DOCKER_GID}" docker
fi

# github actions runner setups a svc file after install
# so if that doesn't exist,'
if [ ! -f ./svc.sh ]; then
  sudo -u runner ./config.sh \
    --unattended \
    --url "${GITHUB_REPO}" \
    --token "${GITHUB_RUNNER_TOKEN}" \
    --labels "${LABELS:-ubuntu-24}"
fi

exec sudo -u runner ./run.sh
