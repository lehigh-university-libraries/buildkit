<?php
error_reporting(E_ALL);
set_error_handler(function ($severity, $message) { throw new RuntimeException($message); });
$template = file('/usr/local/share/scalar/system/application/views/arbors/html5_RDFa/wrapper.php');
$sort = $name = null;
foreach ($template as $line) {
    if (strpos($line, '->sort_number =') !== false && strpos($line, '$outward_item->page_index') !== false) $sort = trim($line);
    if (strpos($line, 'scalar:fullname') !== false && strpos($line, '$outward_item') !== false) $name = $line;
}
if ($sort === null || $name === null) throw new RuntimeException('RDFa template sections missing');
foreach (array(false, true) as $populated) {
    $version = new stdClass;
    $outward_item = (object) array('version_index' => 0, 'versions' => array($version));
    if ($populated) {
        $outward_item->page_index = 4;
        $version->fullname = 'Fixture Author';
    }
    eval($sort);
    ob_start();
    eval('?>' . $name);
    $output = ob_get_clean();
    if ($version->sort_number !== ($populated ? 4 : 0)
        || strpos($output, '>'.($populated ? 'Fixture Author' : '').'</span>') === false) {
        throw new RuntimeException('RDFa optional field rendering changed');
    }
}
echo "PASS: RDFa optional fields render without warnings\n";
