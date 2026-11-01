import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get nativeCaptureAvailable =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class CaptureResult {
  final String uri, mime;
  final int width, height;
  final int? durationMs, actualStartMs;
  const CaptureResult._(
    this.uri,
    this.mime,
    this.width,
    this.height,
    this.durationMs,
    this.actualStartMs,
  );
  factory CaptureResult.parse(Object? raw) {
    if (raw is! Map) throw const FormatException('Missing capture result');
    final uri = raw['uri'],
        mime = raw['mime'],
        width = raw['width'],
        height = raw['height'],
        duration = raw['durationMs'],
        start = raw['actualStartMs'];
    final parsed = uri is String ? Uri.tryParse(uri) : null;
    if (parsed == null ||
        uri is! String ||
        uri.length > 2048 ||
        !uri.startsWith('file:///') ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        Uri.decodeComponent(uri).split('/').any((s) => s == '..' || s == '.') ||
        parsed.pathSegments.any((s) => s == '..' || s == '.') ||
        uri.runes.any((r) => r < 32) ||
        !{'image/png', 'video/mp4'}.contains(mime) ||
        width is! int ||
        height is! int ||
        width < 1 ||
        height < 1 ||
        width > 16384 ||
        height > 16384 ||
        width * height > 16000000 ||
        mime == 'video/mp4' &&
            (duration is! int || duration < 1 || duration > 300000) ||
        start != null && (start is! int || start < 0 || start > 300000)) {
      throw const FormatException('Invalid native capture result');
    }
    return CaptureResult._(
      uri,
      mime as String,
      width,
      height,
      duration is int ? duration : null,
      start as int?,
    );
  }
}

class CaptureStatus {
  final bool recording, pending;
  final CaptureResult? lastResult;
  final String? error;
  const CaptureStatus(
    this.recording,
    this.pending,
    this.lastResult,
    this.error,
  );
  factory CaptureStatus.parse(Object? raw) {
    if (raw is! Map ||
        raw['recording'] is! bool ||
        raw['pending'] is! bool ||
        raw['error'] != null && raw['error'] is! String)
      throw const FormatException('Invalid capture status');
    return CaptureStatus(
      raw['recording'] as bool,
      raw['pending'] as bool,
      raw['lastResult'] == null ? null : CaptureResult.parse(raw['lastResult']),
      raw['error'] as String?,
    );
  }
}

/// Native code alone resolves these URIs, and accepts only its owned captures.
class NativeCapture {
  static const _channel = MethodChannel('handy_capture');
  const NativeCapture();
  void _supported() {
    if (!nativeCaptureAvailable)
      throw UnsupportedError(
        'Native capture is available on Android and iOS. Import images/videos on other platforms.',
      );
  }

  Future<CaptureStatus> status() async {
    _supported();
    return CaptureStatus.parse(await _channel.invokeMethod<Object?>('status'));
  }

  Future<CaptureResult> screenshot({int delayMs = 3000}) async {
    _supported();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      throw UnsupportedError(
        'iOS cannot capture other apps. Use the system screenshot buttons, then import the image.',
      );
    }
    if (delayMs < 0 || delayMs > 10000)
      throw const FormatException('Delay: 0-10000 ms');
    return CaptureResult.parse(
      await _channel.invokeMethod<Object?>('screenshot', {'delayMs': delayMs}),
    );
  }

  Future<void> startRecording() async {
    _supported();
    await _channel.invokeMethod<Object?>('startRecording');
  }

  Future<CaptureResult> stopRecording() async {
    _supported();
    return CaptureResult.parse(
      await _channel.invokeMethod<Object?>('stopRecording'),
    );
  }

  Future<void> cancel() async {
    _supported();
    await _channel.invokeMethod<void>('cancel');
  }

  Future<void> clear() async {
    _supported();
    await _channel.invokeMethod<void>('clear');
  }

  Future<Uint8List> read(CaptureResult capture) async {
    _supported();
    final bytes = await _channel.invokeMethod<Uint8List>('read', {
      'uri': capture.uri,
    });
    if (bytes == null ||
        bytes.length > (capture.mime == 'image/png' ? 8000000 : 30000000) ||
        bytes.length < 8 ||
        capture.mime == 'image/png' &&
            bytes.take(8).join(',') != '137,80,78,71,13,10,26,10' ||
        capture.mime == 'video/mp4' &&
            String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp') {
      throw const FormatException('Capture bytes failed verification');
    }
    return bytes;
  }

  Future<CaptureResult> importVideo(Uint8List bytes) async {
    _supported();
    if (bytes.length < 33 ||
        bytes.length > 30000000 ||
        String.fromCharCodes(bytes.sublist(4, 8)) != 'ftyp')
      throw const FormatException('Choose MP4 up to 30 MB');
    return CaptureResult.parse(
      await _channel.invokeMethod<Object?>('importVideo', {'bytes': bytes}),
    );
  }

  Future<CaptureResult> transform(
    CaptureResult input, {
    int rotation = 0,
    int maxEdge = 720,
    bool mute = false,
    String format = 'mp4',
  }) async {
    _supported();
    if (input.mime != 'video/mp4' ||
        !{0, 90, 180, 270}.contains(rotation) ||
        !{240, 480, 720, 1280}.contains(maxEdge) ||
        format != 'mp4') {
      throw const FormatException(
        'Choose MP4, rotation 0/90/180/270 and maximum edge 240/480/720/1280',
      );
    }
    return CaptureResult.parse(
      await _channel.invokeMethod<Object?>('transform', {
        'uri': input.uri,
        'rotation': rotation,
        'maxEdge': maxEdge,
        'mute': mute,
      }),
    );
  }

  Future<CaptureResult> trim(
    CaptureResult input,
    int startMs,
    int endMs,
  ) async {
    _supported();
    if (input.mime != 'video/mp4' ||
        startMs < 0 ||
        endMs <= startMs ||
        endMs > input.durationMs!)
      throw const FormatException('Invalid video trim range');
    return CaptureResult.parse(
      await _channel.invokeMethod<Object?>('trim', {
        'uri': input.uri,
        'startMs': startMs,
        'endMs': endMs,
      }),
    );
  }

  Future<CaptureResult> frame(CaptureResult input, int timeMs) async {
    _supported();
    if (input.mime != 'video/mp4' || timeMs < 0 || timeMs >= input.durationMs!)
      throw const FormatException('Invalid frame time');
    return CaptureResult.parse(
      await _channel.invokeMethod<Object?>('frame', {
        'uri': input.uri,
        'timeMs': timeMs,
      }),
    );
  }

  Future<CaptureResult> combine(List<CaptureResult> inputs) async {
    _supported();
    if (inputs.length < 2 ||
        inputs.length > 20 ||
        inputs.any((c) => c.mime != 'video/mp4'))
      throw const FormatException('Choose 2-20 compatible MP4 clips');
    return CaptureResult.parse(
      await _channel.invokeMethod<Object?>('combine', {
        'uris': [for (final c in inputs) c.uri],
      }),
    );
  }
}
