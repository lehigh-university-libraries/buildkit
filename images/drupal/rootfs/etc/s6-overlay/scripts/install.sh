#!/command/with-contenv bash
# shellcheck shell=bash
set -euo pipefail

export PATH="/var/www/drupal/vendor/bin:${PATH}"

# shellcheck source=images/base/rootfs/usr/local/share/libops/database.sh
source "${LIBOPS_DATABASE_LIBRARY:-/usr/local/share/libops/database.sh}"
# shellcheck source=images/base/rootfs/usr/local/share/libops/environment.sh
source "${LIBOPS_ENVIRONMENT_LIBRARY:-/usr/local/share/libops/environment.sh}"

function mysql_create_database {
    DB_CHARACTER_SET=utf8mb4 \
        DB_COLLATION=utf8mb4_unicode_ci \
        render-database-bootstrap-sql.sh | create-database.sh
}

function mysql_count_query {
    cat <<-SQL
SELECT COUNT(DISTINCT table_name)
FROM information_schema.columns
WHERE table_schema = DATABASE();
SQL
}

function installed {
    local count
    count=$(LIBOPS_DATABASE_PASSWORD="${DB_PASSWORD}" execute-sql-file.sh \
        --host "${DB_HOST}" \
        --port "${DB_PORT}" \
        --user "${DB_USER}" \
        --database "${DB_NAME}" \
        <(mysql_count_query) -- -N 2>/dev/null) || return 1
    [[ ${count:-0} -ne 0 ]]
}

function setup_directories {
    local site_directory public_files_directory private_files_directory twig_cache_directory
    site_directory="/var/www/drupal/web/sites/${DRUPAL_DEFAULT_SUBDIR}"
    public_files_directory="${site_directory}/files"
    private_files_directory="/var/www/drupal/private"
    twig_cache_directory="${private_files_directory}/php"

    mkdir -p "${site_directory}" "${public_files_directory}" "${private_files_directory}" "${twig_cache_directory}"
    chown nginx:nginx "${site_directory}" "${public_files_directory}" "${private_files_directory}" "${twig_cache_directory}"
    chmod ug+rw "${site_directory}" "${public_files_directory}" "${private_files_directory}" "${twig_cache_directory}"
}

function ensure_runtime_settings {
    local core_settings defaults_file drupal_root marker settings_file site_directory
    drupal_root="${DRUPAL_ROOT:-/var/www/drupal}"
    site_directory="${drupal_root}/web/sites/${DRUPAL_DEFAULT_SUBDIR}"
    settings_file="${site_directory}/settings.php"
    core_settings="${drupal_root}/web/core/assets/scaffold/files/default.settings.php"
    defaults_file="${DRUPAL_DEFAULT_SETTINGS_FILE:-/usr/share/drupal/default_settings.txt}"
    marker="require '/etc/drupal/libops.settings.php';"

    if [ ! -f "${settings_file}" ]; then
        if [ ! -f "${core_settings}" ]; then
            echo "Drupal core settings template is missing: ${core_settings}" >&2
            return 1
        fi
        install -m 0644 "${core_settings}" "${settings_file}"
    fi
    if grep -Fq "${marker}" "${settings_file}"; then
        return 0
    fi
    if [ ! -f "${defaults_file}" ]; then
        echo "LibOps Drupal runtime settings are missing: ${defaults_file}" >&2
        return 1
    fi
    printf '\n' >>"${settings_file}"
    cat "${defaults_file}" >>"${settings_file}"
}

function drush_cache_setup {
    mkdir -p /tmp/drush-/cache
    chmod a+rwx /tmp/drush-/cache
}

function uri_encode {
    LIBOPS_DRUPAL_URI_COMPONENT="$1" \
        php "${LIBOPS_DRUPAL_URI_ENCODER:-/usr/local/share/libops/drupal-uri-encode.php}"
}

