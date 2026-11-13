<?php
require '/usr/local/share/scalar/system/application/arc/vendor/autoload.php';
error_reporting(E_ALL);
set_error_handler(function ($severity, $message) {
    // Legacy parser state uses dynamic properties; keep this check focused on XML callbacks.
    if ($severity === E_DEPRECATED && strpos($message, 'Creation of dynamic property ARC2_') === 0) return true;
    throw new RuntimeException($message);
});
// Exercise the same catalog parse used by /book/import/internet_archive.
$parser = ARC2::getRDFParser();
$parser->parse('https://scalar.example.edu/system/application/rdf/xsl/archives.rdf',
    file_get_contents('/usr/local/share/scalar/system/application/rdf/xsl/archives.rdf'));
if ($parser->getErrors() || !$parser->getTriples()) {
    throw new RuntimeException('Import archive catalog parsing failed');
}
$found = false;
foreach ($parser->getTriples() as $triple) {
    if ($triple['p'] === 'http://purl.org/dc/elements/1.1/title' && $triple['o'] === 'Internet Archive') $found = true;
}
if (!$found) throw new RuntimeException('Internet Archive missing from import catalog');
foreach (array('RDFXMLParser', 'AtomParser', 'SPOGParser', 'LegacyXMLParser') as $name) {
    $parser = ARC2::getComponent($name);
    $parser->encoding = 'UTF-8';
    $parser->initXMLParser();
}
echo "PASS: import catalog and XML parser callbacks on PHP 8.4\n";
