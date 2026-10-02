#!/command/with-contenv bash
# shellcheck shell=bash
set -e

# shellcheck disable=SC1091
source /usr/local/share/libops/database.sh
# shellcheck disable=SC1091
source /usr/local/share/libops/environment.sh

# Never initialize a network-accessible root account with empty credentials.
database_require_root_credentials

# A scoped database can be provisioned by the database container for isolated
# tests or simple deployments. Production templates use a dedicated one-shot
# initializer and therefore do not pass DB_PASSWORD to this service.
bootstrap_sql=
if [ -n "${DB_PASSWORD:-}" ]; then
    require_environment_variables DB_NAME DB_USER
    bootstrap_sql=$(render-database-bootstrap-sql.sh)
fi

# Make run directory if it does not exist.
mkdir /run/mysqld &>/dev/null || true
chown mysql:mysql /run/mysqld

# Create the database if it does not exist.
if [[ ! -d "/var/lib/mysql/mysql" ]]; then
    s6-setuidgid mysql mariadb-install-db --basedir=/usr --datadir=/var/lib/mysql --skip-test-db --user mysql
fi

# Startup the database so we can change the root users password.
s6-setuidgid mysql /usr/bin/mariadbd --skip-networking &
MYSQLD_PID=$!

# Wait for it to startup.
until mariadb --no-defaults --protocol=socket --user="${DB_ROOT_USER}" -e "SELECT 1" &>/dev/null; do
    sleep 1
done

# Change the root users password.
echo "Changing the root users (${DB_ROOT_USER}) password."
database_validate_identifier DB_ROOT_USER "${DB_ROOT_USER}"
db_root_user_sql=$(database_escape_sql_literal "${DB_ROOT_USER}")
db_root_password_sql=$(database_escape_sql_literal "${DB_ROOT_PASSWORD}")
cat <<-EOF | mariadb --no-defaults --protocol=socket --user="${DB_ROOT_USER}"
	CREATE USER IF NOT EXISTS '${db_root_user_sql}'@'%';
	GRANT ALL PRIVILEGES ON *.* TO '${db_root_user_sql}'@'%' WITH GRANT OPTION;
	SET PASSWORD FOR '${db_root_user_sql}'@'localhost' = PASSWORD('${db_root_password_sql}');
	SET PASSWORD FOR '${db_root_user_sql}'@'%' = PASSWORD('${db_root_password_sql}');
	FLUSH PRIVILEGES;
	${bootstrap_sql}
EOF

# Stop the database.
kill -s TERM "${MYSQLD_PID}"

# Allow database to stop.
wait
