package com.example.focus_or_roast

import android.app.ActivityOptions
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

class AppUsageDetector(
    private val context: Context,
    private val onDistractionDetected: (String) -> Unit
) {
    private val TAG = "FocusRoast_Detector"
    private val handler = Handler(Looper.getMainLooper())
    private var isMonitoring = false
    private var monitoredPackages: Set<String> = emptySet()
    private var lastDetectedPackage: String? = null
    private var currentSubject: String = "General"
    private var currentDurationMinutes: Int = 30

    private val checkRunnable = object : Runnable {
        override fun run() {
            if (!isMonitoring) return

            try {
                val currentForeground = UsageStatsHelper.getForegroundApp(context)
                if (currentForeground != null && currentForeground.isNotEmpty()) {
                    val isMatch = monitoredPackages.contains(currentForeground)
                    
                    // Diagnostic log for current foreground and match
                    Log.d("[FocusRoast_Diag]", "Current foreground package detected: $currentForeground | Match: $isMatch | BlockActive=${BlockActivity.isActive}")

                    if (isMatch) {
                        Log.i("[FocusRoast_Diag]", "Foreground: $currentForeground | Monitored: $monitoredPackages | Match result: true")

                        // Distraction app detected!
                        if (!BlockActivity.isActive) {
                            if (!UsageStatsHelper.hasOverlayPermission(context)) {
                                Log.w("[FocusRoast_Diag]", "SYSTEM_ALERT_WINDOW not granted — attempting best-effort launch over $currentForeground")
                            }
                            Log.i("[FocusRoast_Diag]", "Launching BlockActivity for: $currentForeground")
                            launchBlockActivity(currentForeground)
                        }

                        // Debounce distraction event recording
                        if (currentForeground != lastDetectedPackage) {
                            Log.i("[FocusRoast_Diag]", "DISTRACTION EVENT RECORDED: $currentForeground")
                            lastDetectedPackage = currentForeground
                            onDistractionDetected(currentForeground)
                        }
                    } else {
                        // Reset debounce when user returns to FocusRoast or any non-distraction app
                        // This ensures that opening the distraction app AGAIN counts as a NEW event
                        if (lastDetectedPackage != null) {
                            Log.d("[FocusRoast_Diag]", "Foreground is non-distraction ($currentForeground), resetting lastDetectedPackage from $lastDetectedPackage to null")
                            lastDetectedPackage = null
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in checkRunnable: ${e.message}", e)
            }

            if (isMonitoring) {
                handler.postDelayed(this, 800) // Poll every 800ms
            }
        }
    }

    private fun launchBlockActivity(packageName: String) {
        Log.i("[FocusRoast_Diag]", "BlockActivity launch attempt for package: $packageName")
        var launchSuccess = false
        try {
            val intent = Intent(context, BlockActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("package_name", packageName)
                putExtra("subject", currentSubject)
                putExtra("duration_minutes", currentDurationMinutes)
            }

            val optionsBundle = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ActivityOptions.makeBasic().apply {
                    setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                }.toBundle()
            } else {
                null
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                1002,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            // Method 1: Direct activity launch with ActivityOptions
            try {
                if (optionsBundle != null) {
                    context.startActivity(intent, optionsBundle)
                } else {
                    context.startActivity(intent)
                }
                launchSuccess = true
            } catch (e1: Exception) {
                Log.w(TAG, "Direct startActivity failed: ${e1.message}")
            }

            // Method 2: PendingIntent send with background launch allowance
            try {
                if (optionsBundle != null) {
                    pendingIntent.send(context, 0, intent, null, null, null, optionsBundle)
                } else {
                    pendingIntent.send()
                }
                launchSuccess = true
            } catch (e2: Exception) {
                Log.w(TAG, "PendingIntent send failed: ${e2.message}")
            }

            // Method 3: Full-Screen Intent notification for guaranteed display
            try {
                val notifBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Notification.Builder(context, BackgroundService.CHANNEL_ID)
                } else {
                    @Suppress("DEPRECATION")
                    Notification.Builder(context)
                }
                val blockNotif = notifBuilder
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setContentTitle("🔥 Distraction Blocked!")
                    .setContentText("Focus session is active. Get back to work!")
                    .setFullScreenIntent(pendingIntent, true)
                    .setAutoCancel(true)
                    .build()

                val notifManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notifManager.notify(1002, blockNotif)
                launchSuccess = true
            } catch (e3: Exception) {
                Log.w(TAG, "FullScreenIntent notification failed: ${e3.message}")
            }

            Log.i("[FocusRoast_Diag]", "BlockActivity launch attempt result: ${if (launchSuccess) "SUCCESS" else "FAILED"}")
        } catch (e: Exception) {
            Log.e("[FocusRoast_Diag]", "BlockActivity launch attempt result: FAILED (${e.message})", e)
        }
    }

    fun startMonitoring(packages: List<String>, subject: String = "General", durationMinutes: Int = 30) {
        monitoredPackages = packages.toSet()
        currentSubject = subject
        currentDurationMinutes = durationMinutes
        lastDetectedPackage = null
        Log.i("[FocusRoast_Diag]", "Packages monitored by AppUsageDetector: $monitoredPackages (Subject: $subject, Duration: $durationMinutes min)")
        if (!isMonitoring) {
            isMonitoring = true
            handler.post(checkRunnable)
        }
    }

    fun stopMonitoring() {
        Log.i("[FocusRoast_Diag]", "AppUsageDetector: stopMonitoring")
        isMonitoring = false
        lastDetectedPackage = null
        monitoredPackages = emptySet()
        handler.removeCallbacks(checkRunnable)
    }
}
