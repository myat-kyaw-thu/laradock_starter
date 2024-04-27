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
        <h3 class="my-4">Register</h3>

        <form action="_actions/create.php" method="post" class="mb-4">
            <input type="name" name="name" placeholder="Name" class="form-control mb-3" required>
            <input type="email" name="email" placeholder="Email" class="form-control mb-3" required>
            <input type="phone" name="phone" placeholder="Phone" class="form-control mb-3" required>
           <textarea name="address" placeholder="Address" class="form-control mb-3"></textarea>
            <input type="password" name="password" placeholder="Password" class="form-control mb-3" required>
            <button class="btn btn-primary w-100">Register</button>
        </form>
        <a href="index.php">Login</a>
    </div>
</body>

</html>