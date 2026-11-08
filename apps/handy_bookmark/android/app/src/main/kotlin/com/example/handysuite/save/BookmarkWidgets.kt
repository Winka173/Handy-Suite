package com.example.handysuite.save

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Handy Bookmark's home-screen widgets. Each reads only the strings the
 * app wrote under its own prefix (`queue_title`, `picks_row2_text`...) and
 * draws them; none reads the library. Taps open links the app resolves.
 */
abstract class BookmarkWidget(
  private val prefix: String,
  private val layout: Int,
  private val rows: IntArray,
  private val gallery: Boolean = false,
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
    views.setTextViewText(R.id.title, get(data, "title") ?: "Handy Bookmark")
    views.setTextViewText(R.id.value, get(data, "value") ?: "")
    views.setTextViewText(R.id.detail, get(data, "detail") ?: "")
    views.setViewVisibility(R.id.detail, if (get(data, "detail").isNullOrEmpty()) View.GONE else View.VISIBLE)
    views.setOnClickPendingIntent(R.id.widget_root, open(context, get(data, "uri") ?: "handy-bookmark://save"))
    for ((i, id) in rows.withIndex()) {
      val uri = get(data, "row${i}_uri")
      val text = get(data, "row${i}_text")
      if (gallery) {
        val cell = CELLS[i]
        val path = get(data, "img$i")
        val picture = path?.let { picture(it) }
        if (uri == null || picture == null) {
          views.setViewVisibility(cell, View.INVISIBLE)
          continue
        }
        views.setViewVisibility(cell, View.VISIBLE)
        views.setImageViewBitmap(IMAGES[i], picture)
        views.setTextViewText(id, text ?: "")
        views.setViewVisibility(id, if (text.isNullOrEmpty()) View.GONE else View.VISIBLE)
        views.setOnClickPendingIntent(cell, open(context, uri))
        continue
      }
      if (text == null) {
        views.setViewVisibility(id, View.GONE)
        continue
      }
      views.setViewVisibility(id, View.VISIBLE)
      views.setTextViewText(id, text)
      uri?.let { views.setOnClickPendingIntent(id, open(context, it)) }
    }
    applyStyle(views) { get(data, it) }
    return views
  }

  /** A gallery picture, read small: widgets have a tight memory budget. */
  private fun picture(path: String) = try {
    val file = File(path)
    if (!file.isFile) null else {
      val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
      BitmapFactory.decodeFile(path, bounds)
      var sample = 1
      while (bounds.outWidth / (sample * 2) >= 320 && bounds.outHeight / (sample * 2) >= 320) sample *= 2
      BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
    }
  } catch (_: Exception) { null }

  private fun color(v: String?): Int? = v?.toLongOrNull(16)?.toInt()

  /**
   * The widget style the app chose (`style_bg`, `style_ink`, `style_muted`,
   * `style_accent`, ARGB hex). Without them the theme's own colours stay.
   */
  private fun applyStyle(views: RemoteViews, get: (String) -> String?) {
    val bg = color(get("style_bg")) ?: return
    val ink = color(get("style_ink")) ?: return
    val muted = color(get("style_muted")) ?: ink
    val accent = color(get("style_accent")) ?: ink
    views.setInt(R.id.bg, "setColorFilter", bg)
    views.setInt(R.id.dot, "setColorFilter", accent)
    views.setTextColor(R.id.title, muted)
    views.setTextColor(R.id.detail, muted)
    views.setTextColor(R.id.value, ink)
    if (!gallery) for (id in rows) views.setTextColor(id, ink)
  }

  companion object {
    val FOUR = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3)
    val CELLS = intArrayOf(R.id.cell0, R.id.cell1, R.id.cell2, R.id.cell3)
    val IMAGES = intArrayOf(R.id.img0, R.id.img1, R.id.img2, R.id.img3)
  }
}

class QuickSaveWidget : BookmarkWidget("save_", R.layout.bm_widget_save, IntArray(0))

class QueueWidget : BookmarkWidget("queue_", R.layout.bm_widget_list, BookmarkWidget.FOUR.copyOf(3))

class ShelfWidget : BookmarkWidget("shelf_", R.layout.bm_widget_list, BookmarkWidget.FOUR.copyOf(3))

class PicksWidget : BookmarkWidget("picks_", R.layout.bm_widget_list, BookmarkWidget.FOUR)

class GalleryWidget : BookmarkWidget("gallery_", R.layout.bm_widget_gallery, BookmarkWidget.FOUR, gallery = true)
