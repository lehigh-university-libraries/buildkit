#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage {
    cat <<-EOF
    usage: $PROGNAME HOST PORT

    Waits for the given PORT to be open on HOST, re-checks every second.

    Use in conjunction with timeout.

    OPTIONS:
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
      Check if database is acccessible:
      timeout 10 $PROGNAME database 3306
EOF
}

function cmdline {
    local positional=()

    while (($# > 0)); do
        case "$1" in
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
            positional+=("$@")
            break
            ;;
        -*)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
        *)
            positional+=("$1")
            shift
            ;;
        esac
    done

    if [ "${#positional[@]}" -ne 2 ]; then
        echo "Illegal number of parameters" >&2
        usage
        return 1
    fi

    HOST=${positional[0]}
    PORT=${positional[1]}
    readonly HOST PORT

    return 0
}

function main {
    cmdline "${ARGS[@]}"
    echo "Waiting for ${PORT} on ${HOST} to open." >&2
    while ! nc -z -w5 "${HOST}" "${PORT}" &>/dev/null; do
        sleep 1
    done
    exit 0
}
main
