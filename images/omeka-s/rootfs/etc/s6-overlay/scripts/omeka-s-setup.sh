#!/command/with-contenv bash
# shellcheck shell=bash

set -eou pipefail

# shellcheck disable=SC1091
source /usr/local/share/libops/database.sh
# shellcheck disable=SC1091
source /usr/local/share/libops/environment.sh

function mysql_create_database {
    DB_CHARACTER_SET=utf8mb4 \
        DB_COLLATION=utf8mb4_unicode_ci \
        render-database-bootstrap-sql.sh | create-database.sh
}

function wait_for_database {
    local attempts=0
    until database_mariadb_with_password "${DB_PASSWORD}" \
        --host="${DB_HOST}" \
        --port="${DB_PORT}" \
        --user="${DB_USER}" \
        --database="${DB_NAME}" \
        --execute='SELECT 1' \
        >/dev/null 2>&1; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 60 ]; then
            echo "Database was not ready in time"
            exit 1
        fi
        sleep 2
    done
}

function check_installed {
    database_mariadb_with_password "${DB_PASSWORD}" \
        --host="${DB_HOST}" \
        --port="${DB_PORT}" \
        --user="${DB_USER}" \
        --database="${DB_NAME}" \
        --execute="SELECT 1 FROM \`user\` LIMIT 1" \
        >/dev/null 2>&1
}

function install_omeka {
    if check_installed; then
        echo "Omeka S is already installed."
        return 0
    fi

    require_environment_variables OMEKA_S_ADMIN_PASSWORD

    timeout 300 wait-for-open-port.sh localhost 80

    local form_dir install_log curl_status=0
    umask 077
    form_dir=$(mktemp -d)
    install_log=$(mktemp -t omeka-s-install.XXXXXXXXXX)
    trap 'rm -rf -- "${form_dir}" "${install_log}"' EXIT
    printf '%s' "${OMEKA_S_ADMIN_EMAIL}" >"${form_dir}/admin-email"
    printf '%s' "${OMEKA_S_ADMIN_NAME}" >"${form_dir}/admin-name"
    printf '%s' "${OMEKA_S_ADMIN_PASSWORD}" >"${form_dir}/admin-password"
    printf '%s' "${OMEKA_S_SITE_TITLE}" >"${form_dir}/site-title"
    printf '%s' "${OMEKA_S_TIME_ZONE}" >"${form_dir}/time-zone"
    printf '%s' "${OMEKA_S_LOCALE}" >"${form_dir}/locale"
    printf '%s' Submit >"${form_dir}/submit"

    curl -fsS \
        --data-urlencode "user[email]@${form_dir}/admin-email" \
        --data-urlencode "user[email-confirm]@${form_dir}/admin-email" \
        --data-urlencode "user[name]@${form_dir}/admin-name" \
        --data-urlencode "user[password-confirm][password]@${form_dir}/admin-password" \
        --data-urlencode "user[password-confirm][password-confirm]@${form_dir}/admin-password" \
        --data-urlencode "settings[installation_title]@${form_dir}/site-title" \
        --data-urlencode "settings[time_zone]@${form_dir}/time-zone" \
        --data-urlencode "settings[locale]@${form_dir}/locale" \
        --data-urlencode "submit@${form_dir}/submit" \
        http://localhost/install >"${install_log}" 2>&1 || curl_status=$?
    rm -rf -- "${form_dir}"

    if [ "${curl_status}" -ne 0 ]; then
        cat "${install_log}"
        rm -f -- "${install_log}"
        trap - EXIT
        return "${curl_status}"
    fi
    if ! check_installed; then
        echo "Omeka S installer response did not create the expected database tables."
        cat "${install_log}"
        exit 1
    fi
    rm -f -- "${install_log}"
    trap - EXIT
}

function main {
    if [ ! -f /var/www/omeka-s/index.php ]; then
        echo "Omeka S application files are not present. Skipping Omeka S setup."
        return 0
    fi

    require_environment_variables DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD

    if [ "${DB_HOST}" = "mariadb" ]; then
        database_bootstrap_if_enabled mysql_create_database
    fi
    wait_for_database
    install_omeka
    touch /installed
}

main
