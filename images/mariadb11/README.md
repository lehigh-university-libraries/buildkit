# MariaDB 11

Docker image for [MariaDB] version 11.8.8.

Built from [lehigh-university-libraries/buildkit mariadb11](https://github.com/lehigh-university-libraries/buildkit/tree/main/images/mariadb11)

Please refer to the [MariaDB Documentation] for more in-depth information.

As a quick example this will generate a root password, bring up MariaDB, and
connect as `root` using that generated credential.

```bash
export DB_ROOT_PASSWORD="$(openssl rand -hex 32)"
docker run --rm -d --name mariadb \
  --env DB_ROOT_PASSWORD \
  lehighlts/mariadb:11
docker exec -ti --env MYSQL_PWD="${DB_ROOT_PASSWORD}" mariadb mariadb -u root
```

## Dependencies

Requires `lehighlts/base` Docker image to build. Please refer to the
[Base Image README](../base/README.md) for additional information.

## Ports

| Port | Description       |
| :--- | :---------------- |
| 3306 | MySQL Client Port |

## Volumes

| Path                 | Description                                    |
| :------------------- | :--------------------------------------------- |
| /var/lib/mysql       | Database files                                 |
| /var/lib/mysql-files | Location to import databases via CSV/SQL files |

## Settings

### Database Settings

Please see the documentation in the [base image] for more information about the
default database connection configuration.

| Environment Variable | Default | Description                                                                           |
| :------------------- | :------ | :------------------------------------------------------------------------------------ |
| DB_ROOT_PASSWORD     |         | The database root password; required at startup                                       |
| DB_ROOT_USER         | root    | The database root user                                                                |
| DB_NAME              | default | Optional scoped database to create when `DB_PASSWORD` is set                          |
| DB_USER              | default | Optional scoped database user to create when `DB_PASSWORD` is set                     |
| DB_PASSWORD          |         | Scoped user password; leave empty when provisioning through a separate initializer     |
| MYSQL_MAX_ALLOWED_PACKET | 16777216 | Max packet length to send to or receive from the server, [documentation](https://mariadb.com/docs/server/ref/mdb/system-variables/max_allowed_packet/)
| MYSQL_TRANSACTION_ISOLATION | READ-COMMITTED | The isolation level for transactions.

## Logs

| Path   | Description   |
| :----- | :------------ |
| STDOUT | [MariaDB Log] |

[base image]: ../base/README.md
[MariaDB Documentation]: https://mariadb.org/documentation/
[MariaDB]: https://mariadb.org/
