package hu.eletrend.eletrend

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Paint
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Kezdőképernyő-widget a mai szokásokkal. Az adatokat a Dart oldal írja
 * (lib/habits_widget.dart), egy szokásra koppintva a Dart kód pipálja ki.
 */
class HabitsWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    // Ha az adat egy korábbi napról való (éjfél óta nem nyitottad meg az appot), ma még semmi sincs kész.
    val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    val fresh = widgetData.getString("day", null) == today
    val count = widgetData.getInt("count", 0)
    val rows = listOf(
        Triple(R.id.row0, R.id.check0, R.id.name0),
        Triple(R.id.row1, R.id.check1, R.id.name1),
        Triple(R.id.row2, R.id.check2, R.id.name2),
        Triple(R.id.row3, R.id.check3, R.id.name3),
        Triple(R.id.row4, R.id.check4, R.id.name4),
    )

    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.habits_widget).apply {
        var done = 0
        rows.forEachIndexed { i, (row, check, name) ->
          if (i >= count) {
            setViewVisibility(row, View.GONE)
            return@forEachIndexed
          }
          val isDone = fresh && widgetData.getBoolean("habit${i}_done", false)
          if (isDone) done++
          setViewVisibility(row, View.VISIBLE)
          setTextViewText(check, if (isDone) "✅" else "⬜")
          setTextViewText(name, widgetData.getString("habit${i}_name", ""))
          setInt(name, "setPaintFlags", if (isDone) Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG else Paint.ANTI_ALIAS_FLAG)
          val id = Uri.encode(widgetData.getString("habit${i}_id", ""))
          setOnClickPendingIntent(row, HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("eletrend://toggle?id=$id")))
        }
        setViewVisibility(R.id.widget_empty, if (count == 0) View.VISIBLE else View.GONE)
        setTextViewText(R.id.widget_title, if (count == 0) "Mai szokások" else "Mai szokások  $done/$count")
        setOnClickPendingIntent(R.id.widget_title, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
      }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
