package com.example.handysuite.habit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.time.LocalDate

/**
 * Handy Habit's home-screen widgets. Each draws only what the app wrote
 * (see lib/widget_data.dart): words, bead strings as letters, today's fill
 * and the habit's colour. Tapping today's bead fills it here at once, then
 * the app records the check-in in the background and rewrites the data.
 */
object Beads {
  fun dp(context: Context, v: Float) =
    TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, context.resources.displayMetrics)

  fun colour(s: String?, fallback: Int): Int = try {
    if (s.isNullOrEmpty()) fallback else Color.parseColor(s)
  } catch (_: Exception) { fallback }

  /** One bead, centred in a cell of [size] px. */
  private fun bead(c: Canvas, cx: Float, cy: Float, size: Float, letter: Char, color: Int, ring: Int) {
    val r = size / 2f * 0.86f
    val stroke = maxOf(2f, size / 11f)
    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
    val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE; strokeWidth = stroke; this.color = ring
    }
    when (letter) {
      'c' -> c.drawCircle(cx, cy, r, fill)
      'p' -> {
        c.drawCircle(cx, cy, r - stroke / 2, line.apply { this.color = withAlpha(color, 90) })
        c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), -90f, 180f, true, fill)
      }
      's' -> {
        c.drawCircle(cx, cy, r - stroke / 2, line)
        c.drawLine(cx - r * .45f, cy, cx + r * .45f, cy, line)
      }
      'z' -> c.drawCircle(cx, cy, r * .82f, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = withAlpha(ring, 70) })
      'v' -> {
        c.drawCircle(cx, cy, r - stroke / 2, line)
        c.drawCircle(cx, cy, r * .55f, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = ring })
      }
      'n' -> c.drawCircle(cx, cy, r * .2f, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = withAlpha(ring, 120) })
      'x' -> c.drawCircle(cx, cy, r - stroke / 2, line.apply { this.color = withAlpha(ring, 70); strokeWidth = stroke * .6f })
      else -> c.drawCircle(cx, cy, r - stroke / 2, line)
    }
  }

  fun withAlpha(color: Int, alpha: Int) = Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

  /** A string of beads in one row, [cell] dp each. */
  fun row(context: Context, letters: String, color: Int, ring: Int, cell: Float): Bitmap {
    val size = dp(context, cell)
    val n = maxOf(1, letters.length)
    val bmp = Bitmap.createBitmap((size * n).toInt(), size.toInt(), Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    letters.forEachIndexed { i, ch -> bead(c, size * i + size / 2, size / 2, size * .82f, ch, color, ring) }
    return bmp
  }

  /** A grid, a column per week and a row per weekday ([letters] by week). */
  fun grid(context: Context, letters: String, color: Int, ring: Int, cell: Float, rows: Int = 7): Bitmap {
    val size = dp(context, cell)
    val cols = maxOf(1, (letters.length + rows - 1) / rows)
    val bmp = Bitmap.createBitmap((size * cols).toInt(), (size * rows).toInt(), Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    letters.forEachIndexed { i, ch ->
      bead(c, size * (i / rows) + size / 2, size * (i % rows) + size / 2, size * .84f, ch, color, ring)
    }
    return bmp
  }

  /** Today's bead: a ring that fills clockwise, then a full bead with a tick. */
  fun today(context: Context, fill: Int, color: Int, ring: Int, sizeDp: Float, plus: Boolean): Bitmap {
    val size = dp(context, sizeDp)
    val bmp = Bitmap.createBitmap(size.toInt(), size.toInt(), Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val cx = size / 2; val r = size / 2 * .82f
    val stroke = size / 9f
    if (fill >= 100) {
      c.drawCircle(cx, cx, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color })
      val ink = if (luminance(color) > .45) Color.BLACK else Color.WHITE
      val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeWidth = stroke; this.color = ink
        strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
      }
      val p = Path().apply {
        moveTo(cx - r * .42f, cx + r * .02f)
        lineTo(cx - r * .1f, cx + r * .32f)
        lineTo(cx + r * .45f, cx - r * .3f)
      }
      c.drawPath(p, tick)
      return bmp
    }
    val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE; strokeWidth = stroke * .8f; this.color = withAlpha(color, 80)
    }
    c.drawCircle(cx, cx, r - stroke / 2, track)
    if (fill > 0) {
      val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeWidth = stroke * 1.3f; this.color = color; strokeCap = Paint.Cap.ROUND
      }
      val o = r - stroke / 2
      c.drawArc(RectF(cx - o, cx - o, cx + o, cx + o), -90f, 360f * fill / 100f, false, arc)
    }
    if (plus) {
      val pen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeWidth = stroke * .8f; this.color = color; strokeCap = Paint.Cap.ROUND
      }
      c.drawLine(cx - r * .32f, cx, cx + r * .32f, cx, pen)
      c.drawLine(cx, cx - r * .32f, cx, cx + r * .32f, pen)
    }
    return bmp
  }

  /** Letters above the columns of a [row] of the same [cell]. */
  fun labels(context: Context, labels: List<String>, ink: Int, cell: Float): Bitmap {
    val size = dp(context, cell)
    val h = dp(context, 14f)
    val bmp = Bitmap.createBitmap((size * maxOf(1, labels.size)).toInt(), h.toInt(), Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = ink; textSize = dp(context, 10f); textAlign = Paint.Align.CENTER
    }
    labels.forEachIndexed { i, s -> c.drawText(s, size * i + size / 2, h * .8f, p) }
    return bmp
  }

  private fun luminance(c: Int) =
    (0.2126 * Color.red(c) + 0.7152 * Color.green(c) + 0.0722 * Color.blue(c)) / 255.0
}

