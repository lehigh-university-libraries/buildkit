#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage() {
    cat <<-EOF
    usage: $PROGNAME options [DIR]...

    Creates a user/group for the service and as well as a directory in /opt
    ensuring that all files are owned by that user/group.

    Additional parameters are directories to be created, and owned by the new
    user/group.

    OPTIONS:
       -n --name          The name of the user (used to create user/group and home directory).
       -g --group         The secondary group to add the user to (Optional).
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Create user/group "activemq" and home folder /opt/activemq:
       $PROGNAME --name "activemq"
EOF
}

function cmdline() {
    NAME=
    GROUP=
    DIRECTORIES=()

    while (($# > 0)); do
        case "$1" in
        -n|--name|-g|--group)
            if (($# < 2)); then
                echo "Option $1 requires a value" >&2
                exit 1
            fi
            case "$1" in
                -n|--name) NAME=$2 ;;
                -g|--group) GROUP=$2 ;;
            esac
            shift 2
            ;;
        --name=*) NAME=${1#*=}; shift ;;
        --group=*) GROUP=${1#*=}; shift ;;
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
            DIRECTORIES+=("$@")
            break
            ;;
        -*)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
        *)
            DIRECTORIES+=("$1")
            shift
            ;;
        esac
    done

    if [[ -z ${NAME} ]]; then
        echo "Missing one or more required options: --name" >&2
        exit 1
    fi

    readonly NAME GROUP DIRECTORIES

    return 0
}

function main {
    local install_directory user group
    cmdline "${ARGS[@]}"

    install_directory="/opt/${NAME}"
    user="${NAME}"
    group="${NAME}"
    mkdir -p "${install_directory}"
    if ! grep -q "^${group}:" /etc/group; then
        addgroup "${group}" # Primary group is always the same as the name.
    fi
    # Users that run services should permit login and should not require passwords.
    if ! id -u "${user}" >/dev/null 2>&1; then
        adduser --system --disabled-password --no-create-home --ingroup "${group}" --shell /sbin/nologin --home "${install_directory}" "${user}"
    fi
    # User also needs to be a member of tty to write directly to /dev/stdout, etc.
    if ! id -nG "${user}" | tr ' ' '\n' | grep -qx tty; then
        addgroup "${user}" tty
    fi
    # Optional secondary group.
    if [[ -n "${GROUP}" ]]; then
        if ! id -nG "${user}" | tr ' ' '\n' | grep -qx "${GROUP}"; then
            addgroup "${NAME}" "${GROUP}"
        fi
    fi
    if ((${#DIRECTORIES[@]})); then
        mkdir -p "${DIRECTORIES[@]}"
    fi
    chown -R "${user}:${group}" "${install_directory}" "${DIRECTORIES[@]}"
}
main
