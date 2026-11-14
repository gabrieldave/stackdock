import { defineConfig } from 'vite';
import { resolve } from 'node:path';
import { viteSingleFile } from 'vite-plugin-singlefile';

/** Vista previa de un solo archivo (sin backend): checkout en modo demo, imágenes inline. */
export default defineConfig({
  publicDir: false,
  plugins: [viteSingleFile()],
  build: {
    outDir: 'dist-preview',
    emptyOutDir: true,
    rollupOptions: { input: resolve(__dirname, 'preview.html') },
  },
});
