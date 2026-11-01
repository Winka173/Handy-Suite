import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: { include: ['tooling/re2-web-bridge.test.ts'] },
});
