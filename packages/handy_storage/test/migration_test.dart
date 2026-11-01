import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_workflow/handy_workflow.dart';

void main() {
  test(
    'all six app envelopes roundtrip and reject cross-app or unsupported legacy recipes',
    () {
      const apps = ['tools', 'docs', 'media', 'dev', 'keep', 'recall'];
      for (final app in apps) {
        final current = HandyPreferences(
          locale: 'vi',
          theme: 'dark',
          drafts: {'uppercase': 'PRIVATE_DRAFT'},
        );
        final encoded = exportPreferences(
          current,
          app: app,
          includeDrafts: false,
        );
        expect(encoded, isNot(contains('PRIVATE_DRAFT')));
        final restored = importPreferences(encoded, app: app);
        expect(restored.toJson(), current.copyWith(drafts: {}).toJson());
        final legacy = jsonEncode({
          'version': 1,
          'app': app,
          'preferences': {'locale': 'vi', 'theme': 'dark', 'favorites': []},
          'recipes': [],
          'entitlement': 'PRO_LIFETIME',
        });
        expect(importPreferences(legacy, app: app).toJson(), restored.toJson());
        expect(
          exportPreferences(restored, app: app),
          isNot(contains('PRO_LIFETIME')),
        );
        for (final other in apps.where((v) => v != app)) {
          expect(
            () => importPreferences(encoded, app: other),
            throwsFormatException,
          );
          expect(
            () => importPreferences(legacy, app: other),
            throwsFormatException,
          );
        }
      }
      expect(
        () => exportPreferences(HandyPreferences(), app: 'snap'),
        throwsFormatException,
      );
      expect(
        () => importPreferences('{"version":1}', app: 'docs'),
        throwsFormatException,
      );
      expect(
        () => importPreferences(
          jsonEncode({
            'version': 1,
            'app': 'docs',
            'preferences': {'locale': 'en', 'theme': 'light', 'favorites': []},
            'recipes': [
              {
                'version': 1,
                'name': 'Unsafe',
                'steps': ['jwt'],
              },
            ],
          }),
          app: 'docs',
          knownTools: {'md-text'},
          workflowSteps: {'md-text'},
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'actual React Native backup preserves nested preferences and recipes',
    () {
      final imported = importPreferences(
        jsonEncode({
          'version': 1,
          'app': 'tools',
          'preferences': {
            'locale': 'vi',
            'theme': 'dark',
            'favorites': ['calculate', 'units', 'accents'],
          },
          'recipes': [
            {
              'version': 1,
              'name': 'Tiếng Việt 😀',
              'steps': ['normalize', 'accents', 'uppercase'],
            },
          ],
          'drafts': {'uppercase': 'must not import outside legacy envelope'},
          'entitlement': 'PRO_LIFETIME',
        }),
      );
      expect(imported.locale, 'vi');
      expect(imported.theme, 'dark');
      expect(imported.favorites, ['calculate', 'units', 'accents']);
      expect(imported.recipes.single.name, 'Tiếng Việt 😀');
      expect(imported.recipes.single.steps, [
        'normalize',
        'accents',
        'uppercase',
      ]);
      expect(imported.drafts, isEmpty);
      final reopened = importPreferences(exportPreferences(imported));
      expect(reopened.toJson(), imported.toJson());
      expect(exportPreferences(imported), isNot(contains('PRO_LIFETIME')));
    },
  );
  test('wrong-app legacy backups fail before changing state', () {
    final current = HandyPreferences(locale: 'vi', theme: 'dark');
    for (final app in [
      'docs',
      'media',
      'dev',
      'snap',
      'keep',
      'recall',
      'handy-tools',
      '',
    ]) {
      expect(
        () => importPreferences(
          jsonEncode({
            'version': 1,
            'app': app,
            'preferences': {'locale': 'en', 'theme': 'light', 'favorites': []},
            'recipes': [],
          }),
        ),
        throwsFormatException,
      );
      expect(current.locale, 'vi');
      expect(current.theme, 'dark');
    }
  });
  test('unknown or malformed envelopes are rejected', () {
    for (final value in [
      {'version': 1, 'format': 'other-app'},
      {'version': 1, 'app': 'tools', 'preferences': null, 'recipes': []},
      {'version': 1, 'app': 'tools', 'preferences': {}, 'recipes': null},
      {'version': 2, 'app': 'tools', 'preferences': {}, 'recipes': []},
      {'version': 1, 'app': 'tools', 'preferences': {}, 'recipes': []},
    ]) {
      expect(() => importPreferences(jsonEncode(value)), throwsFormatException);
    }
  });
  test(
    'safe draft allowlist drops HAR, redaction, arbitrary secrets and paths',
    () {
      final imported = importPreferences(
        jsonEncode({
          'version': 1,
          'drafts': {
            'uppercase': 'Đặng Thị Hồng 😀',
            'har-summary': 'HARSECRET',
            'redact': 'REDACTSECRET',
            'http': 'HTTPSECRET',
            'env': 'ENVSECRET',
            'unknown': 'UNKNOWNSECRET',
            'password': 'PASSWORDSECRET',
            'arbitrary-path': 'file:///private/data',
          },
        }),
      );
      expect(imported.drafts, {'uppercase': 'Đặng Thị Hồng 😀'});
      final exported = exportPreferences(imported);
      for (final secret in [
        'HARSECRET',
        'REDACTSECRET',
        'HTTPSECRET',
        'ENVSECRET',
        'UNKNOWNSECRET',
        'PASSWORDSECRET',
        'file:///',
      ]) {
        expect(exported, isNot(contains(secret)));
      }
    },
  );
  test('unknown favorite IDs cannot silently migrate as a valid tool', () {
    expect(
      () => importPreferences('{"version":1,"favorites":["not-a-tool"]}'),
      throwsFormatException,
    );
    expect(
      importPreferences(
        '{"version":1,"favorites":["units","units"]}',
      ).favorites,
      ['units'],
    );
  });
  test('unknown and incompatible saved workflow IDs fail before commit', () {
    final current = HandyPreferences(locale: 'vi');
    for (final id in [
      'dedupe',
      'strip-diacritics',
      'missing',
      'loan',
      'units',
      'calculate',
    ]) {
      expect(
        () => importPreferences(
          jsonEncode({
            'version': 1,
            'recipes': [
              {
                'version': 1,
                'name': 'Bad',
                'steps': ['uppercase', id],
              },
            ],
          }),
        ),
        throwsFormatException,
      );
      expect(current.recipes, isEmpty);
    }
    expect(
      () => exportPreferences(
        HandyPreferences(
          recipes: [
            Recipe('bad', ['missing']),
          ],
        ),
      ),
      throwsFormatException,
    );
  });
  test('known migrated workflow steps remain runnable', () {
    final imported = importPreferences(
      jsonEncode({
        'version': 1,
        'recipes': [
          {
            'version': 1,
            'name': 'Text',
            'steps': toolsTextWorkflowIds.toList(),
          },
        ],
      }),
    );
    expect(imported.recipes.single.steps.toSet(), toolsTextWorkflowIds);
  });
  test('non-Tools apps can provide a separate safe registry explicitly', () {
    final imported = importPreferences(
      '{"version":1,"favorites":["json-format"],"drafts":{"json-format":"{}","uppercase":"not this app"},"recipes":[{"version":1,"name":"JSON","steps":["json-format"]}]}',
      knownTools: {'json-format'},
      workflowSteps: {'json-format'},
    );
    expect(imported.drafts, {'json-format': '{}'});
    expect(
      importPreferences(
        exportPreferences(
          imported,
          knownTools: {'json-format'},
          workflowSteps: {'json-format'},
        ),
        knownTools: {'json-format'},
        workflowSteps: {'json-format'},
      ).toJson(),
      imported.toJson(),
    );
  });
  test(
    'legacy TS preferences normalize without importing secrets or nonportable paths',
    () {
      final p = importPreferences(
        jsonEncode({
          'version': 1,
          'locale': 'vi',
          'theme': 'dark',
          'favorites': ['calculate'],
          'drafts': {
            'uppercase': 'Tiếng Việt',
            'jwt': 'secret',
            'http': 'token',
            'env': 'secret',
          },
          'recipes': [
            {
              'version': 1,
              'name': 'Chữ hoa',
              'steps': ['uppercase'],
            },
          ],
          'history': [
            {'uri': 'file:///other-install/a.txt'},
          ],
        }),
      );
      expect(p.locale, 'vi');
      expect(p.drafts, {'uppercase': 'Tiếng Việt'});
      expect(p.toJson().containsKey('history'), false);
      expect(p.recipes.single.steps, ['uppercase']);
    },
  );
  test(
    'Flutter package roundtrip retains Unicode and schedules no migration side effects',
    () {
      final p = HandyPreferences(
        locale: 'vi',
        theme: 'dark',
        favorites: ['calculate'],
        drafts: {'normalize': 'Đặng 😀'},
        recipes: [
          Recipe('Chuẩn hóa', ['normalize']),
        ],
      );
      expect(importPreferences(exportPreferences(p)).toJson(), p.toJson());
    },
  );
  test('unknown versions and corrupt imports do not reset existing state', () {
    final before = HandyPreferences(locale: 'vi');
    for (final input in [
      '{broken',
      'null',
      '{"version":2}',
      '{"format":"handy-tools-settings","version":99,"state":{"version":1}}',
      '{"version":1,"theme":"evil"}',
    ]) {
      expect(() => importPreferences(input), throwsA(anything));
      expect(before.locale, 'vi');
    }
  });
  test(
    'limits, mixed types and sensitive exported drafts rejected or removed',
    () {
      expect(
        () => importPreferences(
          jsonEncode({
            'version': 1,
            'favorites': [1],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => importPreferences(
          jsonEncode({
            'version': 1,
            'drafts': {'x': List.filled(50001, 'x').join()},
          }),
        ),
        throwsFormatException,
      );
      expect(
        exportPreferences(
          HandyPreferences(drafts: {'password': 'do not persist'}),
        ),
        isNot(contains('do not persist')),
      );
    },
  );
  test('export never trusts imported pro entitlement fields', () {
    final p = importPreferences(
      '{"version":1,"pro":true,"entitlement":"PRO_LIFETIME","locale":"en"}',
    );
    expect(exportPreferences(p), isNot(contains('PRO_LIFETIME')));
  });
  test(
    'immutable preference collections prevent accidental partial writes',
    () {
      final p = HandyPreferences(
        favorites: ['calculate'],
        drafts: {'upper': 'x'},
      );
      expect(() => p.favorites.add('x'), throwsUnsupportedError);
      expect(() => p.drafts['upper'] = 'changed', throwsUnsupportedError);
      expect(p.copyWith(theme: 'dark').locale, 'system');
    },
  );
}
