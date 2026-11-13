#!/usr/bin/env bash
set -euo pipefail
umask 077
: "${DB_HOST:?Set DB_HOST}" "${DB_USER:?Set DB_USER}" "${DB_NAME:?Set DB_NAME}"
[[ "$DB_NAME" != -* ]] || { echo 'DB_NAME cannot start with -' >&2; exit 1; }
backup_dir=${BACKUP_DIR:-/db}
mkdir -p "$backup_dir"
exec 9>"$backup_dir/.lock"
flock -n 9 || { echo 'Backup already running' >&2; exit 1; }
mkdir -p "$backup_dir/daily" "$backup_dir/monthly"
now=$(date -u +%s)
day=$(date -u -d "@$now" +%F)
month=${day:0:7}
# Keep today and the previous six UTC dates.
cutoff=$(date -u -d "@$((now - 6 * 86400))" +%F)
year=${month:0:4}
month_number=${month:5:2}
# Previous twelve completed months, plus the current month's latest dump.
monthly_cutoff=$(printf '%04d-%02d' "$((10#$year - 1))" "$((10#$month_number))")
password=${DB_PASSWORD:-}
if [[ -f /run/secrets/DB_PASSWORD ]]; then password=$(cat /run/secrets/DB_PASSWORD); fi
export MYSQL_PWD=$password
unset password
partial=$(mktemp "$backup_dir/daily/.partial.XXXXXX")
monthly_tmp="$backup_dir/monthly/.latest.$$"
trap 'rm -f -- "$partial" "$monthly_tmp"' EXIT
# Transactional tables only; avoid concurrent DDL during the dump.
mariadb-dump --host="$DB_HOST" --port="${DB_PORT:-3306}" --user="$DB_USER" \
    --single-transaction --quick --skip-lock-tables --no-tablespaces \
    --hex-blob --triggers --databases "$DB_NAME" | gzip > "$partial"
gzip -t "$partial"
mv -f -- "$partial" "$backup_dir/daily/$day.sql.gz"
# Hard links share storage; rename preserves the previous monthly dump on failure.
ln -- "$backup_dir/daily/$day.sql.gz" "$monthly_tmp"
mv -f -- "$monthly_tmp" "$backup_dir/monthly/$month.sql.gz"
shopt -s nullglob
for file in "$backup_dir"/daily/*.sql.gz; do
    name=${file##*/}; stamp=${name%.sql.gz}
    if [[ $stamp =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && $stamp < $cutoff ]]; then rm -- "$file"; fi
done
for file in "$backup_dir"/monthly/*.sql.gz; do
    name=${file##*/}; stamp=${name%.sql.gz}
    if [[ $stamp =~ ^[0-9]{4}-[0-9]{2}$ && $stamp < $monthly_cutoff ]]; then rm -- "$file"; fi
done
printf 'Database backup completed: %s\n' "$day"
