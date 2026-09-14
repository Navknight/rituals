package com.rituals.android

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TodayWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = HomeWidgetPlugin.getData(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.today_widget).apply {
                val done = data.getString("todayDone", null)?.toIntOrNull() ?: 0
                val due = data.getString("todayDue", null)?.toIntOrNull() ?: 0
                val lines = data.getString("todayLines", null).orEmpty()
                val space = data.getString("todaySpace", null).orEmpty()

                setTextViewText(R.id.widget_today_space, space)
                setTextViewText(R.id.widget_today_count, "$done/$due")
                setProgressBar(
                    R.id.widget_today_progress,
                    100,
                    if (due <= 0) 0 else (done * 100 / due).coerceIn(0, 100),
                    false
                )
                setTextViewText(
                    R.id.widget_today_lines,
                    if (due <= 0 || lines.isEmpty()) "Nothing due today" else lines
                )

                // Tapping the widget opens the app.
                val launch = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (launch != null) {
                    setOnClickPendingIntent(
                        R.id.widget_container,
                        PendingIntent.getActivity(
                            context,
                            0,
                            launch,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                    )
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
