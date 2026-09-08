package doo.chuk.dev.widgets

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import doo.chuk.dev.R
import org.json.JSONObject

/** Which of the four lists a factory serves. */
enum class WidgetKind(val itemLayout: Int) {
    TASKS(R.layout.widget_item_task),
    CALENDAR(R.layout.widget_item_calendar),
    NOTES(R.layout.widget_item_note),
    HABITS(R.layout.widget_item_habit),
}

/**
 * Draws the rows of one widget from the JSON snapshot in [WidgetStore].
 *
 * The rows are one group, like every list in the app: the first and last row
 * get the strong outer corner, the corners in between stay nearly square, and a
 * 3dp gap does the separating instead of a divider.
 */
class WidgetListFactory(
    private val context: Context,
    private val kind: WidgetKind,
) : RemoteViewsService.RemoteViewsFactory {

    private val rows = mutableListOf<JSONObject>()
    private var tomorrow: String = ""

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        rows.clear()
        when (kind) {
            WidgetKind.TASKS -> rows += WidgetStore.rows(context, WidgetStore.KEY_TASKS)
            WidgetKind.NOTES -> rows += WidgetStore.rows(context, WidgetStore.KEY_NOTES)
            WidgetKind.HABITS -> rows += WidgetStore.rows(context, WidgetStore.KEY_HABITS)
            WidgetKind.CALENDAR -> {
                rows += WidgetStore.calendarRows(context)
                tomorrow = WidgetStore.calendar(context).optString("tomorrow")
            }
        }
    }

    override fun onDestroy() = rows.clear()

    override fun getCount(): Int = rows.size

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        rows.getOrNull(position)?.optString("id")?.hashCode()?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, kind.itemLayout)
        val row = rows.getOrNull(position) ?: return views

        views.setInt(R.id.widget_item_root, "setBackgroundResource", rowBackground(position))

        when (kind) {
            WidgetKind.TASKS -> bindTask(views, row)
            WidgetKind.CALENDAR -> bindCalendar(views, row)
            WidgetKind.NOTES -> bindNote(views, row)
            WidgetKind.HABITS -> bindHabit(views, row)
        }
        return views
    }

    // ── Rows ──────────────────────────────────────────────────────────────────

    private fun bindTask(views: RemoteViews, row: JSONObject) {
        val id = row.optString("id")
        val done = row.optBoolean("is_completed")
        val title = row.optString("title")

        if (done) {
            val struck = SpannableString(title)
            struck.setSpan(
                StrikethroughSpan(),
                0,
                struck.length,
                Spanned.SPAN_INCLUSIVE_EXCLUSIVE,
            )
            views.setTextViewText(R.id.widget_item_title, struck)
            views.setTextColor(R.id.widget_item_title, color(R.color.widget_text_tertiary))
            views.setImageViewResource(R.id.widget_item_check, R.drawable.ic_widget_check_on)
        } else {
            views.setTextViewText(R.id.widget_item_title, title)
            views.setTextColor(R.id.widget_item_title, color(R.color.widget_text_primary))
            views.setImageViewResource(R.id.widget_item_check, R.drawable.ic_widget_check_off)
        }

        val meta = row.optString("date")
        if (meta.isEmpty() || done) {
            views.setViewVisibility(R.id.widget_item_meta, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_item_meta, View.VISIBLE)
            views.setTextViewText(R.id.widget_item_meta, meta)
            views.setTextColor(
                R.id.widget_item_meta,
                if (row.optBoolean("overdue")) {
                    color(R.color.widget_priority_1)
                } else {
                    color(R.color.widget_text_secondary)
                },
            )
        }

        views.setInt(
            R.id.widget_item_accent,
            "setBackgroundColor",
            priorityColor(row.optInt("priority", 4)),
        )

        views.setOnClickFillInIntent(R.id.widget_item_root, open("open_task", id = id))
        views.setOnClickFillInIntent(
            R.id.widget_item_check,
            Intent().apply {
                action = ChukdooWidgets.ACTION_TOGGLE_TASK
                putExtra(ChukdooWidgets.EXTRA_ID, id)
                putExtra(ChukdooWidgets.EXTRA_DONE, !done)
            },
        )
    }

    private fun bindCalendar(views: RemoteViews, row: JSONObject) {
        val allDay = row.optBoolean("all_day")
        val start = row.optString("time")
        val end = row.optString("end")

        views.setTextViewText(R.id.widget_item_time, if (allDay) "All day" else start)
        if (allDay || end.isEmpty() || end == "null") {
            views.setViewVisibility(R.id.widget_item_time_end, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_item_time_end, View.VISIBLE)
            views.setTextViewText(R.id.widget_item_time_end, end)
        }

        views.setTextViewText(R.id.widget_item_title, row.optString("title"))
        views.setInt(
            R.id.widget_item_accent,
            "setBackgroundColor",
            parseColor(row.optString("color"), color(R.color.widget_accent)),
        )

        val day = row.optString("day")
        val label = buildString {
            if (day.isNotEmpty() && day == tomorrow) append("Tomorrow")
            if (row.optString("kind") == "task") {
                if (isNotEmpty()) append(" · ")
                append("Task")
            }
        }
        if (label.isEmpty()) {
            views.setViewVisibility(R.id.widget_item_meta, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_item_meta, View.VISIBLE)
            views.setTextViewText(R.id.widget_item_meta, label)
        }

        views.setOnClickFillInIntent(R.id.widget_item_root, open("open_day", date = day))
    }

    private fun bindNote(views: RemoteViews, row: JSONObject) {
        views.setTextViewText(R.id.widget_item_title, row.optString("title"))

        val snippet = row.optString("snippet")
        if (snippet.isEmpty()) {
            views.setViewVisibility(R.id.widget_item_meta, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_item_meta, View.VISIBLE)
            views.setTextViewText(R.id.widget_item_meta, snippet)
        }

        views.setInt(
            R.id.widget_item_accent,
            "setBackgroundColor",
            parseColor(row.optString("color"), color(R.color.widget_accent)),
        )
        views.setOnClickFillInIntent(
            R.id.widget_item_root,
            open("open_note", id = row.optString("id")),
        )
    }

    private fun bindHabit(views: RemoteViews, row: JSONObject) {
        val id = row.optString("id")
        val done = row.optBoolean("done")
        val streak = row.optInt("streak", 0)

        views.setTextViewText(R.id.widget_item_title, row.optString("name"))
        views.setTextColor(
            R.id.widget_item_title,
            if (done) color(R.color.widget_text_secondary) else color(R.color.widget_text_primary),
        )
        views.setImageViewResource(
            R.id.widget_item_check,
            if (done) R.drawable.ic_widget_check_on else R.drawable.ic_widget_check_off,
        )

        views.setViewVisibility(R.id.widget_item_meta, View.VISIBLE)
        views.setTextViewText(
            R.id.widget_item_meta,
            when (streak) {
                0 -> "No streak yet"
                1 -> "1 day streak"
                else -> "$streak day streak"
            },
        )

        views.setInt(
            R.id.widget_item_accent,
            "setBackgroundColor",
            parseColor(row.optString("color"), color(R.color.widget_accent)),
        )

        views.setOnClickFillInIntent(R.id.widget_item_root, open("open_habits"))
        views.setOnClickFillInIntent(
            R.id.widget_item_check,
            Intent().apply {
                action = ChukdooWidgets.ACTION_TOGGLE_HABIT
                putExtra(ChukdooWidgets.EXTRA_ID, id)
                putExtra(ChukdooWidgets.EXTRA_DONE, !done)
            },
        )
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun open(target: String, id: String? = null, date: String? = null): Intent =
        Intent().apply {
            action = ChukdooWidgets.ACTION_OPEN
            putExtra(ChukdooWidgets.EXTRA_TARGET, target)
            if (!id.isNullOrEmpty()) putExtra(ChukdooWidgets.EXTRA_ID, id)
            if (!date.isNullOrEmpty()) putExtra(ChukdooWidgets.EXTRA_DATE, date)
        }

    private fun rowBackground(position: Int): Int {
        val last = rows.size - 1
        return when {
            rows.size == 1 -> R.drawable.widget_row_single
            position == 0 -> R.drawable.widget_row_first
            position == last -> R.drawable.widget_row_last
            else -> R.drawable.widget_row_middle
        }
    }

    private fun color(res: Int): Int = context.getColor(res)

    private fun priorityColor(priority: Int): Int = color(
        when (priority) {
            1 -> R.color.widget_priority_1
            2 -> R.color.widget_priority_2
            3 -> R.color.widget_priority_3
            else -> R.color.widget_priority_4
        }
    )

    private fun parseColor(value: String?, fallback: Int): Int {
        if (value.isNullOrEmpty() || value == "null") return fallback
        return try {
            Color.parseColor(value)
        } catch (_: IllegalArgumentException) {
            fallback
        }
    }
}

/** One service per widget: a collection intent is matched by its component. */
abstract class ChukdooWidgetService : RemoteViewsService() {
    abstract val kind: WidgetKind
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WidgetListFactory(applicationContext, kind)
}

class TasksWidgetService : ChukdooWidgetService() {
    override val kind = WidgetKind.TASKS
}

class CalendarWidgetService : ChukdooWidgetService() {
    override val kind = WidgetKind.CALENDAR
}

class NotesWidgetService : ChukdooWidgetService() {
    override val kind = WidgetKind.NOTES
}

class HabitsWidgetService : ChukdooWidgetService() {
    override val kind = WidgetKind.HABITS
}
