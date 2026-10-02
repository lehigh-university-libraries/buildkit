#!/usr/bin/env bash
set -e

s6-svwait -U /run/service/fpm
test -S /run/php-fpm/php-fpm.sock
command -v php
php -v
composer --version
test "${COMPOSER_ALLOW_SUPERUSER}" = "1"
test "${COMPOSER_MEMORY_LIMIT}" = "-1"
