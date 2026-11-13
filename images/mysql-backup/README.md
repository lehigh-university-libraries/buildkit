# MySQL and MariaDB backup copies

Backup runtime derived from `base`, using its pinned MariaDB dump client for
MySQL/MariaDB application databases. No application is bundled; release metadata
uses the branch fallback (`main`), not an invented upstream software version.
Publish through the normal Buildkit pipeline and pin the resulting digest in
consumer deployments.

Set `DB_HOST`, `DB_PORT` (default 3306), `DB_USER`, `DB_NAME`, and `DB_PASSWORD`
(prefer a Compose secret at `/run/secrets/DB_PASSWORD`). The scoped application
user needs SELECT, SHOW VIEW, and TRIGGER privileges for its database. Dumps
include triggers; routines and events are outside this application's backup scope.

Mount `/db` to a persistent directory. `BACKUP_CRON` defaults to `0 2 * * *`
(UTC). There is no startup dump; run `/command/with-contenv mysql-backup.sh`
with `docker compose exec db-backup` for an immediate copy. Failures go to stderr
and the next scheduled job retries. Monitor job logs and backup age.

Each successful job atomically writes `daily/YYYY-MM-DD.sql.gz`, then updates
`monthly/YYYY-MM.sql.gz` using a hard link. The monthly copy becomes the last
successful dump of that month. Keep seven UTC daily dates, twelve completed
calendar months, and the current month's latest copy. Missed jobs do not create
snapshots. Cleanup only touches matching SQL filenames in these two directories,
and only follows successful dumping/compression. Files are private (0600), jobs
are locked against overlap, and failed jobs leave existing copies intact.

SET backs up Galera every 30 days. These are additional LOCKSS (Lots of Copies
Keep Stuff Safe) copies, not a backup of uploaded files or other volumes. Existing
backups from other tools are preserved and need separate retention management.

`--single-transaction` provides a consistent snapshot for transactional tables.
Avoid concurrent DDL; nontransactional tables require coordinated write downtime.
The MariaDB client adds a sandbox directive; use a compatible MariaDB client to
restore. Validate recovery into an isolated database server before relying on it:

```sh
gzip -dc backups/daily/YYYY-MM-DD.sql.gz | mariadb -h ISOLATED_HOST -u RESTORE_USER -p
```

The dump contains CREATE DATABASE/USE for `DB_NAME`; never run this verification
against production. Use a protected client option file or interactive password
handling for automated restores. Run the image's `Backup` (MySQL 8.4) and `MariaDB` (MariaDB 11.8) tests
for dump/restore using scoped backup credentials, retention, and failed-dump coverage.
The same image and settings support both servers; no engine selector is needed.
