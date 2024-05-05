<?php
include("vendor/autoload.php");

use Helpers\Auth;
use Helpers\HTTP;
use Libs\Database\UsersTable;
use Libs\Database\MySQL;
use Faker\Factory as Faker;

$mysql = new MySQL;
$table = new UsersTable($mysql);
$faker = Faker::create();

// echo "Starting...<br>";

// for ($i=0; $i < 20; $i++) { 
//     $table->insert([
//         "name" => $faker->name,
//         "email" => $faker->email,
//         "address" => $faker->address,
//         "phone" => $faker->phoneNumber,
//         "password" => "password",
//     ]);
// }

// echo "Done..<br>";

// strip_tags() (php function)
// htmlspecialchars() (php function)
