package com.example.devicelocunlock

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Token সংরক্ষণ করুন
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val data = message.data
        if (data.isNotEmpty()) {
            val command = data["command"]
            when (command) {
                "LOCK" -> {
                    lockDevice()
                    showNotification("Device Locked", "আপনার ডিভাইস লক করা হয়েছে")
                }
                "UNLOCK" -> {
                    showNotification("Device Unlocked", "আপনার ডিভাইস আনলক করা হয়েছে")
                }
                "EMERGENCY_LOCK" -> {
                    lockDevice()
                    showNotification("Emergency Lock", "জরুরী কারণে ডিভাইস লক করা হয়েছে")
                }
                "REMINDER" -> {
                    val title = data["title"] ?: "Reminder"
                    val body = data["body"] ?: "আপনার পেমেন্টের সময় এসেছে"
                    showNotification(title, body)
                }
            }
        }
    }

    private fun lockDevice() {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, DeviceAdminReceiver::class.java)

        if (dpm.isAdminActive(adminComponent)) {
            dpm.lockNow()
        }
    }

    private fun showNotification(title: String, body: String) {
        val channelId = "device_lock_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Device Lock Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}