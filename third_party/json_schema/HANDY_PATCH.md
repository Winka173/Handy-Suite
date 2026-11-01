# JSON Schema integration patch

Upstream json_schema 5.2.2, https://github.com/workiva/json_schema, Boost Software
License with retained upstream and JSON-Schema-Test-Suite notices. Only lib,
pubspec, LICENSE and README were copied from the published package.

Changes:
- Integral JSON decimals (for example maxItems: 2.0) are accepted as integers.
- Absolute-path references resolve at the inherited origin, not its directory.
- Schema-supplied pattern/patternProperties use an injected SchemaPattern
  compiler instead of Dart backtracking RegExp. The app always supplies RE2.
- Shared synchronous validation-step/depth and error-output callbacks let the
  caller abort recursive/combinatorial schemas and quadratic uniqueItems work.
  An aborted evaluation throws; it never becomes a successful validation.
- Nested composition validators inherit validateFormats from the parent. The
  app keeps format assertions disabled, matching the legacy Ajv configuration.

The app uses synchronous creation and an explicit denying RefProvider. No
external reference is fetched. Limits and strict draft-07 keyword checks live in
handy_dev_engine; they are application policy, not claims about the upstream
library. This vendor directory is part of the Flutter migration and must remain
when legacy Expo application source is eventually removed.
