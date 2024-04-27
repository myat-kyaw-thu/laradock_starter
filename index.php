<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Index</title>
    <link rel="stylesheet" href="css/bootstrap.min.css">

</head>

<body>
    <div class="container text-center" style="max-width: 600px;">
        <h3 class="my-4">Login</h3>
        <?php
        if (isset($_GET['incorrect'])) :
        ?>
            <div class="alert alert-warning">
                Incorrect Password or Email
            </div>
        <?php endif ?>
        <?php
        if (isset($_GET['register'])) :
        ?>
            <div class="alert alert-success">
                Account Created, Please Login
            </div>
        <?php endif ?>

        <form action="_actions/login.php" method="post" class="mb-4">

            <input type="email" name="email" placeholder="Email" class="form-control mb-3" required>
            <input type="password" name="password" placeholder="Password" class="form-control mb-3" required>
            <button class="btn btn-primary w-100">Login</button>
        </form>
        <a href="register.php">Sign Up</a>
    </div>
</body>

</html>