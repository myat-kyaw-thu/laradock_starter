import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/css/app.css',
                'resources/js/app.js',
            ],
            refresh: true,
        }),
    ],

    server: {
        host: process.env.VITE_HOST ?? '0.0.0.0',
        port: 5173,
        strictPort: true,

        hmr: {
            host: 'localhost',
            port: 5173,
        },

        watch: {
            usePolling: true,
            interval: 1000,
        },
    },
});
