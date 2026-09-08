package doo.chuk.dev.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import doo.chuk.dev.R

/**
 * What the four widgets have in common: a header with a title, a subtitle and
 * one round action button, a list fed by a [android.widget.RemoteViewsService]
 * and an empty state.
 *
 * A subclass only says which layout, which service and which taps it wants.
 */
abstract class ChukdooWidgetProvider : AppWidgetProvider() {

    /** Root layout of this widget. */
    abstract val layoutRes: Int

    /** Title shown top left. */
    abstract val titleRes: Int

    /** Service that fills the list. */
    abstract val serviceClass: Class<*>

    /** Where the header (and the empty state) takes the user. */
    abstract val openTarget: String

    /** Where the round button takes the user. */
    abstract val actionTarget: String

    /** Second header line, e.g. "3 open". Null hides the line. */
    open fun subtitle(context: Context): String? = null

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, build(context, appWidgetId))
        }
        @Suppress("DEPRECATION")
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
    }

    private fun build(context: Context, appWidgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, layoutRes)
        val name = javaClass.name

        views.setTextViewText(R.id.widget_title, context.getString(titleRes))

        val subtitle = subtitle(context)
        if (subtitle.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_subtitle, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_subtitle, View.VISIBLE)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
        }

        val headerIntent = ChukdooWidgets.openIntent(
            context,
            ChukdooWidgets.requestCode(name, openTarget),
            openTarget,
        )
        views.setOnClickPendingIntent(R.id.widget_header, headerIntent)
        views.setOnClickPendingIntent(R.id.widget_empty, headerIntent)
        views.setOnClickPendingIntent(
            R.id.widget_action,
            ChukdooWidgets.openIntent(
                context,
                ChukdooWidgets.requestCode(name, actionTarget, "action"),
                actionTarget,
            ),
        )

        // The service intent has to differ per widget instance, otherwise two
        // placed copies share one factory and show the same scroll position.
        val serviceIntent = android.content.Intent(context, serviceClass).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(toUri(android.content.Intent.URI_INTENT_SCHEME))
        }
        @Suppress("DEPRECATION")
        views.setRemoteAdapter(R.id.widget_list, serviceIntent)
        views.setEmptyView(R.id.widget_list, R.id.widget_empty)
        views.setPendingIntentTemplate(
            R.id.widget_list,
            ChukdooWidgets.itemTemplate(
                context,
                ChukdooWidgets.requestCode(name, "template", appWidgetId),
            ),
        )
        return views
    }
}
