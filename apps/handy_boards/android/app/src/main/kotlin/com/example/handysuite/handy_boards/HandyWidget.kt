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
 * The home-screen widget. The app writes what it shows (`title`, `value`,
 * `detail`, `uri`, and `rowN_text` / `rowN_uri` for tappable rows) through
 * home_widget whenever its data changes; nothing here reads the app's data.
 */
class HandyWidget : HomeWidgetProvider() {
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

  private fun views(context: Context, data: SharedPreferences): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.handy_widget)
    views.setTextViewText(R.id.title, data.getString("title", "Handy Boards"))
    views.setTextViewText(R.id.value, data.getString("value", ""))
    views.setTextViewText(R.id.detail, data.getString("detail", ""))
    views.setOnClickPendingIntent(R.id.widget_root, open(context, data.getString("uri", "handy-boards://today")!!))
    for ((i, id) in ROWS.withIndex()) {
      val text = data.getString("row${i}_text", null)
      if (text == null) {
        views.setViewVisibility(id, View.GONE)
        continue
      }
      views.setViewVisibility(id, View.VISIBLE)
      views.setTextViewText(id, text)
      data.getString("row${i}_uri", null)?.let { views.setOnClickPendingIntent(id, open(context, it)) }
    }
    return views
  }

  companion object {
    private val ROWS = intArrayOf(R.id.row0, R.id.row1, R.id.row2)
  }
}
