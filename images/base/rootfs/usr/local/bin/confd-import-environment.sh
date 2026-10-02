#!/usr/bin/env bash
set -e

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage() {
    cat <<-EOF
    usage: $PROGNAME

    Import environment variables from confd into the 'container environment',
    i.e. accessible via with-contenv.

    Reads a confd template file from stdin. Renders the file and then imports it
    into the container environment with s6-env and s6-dumpenv.

    The file passed via stdin should render to a set of key/values repesenting a
    set of environment variables and their values.

    OPTIONS:
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       Import the environment variable FOO_BAR from confd:
       echo 'FOO_BAR="{{ getv "/foo/bar" }}"' | $PROGNAME
EOF
}

function cmdline() {
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
                echo "confd-import-environment.sh does not accept positional arguments" >&2
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

    # Temporary directory to deposit generated confd configuration templates and
    # output, etc.
    tmp_dir="$(mktemp -d -t confd-XXXXXXXXXX)"
    trap 'rm -rf -- "${tmp_dir}"' EXIT HUP INT TERM
    mkdir -p "${tmp_dir}/conf.d" "${tmp_dir}/templates" "${tmp_dir}/out"

    # Generate template script that will update the container environment with
    # values provided by the confd backend. execline is used rather than bash
    # to avoid issues with whitespace newlines and string interpolation.
    echo 's6-env -i' >"${tmp_dir}/templates/import.sh.tmpl"
    cat - >>"${tmp_dir}/templates/import.sh.tmpl"
    echo 's6-dumpenv -- /var/run/s6/container_environment' >>"${tmp_dir}/templates/import.sh.tmpl"

    # Temporary confd template config.
    cat <<EOF >>"${tmp_dir}/conf.d/import.sh.toml"
[template]
src = "import.sh.tmpl"
dest = "${tmp_dir}/import.sh"
keys = ["/"]
EOF

    # Temporary confd config.
    cat <<EOF >"${tmp_dir}/confd.toml"
confdir = "${tmp_dir}"
noop = false
prefix = "/"
EOF

    # Generate script to import environment variables from confd.
    with-contenv confd-render-templates.sh -- -onetime -sync-only -config-file "${tmp_dir}/confd.toml"

    # Import the variables from confd.
    execlineb -P "${tmp_dir}/import.sh"

}
main
