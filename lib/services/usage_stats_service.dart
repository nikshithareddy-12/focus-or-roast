  import 'package:flutter/services.dart';

class InstalledApp {
  final String name;
  final String packageName;
  final Uint8List? iconBytes;

  InstalledApp({
    required this.name,
    required this.packageName,
    this.iconBytes,
  });

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledApp(
      name: map['name'] ?? '',
      packageName: map['packageName'] ?? '',
      iconBytes: map['icon'] != null ? Uint8List.fromList(List<int>.from(map['icon'])) : null,
    );
  }
}

class UsageStatsService {
  static const _methodChannel = MethodChannel('com.example.focus_or_roast/usage');
  static const _eventChannel = EventChannel('com.example.focus_or_roast/distraction_stream');

  Future<bool> hasUsagePermission() async {
    try {
      final bool hasPerm = await _methodChannel.invokeMethod('hasUsagePermission');
      return hasPerm;
    } catch (e) {
      print('Error checking usage permission: $e');
      return false;
    }
  }

  Future<void> openUsageSettings() async {
    try {
      await _methodChannel.invokeMethod('openUsageSettings');
    } catch (e) {
      print('Error opening usage settings: $e');
    }
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final List<dynamic>? result = await _methodChannel.invokeMethod('getInstalledApps');
      if (result == null) return [];
      return result.map((item) => InstalledApp.fromMap(item as Map)).toList();
    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }

  Future<void> startMonitoring({
    required List<String> packages,
    required String subject,
  }) async {
    try {
      await _methodChannel.invokeMethod('startMonitoring', {
        'packages': packages,
        'subject': subject,
      });
    } catch (e) {
      print('Error starting native monitoring: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      await _methodChannel.invokeMethod('stopMonitoring');
    } catch (e) {
      print('Error stopping native monitoring: $e');
    }
  }

  Future<void> bringAppToFront() async {
    try {
      await _methodChannel.invokeMethod('bringAppToFront');
    } catch (e) {
      print('Error bringing app to front: $e');
    }
  }

  Stream<String> get distractionStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }
}
