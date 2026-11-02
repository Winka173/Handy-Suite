import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { expect, test } from 'vitest';

function worker(options: { full?: boolean; abort?: boolean } = {}) {
  let fetchHandler: (event: any) => void;
  const records: unknown[] = [],
    signals: unknown[] = [];
  let committed = false;
  const indexedDB = {
    open: () => {
      const request: any = {};
      setTimeout(() => {
        request.result = {
          close() {},
          transaction: () => {
            const transaction: any = {};
            transaction.abort = () => transaction.onabort();
            transaction.objectStore = () => ({
              count: () => {
                const count: any = {
                  result: options.full ? 100 : records.length,
                };
                setTimeout(() => count.onsuccess(), 0);
                return count;
              },
              add: (value: unknown) => {
                setTimeout(() => {
                  if (options.abort) transaction.onabort();
                  else {
                    records.push(value);
                    committed = true;
                    transaction.oncomplete();
                  }
                }, 0);
              },
            });
            return transaction;
          },
        };
        request.onsuccess();
      }, 0);
      return request;
    },
  };
  vm.runInNewContext(
    readFileSync('apps/handy_bookmark/web/save_share_worker.js', 'utf8'),
    {
      self: {
        registration: { scope: 'https://save.example/app/' },
        clients: {
          matchAll: async () => [
            { postMessage: (value: unknown) => signals.push(value) },
          ],
        },
        addEventListener: (kind: string, handler: typeof fetchHandler) => {
          if (kind === 'fetch') fetchHandler = handler;
        },
      },
      indexedDB,
      URL,
      URLSearchParams,
      Request,
      Response,
      TextEncoder,
      TextDecoder,
      Uint8Array,
      crypto: { randomUUID: () => '12345678-1234-4123-8123-123456789abc' },
    },
  );
  return {
    records,
    signals,
    committed: () => committed,
    receive: (request: Request) => {
      let response: Promise<Response> | undefined;
      fetchHandler!({
        request,
        respondWith: (value: Promise<Response>) => {
          response = value;
        },
      });
      return response;
    },
  };
}

test('Web Share Target commits before redirect; private URLs never enter location or client messages', async () => {
  const w = worker();
  const pending = w.receive(
    new Request('https://save.example/app/share-target', {
      method: 'POST',
      body: new URLSearchParams({
        title: 'Read later',
        text: 'https://example.org/private?token=secret',
      }),
    }),
  )!;
  expect(w.committed()).toBe(false);
  const response = await pending;
  expect(w.committed()).toBe(true);
  expect(response.status).toBe(303);
  expect(response.headers.get('location')).toBe(
    'https://save.example/app/?shared=1',
  );
  expect(w.records).toHaveLength(1);
  expect(w.signals).toEqual([{ type: 'handy-save-share' }]);
});

test('Web Share Target rejects malformed/oversized input, full queue and aborted transactions', async () => {
  const request = (
    body: string,
    contentType = 'application/x-www-form-urlencoded',
  ) =>
    new Request('https://save.example/app/share-target', {
      method: 'POST',
      body,
      headers: { 'content-type': contentType },
    });
  for (const [body, mime, status] of [
    ['text=', undefined, 400],
    ['text=hello&unexpected=x', undefined, 400],
    ['text=x', 'text/plain', 415],
    [`text=${'x'.repeat(262145)}`, undefined, 413],
  ] as const) {
    const w = worker(),
      response = await w.receive(request(body, mime));
    expect(response!.status).toBe(status);
    expect(w.records).toHaveLength(0);
  }
  for (const options of [{ full: true }, { abort: true }]) {
    const w = worker(options),
      response = await w.receive(request('url=https%3A%2F%2Fexample.org'));
    expect(response!.status).toBe(503);
    expect(w.records).toHaveLength(0);
  }
});

test('worker ignores other origins, paths, GETs and query-bearing endpoints', () => {
  const w = worker();
  for (const address of [
    'https://external.example/app/share-target',
    'https://save.example/app/api',
    'https://save.example/app/share-target?url=secret',
  ])
    expect(
      w.receive(new Request(address, { method: 'POST', body: 'text=x' })),
    ).toBeUndefined();
  expect(
    w.receive(new Request('https://save.example/app/share-target')),
  ).toBeUndefined();
});
