package com.example.rituals

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

class RitualWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.ritual_widget).apply {
                val posterName = widgetData.getString("posterName", null)
                setTextViewText(
                    R.id.widget_poster_name,
                    posterName ?: "Waiting for photos..."
                )

                val caption = widgetData.getString("caption", null)
                setTextViewText(
                    R.id.widget_caption,
                    caption ?: ""
                )

                // Load photo if available
                val photoUrl = widgetData.getString("photoUrl", null)
                if (photoUrl != null) {
                    val file = File(photoUrl)
                    if (file.exists()) {
                        val bitmap: Bitmap = BitmapFactory.decodeFile(file.absolutePath)
                        setImageViewBitmap(R.id.widget_image, bitmap)
                    }
                }
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
