#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

CERT_DIR="${CERT_DIR:-./certs}"
CA_SUBJECT="${CA_SUBJECT:-/CN=LibOps Local Development CA}"
LEAF_SUBJECT="${LEAF_SUBJECT:-/CN=localhost}"
SUBJECT_ALT_NAMES="${SUBJECT_ALT_NAMES:-DNS:localhost,IP:127.0.0.1,IP:::1}"
CA_KEY="${CERT_DIR}/rootCA-key.pem"; CA_CERT="${CERT_DIR}/rootCA.pem"
LEAF_KEY="${CERT_DIR}/privkey.pem"; LEAF_CERT="${CERT_DIR}/cert.pem"
readonly CERT_DIR CA_SUBJECT LEAF_SUBJECT SUBJECT_ALT_NAMES CA_KEY CA_CERT LEAF_KEY LEAF_CERT

install -d -m 0700 "${CERT_DIR}"
[ ! -s "${CA_CERT}" ] || [ -s "${CA_KEY}" ] || { echo "CA key is missing for ${CA_CERT}" >&2; exit 1; }
[ ! -s "${LEAF_CERT}" ] || [ -s "${LEAF_KEY}" ] || { echo "Leaf key is missing for ${LEAF_CERT}" >&2; exit 1; }
if [ ! -s "${CA_KEY}" ]; then umask 077; openssl genrsa -out "${CA_KEY}" 4096; fi
chmod 0600 "${CA_KEY}"
if [ ! -s "${CA_CERT}" ]; then
  openssl req -x509 -new -sha256 -key "${CA_KEY}" -out "${CA_CERT}" -days 3650 -subj "${CA_SUBJECT}" \
    -addext 'subjectKeyIdentifier=hash' -addext 'authorityKeyIdentifier=keyid:always,issuer' \
    -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign'
fi
chmod 0644 "${CA_CERT}"
if [ ! -s "${LEAF_KEY}" ]; then umask 077; openssl genrsa -out "${LEAF_KEY}" 2048; fi
chmod 0600 "${LEAF_KEY}"
if [ ! -s "${LEAF_CERT}" ]; then
  workdir="$(mktemp -d)"; trap 'rm -rf -- "${workdir}"' EXIT
  openssl req -new -sha256 -key "${LEAF_KEY}" -out "${workdir}/leaf.csr" -subj "${LEAF_SUBJECT}"
  printf '%s\n' 'authorityKeyIdentifier=keyid,issuer' 'basicConstraints=critical,CA:FALSE' \
    'keyUsage=critical,digitalSignature,keyEncipherment' 'extendedKeyUsage=serverAuth' \
    "subjectAltName=${SUBJECT_ALT_NAMES}" >"${workdir}/leaf.ext"
  openssl x509 -req -sha256 -in "${workdir}/leaf.csr" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
    -set_serial "0x$(openssl rand -hex 16)" -out "${LEAF_CERT}" -days 825 -extfile "${workdir}/leaf.ext"
fi
chmod 0644 "${LEAF_CERT}"
owner_uid="${HOST_UID:-$(stat -c %u -- "${CERT_DIR}")}"
owner_gid="${HOST_GID:-$(stat -c %g -- "${CERT_DIR}")}"
printf '%s\n' "${owner_uid}" >"${CERT_DIR}/UID"
chmod 0644 "${CERT_DIR}/UID"
chown -R "${owner_uid}:${owner_gid}" "${CERT_DIR}"
echo "Development certificates are ready in ${CERT_DIR}."
