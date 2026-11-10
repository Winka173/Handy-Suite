package com.example.handysuite.habit

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "handy_habit/system").setMethodCallHandler { call, result ->
      when (call.method) {
        "status" -> {
          val alarms = getSystemService(Context.ALARM_SERVICE) as AlarmManager
          val power = getSystemService(Context.POWER_SERVICE) as PowerManager
          result.success(mapOf(
            "exactAllowed" to (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()),
            "batteryExempt" to power.isIgnoringBatteryOptimizations(packageName)
          ))
        }
        "battery", "notifications" -> {
          try {
            val intent = if (call.method == "battery") Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
              else Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            startActivity(intent)
            result.success(null)
          } catch (_: Exception) {
            try {
              startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
              result.success(null)
            } catch (_: Exception) { result.error("unavailable", "System settings unavailable", null) }
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}
