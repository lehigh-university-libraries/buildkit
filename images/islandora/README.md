# Islandora

Docker image for [Drupal].

Built from [lehigh-university-libraries/buildkit islandora](https://github.com/lehigh-university-libraries/buildkit/tree/main/images/islandora)

Acts as base Docker image for Drupal based projects, it doesn't install Drupal
as consumers of this image are expected to provide their own composer file.
Instead it provides startup scripts that allow Drupal to be installed when the
image is first run.

## Dependencies

Requires the matching `lehighlts/drupal` PHP variant to build. Please refer to the
[Drupal Image README](../drupal/README.md) for additional information including
additional settings, volumes, ports, etc.

Includes the dependencies migrated from `docker-builds/drupal`: FFmpeg,
ImageMagick, libvips, Crosswalk, and the PHP SQLite PDO, uploadprogress,
memcache, and xhprof extensions. The extensions match each variant's PHP version.

## Ports

| Port | Description |
| :--- | :---------- |
| 80   | HTTP        |

## Settings

### Network Settings

| Environment Variable     | Default | Description                                                                        |
| :----------------------- | :------ | :--------------------------------------------------------------------------------- |
| INGRESS_HOSTNAMES        | localhost,drupal.internal | Comma-separated hostnames accepted by the application.                           |
| INGRESS_SCHEME           | https   | Inform PHP that `https` should be used when set to `https`.                       |
| DRUPAL_REVERSE_PROXY_IPS |         | Use the IP address for the host 'traefik' if found otherwise default to `0.0.0.0`. |

### Database Settings

[Drupal] can make use of different database backends for storage. Use the base
image `DB_*` settings for the single Islandora site database. Docker secrets are
imported into the container environment before confd renders Drupal settings, so
`DB_PASSWORD` and the other database values are written into the generated
settings include instead of being read by Drupal on each request.

### JWT Settings

[Drupal] is expected to make use of JWT for authentication. Please see the
documentation in the [base image] for more information.

The public/private key pair used here should be the same key as is used in the
derivative service and `fcrepo` based containers.

### Site

| Environment Variable            | Default                 | Description                                        |
| :------------------------------ | :---------------------- | :------------------------------------------------- |
| DRUPAL_DEFAULT_ACCOUNT_EMAIL    | webmaster@localhost.com | The email to use for the admin account             |
| DRUPAL_DEFAULT_ACCOUNT_NAME     | admin                   | The Drupal administrator user                      |
| DRUPAL_DEFAULT_ACCOUNT_PASSWORD |                         | The Drupal administrator password; required when installing a site |
| DRUPAL_DEFAULT_EMAIL            | webmaster@localhost.com | The Drupal administrators email                    |
| DRUPAL_DEFAULT_LOCALE           | en                      | The Drupal sites locale                            |
| DRUPAL_DEFAULT_NAME             | default                 | The Drupal sites name                              |
| DRUPAL_DEFAULT_PROFILE          | standard                | The installation profile to use                    |
| DRUPAL_DEFAULT_SUBDIR           | default                 | The installation profile to use                    |
| DRUPAL_DEFAULT_CONFIGDIR        |                         | Install using existing config files from directory |
| DRUPAL_DEFAULT_INSTALL          | true                    | Perform install if not already installed           |

The image has no administrator password default and fails closed when
`DRUPAL_DEFAULT_INSTALL=true` without an explicit password.

[base image]: ../base/README.md
[Drupal]: https://www.drupal.org/
