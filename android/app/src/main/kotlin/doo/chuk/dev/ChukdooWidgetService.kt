package doo.chuk.dev

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * Service that provides data to the widget's ListView
 */
class ChukdooWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ChukdooWidgetFactory(applicationContext)
    }
}

/**
 * Factory that creates RemoteViews for the widget's ListView
 */
class ChukdooWidgetFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "ChukdooWidgetFactory"
        private const val MAX_TODOS = 5
    }

    private val todayTodos = mutableListOf<TodoItem>()

    data class TodoItem(
        val id: String,
        val title: String,
        val dueTime: String?,
        val priority: Int,
        val isCompleted: Boolean
    )

    override fun onCreate() {
        Log.d(TAG, "Factory created")
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "Reloading data")
        todayTodos.clear()

        try {
            // Read todos from Hive storage
            // Hive stores data in the app's files directory
            val hivePath = File(context.filesDir, "hive/todos.hive")

            // Read from Flutter's SharedPreferences
            // Flutter stores in FlutterSharedPreferences with "flutter." prefix
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val todosJson = prefs.getString("flutter.today_todos", null)

            if (todosJson != null) {
                val todosArray = org.json.JSONArray(todosJson)
                val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

                for (i in 0 until minOf(todosArray.length(), MAX_TODOS)) {
                    val todo = todosArray.getJSONObject(i)
                    val dueDate = todo.optString("due_date", "")

                    // Only show today's todos
                    if (dueDate.startsWith(today) || dueDate.isEmpty()) {
                        todayTodos.add(
                            TodoItem(
                                id = todo.getString("id"),
                                title = todo.getString("title"),
                                dueTime = todo.optString("due_time", null),
                                priority = todo.optInt("priority", 4),
                                isCompleted = todo.optBoolean("is_completed", false)
                            )
                        )
                    }
                }
            }

            Log.d(TAG, "Loaded ${todayTodos.size} todos")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading todos: ${e.message}")
        }
    }

    override fun onDestroy() {
        todayTodos.clear()
    }

    override fun getCount(): Int = todayTodos.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= todayTodos.size) {
            return RemoteViews(context.packageName, R.layout.widget_todo_item)
        }

        val todo = todayTodos[position]
        val views = RemoteViews(context.packageName, R.layout.widget_todo_item)

        // Set title
        views.setTextViewText(R.id.widget_todo_title, todo.title)

        // Set time if available
        if (!todo.dueTime.isNullOrEmpty()) {
            views.setTextViewText(R.id.widget_todo_time, todo.dueTime)
            views.setViewVisibility(R.id.widget_todo_time, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_todo_time, android.view.View.GONE)
        }

        // Set priority color
        val priorityColor = when (todo.priority) {
            1 -> Color.parseColor("#FF5252") // Red
            2 -> Color.parseColor("#FFB74D") // Amber
            3 -> Color.parseColor("#64B5F6") // Blue
            else -> Color.parseColor("#5C5C6E") // Grey
        }
        views.setInt(R.id.widget_todo_priority, "setBackgroundColor", priorityColor)

        // Set checkbox state
        val checkboxRes = if (todo.isCompleted) {
            android.R.drawable.checkbox_on_background
        } else {
            android.R.drawable.checkbox_off_background
        }
        views.setImageViewResource(R.id.widget_todo_checkbox, checkboxRes)

        // Set fill-in intent for clicks
        val fillInIntent = Intent().apply {
            putExtra(ChukdooWidget.EXTRA_TODO_ID, todo.id)
        }
        views.setOnClickFillInIntent(R.id.widget_todo_item, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
