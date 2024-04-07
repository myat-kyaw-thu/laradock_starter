<?php
include("vendor/autoload.php");

use Helpers\Auth;
use Helpers\HTTP;
use Libs\Database\UsersTable;
use Libs\Database\MySQL;
use Faker\Factory as Faker;

$mysql = new MySQL;
$db = $mysql->connect();

$result = $db->query("SELECT * FROM roles");
print_r($result->fetchAll());