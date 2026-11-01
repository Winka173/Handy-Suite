import 'dart:math';

/// A unique id: the prefix, the time and a random part.
String captureId(String prefix) =>
    '$prefix-${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';

/// Where a guide keeps one of its pictures.
String imageUri(String projectId) =>
    'file:///handy-media/$projectId/${captureId('image')}.png';
