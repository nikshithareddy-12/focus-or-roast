package com.example.focus_or_roast

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

class BackgroundService : Service() {
    companion object {
        const val TAG = "FocusRoast_BgService"
        const val CHANNEL_ID = "focus_roast_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START_MONITORING = "com.example.focus_or_roast.ACTION_START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.example.focus_or_roast.ACTION_STOP_MONITORING"

        var distractionListener: ((String) -> Unit)? = null
    }

    private var appUsageDetector: AppUsageDetector? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "BackgroundService onCreate")
        createNotificationChannel()
        val notification = createNotification("Focus session active", "Monitoring distraction apps...")
        if (Build.VERSION.SDK_INT >= 34) { // Build.VERSION_CODES.UPSIDE_DOWN_CAKE
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        appUsageDetector = AppUsageDetector(applicationContext) { packageName ->
            Log.d(TAG, "Distraction detected by service: $packageName")
            distractionListener?.invoke(packageName)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START_MONITORING
        Log.d(TAG, "onStartCommand with action: $action")

        when (action) {
            ACTION_START_MONITORING -> {
                val packages = intent?.getStringArrayListExtra("packages") ?: arrayListOf()
                val subject = intent?.getStringExtra("subject") ?: "General"
                val durationMinutes = intent?.getIntExtra("duration_minutes", 30) ?: 30

                Log.i("[FocusRoast_Diag]", "Packages received by BackgroundService: $packages")
                Log.d(TAG, "Starting monitoring for packages: $packages, subject: $subject, duration: $durationMinutes min")
                updateNotification("Focus Mode: $subject", "Monitoring $durationMinutes min session")
                appUsageDetector?.startMonitoring(packages, subject, durationMinutes)
            }
            ACTION_STOP_MONITORING -> {
                Log.d(TAG, "Stopping monitoring and foreground service")
                appUsageDetector?.stopMonitoring()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "BackgroundService onDestroy")
        appUsageDetector?.stopMonitoring()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "FocusRoast Active Session",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitoring distraction apps during active focus sessions"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(title: String, text: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(title: String, text: String) {
        val notification = createNotification(title, text)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }
}
