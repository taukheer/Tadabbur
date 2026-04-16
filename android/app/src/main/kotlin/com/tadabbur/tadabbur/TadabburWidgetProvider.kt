package com.tadabbur.tadabbur

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Tadabbur home screen widget (Android).
 *
 * Reads today's ayah from the [HomeWidget]-shared preferences that the
 * Flutter side writes on every app launch + ayah completion. On tap,
 * opens the app — on Android 12+ the launch goes through the standard
 * MainActivity intent so the app restores the user's current screen.
 *
 * Data contract (keys must match HomeWidgetService in Dart):
 *   - "arabic"        → Uthmani Arabic text of today's ayah
 *   - "translation"   → localized translation (empty string if missing)
 *   - "verseKey"      → e.g. "52:2"
 *   - "surahName"     → e.g. "At-Tur"
 *   - "dayLabel"      → e.g. "Day 4" (empty string if unknown)
 */
class TadabburWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.tadabbur_widget)

            val arabic = widgetData.getString("arabic", null)
                ?: context.getString(R.string.widget_placeholder_arabic)
            val translation = widgetData.getString("translation", null) ?: ""
            val verseKey = widgetData.getString("verseKey", null) ?: ""
            val surahName = widgetData.getString("surahName", null) ?: ""
            val dayLabel = widgetData.getString("dayLabel", null) ?: ""

            views.setTextViewText(R.id.widget_arabic, arabic)

            if (translation.isNotEmpty()) {
                views.setTextViewText(R.id.widget_translation, translation)
            } else {
                views.setTextViewText(
                    R.id.widget_translation,
                    context.getString(R.string.widget_placeholder_translation)
                )
            }

            if (verseKey.isNotEmpty()) {
                views.setTextViewText(
                    R.id.widget_verse_ref,
                    if (surahName.isNotEmpty()) "$surahName  ·  $verseKey"
                    else verseKey
                )
            } else {
                views.setTextViewText(R.id.widget_verse_ref, "Tadabbur")
            }

            views.setTextViewText(R.id.widget_day, dayLabel)

            // Tap widget → launch the app. Uses HomeWidgetLaunchIntent
            // so plugin receives the launch reason and can navigate the
            // Flutter side to the daily ayah screen if desired later.
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("tadabbur://widget")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
