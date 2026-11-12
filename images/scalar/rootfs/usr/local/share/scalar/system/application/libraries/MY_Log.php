<?php defined('BASEPATH') OR exit('No direct script access allowed');

// CodeIgniter's stock logger requires a writable directory and creates daily
// files. Use its supported extension point to send application logs to stderr.
class MY_Log extends CI_Log {
    public function __construct() {
        $config =& get_config();
        $this->_threshold = (int) $config['log_threshold'];
        $this->_date_fmt = $config['log_date_format'];
    }

    public function write_log($level = 'error', $msg = '', $php_error = false) {
        $level = strtoupper($level);
        if (!isset($this->_levels[$level]) || $this->_levels[$level] > $this->_threshold) {
            return false;
        }
        return error_log($level . ' - ' . date($this->_date_fmt) . ' --> ' . $msg);
    }
}
