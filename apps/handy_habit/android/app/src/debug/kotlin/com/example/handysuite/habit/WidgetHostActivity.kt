package com.example.handysuite.habit

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.ScrollView

/**
 * Debug builds only: hosts Habit's widgets on a plain screen so they can
 * be checked on an emulator whose launcher has no widget host. Grant it
 * once with `adb shell appwidget grantbind --package <debug package>`.
 * Launch with `--es widgets today,habit,routine,week,year`.
 */
class WidgetHostActivity : Activity() {
  private lateinit var host: AppWidgetHost

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    host = AppWidgetHost(this, 4711)
    val manager = AppWidgetManager.getInstance(this)
    val column = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(24, 48, 24, 48)
      setBackgroundColor(0xFF3A4A5A.toInt())
    }
    val names = (intent.getStringExtra("widgets") ?: "today,habit,routine,week,year").split(",")
    val classes = mapOf(
      "today" to (HandyWidget::class.java to 760),
      "habit" to (SingleHabitWidget::class.java to 260),
      "routine" to (RoutineWidget::class.java to 330),
      "week" to (WeekWidget::class.java to 560),
      "year" to (YearWidget::class.java to 560),
    )
    for (name in names) {
      val (cls, height) = classes[name.trim()] ?: continue
      val provider = ComponentName(this, cls)
      val id = host.allocateAppWidgetId()
      if (!manager.bindAppWidgetIdIfAllowed(id, provider)) {
        host.deleteAppWidgetId(id)
        continue
      }
      val info = manager.getAppWidgetInfo(id)
      val view = host.createView(this, id, info)
      val options = Bundle().apply {
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 340)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height / 3)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 340)
        putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, height / 3)
      }
      manager.updateAppWidgetOptions(id, options)
      view.tag = name
      column.addView(view, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, height).apply {
        bottomMargin = 24
      })
      sendBroadcast(android.content.Intent(this, cls).apply {
        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(id))
      })
    }
    setContentView(ScrollView(this).apply { addView(column) })
  }

  override fun onStart() {
    super.onStart()
    host.startListening()
  }

  override fun onStop() {
    host.stopListening()
    super.onStop()
  }

  override fun onDestroy() {
    host.deleteHost()
    super.onDestroy()
  }
}
