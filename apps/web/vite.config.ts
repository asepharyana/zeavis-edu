import react from '@vitejs/plugin-react';
import tsconfigPaths from 'vite-tsconfig-paths';
import path from 'node:path';
import { defineConfig, loadEnv } from 'vite';
import { metricsPlugin } from './vite-plugin-metrics';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const apiProxyTarget = env.VITE_API_PROXY_TARGET || 'http://localhost:4006';

  return {
    plugins: [
      react(),
      tsconfigPaths(),
      metricsPlugin(),
      {
        name: 'cloudflare-rocket-loader-fix',
        transformIndexHtml(html) {
          // Prevent Cloudflare Rocket Loader from mangling <script type="module">
          // which breaks the entire JS bundle (blank page)
          return html.replace(
            /<script type="module"/g,
            '<script data-cfasync="false" type="module"',
          );
        },
      },
    ],
    server: {
      proxy: {
        '/api': apiProxyTarget,
      },
    },
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src'),
      },
    },
  };
});
