package doo.chuk.dev.widgets

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The only door between the widgets and the app's data.
 *
 * Reading: Dart writes one JSON blob per widget into the app's
 * `FlutterSharedPreferences` file (see `lib/features/widget/widget_service.dart`).
 * A widget is redrawn by the launcher, at times when no Flutter engine exists,
 * so it must be able to read its content without one. Plain JSON in the
 * preferences file is what makes that possible.
 *
 * Writing: a tick cannot reach Hive — Hive lives in the Dart isolate. The tick
 * is therefore queued here and applied by `WidgetService.processPending()` when
 * the app next starts or resumes. The stored blob is updated at the same time,
 * so the row looks right immediately even though the real write is still owed.
 */
object WidgetStore {

    private const val PREFS = "FlutterSharedPreferences"

    // Written by Dart, read by the widgets.
    const val KEY_TASKS = "flutter.widget_tasks"
    const val KEY_CALENDAR = "flutter.widget_calendar"
    const val KEY_NOTES = "flutter.widget_notes"
    const val KEY_HABITS = "flutter.widget_habits"

    // Written by the widgets, read by Dart.
    private const val KEY_PENDING_TASKS = "flutter.widget_pending_tasks"
    private const val KEY_PENDING_HABITS = "flutter.widget_pending_habits"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun today(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    /** Rows of one list widget, in the order Dart put them. */
    fun rows(context: Context, key: String): List<JSONObject> {
        val raw = prefs(context).getString(key, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { array.optJSONObject(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** The calendar widget carries a header next to its rows. */
    fun calendar(context: Context): JSONObject {
        val raw = prefs(context).getString(KEY_CALENDAR, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    fun calendarRows(context: Context): List<JSONObject> {
        val array = calendar(context).optJSONArray("items") ?: return emptyList()
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
    }

    /**
     * Queue "this task should now be [done]" and flag it in the stored blob so
     * the row redraws as ticked right away.
     */
    fun toggleTask(context: Context, id: String, done: Boolean) {
        val p = prefs(context)
        val pending = readMap(p, KEY_PENDING_TASKS)
        pending.put(id, done)

        val tasks = readArray(p, KEY_TASKS)
        for (i in 0 until tasks.length()) {
            val row = tasks.optJSONObject(i) ?: continue
            if (row.optString("id") == id) row.put("is_completed", done)
        }

        p.edit()
            .putString(KEY_PENDING_TASKS, pending.toString())
            .putString(KEY_TASKS, tasks.toString())
            .apply()
    }

    /**
     * Queue a habit tick for today. The streak is nudged by one so the row does
     * not lie until the app has recomputed it for real.
     */
    fun toggleHabit(context: Context, id: String, done: Boolean) {
        val p = prefs(context)
        val day = today()
        val pending = readMap(p, KEY_PENDING_HABITS)
        pending.put("$id|$day", done)

        val habits = readArray(p, KEY_HABITS)
        for (i in 0 until habits.length()) {
            val row = habits.optJSONObject(i) ?: continue
            if (row.optString("id") != id) continue
            if (row.optBoolean("done") == done) continue
            row.put("done", done)
            val streak = row.optInt("streak", 0)
            row.put("streak", if (done) streak + 1 else maxOf(0, streak - 1))
        }

        p.edit()
            .putString(KEY_PENDING_HABITS, pending.toString())
            .putString(KEY_HABITS, habits.toString())
            .apply()
    }

    private fun readMap(p: SharedPreferences, key: String): JSONObject {
        val raw = p.getString(key, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun readArray(p: SharedPreferences, key: String): JSONArray {
        val raw = p.getString(key, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }
}
