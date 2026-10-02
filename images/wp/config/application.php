<?php

$root_dir = dirname(__DIR__);
$webroot_dir = $root_dir . '/web';

require __DIR__ . '/libops-runtime.php';

define('WP_CONTENT_DIR', $webroot_dir . '/app');
define('WP_CONTENT_URL', WP_HOME . '/app');
define('FS_METHOD', 'direct');
define('DISALLOW_FILE_EDIT', true);
define('AUTOMATIC_UPDATER_DISABLED', true);

define('WP_DEBUG', WP_ENV !== 'production');
define('WP_DEBUG_LOG', WP_ENV !== 'production');
define('WP_DEBUG_DISPLAY', false);

if (
    isset($_SERVER['HTTP_X_FORWARDED_PROTO']) &&
    $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https'
) {
    $_SERVER['HTTPS'] = 'on';
}

if (!defined('ABSPATH')) {
    define('ABSPATH', $webroot_dir . '/wp/');
}