/** What every Habit widget shares: data, colours, links, the new day. */
abstract class HabitWidget(protected val prefix: String) : AppWidgetProvider() {
  override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
    val data = HomeWidgetPlugin.getData(context)
    refreshIfStale(context, data)
    for (id in ids) manager.updateAppWidget(id, render(context, data, manager.getAppWidgetOptions(id)))
  }

  override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
    super.onAppWidgetOptionsChanged(context, manager, id, options)
    manager.updateAppWidget(id, render(context, HomeWidgetPlugin.getData(context), options))
  }

  abstract fun render(context: Context, data: SharedPreferences, options: Bundle): RemoteViews

  protected fun str(data: SharedPreferences, key: String, fallback: String = "") =
    data.getString(prefix + key, null) ?: fallback

  protected fun night(context: Context) =
    context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

  protected fun colour(context: Context, data: SharedPreferences, key: String, light: String, dark: String): Int {
    val n = night(context)
    return Beads.colour(str(data, "${if (n) "dark" else "light"}_$key"), Color.parseColor(if (n) dark else light))
  }

  protected fun ink(c: Context, d: SharedPreferences) = colour(c, d, "ink", "#FF281B18", "#FFFFF4EF")
  protected fun muted(c: Context, d: SharedPreferences) = colour(c, d, "muted", "#FF69534B", "#FFCDBAB2")
  protected fun accent(c: Context, d: SharedPreferences) = colour(c, d, "accent", "#FFB42318", "#FFF07755")

  protected fun ground(views: RemoteViews, data: SharedPreferences) {
    views.setInt(R.id.widget_root, "setBackgroundResource", when (str(data, "palette")) {
      "grove" -> R.drawable.handy_widget_grove
      "ochre" -> R.drawable.handy_widget_ochre
      else -> R.drawable.handy_widget_bg
    })
  }

  protected fun open(context: Context, uri: String): PendingIntent =
    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

  /** Today's bead for the habit under [key]: a check-in, or open it. */
  protected fun beadAction(context: Context, data: SharedPreferences, key: String): PendingIntent {
    val full = prefix + key
    return if (data.getString("${full}mode", "open") == "tap") {
      val intent = Intent(context, CheckInReceiver::class.java).apply {
        action = CheckInReceiver.ACTION
        this.data = Uri.parse("handy-habit://tap/${Uri.encode(data.getString("${full}id", ""))}?key=$full")
        putExtra("key", full)
      }
      var flags = PendingIntent.FLAG_UPDATE_CURRENT
      if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
      PendingIntent.getBroadcast(context, 0, intent, flags)
    } else {
      open(context, data.getString("${full}open", null) ?: "handy-habit://today")
    }
  }

  companion object {
    /** A day ended since the app last wrote: redraw now, then ask for fresh data once. */
    fun refreshIfStale(context: Context, data: SharedPreferences) {
      val today = LocalDate.now().toString()
      val day = data.getString("day", null) ?: return
      if (day >= today) return
      if (data.getString("refresh_asked", "") == today) return
      data.edit().putString("refresh_asked", today).apply()
      try {
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("handy-habit://refresh")).send()
      } catch (_: Exception) {}
    }

    /** Redraws every Habit widget on the home screen. */
    fun redrawAll(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      for (cls in listOf(
        HandyWidget::class.java, SingleHabitWidget::class.java, RoutineWidget::class.java,
        WeekWidget::class.java, YearWidget::class.java,
      )) {
        val ids = manager.getAppWidgetIds(ComponentName(context, cls))
        if (ids.isEmpty()) continue
        context.sendBroadcast(Intent(context, cls).apply {
          action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
          putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        })
      }
    }
  }
}

