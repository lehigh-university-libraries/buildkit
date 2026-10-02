#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage {
    cat <<-EOF
    usage: $PROGNAME options [DRUSH_ARGS]

    Install a Drupal site with the given [DRUSH_ARGS].

    OPTIONS:
       --host             The database host.
       --port             The database port.
       --db-user          The user to connect as.
       --db-name          The name of the database to install into.

       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Install default Drupal site:
       LIBOPS_DRUPAL_INSTALL_DB_PASSWORD=password $PROGNAME \\
                --host "mariadb" \\
                --port "3306" \\
                --db-user "root" \\
                --db-name "drupal_default" \\
                standard --sites-subdir=default --site-name=Islandora
EOF
}

function cmdline {
    HOST=
    PORT=
    DB_USER=
    DB_PASSWORD=${LIBOPS_DRUPAL_INSTALL_DB_PASSWORD:-}
    DB_NAME=
    DRUSH_ARGS=()

    while (($# > 0)); do
        case "$1" in
        -b|--host|-c|--port|-d|--db-user|-f|--db-name)
            if (($# < 2)); then
                echo "Option $1 requires a value" >&2
                exit 1
            fi
            case "$1" in
                -b|--host) HOST=$2 ;;
                -c|--port) PORT=$2 ;;
                -d|--db-user) DB_USER=$2 ;;
                -f|--db-name) DB_NAME=$2 ;;
            esac
            shift 2
            ;;
        --host=*) HOST=${1#*=}; shift ;;
        --port=*) PORT=${1#*=}; shift ;;
        --db-user=*) DB_USER=${1#*=}; shift ;;
        --db-name=*) DB_NAME=${1#*=}; shift ;;
        -h|--help)
            usage
            exit 0
            ;;
        -x|--debug)
            set -x
            shift
            ;;
        --)
            shift
            DRUSH_ARGS+=("$@")
            break
            ;;
        -*)
            # The first unrecognized option and all following arguments belong
            # to drush, allowing its own option syntax to pass through intact.
            DRUSH_ARGS+=("$@")
            break
            ;;
        *)
            DRUSH_ARGS+=("$1")
            shift
            ;;
        esac
    done

    if [[ -z $HOST || -z $PORT || -z $DB_USER || -z $DB_PASSWORD || -z $DB_NAME ]]; then
        echo "Missing one of required settings: --host --port --db-user --db-name LIBOPS_DRUPAL_INSTALL_DB_PASSWORD"
        exit 1
    fi

    readonly HOST PORT DB_USER DB_PASSWORD DB_NAME DRUSH_ARGS

    return 0
}

function execute_sql_file {
    LIBOPS_DATABASE_PASSWORD="${DB_PASSWORD}" execute-sql-file.sh \
        --host "${HOST}" \
        --port "${PORT}" \
        --user "${DB_USER}" \
        --database "${DB_NAME}" \
        "${@}"
}

function mysql_count_query {
    cat <<-EOF
SELECT COUNT(DISTINCT table_name)
FROM information_schema.columns
WHERE table_schema = DATABASE();
EOF
}

function mysql_count {
    execute_sql_file <(mysql_count_query) -- -N 2>/dev/null
}

function uri_encode {
    LIBOPS_DRUPAL_URI_COMPONENT="$1" \
        php "${LIBOPS_DRUPAL_URI_ENCODER:-/usr/local/share/libops/drupal-uri-encode.php}"
}

function database_url {
    local encoded_name encoded_password encoded_user
    encoded_user=$(uri_encode "${DB_USER}")
    encoded_password=$(uri_encode "${DB_PASSWORD}")
    encoded_name=$(uri_encode "${DB_NAME}")
    printf 'mysql://%s:%s@%s:%s/%s' \
        "${encoded_user}" "${encoded_password}" "${HOST}" "${PORT}" "${encoded_name}"
}

# Check the number of tables to determine if it has already been installed.
function installed {
    local count=
    count=$(mysql_count)
    [[ $count -ne 0 ]]
}

function main {
    local drush_database_url
    cmdline "${ARGS[@]}"
    if installed; then
        echo "Site already is installed."
        return 0
    fi
    echo "Installing site."
    drush_database_url=$(database_url)
    DRUSH_COMMAND_SITE_INSTALL_OPTIONS_ACCOUNT_PASS="${LIBOPS_DRUPAL_INSTALL_ACCOUNT_PASSWORD:-}" \
        DRUSH_COMMAND_SITE_INSTALL_OPTIONS_DB_URL="${drush_database_url}" \
        drush \
        -n \
        si "${DRUSH_ARGS[@]}"
}
main
