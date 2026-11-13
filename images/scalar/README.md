# Scalar runtime configuration

At container startup, the inherited s6 environment setup loads Docker environment
variables and `/run/secrets/NAME` files (secret files take precedence). Confd
renders `database.php`, `config.php`, and `local_settings.php` before PHP-FPM
starts. Generated files are owned by root:nginx with mode 0640; PHP workers can
read them but cannot modify them. The application tree is not a host mount.
Changing values requires recreating the container. Never bake secret values
into an image or commit them in Compose files.

PHP-FPM retains `clear_env = yes` and has no Scalar environment passthrough.
Nginx does not receive database credentials. Settings remain accessible to the
application through its configuration files, so file rendering does not protect
secrets from compromised PHP code or container administrators.

`SCALAR_BASE_URL` sets the canonical site URL (default
`https://scalar.lehigh.edu/`); request Host and forwarding headers cannot change
it. `SCALAR_COOKIE_SECURE` defaults to true. Existing session/database table
prefixes and encryption keys must match the migrated installation. Missing
credentials are empty, with no embedded secret fallback.

## Environment variables consumed by confd

Every application-template input is listed below. An empty value uses the
listed default. Supply secrets privately as environment variables or matching
`/run/secrets/NAME` files; secret files take precedence.

### Database

Rendered into `database.php`.

| Variable | Default |
| --- | --- |
| `SCALAR_ARC_DB_PREFIX` | `scalar_store_` |
| `SCALAR_DB_CHARSET` | `utf8` |
| `SCALAR_DB_COLLATION` | `utf8_general_ci` |
| `SCALAR_DB_DATABASE` | empty |
| `SCALAR_DB_HOSTNAME` | `127.0.0.1` |
| `SCALAR_DB_PASSWORD` | empty |
| `SCALAR_DB_PORT` | `3306` |
| `SCALAR_DB_PREFIX` | `scalar_db_` |
| `SCALAR_DB_STRICT` | `false` |
| `SCALAR_DB_USERNAME` | empty |

### Core application, sessions, cookies, and logging

Rendered into `config.php`.

| Variable | Default |
| --- | --- |
| `MEDIA_URL` | empty |
| `SCALAR_BASE_URL` | `https://scalar.lehigh.edu` |
| `SCALAR_COOKIE_DOMAIN` | empty |
| `SCALAR_COOKIE_PATH` | `/` |
| `SCALAR_COOKIE_PREFIX` | empty |
| `SCALAR_COOKIE_SECURE` | `true` |
| `SCALAR_CSRF_COOKIE_NAME` | `csrf_cookie_name` |
| `SCALAR_CSRF_EXPIRATION` | `7200` |
| `SCALAR_CSRF_PROTECTION` | `false` |
| `SCALAR_CSRF_TOKEN_NAME` | `csrf_test_name` |
| `SCALAR_ENCRYPTION_KEY` | empty |
| `SCALAR_LANGUAGE` | `en` |
| `SCALAR_LOG_DATE_FORMAT` | `Y-m-d H:i:s` |
| `SCALAR_LOG_THRESHOLD` | `1` |
| `SCALAR_PHP_ERROR_REPORTING` | `32767` (all PHP severities) |
| `SCALAR_PROXY_IPS` | empty |
| `SCALAR_SESSION_COOKIE_NAME` | `ci_session` |
| `SCALAR_SESSION_EXPIRATION` | `14400` |
| `SCALAR_SESSION_EXPIRE_ON_CLOSE` | `false` |
| `SCALAR_SESSION_MATCH_IP` | `false` |
| `SCALAR_SESSION_MATCH_USERAGENT` | `true` |
| `SCALAR_SESSION_TABLE_NAME` | `scalar_db_sessions` |
| `SCALAR_SESSION_UPDATE_INTERVAL` | `300` |
| `SCALAR_TIME_REFERENCE` | `local` |

### Site, authentication, mail, and provider integrations

Rendered into `local_settings.php`.

