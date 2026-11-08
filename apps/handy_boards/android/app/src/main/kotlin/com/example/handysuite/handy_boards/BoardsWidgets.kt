package com.example.handysuite.handy_boards

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The other Handy Boards widgets. Each reads only the strings the app wrote
 * under its own prefix (`progress_title`, `week_row3_text`...) and draws
 * them; none of them reads the boards. Taps open links the app resolves.
 */
abstract class PrefixedWidget(
  private val prefix: String,
  private val layout: Int,
  private val rows: IntArray,
  private val hasProgress: Boolean = false,
) : HomeWidgetProvider() {
  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      appWidgetManager.updateAppWidget(widgetId, views(context, widgetData))
    }
  }

  private fun open(context: Context, uri: String): PendingIntent =
    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

  private fun get(data: SharedPreferences, key: String): String? = data.getString(prefix + key, null)

  private fun views(context: Context, data: SharedPreferences): RemoteViews {
    val views = RemoteViews(context.packageName, layout)
    views.setTextViewText(R.id.title, get(data, "title") ?: "Handy Boards")
    views.setTextViewText(R.id.value, get(data, "value") ?: "")
    views.setTextViewText(R.id.detail, get(data, "detail") ?: "")
    views.setOnClickPendingIntent(R.id.widget_root, open(context, get(data, "uri") ?: "handy-boards://today"))
    if (hasProgress) {
      views.setProgressBar(R.id.progress, 100, (get(data, "progress") ?: "0").toIntOrNull() ?: 0, false)
    }
    for ((i, id) in rows.withIndex()) {
      val text = get(data, "row${i}_text")
      if (text == null) {
        views.setViewVisibility(id, View.GONE)
        continue
      }
      views.setViewVisibility(id, View.VISIBLE)
      views.setTextViewText(id, text)
      get(data, "row${i}_uri")?.let { views.setOnClickPendingIntent(id, open(context, it)) }
    }
    return views
  }
}

private val THREE = intArrayOf(R.id.row0, R.id.row1, R.id.row2)

class ProgressWidget : PrefixedWidget("progress_", R.layout.handy_widget_progress, IntArray(0), true)

class UpcomingWidget : PrefixedWidget("upcoming_", R.layout.handy_widget, THREE)

class WorkWidget : PrefixedWidget("work_", R.layout.handy_widget, THREE)

class WeekWidget :
  PrefixedWidget(
    "week_",
    R.layout.handy_widget_week,
    intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3, R.id.row4, R.id.row5, R.id.row6),
  )
