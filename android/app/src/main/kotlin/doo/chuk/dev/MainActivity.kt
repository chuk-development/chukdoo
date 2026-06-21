package doo.chuk.dev

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val WIDGET_CHANNEL = "doo.chuk.dev/widget"
    private val SUNRISE_CHANNEL = "doo.chuk.dev/sunrise"
    private val SUNRISE_EVENTS = "doo.chuk.dev/sunrise_events"
    private val SUNRISE_URI = Uri.parse("content://doo.chuk.dev.sunrise/today")

    private var observer: ContentObserver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    updateWidget()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SUNRISE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "notifyChange" -> {
                    contentResolver.notifyChange(SUNRISE_URI, null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SUNRISE_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    registerObserver()
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterObserver()
                }
            })
    }

    private fun registerObserver() {
        if (observer != null) return
        observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                eventSink?.success(true)
            }
        }
        try {
            contentResolver.registerContentObserver(SUNRISE_URI, true, observer!!)
        } catch (_: Exception) {
            observer = null
        }
    }

    private fun unregisterObserver() {
        observer?.let {
            try { contentResolver.unregisterContentObserver(it) } catch (_: Exception) {}
        }
        observer = null
    }

    override fun onDestroy() {
        unregisterObserver()
        super.onDestroy()
    }

    private fun updateWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val widgetComponent = ComponentName(applicationContext, ChukdooWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)

        if (appWidgetIds.isNotEmpty()) {
            val intent = Intent(applicationContext, ChukdooWidget::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            }
            sendBroadcast(intent)
        }
    }
}
