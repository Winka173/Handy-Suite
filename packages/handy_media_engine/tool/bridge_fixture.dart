import 'dart:io';
import 'package:handy_media_engine/handy_media_engine.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2)
    throw ArgumentError('Supply legacy input ZIP and Dart output ZIP');
  final source = await File(args[0]).readAsBytes(),
      bundle = parsePortableProject(source);
  final output = buildPortableProject(bundle.project, bundle.assets);
  await File(args[1]).writeAsBytes(output, flush: true);
  stdout.writeln(
    'Dart reopened legacy Snap ZIP and re-exported ${bundle.project.steps.length} steps / ${bundle.project.steps.first.annotations.length} annotation kinds',
  );
}