/** Today: the kept ring as a bar, and up to five habits with their beads. */
class HandyWidget : HabitWidget("") {
  override fun render(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.habit_widget_today)
    ground(views, data)
    val ink = ink(context, data); val muted = muted(context, data); val accent = accent(context, data)
    views.setTextViewText(R.id.title, str(data, "title", "Handy Habit"))
    views.setTextViewText(R.id.value, str(data, "value", context.getString(R.string.handy_widget_open)))
    views.setTextViewText(R.id.detail, str(data, "detail"))
    views.setTextColor(R.id.title, muted); views.setTextColor(R.id.detail, muted); views.setTextColor(R.id.value, ink)
    views.setProgressBar(R.id.progress, 100, str(data, "progress", "0").toIntOrNull() ?: 0, false)
    views.setOnClickPendingIntent(R.id.widget_root, open(context, str(data, "uri", "handy-habit://today")))
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
    val scale = context.resources.configuration.fontScale.coerceAtLeast(1f)
    val room = ((height - 96 * scale) / (46 * scale)).toInt().coerceIn(1, 5)
    val count = str(data, "hcount", "0").toIntOrNull() ?: 0
    for ((i, ids) in ROWS.withIndex()) {
      val shown = i < count && i < room
      views.setViewVisibility(ids[0], if (shown) View.VISIBLE else View.GONE)
      if (!shown) continue
      val key = "h${i}_"
      val colour = Beads.colour(str(data, "${key}color"), accent)
      views.setTextViewText(ids[1], str(data, "${key}name"))
      views.setTextColor(ids[1], ink)
      views.setImageViewBitmap(ids[2], Beads.row(context, str(data, "${key}beads"), colour, muted, 13f))
      val fill = str(data, "${key}fill", "0").toIntOrNull() ?: 0
      val plus = str(data, "${key}step", "100") != "100" && fill < 100
      views.setImageViewBitmap(ids[3], Beads.today(context, fill, colour, muted, 36f, plus))
      views.setContentDescription(ids[3], str(data, "${key}name"))
      views.setOnClickPendingIntent(ids[3], beadAction(context, data, key))
      views.setOnClickPendingIntent(ids[0], open(context, str(data, "${key}open", "handy-habit://today")))
    }
    views.setViewVisibility(R.id.empty, if (count == 0) View.VISIBLE else View.GONE)
    views.setTextColor(R.id.empty, muted)
    return views
  }

  companion object {
    val ROWS = arrayOf(
      intArrayOf(R.id.row0, R.id.name0, R.id.beads0, R.id.bead0),
      intArrayOf(R.id.row1, R.id.name1, R.id.beads1, R.id.bead1),
      intArrayOf(R.id.row2, R.id.name2, R.id.beads2, R.id.bead2),
      intArrayOf(R.id.row3, R.id.name3, R.id.beads3, R.id.bead3),
      intArrayOf(R.id.row4, R.id.name4, R.id.beads4, R.id.bead4),
    )
  }
}

