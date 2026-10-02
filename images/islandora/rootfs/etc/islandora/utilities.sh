#!/command/with-contenv bash
# shellcheck shell=bash

# Capitalize the given string.
function capitalize {
    local string="${1}"
    shift
    awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}' <<<"${string}"
}

# Transform the given string to uppercase.
function uppercase {
    local string="${1}"
    shift
    tr '[:lower:]' '[:upper:]' <<<"${string}"
}

# Joins the given array into a string delimited by the first argument.
function join_by {
    local IFS="${1}"
    shift
    echo "$*"
}

# Get variable value for the single Drupal site.
function drupal_site_env {
    local suffix var
    # Keep the site argument for function call compatibility.
    shift
    suffix="$(uppercase "${1}")"
    shift
    case "${suffix}" in
    DB_HOST | DB_PORT | DB_ROOT_PASSWORD | DB_ROOT_USER | DB_NAME | DB_USER | DB_PASSWORD)
        var="${suffix}"
        ;;
    *)
        var="DRUPAL_DEFAULT_${suffix}"
        ;;
    esac
    echo "${!var}"
}

function site_index {
    echo 0
}

# Wait for service to respond.
function wait_for_service {
    local site service duration host port service_name
    site="${1}"
    shift
    service="${1}"
    shift
    duration="${1-300}"
    host=$(drupal_site_env "${site}" "${service}_HOST")
    port=$(drupal_site_env "${site}" "${service}_PORT")
    service_name=$(capitalize "${service}")

    if timeout "${duration}" wait-for-open-port.sh "${host}" "${port}"; then
        echo "${service_name} Found at ${host}:${port}"
        return 0
    else
        echo "Could not connect to ${service_name} at ${host}:${port}"
        exit 1
    fi
}

