import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/metadata_client.dart';

void main() {
  test(
    'explicit public dart.dev metadata request uses the real pinned client',
    () async {
      final client = MetadataClient();
      try {
        final result = await HttpOverrides.runWithHttpOverrides(
          () => client.fetch('https://dart.dev/'),
          RealHttp(),
        );
        final report = {
          'scope': 'explicit curated public test URL; no user data',
          'status': result.status,
          'hasTitle': result.title?.isNotEmpty == true,
          'errorCode': result.errorCode,
          'noCredentials': true,
        };
        await File(
          '../../docs/qa/evidence/save-live-metadata.json',
        ).writeAsString(jsonEncode(report));
        expect(result.status, anyOf('complete', 'partial'));
        expect(result.title, contains('Dart'));
      } finally {
        client.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}

class RealHttp extends HttpOverrides {}
