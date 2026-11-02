package com.example.handysuite.recall

import android.content.Intent
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    adopt(intent)
    super.onCreate(savedInstanceState)
  }

  override fun onNewIntent(intent: Intent) {
    adopt(intent)
    super.onNewIntent(intent)
  }

  /// A link from another Handy app (handy-recall://new?…) reaches Flutter
  /// the same way a widget tap does.
  private fun adopt(intent: Intent?) {
    if (intent?.action == Intent.ACTION_VIEW && intent.data?.scheme == "handy-recall" &&
      (intent.dataString?.length ?: 0) <= 3000
    ) intent.action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
  }
}
