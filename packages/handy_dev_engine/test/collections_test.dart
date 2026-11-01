import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

ApiRequest req(String id) => ApiRequest(
  id: id,
  name: id,
  url: 'https://example.com/?token=QUERY_SECRET',
  method: 'POST',
  body: 'BODY_SECRET',
  headers: {'X-Key': 'HEADER_SECRET'},
  auth: const ApiAuth.bearer('TOKEN_SECRET'),
);
void main() {
  test(
    'v1 flat workspace migrates to General without dropping IDs or session data',
    () {
      final original = req('legacy'),
          workspace = parseWorkspace(
            jsonEncode({
              'version': 1,
              'requests': [original.toJson()],
              'environments': [
                ApiEnvironment(
                  id: 'env',
                  name: 'Local',
                  values: {'BASE': 'ENV_SECRET'},
                ).toJson(),
              ],
            }),
          );
      expect(workspace.collections.single.id, 'general');
      expect(workspace.collections.single.requestIds, ['legacy']);
      expect(workspace.requests.single.toJson(), original.toJson());
      expect(workspace.environments.single.values['BASE'], 'ENV_SECRET');
      expect(workspace.toJson()['version'], 2);
      expect(
        parseWorkspace(jsonEncode(workspace.toJson())).requests.single.toJson(),
        original.toJson(),
      );
    },
  );
  test(
    'create/rename/move/duplicate/delete collections preserve request and env membership',
    () {
      var w = createCollection(
        createCollection(emptyWorkspace(), 'a', 'Alpha'),
        'b',
        'Beta',
      );
      w = saveRequest(w, req('r1'), collectionId: 'a');
      w = saveRequest(w, req('r2'), collectionId: 'b');
      w = saveRequest(w, req('r1').copyWith(name: 'Changed'));
      expect(w.collections.firstWhere((c) => c.id == 'a').requestIds, ['r1']);
      w = saveEnvironment(
        w,
        ApiEnvironment(id: 'e', name: 'Local', values: {'X': 'private'}),
      );
      expect(w.collections.length, 3);
      w = renameCollection(w, 'a', 'Renamed');
      expect(w.collections.firstWhere((c) => c.id == 'a').name, 'Renamed');
      expect(() => removeCollection(w, 'a'), throwsFormatException);
      w = removeCollection(w, 'a', moveTo: 'b');
      expect(w.requests.length, 2);
      expect(w.collections.firstWhere((c) => c.id == 'b').requestIds, [
        'r2',
        'r1',
      ]);
      expect(w.environments.single.id, 'e');
      w = removeRequest(w, 'r2');
      expect(w.collections.firstWhere((c) => c.id == 'b').requestIds, ['r1']);
      w = saveRequest(
        w,
        w.requests.single.copyWith(id: 'copy'),
        collectionId: 'b',
      );
      expect(w.collections.firstWhere((c) => c.id == 'b').requestIds, [
        'r1',
        'copy',
      ]);
      expect(
        () => w.collections.first.requestIds.add('lost'),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'collection export/import roundtrip keeps grouping while removing secrets by default',
    () {
      var w = createCollection(emptyWorkspace(), 'a', 'Collection A');
      w = saveRequest(w, req('r1'), collectionId: 'a');
      w = saveEnvironment(
        w,
        ApiEnvironment(id: 'e', name: 'Local', values: {'BASE': 'ENV_SECRET'}),
      );
      final output = exportWorkspace(w), restored = parseWorkspace(output);
      for (final secret in [
        'QUERY_SECRET',
        'BODY_SECRET',
        'HEADER_SECRET',
        'TOKEN_SECRET',
        'ENV_SECRET',
      ]) {
        expect(output, isNot(contains(secret)));
      }
      expect(
        restored.collections.map((c) => c.toJson()),
        w.collections.map((c) => c.toJson()),
      );
      expect(exportWorkspace(restored), output);
    },
  );
  test(
    'dangling/duplicate/missing memberships and collection limits reject before persistence',
    () {
      final good = saveRequest(emptyWorkspace(), req('r1')).toJson();
      for (final collections in [
        [],
        [
          {'id': 'a', 'name': 'A', 'requestIds': []},
        ],
        [
          {
            'id': 'a',
            'name': 'A',
            'requestIds': ['unknown'],
          },
        ],
        [
          {
            'id': 'a',
            'name': 'A',
            'requestIds': ['r1'],
          },
          {
            'id': 'b',
            'name': 'B',
            'requestIds': ['r1'],
          },
        ],
      ]) {
        expect(
          () =>
              parseWorkspace(jsonEncode({...good, 'collections': collections})),
          throwsFormatException,
        );
      }
      expect(
        () => removeCollection(emptyWorkspace(), 'general'),
        throwsFormatException,
      );
      expect(
        () => saveRequest(emptyWorkspace(), req('r1'), collectionId: 'missing'),
        throwsFormatException,
      );
      var w = emptyWorkspace();
      for (var i = 0; i < 29; i++) {
        w = createCollection(w, 'c$i', 'C$i');
      }
      expect(
        () => createCollection(w, 'overflow', 'Overflow'),
        throwsFormatException,
      );
    },
  );
}
