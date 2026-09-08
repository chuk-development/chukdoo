package doo.chuk.dev.widgets

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import doo.chuk.dev.MainActivity

/**
 * Where every widget tap lands. Invisible: it decides and finishes.
 *
 * It exists because a collection (the list inside a widget) can carry exactly
 * one PendingIntent template, while a row has to do two different things — tick
 * and open. A broadcast receiver cannot open an activity from the background,
 * so the template is an activity PendingIntent and the branch happens here.
 */
class WidgetActionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val id = intent.getStringExtra(ChukdooWidgets.EXTRA_ID)
        val done = intent.getBooleanExtra(ChukdooWidgets.EXTRA_DONE, true)

        when (intent.action) {
            ChukdooWidgets.ACTION_TOGGLE_TASK -> {
                if (!id.isNullOrEmpty()) WidgetStore.toggleTask(this, id, done)
                ChukdooWidgets.refreshAll(this)
            }

            ChukdooWidgets.ACTION_TOGGLE_HABIT -> {
                if (!id.isNullOrEmpty()) WidgetStore.toggleHabit(this, id, done)
                ChukdooWidgets.refreshAll(this)
            }

            else -> openApp()
        }

        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    private fun openApp() {
        val target = intent.getStringExtra(ChukdooWidgets.EXTRA_TARGET) ?: "open_tasks"
        val launch = Intent(this, MainActivity::class.java).apply {
            action = ChukdooWidgets.ACTION_OPEN
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(ChukdooWidgets.EXTRA_TARGET, target)
            intent.getStringExtra(ChukdooWidgets.EXTRA_ID)?.let {
                putExtra(ChukdooWidgets.EXTRA_ID, it)
            }
            intent.getStringExtra(ChukdooWidgets.EXTRA_DATE)?.let {
                putExtra(ChukdooWidgets.EXTRA_DATE, it)
            }
        }
        startActivity(launch)
    }
}
