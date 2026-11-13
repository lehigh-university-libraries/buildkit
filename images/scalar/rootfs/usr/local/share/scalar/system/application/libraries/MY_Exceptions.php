<?php defined('BASEPATH') OR exit('No direct script access allowed');

// CodeIgniter logs PHP warnings even when PHP's error_reporting excludes them.
class MY_Exceptions extends CI_Exceptions {
    public function log_exception($severity, $message, $filepath, $line) {
        if (($severity & (int) config_item('php_error_reporting')) === 0) {
            return;
        }
        parent::log_exception($severity, $message, $filepath, $line);
    }
}
