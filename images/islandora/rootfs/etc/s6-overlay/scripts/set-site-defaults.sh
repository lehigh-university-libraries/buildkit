#!/command/with-contenv bash
# shellcheck shell=bash
set -e

cat <<EOF | /usr/local/bin/confd-import-environment.sh
DRUPAL_SITES="DEFAULT"
EOF
