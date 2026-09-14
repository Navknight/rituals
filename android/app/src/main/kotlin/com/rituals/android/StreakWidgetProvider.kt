package com.rituals.android

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class StreakWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = HomeWidgetPlugin.getData(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                val streak = data.getString("topStreak", null).orEmpty()
                val ritual = data.getString("topStreakRitual", null).orEmpty()

                if (streak.isEmpty() || streak == "0") {
                    setTextViewText(R.id.widget_streak_number, "0")
                    setTextViewText(R.id.widget_streak_ritual, "Start a streak today")
                } else {
                    setTextViewText(R.id.widget_streak_number, "$streak ⚡")
                    setTextViewText(R.id.widget_streak_ritual, ritual)
                }

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
