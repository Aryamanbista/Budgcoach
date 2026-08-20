import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _enabledKey = 'personalized_notifications_enabled';
  static const String _notifiedKey = 'notified_nudge_ids';
  static final StreamController<String> _routes =
      StreamController<String>.broadcast();
  static String? _initialRoute;

  static Stream<String> get routes => _routes.stream;

  static String? takeInitialRoute() {
    final route = _initialRoute;
    _initialRoute = null;
    return route;
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.startsWith('/')) _routes.add(route);
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final route = launchDetails?.notificationResponse?.payload;
      if (route != null && route.startsWith('/')) _initialRoute = route;
    }
  }

  static Future<bool> isEnabled() async =>
      (await _storage.read(key: _enabledKey)) == 'true';

  static Future<bool> setEnabled(bool enabled) async {
    if (kIsWeb) return false;
    if (!enabled) {
      await _storage.write(key: _enabledKey, value: 'false');
      await _plugin.cancelAll();
      return false;
    }

    bool granted = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      granted =
          await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    await _storage.write(key: _enabledKey, value: granted.toString());
    return granted;
  }

  static Future<void> showPersonalizedNudge({
    required String id,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!await isEnabled() || id.isEmpty) return;
    final notified = (await _storage.read(key: _notifiedKey) ?? '')
        .split('|')
        .where((item) => item.isNotEmpty)
        .toList();
    if (notified.contains(id)) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'personalized_nudges',
        'Personalized budget nudges',
        channelDescription:
            'Timely alerts based on your own budgets and spending',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
      payload: route ?? '/nudges',
    );
    notified.add(id);
    await _storage.write(
      key: _notifiedKey,
      value: notified.reversed.take(100).toList().reversed.join('|'),
    );
  }
}
