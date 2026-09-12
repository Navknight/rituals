package com.example.rituals

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

class RitualWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = HomeWidgetPlugin.getData(context)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.ritual_widget).apply {
                val ritual = data.getString("ritualTitle", null).orEmpty()
                val poster = data.getString("posterName", null).orEmpty()

                setTextViewText(
                    R.id.widget_poster_name,
                    when {
                        ritual.isNotEmpty() && poster.isNotEmpty() -> "$poster · $ritual"
                        ritual.isNotEmpty() -> ritual
                        poster.isNotEmpty() -> poster
                        else -> "No proof yet"
                    }
                )

                setTextViewText(R.id.widget_caption, data.getString("caption", null).orEmpty())

                val streak = data.getString("streak", null).orEmpty()
                if (streak.isEmpty() || streak == "0") {
                    setViewVisibility(R.id.widget_streak, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_streak, View.VISIBLE)
                    setTextViewText(R.id.widget_streak, "$streak day streak")
                }

                // The widget can only draw a local file, so the on-device copy
                // is what it renders. The remote URL is only a fallback marker.
                val localPath = data.getString("localPath", null)
                val file = localPath?.takeIf { it.isNotEmpty() }?.let { File(it) }
                if (file != null && file.exists()) {
                    BitmapFactory.decodeFile(file.absolutePath)?.let {
                        setImageViewBitmap(R.id.widget_image, it)
                    }
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
