<?php
// Exercise generated settings through PHP-FPM, not its CLI environment.
define('BASEPATH', '/usr/local/share/scalar/system/');
define('APPPATH', BASEPATH . 'application/');
require APPPATH . 'config/config.php';
require APPPATH . 'config/local_settings.php';
require APPPATH . 'config/database.php';
function check($condition, $message) {
    if (!$condition) {
        http_response_code(500);
        exit($message);
    }
}
$baseline = json_decode(file_get_contents('/upstream-keys.json'), true);
check(trim(file_get_contents('/usr/share/scalar-version')) === $baseline['version'], 'Review templates against the new upstream release');
foreach ($baseline['files'] as $file => $keys) {
    foreach ($keys as $key) {
        check(array_key_exists($key, $file === 'database.php' ? $db['default'] : $config), 'Missing upstream setting: ' . $key);
    }
    check(strpos(file_get_contents(APPPATH . 'config/' . $file), 'getenv(') === false, 'Unrendered runtime environment lookup');
    check((fileperms(APPPATH . 'config/' . $file) & 0777) === 0640, 'Wrong config permissions');
    check(fileowner(APPPATH . 'config/' . $file) === 0, 'Config must be root-owned');
    check(!is_writable(APPPATH . 'config/' . $file), 'Worker can overwrite config');
}
check($db['default']['password'] === file_get_contents('/expected-password'), 'Secret precedence or PHP escaping failed');
check($db['default']['hostname'] === 'config-db.invalid' && $db['default']['port'] === 3307, 'Database options were not rendered');
check($db['default']['username'] === 'test-user' && $db['default']['database'] === 'test-db', 'Database account was not rendered');
check($config['encryption_key'] === "encrypt'back\\slash\$literal", 'Encryption key escaping failed');
check($config['base_url'] === 'https://scalar.example.edu/books/', 'Canonical URL depends on request headers');
check($config['cookie_secure'] === true && $config['sess_expiration'] === 900, 'Cookie/session configuration failed');
check($config['use_ldap'] === false && $config['use_ad_ldap'] === false && $config['strong_password'] === false, 'False was treated as true');
check($config['set_ldap_referrals'] === 0, 'LDAP zero was not preserved');
check($config['ldap_email_domain'] === 'example.edu' && $config['ldap_object_class'] === 'person', 'LDAP settings failed');
check($config['smtp_port'] === 587 && $config['smtp_secure'] === 'tls', 'SMTP options failed');
check($config['register_key'] === array('first', 'second'), 'Registration keys failed');
foreach (array('SCALAR_DB_PASSWORD', 'SCALAR_DB_HOSTNAME', 'SCALAR_ENCRYPTION_KEY', 'SCALAR_SHASALT') as $name) {
    check(getenv($name) === false, 'Worker inherited application environment');
}
check(ini_get('display_errors') === '' || ini_get('display_errors') === '0', 'PHP error display enabled');
check(ini_get('error_log') === '/proc/self/fd/2', 'PHP errors are not sent to stderr');
function &get_config() { global $config; return $config; }
require BASEPATH . 'libraries/Log.php';
require APPPATH . 'libraries/MY_Log.php';
$logger = new MY_Log();
check($logger->write_log('error', 'scalar-application-stderr-probe'), 'Application logging failed');
check($logger->write_log('debug', 'scalar-debug-stderr-probe'), 'Configured logging threshold ignored');
check(!$logger->write_log('info', 'must-not-log-info'), 'Log threshold not enforced');
error_log('scalar-php-stderr-probe');
echo 'runtime-config-ok';
