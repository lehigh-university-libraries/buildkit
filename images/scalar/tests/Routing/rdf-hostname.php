<?php
// Capture the connection settings without connecting to or creating an RDF store.
class ARC2 {
    public static $settings;
    public static function getStore($settings) {
        self::$settings = $settings;
        return new class {
            public function isSetUp() { return true; }
        };
    }
}
$ci = new stdClass;
$ci->config = new class {
    public function item($name) { return array(); }
};
function &get_instance() { return $GLOBALS['ci']; }
require '/usr/local/share/scalar/system/application/libraries/RDF_Store.php';
foreach (array(
    array('host.docker.internal', 3306, 'host.docker.internal'),
    array('host.docker.internal', 3307, 'host.docker.internal'),
    array('host.docker.internal:3307', 3307, 'host.docker.internal'),
    array('127.0.0.1', '', '127.0.0.1'),
) as $case) {
    $ci->db = (object) array('hostname' => $case[0], 'port' => $case[1],
        'database' => 'scalar', 'username' => 'fixture', 'password' => 'fixture',
        'ARC_dbprefix' => 'scalar_store_');
    new RDF_Store;
    if (ARC2::$settings['db_host'] !== $case[2] || ARC2::$settings['db_port'] !== $case[1]) {
        throw new RuntimeException('RDF store lost its database hostname or port');
    }
}
echo "PASS: RDF store preserves database hostname with separate port\n";
