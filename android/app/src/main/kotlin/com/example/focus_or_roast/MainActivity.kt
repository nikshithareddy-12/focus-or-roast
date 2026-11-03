package com.example.focus_or_roast

import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "FocusRoast_MainActivity"
    private val USAGE_CHANNEL = "com.example.focus_or_roast/usage"
    private val DISTRACTION_CHANNEL = "com.example.focus_or_roast/distraction_stream"

    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.d(TAG, "configureFlutterEngine")

        // Hook BackgroundService distraction listener to Flutter EventSink
        BackgroundService.distractionListener = { packageName ->
            runOnUiThread {
                Log.d(TAG, "Sending distraction event to Flutter: $packageName")
                eventSink?.success(packageName)
            }
        }

        val handler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "hasUsagePermission" -> {
                    val hasPerm = UsageStatsHelper.hasUsagePermission(this)
                    result.success(hasPerm)
                }
                "openUsageSettings" -> {
                    UsageStatsHelper.openUsageSettings(this)
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    val hasOverlay = UsageStatsHelper.hasOverlayPermission(this)
                    result.success(hasOverlay)
                }
                "openOverlaySettings" -> {
                    UsageStatsHelper.openOverlaySettings(this)
                    result.success(null)
                }
                "getInstalledApps" -> {
                    Thread {
                        val apps = UsageStatsHelper.getInstalledApps(this)
                        runOnUiThread {
                            result.success(apps)
                        }
                    }.start()
                }
                "startMonitoring" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val subject = call.argument<String>("subject") ?: "General"
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 30

                    Log.i("[FocusRoast_Diag]", "Packages received by MainActivity: $packages (subject=$subject, duration=$durationMinutes)")

                    val serviceIntent = Intent(this, BackgroundService::class.java).apply {
                        action = BackgroundService.ACTION_START_MONITORING
                        putStringArrayListExtra("packages", ArrayList(packages))
                        putExtra("subject", subject)
                        putExtra("duration_minutes", durationMinutes)
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }

                    result.success(null)
                }
                "stopMonitoring" -> {
                    Log.i("[FocusRoast_Diag]", "MainActivity: stopMonitoring called")
                    val serviceIntent = Intent(this, BackgroundService::class.java).apply {
                        action = BackgroundService.ACTION_STOP_MONITORING
                    }
                    startService(serviceIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL).setMethodCallHandler(handler)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DISTRACTION_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "Distraction EventChannel listening")
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "Distraction EventChannel cancelled")
                    eventSink = null
                }
            }
        )
    }

    override fun onDestroy() {
        BackgroundService.distractionListener = null
        super.onDestroy()
    }
}
