#!/bin/sh

set -eu

for argument do
  case "${argument}" in
    *"${EXPECTED_RAW_PASSWORD}"*) exit 42 ;;
  esac
done
printf '%s\n' "${DRUSH_COMMAND_SITE_INSTALL_OPTIONS_DB_URL}" >"${DRUSH_OUTPUT}"
