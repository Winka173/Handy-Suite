import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    include: [
      'tooling/pwa-assets.test.ts',
      'tooling/save-share-worker.test.ts',
    ],
  },
});