function install_site {
    local db_url

    # A fresh site has no bootstrapped settings yet. Pass the database through
    # Drush's command environment to keep its password out of process arguments.
    db_url="mysql://$(uri_encode "${DB_USER}")"
    db_url+=":$(uri_encode "${DB_PASSWORD}")"
    db_url+="@${DB_HOST}:${DB_PORT}/$(uri_encode "${DB_NAME}")"

    DRUSH_COMMAND_SITE_INSTALL_OPTIONS_DB_URL="${db_url}" \
        DRUSH_COMMAND_SITE_INSTALL_OPTIONS_ACCOUNT_PASS="${DRUPAL_DEFAULT_ACCOUNT_PASSWORD}" drush \
        -n \
        -r /var/www/drupal/web \
        site:install "${DRUPAL_DEFAULT_PROFILE}" \
        --sites-subdir="${DRUPAL_DEFAULT_SUBDIR}" \
        --site-name="${DRUPAL_DEFAULT_NAME}" \
        --site-mail="${DRUPAL_DEFAULT_EMAIL}" \
        --account-name="${DRUPAL_DEFAULT_ACCOUNT_NAME}" \
        --account-mail="${DRUPAL_DEFAULT_ACCOUNT_EMAIL}" \
        --locale="${DRUPAL_DEFAULT_LOCALE}"

    if [[ "${DRUPAL_DEFAULT_INSTALL_EXISTING_CONFIG}" == "true" ]]; then
        local source_uuid
        source_uuid="$(yq -r '.uuid // ""' "${DRUPAL_DEFAULT_CONFIGDIR}/system.site.yml")"
        if [[ -z "${source_uuid}" ]]; then
            echo "Existing configuration has no site UUID" >&2
            return 1
        fi
        drush -n -r /var/www/drupal/web config:set system.site uuid \
            "${source_uuid}" --uri="$(drush_uri)" --yes
        drush -n -r /var/www/drupal/web config:import \
            --source="${DRUPAL_DEFAULT_CONFIGDIR}" \
            --uri="$(drush_uri)" \
            --yes
    fi
}

function run_install_hooks {
    local hook
    if [ ! -d /etc/s6-overlay/scripts/install.d ]; then
        return 0
    fi
    for hook in /etc/s6-overlay/scripts/install.d/*; do
        if [ ! -f "${hook}" ] || [ ! -x "${hook}" ]; then
            continue
        fi
        echo "Running Drupal install hook ${hook}"
        "${hook}"
    done
}

function ingress_primary_hostname {
    local hostnames hostname
    hostnames="${INGRESS_HOSTNAMES:-localhost}"
    hostname="${hostnames%%,*}"
    hostname="${hostname//[[:space:]]/}"
    echo "${hostname:-localhost}"
}

function ingress_base_url {
    local scheme
    scheme="${INGRESS_SCHEME:-http}"
    echo "${scheme:-http}://$(ingress_primary_hostname)"
}

function drush_uri {
    ingress_base_url
}

function rebuild_drupal_cache {
    local uri
    uri="$(drush_uri)"
    drush --root=/var/www/drupal/web --uri="${uri}" cache:rebuild
}

function finished {
    touch /installed
    cat <<-EOT


#####################
# Install Completed #
#####################
EOT
}

function main {
    if [ ! -f /var/www/drupal/web/core/lib/Drupal.php ]; then
        echo "Drupal application files are not present. Skipping Drupal setup."
        return 0
    fi
    if ! command -v drush >/dev/null 2>&1; then
        echo "Drush is not present. Skipping Drupal setup."
        return 0
    fi

    require_environment_variables DB_HOST DB_NAME DB_USER DB_PASSWORD DRUPAL_DEFAULT_SALT

    cd /var/www/drupal
    drush_cache_setup
    setup_directories
    ensure_runtime_settings
    if [ "${DB_HOST}" = "mariadb" ]; then
        database_bootstrap_if_enabled mysql_create_database
    fi

    if installed; then
        echo "Already Installed"
    else
        require_environment_variables DRUPAL_DEFAULT_ACCOUNT_PASSWORD
        echo "Installing"
        install_site
        run_install_hooks
        rebuild_drupal_cache
    fi
    finished
}

if [ "${DRUPAL_SETUP_LIBRARY_ONLY:-false}" != "true" ]; then
    main
fi
