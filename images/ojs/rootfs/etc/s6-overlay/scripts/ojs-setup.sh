#!/command/with-contenv bash
# shellcheck shell=bash

set -eou pipefail

# shellcheck source=images/base/rootfs/usr/local/share/libops/database.sh
source "${LIBOPS_DATABASE_LIBRARY:-/usr/local/share/libops/database.sh}"
# shellcheck source=images/base/rootfs/usr/local/share/libops/environment.sh
source "${LIBOPS_ENVIRONMENT_LIBRARY:-/usr/local/share/libops/environment.sh}"

function mysql_create_database {
    DB_CHARACTER_SET=utf8 \
        DB_COLLATION=utf8_general_ci \
        render-database-bootstrap-sql.sh | create-database.sh
}

function set_ojs_installed {
    touch /installed
    /etc/s6-overlay/scripts/ojs-install-state.sh
    export OJS_INSTALLED=On
    render_ojs_config
}

function fix_ojs_writable_permissions {
    local dir=
    for dir in /var/www/files /var/www/ojs/cache /var/www/ojs/public; do
        mkdir -p "${dir}"
        chown -R nginx:nginx "${dir}"
        find "${dir}" -type d -exec chmod 750 {} +
        find "${dir}" -type f -exec chmod 640 {} +
    done
}

function render_ojs_config {
    /etc/s6-overlay/scripts/confd-oneshot.sh
}

function validate_ojs_app_key {
    local encoded_key key_length

    if [[ "${OJS_SECRET_KEY}" == base64:* ]]; then
        encoded_key=${OJS_SECRET_KEY#base64:}
        if [[ ! "${encoded_key}" =~ ^[A-Za-z0-9+/]{43}=$ ]] ||
            ! key_length=$(printf '%s' "${encoded_key}" | openssl base64 -d -A 2>/dev/null | wc -c); then
            echo "OJS_SECRET_KEY is not valid base64" >&2
            return 1
        fi
    else
        key_length=${#OJS_SECRET_KEY}
    fi

    if [ "${key_length}" -ne 32 ]; then
        echo "OJS_SECRET_KEY must contain exactly 32 bytes for the default aes-256-cbc cipher" >&2
        return 1
    fi
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
        if [ "${attempts}" -ge 60 ]; then
            echo "Database was not ready in time: ${DB_HOST}:${DB_PORT}" >&2
            return 1
        fi
        sleep 2
    done
}

function check_ojs_installed {
    database_mariadb_with_password "${DB_PASSWORD}" \
        --host="${DB_HOST}" \
        --port="${DB_PORT}" \
        --user="${DB_USER}" \
        --database="${DB_NAME}" \
        --execute="SELECT 1 FROM versions WHERE current = 1 AND product_type = 'core' AND product = 'ojs2' LIMIT 1" \
        &>/dev/null
    return $?
}

function install_ojs {
    echo "OJS not installed. Running installation..."

    local enable_beacon=n install_log install_success=
    umask 077
    install_log=$(mktemp -t ojs-install.XXXXXXXXXX)
    trap 'rm -f -- "${install_log}"' EXIT
    case "${OJS_ENABLE_BEACON}" in
        1|[Oo][Nn]|[Tt][Rr][Uu][Ee]|[Yy]*)
            enable_beacon=y
            ;;
    esac

    echo "Running OJS CLI installer..."
    {
        printf '%s\n' "${OJS_LOCALE}"
        printf '\n'
        printf '%s\n' "${OJS_FILES_DIR}"
        printf '%s\n' "${OJS_ADMIN_USERNAME}"
        printf '%s\n' "${OJS_ADMIN_PASSWORD}"
        printf '%s\n' "${OJS_ADMIN_PASSWORD}"
        printf '%s\n' "${OJS_ADMIN_EMAIL}"
        printf 'mysqli\n'
        printf '%s\n' "${DB_HOST}"
        printf '%s\n' "${DB_USER}"
        printf '%s\n' "${DB_PASSWORD}"
        printf '%s\n' "${DB_NAME}"
        printf '%s\n' "${OJS_OAI_REPOSITORY_ID}"
        printf '%s\n' "${enable_beacon}"
        printf 'y\n'
    } | php /var/www/ojs/tools/install.php >"${install_log}" 2>&1 && install_success=true || install_success=

    if [ -n "${install_success}" ] && grep -q "Successfully installed version" "${install_log}" && check_ojs_installed; then
        echo "=========================================="
        echo "OJS Installation Complete!"
        echo "=========================================="
        rm -f -- "${install_log}"
        trap - EXIT
        set_ojs_installed
        fix_ojs_writable_permissions
    else
        echo "=========================================="
        echo "OJS Installation Failed!"
        echo "=========================================="
        cat "${install_log}"
        echo "=========================================="
        exit 1
    fi
}

function setup_ojs_database {
    if [ "${DB_HOST}" = "mariadb" ]; then
        database_bootstrap_if_enabled mysql_create_database
    fi
    wait_for_database
    if check_ojs_installed; then
        echo "OJS already installed. Skipping installation."
        set_ojs_installed
        fix_ojs_writable_permissions
        return 0
    fi
    require_environment_variables OJS_ADMIN_PASSWORD
    install_ojs
}

function main {
    if [ ! -f /var/www/ojs/index.php ]; then
        echo "OJS application files are not present. Skipping OJS setup."
        return 0
    fi

    require_environment_variables \
        DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD \
        OJS_SALT OJS_API_KEY_SECRET OJS_SECRET_KEY
    validate_ojs_app_key

    # wait for nginx
    if ! timeout 300 wait-for-open-port.sh localhost 80; then
        echo "Could not connect to nginx at localhost:80"
        exit 1
    fi
    setup_ojs_database
}

if [ "${OJS_SETUP_LIBRARY_ONLY:-false}" != "true" ]; then
    main
fi
