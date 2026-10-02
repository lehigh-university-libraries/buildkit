#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage() {
    cat <<-EOF
    usage: $PROGNAME options FILE

    With no FILE, or when FILE is -, read standard input.

    Wrapper around execute-sql-file.sh for creating MariaDB/MySQL databases.

    If any of the options are not provided they will be derived from their
    respective 'DB' environment variables.

    Warning: by default DB_ROOT_USER/DB_ROOT_PASSWORD will be used if the
    respective options are not specified.

    OPTIONS:
       --host             The database host.
       --port             The database port.
       --user             The user to connect as.
       --password         The password to use for the user.
       --database         The database to create.
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Create a new MariaDB database:
       echo 'CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci;' | $PROGNAME
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
    DATABASE_NAME=

    while (($# > 0)); do
        case "$1" in
        --host|-b|--port|-c|--user|-d|--password|-e|--database|-f)
            if (($# < 2)); then
                echo "Option $1 requires a value" >&2
                exit 1
            fi
            case "$1" in
                --host|-b) HOST=$2 ;;
                --port|-c) PORT=$2 ;;
                --user|-d) USER=$2 ;;
                --password|-e) PASSWORD=$2 ;;
                --database|-f) DATABASE_NAME=$2 ;;
            esac
            shift 2
            ;;
        --host=*) HOST=${1#*=}; shift ;;
        --port=*) PORT=${1#*=}; shift ;;
        --user=*) USER=${1#*=}; shift ;;
        --password=*) PASSWORD=${1#*=}; shift ;;
        --database=*) DATABASE_NAME=${1#*=}; shift ;;
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

    if fallback "--database" "DATABASE_NAME" "DB_NAME"; then
        DATABASE_NAME=${DB_NAME}
    fi

    if fallback "--user" "USER" "DB_ROOT_USER"; then
        USER=${DB_ROOT_USER}
    fi

    if fallback "--password" "PASSWORD" "DB_ROOT_PASSWORD"; then
        PASSWORD=${DB_ROOT_PASSWORD}
    fi

    if fallback "--host" "HOST" "DB_HOST"; then
        HOST=${DB_HOST}
    fi

    if fallback "--port" "PORT" "DB_PORT"; then
        PORT=${DB_PORT}
    fi

    # Allow either passing in a file/pipe or reading from stdin by specifiying "-" or
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

    readonly HOST PORT USER PASSWORD DATABASE_NAME FILE

    return 0
}

function execute_sql_file {
    LIBOPS_DATABASE_PASSWORD="${PASSWORD}" execute-sql-file.sh \
        --host "${HOST}" \
        --port "${PORT}" \
        --user "${USER}" \
        "${@}"
}

function mysql_create_database {
    execute_sql_file "${FILE}"
}

function main {
    cmdline "${ARGS[@]}"
    # The database name is validated here; the creation SQL is supplied by stdin/file.
    : "${DATABASE_NAME}"

    mysql_create_database
}
main
