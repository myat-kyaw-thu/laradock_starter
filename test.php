<?php
include("vendor/autoload.php");

use Helpers\Auth;
use Helpers\HTTP;
use Libs\Database\UsersTable;
use Libs\Database\MySQL;
use Faker\Factory as Faker;


Auth::check();


HTTP::redirect();

$db = new MySQL;
$db->connect();


$table = new UsersTable;
$table->insert();

$faker = Faker::create();
echo $faker->name;