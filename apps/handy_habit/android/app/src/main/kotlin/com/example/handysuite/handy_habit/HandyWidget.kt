package com.example.handysuite.habit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import android.net.Uri

/** Strings-only renderer. Each type has shared selection; no database or background check-in. */
open class HabitWidgetProvider(private val prefix: String) : HomeWidgetProvider() {
  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
    for (id in ids) manager.updateAppWidget(id, views(context, data, manager.getAppWidgetOptions(id)))
  }
  override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
    super.onAppWidgetOptionsChanged(context, manager, id, options)
    manager.updateAppWidget(id, views(context, HomeWidgetPlugin.getData(context), options))
  }
  private fun open(context: Context, uri: String): PendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
  private fun views(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
    fun str(key: String, fallback: String = "") = data.getString("$prefix$key", fallback) ?: fallback
    val night = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    fun colour(key: String, fallback: String): Int = try { Color.parseColor(str("${if (night) "dark" else "light"}_$key", fallback)) } catch (_: Exception) { Color.parseColor(fallback) }
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
    val large = height >= 300
    val layout = when (str("palette")) {
      "grove" -> if (large) R.layout.handy_widget_grove_large else R.layout.handy_widget_grove_compact
      "ochre" -> if (large) R.layout.handy_widget_ochre_large else R.layout.handy_widget_ochre_compact
      else -> if (large) R.layout.handy_widget else R.layout.handy_widget_compact
    }
    val views = RemoteViews(context.packageName, layout)
    val ink = colour("ink", if (night) "#FFF4EF" else "#281B18")
    val muted = colour("muted", if (night) "#CDBAB2" else "#69534B")
    val accent = colour("accent", if (night) "#F07755" else "#B42318")
    views.setInt(R.id.widget_root, "setBackgroundResource", when (str("palette")) { "grove" -> R.drawable.handy_widget_grove; "ochre" -> R.drawable.handy_widget_ochre; else -> R.drawable.handy_widget_bg })
    views.setTextViewText(R.id.title, str("title", "Handy Habit"))
    views.setTextViewText(R.id.value, str("value", context.getString(R.string.handy_widget_open)))
    views.setTextViewText(R.id.detail, str("detail"))
    views.setTextColor(R.id.title, muted)
    views.setTextColor(R.id.detail, muted)
    views.setTextColor(R.id.value, ink)
    views.setTextColor(R.id.bead, accent)
    views.setOnClickPendingIntent(R.id.widget_root, open(context, str("uri", "handy-habit://today")))
    val progress = str("progress").toIntOrNull()
    views.setViewVisibility(R.id.progress, if (progress == null) View.GONE else View.VISIBLE)
    views.setProgressBar(R.id.progress, 100, progress?.coerceIn(0,100) ?: 0, false)
    if (large) {
      val scale = context.resources.configuration.fontScale.coerceAtLeast(1f)
      val availableRows = ((height - 150 * scale) / 48).toInt().coerceIn(0,3)
      for ((i, id) in ROWS.withIndex()) {
        val text = str("row${i}_text")
        views.setViewVisibility(id, if (text.isEmpty() || i >= availableRows) View.GONE else View.VISIBLE)
        views.setTextViewText(id, text)
        views.setTextColor(id, ink)
        views.setOnClickPendingIntent(id, open(context, str("row${i}_uri", "handy-habit://today")))
      }
    }
    return views
  }
  companion object { private val ROWS = intArrayOf(R.id.row0, R.id.row1, R.id.row2) }
}
class HandyWidget : HabitWidgetProvider("")
class SingleHabitWidget : HabitWidgetProvider("habit_")
class RoutineWidget : HabitWidgetProvider("routine_")
