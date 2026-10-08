package com.aistudio.sanchay.savtrkr

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val METHOD_CHANNEL = "com.aistudio.sanchay/notifications"
    private val EVENT_CHANNEL = "com.aistudio.sanchay/notification_stream"

    private var methodChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerGranted" -> {
                    val enabledListeners = NotificationManagerCompat.getEnabledListenerPackages(this)
                    val isEnabled = enabledListeners.contains(packageName)
                    result.success(isEnabled)
                }
                "openNotificationListenerSettings" -> {
                    openNotificationListenerSettings()
                    result.success(true)
                }
                "getPendingNotifications" -> {
                    val pendingList = ArrayList(UpiNotificationListenerService.queuedTransactions)
                    UpiNotificationListenerService.queuedTransactions.clear()
                    val persistedList = UpiNotificationListenerService.getAndClearPersistedTransactions(this)
                    pendingList.addAll(persistedList)
                    result.success(pendingList)
                }
                "simulateNotification" -> {
                    val sample = call.arguments as? Map<*, *>
                    if (sample != null) {
                        @Suppress("UNCHECKED_CAST")
                        val txMap = sample as Map<String, Any>
                        methodChannel?.invokeMethod("onNotificationIntercepted", txMap)
                        eventSink?.success(txMap)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing sample transaction map", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Connect real-time callback
        UpiNotificationListenerService.listenerCallback = { txMap ->
            runOnUiThread {
                methodChannel?.invokeMethod("onNotificationIntercepted", txMap)
                eventSink?.success(txMap)
            }
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val enabledListeners = NotificationManagerCompat.getEnabledListenerPackages(this)
        if (enabledListeners.contains(packageName)) {
            return true
        }
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!TextUtils.isEmpty(flat)) {
            val names = flat.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
            for (name in names) {
                val cn = ComponentName.unflattenFromString(name)
                if (cn != null && TextUtils.equals(packageName, cn.packageName)) {
                    return true
                }
            }
        }
        return false
    }

    private fun openNotificationListenerSettings() {
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            startActivity(intent)
        } catch (_: Exception) {
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        UpiNotificationListenerService.listenerCallback = null
        eventSink = null
    }
}
