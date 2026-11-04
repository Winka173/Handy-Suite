import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:handy_workflow/handy_workflow.dart';

/// Pilot defaults. Other apps must supply their own safe registry instead of
/// interpreting unknown tool IDs as migratable data.
const Set<String> toolsPreferenceIds = {
  'calculate',
  // The calc notebook's sheet, kept as a draft.
  'notebook',
  // The tools opened last, newest first, as a comma list (no contents).
  'recent',
  'units',
  'loan',
  'compound',
  'percent',
  'dates',
  'normalize',
  'deduplicate',
  'sort',
  'uppercase',
  'lowercase',
  'accents',
  'count',
  'contrast',
  'tax',
  'split-bill',
  'ratio',
  'manual-exchange',
  'business-days',
  'title-case',
  'sentence-case',
  'literal-replace',
  'colors',
};
const Set<String> toolsTextWorkflowIds = {
  'normalize',
  'deduplicate',
  'sort',
  'uppercase',
  'lowercase',
  'accents',
  'title-case',
  'sentence-case',
};

class HandyPreferences {
  final String locale, theme;
  final List<String> favorites;
  final Map<String, String> drafts;
  final List<Recipe> recipes;
  HandyPreferences({
    this.locale = 'system',
    this.theme = 'system',
    Iterable<String> favorites = const [],
    Map<String, String> drafts = const {},
    Iterable<Recipe> recipes = const [],
  }) : favorites = List.unmodifiable(favorites),
       drafts = Map.unmodifiable(drafts),
       recipes = List.unmodifiable(recipes);
  factory HandyPreferences.fromJson(
    Object? input, {
    Set<String> knownTools = toolsPreferenceIds,
    Set<String> workflowSteps = toolsTextWorkflowIds,
  }) {
    if (input is! Map || input['version'] != 1)
      throw const FormatException('Unsupported settings version');
    final locale = input['locale'] ?? 'system',
        theme = input['theme'] ?? 'system';
    if (!['system', 'en', 'vi'].contains(locale) ||
        !['system', 'light', 'dark'].contains(theme))
      throw const FormatException('Invalid locale/theme');
    final favorites = input['favorites'] ?? [],
        drafts = input['drafts'] ?? {},
        recipes = input['recipes'] ?? [];
    if (favorites is! List ||
        favorites.length > 100 ||
        favorites.any((s) => s is! String || !knownTools.contains(s)) ||
        drafts is! Map ||
        drafts.length > 100 ||
        recipes is! List ||
        recipes.length > 30)
      throw const FormatException('Invalid settings limits');
    final safeDrafts = <String, String>{};
    for (final entry in drafts.entries) {
      if (entry.key is! String ||
          (entry.key as String).length > 100 ||
          entry.value is! String ||
          (entry.value as String).length > 50000)
        throw const FormatException('Invalid draft');
      if (knownTools.contains(entry.key)) safeDrafts[entry.key] = entry.value;
    }
    final parsedRecipes = recipes.map(Recipe.fromJson).toList();
    for (final recipe in parsedRecipes) {
      if (recipe.steps.any((id) => !workflowSteps.contains(id))) {
        throw const FormatException(
          'Settings contain an unknown or incompatible text workflow step',
        );
      }
    }
    return HandyPreferences(
      locale: locale,
      theme: theme,
      favorites: favorites.cast<String>().toSet(),
      drafts: safeDrafts,
      recipes: parsedRecipes,
    );
  }
  Map<String, Object> toJson() => {
    'version': 1,
    'locale': locale,
    'theme': theme,
    'favorites': favorites,
    'drafts': drafts,
    'recipes': recipes.map((r) => r.toJson()).toList(),
  };
  HandyPreferences copyWith({
    String? locale,
    String? theme,
    Iterable<String>? favorites,
    Map<String, String>? drafts,
    Iterable<Recipe>? recipes,
  }) => HandyPreferences(
    locale: locale ?? this.locale,
    theme: theme ?? this.theme,
    favorites: favorites ?? this.favorites,
    drafts: drafts ?? this.drafts,
    recipes: recipes ?? this.recipes,
  );
}

