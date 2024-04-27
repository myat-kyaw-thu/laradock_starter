<?php
include("../vendor/autoload.php");

use Libs\Database\MySQL;
use Libs\Database\UsersTable;
use Helpers\HTTP;

$table = new UsersTable(new MySQL);
$table->insert([
    "name" => $_POST["name"],
    "email" => $_POST["email"],
    "password" => $_POST["password"],
    "address" => $_POST["address"],
    "phone" => $_POST["phone"],
]);
HTTP::redirect("/index.php" , "register=success");