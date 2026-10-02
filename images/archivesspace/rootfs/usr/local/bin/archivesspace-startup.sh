#!/command/with-contenv bash
# shellcheck shell=bash
set -euo pipefail

# shellcheck disable=SC1091
source /usr/local/share/libops/database.sh
# shellcheck disable=SC1091
source /usr/local/share/libops/environment.sh

require_environment_variables DB_HOST DB_NAME DB_USER DB_PASSWORD

data_dir="${APPCONFIG_DATA_DIR:-/archivesspace/data}"
mkdir -p "${data_dir}/tmp"
chown -R archivesspace:archivesspace "${data_dir}" /archivesspace/config

function create_archivesspace_database {
  DB_CHARACTER_SET=utf8mb4 \
    DB_COLLATION=utf8mb4_unicode_ci \
    render-database-bootstrap-sql.sh | create-database.sh
}

if [ -n "${ASPACE_INITIALIZE_PLUGINS:-}" ]; then
  IFS=',' read -r -a plugins <<<"${ASPACE_INITIALIZE_PLUGINS}"
  for plugin in "${plugins[@]}"; do
    s6-setuidgid archivesspace /archivesspace/scripts/initialize-plugin.sh "${plugin}"
  done
fi

rm -rf "${data_dir:?}/tmp"/*

if [ "${ASPACE_DB_MIGRATE:-true}" = "true" ]; then
  database_bootstrap_if_enabled create_archivesspace_database
  s6-setuidgid archivesspace /archivesspace/scripts/setup-database.sh
fi

unset DB_ROOT_PASSWORD
exec s6-setuidgid archivesspace /archivesspace/archivesspace.sh
