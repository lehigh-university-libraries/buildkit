<?php
define('BASEPATH', '/usr/local/share/scalar/system/');
require BASEPATH . 'libraries/Encrypt.php';
error_reporting(E_ALL);
set_error_handler(function ($severity, $message) {
    throw new RuntimeException($message);
});
$key = str_repeat('k', 32);
$iv = str_repeat('i', 32);
$text = 'scalar-session-fixture';
// Recorded from the unpatched image to preserve existing session compatibility.
$expected = 'dda2362410b51a8173283fa3b06c528c23bb72e0c92853ed84a3679949f7a776';
$encrypted = mcrypt_encrypt(MCRYPT_RIJNDAEL_256, $key, $text, MCRYPT_MODE_CBC, $iv);
if (bin2hex($encrypted) !== $expected
    || rtrim(mcrypt_decrypt(MCRYPT_RIJNDAEL_256, $key, hex2bin($expected), MCRYPT_MODE_CBC, $iv), "\0") !== $text) {
    throw new RuntimeException('Legacy session encryption compatibility changed');
}
echo "PASS: legacy mcrypt compatibility without PHP deprecations\n";