# Waits for services that are required to be running to successfully ingest content.
function wait_for_required_services {
    local site
    site="${1}"
    shift
    if [ $# -gt 0 ]; then
        while [ $# -gt 0 ]; do
            local service="${1}"
            shift
            wait_for_service "${site}" "${service}"
        done
    else
        wait_for_service "${site}" "SOLR"
        wait_for_service "${site}" "FCREPO"
        wait_for_service "${site}" "BROKER"
        wait_for_service "${site}" "TRIPLESTORE"
    fi
}

# Apply given function for the single Drupal site.
function for_all_sites {
    local func
    func="${1}"
    shift
    "${func}" "DEFAULT" "${@}"
}

function execute_sql_file {
    local site host port user password
    site="${1}"
    shift
    host=$(drupal_site_env "${site}" "DB_HOST")
    port=$(drupal_site_env "${site}" "DB_PORT")
    user=$(drupal_site_env "${site}" "DB_ROOT_USER")
    password=$(drupal_site_env "${site}" "DB_ROOT_PASSWORD")
    LIBOPS_DATABASE_PASSWORD="${password}" execute-sql-file.sh \
        --host "${host}" \
        --port "${port}" \
        --user "${user}" \
        "${@}"
}

function mysql_query {
    local site db_name db_user db_password
    site="${1}"
    shift
    db_name=$(drupal_site_env "${site}" "DB_NAME")
    db_user=$(drupal_site_env "${site}" "DB_USER")
    db_password=$(drupal_site_env "${site}" "DB_PASSWORD")
    DB_NAME="${db_name}" \
        DB_USER="${db_user}" \
        DB_PASSWORD="${db_password}" \
        DB_CHARACTER_SET=utf8 \
        DB_COLLATION=utf8_general_ci \
        render-database-bootstrap-sql.sh
}

function mysql_create_database {
    local site
    site="${1}"
    shift
    execute_sql_file "${site}" <(mysql_query "${site}")
}

# Create a database for the given site.
function create_database {
    local site
    site="${1}"
    shift
    mysql_create_database "${site}"
}

# Install the given site.
function install_site {
    local \
        site drupal_root host port user password db_name account_email \
        account_name account_password profile site_email site_locale site_name \
        subdir site_directory files_directory install use_existing_config \
        use_existing_config_arg
    site="${1}"
    shift
    drupal_root=/var/www/drupal/web
    host=$(drupal_site_env "${site}" "DB_HOST")
    port=$(drupal_site_env "${site}" "DB_PORT")
    user=$(drupal_site_env "${site}" "DB_USER")
    password=$(drupal_site_env "${site}" "DB_PASSWORD")
    db_name=$(drupal_site_env "${site}" "DB_NAME")
    account_email=$(drupal_site_env "${site}" "ACCOUNT_EMAIL")
    account_name=$(drupal_site_env "${site}" "ACCOUNT_NAME")
    account_password=$(drupal_site_env "${site}" "ACCOUNT_PASSWORD")
    profile=$(drupal_site_env "${site}" "PROFILE")
    site_email=$(drupal_site_env "${site}" "EMAIL")
    site_locale=$(drupal_site_env "${site}" "LOCALE")
    site_name=$(drupal_site_env "${site}" "NAME")
    subdir=$(drupal_site_env "${site}" "SUBDIR")
    site_directory=$(realpath "${drupal_root}/sites/${subdir}")
    files_directory=$(realpath "${site_directory}/files")
    install=$(drupal_site_env "${site}" "INSTALL")
    use_existing_config=$(drupal_site_env "${site}" "INSTALL_EXISTING_CONFIG")
    use_existing_config_arg=

    if [ "${install}" != "true" ]; then
        echo "Skipping install of site: $(capitalize "${site}")"
        return 0
    fi

    # Installing from an existing config is optional only works with
    # non-standard profiles. Ones that do not specify an install hook.
    #
    # https://www.drupal.org/node/2897299
    # https://www.drupal.org/project/drupal/issues/2982052
    if [[ "${use_existing_config}" == "true" ]]; then
        use_existing_config_arg="--existing-config"
    fi

    # Ensure the files directory is writable by nginx, as when it is a new volume it is owned by root.
    chown -R 100:101 "${files_directory}"
    chmod -R ug+rw "${files_directory}"

    # Allow changes to settings.php if it exists.
    if [[ -f "${site_directory:?}/settings.php" ]]; then
        chmod a=rwx "${site_directory:?}/settings.php"
    fi

    echo "--driver mysql"
    echo "--host ${host}"
    echo "--port ${port}"
    echo "--dbuser ${user}"
    echo "--dbname ${db_name}"
    echo "PROFILE: ${profile}"
    echo "--account-mail=${account_email}"
    echo "--account-name=${account_name}"
    echo "--site-mail=${site_email}"
    echo "--locale=${site_locale}"
    echo "--site-name=${site_name}"
    echo "--sites-subdir=${subdir}"
    echo "USE_EXISTIG_CONFIG: ${use_existing_config_arg}"
    echo "EVERYTHING ELSE: $*"

    LIBOPS_DRUPAL_INSTALL_ACCOUNT_PASSWORD="${account_password}" \
    LIBOPS_DRUPAL_INSTALL_DB_PASSWORD="${password}" \
    /usr/local/bin/install-drupal-site.sh \
        --host "${host}" \
        --port "${port}" \
        --db-user "${user}" \
        --db-name "${db_name}" \
        "${profile}" \
        --account-mail="${account_email}" \
        --account-name="${account_name}" \
        --site-mail="${site_email}" \
        --locale="${site_locale}" \
        --site-name="${site_name}" \
        --sites-subdir="${subdir}" \
        "${use_existing_config_arg}" \
        "${@}"

    # Restrict changes to settings.php
    if [[ -f "${site_directory:?}/settings.php" ]]; then
        chmod a=,ug=r "${site_directory:?}/settings.php"
    fi
}

# Enable module and apply configuration.
function configure_jwt_module {
    local site site_url
    site="${1}"
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drush -l "${site_url}" -y pm:enable jwt
    drush -l "${site_url}" -y config:import --partial --source=/etc/islandora/configs/jwt
}

# Install and configure the islandora module.
function configure_islandora_module {
    local site site_url broker_host broker_port broker_url
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    broker_host=$(drupal_site_env "${site}" "BROKER_HOST")
    broker_port=$(drupal_site_env "${site}" "BROKER_PORT")
    broker_url="tcp://${broker_host}:${broker_port}"

    drush -l "${site_url}" -y pm:enable islandora_core_feature
    drush -l "${site_url}" -y config:set --input-format=yaml jsonld.settings remove_jsonld_format true
    drush -l "${site_url}" -y config:set --input-format=yaml islandora.settings broker_url "${broker_url}"

    if drush -l "${site_url}" role:list | grep -q fedoraadmin; then
        echo "Fedora Admin role already exists.  No need to create it."
    else
        drush -l "${site_url}" role:create fedoraadmin fedoraAdmin
    fi
    drush -l "${site_url}" -y user:role:add fedoraadmin admin
}

# Configure Solr port and host.
function configure_islandora_default_module {
    local site site_url host port
    if ! drush pm-list --format=string --type=module --status=enabled --no-core | grep -q search_api; then
        echo "Search API is not installed.  Skipping configuration"
        return 0
    fi
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    host=$(drupal_site_env "${site}" "SOLR_HOST")
    port=$(drupal_site_env "${site}" "SOLR_PORT")

    drush -l "${site_url}" -y config:set search_api.server.default_solr_server backend_config.connector_config.host "${host}"
    drush -l "${site_url}" -y config:set search_api.server.default_solr_server backend_config.connector_config.port "${port}"
}

# Install search_api_solr and configure. Also uninstall the default search module.
function configure_search_api_solr_module {
    local site site_url
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")

    drush -l "${site_url}" -y pm:enable search_api_solr
    drush -l "${site_url}" -y pm:uninstall search
}

# Enables and sets carapace as the default theme.
function set_carapace_default_theme {
    local site site_url
    if ! drush pm-list --format=string --type=theme --status=enabled --no-core | grep -q carapace; then
        echo "carapace is not available. Skipping configuration."
        return 0
    fi

    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drush -l "${site_url}" -y config:set system.theme default carapace
}

# Configure Openseadragon to point use cantaloupe.
function configure_openseadragon {
    local site site_url cantaloupe_url

    if ! drush pm-list --format=string --type=module --status=enabled --no-core | grep -q openseadragon; then
        echo "openseadragon is not installed.  Skipping configuration"
        return 0
    fi

    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    cantaloupe_url=$(drupal_site_env "${site}" "CANTALOUPE_URL")

    drush -l "${site_url}" -y config-set --input-format=yaml media.settings standalone_url true
    drush -l "${site_url}" -y config-set --input-format=yaml openseadragon.settings iiif_server "${cantaloupe_url}"
    drush -l "${site_url}" -y config-set --input-format=yaml openseadragon.settings manifest_view iiif_manifest
    drush -l "${site_url}" -y config-set --input-format=yaml islandora_iiif.settings iiif_server "${cantaloupe_url}"
}

# Imports any migrations in the 'islandora' group.
function import_islandora_migrations {
    local site site_url
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drush -l "${site_url}" -y --userid=1 migrate:import islandora_defaults_tags,islandora_tags
}

# Enable module and apply configuration.
function enable_modules {
    local site site_url
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drush -l "${site_url}" -y pm:enable "${@}"
}

# Enable module and apply configuration.
function import_features {
    local site site_url features
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    features=$(join_by , "${@}")
    shift
    drush -l "${site_url}" fim --no-interaction --yes "${features}"
}

# Rebuild the cache for the given site.
function cache_rebuild {
    local site site_url
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drush -l "${site_url}" -y cache:rebuild
}

# Changes the site ID to match the configuration folder to allow it to be imported.
function set_site_uuid {
    local site site_url drupal_root config_dir uuid
    site="${1}"
    shift
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drupal_root=/var/www/drupal/web
    # Handle the case if config_dir is a relative path.
    config_dir=$(realpath "$(drush --root="${drupal_root}" php:script /etc/islandora/config-sync-directory.php)")
    uuid=$(awk '/uuid/ { print $2 }' "${config_dir:?}/system.site.yml")
    drush -l "${site_url}" -y config:set --input-format=yaml system.site uuid "${uuid}"
}

# Replace references to standard profile in the config files with minimal.
#
# Often we build sites with the standard profile but it is not possible to install
# from a configuration that was generated on a standard profile site.
#
# https://www.drupal.org/project/drupal/issues/2982052
function remove_standard_profile_references_from_config {
    local config_files
    # Do not modify configuration in in the core module.
    config_files=$(find /var/www/drupal -name "core.extension.yml" ! -path '*/core/*')
    for config_file in ${config_files}; do
        # Remove standard profile references, and replace with minimal.
        sed -i 's|\( *\)standard:\(.*\)|\1minimal:\2|' "${config_file}"
        sed -i 's|profile: *standard|profile: minimal|' "${config_file}"
    done
}

# Import sites configuration.
function import_config {
    local site site_url
    site="${1}"
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drush -l "${site_url}" -y config:import
}

# Export sites configuration.
function export_config {
    local site site_url
    site="${1}"
    site_url=$(drupal_site_env "${site}" "SITE_URL")
    drush -l "${site_url}" -y config:export
}
