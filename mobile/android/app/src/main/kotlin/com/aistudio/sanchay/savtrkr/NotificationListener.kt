package com.aistudio.sanchay.savtrkr

import android.content.ComponentName
import android.util.Log

/**
 * Android 16 Resilient NotificationListenerService
 * Subclasses UpiNotificationListenerService to provide exact class reference
 * and auto-rebind logic requested for Android 16 background resilience.
 */
class NotificationListener : UpiNotificationListenerService() {

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w("NotificationListener", "Android 16 NotificationListener disconnected. Auto-reconnecting...")
        try {
            requestRebind(ComponentName(this, NotificationListener::class.java))
        } catch (e: Exception) {
            Log.e("NotificationListener", "Failed to auto-rebind NotificationListener: ${e.message}")
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        try {
            requestRebind(ComponentName(this, NotificationListener::class.java))
        } catch (e: Exception) {
            Log.d("NotificationListener", "Rebind on connect notice: ${e.message}")
        }
    }
}
