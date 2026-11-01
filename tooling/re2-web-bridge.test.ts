import { readFileSync } from 'node:fs';
import { createContext, runInContext } from 'node:vm';
import { expect, test } from 'vitest';

test('vendored Flutter browser RE2 matches fixed expected semantics and bounds', () => {
  const sandbox = createContext({ TextEncoder });
  for (const path of [
    'apps/handy_dev/web/vendor/re2js-2.9.1.js',
    'apps/handy_dev/web/handy_re2.js',
  ]) {
    runInContext(readFileSync(path, 'utf8'), sandbox, { timeout: 5000 });
  }
  const execute = (text: string, pattern: string) =>
    JSON.parse(sandbox.handyRe2Matches(text, pattern));
  const booleanTest = (text: string, pattern: string) =>
    JSON.parse(sandbox.handyRe2Test(text, pattern));
  expect(booleanTest('Vietnam', '^\\p{L}+$')).toEqual({
    ok: true,
    value: true,
  });
  expect(booleanTest('a'.repeat(999999) + '!', '(a+)+$')).toEqual({
    ok: true,
    value: false,
  });
  expect(booleanTest('a'.repeat(1000001), 'a').ok).toBe(false);
  expect(booleanTest('abc', '(a)\\1').ok).toBe(false);
  const frozen = JSON.parse(
    readFileSync('test-fixtures/re2/legacy-matches.json', 'utf8'),
  ) as {
    cases: { text: string; pattern: string; expected: unknown }[];
  };
  expect(frozen.cases.length).toBe(6);
  for (const { text, pattern, expected } of frozen.cases) {
    const result = execute(text, pattern);
    expect(result.ok).toBe(true);
    expect(result.value).toEqual(expected);
  }
  for (const [text, pattern] of [
    ['aaa', '(a)\\1'],
    ['aaa', 'a(?=b)'],
    ['aaa', '['],
    ['a'.repeat(100001), 'a'],
    ['x', '€'.repeat(334)],
    ['a'.repeat(100000), '('.repeat(25) + 'a+' + ')'.repeat(25)],
  ])
    expect(execute(text!, pattern!).ok).toBe(false);
});
