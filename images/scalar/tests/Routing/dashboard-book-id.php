<?php
error_reporting(E_ALL);
set_error_handler(function ($severity, $message) { throw new RuntimeException($message); });
class MY_Model { public $db; }
require '/usr/local/share/scalar/system/application/models/book_model.php';
$model = (new ReflectionClass('Book_model'))->newInstanceWithoutConstructor();
$model->db = new class {
    public $queries = array();
    public function query($sql, $bindings) {
        $this->queries[] = array($sql, $bindings);
        return new class { public function result() { return array(); } };
    }
};
foreach (array('undefined', null, '', array('7'), '7 OR 1=1', '7; SELECT 1', -1, 0, '1.5') as $id) {
    if ($model->get_images($id) !== array() || $model->db->queries) {
        throw new RuntimeException('Invalid book ID reached the image query');
    }
}
foreach (array(7, '42') as $id) {
    $model->get_images($id, array('mp4', 'video'));
    $query = end($model->db->queries);
    if (strpos($query[0], 'AND A.book_id = ? ') === false || $query[1] !== array((int) $id)) {
        throw new RuntimeException('Book image query did not bind the book ID');
    }
}
echo "PASS: invalid dashboard book IDs cannot reach image SQL\n";
