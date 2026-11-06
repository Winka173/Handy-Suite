import 'package:flutter/widgets.dart';
import 'package:handy_ads/handy_ads.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  installHandyAds();
  runApp(const KeepApp());
}