| Variable | Default |
| --- | --- |
| `HAM_API_KEY` | empty |
| `SCALAR_ACTIVE_BOOK_LIST` | `book_list` |
| `SCALAR_ACTIVE_COVER` | `cover` |
| `SCALAR_ACTIVE_DASHBOARD` | `dashboard` |
| `SCALAR_ACTIVE_MELON` | `cantaloupe` |
| `SCALAR_AD_BIND_PASS` | empty |
| `SCALAR_AD_BIND_USER` | empty |
| `SCALAR_BOOK_MESSAGE` | empty |
| `SCALAR_BOOK_MESSAGE_COOKIE_NAME` | `ci_hide_scalar_book_msg` |
| `SCALAR_DEFAULT_STYLESHEET` | `minimal` |
| `SCALAR_DIRECTORY_MODE` | `0775` |
| `SCALAR_DPLA_KEY` | empty |
| `SCALAR_EMAIL_FROM_ADDRESS` | empty |
| `SCALAR_EMAIL_REPLYTO_ADDRESS` | empty |
| `SCALAR_EMAIL_REPLYTO_NAME` | empty |
| `SCALAR_EXTERNAL_DIRECT_HYPERLINK` | `false` |
| `SCALAR_FILE_MODE` | `0664` |
| `SCALAR_FLOWPLAYER_KEY` | empty |
| `SCALAR_GOOGLE_AUTHENTICATOR_SALT` | empty |
| `SCALAR_GOOGLE_MAPS_KEY` | empty |
| `SCALAR_IFRAME_REDLIST` | `youtube.com,vimeo.com,google.com,microsoft.com,metmuseum.org,bloomberg.com,nytimes.com,nationalreview.com,theguardian.com,twitter.com` |
| `SCALAR_INDEX_HIDE_PUBLISHED` | `true` |
| `SCALAR_INDEX_MESSAGE` | empty |
| `SCALAR_INDEX_RENDER_PUBLISHED` | `true` |
| `SCALAR_LDAP_BASEDN` | empty |
| `SCALAR_LDAP_EMAIL_DOMAIN` | empty |
| `SCALAR_LDAP_FILTER` | empty |
| `SCALAR_LDAP_OBJECT_CLASS` | `user` |
| `SCALAR_LDAP_PORT` | `389` |
| `SCALAR_LDAP_SERVER` | empty |
| `SCALAR_LDAP_UNAME_FIELD` | `uid` |
| `SCALAR_LOGIN_PENALTY_SECONDS` | `120` |
| `SCALAR_MAX_LOGIN_ATTEMPTS` | `6` |
| `SCALAR_NYPL_KEY` | empty |
| `SCALAR_PASSWORD_RESET_DAYS` | `60` |
| `SCALAR_PRIVACY_POLICY` | empty |
| `SCALAR_RECAPTCHA_PRIVATE_KEY` | empty |
| `SCALAR_RECAPTCHA_PUBLIC_KEY` | empty |
| `SCALAR_RECAPTCHA2_SECRET_KEY` | empty |
| `SCALAR_RECAPTCHA2_SITE_KEY` | empty |
| `SCALAR_REGISTER_KEYS` | empty |
| `SCALAR_REGISTRATION_KEY_MESSAGE` | empty |
| `SCALAR_SET_LDAP_REFERRALS` | empty |
| `SCALAR_SHASALT` | empty |
| `SCALAR_SMTP_AUTH` | `true` |
| `SCALAR_SMTP_HOST` | empty |
| `SCALAR_SMTP_PASSWORD` | empty |
| `SCALAR_SMTP_PORT` | `465` |
| `SCALAR_SMTP_SECURE` | `ssl` |
| `SCALAR_SMTP_USERNAME` | empty |
| `SCALAR_SOUNDCLOUD_ID` | empty |
| `SCALAR_STRONG_PASSWORD` | `false` |
| `SCALAR_TERMS_OF_SERVICE` | empty |
| `SCALAR_USE_AD_LDAP` | `false` |
| `SCALAR_USE_LDAP` | `false` |
| `SCALAR_USER_HISTORY_MAX_RECORDS` | `20` |
| `SCALAR_YOUTUBE_DATA_KEY` | empty |

`SCALAR_REGISTER_KEYS` and `SCALAR_IFRAME_REDLIST` are comma-separated lists.
The current upstream LDAP keys are `ldap_email_domain` and `ldap_object_class`;
set `SCALAR_LDAP_EMAIL_DOMAIN=lehigh.edu` and
`SCALAR_LDAP_OBJECT_CLASS=person` to preserve the legacy Lehigh restrictions.
Supply the approved LDAP URI and base DN explicitly.

