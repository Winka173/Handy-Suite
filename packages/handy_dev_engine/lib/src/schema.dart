import 'dart:convert';
import 'package:json_schema/json_schema.dart';
import 'regex.dart';
import 'transforms.dart' show bounded, parseJson, assertJsonData;

class _SchemaBudget {
  int steps = 0, depth = 0, errors = 0, errorBytes = 0, regexWork = 0;
  void guard(bool entering) {
    if (!entering) {
      depth--;
      return;
    }
    if (++steps > 250000 || ++depth > 200)
      throw StateError('Schema evaluation limit exceeded');
  }

  void error(String message, String path, String schemaPath) {
    errorBytes += (message.length + path.length + schemaPath.length) * 3;
    if (++errors > 2000 || errorBytes > 1500000)
      throw StateError('Schema error output limit exceeded');
  }
}

class _SafeSchemaPattern implements SchemaPattern {
  @override
  final String pattern;
  final _SchemaBudget budget;
  _SafeSchemaPattern(this.pattern, this.budget) {
    regexHasMatch('', pattern);
  }
  @override
  bool hasMatch(String text) {
    budget.regexWork += text.length + pattern.length;
    if (budget.regexWork > 10000000)
      throw StateError('Schema regex work limit exceeded');
    return regexHasMatch(text, pattern);
  }

  @override
  String toString() => pattern;
}

void _checkSchema(Object? value, [int depth = 0]) {
  if (depth > 40) throw const FormatException('Schema nesting limit exceeded');
  if (value is bool) return;
  if (value is! Map)
    throw const FormatException('Schema must be an object or boolean');
  const keywords = {
    r'$id',
    r'$schema',
    r'$ref',
    r'$comment',
    'title',
    'description',
    'default',
    'examples',
    'readOnly',
    'writeOnly',
    'type',
    'enum',
    'const',
    'multipleOf',
    'maximum',
    'exclusiveMaximum',
    'minimum',
    'exclusiveMinimum',
    'maxLength',
    'minLength',
    'pattern',
    'format',
    'contentEncoding',
    'contentMediaType',
    'items',
    'additionalItems',
    'maxItems',
    'minItems',
    'uniqueItems',
    'contains',
    'maxProperties',
    'minProperties',
    'required',
    'properties',
    'patternProperties',
    'additionalProperties',
    'dependencies',
    'propertyNames',
    'definitions',
    'allOf',
    'anyOf',
    'oneOf',
    'not',
    'if',
    'then',
    'else',
  };
  for (final key in value.keys) {
    if (!keywords.contains(key))
      throw FormatException('Unsupported draft-07 keyword: $key');
  }
  if (value.containsKey(r'$schema') &&
      !{
        r'http://json-schema.org/draft-07/schema#',
        r'https://json-schema.org/draft-07/schema#',
      }.contains(value[r'$schema']))
    throw const FormatException('Only JSON Schema draft-07 is supported');
  for (final key in ['properties', 'patternProperties', 'definitions']) {
    if (value[key] is Map)
      for (final child in (value[key] as Map).values) {
        _checkSchema(child, depth + 1);
      }
  }
  for (final key in ['allOf', 'anyOf', 'oneOf']) {
    if (value[key] is List)
      for (final child in value[key] as List) {
        _checkSchema(child, depth + 1);
      }
  }
  for (final key in [
    'additionalProperties',
    'additionalItems',
    'contains',
    'propertyNames',
    'not',
    'if',
    'then',
    'else',
  ]) {
    if (value.containsKey(key)) _checkSchema(value[key], depth + 1);
  }
  if (value['items'] is List) {
    for (final child in value['items'] as List) {
      _checkSchema(child, depth + 1);
    }
  } else if (value.containsKey('items')) {
    _checkSchema(value['items'], depth + 1);
  }
  if (value['dependencies'] is Map)
    for (final child in (value['dependencies'] as Map).values) {
      if (child is! List) _checkSchema(child, depth + 1);
    }
}

Map<String, Object?> validateJsonSchema(String input, String options) {
  final instance = parseJson(input),
      schema = parseJson(bounded(options, 20000));
  _checkSchema(schema);
  final oldCompiler = JsonSchema.patternCompiler,
      oldGuard = JsonSchema.validationGuard,
      oldError = JsonSchema.errorGuard;
  final budget = _SchemaBudget();
  JsonSchema.patternCompiler = (pattern) => _SafeSchemaPattern(pattern, budget);
  JsonSchema.validationGuard = budget.guard;
  JsonSchema.errorGuard = budget.error;
  try {
    final compiled = JsonSchema.create(
      schema as Object,
      schemaVersion: SchemaVersion.draft7,
      refProvider: RefProvider.sync(
        (_) => throw const FormatException(
          'External or unresolved schema references are disabled',
        ),
      ),
    );
    final result = compiled.validate(instance, validateFormats: false);
    final output = <String, Object?>{
      'valid': result.isValid,
      'errors': result.isValid
          ? null
          : [
              for (final error in result.errors)
                {
                  'instancePath': error.instancePath,
                  'schemaPath': '#${error.schemaPath}',
                  'message': error.message,
                },
            ],
    };
    assertJsonData(output);
    if (utf8.encode(jsonEncode(output)).length > 2000000)
      throw const FormatException('Schema output limit exceeded');
    return output;
  } on StateError {
    throw const FormatException(
      'Schema resource limits exceeded; simplify the schema or data',
    );
  } finally {
    JsonSchema.patternCompiler = oldCompiler;
    JsonSchema.validationGuard = oldGuard;
    JsonSchema.errorGuard = oldError;
  }
}
