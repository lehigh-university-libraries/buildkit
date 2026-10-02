#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage {
    cat <<-EOF
    usage: $PROGNAME

    Runs all the scripts in /etc/cleanup.d

    OPTIONS:
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Clone repository:
       $PROGNAME
EOF
}

function cmdline {
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
            if (($# > 0)); then
                echo "cleanup.sh does not accept positional arguments" >&2
                exit 1
            fi
            ;;
        *)
            echo "Invalid option or argument: $1" >&2
            exit 1
            ;;
        esac
    done

    return 0
}

function main {
    cmdline "${ARGS[@]}"
    for file in /etc/cleanup.d/*; do
        if [[ -f "${file}" && -x "${file}" ]]; then
            "${file}"
        fi
    done
}
main
