<?php
define('FCPATH', '/opt/scalar/');
define('BASEPATH', '/usr/local/share/scalar/system/');
function base_url() { return 'https://scalar.lehigh.edu/'; }
require BASEPATH . 'application/helpers/MY_html_helper.php';
foreach (array('/opt/scalar/', '/usr/local/share/scalar/') as $root) {
    $file = $root . 'system/application/views/modules/book_list/book_list.php';
    $path = 'system/application/views/modules/book_list/';
    if (path_from_file($file) !== $path || url_from_file($file) !== base_url() . $path) {
        throw new RuntimeException('Application asset path leaked into URL');
    }
}
if (path_from_file('/opt/scalar/book/media/image.png') !== 'book/media/') {
    throw new RuntimeException('Book media path changed');
}
echo "PASS: bundled asset URLs and persistent book media paths\n";
