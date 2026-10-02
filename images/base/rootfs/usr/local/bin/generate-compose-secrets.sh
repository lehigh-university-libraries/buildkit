#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-compose.yaml}"
SECRETS_ROOT="${SECRETS_ROOT:-./secrets}"
readonly COMPOSE_FILE SECRETS_ROOT

format_secret() {
  local name="$1" variable="SECRET_FORMAT_${1//[^A-Za-z0-9_]/_}" format
  format="${!variable:-hex32}"
  case "${format}" in
    hex32) openssl rand -hex 32 ;;
    base64-32) openssl rand -base64 32 | tr -d '\n' ;;
    laravel-base64) printf 'base64:'; openssl rand -base64 32 | tr -d '\n' ;;
    salt74)
      value="$(openssl rand -base64 96 | tr -dc 'A-Za-z0-9_-')"
      printf '%s' "${value:0:74}"
      ;;
    *) echo "Unsupported secret format ${format} for ${name}" >&2; return 1 ;;
  esac
}

resolve_path() {
  local declared="$1"
  case "${declared}" in
    ./*) printf '%s/%s' "${PWD}" "${declared#./}" ;;
    /*) printf '%s' "${declared}" ;;
    *) printf '%s/%s' "${SECRETS_ROOT%/}" "${declared##*/}" ;;
  esac
}

[ -f "${COMPOSE_FILE}" ] || { echo "Compose file not found: ${COMPOSE_FILE}" >&2; exit 1; }
umask 077
while IFS=$'\t' read -r name declared; do
  if [ -z "${name}" ] || [ -z "${declared}" ]; then
    continue
  fi
  path="$(resolve_path "${declared}")"
  case "${path}" in
    */certs/*) continue ;;
  esac
  install -d -m 0700 "$(dirname -- "${path}")"
  if [ ! -s "${path}" ]; then
    echo "Creating: ${path}" >&2
    format_secret "${name}" >"${path}"
  fi
  chmod 0600 "${path}"
done < <(yq -r '(.secrets // {}) | to_entries[] | select(.value.file != null) | [.key, .value.file] | @tsv' "${COMPOSE_FILE}")

owner_uid="${HOST_UID:-$(stat -c %u -- "${SECRETS_ROOT}")}"
owner_gid="${HOST_GID:-$(stat -c %g -- "${SECRETS_ROOT}")}"
chown -R "${owner_uid}:${owner_gid}" "${SECRETS_ROOT}"
