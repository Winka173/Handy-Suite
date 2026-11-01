import 'dart:convert';
import 'package:handy_core/handy_core.dart';

class Recipe {
  final String name;
  final List<String> steps;
  Recipe(this.name, Iterable<String> steps) : steps = List.unmodifiable(steps) {
    if (name.trim().isEmpty ||
        name.length > 200 ||
        this.steps.isEmpty ||
        this.steps.length > 20 ||
        this.steps.any(
          (s) => !RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,99}$').hasMatch(s),
        ))
      throw const FormatException('Invalid workflow');
  }
  factory Recipe.fromJson(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['name'] is! String ||
        value['steps'] is! List ||
        (value['steps'] as List).any((s) => s is! String))
      throw const FormatException('Unsupported workflow');
    return Recipe(value['name'], (value['steps'] as List).cast<String>());
  }
  Map<String, Object> toJson() => {'version': 1, 'name': name, 'steps': steps};
  String export() => jsonEncode(toJson());
}

class WorkflowStep {
  final String id, inputMime, outputMime;
  final Future<String> Function(String input) run;
  const WorkflowStep(this.id, this.inputMime, this.outputMime, this.run);
}

List<WorkflowStep> plan(
  Recipe recipe,
  Map<String, WorkflowStep> registry,
  String inputMime,
) {
  final result = <WorkflowStep>[];
  var mime = inputMime;
  for (final id in recipe.steps) {
    final step = registry[id];
    if (step == null || step.id != id || step.inputMime != mime)
      throw FormatException('Unknown or incompatible workflow step: $id');
    result.add(step);
    mime = step.outputMime;
  }
  return List.unmodifiable(result);
}

Future<String> execute(
  Recipe recipe,
  Map<String, WorkflowStep> registry,
  String input, {
  String inputMime = 'text/plain',
  CancellationToken? cancellation,
  void Function(int, int)? progress,
}) async {
  final steps = plan(recipe, registry, inputMime);
  if (utf8.encode(input).length > 1000000)
    throw const FormatException('Workflow input exceeds 1 MB');
  var output = input;
  for (var i = 0; i < steps.length; i++) {
    // A completed Future alone only yields to microtasks. Yield an event turn
    // so pointer/keyboard cancellation can arrive between synchronous transforms.
    await Future<void>.delayed(Duration.zero);
    cancellation?.check();
    output = await steps[i].run(output);
    cancellation?.check();
    if (utf8.encode(output).length > 1000000)
      throw const FormatException('Workflow output exceeds 1 MB');
    progress?.call(i + 1, steps.length);
  }
  return output;
}

class BatchOutcome<T> {
  final T? value;
  final Object? error;
  const BatchOutcome.success(this.value) : error = null;
  const BatchOutcome.failure(this.error) : value = null;
}

Future<List<BatchOutcome<R>>> batch<T, R>(
  Iterable<T> inputs,
  Future<R> Function(T) process, {
  CancellationToken? cancellation,
  void Function(int, int)? progress,
}) async {
  final list = inputs.take(51).toList();
  if (list.length > 50) throw const FormatException('Batch limit: 50');
  final result = <BatchOutcome<R>>[];
  for (final input in list) {
    await Future<void>.delayed(Duration.zero);
    cancellation?.check();
    try {
      final value = await process(input);
      cancellation?.check();
      result.add(BatchOutcome.success(value));
    } on Cancelled {
      rethrow;
    } catch (e) {
      result.add(BatchOutcome.failure(e));
    }
    progress?.call(result.length, list.length);
  }
  return result;
}
