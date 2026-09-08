package doo.chuk.dev

import android.content.Intent
import android.database.ContentObserver
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import doo.chuk.dev.widgets.ChukdooWidgets
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
    private var widgetChannel: MethodChannel? = null

    /**
     * The widget tap that started the app. Dart pulls it once after its first
     * frame — the method channel exists long before the Dart side has installed
     * its handler, so pushing it right away would drop it.
     */
    private var pendingWidgetAction: HashMap<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Data changed in the app: redraw every placed widget.
                "updateWidgets", "updateWidget" -> {
                    ChukdooWidgets.refreshAll(applicationContext)
                    result.success(null)
                }
                "takeLaunchAction" -> {
                    val action = pendingWidgetAction
                    pendingWidgetAction = null
                    result.success(action)
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingWidgetAction = readWidgetAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = readWidgetAction(intent) ?: return
        // The app is already running, so the Dart handler is listening.
        val channel = widgetChannel
        if (channel != null) {
            channel.invokeMethod("widgetAction", action)
        } else {
            pendingWidgetAction = action
        }
    }

    /** The extras a widget tap carries, as the map Dart expects. */
    private fun readWidgetAction(intent: Intent?): HashMap<String, String>? {
        if (intent == null) return null
        if (intent.action != ChukdooWidgets.ACTION_OPEN) return null
        val target = intent.getStringExtra(ChukdooWidgets.EXTRA_TARGET) ?: return null
        val map = HashMap<String, String>()
        map["action"] = target
        intent.getStringExtra(ChukdooWidgets.EXTRA_ID)?.let { map["id"] = it }
        intent.getStringExtra(ChukdooWidgets.EXTRA_DATE)?.let { map["date"] = it }
        return map
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
        widgetChannel = null
        super.onDestroy()
    }
}
