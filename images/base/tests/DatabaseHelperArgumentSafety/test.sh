#!/command/with-contenv bash
# shellcheck shell=bash

set -euo pipefail

stub_dir="$(mktemp -d)"
capture="$(mktemp)"
marker=/tmp/database-helper-injected
# shellcheck disable=SC2016 # Literal command substitution is an injection payload.
password='space "$(touch /tmp/database-helper-injected)" quote'"'"' semicolon; back\slash end'

cleanup() {
    rm -rf "${stub_dir}" "${capture}" "${marker}"
}
trap cleanup EXIT

cat >"${stub_dir}/mariadb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for argument in "$@"; do
    if [[ "${argument}" == --password* ]]; then
        echo "Password was exposed in MariaDB argv" >&2
        exit 1
    fi
    if [[ "${argument}" == --defaults-extra-file=* ]]; then
        defaults_file=${argument#*=}
        test -r "${defaults_file}"
        test "$(stat -c '%a' "${defaults_file}")" = 600
    fi
done
printf '%s\n' "$@" >>"${DATABASE_HELPER_CAPTURE:?}"
EOF

cat >"${stub_dir}/wait-for-open-port.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"${stub_dir}/wget" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
destination=
url=${!#}
while (($# > 0)); do
    case "$1" in
        -P) destination=$2; shift 2 ;;
        *) shift ;;
    esac
done
printf '%s' "${url}" >"${DOWNLOAD_ARGUMENT_CAPTURE:?}"
mkdir -p "${destination}"
: >"${destination}/$(basename "${url}")"
EOF

cat >"${stub_dir}/nc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"${PORT_ARGUMENT_CAPTURE:?}"
EOF

cat >"${stub_dir}/confd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"${CONFD_ARGUMENT_CAPTURE:?}"
EOF

chmod +x "${stub_dir}/mariadb" "${stub_dir}/wait-for-open-port.sh" \
    "${stub_dir}/wget" "${stub_dir}/nc" "${stub_dir}/confd"
export DATABASE_HELPER_CAPTURE="${capture}"
export PATH="${stub_dir}:${PATH}"
export LIBOPS_DATABASE_LIBRARY=${LIBOPS_DATABASE_LIBRARY:-/usr/local/share/libops/database.sh}
export LIBOPS_BIN_DIRECTORY=${LIBOPS_BIN_DIRECTORY:-/usr/local/bin}
# shellcheck disable=SC1090
source "${LIBOPS_DATABASE_LIBRARY}"
# shellcheck disable=SC1090
source "${LIBOPS_ENVIRONMENT_LIBRARY:-/usr/local/share/libops/environment.sh}"

client_defaults_file=$(mktemp)
database_write_client_defaults_file "${client_defaults_file}" "${password}"
test "$(stat -c '%a' "${client_defaults_file}")" = 600
expected_client_defaults=$(cat <<'EOF'
[client]
password="space \"$(touch /tmp/database-helper-injected)\" quote' semicolon; back\\slash end"
EOF
)
test "$(cat "${client_defaults_file}")" = "${expected_client_defaults}"
rm -f "${client_defaults_file}"

if REQUIRED_TEST_VALUE='' require_environment_variables REQUIRED_TEST_VALUE 2>/dev/null; then
    echo "Empty required environment value was accepted" >&2
    exit 1
fi
REQUIRED_TEST_VALUE=present require_environment_variables REQUIRED_TEST_VALUE

if DB_ROOT_USER=root DB_ROOT_PASSWORD='' database_require_root_credentials 2>/dev/null; then
    echo "Empty database root password was accepted" >&2
    exit 1
fi
if DB_ROOT_USER='' DB_ROOT_PASSWORD=root database_require_root_credentials 2>/dev/null; then
    echo "Empty database root user was accepted" >&2
    exit 1
fi

bootstrap_marker="${stub_dir}/bootstrap-called"
export DB_ROOT_USER=root
record_bootstrap() {
    touch "${bootstrap_marker}"
}

DB_BOOTSTRAP_ENABLED=false \
    DB_ROOT_PASSWORD=password \
    database_bootstrap_if_enabled record_bootstrap
test ! -e "${bootstrap_marker}"

if DB_BOOTSTRAP_ENABLED=true \
    DB_ROOT_PASSWORD='' \
    database_bootstrap_if_enabled record_bootstrap 2>/dev/null; then
    echo "Database bootstrap accepted an empty root password" >&2
    exit 1
fi
test ! -e "${bootstrap_marker}"

if DB_BOOTSTRAP_ENABLED=invalid \
    DB_ROOT_PASSWORD=root \
    database_bootstrap_if_enabled record_bootstrap 2>/dev/null; then
    echo "Database bootstrap accepted an invalid enable flag" >&2
    exit 1
fi
test ! -e "${bootstrap_marker}"

DB_BOOTSTRAP_ENABLED=true \
    DB_ROOT_PASSWORD=root \
    database_bootstrap_if_enabled record_bootstrap
test -e "${bootstrap_marker}"
rm "${bootstrap_marker}"

# shellcheck disable=SC2016 # Literal command substitution is an injection payload.
malicious_argument='space "$(touch /tmp/database-helper-injected)" quote'"'"' and back\slash'
download_capture="${stub_dir}/download-argument"
port_capture="${stub_dir}/port-argument"
confd_capture="${stub_dir}/confd-argument"
export DOWNLOAD_ARGUMENT_CAPTURE="${download_capture}"
export PORT_ARGUMENT_CAPTURE="${port_capture}"
export CONFD_ARGUMENT_CAPTURE="${confd_capture}"

DOWNLOAD_CACHE_DIRECTORY="${stub_dir}/downloads" \
    download.sh \
    --url "https://example.invalid/${malicious_argument}" \
    --sha256 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
test "$(cat "${download_capture}")" = "https://example.invalid/${malicious_argument}"

"${LIBOPS_BIN_DIRECTORY}/wait-for-open-port.sh" "${malicious_argument}" "33 06"
mapfile -t port_args <"${port_capture}"
test "${port_args[2]}" = "${malicious_argument}"
test "${port_args[3]}" = "33 06"

CONFD_LOG_LEVEL=error confd-render-templates.sh -- -config-file "${malicious_argument}"
mapfile -t confd_args <"${confd_capture}"
test "${confd_args[5]}" = "${malicious_argument}"

for helper in create-service-user.sh cleanup.sh confd-import-environment.sh; do
    "${helper}" --help "${malicious_argument}" >/dev/null
done
test ! -e "${marker}"

sql=$(
    DB_NAME="database_name" \
        DB_USER="database_user" \
        DB_PASSWORD="${password}" \
        render-database-bootstrap-sql.sh
)
expected_sql=$(cat <<'EOF'
CREATE DATABASE IF NOT EXISTS `database_name` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'database_user'@'%' IDENTIFIED BY 'space "$(touch /tmp/database-helper-injected)" quote'' semicolon; back\\slash end';
GRANT ALL PRIVILEGES ON `database_name`.* TO 'database_user'@'%';
SET PASSWORD FOR 'database_user'@'%' = PASSWORD('space "$(touch /tmp/database-helper-injected)" quote'' semicolon; back\\slash end');
FLUSH PRIVILEGES;
EOF
)
test "${sql}" = "${expected_sql}"

if DB_NAME="invalid-name" \
    DB_USER="database_user" \
    DB_PASSWORD="${password}" \
    render-database-bootstrap-sql.sh >/dev/null 2>&1; then
    echo "Invalid database identifier was accepted" >&2
    exit 1
fi

wait-for-database.sh \
    --host "database host" \
    --port 3306 \
    --user "database user" \
    --password "${password}" \
    --timeout 1

grep -Fqx -- "--host=database host" "${capture}"
grep -Fqx -- "--user=database user" "${capture}"
if grep -Eq '^--password(=|$)' "${capture}"; then
    echo "Database password was exposed in client argv" >&2
    exit 1
fi

printf 'SELECT 1;\n' | execute-sql-file.sh \
    --host "database host" \
    --port 3306 \
    --user "database user" \
    --password "${password}" \
    --database "database name" \
    -- - --skip-column-names

grep -Fqx -- "--database=database name" "${capture}"
grep -Fqx -- "--skip-column-names" "${capture}"

# A lone dash is also the documented FILE argument and must not be rejected as
# an unknown option when callers do not use an option delimiter before it.
printf 'SELECT 1;\n' | execute-sql-file.sh \
    --host "database host" \
    --port 3306 \
    --user "database user" \
    --password "${password}" \
    --database "database name" \
    - -- --batch

grep -Fqx -- "--batch" "${capture}"

printf 'SELECT 1;\n' | \
    DB_HOST="database host" \
    DB_PORT=3306 \
    DB_NAME="database name" \
    DB_ROOT_USER="database user" \
    DB_ROOT_PASSWORD="${password}" \
    create-database.sh

if grep -Eq '^--password(=|$)' "${capture}"; then
    echo "Database password was exposed in client argv" >&2
    exit 1
fi
test ! -e "${marker}"
