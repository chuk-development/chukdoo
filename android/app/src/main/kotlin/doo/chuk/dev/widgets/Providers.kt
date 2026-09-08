package doo.chuk.dev.widgets

import android.content.Context
import doo.chuk.dev.R

/** The open tasks of the main list. Ticking a row completes it in the app. */
class TasksWidgetProvider : ChukdooWidgetProvider() {
    override val layoutRes = R.layout.widget_tasks
    override val titleRes = R.string.widget_tasks_name
    override val serviceClass = TasksWidgetService::class.java
    override val openTarget = "open_tasks"
    override val actionTarget = "add_task"

    override fun subtitle(context: Context): String {
        val open = WidgetStore.rows(context, WidgetStore.KEY_TASKS)
            .count { !it.optBoolean("is_completed") }
        return when (open) {
            0 -> "All done"
            1 -> "1 open"
            else -> "$open open"
        }
    }
}

/** Today and tomorrow: events and tasks that carry a time. */
class CalendarWidgetProvider : ChukdooWidgetProvider() {
    override val layoutRes = R.layout.widget_calendar
    override val titleRes = R.string.widget_calendar_name
    override val serviceClass = CalendarWidgetService::class.java
    override val openTarget = "open_calendar"
    override val actionTarget = "open_day"

    override fun subtitle(context: Context): String? =
        WidgetStore.calendar(context).optString("header").ifEmpty { null }
}

/** The notes edited most recently, with a plain-text snippet. */
class NotesWidgetProvider : ChukdooWidgetProvider() {
    override val layoutRes = R.layout.widget_notes
    override val titleRes = R.string.widget_notes_name
    override val serviceClass = NotesWidgetService::class.java
    override val openTarget = "open_notes"
    override val actionTarget = "new_note"

    override fun subtitle(context: Context): String = "Recently edited"
}

/** Today's habits with their streak; a tick marks one done. */
class HabitsWidgetProvider : ChukdooWidgetProvider() {
    override val layoutRes = R.layout.widget_habits
    override val titleRes = R.string.widget_habits_name
    override val serviceClass = HabitsWidgetService::class.java
    override val openTarget = "open_habits"
    override val actionTarget = "open_habits"

    override fun subtitle(context: Context): String? {
        val rows = WidgetStore.rows(context, WidgetStore.KEY_HABITS)
        if (rows.isEmpty()) return null
        val done = rows.count { it.optBoolean("done") }
        return "$done of ${rows.size} done"
    }
}
