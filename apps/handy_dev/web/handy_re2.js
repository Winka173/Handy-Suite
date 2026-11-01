/* Local Flutter Web bridge. RE2JS is vendored separately under its MIT license. */
(function () {
  'use strict';
  const encoder = new TextEncoder();
  globalThis.handyRe2Test = function (text, pattern) {
    try {
      if (typeof text !== 'string' || typeof pattern !== 'string' || text.length > 1000000 || encoder.encode(text).length > 1000000 || pattern.length > 1000 || encoder.encode(pattern).length > 1000) throw new Error('Schema regex byte limit exceeded');
      return JSON.stringify({ok: true, value: globalThis.RE2JS.RE2JS.compile(pattern).test(text)});
    } catch (_) { return JSON.stringify({ok: false, error: 'Schema RE2 pattern could not be evaluated'}); }
  };
  globalThis.handyRe2Matches = function (text, pattern) {
    try {
      if (typeof text !== 'string' || typeof pattern !== 'string' ||
          text.length > 100000 || encoder.encode(text).length > 100000 ||
          pattern.length > 1000 || encoder.encode(pattern).length > 1000) {
        throw new Error('RE2 limits: 100 KB input / 1000 UTF-8 bytes pattern');
      }
      const compiled = globalThis.RE2JS.RE2JS.compile(pattern);
      const matcher = compiled.matcher(text), matches = [];
      let outputBytes = 0, groupValues = 0;
      while (matches.length < 1000 && matcher.find()) {
        const groups = [];
        for (let i = 0; i <= matcher.groupCount(); i++) {
          const group = matcher.group(i);
          outputBytes += group === null ? 4 : encoder.encode(group).length + 8;
          if (++groupValues > 20000 || outputBytes > 1500000) {
            throw new Error('RE2 capture output limit exceeded');
          }
          groups.push(group);
        }
        matches.push({start: matcher.start(), end: matcher.end(), groups});
      }
      return JSON.stringify({ok: true, value: {
        engine: 'RE2 (no backreferences or lookaround)', matches,
        truncated: matches.length === 1000,
      }});
    } catch (error) {
      return JSON.stringify({ok: false, error: String(error).slice(0, 2000)});
    }
  };
})();
