package com.openthings.openthings

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import android.content.SharedPreferences

/**
 * Home-screen "Today" widget: shows the Today count and the first few
 * to-do titles. Data is pushed from Dart via the home_widget plugin.
 */
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.today_widget).apply {
                val count = widgetData.getInt("today_count", 0)
                val titles = widgetData.getString("today_titles", "") ?: ""
                setTextViewText(R.id.widget_title, "Today · $count")
                setTextViewText(
                    R.id.widget_body,
                    if (titles.isEmpty()) "All clear" else titles
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
