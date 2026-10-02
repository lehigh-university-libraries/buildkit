#!/usr/bin/env bash

set -euo pipefail

export OJS_SETUP_LIBRARY_ONLY=true
export LIBOPS_DATABASE_LIBRARY="$1"
export LIBOPS_ENVIRONMENT_LIBRARY="$2"
# The third argument is the checked-in OJS setup helper under test.
# shellcheck disable=SC1090
source "$3"

calls="$(mktemp)"
mysql_create_database() { printf 'bootstrap\n' >>"${calls}"; }
wait_for_database() { printf 'wait\n' >>"${calls}"; }
check_ojs_installed() { printf 'check\n' >>"${calls}"; return 1; }
install_ojs() { printf 'install\n' >>"${calls}"; }

export DB_HOST=external-database.example
export DB_BOOTSTRAP_ENABLED=false
export OJS_ADMIN_PASSWORD=test-admin-password
setup_ojs_database
test "$(cat "${calls}")" = $'wait\ncheck\ninstall'
