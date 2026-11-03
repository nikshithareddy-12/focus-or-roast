import 'package:flutter/services.dart';
import '../core/constants/app_keys.dart';
import '../models/distraction_model.dart';

class NativeUsageService {
  static const MethodChannel _methodChannel = MethodChannel(AppKeys.usageChannel);
  static const EventChannel _eventChannel = EventChannel(AppKeys.distractionChannel);

  /// Check if PACKAGE_USAGE_STATS permission is granted
  static Future<bool> hasUsagePermission() async {
    try {
      print('[FocusRoast_Diag] Flutter calling hasUsagePermission method channel...');
      final bool hasPermission = await _methodChannel.invokeMethod('hasUsagePermission');
      print('[FocusRoast_Diag] Flutter received hasUsagePermission: $hasPermission');
      return hasPermission;
    } on PlatformException catch (e) {
      print('[FocusRoast_Diag] Flutter hasUsagePermission PlatformException: $e');
      return false;
    } catch (e) {
      print('[FocusRoast_Diag] Flutter hasUsagePermission generic Exception: $e');
      return false;
    }
  }

  /// Open Android Usage Access settings screen
  static Future<void> openUsageSettings() async {
    try {
      await _methodChannel.invokeMethod('openUsageSettings');
    } on PlatformException catch (_) {}
  }

  /// Check if SYSTEM_ALERT_WINDOW (Display over other apps) permission is granted
  static Future<bool> hasOverlayPermission() async {
    try {
      final bool hasOverlay = await _methodChannel.invokeMethod('hasOverlayPermission');
      return hasOverlay;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Open Android Display Over Other Apps settings screen
  static Future<void> openOverlaySettings() async {
    try {
      await _methodChannel.invokeMethod('openOverlaySettings');
    } on PlatformException catch (_) {}
  }

  /// Get installed launcher applications from device
  static Future<List<DistractionModel>> getInstalledApps() async {
    try {
      final List<dynamic> result = await _methodChannel.invokeMethod('getInstalledApps');
      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return DistractionModel.fromMap(map);
      }).toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Start background detection monitoring for selected distraction package names
  static Future<void> startMonitoring(
    List<String> distractionPackageNames, {
    String subject = 'General',
    int durationMinutes = 30,
  }) async {
    print('[FocusRoast_Diag] Packages passed from Flutter: $distractionPackageNames (subject: $subject, duration: $durationMinutes)');
    try {
      await _methodChannel.invokeMethod('startMonitoring', {
        'packages': distractionPackageNames,
        'subject': subject,
        'durationMinutes': durationMinutes,
      });
    } on PlatformException catch (e) {
      print('[FocusRoast_Diag] startMonitoring PlatformException: $e');
    }
  }

  /// Stop background detection monitoring
  static Future<void> stopMonitoring() async {
    try {
      await _methodChannel.invokeMethod('stopMonitoring');
    } on PlatformException catch (_) {}
  }

  /// Broadcast stream of foreground package names detected by Kotlin AppUsageDetector
  static Stream<String> get distractionStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }
}