CodeIgniter application messages, PHP errors, and PHP-FPM worker output go to
stderr. Nginx access logs go to stdout; Nginx errors go to stderr.
`SCALAR_CSRF_PROTECTION` retains upstream false by default; enable it only
after testing editor/API forms.

Boolean values use `true`/`false`; numeric values use decimal except upload
modes. Do not change database/table prefixes or session salts during migration
without migrating their data. `log_threshold=0` disables application logs.
The image does not enable arbitrary PHP config overrides from book storage.

## Upstream baseline

The image bundles upstream master commit
[`daf68e2cca8e89d5c39d52ac606dd129e880bf0d`](https://github.com/anvc/scalar/commit/daf68e2cca8e89d5c39d52ac606dd129e880bf0d),
verified on 2026-11-13. Upstream identifies this snapshot as **2.6.12**; it is
not a tagged 2.6.12 release. The source archive has a pinned SHA256 checksum.
`/usr/share/scalar-version` and `/usr/share/scalar-revision` record both values.
The build rejects a source version that differs from `SOFTWARE_VERSION`.

Renovate follows master's commit digest and recalculates the archive checksum.
When updating the pin, review upstream's `scalar-version.php`, update
`SOFTWARE_VERSION` if needed, and refresh the version/revision and active config
keys in `tests/RuntimeConfiguration/upstream-keys.json`. Commented configuration
examples are not active defaults. Tests require this review even when upstream
keeps the same version number. Patches apply with zero fuzz; an upstream change
that makes a patch obsolete must be reviewed rather than silently skipped.

### Compatibility patches and upstream contributions

Each patch in `patches/` is rebased directly against the pinned upstream source:

| Patch | Purpose |
|---|---|
| `272-ldap.patch` | Remaining LDAP domain/object-class support, filter escaping, and URI-based connection API. Master already supplies boolean parsing, LDAPS handling, and failed-search handling. |
| `asset-paths.patch` | Generate public asset URLs when application code and writable book data have separate filesystem roots. |
| `mcrypt-properties.patch` | Declare compatibility-layer state instead of creating deprecated dynamic properties. |
| `rdf-hostname.patch` | Preserve a database hostname when the port is supplied separately. |
| `dashboard-book-id.patch` | Normalize invalid dashboard IDs, bind image-query IDs, and prevent invalid IDs in tab links. |
| `php-deprecations.patch` | Preserve the legacy strict-error category without referencing the deprecated PHP constant. Master's null-JSON fix is used directly. |
| `rdfa-optional-fields.patch` | Render optional RDFa fields without undefined-property warnings. |
| `arc2-xml-callables.patch` | Register direct XML method callbacks in all four ARC2 XML parsers for PHP 8.4. |

The mcrypt and XML parser changes affect bundled third-party libraries; they
should also be considered for their upstream projects. The other compatibility
fixes belong in Scalar. The regression fixtures in `tests/Routing/` exercise
these changes independently of production credentials or external services.

Container-specific confd rendering, stderr logging, canonical origin, file
permissions, and Nginx buffers remain in `rootfs/`, separate from upstream
compatibility patches. No upstream PRs have been opened by this change.

### PHP log severity

`SCALAR_PHP_ERROR_REPORTING` accepts a numeric PHP error-reporting bitmask.
Use `4437` for fatal/error categories (`E_ERROR`, `E_PARSE`, `E_CORE_ERROR`,
`E_COMPILE_ERROR`, `E_USER_ERROR`, `E_RECOVERABLE_ERROR`), or `32767` to include
warnings, notices, and deprecations. `0` disables PHP error logging through
Scalar's error handler. The mask applies to native PHP reporting and
CodeIgniter's PHP-error logger; application messages such as login events still
follow `SCALAR_LOG_THRESHOLD`. Logs continue to go to stderr. The deployment
Compose defaults to `4437`; the image defaults to `32767`. Recreate Scalar after
changing the setting. This requires an image built with the severity-filter
support; PHP-FPM does not read application environment variables directly.
