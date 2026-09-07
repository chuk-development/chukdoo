package doo.chuk.dev

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Bundle
import org.json.JSONArray
import org.json.JSONException

/**
 * Read-only ContentProvider that exposes today's pending todos to Sunrise
 * (or any other app the user explicitly approves).
 *
 * Gated by the user-toggled boolean preference `sunrise_enabled`.
 * When the toggle is OFF the cursor returns enabled=0 and no data.
 *
 * Both apps must consent:
 *   - Chukdoo user toggles ON in Settings → "Sunrise verbinden"
 *   - Sunrise user installs/launches Sunrise to read the feed
 */
class SunriseExportProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val ctx = context ?: return MatrixCursor(columns)
        // Flutter's shared_preferences stores under this file with "flutter." prefix
        val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", 0)
        val enabled = prefs.getBoolean("flutter.sunrise_enabled", false)
        val data = prefs.getString("flutter.sunrise_todos", "") ?: ""
        val ts = prefs.getLong("flutter.sunrise_updated_at", 0L)
        val cursor = MatrixCursor(columns)
        cursor.addRow(arrayOf(if (enabled) 1 else 0, if (enabled) data else "", if (enabled) ts else 0L))
        return cursor
    }

    override fun getType(uri: Uri): String = "vnd.android.cursor.item/sunrise.today"

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0

    /**
     * Custom RPC for Sunrise to mark a todo complete without launching the
     * full Chukdoo app. The completion is queued in shared prefs and the
     * exported todos list is updated optimistically so Sunrise reflects the
     * change on its next poll. Actual Hive write happens when Chukdoo next
     * resumes (see SunriseExportService.processPending).
     */
    override fun call(method: String, arg: String?, extras: Bundle?): Bundle? {
        val ctx = context ?: return null
        val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", 0)
        val enabled = prefs.getBoolean("flutter.sunrise_enabled", false)
        if (!enabled) {
            return Bundle().apply { putBoolean("ok", false); putString("error", "disabled") }
        }
        if (arg.isNullOrEmpty()) {
            return Bundle().apply { putBoolean("ok", false); putString("error", "bad_request") }
        }
        val id = arg
        val ok = when (method) {
            "complete" -> toggle(prefs, id, complete = true)
            "uncomplete" -> toggle(prefs, id, complete = false)
            else -> false
        }
        if (ok) {
            ctx.contentResolver.notifyChange(Uri.parse("content://doo.chuk.dev.sunrise/today"), null)
        }
        return Bundle().apply { putBoolean("ok", ok) }
    }

    private fun toggle(prefs: android.content.SharedPreferences, id: String, complete: Boolean): Boolean {
        val pendingKey = if (complete) "flutter.sunrise_pending_complete" else "flutter.sunrise_pending_uncomplete"
        val cancelKey = if (complete) "flutter.sunrise_pending_uncomplete" else "flutter.sunrise_pending_complete"

        val pendingRaw = prefs.getString(pendingKey, null) ?: "[]"
        val pending = try { JSONArray(pendingRaw) } catch (_: JSONException) { JSONArray() }
        var exists = false
        for (i in 0 until pending.length()) {
            if (pending.optString(i) == id) { exists = true; break }
        }
        if (!exists) pending.put(id)

        // Remove from the opposite queue if user is reversing a still-pending op
        val cancelRaw = prefs.getString(cancelKey, null) ?: "[]"
        val cancelled = try {
            val arr = JSONArray(cancelRaw)
            val out = JSONArray()
            for (i in 0 until arr.length()) {
                val v = arr.optString(i)
                if (v != id) out.put(v)
            }
            out.toString()
        } catch (_: JSONException) { cancelRaw }

        // Update exported snapshot: set is_completed for this id if present
        val todosRaw = prefs.getString("flutter.sunrise_todos", null) ?: "[]"
        val updatedTodos = try {
            val arr = JSONArray(todosRaw)
            val out = JSONArray()
            for (i in 0 until arr.length()) {
                val t = arr.optJSONObject(i) ?: continue
                if (t.optString("id") == id) {
                    t.put("is_completed", complete)
                }
                out.put(t)
            }
            out.toString()
        } catch (_: JSONException) { todosRaw }

        prefs.edit()
            .putString(pendingKey, pending.toString())
            .putString(cancelKey, cancelled)
            .putString("flutter.sunrise_todos", updatedTodos)
            .putLong("flutter.sunrise_updated_at", System.currentTimeMillis())
            .apply()
        return true
    }

    companion object {
        private val columns = arrayOf("enabled", "data", "updated_at")
    }
}
