<?php
include("vendor/autoload.php");

use Helpers\Auth;
use Helpers\HTTP;
use Libs\Database\UsersTable;
use Libs\Database\MySQL;
use Faker\Factory as Faker;

$mysql = new MySQL;
$table = new UsersTable($mysql);

$user = $table->find("alice@gmail.com" , "password");
print_r($user);