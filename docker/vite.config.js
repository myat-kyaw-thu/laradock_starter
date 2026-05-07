/**
 * Vite config for Laravel inside Docker
 * ─────────────────────────────────────
 * Copy this file to your Laravel project root (src/vite.config.js)
 * and adjust entry points as needed.
 *
 * Why these server settings?
 *   - server.host '0.0.0.0'  → Vite binds to all interfaces inside the
 *     container so Docker can forward port 5173 to your host machine.
 *   - server.hmr.host 'localhost' → The browser connects to HMR via
 *     localhost (your machine), not the container's internal hostname.
 *   - server.watch.usePolling → Required on Windows/WSL2 where inotify
 *     events don't cross the Docker boundary reliably.
 *
 * Reference: https://laravel.com/docs/12.x/vite#running-vite
 */

import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/css/app.css',
                'resources/js/app.js',
            ],
            refresh: true, // auto-refresh browser on Blade/route changes
        }),
    ],

    server: {
        // Bind to all interfaces so Docker port-forwarding works
        host: process.env.VITE_HOST ?? '0.0.0.0',
        port: 5173,
        strictPort: true, // fail fast if 5173 is taken instead of picking a random port

        hmr: {
            // Browser connects to HMR via localhost (your machine)
            host: 'localhost',
            port: 5173,
        },

        watch: {
            // Needed on Windows / WSL2 — filesystem events don't cross
            // the Docker boundary reliably without polling
            usePolling: true,
            interval: 1000,
        },
    },
});
