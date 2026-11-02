import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: {
    include: [
      'tooling/pwa-assets.test.ts',
      'tooling/bookmark-share-worker.test.ts',
      'tooling/re2-web-bridge.test.ts',
    ],
  },
});
