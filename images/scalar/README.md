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

Verified on 2026-11-12 against the latest release,
[anvc/scalar v2.6.10](https://github.com/anvc/scalar/releases/tag/v2.6.10).
The source files are `system/application/config/{database,config,local_settings}.php`
in that release. `database.php` and `config.php` are identical on upstream
master `daf68e2cca8e89d5c39d52ac606dd129e880bf0d`; the only local-settings
changes there are the LDAP boolean fixes already backported in this image.
The RuntimeConfiguration test inventories every upstream setting and requires
an explicit baseline review when the bundled application version changes.
