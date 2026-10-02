#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=images/base/rootfs/usr/local/share/libops/database.sh
source "${LIBOPS_DATABASE_LIBRARY:-/usr/local/share/libops/database.sh}"

: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"

DB_CHARACTER_SET=${DB_CHARACTER_SET:-utf8mb4}
DB_COLLATION=${DB_COLLATION:-utf8mb4_unicode_ci}

database_validate_identifier DB_NAME "${DB_NAME}"
database_validate_identifier DB_USER "${DB_USER}"
database_validate_identifier DB_CHARACTER_SET "${DB_CHARACTER_SET}"
database_validate_identifier DB_COLLATION "${DB_COLLATION}"

db_user_sql=$(database_escape_sql_literal "${DB_USER}")
db_password_sql=$(database_escape_sql_literal "${DB_PASSWORD}")

cat <<-SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET ${DB_CHARACTER_SET} COLLATE ${DB_COLLATION};
CREATE USER IF NOT EXISTS '${db_user_sql}'@'%' IDENTIFIED BY '${db_password_sql}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${db_user_sql}'@'%';
SET PASSWORD FOR '${db_user_sql}'@'%' = PASSWORD('${db_password_sql}');
FLUSH PRIVILEGES;
SQL
