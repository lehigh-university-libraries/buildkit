#!/usr/bin/env bash
set -e
umask 077

# Sets container environment variables in order of precedence depending on the
# source:
#
#  1. Secrets kept in /run/secrets
#  2. Environment variables passed into the container
#  3. Environment variables defined in Dockerfile(s)
#  4. Environment variables defined in the /etc/defaults directory (lowest only used for multiline variables)
#
# If not defined in the highest level the next level applies and so forth down
# the list. /etc/defaults and the environment variables declared in the
# Dockerfile(s) used to create this image are expected to define all
# environment variables used by scripts and Confd templates.
#
# Confd templates are required to use `getenv` function for all default values.

# Load the environment variables according to the expected precedence.
# Note `exec -c` is used to empty the existing environment.
#
# Write those to the container environment if not already present. The container
# environment has already been initialized by this point and contains levels 2 and
# 4 as mentioned in the top of this file.

# Temporary conditional to prevent issues with Kubernetes as `s6-envdir` expects the
# folder to contain only files, Kubernetes mounts a folder in this location and works
# with secrets in a different way. At a later time we'll revisit our convention to
# hopefully support all that Kuberentes has to offer while not degrading the
# quality of Swarm or Docker Compose. At the moment Kubernetes users will need
# to inject the secrets as environment variables. Please see
# https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-environment-variables
if [[ $(find /run/secrets -mindepth 1 -maxdepth 1 -type d | wc -l) -gt 0 ]]; then
    /command/exec -c \
        s6-envdir -fn -- /etc/defaults \
        s6-envdir -fn -- /var/run/s6/container_environment \
        s6-dumpenv -- /var/run/s6/container_environment
else
    secret_envdir="/var/run/s6/secret_environment"
    rm -rf "${secret_envdir}"
    mkdir -p "${secret_envdir}"

    for secret in /run/secrets/*; do
        if [[ ! -f "${secret}" ]]; then
            continue
        fi

        name="$(basename "${secret}")"
        if [[ "${name}" = "GOOGLE_APPLICATION_CREDENTIALS" ]]; then
            printf '%s' "${secret}" > "${secret_envdir}/${name}"
        else
            cp "${secret}" "${secret_envdir}/${name}"
        fi
    done

    /command/exec -c \
        s6-envdir -fn -- /etc/defaults \
        s6-envdir -fn -- /var/run/s6/container_environment \
        s6-envdir -fn -- "${secret_envdir}" \
        s6-dumpenv -- /var/run/s6/container_environment
fi

# Normalize the container environment through confd's env backend. This can only
# import values that are already defined in the environment.
{
    # shellcheck disable=SC2016 # Literal Go template; shell expansion is unwanted.
    printf '%s\n' '{{ define "execlineEscape" -}}{{- $escaped := replace . "\\" "\\\\" -1 -}}{{- replace $escaped "\"" "\\\"" -1 -}}{{- end -}}'
    for file in /var/run/s6/container_environment/*; do
        VAR=$(basename "${file}")
        KEY=$(echo "${VAR}" | tr '[:upper:]' '[:lower:]' | tr '_' '/')
        echo "${VAR}=\"{{ template \"execlineEscape\" (getv \"/${KEY}\" (getenv \"${VAR}\")) }}\""
    done
} | /usr/local/bin/confd-import-environment.sh

# These files can include database administrator and application credentials.
# Startup scripts run as root and import them before dropping privileges, so
# they do not need to be readable by application service users.
chmod 0700 /var/run/s6/container_environment
find /var/run/s6/container_environment -maxdepth 1 -type f -exec chmod 0600 {} +
