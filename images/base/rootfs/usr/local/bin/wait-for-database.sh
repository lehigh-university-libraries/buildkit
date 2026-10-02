#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

# shellcheck source=images/base/rootfs/usr/local/share/libops/database.sh
source "${LIBOPS_DATABASE_LIBRARY:-/usr/local/share/libops/database.sh}"

CLIENT_DEFAULTS_FILE=
REMOVE_CLIENT_DEFAULTS_FILE=false

function usage {
    cat <<-EOF
    usage: $PROGNAME options

    Waits for an connection to an database as the given user, or until the
    timeout is exceeded.

    Exits non-zero if not successful.

    OPTIONS:
       --host             The database host.
       --port             The database port.
       --user             The user to connect as.
       --password         The password to use for the user.
       --defaults-extra-file  Existing MariaDB client option file containing the password.
       --timeout          Time to wait for a connection to the database, defaults to 5 minutes. (Optional)
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Check if database is acccessible:
       $PROGNAME \\
                --host database \\
                --port 3306 \\
                --user root \\
                --password password
EOF
}

function cmdline {
    HOST=
    PORT=
    USER=
    PASSWORD=
    DEFAULTS_EXTRA_FILE=
    TIMEOUT=300

    while (($# > 0)); do
        case "$1" in
        --host|-b|--port|-c|--user|-d|--password|-e|--timeout|-t|--defaults-extra-file)
            if (($# < 2)); then
                echo "Option $1 requires a value" >&2
                exit 1
            fi
            case "$1" in
                --host|-b) HOST=$2 ;;
                --port|-c) PORT=$2 ;;
                --user|-d) USER=$2 ;;
                --password|-e) PASSWORD=$2 ;;
                --timeout|-t) TIMEOUT=$2 ;;
                --defaults-extra-file) DEFAULTS_EXTRA_FILE=$2 ;;
            esac
            shift 2
            ;;
        --host=*) HOST=${1#*=}; shift ;;
        --port=*) PORT=${1#*=}; shift ;;
        --user=*) USER=${1#*=}; shift ;;
        --password=*) PASSWORD=${1#*=}; shift ;;
        --timeout=*) TIMEOUT=${1#*=}; shift ;;
        --defaults-extra-file=*) DEFAULTS_EXTRA_FILE=${1#*=}; shift ;;
        -h|--help)
            usage
            exit 0
            ;;
        -x|--debug)
            set -x
            shift
            ;;
        --) shift; break ;;
        -*)
            echo "Invalid option: $1" >&2
            usage
            exit 1
            ;;
        *)
            break
            ;;
        esac
    done

    if [[ -z "${PASSWORD}" && -n "${LIBOPS_DATABASE_PASSWORD:-}" ]]; then
        PASSWORD=${LIBOPS_DATABASE_PASSWORD}
    elif [[ -z "${PASSWORD}" && -n "${DB_ROOT_PASSWORD:-}" ]]; then
        PASSWORD=${DB_ROOT_PASSWORD}
    fi

    if [[ -z $HOST || -z $PORT || -z $USER || ( -z $PASSWORD && -z $DEFAULTS_EXTRA_FILE ) ]]; then
        echo "Missing one of required options: --host --port --user and --password/--defaults-extra-file" >&2
        exit 1
    fi

    if [[ -n "${DEFAULTS_EXTRA_FILE}" && ! -r "${DEFAULTS_EXTRA_FILE}" ]]; then
        echo "MariaDB client option file is not readable: ${DEFAULTS_EXTRA_FILE}" >&2
        exit 1
    fi

    readonly HOST PORT USER PASSWORD DEFAULTS_EXTRA_FILE TIMEOUT

    return 0
}

function wait_for_connection {
    local duration=${TIMEOUT}
    echo "Waiting for up to ${duration} seconds to connect to Database ${HOST}:${PORT}" >&2
    timeout "${duration}" wait-for-open-port.sh "${HOST}" "${PORT}"
}

function mysql_validate_credentials {
    mariadb \
        --defaults-extra-file="${CLIENT_DEFAULTS_FILE}" \
        --batch \
        --skip-column-names \
        --user="${USER}" \
        --host="${HOST}" \
        --port="${PORT}" \
        --protocol=tcp \
        --execute "SELECT 1" \
        >/dev/null
}

function prepare_client_defaults_file {
    if [[ -n "${DEFAULTS_EXTRA_FILE}" ]]; then
        CLIENT_DEFAULTS_FILE=${DEFAULTS_EXTRA_FILE}
        return 0
    fi

    CLIENT_DEFAULTS_FILE=$(mktemp -t mariadb-client.XXXXXXXXXX)
    database_write_client_defaults_file "${CLIENT_DEFAULTS_FILE}" "${PASSWORD}"
    REMOVE_CLIENT_DEFAULTS_FILE=true
}

function cleanup_client_defaults_file {
    if [[ "${REMOVE_CLIENT_DEFAULTS_FILE}" = "true" && -n "${CLIENT_DEFAULTS_FILE}" ]]; then
        rm -f -- "${CLIENT_DEFAULTS_FILE}"
    fi
}

function validate_credentials {
    echo "Validating Database credentials" >&2
    mysql_validate_credentials
}

function main {
    cmdline "${ARGS[@]}"
    prepare_client_defaults_file
    trap cleanup_client_defaults_file EXIT

    if wait_for_connection; then
        echo "Database found" >&2
    else
        echo "Timed out waiting for database connection" >&2
        return 1
    fi

    if validate_credentials; then
        echo "Credentials are valid" >&2
        return 0
    else
        echo "Credentials are invalid" >&2
        return 1
    fi
}
main
