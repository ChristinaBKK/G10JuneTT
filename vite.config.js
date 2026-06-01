import { resolve } from 'node:path';

import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        adminCourseChanges: resolve(__dirname, 'admin-course-changes.html'),
      },
    },
  },
});