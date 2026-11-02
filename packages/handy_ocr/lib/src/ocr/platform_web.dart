import 'engine.dart';

/// Browsers get no on-device engine here: nothing is uploaded instead.
(OcrEngine, String)? platformOcrEngine() => null;
