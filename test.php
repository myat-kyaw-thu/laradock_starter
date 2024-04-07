<?php
include("vendor/autoload.php");

use Helpers\Auth;
use Helpers\HTTP;
use Libs\Database\UsersTable;
use Libs\Database\MySQL;
use Faker\Factory as Faker;

$mysql = new MySQL;
$table = new UsersTable($mysql);

$id = $table->insert([
    "name" => "Alice",
    "email" => "alice@gmail.com",
    "phone" => "3453345",
    "address" => "Some Address",
    "password" => "password",
]);
echo $id;