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

function wp_cli {
    s6-setuidgid nginx wp --path=/var/www/bedrock/web/wp "$@"
}

function wait_for_wordpress_files {
    local attempts=0
    while [ ! -f /var/www/bedrock/web/wp/wp-load.php ]; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 120 ]; then
            echo "Composer-managed WordPress files were not installed in time"
            exit 1
        fi
        sleep 1
    done
}

function should_skip_wordpress_setup {
    [ ! -f /var/www/bedrock/composer.json ] && [ ! -f /var/www/bedrock/web/wp/wp-load.php ]
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

function check_wordpress_installed {
    wp_cli core is-installed >/dev/null 2>&1
}

function wordpress_home {
    php /usr/local/share/libops/wordpress-home.php
}

function install_wordpress {
    if check_wordpress_installed; then
        echo "WordPress is already installed."
        return 0
    fi

    require_environment_variables WORDPRESS_ADMIN_PASSWORD

    echo "WordPress not installed. Running wp-cli installation..."
    printf '%s\n' "${WORDPRESS_ADMIN_PASSWORD}" | wp_cli core install \
        --url="$(wordpress_home)" \
        --title="${WORDPRESS_SITE_TITLE}" \
        --admin_user="${WORDPRESS_ADMIN_USERNAME}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --prompt=admin_password \
        --skip-email

    wp_cli option update permalink_structure '/%postname%/'
    wp_cli option update blog_public "${WORDPRESS_BLOG_PUBLIC}"

    if [ "${WORDPRESS_LOCALE}" != "en_US" ]; then
        wp_cli language core install "${WORDPRESS_LOCALE}" || true
        wp_cli site switch-language "${WORDPRESS_LOCALE}" || true
    fi

    if check_wordpress_installed; then
        echo "=========================================="
        echo "WordPress installation complete!"
        echo "=========================================="
    else
        echo "=========================================="
        echo "WordPress installation failed!"
        echo "=========================================="
        exit 1
    fi
}

function main {
    if should_skip_wordpress_setup; then
        echo "WordPress application files are not present. Skipping WordPress setup."
        return 0
    fi

    require_environment_variables \
        DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD \
        WORDPRESS_AUTH_KEY WORDPRESS_SECURE_AUTH_KEY \
        WORDPRESS_LOGGED_IN_KEY WORDPRESS_NONCE_KEY \
        WORDPRESS_AUTH_SALT WORDPRESS_SECURE_AUTH_SALT \
        WORDPRESS_LOGGED_IN_SALT WORDPRESS_NONCE_SALT

    wait_for_wordpress_files
    if [ "${DB_HOST}" = "mariadb" ]; then
        database_bootstrap_if_enabled mysql_create_database
    fi
    wait_for_database
    install_wordpress
    touch /installed
}
main
