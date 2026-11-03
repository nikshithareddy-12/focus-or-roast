package com.example.focus_or_roast

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import java.io.ByteArrayOutputStream

object UsageStatsHelper {
    private const val TAG = "FocusRoast_Usage"

    fun hasUsagePermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }

        // Primary source of truth: AppOps GET_USAGE_STATS state
        var granted = (mode == AppOpsManager.MODE_ALLOWED)

        // When mode is MODE_DEFAULT (or not explicitly allowed/denied),
        // verify via UsageStatsManager as a supplementary check
        if (!granted && mode == AppOpsManager.MODE_DEFAULT) {
            try {
                val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
                val now = System.currentTimeMillis()
                val stats = usageStatsManager?.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    now - 1000 * 60 * 5, // last 5 minutes
                    now
                )
                // If usage permission is granted, queryUsageStats returns non-empty list on active device
                if (stats != null && stats.isNotEmpty()) {
                    granted = true
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error querying usage stats fallback: ${e.message}")
            }
        }

        Log.i("[FocusRoast_Diag]", "Package: ${context.packageName}, AppOps mode: $mode, Final permission result: $granted")
        return granted
    }

    fun openUsageSettings(context: Context) {
        Log.d(TAG, "Opening Usage Access settings screen")
        try {
            // Attempt to open FocusRoast's specific Usage Access settings page using package URI
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", context.packageName, null)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Targeted usage settings intent failed, opening generic settings: ${e.message}")
            val fallbackIntent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(fallbackIntent)
        }
    }

    fun hasOverlayPermission(context: Context): Boolean {
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
        Log.i("[FocusRoast_Diag]", "Overlay permission status: $granted")
        return granted
    }

    fun openOverlaySettings(context: Context) {
        Log.d(TAG, "Opening Overlay permission settings screen")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:" + context.packageName)
            ).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        }
    }

    fun getInstalledApps(context: Context): List<Map<String, Any>> {
        Log.d(TAG, "Querying installed launcher applications...")
        val pm = context.packageManager
        
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(mainIntent, 0)
        }

        val appList = mutableListOf<Map<String, Any>>()
        val ownPackage = context.packageName
        val addedPackages = mutableSetOf<String>()

        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo.packageName
            if (packageName == ownPackage) continue
            if (addedPackages.contains(packageName)) continue

            val appLabel = resolveInfo.loadLabel(pm).toString()
            val iconDrawable = try {
                resolveInfo.loadIcon(pm)
            } catch (e: Exception) {
                null
            }
            val iconBytes = if (iconDrawable != null) drawableToByteArray(iconDrawable) else null

            val appMap = mutableMapOf<String, Any>(
                "name" to appLabel,
                "packageName" to packageName
            )
            if (iconBytes != null) {
                appMap["icon"] = iconBytes
            }
            appList.add(appMap)
            addedPackages.add(packageName)
        }

        Log.i("[FocusRoast_Diag]", "Found ${appList.size} launchable installed apps on device")
        return appList.sortedBy { (it["name"] as String).lowercase() }
    }

    fun getForegroundApp(context: Context): String? {
        if (!hasUsagePermission(context)) {
            Log.w(TAG, "Cannot getForegroundApp: Usage Access permission not granted")
            return null
        }

        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 60000 // 60 seconds window for reliable event history

        val events = usm.queryEvents(startTime, endTime)
        var lastForegroundApp: String? = null
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastForegroundApp = event.packageName
            }
        }

        if (lastForegroundApp == null) {
            // Fallback to queryUsageStats
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_BEST, startTime, endTime)
            if (!stats.isNullOrEmpty()) {
                val sorted = stats.sortedByDescending { it.lastTimeUsed }
                lastForegroundApp = sorted.firstOrNull()?.packageName
            }
        }

        return lastForegroundApp
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        return try {
            val targetSize = 48 // Small icon thumbnail for ultra-fast compression and serialization
            val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                Bitmap.createScaledBitmap(drawable.bitmap, targetSize, targetSize, true)
            } else {
                val bitmap = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bitmap
            }
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 60, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }
}
