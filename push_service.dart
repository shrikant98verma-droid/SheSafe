import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_nav.dart';
import '../pages/family_alert_page.dart';
import '../widgets/nearby_alert_sheet.dart';
import 'backend.dart';

final _local = FlutterLocalNotificationsPlugin();

const _channel = AndroidNotificationChannel(
  'sos_alerts',
  'SOS alerts',
  description: 'Emergency alerts from trusted contacts and people nearby',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

Future<void> _initLocal({DidReceiveNotificationResponseCallback? onTap}) async {
  await _local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: onTap,
  );
  await _local
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
}

/// Shows the alert as a high-priority notification. For an SOS it is a
/// full-screen intent, so on a locked phone the alert screen opens by itself.
Future<void> _showAlertNotification(Map<String, dynamic> data) async {
  await _initLocal();
  final isSos = data['type'] == 'sos';
  await _local.show(
    ((data['sosId'] as String?) ?? '').hashCode & 0x7fffffff,
    isSos
        ? '${data['name'] ?? 'Someone'} is in danger'
        : 'A woman near you may need help',
    isSos
        ? 'Tap to see her live location'
        : '${data['distance'] ?? 'Nearby'}. Tap to help.',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: isSos,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    ),
    payload: jsonEncode(data),
  );
}

/// Runs when a push arrives while the app is closed or in the background.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _showAlertNotification(message.data);
}

class PushService {
  PushService._();

  /// Sets up notification handling. Call once after the app has started.
  static Future<void> init() async {
    await _initLocal(onTap: (r) => _openPayload(r.payload));

    // App is open: show the alert screen straight away.
    FirebaseMessaging.onMessage.listen((m) => _openData(m.data));

    // App was started by tapping or by a full-screen alert.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final payload = launch!.notificationResponse?.payload;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(
          const Duration(milliseconds: 400),
          () => _openPayload(payload),
        );
      });
    }
  }

  /// Asks for notification permissions and saves this phone's push token.
  static Future<void> registerToken(SafetyBackend backend) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, sound: true, criticalAlert: true);
      final android = _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestFullScreenIntentPermission();
      final token = await messaging.getToken();
      if (token != null) await backend.saveFcmToken(token);
      messaging.onTokenRefresh.listen(backend.saveFcmToken);
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  static void _openPayload(String? payload) {
    if (payload == null) return;
    try {
      _openData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {}
  }

  static void _openData(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (nav == null || context == null) return;
    final sosId = data['sosId'] as String?;

    if (data['type'] == 'sos') {
      nav.push(MaterialPageRouteHelper.fullscreen(
        FamilyAlertPage(
          name: (data['name'] as String?) ?? 'Someone',
          phone: (data['phone'] as String?) ?? '',
          sosId: sosId,
          lat: double.tryParse('${data['lat'] ?? ''}'),
          lng: double.tryParse('${data['lng'] ?? ''}'),
        ),
      ));
    } else if (data['type'] == 'nearby') {
      showNearbyAlertSheet(
        context,
        sosId: sosId,
        distanceText: (data['distance'] as String?) ?? 'Nearby',
      );
    }
  }
}

class MaterialPageRouteHelper {
  static Route<void> fullscreen(Widget page) => PageRouteBuilder<void>(
        fullscreenDialog: true,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}
