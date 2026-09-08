package doo.chuk.dev.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import doo.chuk.dev.R

/** Names and helpers shared by the four home screen widgets. */
object ChukdooWidgets {

    /** Ticks handled on the home screen, without opening the app. */
    const val ACTION_TOGGLE_TASK = "doo.chuk.dev.widget.TOGGLE_TASK"
    const val ACTION_TOGGLE_HABIT = "doo.chuk.dev.widget.TOGGLE_HABIT"

    /** Taps that hand over to the app. [EXTRA_TARGET] says where to land. */
    const val ACTION_OPEN = "doo.chuk.dev.widget.OPEN"

    const val EXTRA_TARGET = "widget_target"
    const val EXTRA_ID = "widget_id"
    const val EXTRA_DATE = "widget_date"
    const val EXTRA_DONE = "widget_done"

    /** Every provider, so one change can refresh all of them. */
    val providers: List<Class<out ChukdooWidgetProvider>> = listOf(
        TasksWidgetProvider::class.java,
        CalendarWidgetProvider::class.java,
        NotesWidgetProvider::class.java,
        HabitsWidgetProvider::class.java,
    )

    /**
     * Redraw every placed widget. A task can show up in the tasks list and in
     * the calendar, and a habit tick changes the header count, so a change is
     * never local to one provider.
     */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isEmpty()) continue
            @Suppress("DEPRECATION")
            manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
            context.sendBroadcast(
                Intent(context, provider).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
            )
        }
    }

    /**
     * A PendingIntent that lands in the app. Always `getActivity`: a broadcast
     * receiver may not start an activity from the background, which is exactly
     * what a widget tap is.
     */
    fun openIntent(
        context: Context,
        requestCode: Int,
        target: String,
        id: String? = null,
        date: String? = null,
    ): PendingIntent {
        val intent = Intent(context, WidgetActionActivity::class.java).apply {
            action = ACTION_OPEN
            putExtra(EXTRA_TARGET, target)
            if (id != null) putExtra(EXTRA_ID, id)
            if (date != null) putExtra(EXTRA_DATE, date)
        }
        return PendingIntent.getActivity(context, requestCode, intent, immutableFlags())
    }

    /**
     * The one PendingIntent a collection can carry. It has no action and no
     * extras: every row fills those in itself (see
     * [android.widget.RemoteViews.setOnClickFillInIntent]), which is why it has
     * to be mutable.
     */
    fun itemTemplate(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, WidgetActionActivity::class.java)
        return PendingIntent.getActivity(context, requestCode, intent, mutableFlags())
    }

    private fun immutableFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun mutableFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    /**
     * A stable, collision-free request code. Two PendingIntents that differ
     * only in their extras count as equal, so the request code is what keeps
     * the header button and the plus button apart.
     */
    fun requestCode(vararg parts: Any?): Int = parts.contentHashCode()
}