HandyPreferences importPreferences(
  String text, {
  String app = 'tools',
  Set<String> knownTools = toolsPreferenceIds,
  Set<String> workflowSteps = toolsTextWorkflowIds,
}) {
  _settingsApp(app);
  if (utf8.encode(text).length > 1000000)
    throw const FormatException('Settings limit: 1 MB');
  final raw = jsonDecode(text);
  HandyPreferences parse(Object? value) => HandyPreferences.fromJson(
    value,
    knownTools: knownTools,
    workflowSteps: workflowSteps,
  );
  // Actual React Native PreferencesBackup envelope. Detect it before the raw
  // state fallback so nested preferences are never silently replaced by defaults.
  if (raw is Map &&
      (raw.containsKey('app') || raw.containsKey('preferences'))) {
    if (raw['version'] != 1 ||
        raw['app'] != app ||
        raw['preferences'] is! Map ||
        raw['recipes'] is! List) {
      throw const FormatException(
        'Unsupported legacy settings app, version or structure',
      );
    }
    final preferences = raw['preferences'] as Map;
    if (!['system', 'en', 'vi'].contains(preferences['locale']) ||
        !['system', 'light', 'dark'].contains(preferences['theme']) ||
        preferences['favorites'] is! List) {
      throw const FormatException(
        'Legacy preferences are incomplete or invalid',
      );
    }
    return parse({
      'version': 1,
      'locale': preferences['locale'],
      'theme': preferences['theme'],
      'favorites': preferences['favorites'],
      'recipes': raw['recipes'],
      // RN exports never included drafts/history or store entitlements.
      'drafts': <String, String>{},
    });
  }
  if (raw is Map && raw['format'] == 'handy-$app-settings') {
    if (raw['version'] != 1)
      throw const FormatException('Unsupported settings package');
    return parse(raw['state']);
  }
  if (raw is Map && raw.containsKey('format'))
    throw const FormatException('Unsupported settings format');
  if (app != 'tools')
    throw const FormatException('App-specific settings envelope required');
  return parse(raw);
}

String exportPreferences(
  HandyPreferences preferences, {
  String app = 'tools',
  bool includeDrafts = true,
  Set<String> knownTools = toolsPreferenceIds,
  Set<String> workflowSteps = toolsTextWorkflowIds,
}) {
  _settingsApp(app);
  return jsonEncode({
    'format': 'handy-$app-settings',
    'version': 1,
    'state': HandyPreferences.fromJson(
      (includeDrafts ? preferences : preferences.copyWith(drafts: {})).toJson(),
      knownTools: knownTools,
      workflowSteps: workflowSteps,
    ).toJson(),
  });
}

void _settingsApp(String app) {
  if (!{'tools', 'docs', 'media', 'dev', 'keep', 'recall'}.contains(app)) {
    throw const FormatException('Unknown settings app');
  }
}

abstract interface class PreferencesRepository {
  Future<HandyPreferences> load();
  Future<void> save(HandyPreferences state);
}

class DevicePreferencesRepository implements PreferencesRepository {
  final String namespace;
  final SharedPreferencesAsync _prefs;
  final Set<String> knownTools, workflowSteps;
  DevicePreferencesRepository(
    this.namespace, {
    SharedPreferencesAsync? preferences,
    this.knownTools = toolsPreferenceIds,
    this.workflowSteps = toolsTextWorkflowIds,
  }) : _prefs = preferences ?? SharedPreferencesAsync() {
    if (namespace.length > 80 ||
        !RegExp(r'^handy-[a-z]+(?:-[a-z]+)*$').hasMatch(namespace))
      throw ArgumentError('Invalid app namespace');
  }
  String get key => '$namespace-flutter-preferences-v1';
  @override
  Future<HandyPreferences> load() async {
    final text = await _prefs.getString(key);
    return text == null
        ? HandyPreferences()
        : importPreferences(
            text,
            knownTools: knownTools,
            workflowSteps: workflowSteps,
          );
  }

  @override
  Future<void> save(HandyPreferences state) async {
    final text = exportPreferences(
      state,
      knownTools: knownTools,
      workflowSteps: workflowSteps,
    );
    if (utf8.encode(text).length > 1000000)
      throw const FormatException('Settings limit: 1 MB');
    await _prefs.setString(key, text);
  }
}
