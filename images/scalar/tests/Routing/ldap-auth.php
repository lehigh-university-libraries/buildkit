<?php
namespace ScalarLdapTest;
// Run with: php -n tests/ldap-auth.php (LDAP calls are stubbed; no server required).
const LDAP_ESCAPE_FILTER = 1;
const LDAP_OPT_PROTOCOL_VERSION = 17;
const LDAP_OPT_REFERRALS = 8;
class MY_Model { public $config; public function __construct() {} }
class TestConfig {
    public $values;
    public function __construct($values) { $this->values = $values; }
    public function item($name) { return $this->values[$name] ?? null; }
}
function ldap_escape($value, $ignore = '', $flags = 0) {
    return strtr($value, ["\\" => '\\5c', '*' => '\\2a', '(' => '\\28', ')' => '\\29', "\0" => '\\00']);
}
function ldap_connect($uri) { $GLOBALS['uri'] = $uri; return true; }
function ldap_set_option(...$args) { return true; }
function ldap_start_tls($connection) { $GLOBALS['starttls'] = true; return true; }
function ldap_search($connection, $base, $filter) { $GLOBALS['filter'] = $filter; return true; }
function ldap_get_entries($connection, $search) { return ['count' => 0]; }
// Load the bundled model in this namespace so LDAP calls use the stubs.
$reporting = error_reporting(error_reporting() & ~E_DEPRECATED);
try {
    eval('namespace ' . __NAMESPACE__ . '; ?>' . file_get_contents('/usr/local/share/scalar/system/application/models/user_model.php'));
} finally {
    error_reporting($reporting);
}
function check($condition, $message) { if (!$condition) { fwrite(STDERR, "$message\n"); exit(1); } }
$model = new User_model();
$model->config = new TestConfig([
    'ldap_server' => 'ldaps://directory.example', 'ldap_port' => 636,
    'ldap_email_domain' => 'example.edu', 'ldap_object_class' => 'person',
    'ldap_uname_field' => 'uid', 'ldap_filter' => '(enabled=true)',
]);
check($model->get_from_ldap_by_email_and_password('name@wrong.edu', 'password') === false, 'Wrong domain accepted');
check(!isset($GLOBALS['uri']), 'Connected for rejected domain');
check($model->get_from_ldap_by_email_and_password('bad-email', 'password') === false, 'Malformed email accepted');
$model->get_from_ldap_by_email_and_password('a*)(uid=*)@EXAMPLE.EDU', 'password');
check($GLOBALS['uri'] === 'ldaps://directory.example:636', 'Wrong LDAPS URI');
check(!isset($GLOBALS['starttls']), 'StartTLS used with LDAPS');
check($GLOBALS['filter'] === '(&(objectClass=person)(uid=a\\2a\\29\\28uid=\\2a\\29)(enabled=true))', 'LDAP filter was not escaped');
$model->config->values['ldap_server'] = 'ldap://directory.example:1389';
$model->get_from_ldap_by_email_and_password('name@example.edu', 'password');
check($GLOBALS['uri'] === 'ldap://directory.example:1389', 'URI port was not preserved');
check(!empty($GLOBALS['starttls']), 'StartTLS was not used with LDAP');
echo "LDAP authentication checks passed\n";
