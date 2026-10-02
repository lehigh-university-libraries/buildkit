# PHP 8.3

Docker image for [PHP-FPM] version 8.3.

Built from [lehigh-university-libraries/buildkit php83](https://github.com/lehigh-university-libraries/buildkit/tree/main/images/php83)

Acts as the PHP-FPM base Docker image for PHP based services. The Nginx image
extends this image to provide the web server layer.

## Dependencies

Requires `lehighlts/base` Docker image to build. Please refer to the
[Base Image README](../base/README.md) for additional information.

## Settings

> N.B. For all of the settings below images that descend from
> `lehighlts/php` will apply prefix to every setting. So for example
> `PHP_LOG_LEVEL` would become `DRUPAL_PHP_LOG_LEVEL` this is to allow for
> different settings on a per-service basis.

| Environment Variable          | Default  | Description                                                                        |
| :---------------------------- | :------- | :--------------------------------------------------------------------------------- |
| PHP_DEFAULT_SOCKET_TIMEOUT    | 60       | Default timeout for socket based streams (seconds)                                 |
| PHP_LOG_LEVEL                 | notice   | Log level. Possible Values: alert, error, warning, notice, debug                   |
| PHP_LOG_LIMIT                 | 16384    | Log limit on number of characters in the single line                               |
| PHP_MAX_EXECUTION_TIME        | 30       | Maximum execution time of each script, in seconds                                  |
| PHP_MAX_FILE_UPLOADS          | 20       | Maximum number of files that can be uploaded via a single request                  |
| PHP_MAX_INPUT_TIME            | 60       | Maximum amount of time each script may spend parsing request data                  |
| PHP_MEMORY_LIMIT              | 256M     | Maximum amount of memory a script may consume                                      |
| PHP_PM                        | dynamic  | static, dynamic, or ondemand                                                       |
| PHP_PM_MAX_CHILDREN           | 5        | The number of simultaneous requests that will be served                            |
| PHP_PM_START_SERVERS          | 2        | The number of child processes created on startup                                   |
| PHP_PM_MIN_SPARE_SERVERS      | 1        | The desired minimum number of idle server processes (dynamic only)                 |
| PHP_PM_MAX_SPARE_SERVERS      | 3        | The desired maximum number of idle server processes (dynamic only)                 |
| PHP_PM_IDLE_TIMEOUT           | 10s      | The number of seconds after which an idle process will be killed (ondemand only)   |
| PHP_PM_MAX_REQUESTS           | 0        | The number of requests each child process should execute before respawning         |
| PHP_POST_MAX_SIZE             | 128M     | Maximum size of POST data that PHP will accept                                     |
| PHP_PROCESS_CONTROL_TIMEOUT   | 60       | Timeout for child processes to wait for a reaction on signals from master          |
| PHP_REQUEST_TERMINATE_TIMEOUT | 60       | Timeout for serving a single request after which the worker process will be killed |
| PHP_UPLOAD_MAX_FILESIZE       | 128M     | Maximum allowed size for uploaded files                                            |

## Updating

You can change the release used for `composer` by modifying the build argument
`COMPOSER_VERSION` and `COMPOSER_SHA256` in the `Dockerfile` shown as `XXXXXXXXXXXX` in the
following snippet:

```Dockerfile
ARG COMPOSER_VERSION=XXXXXXXXXXXX
#...
ARG COMPOSER_SHA256=XXXXXXXXXXXX
```

[PHP-FPM]: https://www.php.net/manual/en/install.fpm.php
