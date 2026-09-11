import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  server: {
    proxy: {
      '/api/robot': {
        target: 'http://10.0.0.110:5000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/robot/, '/api'),
      },
    },
  },
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['logo.png', 'apple-touch-icon.png'],
      devOptions: { enabled: true },
      manifest: {
        name: 'G.A.T.T.O. - Gestore Autonomo',
        short_name: 'G.A.T.T.O.',
        description: 'Gestore Autonomo Tecnologico Terreni Orti',
        theme_color: '#166534',
        background_color: '#f0fdf4',
        display: 'standalone',
        start_url: '/app',
        scope: '/app',
        id: '/app',
        icons: [
          { src: '/pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: '/pwa-512x512.png', sizes: '512x512', type: 'image/png' },
        ],
      },
    })
  ],
})
