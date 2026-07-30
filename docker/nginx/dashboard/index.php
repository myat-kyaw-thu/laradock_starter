<?php
// LaraDoc Starter — Developer Dashboard

$htmlDir = '/var/www/html';
$projects = [];

if (is_dir($htmlDir)) {
    $dirs = array_filter(glob($htmlDir . '/*'), 'is_dir');
    foreach ($dirs as $dir) {
        $slug = basename($dir);
        $envPath = $dir . '/.env';
        
        $projectInfo = [
            'name' => ucfirst($slug),
            'url' => "http://{$slug}.localhost",
            'db' => 'N/A',
            'laravel_ver' => 'Unknown',
            'has_env' => false
        ];
        
        if (file_exists($envPath)) {
            $projectInfo['has_env'] = true;
            $lines = file($envPath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                if (strpos(trim($line), '#') === 0) continue;
                $parts = explode('=', $line, 2);
                if (count($parts) === 2) {
                    $key = trim($parts[0]);
                    $val = trim(trim($parts[1]), '"\'');
                    if ($key === 'APP_NAME') $projectInfo['name'] = $val;
                    if ($key === 'APP_URL') $projectInfo['url'] = $val;
                    if ($key === 'DB_DATABASE') $projectInfo['db'] = $val;
                }
            }
        }
        
        // Try to get Laravel version from composer.json
        $composerPath = $dir . '/composer.json';
        if (file_exists($composerPath)) {
            $composerData = json_decode(file_get_contents($composerPath), true);
            if (isset($composerData['require']['laravel/framework'])) {
                $projectInfo['laravel_ver'] = str_replace(['^', '~'], '', $composerData['require']['laravel/framework']);
            }
        }
        
        $projects[] = $projectInfo;
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LaraDoc Dashboard</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #0b0f19;
            --card-bg: rgba(22, 28, 45, 0.4);
            --card-border: rgba(255, 255, 255, 0.05);
            --primary: #4f46e5;
            --primary-glow: rgba(79, 70, 229, 0.4);
            --accent: #06b6d4;
            --text-main: #f3f4f6;
            --text-muted: #9ca3af;
            --success: #10b981;
            --success-glow: rgba(16, 185, 129, 0.2);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            overflow-x: hidden;
            background-image: 
                radial-gradient(circle at 10% 20%, rgba(79, 70, 229, 0.15) 0%, transparent 40%),
                radial-gradient(circle at 90% 80%, rgba(6, 182, 212, 0.1) 0%, transparent 40%);
        }

        header {
            padding: 2.5rem 2rem;
            max-width: 1200px;
            width: 100%;
            margin: 0 auto;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--card-border);
        }

        .logo {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            font-family: 'Outfit', sans-serif;
            font-size: 1.5rem;
            font-weight: 700;
            background: linear-gradient(135deg, #fff 30%, var(--text-muted) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .logo span {
            background: linear-gradient(135deg, var(--accent) 0%, var(--primary) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .system-services {
            display: flex;
            gap: 1rem;
        }

        .service-btn {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.6rem 1.2rem;
            border-radius: 9999px;
            font-size: 0.875rem;
            font-weight: 600;
            text-decoration: none;
            color: var(--text-main);
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            backdrop-filter: blur(12px);
        }

        .service-btn:hover {
            border-color: var(--primary);
            box-shadow: 0 0 15px var(--primary-glow);
            transform: translateY(-2px);
        }

        .service-btn svg {
            width: 16px;
            height: 16px;
        }

        main {
            flex: 1;
            padding: 3rem 2rem;
            max-width: 1200px;
            width: 100%;
            margin: 0 auto;
        }

        .hero {
            text-align: center;
            margin-bottom: 4rem;
        }

        .hero h1 {
            font-family: 'Outfit', sans-serif;
            font-size: 3rem;
            font-weight: 800;
            margin-bottom: 1rem;
            letter-spacing: -0.025em;
            background: linear-gradient(135deg, #fff 40%, var(--text-muted) 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .hero p {
            font-size: 1.1rem;
            color: var(--text-muted);
            max-width: 600px;
            margin: 0 auto;
        }

        .section-title {
            font-family: 'Outfit', sans-serif;
            font-size: 1.5rem;
            font-weight: 600;
            margin-bottom: 2rem;
            display: flex;
            align-items: center;
            gap: 0.75rem;
        }

        .section-title::after {
            content: '';
            flex: 1;
            height: 1px;
            background: var(--card-border);
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
            gap: 2rem;
            margin-bottom: 4rem;
        }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 16px;
            padding: 1.75rem;
            position: relative;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            backdrop-filter: blur(12px);
            overflow: hidden;
        }

        .card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: linear-gradient(135deg, rgba(79, 70, 229, 0.05) 0%, transparent 100%);
            opacity: 0;
            transition: opacity 0.3s ease;
            pointer-events: none;
        }

        .card:hover {
            transform: translateY(-4px);
            border-color: rgba(79, 70, 229, 0.3);
            box-shadow: 0 10px 30px -10px rgba(0, 0, 0, 0.7);
        }

        .card:hover::before {
            opacity: 1;
        }

        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 1.25rem;
        }

        .card-title {
            font-size: 1.25rem;
            font-weight: 700;
            color: #fff;
            letter-spacing: -0.01em;
        }

        .badge {
            font-size: 0.75rem;
            font-weight: 700;
            padding: 0.25rem 0.6rem;
            border-radius: 9999px;
            background: var(--success-glow);
            color: var(--success);
            border: 1px solid rgba(16, 185, 129, 0.2);
        }

        .metadata-list {
            margin-bottom: 2rem;
            font-size: 0.875rem;
        }

        .metadata-item {
            display: flex;
            justify-content: space-between;
            padding: 0.5rem 0;
            border-bottom: 1px dashed rgba(255, 255, 255, 0.05);
        }

        .metadata-item:last-child {
            border: none;
        }

        .metadata-label {
            color: var(--text-muted);
        }

        .metadata-value {
            font-weight: 600;
            color: var(--text-main);
        }

        .card-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 0.5rem;
            width: 100%;
            padding: 0.8rem;
            border-radius: 8px;
            font-weight: 700;
            text-decoration: none;
            background: linear-gradient(135deg, var(--primary) 0%, #3b82f6 100%);
            color: #fff;
            box-shadow: 0 4px 12px rgba(79, 70, 229, 0.3);
            transition: all 0.2s ease;
        }

        .card-btn:hover {
            box-shadow: 0 6px 20px rgba(79, 70, 229, 0.5);
            transform: translateY(-1px);
        }

        .empty-state {
            text-align: center;
            padding: 4rem 2rem;
            background: var(--card-bg);
            border: 1px dashed var(--card-border);
            border-radius: 16px;
            grid-column: 1 / -1;
        }

        .empty-state h3 {
            font-size: 1.25rem;
            margin-bottom: 0.5rem;
        }

        .empty-state p {
            color: var(--text-muted);
            margin-bottom: 1.5rem;
        }

        .code-block {
            display: inline-block;
            background: rgba(0, 0, 0, 0.3);
            border: 1px solid var(--card-border);
            padding: 0.5rem 1rem;
            border-radius: 6px;
            font-family: monospace;
            font-size: 0.9rem;
            color: var(--accent);
        }

        footer {
            text-align: center;
            padding: 3rem 2rem;
            color: var(--text-muted);
            font-size: 0.875rem;
            border-top: 1px solid var(--card-border);
            margin-top: auto;
        }
    </style>
</head>
<body>

    <header>
        <div class="logo">
            LaraDoc <span>Starter</span>
        </div>
        <div class="system-services">
            <a href="http://phpmyadmin.localhost" target="_blank" class="service-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7V4h16v3M9 20h6M12 12v8M4 7h16v10H4z"/></svg>
                phpMyAdmin
            </a>
            <a href="http://mailpit.localhost" target="_blank" class="service-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><path d="M22 6l-10 7L2 6"/></svg>
                Mailpit
            </a>
        </div>
    </header>

    <main>
        <div class="hero">
            <h1>Local Development Dashboard</h1>
            <p>One Docker environment, multiple fully isolated Laravel projects. Zero configuration domain routing.</p>
        </div>

        <h2 class="section-title">Laravel Projects</h2>
        
        <div class="grid">
            <?php if (empty($projects)): ?>
                <div class="empty-state">
                    <h3>No projects found</h3>
                    <p>Get started by creating your first Laravel project in the environment.</p>
                    <div class="code-block">bash add-project.sh my-app</div>
                </div>
            <?php else: ?>
                <?php foreach ($projects as $project): ?>
                    <div class="card">
                        <div>
                            <div class="card-header">
                                <h3 class="card-title"><?= htmlspecialchars($project['name']) ?></h3>
                                <span class="badge">PHP 8.4</span>
                            </div>
                            <div class="metadata-list">
                                <div class="metadata-item">
                                    <span class="metadata-label">Local Domain</span>
                                    <span class="metadata-value" style="color: var(--accent);"><?= htmlspecialchars(str_replace('http://', '', $project['url'])) ?></span>
                                </div>
                                <div class="metadata-item">
                                    <span class="metadata-label">Database Schema</span>
                                    <span class="metadata-value"><?= htmlspecialchars($project['db']) ?></span>
                                </div>
                                <div class="metadata-item">
                                    <span class="metadata-label">Laravel Version</span>
                                    <span class="metadata-value">v<?= htmlspecialchars($project['laravel_ver']) ?></span>
                                </div>
                            </div>
                        </div>
                        <a href="<?= htmlspecialchars($project['url']) ?>" target="_blank" class="card-btn">
                            Open Application
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14L21 3"/></svg>
                        </a>
                    </div>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </main>

    <footer>
        <p>LaraDoc Starter &copy; <?= date('Y') ?>. Powered by Docker Alpine and Nginx.</p>
    </footer>

</body>
</html>
