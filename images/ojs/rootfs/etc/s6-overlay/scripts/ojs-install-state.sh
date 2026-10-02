#!/command/with-contenv bash
# shellcheck shell=bash

set -euo pipefail

state=Off
if [ -f /installed ]; then
    state=On
fi

environment_dir=/var/run/s6/container_environment
umask 077
mkdir -p "${environment_dir}"
printf '%s' "${state}" >"${environment_dir}/OJS_INSTALLED"
chmod 0600 "${environment_dir}/OJS_INSTALLED"
