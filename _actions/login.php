<?php

$email = $_POST['email'];
$password = $_POST['password'];
if ($email == "alice@gmail.com" && $password == "password") {
    session_start();
    $_SESSION['user'] = ['name' => 'alice'];
    header("loaction : ../profile.php");
} else {
    header("location : ../index.php?incorrect=login");
}
