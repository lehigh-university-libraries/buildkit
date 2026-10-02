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
    database_validate_identifier OMEKA_CLASSIC_TABLE_PREFIX "${OMEKA_CLASSIC_TABLE_PREFIX}"
    database_mariadb_with_password "${DB_PASSWORD}" \
        --host="${DB_HOST}" \
        --port="${DB_PORT}" \
        --user="${DB_USER}" \
        --database="${DB_NAME}" \
        --execute="SELECT 1 FROM ${OMEKA_CLASSIC_TABLE_PREFIX}options LIMIT 1" \
        >/dev/null 2>&1
}

function install_omeka {
    if check_installed; then
        echo "Omeka Classic is already installed."
        return 0
    fi

    require_environment_variables OMEKA_CLASSIC_ADMIN_PASSWORD

    timeout 300 wait-for-open-port.sh localhost 80

    local form_dir install_log curl_status=0
    umask 077
    form_dir=$(mktemp -d)
    install_log=$(mktemp -t omeka-classic-install.XXXXXXXXXX)
    trap 'rm -rf -- "${form_dir}" "${install_log}"' EXIT
    printf '%s' "${OMEKA_CLASSIC_ADMIN_USERNAME}" >"${form_dir}/admin-username"
    printf '%s' "${OMEKA_CLASSIC_ADMIN_PASSWORD}" >"${form_dir}/admin-password"
    printf '%s' "${OMEKA_CLASSIC_ADMIN_EMAIL}" >"${form_dir}/admin-email"
    printf '%s' "${OMEKA_CLASSIC_SITE_TITLE}" >"${form_dir}/site-title"
    printf '%s' , >"${form_dir}/tag-delimiter"
    printf '%s' 800 >"${form_dir}/fullsize-constraint"
    printf '%s' 200 >"${form_dir}/thumbnail-constraint"
    printf '%s' 200 >"${form_dir}/square-thumbnail-constraint"
    printf '%s' 10 >"${form_dir}/per-page-admin"
    printf '%s' 10 >"${form_dir}/per-page-public"
    printf '%s' /usr/bin >"${form_dir}/path-to-convert"
    printf '%s' Install >"${form_dir}/install-submit"

    curl -fsS \
        --data-urlencode "username@${form_dir}/admin-username" \
        --data-urlencode "password@${form_dir}/admin-password" \
        --data-urlencode "password_confirm@${form_dir}/admin-password" \
        --data-urlencode "super_email@${form_dir}/admin-email" \
        --data-urlencode "administrator_email@${form_dir}/admin-email" \
        --data-urlencode "site_title@${form_dir}/site-title" \
        --data-urlencode "tag_delimiter@${form_dir}/tag-delimiter" \
        --data-urlencode "fullsize_constraint@${form_dir}/fullsize-constraint" \
        --data-urlencode "thumbnail_constraint@${form_dir}/thumbnail-constraint" \
        --data-urlencode "square_thumbnail_constraint@${form_dir}/square-thumbnail-constraint" \
        --data-urlencode "per_page_admin@${form_dir}/per-page-admin" \
        --data-urlencode "per_page_public@${form_dir}/per-page-public" \
        --data-urlencode "path_to_convert@${form_dir}/path-to-convert" \
        --data-urlencode "install_submit@${form_dir}/install-submit" \
        http://localhost/install/install.php >"${install_log}" 2>&1 || curl_status=$?
    rm -rf -- "${form_dir}"

    if [ "${curl_status}" -ne 0 ]; then
        cat "${install_log}"
        rm -f -- "${install_log}"
        trap - EXIT
        return "${curl_status}"
    fi
    if ! check_installed; then
        echo "Omeka Classic installer response did not create the expected database tables."
        cat "${install_log}"
        exit 1
    fi
    rm -f -- "${install_log}"
    trap - EXIT
}

function main {
    if [ ! -f /var/www/omeka-classic/index.php ]; then
        echo "Omeka Classic application files are not present. Skipping Omeka Classic setup."
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
