package doo.chuk.dev

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.net.Uri
import android.util.Log

/**
 * Chukdoo Home Screen Widget
 * Shows today's todos with ability to mark them as completed
 */
class ChukdooWidget : AppWidgetProvider() {

    companion object {
        private const val TAG = "ChukdooWidget"
        const val ACTION_REFRESH = "doo.chuk.dev.ACTION_REFRESH"
        const val ACTION_OPEN_APP = "doo.chuk.dev.ACTION_OPEN_APP"
        const val ACTION_TOGGLE_TODO = "doo.chuk.dev.ACTION_TOGGLE_TODO"
        const val EXTRA_TODO_ID = "todo_id"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")

        // Update each widget instance
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_REFRESH -> {
                Log.d(TAG, "Refresh action received")
                // Trigger widget update
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (appWidgetIds != null) {
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
            ACTION_TOGGLE_TODO -> {
                val todoId = intent.getStringExtra(EXTRA_TODO_ID)
                Log.d(TAG, "Toggle todo: $todoId")
                // TODO: Implement toggle via platform channel
            }
            ACTION_OPEN_APP -> {
                Log.d(TAG, "Open app action")
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(launchIntent)
            }
        }
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "Widget disabled")
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_layout)

        // Set up refresh button
        val refreshIntent = Intent(context, ChukdooWidget::class.java).apply {
            action = ACTION_REFRESH
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            appWidgetId,
            refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshPendingIntent)

        // Set up click to open app
        val openAppIntent = Intent(context, ChukdooWidget::class.java).apply {
            action = ACTION_OPEN_APP
        }
        val openAppPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)

        // Set up list view with remote adapter
        val serviceIntent = Intent(context, ChukdooWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_todo_list, serviceIntent)

        // Set empty view
        views.setEmptyView(R.id.widget_todo_list, R.id.widget_empty)

        // Set up item click intent template
        val itemClickIntent = Intent(context, ChukdooWidget::class.java).apply {
            action = ACTION_OPEN_APP
        }
        val itemClickPendingIntent = PendingIntent.getBroadcast(
            context,
            1,
            itemClickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        views.setPendingIntentTemplate(R.id.widget_todo_list, itemClickPendingIntent)

        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_todo_list)

        Log.d(TAG, "Widget $appWidgetId updated")
    }
}
