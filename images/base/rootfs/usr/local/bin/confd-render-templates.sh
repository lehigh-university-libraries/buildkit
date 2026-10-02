#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage {
    cat <<-EOF
    usage: $PROGNAME options

    Renders the confd templates according to the container environment.

    Addional options are passed on to confd.

    Exits non-zero if not successful.

    OPTIONS:
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Render templates once then exit:
       $PROGNAME
EOF
}

function cmdline {
    OPTIONS=()

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
            OPTIONS+=("$@")
            break
            ;;
        *)
            OPTIONS+=("$1")
            shift
            ;;
        esac
    done

    readonly OPTIONS

    return 0
}

function main {
    local args
    cmdline "${ARGS[@]}"

    args=("-log-level" "${CONFD_LOG_LEVEL}" "-backend" "env")

    exec confd "${args[@]}" "${OPTIONS[@]}"
}
main