/** One habit: a large today's bead to tap, two weeks of beads, its run. */
class SingleHabitWidget : HabitWidget("habit_") {
  override fun render(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.habit_widget_single)
    ground(views, data)
    val ink = ink(context, data); val muted = muted(context, data); val accent = accent(context, data)
    val colour = Beads.colour(str(data, "color"), accent)
    views.setTextViewText(R.id.value, str(data, "name", str(data, "value", context.getString(R.string.handy_widget_open))))
    views.setTextViewText(R.id.detail, str(data, "streak", str(data, "detail")))
    views.setTextColor(R.id.value, ink); views.setTextColor(R.id.detail, muted)
    views.setOnClickPendingIntent(R.id.widget_root, open(context, str(data, "open", str(data, "uri", "handy-habit://today"))))
    val has = str(data, "id").isNotEmpty()
    views.setViewVisibility(R.id.bead, if (has) View.VISIBLE else View.GONE)
    views.setViewVisibility(R.id.beads, if (has) View.VISIBLE else View.GONE)
    if (has) {
      val fill = str(data, "fill", "0").toIntOrNull() ?: 0
      val plus = str(data, "step", "100") != "100" && fill < 100
      views.setImageViewBitmap(R.id.bead, Beads.today(context, fill, colour, muted, 56f, plus))
      views.setContentDescription(R.id.bead, str(data, "name"))
      views.setOnClickPendingIntent(R.id.bead, beadAction(context, data, ""))
      views.setImageViewBitmap(R.id.beads, Beads.row(context, str(data, "beads"), colour, muted, 12f))
    }
    return views
  }
}

/** A routine: its name, its steps, and Start or Resume. */
class RoutineWidget : HabitWidget("routine_") {
  override fun render(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.habit_widget_routine)
    ground(views, data)
    val ink = ink(context, data); val muted = muted(context, data)
    views.setTextViewText(R.id.value, str(data, "value", context.getString(R.string.handy_widget_open)))
    views.setTextViewText(R.id.detail, str(data, "detail"))
    val button = str(data, "button")
    views.setTextViewText(R.id.button, button)
    views.setViewVisibility(R.id.button, if (button.isEmpty()) View.GONE else View.VISIBLE)
    views.setTextColor(R.id.value, ink); views.setTextColor(R.id.detail, muted)
    val link = open(context, str(data, "uri", "handy-habit://today"))
    views.setOnClickPendingIntent(R.id.widget_root, link)
    views.setOnClickPendingIntent(R.id.button, link)
    return views
  }
}

