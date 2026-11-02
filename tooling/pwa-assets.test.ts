import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { expect, test } from 'vitest';

test.each([
  'tools',
  'docs',
  'media',
  'dev',
  'keep',
  'recall',
  'bookmark',
  'spend',
  'habit',
  'trip',
  'boards',
])(
  'handy_%s worker isolates assets, excludes API data and requires explicit update',
  async (app) => {
    const name = `handy_${app}`;
    const generate = () =>
      execFileSync(process.execPath, ['tooling/flutter-offline.mjs', name], {
        encoding: 'utf8',
      });
    generate();
    const source = readFileSync(
      `apps/${name}/build/web/${name}_service_worker.js`,
      'utf8',
    );
    const evidence = JSON.parse(
      readFileSync(`docs/qa/evidence/${name}-offline-assets.json`, 'utf8'),
    ) as { version: string; files: string[] };
    generate();
    expect(
      readFileSync(`apps/${name}/build/web/${name}_service_worker.js`, 'utf8'),
    ).toBe(source);
    expect(evidence.files).toContain('index.html');
    expect(evidence.files).toContain('main.dart.js');
    expect(
      evidence.files.some(
        (s) => s.includes('service_worker') || s.includes('..'),
      ),
    ).toBe(false);
    const listeners = new Map<
      string,
      (event: Record<string, unknown>) => void
    >();
    const cacheData = new Map<string, Map<string, unknown>>([
      [`${name}-assets-old`, new Map()],
      ['unrelated-app-assets-keep', new Map()],
    ]);
    let activated = 0,
      claimed = 0,
      network = 0;
    const cache = {
      open: async (key: string) => {
        if (!cacheData.has(key)) cacheData.set(key, new Map());
        const values = cacheData.get(key)!;
        return {
          addAll: async (urls: string[]) => {
            urls.forEach((url) => values.set(url, { cached: url }));
          },
          match: async (key: string) => values.get(key),
        };
      },
      keys: async () => [...cacheData.keys()],
      delete: async (key: string) => cacheData.delete(key),
    };
    const self = {
      registration: { scope: `https://example.test/${app}/` },
      clients: {
        claim: async () => {
          claimed++;
        },
      },
      skipWaiting: () => {
        activated++;
      },
      addEventListener: (
        kind: string,
        fn: (event: Record<string, unknown>) => void,
      ) => listeners.set(kind, fn),
    };
    vm.runInNewContext(source, {
      self,
      caches: cache,
      URL,
      // Save's POST inbox worker has its own behavior suite; this test isolates
      // the shared static-asset cache and never treats POSTs as cacheable.
      importScripts: () => {},
      fetch: () => {
        network++;
        return Promise.resolve('network');
      },
    });
    let pending: Promise<unknown> | undefined;
    listeners.get('install')!({
      waitUntil: (value: Promise<unknown>) => {
        pending = value;
      },
    });
    await pending;
    expect(activated).toBe(0);
    const request = (url: string, method = 'GET', mode = 'cors') => {
      let response: Promise<unknown> | undefined;
      listeners.get('fetch')!({
        request: { url, method, mode },
        respondWith: (value: Promise<unknown>) => {
          response = value;
        },
      });
      return response;
    };
    expect(request('https://external.test/api?token=private')).toBeUndefined();
    expect(
      request(`https://example.test/${app}/api?token=private`),
    ).toBeUndefined();
    expect(
      request(`https://example.test/${app}/main.dart.js`, 'POST'),
    ).toBeUndefined();
    expect(await request(`https://example.test/${app}/main.dart.js`)).toEqual({
      cached: 'main.dart.js',
    });
    expect(
      await request(
        `https://example.test/${app}/deep-route`,
        'GET',
        'navigate',
      ),
    ).toEqual({ cached: 'index.html' });
    expect(network).toBe(0);
    listeners.get('message')!({ data: { type: 'other' } });
    expect(activated).toBe(0);
    listeners.get('message')!({ data: { type: 'activate-update' } });
    expect(activated).toBe(1);
    listeners.get('activate')!({
      waitUntil: (value: Promise<unknown>) => {
        pending = value;
      },
    });
    await pending;
    expect(claimed).toBe(1);
    expect(cacheData.has(`${name}-assets-old`)).toBe(false);
    expect(cacheData.has('unrelated-app-assets-keep')).toBe(true);
    const bootstrap = readFileSync(
      `apps/${name}/web/flutter_bootstrap.js`,
      'utf8',
    );
    expect(bootstrap).toContain(`${name}_service_worker.js`);
    expect(bootstrap).toContain("confirm('");
  },
);
