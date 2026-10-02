#!/usr/bin/env bash
# shellcheck shell=bash

function database_validate_identifier {
    local name=$1
    local value=$2

    if [[ ! "${value}" =~ ^[A-Za-z0-9_]+$ ]]; then
        echo "${name} must contain only letters, numbers, and underscores" >&2
        return 1
    fi
}

function database_escape_sql_literal {
    local value=$1

    value=${value//\\/\\\\}
    value=${value//\'/\'\'}
    printf '%s' "${value}"
}

function database_escape_option_file_value {
    local value=$1

    value=${value//\\/\\\\}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    value=${value//\"/\\\"}
    printf '%s' "${value}"
}

function database_write_client_defaults_file {
    local file=$1
    local password=$2
    local password_escaped

    password_escaped=$(database_escape_option_file_value "${password}")
    (
        umask 077
        printf '[client]\npassword="%s"\n' "${password_escaped}" >"${file}"
        chmod 0600 "${file}"
    )
}

function database_mariadb_with_password {
    local password=$1
    shift

    (
        local client_defaults_file
        client_defaults_file=$(mktemp -t mariadb-client.XXXXXXXXXX)
        trap 'rm -f -- "${client_defaults_file}"' EXIT
        database_write_client_defaults_file "${client_defaults_file}" "${password}"
        command mariadb --defaults-extra-file="${client_defaults_file}" "$@"
    )
}

function database_require_root_credentials {
    if [ -z "${DB_ROOT_USER:-}" ]; then
        echo "DB_ROOT_USER must not be empty" >&2
        return 1
    fi
    if [ -z "${DB_ROOT_PASSWORD:-}" ]; then
        echo "DB_ROOT_PASSWORD must not be empty" >&2
        return 1
    fi
}

# Return 0 when application-side database bootstrap was explicitly enabled,
# 1 when it is disabled, and 2 for an unsafe or invalid configuration.
function database_bootstrap_enabled {
    case "${DB_BOOTSTRAP_ENABLED:-false}" in
        1 | [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss] | [Oo][Nn])
            if ! database_require_root_credentials; then
                echo "Root credentials are required when DB_BOOTSTRAP_ENABLED=true" >&2
                return 2
            fi
            return 0
            ;;
        '' | 0 | [Ff][Aa][Ll][Ss][Ee] | [Nn][Oo] | [Oo][Ff][Ff])
            return 1
            ;;
        *)
            echo "DB_BOOTSTRAP_ENABLED must be true or false" >&2
            return 2
            ;;
    esac
}

function database_bootstrap_if_enabled {
    local status=0

    database_bootstrap_enabled || status=$?
    case "${status}" in
        0)
            "$@"
            ;;
        1)
            return 0
            ;;
        *)
            return "${status}"
            ;;
    esac
}