/** Week (Pro): seven days of beads for up to six habits. */
class WeekWidget : HabitWidget("week_") {
  override fun render(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.habit_widget_week)
    ground(views, data)
    val ink = ink(context, data); val muted = muted(context, data); val accent = accent(context, data)
    views.setTextViewText(R.id.title, str(data, "title", "Handy Habit"))
    views.setTextColor(R.id.title, ink)
    views.setOnClickPendingIntent(R.id.widget_root, open(context, str(data, "uri", "handy-habit://today")))
    val pro = str(data, "pro") == "1"
    views.setViewVisibility(R.id.locked, if (pro) View.GONE else View.VISIBLE)
    views.setTextViewText(R.id.locked, str(data, "locked"))
    views.setTextColor(R.id.locked, muted)
    // Without Pro the week still shows, dimmed, under one line saying so.
    views.setImageViewBitmap(R.id.days, Beads.labels(context, str(data, "days").split("|"), muted, 16f))
    val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
    val room = ((height - 70) / 30).coerceIn(1, 6)
    val count = str(data, "count", "0").toIntOrNull() ?: 0
    for ((i, ids) in ROWS.withIndex()) {
      val shown = i < count && i < (if (pro) room else room - 1)
      views.setViewVisibility(ids[0], if (shown) View.VISIBLE else View.GONE)
      if (!shown) continue
      val key = "w${i}_"
      views.setTextViewText(ids[1], str(data, "${key}name"))
      views.setTextColor(ids[1], if (pro) ink else muted)
      views.setImageViewBitmap(ids[2], Beads.row(context, str(data, "${key}beads"), Beads.colour(str(data, "${key}color"), accent), muted, 16f))
      views.setInt(ids[2], "setImageAlpha", if (pro) 255 else 90)
      views.setOnClickPendingIntent(ids[0], open(context, str(data, "${key}uri", "handy-habit://today")))
    }
    return views
  }

  companion object {
    val ROWS = arrayOf(
      intArrayOf(R.id.wrow0, R.id.wname0, R.id.wbeads0),
      intArrayOf(R.id.wrow1, R.id.wname1, R.id.wbeads1),
      intArrayOf(R.id.wrow2, R.id.wname2, R.id.wbeads2),
      intArrayOf(R.id.wrow3, R.id.wname3, R.id.wbeads3),
      intArrayOf(R.id.wrow4, R.id.wname4, R.id.wbeads4),
      intArrayOf(R.id.wrow5, R.id.wname5, R.id.wbeads5),
    )
  }
}

/** Year (Pro): sixteen weeks of one habit as a grid of beads. */
class YearWidget : HabitWidget("year_") {
  override fun render(context: Context, data: SharedPreferences, options: Bundle): RemoteViews {
    val views = RemoteViews(context.packageName, R.layout.habit_widget_year)
    ground(views, data)
    val ink = ink(context, data); val muted = muted(context, data); val accent = accent(context, data)
    views.setTextViewText(R.id.title, str(data, "name", str(data, "value")))
    views.setTextViewText(R.id.detail, str(data, "detail"))
    views.setTextColor(R.id.title, ink); views.setTextColor(R.id.detail, muted)
    views.setOnClickPendingIntent(R.id.widget_root, open(context, str(data, "uri", "handy-habit://today")))
    val pro = str(data, "pro") == "1"
    views.setViewVisibility(R.id.locked, if (pro) View.GONE else View.VISIBLE)
    views.setTextViewText(R.id.locked, str(data, "locked"))
    views.setTextColor(R.id.locked, muted)
    views.setImageViewBitmap(R.id.grid, Beads.grid(context, str(data, "grid"), Beads.colour(str(data, "color"), accent), muted, 12f))
    views.setInt(R.id.grid, "setImageAlpha", if (pro) 255 else 90)
    return views
  }
}

/**
 * A tap on today's bead: fill it in the stored data and redraw at once, so
 * the widget answers immediately, then hand the check-in to the app's
 * background callback, which records it and writes the true figures.
 */
class CheckInReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != ACTION) return
    val data = HomeWidgetPlugin.getData(context)
    val key = intent.getStringExtra("key") ?: return
    val id = data.getString("${key}id", null) ?: return
    if (data.getString("${key}mode", "open") != "tap") return
    val edit = data.edit()
    // Every place this habit is drawn: the Today rows and the one-habit widget.
    val keys = (0 until 5).map { "h${it}_" } + listOf("habit_")
    for (k in keys) {
      if (data.getString("${k}id", null) != id) continue
      val fill = (data.getString("${k}fill", "0")?.toIntOrNull() ?: 0)
      val step = (data.getString("${k}step", "100")?.toIntOrNull() ?: 100)
      val next = minOf(100, fill + step)
      edit.putString("${k}fill", "$next")
      edit.putString("${k}state", if (next >= 100) "c" else "p")
      if (next >= 100) edit.putString("${k}mode", "open")
    }
    edit.apply()
    HabitWidget.redrawAll(context)
    try {
      HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("handy-habit://tap/${Uri.encode(id)}")).send()
    } catch (_: Exception) {}
  }

  companion object {
    const val ACTION = "com.example.handysuite.habit.CHECK_IN"
  }
}
