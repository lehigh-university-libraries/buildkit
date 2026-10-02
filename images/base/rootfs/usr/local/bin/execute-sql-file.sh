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
    usage: $PROGNAME options FILE

    With no FILE, or when FILE is -, read standard input.

    Executes the given SQL file against MariaDB.

    If any of the options are not provided they will be derived from their
    respective 'DB' environment variables.

    Warning: by default DB_ROOT_USER/DB_ROOT_PASSWORD will be used if the
    respective options are not specified.

    OPTIONS:
       --host             The database host.
       --port             The database port.
       --user             The user to connect as.
       --password         The password to use for the user.
       --defaults-extra-file  Existing MariaDB client option file containing the password.
       --database         The database to run the sql command against. (Optional)
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Create a database:
       $PROGNAME \\
                --host "mariadb" \\
                --port "3306" \\
                --user "root" \\
                --password "password" query.sql
EOF
}

# Check if a fallback is required / missing.
function fallback {
    local option=${1}
    local name=${2}
    local fallback=${3}
    if [[ -z ${!name} ]]; then
        if [[ -z ${!fallback} ]]; then
            echo "Missing option ${option} and fallback environment variable ${fallback}" >&2
            exit 1
        else
            return 0
        fi
    fi
    return 1
}

function cmdline {
    HOST=
    PORT=
    USER=
    PASSWORD=
    DATABASE=
    DEFAULTS_EXTRA_FILE=

    while (($# > 0)); do
        case "$1" in
        --host|-b|--port|-c|--user|-d|--password|-e|--database|-f|--defaults-extra-file)
            if (($# < 2)); then
                echo "Option $1 requires a value" >&2
                exit 1
            fi
            case "$1" in
                --host|-b) HOST=$2 ;;
                --port|-c) PORT=$2 ;;
                --user|-d) USER=$2 ;;
                --password|-e) PASSWORD=$2 ;;
                --database|-f) DATABASE=$2 ;;
                --defaults-extra-file) DEFAULTS_EXTRA_FILE=$2 ;;
            esac
            shift 2
            ;;
        --host=*) HOST=${1#*=}; shift ;;
        --port=*) PORT=${1#*=}; shift ;;
        --user=*) USER=${1#*=}; shift ;;
        --password=*) PASSWORD=${1#*=}; shift ;;
        --database=*) DATABASE=${1#*=}; shift ;;
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
        -) break ;;
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

    if fallback "--user" "USER" "DB_ROOT_USER"; then
        USER=${DB_ROOT_USER}
    fi

    if [[ -z "${PASSWORD}" && -n "${LIBOPS_DATABASE_PASSWORD:-}" ]]; then
        PASSWORD=${LIBOPS_DATABASE_PASSWORD}
    elif [[ -z "${PASSWORD}" && -z "${DEFAULTS_EXTRA_FILE}" ]] && fallback "--password" "PASSWORD" "DB_ROOT_PASSWORD"; then
        PASSWORD=${DB_ROOT_PASSWORD}
    fi

    if fallback "--host" "HOST" "DB_HOST"; then
        HOST=${DB_HOST}
    fi

    if fallback "--port" "PORT" "DB_PORT"; then
        PORT=${DB_PORT}
    fi

    # Allow either passing in a file or reading from stdin by specifiying "-" or
    # ommiting completely.
    if [[ -n "${1:-}" && ( -f "$1" || -p "$1" ) ]]; then
        FILE=$1
        shift
    elif [[ "${1:-}" == "-" ]]; then
        FILE=/dev/stdin
        shift
    else
        FILE=/dev/stdin
    fi

    # Remaining options to be passed onto the client, preceeded by '--'.
    if [[ "${1:-}" == "--" ]]; then
        shift
    fi

    if [ "$#" -gt 0 ]; then
        OPTIONS=("${@}")
        shift $#
    else
        OPTIONS=()
    fi

    if [[ -n "${DEFAULTS_EXTRA_FILE}" && ! -r "${DEFAULTS_EXTRA_FILE}" ]]; then
        echo "MariaDB client option file is not readable: ${DEFAULTS_EXTRA_FILE}" >&2
        exit 1
    fi

    readonly HOST PORT USER PASSWORD DATABASE DEFAULTS_EXTRA_FILE FILE OPTIONS

    return 0
}

function wait_for_access {
    # Redirect all output to 'stderr' so that this can be called to do count queries, etc.
    # Callers can extract the value from the appropriate value from 'stdout'.
    wait-for-database.sh \
        --host "${HOST}" \
        --port "${PORT}" \
        --user "${USER}" \
        --defaults-extra-file "${CLIENT_DEFAULTS_FILE}" >&2
}

function mysql_execute_sql_file {
    local database_args=()

    if [[ -n "${DATABASE}" ]]; then
        database_args+=("--database=${DATABASE}")
    fi

    mariadb \
        --defaults-extra-file="${CLIENT_DEFAULTS_FILE}" \
        --host="${HOST}" \
        --port="${PORT}" \
        --user="${USER}" \
        --protocol=tcp \
        "${database_args[@]}" \
        "${OPTIONS[@]}" \
        <"${FILE}"
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

function execute_sql_file {
    mysql_execute_sql_file
}

function main {
    cmdline "${ARGS[@]}"
    prepare_client_defaults_file
    trap cleanup_client_defaults_file EXIT
    wait_for_access
    execute_sql_file
}
main
